import 'package:flutter/material.dart';

import '../../utils/apk_installer.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'dart:async';

import 'package:flutter_softlib/app/http/http_api.dart';
import 'package:flutter_softlib/app/pages/navigate/app/app_component.dart';
import 'package:flutter_softlib/app/pages/navigate/home/home_component.dart';
import 'package:flutter_softlib/app/pages/navigate/tips/tips_component.dart';
import 'package:flutter_softlib/app/pages/navigate/square/square_component.dart';
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
      icon: Icon(Icons.person_outline),
      label: '我的',
      selectedIcon: Icon(Icons.person),
    ),
    NavigationDestination(
      icon: Icon(Icons.download_outlined),
      label: '即存',
      selectedIcon: Icon(Icons.download),
    ),
  ];
  static List<Widget> _basePages() => [
    HomeComponent(),
    AppComponent(),
    SquareComponent(),
    TipsComponent(),
    MineComponent(),
    JicunPage(),
  ];

  List<NavigationDestination> labels = [
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
      icon: Icon(Icons.person_outline),
      label: '我的',
      selectedIcon: Icon(Icons.person),
    ),
  ];
  List<Widget> pages = [
    HomeComponent(),
    AppComponent(),
    SquareComponent(),
    TipsComponent(),
    MineComponent(),
  ];

  /// 按后台配置裁剪 Tab（工具Tab已整体移除）
  Future<void> applyUiConfig({bool force = false}) async {
    try {
      final cfg = await SoftService.instance.fetchConfig(force: force);
      if (cfg == null) return; // 拉不到配置绝不覆盖当前状态
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
      add(ui.tabSquare, _baseLabels[2], _basePages()[2]);
      add(ui.tabTips, _baseLabels[3], _basePages()[3]);
      add(ui.tabMine, _baseLabels[4], _basePages()[4]);
      // 即存 Tab(第 5 个):ui_config.jicun.enable 控制,默认显示。
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
      labels = ls;
      pages = ps;
      if (currentIndex >= ps.length) {
        currentIndex = 0;
        pageController.jumpToPage(0);
      }
      // 深浅模式由后台统一下发
      final tc = ThemeController.instance;
      final m = switch (ui.themeMode) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
      await tc.setMode(m);
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
    //检查更新（v52：独立 UpdateFlow，带进度条）
    UpdateFlow.check();
  }

  /// 切换页面
  void changePage(int index) {
    currentIndex = index;
    pageController.jumpToPage(index);
    update(['navigate']);
  }

  /// 权限请求
  Future<void> _requestPermissionsOnStartup() async {
    await PermissionUtils.requestAppPermissions(Get.context!);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
