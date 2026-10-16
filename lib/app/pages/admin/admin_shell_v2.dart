import 'package:flutter/material.dart';

import '../../design/adaptive.dart';
import '../../design/ui.dart';
import 'admin_ui_kit.dart';

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：管理后台 · 新外壳（商业化仪表盘风）
///
/// 相比旧壳（12 个胶囊挤一行）的改进：
///   · 顶部信息条：标题 + 实时状态点 + 刷新
///   · 导航按**分组**排列（数据 / 内容 / 运营 / 系统），横向滚动，带图标
///   · 当前页高亮更明显（渐变 + 阴影 + 指示条）
///   · 内容区统一留白与分隔
///
/// 功能不变：仍是那 12 个子页，只换外观与导航。
/// ═══════════════════════════════════════════════════════════════
class AdminShellV2 extends StatefulWidget {
  const AdminShellV2({
    super.key,
    required this.tab,
    required this.children,
    required this.onRefresh,
    this.templateName = '',
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

  /// (标签, 图标, 分组)
  static const _items = <(String, IconData, String)>[
    ('概览', Icons.dashboard_rounded, '数据'),
    ('软件', Icons.apps_rounded, '数据'),
    ('用户', Icons.people_alt_rounded, '数据'),
    ('订单', Icons.receipt_long_rounded, '数据'),
    ('内容', Icons.article_rounded, '内容'),
    ('工具', Icons.widgets_rounded, '内容'),
    ('采集', Icons.cloud_download_rounded, '运营'),
    ('解析', Icons.link_rounded, '运营'),
    ('界面', Icons.palette_rounded, '系统'),
    ('配置', Icons.tune_rounded, '系统'),
    ('安全', Icons.shield_rounded, '系统'),
    ('日志', Icons.history_rounded, '系统'),
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

  @override
  Widget build(BuildContext context) {
    final cur = _i >= 0 && _i < _items.length ? _items[_i] : _items[0];
    return Scaffold(
      backgroundColor: context.isDark
          ? const Color(0xFF12141B)
          : const Color(0xFFF5F6FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(cur.$1, cur.$3),
            _navBar(),
            Expanded(
              child: IndexedStack(index: _i, children: widget.children),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部信息条
  Widget _header(String title, String group) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 12, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '管理后台',
                      style: Ty.h1.copyWith(fontSize: 21, color: context.t1),
                    ),
                    const SizedBox(width: 9),
                    AdTag(text: title, color: C.brand),
                  ],
                ),
                const SizedBox(height: 3),
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
                      '$group · 服务正常',
                      style: Ty.tiny.copyWith(
                        fontSize: 10.5,
                        color: context.t3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
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
          ),
        ],
      ),
    );
  }

  /// 分组导航（横向滚动）
  Widget _navBar() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final it = _items[i];
          final on = i == _i;
          return GestureDetector(
            onTap: () {
              widget.tab.animateTo(i);
              setState(() => _i = i);
            },
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
                  Icon(it.$2, size: 15, color: on ? Colors.white : context.t2),
                  const SizedBox(width: 6),
                  Text(
                    it.$1,
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
        },
      ),
    );
  }
}
