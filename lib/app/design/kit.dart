import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'ui.dart';
import 'glass.dart';
import 'glass_theme.dart';

/// ═══════════════════════════════════════════════════════════════
///  统一组件库（Design Kit）
///
///  目标：全 App 的按钮 / 卡片 / 标签 / 空态 / 加载 / 分区标题
///  只用这里的组件，杜绝各页面自己捏样式导致的不一致。
///
///  规则：
///   · 色值只用 C.*，圆角只用 R.*，排版只用 Ty.*
///   · 所有可点元素必须有按压反馈（InkWell/GestureDetector + 缩放）
/// ═══════════════════════════════════════════════════════════════

/// ─────────── 通用弹窗 ───────────
/// AlertDialog 的替代品：玻璃开 → 磨砂壳，玻璃关 → 实底卡，
/// 两种模式共用同一套排版，杜绝「内容裸浮在遮罩上 / 白底叠白底」。
/// 参数尽量对齐 AlertDialog，方便原地替换。
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.insetPadding,
    this.maxWidth = 380,
    this.titlePadding = const EdgeInsets.fromLTRB(20, 18, 20, 0),
    this.contentPadding = const EdgeInsets.fromLTRB(20, 14, 20, 0),
    this.actionsPadding = const EdgeInsets.fromLTRB(12, 8, 12, 10),
    this.actionsAlignment,
    // 以下参数只为兼容 AlertDialog 的调用写法，不生效
    this.shape,
    this.backgroundColor,
    this.elevation,
    this.scrollable = false,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsets? insetPadding;
  final double maxWidth;
  final EdgeInsets titlePadding;
  final EdgeInsets contentPadding;
  final EdgeInsets actionsPadding;
  final MainAxisAlignment? actionsAlignment;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final double? elevation;
  final bool scrollable;

  WrapAlignment get _wrapAlign {
    switch (actionsAlignment) {
      case MainAxisAlignment.start:
        return WrapAlignment.start;
      case MainAxisAlignment.center:
        return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween:
        return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround:
        return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly:
        return WrapAlignment.spaceEvenly;
      default:
        return WrapAlignment.end;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: titlePadding,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                height: 1.3,
                color: context.t1,
                decoration: TextDecoration.none,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: context.t2, size: 20),
                child: title!,
              ),
            ),
          ),
        if (content != null)
          Flexible(
            child: SingleChildScrollView(
              padding: contentPadding,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: context.t2,
                  decoration: TextDecoration.none,
                ),
                child: content!,
              ),
            ),
          ),
        if (actions != null && actions!.isNotEmpty)
          Padding(
            padding: actionsPadding,
            child: Wrap(
              alignment: _wrapAlign,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: actions!,
            ),
          ),
      ],
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          insetPadding ?? const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: PanelSurface(child: body),
      ),
    );
  }
}

/// ─────────── 主按钮 ───────────
/// 渐变胶囊 + 顶部内高光 + 光晕投影，图标带圆形半透明底。
/// 下载/安装/提交等「主行动」统一用它，靠 [color] 区分语义
/// （品牌蓝 / 成功绿 / 会员金），保证状态切换时视觉连续。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.gold = false,
    this.loading = false,
    this.height = 54,
    this.enabled = true,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool gold;
  final bool loading;
  final double height;
  final bool enabled;

  /// 是否占满可用宽度。
  /// ★ 放在 Row 里时必须设为 false —— 否则 width: infinity 会挤爆同行元素。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final _c = color ?? C.brand;
    final gradient = gold
        ? Deco.goldGradient
        : LinearGradient(
            colors: [
              Color.lerp(_c, Colors.white, 0.22)!,
              _c,
              Color.lerp(_c, Colors.black, 0.14)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final fg = gold ? const Color(0xFF3A2E10) : Colors.white;
    final active = enabled && !loading && onPressed != null;

    return Opacity(
      opacity: active ? 1 : 0.55,
      child: Container(
        width: expand ? double.infinity : null,
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(R.full),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: (gold ? C.gold : _c).withAlpha(
                      context.isDark ? 90 : 72,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(R.full),
          child: InkWell(
            onTap: active ? onPressed : null,
            borderRadius: BorderRadius.circular(R.full),
            splashColor: fg.withAlpha(30),
            child: Stack(
              children: [
                // 顶部内高光
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: height * 0.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(R.full),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withAlpha(gold ? 60 : 45),
                          Colors.white.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 18),
                  child: Center(
                    child: loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(fg),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: fg.withAlpha(38),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, size: 16, color: fg),
                                ),
                                const SizedBox(width: 9),
                              ],
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: fg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────── 次级按钮（描边/浅底） ───────────
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.height = 46,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final _c = color ?? C.brand;
    final child = Material(
      color: _c.withAlpha(context.isDark ? 34 : 22),
      borderRadius: BorderRadius.circular(R.full),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(R.full),
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 18),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: _c),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// ─────────── 小圆角操作（进度条上的暂停/取消等） ───────────
class MiniAction extends StatelessWidget {
  const MiniAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final _c = color ?? C.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: _c.withAlpha(context.isDark ? 40 : 24),
          borderRadius: BorderRadius.circular(R.full),
          border: Border.all(color: _c.withAlpha(70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _c),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────── 卡片 ───────────
/// 统一卡片：白/深色底 + 大圆角 + 轻描边 + 柔和阴影，可按压。
class KitCard extends StatelessWidget {
  const KitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.radius = R.lg,
    this.onTap,
    this.gradient,
    this.border = true,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final r = BorderRadius.circular(radius);
    // ★ 1020 全局玻璃：high/medium 档用半透明底 + 高光边；
    //   low/off 档等价于原来的实心卡（零差异，低端机不受影响）。
    //   自定义 gradient 的卡片保持原样，避免破坏会员卡那种彩色卡面。
    final glass = GlassTheme.enabled && gradient == null;
    Widget c = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? (glass ? GlassTheme.edgeGradient(context) : null),
        color: gradient != null
            ? null
            : (glass
                  ? GlassTheme.cardColor(context)
                  : (isDark ? C.bg2 : Colors.white)),
        borderRadius: r,
        border: border
            ? Border.all(
                color: glass
                    ? GlassTheme.borderColor(context)
                    : (isDark
                          ? Colors.white.withAlpha(16)
                          : Colors.black.withAlpha(8)),
                width: glass ? 1.0 : 0.8,
              )
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2C3550).withAlpha(glass ? 10 : 14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
    // 仅 high 档给卡片加真模糊（medium 只做半透明，保证列表滑动的帧率）
    if (glass && GlassTheme.cardBlur) {
      c = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassTheme.sigma,
            sigmaY: GlassTheme.sigma,
          ),
          child: c,
        ),
      );
    }
    if (onTap != null) {
      c = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: c,
        ),
      );
    }
    if (margin != null) c = Padding(padding: margin!, child: c);
    return c;
  }
}

/// ─────────── 玻璃卡片 ───────────
/// 半透明 + 背景模糊 + 细描边，用于需要「浮在光晕上」的高级质感场景
/// （后台概览、会员页等）。普通内容卡用 [KitCard] 即可。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.radius = R.lg,
    this.blur = 18,
    this.alpha = 0.06,
    this.onTap,
    this.glow,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double radius;
  final double blur;
  final double alpha;
  final VoidCallback? onTap;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    // ★ 1016：后台页面统一改用「商业化卡片」样式 ——
    //   原来的 Deco.glass 带 22px 大阴影 + 光晕，多个卡片叠在一起显得脏；
    //   新样式：细描边 + 极轻阴影 + 统一底色，观感干净、成组时有层次。
    //   （GlassCard 只有后台页面在用，所以这里是安全的全量升级）
    final isDark = context.isDark;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glow != null
              ? glow!.withAlpha(isDark ? 70 : 60)
              : (isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(12)),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2C3550).withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: onTap == null
            ? child
            : GestureDetector(onTap: onTap, child: child),
      ),
    );
  }

  Widget _legacyGlass(BuildContext context) {
    return Deco.glass(
      context,
      radius: radius,
      blur: blur,
      alpha: alpha,
      padding: padding,
      margin: margin,
      onTap: onTap,
      glow: glow,
      child: child,
    );
  }
}

/// ─────────── 标签 ───────────
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.color,
    this.icon,
    this.solid = false,
    this.small = false,
  });

  final String text;
  final Color? color;
  final IconData? icon;
  final bool solid;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final _c = color ?? C.brand;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 9,
        vertical: small ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: solid ? _c : _c.withAlpha(context.isDark ? 40 : 24),
        borderRadius: BorderRadius.circular(R.full),
        border: solid ? null : Border.all(color: _c.withAlpha(66), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: small ? 10 : 11.5,
              color: solid ? Colors.white : _c,
            ),
            const SizedBox(width: 3),
          ],
          // ★ 弹性 + 省略号：防止长文本（如用户自定义头衔）撑破父级 Row
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: small ? 10 : 11.5,
                fontWeight: FontWeight.w800,
                color: solid ? Colors.white : _c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────── 分区标题 ───────────
/// 左侧竖条 + 标题 + 可选副标题 / 右侧动作
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final _c = accent ?? C.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: subtitle == null ? 16 : 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_c, _c.withAlpha(90)],
              ),
              borderRadius: BorderRadius.circular(R.full),
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Ty.h2.copyWith(color: context.t1)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Ty.tiny.copyWith(color: context.t3)),
              ],
            ],
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// ─────────── 空态 ───────────
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.text = '暂无数据',
    this.hint,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String text;
  final String? hint;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.brand.withAlpha(context.isDark ? 30 : 16),
              ),
              child: Icon(icon, size: 34, color: C.brand.withAlpha(180)),
            ),
            const SizedBox(height: 16),
            Text(text, style: Ty.h3.copyWith(color: context.t2)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: Ty.small.copyWith(color: context.t3),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// ─────────── 错误态 ───────────
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.text = '加载失败',
    this.hint = '请检查网络后重试',
    this.onRetry,
  });

  final String text;
  final String? hint;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      text: text,
      hint: hint,
      icon: Icons.cloud_off_rounded,
      action: onRetry == null
          ? null
          : SoftButton(
              label: '重试',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
    );
  }
}

/// ─────────── 加载态（首屏） ───────────
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (text != null) ...[
            const SizedBox(height: 14),
            Text(text!, style: Ty.small.copyWith(color: context.t3)),
          ],
        ],
      ),
    );
  }
}

/// ─────────── 骨架屏 ───────────
/// 流光扫过的占位块，用于列表/详情首屏，替代生硬的转圈。
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = R.sm,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.isDark
        ? Colors.white.withAlpha(14)
        : Colors.black.withAlpha(10);
    final shine = context.isDark
        ? Colors.white.withAlpha(30)
        : Colors.white.withAlpha(180);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final x = _c.value * 2 - 1; // -1 → 1
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: [base, shine, base],
            ),
          ),
        );
      },
    );
  }
}

/// 列表骨架（卡片形）
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => KitCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Skeleton(width: 54, height: 54, radius: R.md),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: 150, height: 15),
                  SizedBox(height: 9),
                  Skeleton(width: 220, height: 12),
                  SizedBox(height: 9),
                  Skeleton(width: 110, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────── 进度条 ───────────
class KitProgress extends StatelessWidget {
  const KitProgress({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value; // 0..1
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final _c = color ?? C.brand;
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.full),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: context.isDark
            ? Colors.white.withAlpha(24)
            : Colors.black12,
        valueColor: AlwaysStoppedAnimation<Color>(_c),
      ),
    );
  }
}

/// ─────────── 统计四宫格（详情页数据条） ───────────
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.items});

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 26,
              color: context.isDark
                  ? Colors.white.withAlpha(14)
                  : Colors.black.withAlpha(8),
            ),
          Expanded(child: items[i]),
        ],
      ],
    );
  }
}

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final _c = color ?? C.brand;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Ty.h3.copyWith(fontSize: 16, color: _c ?? context.t1),
        ),
        const SizedBox(height: 3),
        Text(label, style: Ty.tiny.copyWith(color: context.t3)),
      ],
    );
  }
}

/// ─────────── 统一网络图片 ───────────
/// 统一「占位 → 淡入 → 失败兜底」三段式，避免各页面各写一套
/// 导致加载闪烁 / 失败白块。
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = R.md,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
    this.errorIcon = Icons.broken_image_outlined,
    this.bg,
  });

  final String url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final IconData placeholderIcon;
  final IconData errorIcon;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final fallbackBg =
        bg ??
        (context.isDark
            ? Colors.white.withAlpha(12)
            : Colors.black.withAlpha(8));
    Widget fallback(IconData icon) => Container(
      width: width,
      height: height,
      color: fallbackBg,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: (width != null && width! < 40) ? 14 : 22,
        color: context.t3.withAlpha(150),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.trim().isEmpty
          ? fallback(errorIcon)
          : CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: fit,
              fadeInDuration: const Duration(milliseconds: 200),
              // ★ 按实际显示尺寸解码：避免把 2000px 原图整张解到内存
              //   （列表大量图片时这是内存与掉帧的主要来源）
              memCacheWidth: width != null
                  ? (width! * MediaQuery.of(context).devicePixelRatio)
                        .round()
                        .clamp(64, 1024)
                  : null,
              maxWidthDiskCache: 1024,
              placeholder: (_, __) => fallback(placeholderIcon),
              errorWidget: (_, __, ___) => fallback(errorIcon),
            ),
    );
  }
}
