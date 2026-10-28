import 'package:flutter/material.dart';

import '../../design/adaptive.dart';
import '../../design/ui.dart';
import '../../design/app_anim.dart';
import 'admin_save_bus.dart';
import 'admin_ui_kit.dart';
import 'admin_preview.dart';

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：管理后台外壳 · 5 套**真实架构差异**模板（不是换色）
///
///   light_card   顶部横向胶囊导航 + 卡片内容（默认，平衡）
///   dark_console 深色控制台：**左侧竖排导航栏（永久可见）** + 右侧内容
///   minimal      极简：顶部**纯文字标签 + 下划线指示**，大留白，无卡片边框
///   brand        品牌沉浸：**底部 TabBar** 导航（与顶部完全不同的动线）
///   desk         桌面风：**两列宫格导航**（图标方格铺开）+ 内容下移
///
/// 共同点：都用同一套 Ad* 设计组件渲染内容，所以数据展示一致；
///        差异在**导航位置/形态/信息架构**，属于骨架级不同。
/// ═══════════════════════════════════════════════════════════════
class AdminShellV2 extends StatefulWidget {
  const AdminShellV2({
    super.key,
    required this.tab,
    required this.children,
    required this.onRefresh,
    this.templateName = 'light_card',
  });

  final TabController tab;
  final List<Widget> children;
  final VoidCallback onRefresh;
  final String templateName;

  @override
  State<AdminShellV2> createState() => _AdminShellV2State();
}

class _AdminShellV2State extends State<AdminShellV2> {
  int _i = 0;

  static const _items = <(String, IconData, String)>[
    // ★★ 必须与 admin_page.dart 的 children 顺序**逐一对齐**！
    //    之前顺序写错（内容/工具/采集/解析 位置颠倒）→ 点「内容」显示的是采集页。
    //    children 实际顺序：概览 软件 用户 订单 采集 内容 界面 日志 配置 安全 解析 工具
    ('概览', Icons.dashboard_rounded, '数据'),
    ('软件', Icons.apps_rounded, '数据'),
    ('用户', Icons.people_alt_rounded, '数据'),
    ('订单', Icons.receipt_long_rounded, '数据'),
    ('采集', Icons.cloud_download_rounded, '运营'),
    ('内容', Icons.article_rounded, '内容'),
    ('界面', Icons.palette_rounded, '系统'),
    ('日志', Icons.history_rounded, '系统'),
    ('配置', Icons.tune_rounded, '系统'),
    ('安全', Icons.shield_rounded, '系统'),
    ('解析', Icons.link_rounded, '运营'),
    ('工具', Icons.widgets_rounded, '内容'),
  ];

  @override
  void initState() {
    super.initState();
    _i = widget.tab.index;
    widget.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (!mounted) return;
    if (_i != widget.tab.index) setState(() => _i = widget.tab.index);
  }

  void _go(int i) {
    widget.tab.animateTo(i);
    setState(() => _i = i);
  }

  String get _tpl {
    final t = widget.templateName;
    const known = ['light_card', 'dark_console', 'minimal', 'brand', 'desk'];
    return known.contains(t) ? t : 'light_card';
  }

  bool get _isDarkTpl => _tpl == 'dark_console';

  Color get _bg {
    if (_isDarkTpl) return const Color(0xFF0E1015);
    return context.isDark ? const Color(0xFF12141B) : const Color(0xFFF5F6FA);
  }

  @override
  Widget build(BuildContext context) {
    final cur = _i >= 0 && _i < _items.length ? _items[_i] : _items[0];
    final body = IndexedStack(index: _i, children: widget.children);

    // ── 按模板切换**骨架结构** ──
    final shell = switch (_tpl) {
      'dark_console' => _darkConsole(body, cur),
      'minimal' => _minimal(body, cur),
      'brand' => _brand(body, cur),
      'desk' => _desk(body, cur),
      _ => _lightCard(body, cur),
    };
    // ★ 1016：链接预览入口（悬浮按钮，5 套模板都可用）
    return Stack(
      children: [
        shell,
        Positioned(
          right: 14,
          bottom: 90,
          child: GestureDetector(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              showDragHandle: false,
              builder: (_) => const AdminLinkPreviewSheet(),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: C.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: C.brand.withAlpha(90),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.visibility_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ① light_card —— 顶部横向胶囊导航
  // ═══════════════════════════════════════════════════════════
  Widget _lightCard(Widget body, (String, IconData, String) cur) {
    return Scaffold(
      backgroundColor: _bg,
      // ★ 1020：改为监听 visible（当前页有没有登记保存），
      //   避免切到别的 Tab 后仍显示上一页的保存按钮、点下去执行错页面的保存。
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: AdminSaveBus.visible,
        builder: (_, show, __) {
          if (!show) return const SizedBox.shrink();
          return ValueListenableBuilder<bool>(
            valueListenable: AdminSaveBus.saving,
            builder: (_, busy, __) => FloatingActionButton.extended(
              heroTag: null,
              onPressed: busy ? null : AdminSaveBus.run,
              backgroundColor: C.brand,
              foregroundColor: Colors.white,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(busy ? '保存中' : '保存'),
            ),
          );
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(context.pagePadding, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(child: _titleBlock(cur, '管理后台')),
                  _refreshBtn(),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (_, i) => _pill(i),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ② dark_console —— 左侧竖排导航（永久可见）+ 右侧内容
  // ═══════════════════════════════════════════════════════════
  Widget _darkConsole(Widget body, (String, IconData, String) cur) {
    return Scaffold(
      backgroundColor: _bg,
      // ★ 1020：改为监听 visible（当前页有没有登记保存），
      //   避免切到别的 Tab 后仍显示上一页的保存按钮、点下去执行错页面的保存。
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: AdminSaveBus.visible,
        builder: (_, show, __) {
          if (!show) return const SizedBox.shrink();
          return ValueListenableBuilder<bool>(
            valueListenable: AdminSaveBus.saving,
            builder: (_, busy, __) => FloatingActionButton.extended(
              heroTag: null,
              onPressed: busy ? null : AdminSaveBus.run,
              backgroundColor: C.brand,
              foregroundColor: Colors.white,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(busy ? '保存中' : '保存'),
            ),
          );
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 左侧栏：图标 + 文字竖排
            Container(
              width: 62,
              decoration: BoxDecoration(
                color: const Color(0xFF151822),
                border: Border(
                  right: BorderSide(color: Colors.white.withAlpha(16)),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: C.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final on = i == _i;
                        return AppPressable(
                          onTap: () => _go(i),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: on ? C.brandGradient : null,
                              color: on ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _items[i].$2,
                                  size: 18,
                                  color: on
                                      ? Colors.white
                                      : Colors.white.withAlpha(150),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _items[i].$1,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: on
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: on
                                        ? Colors.white
                                        : Colors.white.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  AppPressable(
                    onTap: widget.onRefresh,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14, top: 6),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 19,
                        color: Colors.white.withAlpha(150),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 右侧内容
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cur.$1,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '管理后台 · ${cur.$3}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white.withAlpha(130),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ③ minimal —— 纯文字标签 + 下划线指示，大留白
  // ═══════════════════════════════════════════════════════════
  Widget _minimal(Widget body, (String, IconData, String) cur) {
    return Scaffold(
      backgroundColor: _bg,
      // ★ 1020：改为监听 visible（当前页有没有登记保存），
      //   避免切到别的 Tab 后仍显示上一页的保存按钮、点下去执行错页面的保存。
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: AdminSaveBus.visible,
        builder: (_, show, __) {
          if (!show) return const SizedBox.shrink();
          return ValueListenableBuilder<bool>(
            valueListenable: AdminSaveBus.saving,
            builder: (_, busy, __) => FloatingActionButton.extended(
              heroTag: null,
              onPressed: busy ? null : AdminSaveBus.run,
              backgroundColor: C.brand,
              foregroundColor: Colors.white,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(busy ? '保存中' : '保存'),
            ),
          );
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(context.pagePadding, 14, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cur.$1,
                      style: Ty.h1.copyWith(fontSize: 22, color: context.t1),
                    ),
                  ),
                  _refreshBtn(),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 18),
                itemBuilder: (_, i) {
                  final on = i == _i;
                  return AppPressable(
                    onTap: () => _go(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _items[i].$1,
                          style: Ty.small.copyWith(
                            fontSize: 13,
                            fontWeight: on ? FontWeight.w900 : FontWeight.w500,
                            color: on ? context.t1 : context.t3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: on ? 18 : 0,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: C.brand,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: Ad.stroke(context)),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ④ brand —— 品牌渐变顶栏 + **底部导航**（不同动线）
  // ═══════════════════════════════════════════════════════════
  Widget _brand(Widget body, (String, IconData, String) cur) {
    return Scaffold(
      backgroundColor: _bg,
      // ★ 1020：改为监听 visible（当前页有没有登记保存），
      //   避免切到别的 Tab 后仍显示上一页的保存按钮、点下去执行错页面的保存。
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: AdminSaveBus.visible,
        builder: (_, show, __) {
          if (!show) return const SizedBox.shrink();
          return ValueListenableBuilder<bool>(
            valueListenable: AdminSaveBus.saving,
            builder: (_, busy, __) => FloatingActionButton.extended(
              heroTag: null,
              onPressed: busy ? null : AdminSaveBus.run,
              backgroundColor: C.brand,
              foregroundColor: Colors.white,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(busy ? '保存中' : '保存'),
            ),
          );
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 品牌渐变头
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                14,
                context.pagePadding,
                12,
              ),
              decoration: BoxDecoration(gradient: C.brandGradient),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '管理后台',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cur.$1,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppPressable(
                    onTap: widget.onRefresh,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
            // 底部导航（只放常用的 6 个 + 更多）
            Container(
              decoration: BoxDecoration(
                color: Ad.cardBg(context),
                border: Border(top: BorderSide(color: Ad.stroke(context))),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      for (int i = 0; i < 5; i++)
                        Expanded(child: _bottomItem(i, cur)),
                      Expanded(child: _moreItem(cur)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomItem(int i, (String, IconData, String) cur) {
    final on = i == _i;
    return AppPressable(
      onTap: () => _go(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_items[i].$2, size: 19, color: on ? C.brand : context.t3),
          const SizedBox(height: 2),
          Text(
            _items[i].$1,
            style: Ty.tiny.copyWith(
              fontSize: 9.5,
              fontWeight: on ? FontWeight.w800 : FontWeight.w500,
              color: on ? C.brand : context.t3,
            ),
          ),
        ],
      ),
    );
  }

  /// 「更多」：弹出全部 12 项（底部导航的补充动线）
  Widget _moreItem((String, IconData, String) cur) {
    final inMore = _i >= 5;
    return AppPressable(
      onTap: _showMoreSheet,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            inMore ? _items[_i].$2 : Icons.more_horiz_rounded,
            size: 19,
            color: inMore ? C.brand : context.t3,
          ),
          const SizedBox(height: 2),
          Text(
            inMore ? _items[_i].$1 : '更多',
            style: Ty.tiny.copyWith(
              fontSize: 9.5,
              fontWeight: inMore ? FontWeight.w800 : FontWeight.w500,
              color: inMore ? C.brand : context.t3,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Ad.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('全部功能', style: Ty.h3.copyWith(color: context.t1)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (int i = 5; i < _items.length; i++)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(c);
                        _go(i);
                      },
                      child: Container(
                        width: (MediaQuery.of(context).size.width - 62) / 3,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _i == i
                              ? C.brand.withAlpha(30)
                              : Ad.stroke(context),
                          borderRadius: BorderRadius.circular(Ad.rItem),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _items[i].$2,
                              size: 20,
                              color: _i == i ? C.brand : context.t2,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _items[i].$1,
                              style: Ty.tiny.copyWith(
                                fontSize: 11.5,
                                color: _i == i ? C.brand : context.t2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⑤ desk —— 两列宫格导航（图标方格铺开）+ 内容下移
  // ═══════════════════════════════════════════════════════════
  Widget _desk(Widget body, (String, IconData, String) cur) {
    return Scaffold(
      backgroundColor: _bg,
      // ★ 1020：改为监听 visible（当前页有没有登记保存），
      //   避免切到别的 Tab 后仍显示上一页的保存按钮、点下去执行错页面的保存。
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: AdminSaveBus.visible,
        builder: (_, show, __) {
          if (!show) return const SizedBox.shrink();
          return ValueListenableBuilder<bool>(
            valueListenable: AdminSaveBus.saving,
            builder: (_, busy, __) => FloatingActionButton.extended(
              heroTag: null,
              onPressed: busy ? null : AdminSaveBus.run,
              backgroundColor: C.brand,
              foregroundColor: Colors.white,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(busy ? '保存中' : '保存'),
            ),
          );
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(context.pagePadding, 12, 12, 2),
              child: Row(
                children: [
                  Expanded(child: _titleBlock(cur, '管理后台 · 桌面')),
                  _refreshBtn(),
                ],
              ),
            ),
            // 宫格导航（6 列 × 2 行，图标方格）
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
              child: GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
                childAspectRatio: 0.86,
                children: [
                  for (int i = 0; i < _items.length; i++)
                    AppPressable(
                      onTap: () => _go(i),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _i == i ? C.brandGradient : null,
                          color: _i == i ? null : Ad.cardBg(context),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: _i == i
                                ? Colors.transparent
                                : Ad.stroke(context),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _items[i].$2,
                              size: 15,
                              color: _i == i ? Colors.white : context.t2,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _items[i].$1,
                              style: Ty.tiny.copyWith(
                                fontSize: 9,
                                fontWeight: _i == i
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: _i == i ? Colors.white : context.t3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: Ad.stroke(context)),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 公共小组件
  // ═══════════════════════════════════════════════════════════
  Widget _titleBlock((String, IconData, String) cur, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(sub, style: Ty.h1.copyWith(fontSize: 20, color: context.t1)),
            const SizedBox(width: 8),
            AdTag(text: cur.$1, color: C.brand),
          ],
        ),
        const SizedBox(height: 2),
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
              '${cur.$3} · 服务正常',
              style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _refreshBtn() => AppPressable(
    onTap: widget.onRefresh,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Ad.cardBg(context),
        shape: BoxShape.circle,
        border: Border.all(color: Ad.stroke(context)),
      ),
      child: Icon(Icons.refresh_rounded, size: 18, color: context.t2),
    ),
  );

  Widget _pill(int i) {
    final on = i == _i;
    return AppPressable(
      onTap: () => _go(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: on ? C.brandGradient : null,
          color: on ? null : Ad.cardBg(context),
          borderRadius: BorderRadius.circular(Ad.rChip),
          border: Border.all(
            color: on ? Colors.transparent : Ad.stroke(context),
          ),
        ),
        child: Row(
          children: [
            Icon(_items[i].$2, size: 15, color: on ? Colors.white : context.t2),
            const SizedBox(width: 6),
            Text(
              _items[i].$1,
              style: Ty.tiny.copyWith(
                fontSize: 12.5,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: on ? Colors.white : context.t2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
