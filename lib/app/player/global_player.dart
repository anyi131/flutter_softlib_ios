import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// ═══════════════════════════════════════════════════════════════
/// GlobalPlayer —— 全局播放器（1015 新增）
///
/// 解决：音乐/视频播放时切到其他页面就断了，没有「悬浮窗」控制
///
/// 特性：
///   · 单例持有唯一的 VideoPlayerController（跨页面不断播）
///   · 暴露响应式状态（播放中/进度/标题），供悬浮窗和灵动岛订阅
///   · 页面退出不销毁，只有显式 stop 才释放
/// ═══════════════════════════════════════════════════════════════
class GlobalPlayer {
  GlobalPlayer._();

  static final GlobalPlayer I = GlobalPlayer._();

  /// 当前控制器（null = 未播放）
  VideoPlayerController? ctrl;

  /// 响应式状态
  final playing = false.obs;
  final ready = false.obs;
  final title = ''.obs;
  final subtitle = ''.obs;
  final cover = ''.obs;
  final isAudio = true.obs;
  final pos = 0.obs;
  final total = 0.obs;
  final failed = ''.obs;
  final expanded = false.obs;

  /// 当前播放地址
  String url = '';

  /// 播放完成回调
  VoidCallback? onComplete;

  /// 开始播放（自动停掉上一个）
  Future<void> open({
    required String u,
    required String t,
    String sub = '',
    String pic = '',
    bool audio = true,
  }) async {
    if (url == u && ctrl != null && ready.value) {
      await ctrl!.play();
      playing.value = true;
      return;
    }

    await stop();

    url = u;
    title.value = t;
    subtitle.value = sub;
    cover.value = pic;
    isAudio.value = audio;
    failed.value = '';

    final host = Uri.tryParse(u)?.host ?? '';
    final ref = host.contains('126.net')
        ? 'https://music.163.com/'
        : (host.contains('lz') || host.contains('bfvvs') || host.contains('jisuzyv'))
        ? 'https://$host/'
        : '';

    final c = VideoPlayerController.networkUrl(
      Uri.parse(u),
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        if (ref.isNotEmpty) 'Referer': ref,
      },
    );
    ctrl = c;

    try {
      await c.initialize();
      if (ctrl != c) return;
      c.setLooping(false);
      c.addListener(_tick);
      ready.value = true;
      total.value = c.value.duration.inMilliseconds;
      await c.play();
      playing.value = true;
    } catch (e) {
      if (ctrl != c) return;
      await c.dispose();
      ctrl = null;
      ready.value = false;
      failed.value = _friendly(e);
    }
  }

  void _tick() {
    final c = ctrl;
    if (c == null || !c.value.isInitialized) return;
    pos.value = c.value.position.inMilliseconds;
    final p = c.value.isPlaying;
    if (p != playing.value) playing.value = p;
    // 播放完成 → 自动下一首
    final v = c.value;
    if (v.duration.inMilliseconds > 0 &&
        v.position.inMilliseconds >= v.duration.inMilliseconds - 400 &&
        !v.isPlaying) {
      onComplete?.call();
    }
  }

  Future<void> toggle() async {
    final c = ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
      playing.value = false;
    } else {
      await c.play();
      playing.value = true;
    }
  }

  Future<void> seekTo(int ms) async {
    final c = ctrl;
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(Duration(milliseconds: ms.clamp(0, total.value)));
    pos.value = ms;
  }

  Future<void> stop() async {
    final c = ctrl;
    ctrl = null;
    url = '';
    ready.value = false;
    playing.value = false;
    expanded.value = false;
    pos.value = 0;
    total.value = 0;
    if (c != null) {
      try {
        c.removeListener(_tick);
        await c.dispose();
      } catch (_) {}
    }
  }

  /// 是否有活跃播放（悬浮窗据此显示/隐藏）
  bool get active => ctrl != null && ready.value;

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('403')) return '播放源拒绝访问（403），可换一个源';
    if (s.contains('404')) return '播放地址已失效';
    if (s.contains('timeout') || s.contains('超时')) return '加载超时，请重试';
    if (s.contains('SocketException')) return '网络连接失败';
    return '播放失败，可换一个源试试';
  }
}
