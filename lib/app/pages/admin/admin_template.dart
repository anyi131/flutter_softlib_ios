import 'dart:ui';

import 'package:flutter/material.dart';

import '../../api/soft_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// 管理后台整体界面模板（v54）：5 套骨架
///
/// 由 ui_config.admin_template 下发，「界面」Tab 页头可热切换：
///   light_card   —— 现有浅色卡片（渐变头部 + 玻璃胶囊 Tab 条）
///   dark_console —— 暗色控制台（强制深色、等宽点缀、终端绿高亮、描边卡）
///   minimal      —— 去卡片纯排版 + 细分隔线（文字 Tab 下划线）
///   brand        —— 品牌渐变头部 + 彩色图标底（活泼风）
///   desk         —— 桌面工作台（宽屏左侧图标栏 + 右侧内容，窄屏退化顶部横条）
/// ═══════════════════════════════════════════════════════════════

/// 热切换通知（「界面」Tab 保存后置为新值，AdminPage 监听重建）
final ValueNotifier<String> adminTemplateNotifier = ValueNotifier('light_card');

String get adminTemplateCurrent =>
    SoftService.instance.cachedConfig?.uiConfig.adminTemplate ?? 'light_card';

class AdminTemplateShell extends StatelessWidget {
  const AdminTemplateShell({
    super.key,
    required this.tab,
    required this.onRefresh,
    required this.children,
  });

  final TabController tab;
  final VoidCallback onRefresh;
  final List<Widget> children;

  static const _tabItems = [
    (Icons.dashboard_rounded, '概览'),
    (Icons.apps_rounded, '软件'),
    (Icons.people_rounded, '用户'),
    (Icons.receipt_long_rounded, '订单'),
    (Icons.cloud_download_rounded, '采集'),
    (Icons.article_rounded, '内容'),
    (Icons.palette_rounded, '界面'),
    (Icons.history_rounded, '日志'),
    (Icons.settings_rounded, '配置'),
    (Icons.security_rounded, '安全'),
  ];

  @override
  Widget build(BuildContext context) {
    final tpl = adminTemplateNotifier.value;
    switch (tpl) {
      case 'dark_console':
        return _darkConsole(context);
      case 'minimal':
        return _minimal(context);
      case 'brand':
        return _brand(context);
      case 'desk':
        return _desk(context);
      default:
        return _lightCard(context);
    }
  }

  // ─────────── light_card：现有布局 ───────────
  Widget _lightCard(BuildContext context) => _shell(
    context,
    bg: Deco.pageBackground(context),
    header: _headerLight(context),
    tabBar: _tabBarPills(context),
  );

  Widget _shell(
    BuildContext context, {
    required Widget bg,
    required Widget header,
    required Widget tabBar,
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          bg,
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                header,
                tabBar,
                Expanded(child: _views()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _views() => TabBarView(controller: tab, children: children);

  Widget _headerLight(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(context.pagePadding, 12, 12, 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (r) => Deco.aurora().createShader(r),
                child: Text(
                  '管理后台',
                  style: Ty.display.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: C.mint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '全局配置/界面/采集/经营 · 模板：浅色卡片',
                    style: Ty.small.copyWith(color: context.t3),
                  ),
                ],
              ),
            ],
          ),
        ),
        _roundBtn(context, Icons.refresh_rounded, onRefresh),
      ],
    ),
  );

  Widget _roundBtn(BuildContext context, IconData i, VoidCallback f) =>
      GestureDetector(
        onTap: f,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withAlpha(12) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.isDark
                  ? Colors.white.withAlpha(20)
                  : Colors.black.withAlpha(8),
            ),
          ),
          child: Icon(i, size: 19, color: context.t2),
        ),
      );

  Widget _tabBarPills(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          10,
          context.pagePadding,
          6,
        ),
        itemCount: _tabItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sel = tab.index == i;
          return GestureDetector(
            onTap: () => onTab(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel ? Deco.brandGradient : null,
                color: sel
                    ? null
                    : (context.isDark
                          ? Colors.white.withAlpha(12)
                          : Colors.white),
                borderRadius: BorderRadius.circular(R.full),
                border: Border.all(
                  color: sel
                      ? Colors.transparent
                      : (context.isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(8)),
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: C.brand.withAlpha(70),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _tabItems[i].$1,
                    size: 16,
                    color: sel ? Colors.white : context.t3,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _tabItems[i].$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : context.t2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void onTab(int i) => tab.animateTo(i);

  // ─────────── dark_console：暗色控制台 ───────────
  Widget _darkConsole(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF34D399),
          onPrimary: Color(0xFF04140C),
          surface: Color(0xFF0B0F14),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        fontFamilyFallback: const ['Menlo', 'monospace'],
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 终端风头部
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10161E),
                  borderRadius: BorderRadius.circular(R.md),
                  border: Border.all(color: Colors.white.withAlpha(26)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'root@softlib:~# admin --console',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Menlo',
                      ),
                    ),
                    const Spacer(),
                    _conBtn(context, Icons.refresh_rounded, onRefresh),
                  ],
                ),
              ),
              // 终端绿高亮 Tab 条（描边卡）
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  itemCount: _tabItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final sel = tab.index == i;
                    return GestureDetector(
                      onTap: () => onTab(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF34D399).withAlpha(28)
                              : const Color(0xFF10161E),
                          borderRadius: BorderRadius.circular(R.sm),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF34D399)
                                : Colors.white.withAlpha(24),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: sel
                                    ? const Color(0xFF34D399)
                                    : Colors.white38,
                                fontFamily: 'Menlo',
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _tabItems[i].$2,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: sel
                                    ? const Color(0xFF34D399)
                                    : Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(child: _views()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conBtn(BuildContext context, IconData i, VoidCallback f) =>
      GestureDetector(
        onTap: f,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.xs),
            border: Border.all(color: Colors.white.withAlpha(26)),
          ),
          child: Icon(i, size: 16, color: const Color(0xFF34D399)),
        ),
      );

  // ─────────── minimal：纯排版 + 细分隔线 ───────────
  Widget _minimal(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(color: context.isDark ? C.bg0 : const Color(0xFFFAFAF8)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(context.pagePadding, 14, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '管理后台',
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: context.t1,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onRefresh,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 22,
                          color: context.t3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 细分隔线 + 文字 Tab（下划线）
                Container(
                  height: 1,
                  color: context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(18),
                ),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _tabItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 20),
                    itemBuilder: (context, i) {
                      final sel = tab.index == i;
                      return GestureDetector(
                        onTap: () => onTab(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _tabItems[i].$2,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: sel
                                    ? FontWeight.w900
                                    : FontWeight.w500,
                                color: sel ? context.t1 : context.t3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 18,
                              height: 2,
                              decoration: BoxDecoration(
                                color: sel ? context.t1 : Colors.transparent,
                                borderRadius: BorderRadius.circular(R.full),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  height: 1,
                  color: context.isDark
                      ? Colors.white.withAlpha(14)
                      : Colors.black.withAlpha(12),
                ),
                Expanded(child: _views()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── brand：品牌渐变头部 + 彩色图标底 ───────────
  Widget _brand(BuildContext context) {
    final colors = [
      C.brand,
      C.mint,
      C.gold,
      C.violet,
      C.cyan,
      C.pink,
      C.rose,
      C.success,
      C.warning,
      C.brand,
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 渐变头部块
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    gradient: Deco.brandGradient,
                    borderRadius: BorderRadius.circular(R.xl),
                    boxShadow: [
                      BoxShadow(
                        color: C.brand.withAlpha(90),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '管理后台',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '轻松经营 · 模板：品牌渐变',
                              style: Ty.small.copyWith(
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onRefresh,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(52),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 彩色图标底 Tab 条
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                    itemCount: _tabItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final sel = tab.index == i;
                      return GestureDetector(
                        onTap: () => onTab(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel
                                ? colors[i].withAlpha(26)
                                : context.isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(R.full),
                            border: Border.all(
                              color: sel
                                  ? colors[i].withAlpha(150)
                                  : (context.isDark
                                        ? Colors.white.withAlpha(18)
                                        : Colors.black.withAlpha(8)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: colors[i].withAlpha(
                                    context.isDark ? 44 : 30,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _tabItems[i].$1,
                                  size: 14,
                                  color: colors[i],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _tabItems[i].$2,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: sel ? colors[i] : context.t2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(child: _views()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── desk：左侧图标栏工作台（窄屏退化顶部横条） ───────────
  Widget _desk(BuildContext context) {
    final wide = context.isWide;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: wide
                ? Row(
                    children: [
                      // 左侧图标竖栏
                      Container(
                        width: 84,
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? Colors.white.withAlpha(10)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(R.xl),
                          border: Border.all(
                            color: context.isDark
                                ? Colors.white.withAlpha(18)
                                : Colors.black.withAlpha(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.workspaces_rounded,
                              size: 22,
                              color: C.brand,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '工作台',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: context.t2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                itemCount: _tabItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 2),
                                itemBuilder: (context, i) {
                                  final sel = tab.index == i;
                                  return GestureDetector(
                                    onTap: () => onTab(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: sel
                                            ? Deco.brandGradient
                                            : null,
                                        color: sel ? null : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          R.md,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            _tabItems[i].$1,
                                            size: 19,
                                            color: sel
                                                ? Colors.white
                                                : context.t3,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _tabItems[i].$2,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: sel
                                                  ? Colors.white
                                                  : context.t3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: onRefresh,
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: context.t3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: _views()),
                    ],
                  )
                : Column(
                    children: [
                      // 窄屏：顶部横向图标条
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                          itemCount: _tabItems.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final sel = tab.index == i;
                            return GestureDetector(
                              onTap: () => onTab(i),
                              child: Container(
                                width: 56,
                                decoration: BoxDecoration(
                                  gradient: sel ? Deco.brandGradient : null,
                                  color: sel
                                      ? null
                                      : (context.isDark
                                            ? Colors.white.withAlpha(10)
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(R.md),
                                  border: Border.all(
                                    color: sel
                                        ? Colors.transparent
                                        : (context.isDark
                                              ? Colors.white.withAlpha(18)
                                              : Colors.black.withAlpha(8)),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _tabItems[i].$1,
                                      size: 18,
                                      color: sel ? Colors.white : context.t3,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _tabItems[i].$2,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: sel ? Colors.white : context.t3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(child: _views()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
