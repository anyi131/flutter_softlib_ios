import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// AppAnim —— 全局统一动画系统（v52 #2 动画全面重构）
///
/// 设计原则：
///   · 时长档位：fast 140ms / base 220ms / slow 320ms，全 App 只用这三档
///   · 曲线：emphasized(入场) / exit(退场) / spring(弹性)
///   · 列表入场：AppStaggerIn 统一「渐入+上浮+微缩放」交错动画
///   · 按压反馈：AppPressable 统一「缩放 0.97」触感
///   · 弹窗/卡片：AppScaleIn 淡入缩放；数值：AppCountUp 补间
/// ═══════════════════════════════════════════════════════════════
class AppAnim {
  AppAnim._();

  // ── 时长档位 ──
  // ★ 1015 优化：整体压快 20%。
  //   原 140/220/320 与转场叠加后，「点一下」的等待感太强；
  //   120/180/260 仍是自然的动效节奏，但明显更跟手。
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);

  // ── 曲线 ──
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;

  /// 页面淡入上浮（自定义转场 builder 用）
  static Widget fadeUp(
    BuildContext c,
    Animation<double> a,
    Animation<double> b,
    Widget child,
  ) {
    final t = CurvedAnimation(parent: a, curve: emphasized, reverseCurve: exit);
    return FadeTransition(
      opacity: Tween(begin: 0.0, end: 1.0).animate(t),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(t),
        child: child,
      ),
    );
  }
}

/// ── 列表交错入场 ──
/// 包住每个 item；[index] 越大起跳越晚（封顶 420ms，长列表不拖沓）
class AppStaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  final int intervalMs;
  const AppStaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.intervalMs = 36,
  });

  @override
  State<AppStaggerIn> createState() => _AppStaggerInState();
}

class _AppStaggerInState extends State<AppStaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppAnim.slow,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: AppAnim.emphasized,
  );

  @override
  void initState() {
    super.initState();
    final delay = math.min(widget.index * widget.intervalMs, 420);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) {
        final v = _a.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 22),
            child: Transform.scale(scale: 0.985 + 0.015 * v, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// ── 按压反馈（统一触感）──
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  /// ★ 1015：长按（图片保存等场景）
  final VoidCallback? onLongPress;
  final double scale;
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppAnim.fast,
        curve: AppAnim.emphasized,
        child: widget.child,
      ),
    );
  }
}

/// ── 缩放淡入（弹窗/卡片首次出现）──
class AppScaleIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const AppScaleIn({
    super.key,
    required this.child,
    this.duration = AppAnim.base,
  });

  @override
  State<AppScaleIn> createState() => _AppScaleInState();
}

class _AppScaleInState extends State<AppScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: AppAnim.emphasized),
      child: ScaleTransition(
        scale: Tween(
          begin: 0.92,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _c, curve: AppAnim.spring)),
        child: widget.child,
      ),
    );
  }
}

/// ── 数值补间（进度/积分跳动）──
class AppCountUp extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final String Function(double v)? formatter;
  const AppCountUp({
    super.key,
    required this.value,
    this.style,
    this.formatter,
  });

  @override
  State<AppCountUp> createState() => _AppCountUpState();
}

class _AppCountUpState extends State<AppCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppAnim.slow,
  );
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant AppCountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = AppAnim.emphasized.transform(_c.value);
        final v = _from + (widget.value - _from) * t;
        final text = widget.formatter != null
            ? widget.formatter!(v)
            : v.toStringAsFixed(0);
        return Text(text, style: widget.style);
      },
    );
  }
}
