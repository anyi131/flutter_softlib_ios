import 'package:flutter/material.dart';

import 'lucide.dart';
import 'ui.dart';

/// 1109：统一称号 / 勋章徽章系统
/// ————————————————————————————————
/// 称号样式按「稀有度」分 4 档，全站任何显示昵称的地方都用同一套：
///   legend  传说  红金渐变 + 皇冠 + 光晕（管理员 / 「神·王·至尊·狂人」等）
///   epic    史诗  紫粉渐变 + 星芒（达人 / 大师 / 成就称号 / VIP）
///   rare    稀有  青蓝渐变（普通自定义称号）
///   common  普通  灰底描边
enum TitleRarity { common, rare, epic, legend }

class TitleTier {
  final TitleRarity rarity;
  final List<Color> colors;
  final Color textColor;
  final IconData icon;
  final bool glow;

  const TitleTier(this.rarity, this.colors, this.textColor, this.icon,
      {this.glow = false});
}

/// 稀有度判定（纯客户端，零服务端成本，同称号全站一致）
TitleRarity titleRarityOf(String title,
    {bool isVip = false, bool isAdmin = false}) {
  final t = title.trim();
  if (t.isEmpty) return TitleRarity.common;
  if (isAdmin) return TitleRarity.legend;
  const legendary = ['神', '王', '至尊', '狂人', '传说', '魔王', '霸', '帝'];
  const epic = ['达人', '大师', '高手', '专家', '之星', '王者', '新人报道'];
  for (final k in legendary) {
    if (t.contains(k)) return TitleRarity.legend;
  }
  for (final k in epic) {
    if (t.contains(k)) return TitleRarity.epic;
  }
  if (isVip) return TitleRarity.epic;
  // 按内容稳定取色（不同称号不同色，避免全站一个样）
  return TitleRarity.rare;
}

TitleTier titleTierOf(String title, {bool isVip = false, bool isAdmin = false}) {
  final r = titleRarityOf(title, isVip: isVip, isAdmin: isAdmin);
  switch (r) {
    case TitleRarity.legend:
      return const TitleTier(
        TitleRarity.legend,
        [Color(0xFFFFD86F), Color(0xFFFF8A3D), Color(0xFFE0413E)],
        Color(0xFF4A1B00),
        Lz.crown,
        glow: true,
      );
    case TitleRarity.epic:
      return const TitleTier(
        TitleRarity.epic,
        [Color(0xFFB388FF), Color(0xFF7C4DFF), Color(0xFF5C2BD9)],
        Colors.white,
        Lz.sparkles,
        glow: true,
      );
    case TitleRarity.rare:
      return const TitleTier(
        TitleRarity.rare,
        [Color(0xFF7FE3FF), Color(0xFF3AA8FF), Color(0xFF2B6BFF)],
        Colors.white,
        Lz.badge,
      );
    case TitleRarity.common:
      return const TitleTier(
        TitleRarity.common,
        [Color(0xFFEFF2F7), Color(0xFFE2E8F0)],
        Color(0xFF64748B),
        Lz.badge,
      );
  }
}

/// 称号徽章（全站统一）。title 为空时不渲染。
class TitleBadge extends StatelessWidget {
  final String title;
  final bool isVip;
  final bool isAdmin;
  final double scale; // 1.0 基准；列表中可用 0.9，我的页 1.15

  const TitleBadge(
    this.title, {
    super.key,
    this.isVip = false,
    this.isAdmin = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final t = title.trim();
    if (t.isEmpty) return const SizedBox.shrink();
    final tier = titleTierOf(t, isVip: isVip, isAdmin: isAdmin);
    final fs = 9.5 * scale;
    return Container(
      margin: EdgeInsets.only(left: 5 * scale),
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 1.6 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tier.colors),
        borderRadius: BorderRadius.circular(5 * scale),
        border: Border.all(
          color: tier.textColor.withAlpha(tier.rarity == TitleRarity.common ? 40 : 70),
          width: 0.8,
        ),
        boxShadow: tier.glow
            ? [
                BoxShadow(
                  color: tier.colors.last.withAlpha(110),
                  blurRadius: 6 * scale,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(tier.icon, size: fs + 1.5, color: tier.textColor),
        SizedBox(width: 2.5 * scale),
        Text(
          t,
          style: TextStyle(
            fontSize: fs,
            height: 1.25,
            color: tier.textColor,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ]),
    );
  }
}

/// 勋章（成就可视化）：圆形渐变 + 图标 + 可选光晕
class MedalBadge extends StatelessWidget {
  final String name;
  final IconData? icon;
  final bool earned;
  final double size;
  final TitleRarity rarity;

  const MedalBadge({
    super.key,
    required this.name,
    this.icon,
    this.earned = true,
    this.size = 52,
    this.rarity = TitleRarity.epic,
  });

  static TitleTier _tier(TitleRarity r) => switch (r) {
        TitleRarity.legend => titleTierOf('神'),
        TitleRarity.epic => titleTierOf('达人'),
        TitleRarity.rare => titleTierOf('稀有'),
        TitleRarity.common => titleTierOf(''),
      };

  @override
  Widget build(BuildContext context) {
    final tier = _tier(rarity);
    final colors = earned
        ? tier.colors
        : [const Color(0xFF3A3F4B), const Color(0xFF2A2E38)];
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
                      color: colors.last.withAlpha(120),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              icon ?? Lz.trophy,
              size: size * 0.46,
              color: earned ? tier.textColor : Colors.white24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size + 14,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: earned ? context.t2 : context.t3,
            ),
          ),
        ),
      ],
    );
  }
}
