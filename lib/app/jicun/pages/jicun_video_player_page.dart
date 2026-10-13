import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 即存解析 · 全屏视频播放页
///
/// 黑底 Scaffold，自动播放；中央播放/暂停，底部进度条可拖动 seek，
/// 顶部返回；关闭时 dispose 播放器；加载转圈，失败给错误提示 + 重试。
class JicunVideoPlayerPage extends StatefulWidget {
  const JicunVideoPlayerPage({super.key, required this.url});

  /// 视频直链（所选清晰度或默认第一条）
  final String url;

  @override
  State<JicunVideoPlayerPage> createState() => _JicunVideoPlayerPageState();
}

class _JicunVideoPlayerPageState extends State<JicunVideoPlayerPage> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _failed = false;
  String _error = '';
  bool _controlsHidden = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final old = _ctrl;
    if (old != null) {
      await old.dispose();
      _ctrl = null;
    }
    if (!mounted) return;
    setState(() {
      _initialized = false;
      _failed = false;
      _error = '';
    });
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      if (!mounted || _ctrl != ctrl) {
        // 期间用户退出或已重试（controller 被换掉），别再动它
        if (_ctrl != ctrl) await ctrl.dispose();
        return;
      }
      setState(() => _initialized = true);
      await ctrl.play();
    } catch (e) {
      if (!mounted || _ctrl != ctrl) return;
      await ctrl.dispose();
      if (_ctrl == ctrl) _ctrl = null;
      setState(() {
        _failed = true;
        _error = _friendly(e);
      });
    }
  }

  /// 把原始异常翻成人话
  String _friendly(Object e) {
    final s = e.toString();
    if (e is SocketException || s.contains('SocketException')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (s.contains('404') || s.contains('403')) {
      return '视频链接已失效，可重新解析后再试';
    }
    if (s.contains('timeout') || s.contains('超时')) return '加载超时，请重试';
    return '视频加载失败，请重试';
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _ctrl = null;
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _videoArea(),
          // 点击切换控制条显隐
          if (_initialized && !_failed)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _controlsHidden = !_controlsHidden),
              ),
            ),
          // 顶部返回
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // 中央播放/暂停
          if (_initialized && !_controlsHidden) _centerPlayButton(),
          // 底部进度条
          if (_initialized && !_controlsHidden) _bottomBar(),
        ],
      ),
    );
  }

  Widget _videoArea() {
    if (_failed) return _errorView();
    final c = _ctrl;
    if (c == null || !_initialized) return _loadingView();
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio <= 0 ? 16 / 9 : c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }

  Widget _loadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 14),
          Text('视频加载中…', style: TextStyle(color: Colors.white.withAlpha(200))),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.white.withAlpha(220),
            size: 42,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(220),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => _initPlayer(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _centerPlayButton() {
    final c = _ctrl!;
    final playing = c.value.isPlaying;
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: AnimatedOpacity(
          opacity: playing ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(110),
              shape: BoxShape.circle,
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final c = _ctrl!;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withAlpha(150)],
            ),
          ),
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, v, _) {
              final pos = v.position;
              final dur = v.duration;
              final maxMs = dur.inMilliseconds.toDouble();
              return Row(
                children: [
                  Text(
                    _fmt(pos),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(
                        min: 0,
                        max: maxMs > 0 ? maxMs : 1,
                        value: v.position.inMilliseconds
                            .clamp(0, maxMs > 0 ? maxMs.toInt() : 1)
                            .toDouble(),
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withAlpha(70),
                        onChanged: (ms) {
                          c.seekTo(Duration(milliseconds: ms.round()));
                        },
                      ),
                    ),
                  ),
                  Text(
                    _fmt(dur),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    color: Colors.white,
                    iconSize: 22,
                    onPressed: _togglePlay,
                    icon: Icon(
                      v.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
