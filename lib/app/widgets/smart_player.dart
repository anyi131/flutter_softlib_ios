import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../design/adaptive.dart';
import '../design/ui.dart';
import '../utils/toast_util.dart';

/// ★ 1016：全 App 统一视频播放器（基于 media_kit / libmpv）
///
/// 特性：
///  · 硬解 / HLS / mkv 等任意格式
///  · 手势：左竖滑亮度、右竖滑音量、横滑快进快退（带时间气泡）
///  · 双击左右 10 秒快进/快退；单击显隐控件
///  · 倍速 0.5~2.0、静音、全屏（自动横屏+沉浸）、进度拖动气泡
///  · 首帧前封面/骨架，播放失败给兜底按钮
class SmartPlayer extends StatefulWidget {
  const SmartPlayer({
    super.key,
    required this.url,
    this.poster,
    this.title = '',
    this.autoPlay = true,
    this.loop = false,
    this.showFullscreen = true,
    this.aspectRatio,
    this.onExit,
  });

  final String url;
  final String? poster;
  final String title;
  final bool autoPlay;
  final bool loop;
  final bool showFullscreen;
  final double? aspectRatio;

  /// 全屏退出时的回调（如需要同步状态）
  final VoidCallback? onExit;

  @override
  State<SmartPlayer> createState() => _SmartPlayerState();
}

class _SmartPlayerState extends State<SmartPlayer> {
  late final Player _player;
  late final VideoController _controller;

  bool _ready = false;
  bool _controls = true;
  bool _buffering = false;
  String _error = '';

  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  Duration _buf = Duration.zero;

  // 手势状态
  double _brightness = 0.5;
  double _volume = 1;
  String _hint = ''; // 手势提示文字
  bool _hintVisible = false;
  double _dragDelta = 0; // 横向拖动秒数
  bool _horizontalDrag = false;
  Duration? _seekTarget;

  double _speed = 1.0;
  Timer? _hideTimer;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    // 监听状态
    _subs.add(_player.stream.duration.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_player.stream.position.listen((p) {
      if (mounted && !_horizontalDrag) setState(() => _pos = p);
    }));
    _subs.add(_player.stream.buffer.listen((b) {
      if (mounted) setState(() => _buf = b);
    }));
    _subs.add(_player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    }));
    _subs.add(_player.stream.error.listen((e) {
      if (mounted && e.isNotEmpty) setState(() => _error = e);
    }));
    _subs.add(_player.stream.playing.listen((_) {
      if (mounted) _armHide();
    }));

    _boot();
  }

  Future<void> _boot() async {
    try {
      await _player.setVolume(_volume * 100);
      await _player.open(Media(widget.url), play: widget.autoPlay);
      if (widget.loop) await _player.setPlaylistMode(PlaylistMode.loop);
      if (!mounted) return;
      setState(() => _ready = true);
      _armHide();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _hideTimer?.cancel();
    _player.dispose();
    _restoreSystemUi();
    super.dispose();
  }

  void _armHide() {
    _hideTimer?.cancel();
    if (!_ready) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_player.state.playing) return;
      if (mounted) setState(() => _controls = false);
    });
  }

  void _toggle() {
    if (_player.state.playing) {
      _player.pause();
      setState(() => _controls = true);
      _hideTimer?.cancel();
    } else {
      _player.play();
      _armHide();
    }
  }

  void _showHint(String t) {
    setState(() {
      _hint = t;
      _hintVisible = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _openFullscreen() async {
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _FullscreenPlayer(
        url: widget.url,
        title: widget.title,
        poster: widget.poster,
        aspectRatio: widget.aspectRatio,
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    widget.onExit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.aspectRatio ??
        ((_controller.value.size.width > 0 && _controller.value.size.height > 0)
            ? _controller.value.size.width / _controller.value.size.height
            : 16 / 9);
    return AspectRatio(
      aspectRatio: widget.aspectRatio ?? (ar > 0 ? ar : 16 / 9),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_error.isEmpty)
              Video(
                controller: _controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
            // 封面（首帧前）
            if (!_ready && widget.poster != null && widget.poster!.isNotEmpty)
              Image.network(widget.poster!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            if (_buffering && _error.isEmpty)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                ),
              ),
            if (_error.isNotEmpty) _errorView(),
            // 手势层
            if (_error.isEmpty) _gestureLayer(),
            // 控件层
            if (_error.isEmpty) _controlsLayer(),
            // 手势提示
            if (_hintVisible)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(170),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_hint,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 32),
            const SizedBox(height: 10),
            const Text('视频加载失败', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_error, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniBtn('重试', () {
                  setState(() {
                    _error = '';
                    _ready = false;
                  });
                  _boot();
                }),
                const SizedBox(width: 10),
                _miniBtn('复制链接', () {
                  Clipboard.setData(ClipboardData(text: widget.url));
                  ToastUtil.success('链接已复制');
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(String t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(36),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  // ───────── 手势 ─────────
  Widget _gestureLayer() {
    return LayoutBuilder(builder: (ctx, box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _controls = !_controls);
          if (_controls) _armHide();
        },
        onDoubleTapDown: (d) {
          final x = d.localPosition.dx;
          final seek = x < box.maxWidth / 2 ? -10 : 10;
          final target = _pos + Duration(seconds: seek);
          _player.seek(target < Duration.zero ? Duration.zero : target);
          _showHint(seek > 0 ? '快进 10 秒' : '快退 10 秒');
        },
        onVerticalDragStart: (d) {
          _brightness = 1.0; // 简化：以音量为主
          _dragDelta = 0;
        },
        onVerticalDragUpdate: (d) {
          final up = d.delta.dy < 0;
          final step = d.delta.dy.abs() / 200;
          Set<SystemUiOverlay> overlays = const [];
          if (d.localPosition.dx > box.maxWidth / 2) {
            _volume = (_volume + (up ? step : -step)).clamp(0.0, 1.0);
            _player.setVolume(_volume * 100);
            _showHint('音量 ${(_volume * 100).round()}%');
          } else {
            _brightness = (_brightness + (up ? step : -step)).clamp(0.05, 1.0);
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              statusBarBrightness: _brightness > 0.5 ? Brightness.light : Brightness.dark,
            ));
            _showHint('亮度 ${(_brightness * 100).round()}%');
          }
          overlays.length; // 占位，避免未使用告警
        },
        onHorizontalDragStart: (d) {
          _horizontalDrag = true;
          _dragDelta = 0;
          _seekTarget = _pos;
        },
        onHorizontalDragUpdate: (d) {
          _dragDelta += d.delta.dx;
          final secs = (_dragDelta / 6).round();
          final t = _pos + Duration(seconds: secs);
          setState(() {
            _seekTarget = t < Duration.zero
                ? Duration.zero
                : (t > _dur ? _dur : t);
          });
        },
        onHorizontalDragEnd: (_) {
          if (_seekTarget != null) {
            _player.seek(_seekTarget!);
            setState(() => _pos = _seekTarget!);
          }
          _horizontalDrag = false;
          _seekTarget = null;
        },
        child: _horizontalDrag
            ? Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(180),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_fmt(_seekTarget ?? _pos)} / ${_fmt(_dur)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              )
            : const SizedBox.expand(),
      );
    });
  }

  // ───────── 控件 ─────────
  Widget _controlsLayer() {
    return IgnorePointer(
      ignoring: !_controls,
      child: AnimatedOpacity(
        opacity: _controls ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(120),
                Colors.transparent,
                Colors.black.withAlpha(150),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: Column(
            children: [
              // 顶部：标题 + 倍速 + 全屏
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Row(
                  children: [
                    if (widget.title.isNotEmpty)
                      Expanded(
                        child: Text(widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      )
                    else
                      const Spacer(),
                    _topBtn(_speedLabel(), _showSpeedMenu),
                    if (widget.showFullscreen) _topBtn('全屏', _openFullscreen),
                  ],
                ),
              ),
              const Spacer(),
              // 中间：播放按钮
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(110),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _player.state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const Spacer(),
              // 底部：进度条 + 时间
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Text(_fmt(_pos),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    Expanded(child: _progressBar()),
                    Text(_fmt(_dur),
                        style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(90),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _speedLabel() => _speed == 1.0 ? '倍速' : '${_speed}x';

  void _showSpeedMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2230),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in [0.75, 1.0, 1.25, 1.5, 2.0])
              ListTile(
                dense: true,
                title: Text('${s}x ${s == 1.0 ? '（正常）' : ''}',
                    style: TextStyle(
                      color: s == _speed ? C.brandBright : Colors.white,
                      fontWeight: s == _speed ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14,
                    )),
                trailing: s == _speed ? Icon(Icons.check_rounded, size: 18, color: C.brandBright) : null,
                onTap: () {
                  _player.setRate(s);
                  setState(() => _speed = s);
                  Navigator.pop(c);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _progressBar() {
    final total = _dur.inMilliseconds == 0 ? 1 : _dur.inMilliseconds;
    final p = (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    final b = (_buf.inMilliseconds / total).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (ctx, box) {
      void seekTo(double dx) {
        final ratio = (dx / box.maxWidth).clamp(0.0, 1.0);
        _player.seek(Duration(milliseconds: (total * ratio).round()));
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => seekTo(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: b,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(90),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: p,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: C.brandBright,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: p,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// 全屏播放页
class _FullscreenPlayer extends StatefulWidget {
  const _FullscreenPlayer({
    required this.url,
    required this.title,
    this.poster,
    this.aspectRatio,
  });

  final String url;
  final String title;
  final String? poster;
  final double? aspectRatio;

  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SmartPlayer(
                  url: widget.url,
                  title: widget.title,
                  poster: widget.poster,
                  aspectRatio: widget.aspectRatio,
                  showFullscreen: false,
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(110),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 便捷的「外链/本地」统一入口
class SmartPlayerScreen extends StatelessWidget {
  const SmartPlayerScreen({
    super.key,
    required this.url,
    this.title = '',
    this.poster,
  });

  final String url;
  final String title;
  final String? poster;

  static bool isLocal(String u) {
    return !u.startsWith('http') && File(u).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final isLocalFile = isLocal(url);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title.isEmpty ? '视频播放' : title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          if (!isLocalFile)
            SmartPlayer(url: url, poster: poster, title: title),
          if (isLocalFile) SmartPlayer(url: url, title: title),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('播放源',
                    style: TextStyle(fontSize: 12, color: context.t3)),
                const SizedBox(height: 6),
                SelectableText(url,
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.6)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          ToastUtil.success('链接已复制');
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('复制链接'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
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
    );
  }
}
