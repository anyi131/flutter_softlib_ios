import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'app/api/soft_service.dart';

/// 应用程序主入口
Future<void> main() async {
  // ★ 全局错误捕获：任何未捕获异常都不应导致白屏/闪退
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
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

      try {
        await _initializeServices();
        runApp(const SoftLibApp());
      } catch (error, stackTrace) {
        _logError('startup', error, stackTrace);
        runApp(_buildErrorApp(error.toString()));
      }
    },
    (error, stackTrace) => _logError('zone', error, stackTrace),
  );
}

/// 统一错误日志（不弹窗、不中断用户操作）
void _logError(String tag, Object error, StackTrace? stack) {
  debugPrint('[Softlib][$tag] $error');
  if (stack != null) debugPrint(stack.toString());
}

/// flutter_downloader 后台状态回调
///
/// ★ iOS 专用：iOS 后台会话通过该回调把下载状态回传给 Dart 侧
///   （App 被系统唤醒时也能收到）。Android 不使用，行为不变。
///
/// 注意签名必须与插件 `DownloadCallback = void Function(String id, int status, int progress)`
/// 一致：**status 是 int（插件内部状态码），不是 DownloadTaskStatus 枚举**。
@pragma('vm:entry-point')
void flutterDownloaderCallback(String id, int status, int progress) {
  debugPrint('[Softlib][downloader] $id -> $status $progress%');
}

/// 初始化应用服务
Future<void> _initializeServices() async {
  // 初始化下载器
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  // ★ iOS：注册后台下载回调（iOS 需要用回调接收后台/被唤醒时的下载状态；
  //   Android 侧保持原有行为不变，不做改动）
  if (Platform.isIOS) {
    await FlutterDownloader.registerCallback(flutterDownloaderCallback);
  }
  // 设备信息（供后台操作日志记录型号/系统版本，需求 #10）
  await DeviceInfo.init();
  // 初始化数据库
  Get.put<AppDatabase>(AppDatabase(), permanent: true);
  // 初始化HTTP服务
  Get.lazyPut(() => HttpApi(_createDioInstance()));
  // 恢复登录态（读取本地 token + 用户资料）
  await UserService.instance.restore();
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
    }
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
      systemNavigationBarColor:
          isDark ? const Color(0xFF0E1016) : const Color(0xFFF6F7FB),
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
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
      final isDark = mode == ThemeMode.dark ||
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
        return HighRefreshScope(
          child: EasyLoading.init()(context, child),
        );
      },
      // 统一使用 iOS 风格右滑过渡（GetX 路由）
      // ★ 关键：opaqueRoute 必须为 false！
      //   cupertino 是「平移」转场 —— 动画期间新旧两页同时可见。
      //   若 opaque 为 true，Flutter 会认为新页已完全盖住旧页，从动画一开始
      //   就跳过绘制旧页 → 露出底层黑/白 → 表现为「闪屏」。
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 260),
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
