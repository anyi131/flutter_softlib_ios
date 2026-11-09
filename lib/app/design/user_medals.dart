import 'package:flutter/material.dart';

import 'lucide.dart';
import 'title_badge.dart';
import 'ui.dart';

/// 1109：昵称旁的「小勋章」——全站统一
///   数据来自服务端 user.medals（已获得的成就称号，最多 3 个）+ is_vip
///   尺寸极小（默认 15px），不抢昵称，但一眼能看出这个人有成就/是会员
class InlineMedals extends StatelessWidget {
  final List<String> medals;
  final bool isVip;
  final double size;

  const InlineMedals({
    super.key,
    this.medals = const [],
    this.isVip = false,
    this.size = 15,
  });

  static IconData iconFor(String name) {
    if (name.contains('下载')) return Lz.download;
    if (name.contains('购买') || name.contains('消费')) return Lz.wallet;
    if (name.contains('签到') || name.contains('登录')) return Lz.calendar;
    if (name.contains('邀请')) return Lz.users;
    if (name.contains('评论') || name.contains('发帖')) return Lz.messageCircle;
    if (name.contains('狂') || name.contains('神')) return Lz.flame;
    return Lz.trophy;
  }

  @override
  Widget build(BuildContext context) {
    final shown = medals.take(3).toList();
    if (shown.isEmpty && !isVip) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVip) _medal(context, '会员', Icons.workspace_premium_rounded,
              const [Color(0xFFFFD86F), Color(0xFFFF9F1C)],
              const Color(0xFF4A1B00), solid: true),
          for (final m in shown)
            _medal(
              context,
              m,
              iconFor(m),
              const [Color(0xFFB388FF), Color(0xFF5C2BD9)],
              Colors.white,
              solid: false,
            ),
        ],
      ),
    );
  }

  Widget _medal(BuildContext context, String name, IconData icon,
      List<Color> colors, Color fg, {required bool solid}) {
    return Tooltip(
      message: name,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withAlpha(solid ? 110 : 80),
              blurRadius: 4,
              spreadRadius: 0.2,
            ),
          ],
        ),
        child: Icon(icon, size: size * 0.58, color: fg),
      ),
    );
  }
}

/// 会员勋章（列表里大一点的展示，例如勋章墙）
class VipMedalBadge extends StatelessWidget {
  final bool earned;
  final double size;

  const VipMedalBadge({super.key, this.earned = true, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final colors = earned
        ? const [Color(0xFFFFD86F), Color(0xFFFF9F1C)]
        : const [Color(0xFF3A3F4B), Color(0xFF2A2E38)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: earned
                ? [
                    BoxShadow(
                      color: colors.last.withAlpha(130),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(Icons.workspace_premium_rounded,
              size: size * 0.46,
              color: earned ? const Color(0xFF4A1B00) : Colors.white24),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size + 14,
          child: Text('会员勋章',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: earned ? context.t2 : context.t3,
              )),
        ),
      ],
    );
  }
}
