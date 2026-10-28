import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../design/glass_theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// iOS 27「Liquid Glass」底部导航栏（GlassElasticBar）
///
/// 与旧 liquid 模板的区别（旧版只是「模糊 + 白描边」，本质还是磨砂卡）：
///   1. **真实折射层**：模糊底 + 高光描边 + 双层内反光，
///      选中态用「弹性滑动胶囊」在整条栏上移动，而不是每项各自变底色
///   2. **果冻形变**：胶囊移动时宽度/高度按速度做阻尼伸缩（spring）
///   3. **高光扫过**：胶囊内有一道斜向白色反光，随位置偏移
///   4. **触感反馈**：选中时图标 scale 回弹 + 文字淡入
///   5. **安全区自适应**：底部 inset 变化时气泡高度与圆角同步
///
/// 用法：NavTemplates 里 case 'liquid27' → GlassElasticBar.build(...)
/// ═══════════════════════════════════════════════════════════════
class GlassElasticBar {
  GlassElasticBar._();

  static Widget build(
    BuildContext context,
    List<NavDest> destinations,
    int currentIndex,
    ValueChanged<int> onTap,
    double inset,
  ) {
    // ★ 1027：页面全部是硬编码浅色底，底栏若跟主题走会在浅色页上渲染成
    // 深灰玻璃（真机视频 0:10 那坨深色）。底栏统一走浅色玻璃。
    // ★ 1028 修正：页面自 1026 起已全面走主题（深色底 #0E0F15 / 深色卡 #1A1D28），
    // 上一版写死 isDarkMode=false 导致深色模式下底栏仍是一块白玻璃（用户截图实测）。
    // 现在按页面真实明暗走：深色页 → 深色玻璃，浅色页 → 浅色玻璃。
    final isDark = context.isDark;
    return _ElasticBar(
      destinations: destinations,
      index: currentIndex,
      onTap: onTap,
      isDark: isDark,
      bottomInset: inset,
    );
  }
}

/// 一个导航项（图标 + 文字），与 NavigateLogic.labels 解耦
class NavDest {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const NavDest({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _ElasticBar extends StatefulWidget {
  final List<NavDest> destinations;
  final int index;
  final ValueChanged<int> onTap;
  final bool isDark;
  final double bottomInset;

  const _ElasticBar({
    required this.destinations,
    required this.index,
    required this.onTap,
    required this.isDark,
    required this.bottomInset,
  });

  @override
  State<_ElasticBar> createState() => _ElasticBarState();
}

class _ElasticBarState extends State<_ElasticBar>
    with SingleTickerProviderStateMixin {
  static const double _barH = 64;
  static const double _pillH = 46;
  static const double _pad = 6;

  late AnimationController _c;
  late Animation<double> _pos;
  double _from = 0;
  double _to = 0;
  // ★ iOS 拟真按压状态：按下凹 / 长按浮起
  int? _pressedIdx;
  int? _liftIdx;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _from = _to = widget.index.toDouble();
    _pos = AlwaysStoppedAnimation(widget.index.toDouble());
  }

  @override
  void didUpdateWidget(covariant _ElasticBar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = _pos.value;
      _to = widget.index.toDouble();
      // 弹性曲线：先冲过头再回弹，模拟果冻
      final tween = Tween<double>(begin: _from, end: _to);
      _pos = CurvedAnimation(
        parent: _c,
        curve: const Cubic(0.34, 1.32, 0.52, 1.0),
      ).drive(tween);
      _c
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final n = widget.destinations.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        (widget.bottomInset > 0 ? widget.bottomInset : 8) + 8,
      ),
      child: LayoutBuilder(
        builder: (ctx, cons) {
          final width = cons.maxWidth;
          final itemW = (width - _pad * 2) / n;
          return SizedBox(
            height: _barH,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // ① 玻璃主体
                Positioned.fill(child: _glassBody(context, isDark)),
                // ② 弹性胶囊（单独一层，压在图标下面）
                AnimatedBuilder(
                  animation: _c,
                  builder: (c, _) {
                    final p = _pos.value;
                    // 高速移动时做纵向压扁（果冻形变）
                    final v = (_to - _from).abs();
                    final stretch = Curves.easeOut.transform(_c.value);
                    final squash = v <= 0.001
                        ? 1.0
                        : (1.0 - 0.06 * (1 - stretch)).clamp(0.88, 1.0);
                    final x = _pad + itemW * p;
                    return Positioned(
                      left: x,
                      top: (_barH - _pillH * squash) / 2,
                      width: itemW,
                      height: _pillH * squash,
                      child: _pill(isDark, p),
                    );
                  },
                ),
                // ③ 图标 + 文字（iOS 拟真：按压凹下 / 长按浮起，松手才切换）
                Positioned.fill(
                  child: Row(
                    children: List.generate(n, (i) {
                      final sel = widget.index == i;
                      final d = widget.destinations[i];
                      final activeColor = isDark ? Colors.white : C.brand;
                      final pressed = _pressedIdx == i;
                      final lifted = _liftIdx == i;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) {
                            setState(() => _pressedIdx = i);
                            HapticFeedback.selectionClick();
                          },
                          onTapCancel: () {
                            setState(() {
                              _pressedIdx = null;
                              _liftIdx = null;
                            });
                          },
                          // 轻点：松手即切（长按会抢走 tap 竞技场，互不冲突）
                          onTapUp: (_) {
                            setState(() {
                              _pressedIdx = null;
                              _liftIdx = null;
                            });
                            widget.onTap(i);
                          },
                          // ★ iOS Liquid Glass：长按浮起 + 触觉，松手才切换
                          onLongPressStart: (_) {
                            setState(() => _liftIdx = i);
                            HapticFeedback.mediumImpact();
                          },
                          onLongPressEnd: (_) {
                            setState(() {
                              _pressedIdx = null;
                              _liftIdx = null;
                            });
                            widget.onTap(i);
                          },
                          child: AnimatedScale(
                            // 按压凹下 0.92，长按浮起 1.18（不超出玻璃板被裁切）
                            scale: lifted
                                ? 1.18
                                : pressed
                                ? 0.92
                                : 1.0,
                            duration: Duration(
                              milliseconds: lifted || pressed ? 120 : 320,
                            ),
                            curve: lifted
                                ? Curves.easeOutBack
                                : Curves.easeOut,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 图标（长按浮起时带柔光垫）
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (lifted)
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isDark
                                                          ? Colors.white
                                                          : C.brand)
                                                      .withAlpha(90),
                                                  blurRadius: 18,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: const SizedBox(
                                              width: 30,
                                              height: 30,
                                            ),
                                          ),
                                        AnimatedScale(
                                          scale: sel ? 1.08 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 260,
                                          ),
                                          curve: Curves.easeOutBack,
                                          child: Icon(
                                            sel ? d.activeIcon : d.icon,
                                            size: 21,
                                            color: sel
                                                ? activeColor
                                                : context.t3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  height: 1.1,
                                  fontWeight: sel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: sel
                                      ? (isDark
                                            ? Colors.white
                                            : C.brand.withAlpha(235))
                                      : context.t3,
                                ),
                                child: Text(
                                  d.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 玻璃主体：重模糊 + 内反光 + 高光描边 + 投影
  Widget _glassBody(BuildContext context, bool isDark) {
    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.full),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xCC161A24), Color(0xB312151C)]
              : const [Color(0xF2FFFFFF), Color(0xD9F4F6FF)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(56)
              : Colors.white.withAlpha(240),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 120 : 30),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withAlpha(isDark ? 12 : 170),
            blurRadius: 1.2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 顶部内侧白色反光带（Liquid Glass 的标志性高光）
          Positioned(
            left: 12,
            right: 12,
            top: 1.2,
            height: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.full),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha(isDark ? 40 : 190),
                    Colors.white.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          // 斜向扫光（注意：不要写成 const，C.brand 是可变静态色）
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(R.full),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: const Alignment(0.3, 1.2),
                colors: [
                  Colors.white.withAlpha(isDark ? 26 : 120),
                  Colors.white.withAlpha(0),
                ],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ],
      ),
    );
    final anyBlur = GlassTheme.bigBlur;
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.full),
      child: anyBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: GlassTheme.sigma,
                sigmaY: GlassTheme.sigma,
              ),
              child: body,
            )
          : body,
    );
  }

  /// 选中胶囊：渐变 + 柔光 + 内部斜向反光
  Widget _pill(bool isDark, double position) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            C.brand.withAlpha(isDark ? 150 : 30),
            C.brand.withAlpha(isDark ? 92 : 16),
          ],
        ),
        border: Border.all(
          color: C.brand.withAlpha(isDark ? 110 : 60),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: C.brand.withAlpha(isDark ? 70 : 34),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // 反光位置随胶囊位置轻微偏移（模拟真实玻璃折射）
          gradient: LinearGradient(
            begin: Alignment(-0.6 + position * 0.12, -1),
            end: Alignment(0.5 + position * 0.1, 1),
            colors: [
              Colors.white.withAlpha(isDark ? 42 : 200),
              Colors.white.withAlpha(0),
            ],
            stops: <double>[0.0, 0.7],
          ),
        ),
      ),
    );
  }
}
