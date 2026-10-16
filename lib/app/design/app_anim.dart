import 'dart:async';
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

  /// ★ 1016：只对**前 maxStagger 条**做错峰动画。
  ///   几十条的大列表做入场动画本来就没意义（用户根本看不到），
  ///   而且一旦 Ticker 被 mute（弹窗/路由过渡/切 Tab），
  ///   所有条目会永远停在 opacity 0 → 整页看起来「一片空白」。
  final int maxStagger;

  const AppStaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.intervalMs = 36,
    this.maxStagger = 8,
  });

  @override
  State<AppStaggerIn> createState() => _AppStaggerInState();
}

class _AppStaggerInState extends State<AppStaggerIn> {
  // ★ 1016：不再做「逐条淡入」——
  //   这套动画在做不到的时候会让整列表停在透明，
  //   用户看到的就是「一片空白」。列表内容不值得为动画冒这个险。
  @override
  Widget build(BuildContext context) => widget.child;
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

class _AppScaleInState extends State<AppScaleIn> {
  // ★ 1016：不再持有任何动画控制器 —— 内容永远直接可见。
  @override
  Widget build(BuildContext context) => widget.child;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ★ 1016：Ticker 被 mute 时直接跳到目标值，别显示一个卡住的 0
    if (_c.value < 1 && !TickerMode.of(context)) _c.value = 1;
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
