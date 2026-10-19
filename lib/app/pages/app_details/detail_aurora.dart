import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../models/app_item.dart';

/// ═══════════════════════════════════════════════════════════════
/// 详情页 · 极光渐变（第 6 套模板）
///
/// 设计：四色网格渐变打底 + 毛玻璃数据卡 + 渐变文字 + 彩虹按钮。
///   · 顶部深色区：紫 / 粉 / 青 / 薄荷 四团高饱和光晕叠加
///   · 数据卡：BackdropFilter 毛玻璃 + 白色渐变文字数字
///   · 内容区：白色大圆角上浮，分区标题带渐变竖条
///
/// ★ 不影响原有 5 套模板，只在 switch 里新增一个分支。
/// ═══════════════════════════════════════════════════════════════
class DetailAurora {
  DetailAurora._();

  // 极光专用色（与主品牌色不同的高饱和配色）
  static const Color aViolet = Color(0xFF5B3BFF);
  static const Color aPink = Color(0xFFFF3D9A);
  static const Color aCyan = Color(0xFF00C2FF);
  static const Color aBlue = Color(0xFF38BDF8);
  static const Color aMint = Color(0xFF00E0A4);
  static const Color aOrange = Color(0xFFFF9E3D);
  static const Color aNight = Color(0xFF0B0E1A);

  // ─────────── 顶部渐变区 ───────────

  static Widget header(
    BuildContext context, {
    required AppItem? item,
    required String iconUrl,
    required String topLabel,
    required List<(String, String)> badges,
  }) {
    return Stack(
      children: [
        // ① 四团光晕
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
            // ★ StackFit.expand：让底色 Container 撑满，
            //   否则「无子节点 + 无尺寸」的 Container 在 Stack 里会缩成 0×0，
            //   光晕层就整个看不见了
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: aNight),
                _blob(aViolet, 420, -120, -160, 0.95),
                _blob(aPink, 380, null, -60, 0.85, right: -140),
                _blob(aCyan, 340, -60, 180, 0.75),
                _blob(aMint, 300, null, 300, 0.65, right: -80),
                // 底部压暗，保证按钮区可读
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          aNight.withAlpha(140),
                          aNight.withAlpha(230),
                        ],
                        stops: const [0.5, 0.82, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ② 内容
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 图标：白渐变描边 + 彩色投影
                  Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withAlpha(220),
                          Colors.white.withAlpha(46),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: aViolet.withAlpha(150),
                          blurRadius: 44,
                          offset: const Offset(0, 16),
                        ),
                        BoxShadow(
                          color: Colors.white.withAlpha(60),
                          blurRadius: 0,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: iconUrl.isEmpty
                          ? Container(
                              color: aViolet.withAlpha(60),
                              child: const Icon(
                                Icons.android,
                                color: Colors.white,
                                size: 34,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: iconUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: aViolet.withAlpha(60),
                                child: const Icon(
                                  Icons.android,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item?.title ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 18,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            // 主状态（渐变糖果色）
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [aMint, aCyan],
                                ),
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: [
                                  BoxShadow(
                                    color: aMint.withAlpha(120),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                topLabel,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF00251C),
                                ),
                              ),
                            ),
                            for (final b in badges)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(40),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(50),
                                  ),
                                ),
                                child: Text(
                                  b.$2,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
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

  static Widget _blob(
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
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [c.withAlpha((255 * opacity).round()), c.withAlpha(0)],
            stops: const [0.0, 0.66],
          ),
        ),
      ),
    );
  }

  // ─────────── 毛玻璃数据卡 ───────────

  static Widget statGlass({
    required List<(String, String, Color, Color)> cells,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withAlpha(52)),
            ),
            child: Row(
              children: [
                for (int i = 0; i < cells.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withAlpha(36),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 渐变文字数字
                        ShaderMask(
                          shaderCallback: (r) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white, cells[i].$3],
                          ).createShader(r),
                          child: Text(
                            cells[i].$1,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cells[i].$2,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withAlpha(140),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── 分区标题（渐变竖条）───────────

  static Widget section(
    BuildContext context,
    String title, {
    Widget? trailing,
    bool night = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [aViolet, aPink],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(color: aViolet.withAlpha(110), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: night ? Colors.white : context.t1,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// 官方徽章（渐变）
  static Widget officialBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [aViolet, aPink]),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      '官方',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );

  // ─────────── 截图 ───────────

  static Widget screenshots(
    BuildContext context, {
    required List<String> shots,
    required ValueChanged<int> onTap,
  }) {
    if (shots.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: shots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (c, i) => GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: aViolet.withAlpha(60),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(c).size.width * 0.84,
                ),
                child: CachedNetworkImage(
                  imageUrl: shots[i],
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 220,
                    color: context.isDark
                        ? Colors.white10
                        : Colors.black.withAlpha(6),
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

  // ─────────── 底部按钮（彩虹渐变）───────────

  static Widget downloadButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [aViolet, aPink, aOrange],
            stops: [0.0, 0.52, 1.0],
          ),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: aPink.withAlpha(130),
              blurRadius: 40,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.file_download_rounded,
              size: 19,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
