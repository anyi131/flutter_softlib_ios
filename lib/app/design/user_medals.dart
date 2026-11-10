import 'package:flutter/material.dart';

import 'lucide.dart';
import 'title_badge.dart';
import 'ui.dart';

/// 1109：勋章配色体系 —— 按成就类型给不同颜色/图标，不再全站一个紫
///   传说（狂人/神/霸）  红金 + 皇冠
///   会员               金 + 王冠
///   下载类             蓝青 + 下载箭头
///   消费类             玫瑰 + 钱包
///   签到/连续          青绿 + 日历
///   邀请/好友          橙 + 用户
///   社区/发帖评论      紫 + 消息
///   默认               灰蓝 + 奖杯
class MedalTier {
  final List<Color> colors;
  final Color fg;
  final IconData icon;
  final bool glow;
  final TitleRarity rarity;

  const MedalTier(this.colors, this.fg, this.icon, this.rarity,
      {this.glow = false});
}

MedalTier medalTierOf(String name, {bool isVip = false}) {
  final n = name.trim();
  if (isVip) {
    return const MedalTier(
      [Color(0xFFFFF0B8), Color(0xFFFFD86F), Color(0xFFFF9F1C)],
      Color(0xFF4A1B00),
      Icons.workspace_premium_rounded,
      TitleRarity.legend,
      glow: true,
    );
  }
  if (n.contains('狂') || n.contains('神') || n.contains('王') || n.contains('传说')) {
    return const MedalTier(
      [Color(0xFFFFD86F), Color(0xFFFF8A3D), Color(0xFFE0413E)],
      Color(0xFF4A1B00),
      Lz.crown,
      TitleRarity.legend,
      glow: true,
    );
  }
  if (n.contains('下载')) {
    return const MedalTier(
      [Color(0xFF9BE7FF), Color(0xFF4FC3F7), Color(0xFF0288D1)],
      Color(0xFF00344A),
      Lz.download,
      TitleRarity.epic,
    );
  }
  if (n.contains('购买') || n.contains('消费') || n.contains('充值')) {
    return const MedalTier(
      [Color(0xFFFFC1CB), Color(0xFFFF7A8A), Color(0xFFD81B60)],
      Colors.white,
      Lz.wallet,
      TitleRarity.epic,
    );
  }
  if (n.contains('签到') || n.contains('登录') || n.contains('连续')) {
    return const MedalTier(
      [Color(0xFFA7F3E4), Color(0xFF4DD0B1), Color(0xFF009688)],
      Color(0xFF003A32),
      Lz.calendar,
      TitleRarity.rare,
    );
  }
  if (n.contains('邀请') || n.contains('好友') || n.contains('分享')) {
    return const MedalTier(
      [Color(0xFFFFD9A8), Color(0xFFFFB74D), Color(0xFFF57C00)],
      Color(0xFF4A2600),
      Lz.users,
      TitleRarity.rare,
    );
  }
  if (n.contains('帖') || n.contains('评论') || n.contains('社区') || n.contains('发')) {
    return const MedalTier(
      [Color(0xFFD6C4FF), Color(0xFFB388FF), Color(0xFF5C2BD9)],
      Colors.white,
      Lz.messageCircle,
      TitleRarity.epic,
    );
  }
  return const MedalTier(
    [Color(0xFFCFD8E3), Color(0xFF94A3B8), Color(0xFF52606D)],
    Colors.white,
    Lz.trophy,
    TitleRarity.common,
  );
}

/// 昵称旁的小勋章（与称号同款胶囊，但按类别配色）
class InlineMedals extends StatelessWidget {
  final List<String> medals;
  final bool isVip;
  final double size;

  const InlineMedals({
    super.key,
    this.medals = const [],
    this.isVip = false,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final shown = medals.take(2).toList();
    if (shown.isEmpty && !isVip) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: 4 * (size / 14).clamp(0.8, 1.2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVip) _badge('会员', medalTierOf('', isVip: true), size),
          for (final m in shown) _badge(m, medalTierOf(m), size),
        ],
      ),
    );
  }

  Widget _badge(String text, MedalTier tier, double size) {
    final fs = size * 0.68;
    return Container(
      margin: EdgeInsets.only(right: 4 * (size / 14)),
      padding: EdgeInsets.symmetric(horizontal: size * 0.38, vertical: size * 0.11),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tier.colors),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: tier.fg.withAlpha(70), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: tier.colors.last.withAlpha(tier.glow ? 120 : 70),
            blurRadius: size * (tier.glow ? 0.7 : 0.42),
            spreadRadius: tier.glow ? 0.8 : 0.3,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: fs + 1.2, color: tier.fg),
          SizedBox(width: size * 0.15),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size * 4.6),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fs,
                height: 1.25,
                color: tier.fg,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 会员勋章（勋章墙大号）
class VipMedalBadge extends StatelessWidget {
  final bool earned;
  final double size;

  const VipMedalBadge({super.key, this.earned = true, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final tier = medalTierOf('', isVip: true);
    final colors = earned
        ? tier.colors
        : const [Color(0xFF3A3F4B), Color(0xFF2A2E38), Color(0xFF1F232B)];
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
                      color: tier.colors.last.withAlpha(140),
                      blurRadius: 12,
                      spreadRadius: 1.5,
                    ),
                  ]
                : null,
          ),
          child: Icon(Icons.workspace_premium_rounded,
              size: size * 0.46,
              color: earned ? tier.fg : Colors.white24),
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
