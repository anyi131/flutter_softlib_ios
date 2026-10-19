import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design/adaptive.dart';
import '../../design/ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：管理后台 · 统一设计层（商业化仪表盘风）
///
/// 目标：把后台从「零散卡片堆叠」升级为统一的**数据仪表盘**观感：
///   · 统一圆角 / 留白 / 描边 / 字号层级
///   · 数据类组件（指标格、趋势条、榜单、时间线）
///   · 深浅色一体化（用 context.isDark，不再各页自己判断）
///
/// 使用方式：新页面直接用下面这些组件；老页面可逐步替换。
/// ═══════════════════════════════════════════════════════════════
import '../../design/glass_theme.dart';

class Ad {
  Ad._();

  /// 统一圆角
  static const double rCard = 18;
  static const double rItem = 13;
  static const double rChip = 999;

  /// 统一间距
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 18;

  /// 卡片底色
  ///
  /// ★ 1020：接入全局玻璃（GlassTheme）—— high/medium 档返回半透明底，
  ///   low/off 档与原来的实心色**完全一致**（保证低端机 / 关闭玻璃时零差异）。
  static Color cardBg(BuildContext c) => GlassTheme.cardColor(c);

  /// 卡片描边（玻璃档位下换成更亮的高光边）
  static Color stroke(BuildContext c) => GlassTheme.borderColor(c);
}

/// 统一卡片（商业化：细描边 + 极轻阴影，不用大阴影）
class AdCard extends StatelessWidget {
  const AdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.onTap,
    this.accent,

    /// 兼容旧组件参数（KitCard/GlassCard 的 glow/radius/blur/alpha）
    /// 这样后台页面可以安全地把 KitCard(...)/GlassCard(...) 直接换成 AdCard(...)
    this.glow,
    this.margin,
    this.radius = Ad.rCard,
    this.blur,
    this.alpha,

    /// 兼容旧组件：是否画强调描边（选中态）
    this.border = false,
  });

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? accent;
  final Color? glow;
  final EdgeInsets? margin;
  final double radius;
  final double? blur;
  final double? alpha;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final edge = GlassTheme.edgeGradient(context);
    Widget body = Container(
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Ad.cardBg(context),
        borderRadius: r,
        border: Border.all(
          width: border ? 1.6 : 1,
          color: border
              ? C.brand.withAlpha(context.isDark ? 150 : 120)
              : (accent ?? glow) != null
              ? (accent ?? glow)!.withAlpha(context.isDark ? 70 : 60)
              : Ad.stroke(context),
        ),
      ),
      child: child,
    );

    // ★ 1020 全局玻璃：只在「有内容可透」的档位加叠层
    //   high  → 真模糊（卡片数量多，只在旗舰机开，且由 GlassTheme 控制）
    //   medium→ 不模糊，只叠一层极淡的斜向高光渐变（视觉上是玻璃，性能近零）
    if (GlassTheme.enabled && edge != null) {
      body = ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            if (GlassTheme.cardBlur)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: GlassTheme.sigma,
                    sigmaY: GlassTheme.sigma,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            body,
            // 边缘折光（不吃点击）
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(borderRadius: r, gradient: edge),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null ? body : GestureDetector(onTap: onTap, child: body),
    );
  }
}

/// 分组标题（左侧色条 + 标题 + 说明 + 右侧操作）
class AdSection extends StatelessWidget {
  const AdSection({
    super.key,
    required this.title,
    this.subtitle,
    this.accent,
    this.trailing,

    /// 兼容旧 SectionHeader 的 action 参数
    this.action,
  });

  final String title;
  final String? subtitle;
  final Color? accent;
  final Widget? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? C.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: Ad.gapS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3.5,
            height: 15,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Ty.h3.copyWith(fontSize: 14.5, color: context.t1),
                ),
                if ((subtitle ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      style: Ty.tiny.copyWith(
                        fontSize: 10.5,
                        color: context.t3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 指标格（数值 + 标签 + 图标，可选迷你趋势条）
class AdMetric extends StatelessWidget {
  const AdMetric({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.icon,
    this.ratio,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  /// 0~1，给了就画一条迷你进度
  final double? ratio;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.brand;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 9 : 11,
      ),
      decoration: BoxDecoration(
        color: c.withAlpha(context.isDark ? 30 : 16),
        borderRadius: BorderRadius.circular(Ad.rItem),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 13 : 14, color: c),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.tiny.copyWith(
                    fontSize: compact ? 10 : 10.5,
                    color: context.t3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 16 : 19,
              fontWeight: FontWeight.w900,
              height: 1.05,
              color: c,
            ),
          ),
          if (ratio != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio!.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: c.withAlpha(40),
                valueColor: AlwaysStoppedAnimation<Color>(c),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 横向可滚动的一行指标格
class AdMetricRow extends StatelessWidget {
  const AdMetricRow({super.key, required this.items, this.perWidth = 108});

  final List<Widget> items;
  final double perWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Ad.gapS),
        itemBuilder: (_, i) => SizedBox(width: perWidth, child: items[i]),
      ),
    );
  }
}

/// 趋势条列表（日期 + 条 + 数值）
class AdTrendList extends StatelessWidget {
  const AdTrendList({
    super.key,
    required this.rows,
    this.barColor,
    this.valueSuffix = '',
  });

  /// (标签, 数值, 右侧文字)
  final List<(String, double, String)> rows;
  final Color? barColor;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text('暂无数据', style: Ty.tiny.copyWith(color: context.t3));
    }
    final maxV = rows.map((r) => r.$2).fold<double>(0, (a, b) => a > b ? a : b);
    final c = barColor ?? C.brand;
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    r.$1,
                    style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: maxV <= 0 ? 0 : (r.$2 / maxV).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: c.withAlpha(context.isDark ? 34 : 20),
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  width: 54,
                  child: Text(
                    r.$3,
                    textAlign: TextAlign.right,
                    style: Ty.tiny.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 榜单（名次 + 标题 + 右侧数值）
class AdRankList extends StatelessWidget {
  const AdRankList({super.key, required this.rows, this.accent});

  /// (标题, 右侧文字, 右侧附加文字)
  final List<(String, String, String)> rows;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text('暂无数据', style: Ty.tiny.copyWith(color: context.t3));
    }
    final c = accent ?? C.brand;
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? C.gold.withAlpha(context.isDark ? 52 : 40)
                        : c.withAlpha(context.isDark ? 34 : 22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: Ty.tiny.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: i == 0 ? C.gold : c,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.small.copyWith(fontSize: 12.5, color: context.t1),
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: Ty.tiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
                if (rows[i].$3.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    rows[i].$3,
                    style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// 键值对列表（详情弹窗/信息区块用）
class AdKvList extends StatelessWidget {
  const AdKvList({super.key, required this.rows, this.labelWidth = 64});

  final List<(String, String)> rows;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    r.$1,
                    style: Ty.tiny.copyWith(fontSize: 11.5, color: context.t3),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    r.$2.isEmpty ? '-' : r.$2,
                    style: Ty.small.copyWith(fontSize: 12.5, color: context.t1),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 空状态
class AdEmpty extends StatelessWidget {
  const AdEmpty({super.key, required this.text, this.hint = '', this.icon});

  final String text;
  final String hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(
            icon ?? Icons.inbox_rounded,
            size: 30,
            color: context.t3.withAlpha(140),
          ),
          const SizedBox(height: 8),
          Text(text, style: Ty.small.copyWith(color: context.t3)),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(hint, style: Ty.tiny.copyWith(color: context.t3)),
          ],
        ],
      ),
    );
  }
}

/// 小标签（状态/分类）
class AdTag extends StatelessWidget {
  const AdTag({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(context.isDark ? 44 : 24),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Ty.tiny.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: c,
        ),
      ),
    );
  }
}
