import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/utils/sound_util.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_softlib/app/database/database.dart';
import 'package:flutter_softlib/app/http/http_api.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/design/app_theme.dart';
import 'app/design/theme_controller.dart';
import 'app/design/ui.dart';
import 'app/widgets/pro_motion.dart';
import 'app/api/user_service.dart';
import 'app/utils/device_info_util.dart';
import 'app/design/app_style_controller.dart';
import 'app/design/glass_theme.dart';
import 'app/design/glass_perf_guard.dart';
import 'app/api/soft_service.dart';
import 'app/api/app_sign.dart';

/// 应用程序主入口
Future<void> main() async {
  // ★ 全局错误捕获：任何未捕获异常都不应导致白屏/闪退
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // ★ 1016：音效开关读取（本地偏好）
    unawaited(SoundUtil.init());
    // Flutter 框架层异常（构建/布局/绘制）
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError('FlutterError', details.exception, details.stack);
    };
    // 未捕获的异步错误
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError('PlatformDispatcher', error, stack);
      return true; // 已处理，避免崩溃
    };

    // ★ 1016：启动就把本机签名指纹读出来缓存（防重打包上报用），
    //   不 await —— 别让它拖慢冷启动
    unawaited(AppSign.warmUp());

    // ★ 兜底：任何页面/模板构建异常都不允许变成「整屏白屏」
    //   （release 下 Flutter 默认给空白占位，看起来就是白屏）
    ErrorWidget.builder = (FlutterErrorDetails details) {
      _logError('ErrorWidget', details.exception, details.stack);
      // ★ 1015：兜底页带上错误摘要，方便用户反馈 / 自己排查
      return _UiFallback(detail: details.exception.toString());
    };

    // ★★★ 1015：图片加载全局兜底
    //   很多页面用 CachedNetworkImage 但没写 errorWidget，
    //   网络图 403/404 时会抛异常 → 触发 ErrorWidget → 整块渲染失败。
    //   这里给所有图片流加全局兜底（拿不到图就静默忽略，不报错）。
    try {
      final prevHandler = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final ex = details.exception.toString();
        // 图片加载类异常：只记录，不上报、不渲染错误页
        if (ex.contains('statusCode') ||
            ex.contains('HttpException') ||
            ex.contains('NetworkImage') ||
            ex.contains('CachedNetworkImage') ||
            ex.contains('Image provider')) {
          debugPrint('[Softlib][img] 图片加载失败: $ex');
          return;
        }
        if (prevHandler != null) {
          prevHandler(details);
        } else {
          FlutterError.presentError(details);
          _logError('FlutterError', details.exception, details.stack);
        }
      };
    } catch (_) {}

    try {
      try {
        final info = await PackageInfo.fromPlatform();
        _appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}
      await _initializeServices();
      // ★ 1015：启动心跳上报 —— 每次冷启动都记一条，
      //   便于确认「用户到底装的是哪个版本」，排查「日志版本对不上」。
      try {
        SoftService.reportLogStatic(
          tag: 'boot',
          error: '[v=$_appVersion] App 启动',
          version: _appVersion.isEmpty ? 'unknown' : _appVersion,
        ).catchError((_) {});
      } catch (_) {}
      runApp(const SoftLibApp());
    } catch (error, stackTrace) {
      _logError('startup', error, stackTrace);
      runApp(_buildErrorApp(error.toString()));
    }
  }, (error, stackTrace) => _logError('zone', error, stackTrace));
}

/// 统一错误日志（不弹窗、不中断用户操作）
/// ★ 1015：同时上报到服务器，方便排查真机闪退（release 看不到 debugPrint）
int _reportCount = 0;
void _logError(String tag, Object error, StackTrace? stack) {
  debugPrint('[Softlib][$tag] $error');
  if (stack != null) debugPrint(stack.toString());
  // ★ 1015：带上当前页面路由，便于定位是哪个页面崩的
  String route = '';
  try {
    route = Get.currentRoute;
  } catch (_) {}
  // ★ 1015 修复上报可靠性：
  //   ① 原来限 30 条 —— 超了就彻底哑了，导致「新包崩了但服务器没日志」。
  //      改为按「错误内容去重」，同一错误只报 3 次，不限制总条数。
  //   ② 原来 fire-and-forget，App 秒崩时请求还没发出。
  //      改为同步入队 + 立即发起，并用 unawaited 兜住异常。
  final key = '$tag|${error.toString().split("\n").first}';
  final n = _reportSeen[key] ?? 0;
  if (n >= 3) return; // 同一错误最多报 3 次，防刷屏
  _reportSeen[key] = n + 1;
  _reportCount++;
  try {
    // 不 await（避免阻塞 UI），但立即发起；异常自己吞掉
    SoftService.reportLogStatic(
      tag: tag,
      error: '[v=$_appVersion][route=$route] ' + error.toString(),
      stack: stack?.toString() ?? '',
      version: _appVersion.isEmpty ? 'unknown' : _appVersion,
    ).catchError((_) {});
  } catch (_) {}
}

/// 同一错误的已上报次数（去重，避免刷屏同时保证新错误一定上报）
final Map<String, int> _reportSeen = {};

/// 应用版本（启动时填，供上报用）
String _appVersion = '';

/// 初始化应用服务
Future<void> _initializeServices() async {
  // 初始化下载器
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  // 设备信息（供后台操作日志记录型号/系统版本，需求 #10）
  await DeviceInfo.init();
  // 初始化数据库
  Get.put<AppDatabase>(AppDatabase(), permanent: true);
  // 初始化HTTP服务
  Get.lazyPut(() => HttpApi(_createDioInstance()));
  // 恢复登录态（读取本地 token + 用户资料）
  await UserService.instance.restore();
  // ★ 1014 修复：恢复后立刻向服务端拉一次最新资料。
  //   本地缓存的会员/管理员状态可能已过期或格式不一致，
  //   会造成「明明是会员/管理员，下载却要付费」的误判。
  try {
    if (UserService.instance.isLoggedIn) {
      await UserService.instance.refreshProfile();
    }
  } catch (_) {
    // 刷新失败不影响启动，后续页面仍会用缓存
  }
  // 恢复主题设置
  await ThemeController.instance.restore();
  // 界面样式（软件列表风格，需求 #9）
  Get.put<AppStyleController>(AppStyleController.instance, permanent: true);
  await AppStyleController.instance.restore();
  // v52j #2：冷启动先拉一次配置并应用主题（首帧就是后台设置的样子）
  try {
    final cfg = await SoftService.instance.fetchConfig(force: true);
    if (cfg != null) {
      final ui = cfg.uiConfig;
      await ThemeController.instance.setMode(switch (ui.themeMode) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      });
      ThemeController.instance.applyServerPalette(ui.themePalette);
      AppStyleController.instance.applyServerDefault(ui.listStyle);
      // ★ 1015 修复：详情页模板此前完全没应用后台下发值
      AppStyleController.instance.applyServerDetail(ui.detailStyle);
    }
  } catch (_) {}

  // ★ 1020 全局玻璃（Liquid Glass）+ 自动降级
  //   后台 ui_config.glass_mode 可选 auto/off/low/medium/high，默认 auto。
  //   探测到的设备能力是上限 —— 后台设得再高，低端机也不会硬开真模糊。
  try {
    final mode =
        SoftService.instance.cachedConfig?.uiConfig.glassMode ?? 'auto';
    await GlassTheme.init(serverMode: mode);
    GlassPerfGuard.start();
  } catch (_) {}
  // 配置EasyLoading
  _configureEasyLoading();
  // 设置设备方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

/// 创建Dio实例
Dio _createDioInstance() {
  final dio = Dio();
  // 配置默认选项
  dio.options.connectTimeout = const Duration(seconds: 6);
  dio.options.receiveTimeout = const Duration(seconds: 6);
  dio.options.sendTimeout = const Duration(seconds: 6);
  return dio;
}

/// 配置EasyLoading样式
void _configureEasyLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.yellow
    ..backgroundColor = Colors.green
    ..indicatorColor = Colors.yellow
    ..textColor = Colors.yellow
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = true
    ..dismissOnTap = false;
}

// ============ SonPro 风格设计系统 ============
/// 品牌主色（蓝紫）
const Color kBrandPrimary = Color(0xFF4B5EF5);

/// 强调色（橙红，用于按钮/徽标）
const Color kBrandAccent = Color(0xFFFF6B35);

/// 浅灰分块背景（亮色模式卡片底）
const Color kBrandBgLight = Color(0xFFF4F5F9);

/// 暗色卡片底
const Color kBrandCardDark = Color(0xFF1A1D23);

/// 亮色/暗色主题统一由设计系统构建（见 design/app_theme.dart）
ThemeData buildLightTheme() => buildNewTheme(dark: false);
ThemeData buildDarkTheme() => buildNewTheme(dark: true);

/// 状态栏／导航栏样式同步
/// ★ 带缓存：只有真正变化时才调用平台通道，避免 build 里反复调用造成闪烁
bool? _lastSystemBarDark;
void _syncSystemBars(bool isDark) {
  if (_lastSystemBarDark == isDark) return;
  _lastSystemBarDark = isDark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark
          ? const Color(0xFF0E1016)
          : const Color(0xFFF6F7FB),
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    ),
  );
}

/// 软件库应用主组件
class SoftLibApp extends StatelessWidget {
  const SoftLibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = ThemeController.instance.mode.value;
      // ★ 依赖 rebuildTick：切换全局配色方案时全 App 重建，实现「全局生效」
      final _ = ThemeController.instance.rebuildTick.value;
      final isDark =
          mode == ThemeMode.dark ||
          (mode == ThemeMode.system &&
              MediaQuery.of(Get.context ?? context).platformBrightness ==
                  Brightness.dark);
      _syncSystemBars(isDark);
      return GetMaterialApp(
        title: '安逸软件汇',
        debugShowCheckedModeBanner: false,
        initialRoute: Routes.splash,
        getPages: AppPages.routes,
        builder: (context, child) {
          // 全局高刷：常驻 Ticker 请求设备最高刷新率
          return HighRefreshScope(child: EasyLoading.init()(context, child));
        },
        // 统一使用 iOS 风格右滑过渡（GetX 路由）
        // ★ 关键：opaqueRoute 必须为 false！
        //   cupertino 是「平移」转场 —— 动画期间新旧两页同时可见。
        //   若 opaque 为 true，Flutter 会认为新页已完全盖住旧页，从动画一开始
        //   就跳过绘制旧页 → 露出底层黑/白 → 表现为「闪屏」。
        defaultTransition: Transition.cupertino,
        // ★ 1015 优化：260ms → 180ms。
        //   点击一个功能实际要经历「按压动画 140ms + 转场 260ms + 内容入场 220ms」，
        //   叠加后超过 600ms，用户明显感觉「点了半天才出来」。
        //   转场压到 180ms 更跟手（iOS 原生返回手势也是这个量级）。
        transitionDuration: const Duration(milliseconds: 180),
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeController.instance.mode.value,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale("zh", "CN"), Locale("en", "US")],
        locale: const Locale("zh", "CN"),
      );
    });
  }
}

/// 构建错误应用页面
Widget _buildErrorApp(String error) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.red[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                '应用启动失败',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.red[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // 重启应用
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                ),
                child: const Text('退出应用'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 构建异常时的可见占位（替代 release 下的空白块，避免「整屏白屏」）
class _UiFallback extends StatefulWidget {
  const _UiFallback({this.detail = ''});
  final String detail;

  @override
  State<_UiFallback> createState() => _UiFallbackState();
}

class _UiFallbackState extends State<_UiFallback> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: Color(0xFFB0B5BD),
              ),
              const SizedBox(height: 10),
              const Text(
                '内容加载异常',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '可返回上一页重试，或点下方按钮刷新',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF9AA0A6)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ★ 1015：返回按钮（原先只提示「请返回」，但没有按钮）
                  TextButton(
                    onPressed: () {
                      try {
                        Get.back();
                      } catch (_) {}
                    },
                    child: const Text('返回'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => setState(() {}),
                    child: const Text('重试'),
                  ),
                ],
              ),
              if (widget.detail.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _showDetail = !_showDetail),
                  child: Text(
                    _showDetail ? widget.detail : '查看详情',
                    maxLines: _showDetail ? 8 : 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFB0B5BD),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
