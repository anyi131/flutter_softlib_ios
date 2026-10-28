import 'package:flutter/material.dart';

import '../../utils/safe_ctx.dart';

import '../../utils/apk_installer.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'dart:async';

import 'package:flutter_softlib/app/http/http_api.dart';
import 'package:flutter_softlib/app/pages/navigate/app/app_component.dart';
import 'package:flutter_softlib/app/pages/navigate/home/home_component.dart';
import 'package:flutter_softlib/app/pages/navigate/tips/tips_component.dart';
import 'package:flutter_softlib/app/pages/navigate/square/square_component.dart';
import 'package:flutter_softlib/app/pages/toolkit/tools_component.dart';
import 'package:flutter_softlib/app/pages/navigate/mine/mine_component.dart';
import 'package:flutter_softlib/app/utils/jump_util.dart';
import 'package:flutter_softlib/app/jicun/pages/jicun_page.dart';
import 'package:flutter_softlib/app/utils/toast_util.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../design/theme_controller.dart';
import 'update_flow.dart';

import '../../api/soft_service.dart';
import '../../models/app_config.dart';
import '../splash/maintain_page.dart';
import '../../api/user_service.dart';
import '../../utils/permission_utils.dart';
import '../../widgets/icon_font.dart';

class NavigateLogic extends GetxController with WidgetsBindingObserver {
  /// 底部 Tab —— 由后台「界面配置」动态决定（默认全开）
  // v52j #2：原始 Tab 基准（applyUiConfig 每次从这里重建，避免多次运行索引漂移）
  static const List<NavigationDestination> _baseLabels = [
    NavigationDestination(
      icon: Icon(IconFont.home),
      label: '首页',
      selectedIcon: Icon(IconFont.homeFill),
    ),
    NavigationDestination(
      icon: Icon(IconFont.appB),
      label: '应用',
      selectedIcon: Icon(IconFont.appBFill),
    ),
    // ★ v3.3.4：工具箱 Tab（分类大卡 + 胶囊工具，约 30 个真实工具）
    NavigationDestination(
      icon: Icon(Icons.widgets_outlined),
      label: '工具',
      selectedIcon: Icon(Icons.widgets_rounded),
    ),
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      label: '广场',
      selectedIcon: Icon(Icons.explore),
    ),
    NavigationDestination(
      icon: Icon(Icons.tips_and_updates_outlined),
      label: '线报',
      selectedIcon: Icon(Icons.tips_and_updates),
    ),
    NavigationDestination(
      icon: const Icon(Icons.download_outlined),
      label: '即存',
      selectedIcon: const Icon(Icons.download),
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      label: '我的',
      selectedIcon: Icon(Icons.person),
    ),
  ];
  static List<Widget> _basePages() => [
    HomeComponent(),
    AppComponent(),
    const ToolsComponent(),
    SquareComponent(),
    TipsComponent(),
    JicunPage(),
    MineComponent(),
  ];

  // v55：初始即为完整 6 Tab（首页/应用/广场/线报/即存/我的），
  // 之前初始只有 5 个（缺即存），配置拉取失败时会少一个 Tab。
  List<NavigationDestination> labels = List.of(_baseLabels);
  List<Widget> pages = _basePages();

  /// 维护页是否正显示（防止重复 push）
  bool _maintainShown = false;

  /// 运行中切到维护：整页盖住，用户点「重新加载」会复查配置，恢复后自动关
  void _showMaintain(AppConfig cfg) {
    if (_maintainShown) return;
    final ctx = Get.key.currentContext;
    if (ctx == null) return;
    final nav = Navigator.of(ctx, rootNavigator: true);
    _maintainShown = true;
    nav
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => MaintainPage(
              appName: cfg.splashTitle.isEmpty ? '安逸软件汇' : cfg.splashTitle,
              text: cfg.maintainText,
              template: cfg.maintainTemplate,
              onReload: () async {
                final again =
                    await SoftService.instance.fetchConfig(force: true);
                if (again == null || !again.maintainEnable) {
                  _maintainShown = false;
                  if (nav.canPop()) nav.pop();
                }
              },
            ),
          ),
        )
        .whenComplete(() => _maintainShown = false);
  }

  void _closeMaintain() {
    if (!_maintainShown) return;
    _maintainShown = false;
    final ctx = Get.key.currentContext;
    if (ctx == null) return;
    final nav = Navigator.of(ctx, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  /// 按后台配置裁剪 Tab（工具Tab已整体移除）
  Future<void> applyUiConfig({bool force = false}) async {
    try {
      final cfg = await SoftService.instance.fetchConfig(force: force);
      if (cfg == null) return; // 拉不到配置绝不覆盖当前状态

      // ★ 维护模式：App 已在运行时也要拦得住（冷启动由开屏页负责）
      if (cfg.maintainEnable) {
        _showMaintain(cfg);
        return;
      }
      if (_maintainShown) _closeMaintain();
      final ui = cfg.uiConfig;
      final ls = <NavigationDestination>[];
      final ps = <Widget>[];
      void add(bool on, NavigationDestination d, Widget p) {
        if (on) {
          ls.add(d);
          ps.add(p);
        }
      }

      add(ui.tabHome, _baseLabels[0], _basePages()[0]);
      add(true, _baseLabels[1], _basePages()[1]); // 应用 Tab 常驻
      // ★ v3.3.4：工具箱 Tab（ui_config.tabs.tools 控制，默认开）
      add(ui.tabTools, _baseLabels[2], _basePages()[2]);
      add(ui.tabSquare, _baseLabels[3], _basePages()[3]);
      add(ui.tabTips, _baseLabels[4], _basePages()[4]);
      // 即存 Tab:ui_config.jicun.enable 控制,默认显示。
      // Tab 名由后台 tab_name 下发,拉不到配置时按默认常开处理。
      var jicunOn = true;
      var jicunName = '即存';
      try {
        final j = cfg.jicunConfig;
        if (j != null) {
          jicunOn = j.enable;
          if (j.tabName.trim().isNotEmpty) jicunName = j.tabName.trim();
        }
      } catch (_) {}
      add(
        jicunOn,
        NavigationDestination(
          icon: const Icon(Icons.download_outlined),
          label: jicunName,
          selectedIcon: const Icon(Icons.download),
        ),
        _basePages()[5],
      );
      // 我的 Tab 固定在最后（即存之后）
      add(ui.tabMine, _baseLabels[6], _basePages()[6]);
      labels = ls;
      pages = ps;
      if (currentIndex >= ps.length) {
        currentIndex = 0;
        pageController.jumpToPage(0);
      }
      // 深浅模式由后台统一下发（后台允许用户自选时，保留用户的选择）
      final tc = ThemeController.instance;
      final respectUserTheme = ui.allowUserThemeToggle;
      if (!respectUserTheme) {
        await tc.setMode(switch (ui.themeMode) {
          'dark' => ThemeMode.dark,
          'system' => ThemeMode.system,
          _ => ThemeMode.light,
        });
      }
      tc.applyServerPalette(ui.themePalette);
      update(['navigate']);
    } catch (_) {}
  }

  PageController pageController = PageController();
  int currentIndex = 0;
  HttpApi httpApi = Get.find<HttpApi>();

  @override
  void onInit() {
    super.onInit();
    // v52j #2：App 从后台恢复时重新拉取并应用后台配置
    // （「退出软件重进」多数只是进程恢复，onReady 不会再跑）
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      applyUiConfig(force: true);
    }
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
    //请求权限
    _requestPermissionsOnStartup();
    // 应用后台「全局界面配置」
    applyUiConfig();
    // ★ 1016：启动时 tag=boot 上报早于登录态恢复 → user_id=0（显示"未登录"）。
    //   这里在应用启动完成后补一次归属上报，后台「启动数据」才能看到具体用户。
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        if (!UserService.instance.isLoggedIn) return;
        await SoftService.reportLogStatic(
          tag: 'boot_auth',
          error: '[boot_auth] 已登录用户启动',
        );
      } catch (_) {}
    });
    //检查更新（v52：独立 UpdateFlow，带进度条）
    UpdateFlow.check();
  }

  /// ★ v3.3.4：按语义跳转 —— Tab 数量随后台配置变化（可能有工具箱/即存），
  ///   硬编码索引极易出错，这里统一按「相对位置」定位。
  ///
  /// 我的 Tab 恒为最后一个；签到等入口都属于「我的」页。
  void goMine() {
    if (pages.isEmpty) return;
    changePage(pages.length - 1);
  }

  /// 即存 Tab（若开启）—— 恒为「我的」之前一个
  void goJicun() {
    if (pages.length < 2) return;
    changePage(pages.length - 2);
  }

  /// 工具 Tab（若开启）—— 恒为第 3 个（首页/应用/工具/…）
  void goTools() {
    if (pages.length < 3) return;
    changePage(2);
  }

  /// 切换页面
  void changePage(int index) {
    currentIndex = index;
    pageController.jumpToPage(index);
    update(['navigate']);
  }

  /// 权限请求
  Future<void> _requestPermissionsOnStartup() async {
    final _pc = SafeCtx.of();
    if (_pc != null) await PermissionUtils.requestAppPermissions(_pc);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
