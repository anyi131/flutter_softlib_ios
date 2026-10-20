import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../design/app_anim.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../models/app_item.dart';

/// ═══════════════════════════════════════════════════════════════
/// 详情页 · 霓虹（第 7 套模板）
///
/// ★ 深浅自适应：同一套结构，两套配色
///   深色：#08090F 纯黑底 + 霓虹发光（青绿 00FFC2 / 蓝 00A3FF / 紫 A855F7）
///   浅色：#F4F6FC 浅底 + 柔光（青绿 00D9A6 / 蓝 0891B2 / 紫 9333EA）
///
/// 与极光版的区别：
///   · 极光是「暖彩渐变融合」，霓虹是「冷色线条发光」
///   · 极光内容区上浮覆盖，霓虹保持通透背景
///   · 霓虹的数字用宽字距英文小标签（SIZE / DOWN / VIEW / AGE）
/// ═══════════════════════════════════════════════════════════════
class DetailNeon {
  DetailNeon._();

  // 深色霓虹
  static const Color nBgDark = Color(0xFF08090F);
  static const Color nSurfDark = Color(0xFF101220);
  static const Color nMintDark = Color(0xFF00FFC2);
  static const Color nBlueDark = Color(0xFF00A3FF);
  static const Color nVioletDark = Color(0xFFA855F7);

  // 浅色霓虹
  static const Color nBgLight = Color(0xFFF4F6FC);
  static const Color nMintLight = Color(0xFF00B386);
  static const Color nBlueLight = Color(0xFF0891B2);
  static const Color nVioletLight = Color(0xFF9333EA);

  static Color mint(bool d) => d ? nMintDark : nMintLight;
  static Color blue(bool d) => d ? nBlueDark : nBlueLight;
  static Color violet(bool d) => d ? nVioletDark : nVioletLight;
  static Color bg(bool d) => d ? nBgDark : nBgLight;

  // ─────────── 顶部：图标 + 标题 + 徽章 ───────────

  static Widget header(
    BuildContext context, {
    required AppItem? item,
    required String iconUrl,
    required String topLabel,
    required String sizeText,
    required bool dark,
  }) {
    return Stack(
      children: [
        // 柔光背景（深浅各一套透明度）
        if (dark) ...[
          _glowBg(context, mint(true), 300, -90, -120, 0.20),
          _glowBg(context, violet(true), 280, null, -60, 0.18, right: -100),
        ] else ...[
          _glowBg(context, mint(false), 300, -90, -120, 0.16),
          _glowBg(context, violet(false), 280, null, -60, 0.14, right: -100),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: Column(
            children: [
              // 图标：渐变描边 + 发光
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [mint(dark), blue(dark), violet(dark)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: mint(dark).withAlpha(dark ? 90 : 70),
                      blurRadius: dark ? 40 : 26,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: violet(dark).withAlpha(dark ? 70 : 46),
                      blurRadius: dark ? 70 : 40,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: iconUrl.isEmpty
                      ? Container(
                          color: violet(dark).withAlpha(60),
                          child: const Icon(
                            Icons.android,
                            color: Colors.white,
                            size: 36,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: violet(dark).withAlpha(60),
                            child: const Icon(
                              Icons.android,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                item?.title ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 23,
                  height: 1.24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                  color: dark ? Colors.white : context.t1,
                  shadows: dark
                      ? [
                          Shadow(
                            color: mint(true).withAlpha(90),
                            blurRadius: 30,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 主状态
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [mint(dark), blue(dark)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: mint(dark).withAlpha(dark ? 120 : 90),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      topLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: dark ? const Color(0xFF00251C) : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 大小
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: dark ? nSurfDark : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: dark
                            ? const Color(0xFF22252F)
                            : const Color(0xFFE2E6F0),
                      ),
                    ),
                    child: Text(
                      sizeText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: dark
                            ? const Color(0xFF8A90A0)
                            : const Color(0xFF5C6273),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _glowBg(
    BuildContext context,
    Color c,
    double size,
    double? left,
    double top,
    double opacity, {
    double? right,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [c.withAlpha((255 * opacity).round()), c.withAlpha(0)],
              stops: const [0.0, 0.68],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── 数据条（渐变分隔线）───────────

  static Widget statBar(
    BuildContext context, {
    required List<(String, String, Color)> cells, // (数值, 英文标签, 颜色)
    required bool dark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        color: dark ? nSurfDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? const Color(0xFF1E2230) : const Color(0xFFE6EAF4),
        ),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF1E2850).withAlpha(18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 26,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      cells[i].$3.withAlpha(dark ? 200 : 160),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cells[i].$1,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: i == 0
                          ? (dark ? Colors.white : context.t1)
                          : cells[i].$3,
                      shadows: dark
                          ? [
                              Shadow(
                                color: (i == 0 ? Colors.white : cells[i].$3)
                                    .withAlpha(i == 0 ? 60 : 140),
                                blurRadius: 18,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cells[i].$2,
                    style: TextStyle(
                      fontSize: 8.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: dark
                          ? const Color(0xFF5A6070)
                          : const Color(0xFF9BA1B0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────── 分区标题（渐变竖条）───────────

  static Widget section(
    BuildContext context,
    String title, {
    required bool dark,
    Widget? trailing,
    Color? accent,
  }) {
    final c = accent ?? (dark ? mint(true) : mint(false));
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c, blue(dark)],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: dark
                  ? [BoxShadow(color: c.withAlpha(120), blurRadius: 12)]
                  : null,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: dark ? Colors.white : context.t1,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// 官方描边徽章
  static Widget officialBadge(bool dark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
    decoration: BoxDecoration(
      color: dark ? Colors.transparent : const Color(0xFFF3EEFF),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: violet(dark).withAlpha(dark ? 200 : 120)),
    ),
    child: Text(
      '官方',
      style: TextStyle(
        fontSize: 8.5,
        fontWeight: FontWeight.w900,
        color: dark ? const Color(0xFFC99BFF) : violet(false),
      ),
    ),
  );

  // ─────────── 截图（带发光边）───────────

  static Widget screenshots(
    BuildContext context, {
    required List<String> shots,
    required bool dark,
    required ValueChanged<int> onTap,
  }) {
    if (shots.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: shots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (c, i) => AppPressable(
          onTap: () => onTap(i),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dark ? const Color(0xFF1E2230) : const Color(0xFFE6EAF4),
              ),
              boxShadow: dark
                  ? [BoxShadow(color: mint(true).withAlpha(38), blurRadius: 30)]
                  : [
                      BoxShadow(
                        color: const Color(0xFF1E2850).withAlpha(20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(c).size.width * 0.82,
                ),
                child: CachedNetworkImage(
                  imageUrl: shots[i],
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 210,
                    color: dark ? Colors.white10 : Colors.black.withAlpha(6),
                    child: Icon(Icons.broken_image_outlined, color: context.t3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── 底部按钮 ───────────

  static Widget downloadButton({
    required String label,
    required bool dark,
    required VoidCallback onTap,
  }) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [mint(dark), blue(dark)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: mint(dark).withAlpha(dark ? 140 : 100),
              blurRadius: dark ? 40 : 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.file_download_rounded,
              size: 19,
              color: dark ? const Color(0xFF001A14) : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: dark ? const Color(0xFF001A14) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
