import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../design/ad.dart';
import '../design/app_anim.dart';
import '../design/ui.dart';
import '../api/soft_service.dart';
import '../player/global_player.dart';
import '../pages/toolkit/tool_player_page.dart';

/// ═══════════════════════════════════════════════════════════════
/// MiniPlayer —— 全局播放悬浮窗 + 灵动岛（1015 新增）
///
/// 用法：放在 App 根部（Overlay/Stack 最上层），全局常驻
///   Stack(children: [ 主界面, const MiniPlayer() ])
///
/// 两种形态：
///   · 常态：底部迷你播放条（封面 + 歌名 + 播放/下一首）
///   · 灵动岛：顶部胶囊（播放中状态），点击展开控制面板
///
/// 后台开关：ui_config.player_float_on / player_island_on
/// ═══════════════════════════════════════════════════════════════
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    this.floatOn = true,
    this.islandOn = true,
  });

  /// 后台开关：底部悬浮条
  final bool floatOn;

  /// 后台开关：顶部灵动岛
  final bool islandOn;

  @override
  Widget build(BuildContext context) {
    final p = GlobalPlayer.I;
    // ★★★ 1015 修复：原先把 Get.find 和配置读取放在 Obx 里，
    //   触发 GetX「improper use」检测 → 界面渲染失败 → 整个页面卡死。
    //   正确做法：非响应式操作放 Obx 外面，Obx 内**只**读响应式变量。
    final cfg = SoftService.instance.cachedConfig;
    final ui = cfg?.uiConfig;
    final fOn = floatOn && (ui == null || ui.playerFloatOn);
    final iOn = islandOn && (ui == null || ui.playerIslandOn);

    return Obx(() {
      // Obx 内只读响应式变量（active 依赖 ready/ctrl）
      if (!p.ready.value) return const SizedBox.shrink();
      return Stack(
        children: [
          if (fOn) Positioned(left: 0, right: 0, bottom: 0, child: _bar(context, p)),
          if (iOn) Positioned(top: 0, left: 0, right: 0, child: _island(context, p)),
        ],
      );
    });
  }

  // ─────────── 底部迷你播放条 ───────────
  Widget _bar(BuildContext context, GlobalPlayer p) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Ad.s(context, 10), 0, Ad.s(context, 10), Ad.s(context, 10)),
      child: AppScaleIn(
        child: AppPressable(
          onTap: () => _openFull(context, p),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  C.brand.withAlpha(context.isDark ? 60 : 30),
                  context.isDark ? const Color(0xFF1E1F2A) : Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(R.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(context.isDark ? 90 : 40),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: C.brand.withAlpha(context.isDark ? 60 : 30),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                _cover(context, p, 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: context.t1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.subtitle.value.isEmpty ? '正在播放' : p.subtitle.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ty.tiny.copyWith(fontSize: 11, color: context.t3),
                      ),
                    ],
                  ),
                ),
                _btn(context, p.playing.value ? Icons.pause_rounded : Icons.play_arrow_rounded, p.toggle, big: true),
                _btn(context, Icons.close_rounded, p.stop),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── 顶部灵动岛 ───────────
  Widget _island(BuildContext context, GlobalPlayer p) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: mq.padding.top + 6,
      left: 0,
      right: 0,
      child: Center(
        child: AppScaleIn(
          child: AppPressable(
            onTap: () => p.expanded.toggle(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: p.expanded.value ? Ad.wp(context, 76) : Ad.w(context, 168),
              height: p.expanded.value ? 92 : 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0F),
                borderRadius: BorderRadius.circular(p.expanded.value ? 22 : 19),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(110), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: p.expanded.value
                  ? _islandExpanded(context, p)
                  : _islandCompact(context, p),
            ),
          ),
        ),
      ),
    );
  }

  Widget _islandCompact(BuildContext context, GlobalPlayer p) {
    return Row(
      children: [
        // 左侧波形
        SizedBox(
          width: 22,
          height: 16,
          child: _WavePainter(playing: p.playing.value),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            p.title.value.isEmpty ? '播放中' : p.title.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: p.toggle,
          child: Icon(
            p.playing.value ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _islandExpanded(BuildContext context, GlobalPlayer p) {
    final total = p.total.value;
    final pos = p.pos.value;
    final prog = total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _cover(context, p, 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p.title.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    p.subtitle.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: p.toggle,
              child: Icon(
                p.playing.value ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: prog,
            minHeight: 3,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(pos), style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
            Text(_fmt(total), style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
          ],
        ),
      ],
    );
  }

  // ─────────── 小组件 ───────────
  Widget _cover(BuildContext context, GlobalPlayer p, double size) {
    final pic = p.cover.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: SizedBox(
        width: size,
        height: size,
        child: pic.isEmpty
            ? Container(
                color: C.brand.withAlpha(40),
                alignment: Alignment.center,
                child: Icon(Icons.music_note_rounded, size: size * 0.55, color: C.brand),
              )
            : CachedNetworkImage(
                imageUrl: pic,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: C.brand.withAlpha(40),
                  alignment: Alignment.center,
                  child: Icon(Icons.music_note_rounded, size: size * 0.55, color: C.brand),
                ),
              ),
      ),
    );
  }

  Widget _btn(BuildContext context, IconData icon, VoidCallback onTap, {bool big = false}) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        width: big ? 40 : 34,
        height: big ? 40 : 34,
        alignment: Alignment.center,
        child: Icon(icon, size: big ? 26 : 19, color: context.t1),
      ),
    );
  }

  void _openFull(BuildContext context, GlobalPlayer p) {
    Get.to(() => ToolPlayerPage(
          url: p.url,
          title: p.title.value,
          subtitle: p.subtitle.value,
          cover: p.cover.value,
          isAudio: p.isAudio.value,
        ));
  }

  String _fmt(int ms) {
    if (ms <= 0) return '00:00';
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

/// 灵动岛左侧「播放波形」动画
class _WavePainter extends StatefulWidget {
  const _WavePainter({required this.playing});
  final bool playing;

  @override
  State<_WavePainter> createState() => _WavePainterState();
}

class _WavePainterState extends State<_WavePainter> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _BarsPainter(_c.value, widget.playing),
        size: const Size(22, 16),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.t, this.playing);
  final double t;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4ADE80)
      ..style = PaintingStyle.fill;
    const bars = 4;
    final w = size.width / (bars * 2 - 1);
    for (var i = 0; i < bars; i++) {
      final phase = (t + i * 0.22) % 1.0;
      final h = playing
          ? (0.35 + 0.65 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)) * size.height
          : size.height * 0.3;
      final x = i * w * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, w, h),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.t != t || old.playing != playing;
}
