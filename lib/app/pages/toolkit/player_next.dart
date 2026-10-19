import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/ui.dart';
import '../../widgets/mpv_core.dart';

/// ★ 1016：影视播放页（UI 完全重做）
///
/// 旧版：控件全挤在底部一条、纯 Icon、0 动画、err 提示简陋。
/// 新版：顶部栏 / 中央播放键 / 双击侧向箭头 / 竖滑指示器 /
///      横滑时间胶囊 / 细进度条 / 倍速面板 / 完整加载与错误态
class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.url,
    this.title = '',
    this.poster,
    this.episodes = const [],
    this.onSelectEpisode,
  });

  final String url;
  final String title;
  final String? poster;
  final List<(String, String)> episodes;
  final ValueChanged<String>? onSelectEpisode;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  MpvController? _c;
  bool _ready = false;
  bool _failed = false;
  String _err = '';
  bool _controls = true;
  bool _fullscreen = false;
  int _waitSec = 0;
  double _speed = 1.0;
  double _volume = 1.0;

  Timer? _hideTimer;
  Timer? _waitTimer;
  Timer? _tapTimer;

  String _hint = '';
  bool _hintOn = false;
  double _hintValue = 0.5;
  int _hintType = 0;
  Duration? _seekPreview;
  int _tapSide = 0;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _ready = false;
      _failed = false;
      _err = '';
      _waitSec = 0;
    });
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _waitSec++);
    });

    final host = Uri.tryParse(widget.url)?.host ?? '';
    final ref = host.contains('126.net')
        ? 'https://music.163.com/'
        : (host.contains('lz') || host.contains('bfvvs'))
        ? 'https://$host/'
        : '';
    final c = MpvController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        if (ref.isNotEmpty) 'Referer': ref,
      },
    );
    _c = c;
    try {
      await c.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || _c != c) return;
      _waitTimer?.cancel();
      setState(() => _ready = true);
      c.addListener(_onTick);
      _armHide();
    } catch (e) {
      _waitTimer?.cancel();
      if (!mounted || _c != c) return;
      setState(() {
        _failed = true;
        _err = _friendly(e);
      });
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SocketException')) return '网络连接失败，请检查网络后重试';
    if (s.contains('403')) return '源站拒绝访问，可换个播放源试试';
    if (s.contains('404')) return '视频不存在或已下架';
    if (s.toLowerCase().contains('timeout')) return '加载超时，源站可能较慢';
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }

  void _armHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_c?.value.isPlaying ?? false)) {
        setState(() => _controls = false);
      }
    });
  }

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      setState(() => _controls = true);
      _hideTimer?.cancel();
    } else {
      c.play();
      _armHide();
    }
  }

  void _seek(int sec) {
    final c = _c;
    if (c == null) return;
    final t = c.value.position + Duration(seconds: sec);
    c.seekTo(t < Duration.zero ? Duration.zero : t);
    setState(() {
      _tapSide = sec > 0 ? 1 : -1;
      _hint = '${sec > 0 ? '快进' : '快退'} ${sec.abs()} 秒';
      _hintType = 0;
      _hintOn = true;
    });
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _tapSide = 0;
          _hintOn = false;
        });
      }
    });
  }

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      // ★ 1016：竖屏视频（短剧/短视频）全屏时保持竖屏，只有横屏视频才转横屏
      final v = _c?.value;
      final isPortrait = v != null && v.size.height > v.size.width;
      await SystemChrome.setPreferredOrientations(
        isPortrait
            ? [DeviceOrientation.portraitUp]
            : [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
      );
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _waitTimer?.cancel();
    _tapTimer?.cancel();
    _c?.removeListener(_onTick);
    _c?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final v = _c?.value;
    final ar = (v?.aspectRatio ?? 16 / 9);
    return Scaffold(
      backgroundColor: const Color(0xFF07080B),
      body: SafeArea(
        child: _fullscreen
            ? SizedBox.expand(child: _stage(v, true))
            : Column(
                children: [
                  _header(),
                  AspectRatio(
                    aspectRatio: ar <= 0 ? 16 / 9 : ar,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                      child: _stage(v, false),
                    ),
                  ),
                  Expanded(child: _below(v)),
                ],
              ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('播放链接已复制'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(
              Icons.ios_share_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _below(MpvValue? v) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty)
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _chip(Icons.speed_rounded, '${_speed}x'),
              _chip(Icons.volume_up_rounded, '${(_volume * 100).round()}%'),
              if ((v?.duration ?? Duration.zero) > Duration.zero)
                _chip(Icons.schedule_rounded, _fmt(v!.duration)),
            ],
          ),
          if (widget.episodes.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '选集',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in widget.episodes)
                  GestureDetector(
                    onTap: () {
                      widget.onSelectEpisode?.call(e.$2);
                      _boot();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: e.$2 == widget.url
                            ? C.brand.withAlpha(70)
                            : Colors.white.withAlpha(14),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: e.$2 == widget.url
                              ? C.brand
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        e.$1,
                        style: TextStyle(
                          color: e.$2 == widget.url
                              ? Colors.white
                              : Colors.white60,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _stage(MpvValue? v, bool fs) {
    if (_failed) return _errorView();
    if (!_ready || _c == null) return _loadingView();

    return LayoutBuilder(
      builder: (ctx, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_controls) {
              setState(() => _controls = true);
              _armHide();
            } else if (v?.isPlaying ?? false) {
              setState(() => _controls = false);
            }
          },
          onDoubleTapDown: (d) {
            _seek(d.localPosition.dx < box.maxWidth / 2 ? -10 : 10);
          },
          onVerticalDragUpdate: (d) {
            final up = d.delta.dy < 0;
            final step = d.delta.dy.abs() / 220;
            if (d.localPosition.dx > box.maxWidth / 2) {
              _volume = (_volume + (up ? step : -step)).clamp(0.0, 1.0);
              _c?.setVolume(_volume);
              setState(() {
                _hintType = 2;
                _hintValue = _volume;
                _hintOn = true;
              });
            } else {
              setState(() {
                _hintType = 1;
                _hintValue = (_hintValue + (up ? step : -step)).clamp(
                  0.05,
                  1.0,
                );
                _hintOn = true;
              });
            }
          },
          onVerticalDragEnd: (_) => setState(() => _hintOn = false),
          onHorizontalDragStart: (_) =>
              setState(() => _seekPreview = v?.position ?? Duration.zero),
          onHorizontalDragUpdate: (d) {
            final base = _seekPreview ?? v?.position ?? Duration.zero;
            final t =
                base +
                Duration(milliseconds: ((d.primaryDelta ?? 0) * 6).round());
            setState(() {
              _seekPreview = t < Duration.zero ? Duration.zero : t;
              _hintType = 3;
              _hintOn = true;
            });
          },
          onHorizontalDragEnd: (_) {
            if (_seekPreview != null) _c?.seekTo(_seekPreview!);
            setState(() {
              _seekPreview = null;
              _hintOn = false;
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (v != null && v.isInitialized) MpvView(_c!),
              if (_tapSide != 0)
                Align(
                  alignment: _tapSide > 0
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 26),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _tapSide > 0
                          ? Icons.fast_forward_rounded
                          : Icons.fast_rewind_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              if ((v?.isBuffering ?? false) && _ready)
                const Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (_hintOn && _hintType != 0)
                Center(
                  child: _hintType == 3
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(185),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_fmt(_seekPreview ?? Duration.zero)} / ${_fmt(v?.duration ?? Duration.zero)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(170),
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _hintType == 1
                                    ? Icons.light_mode_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${(_hintValue * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              IgnorePointer(
                ignoring: !_controls,
                child: AnimatedOpacity(
                  opacity: _controls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: _controlsLayer(v),
                ),
              ),
              if (_hintOn && _hintType == 0)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(170),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _hint,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _controlsLayer(MpvValue? v) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(110),
            Colors.transparent,
            Colors.black.withAlpha(160),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(60),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                (v?.isPlaying ?? false)
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _progress(v),
                Row(
                  children: [
                    Text(
                      _fmt(v?.position ?? Duration.zero),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' / ${_fmt(v?.duration ?? Duration.zero)}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(140),
                        fontSize: 11.5,
                      ),
                    ),
                    const Spacer(),
                    _iconBtn(Icons.speed_rounded, '${_speed}x', _showSpeed),
                    _iconBtn(Icons.fullscreen_rounded, '', _toggleFullscreen),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(70),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _progress(MpvValue? v) {
    final total = (v?.duration.inMilliseconds ?? 0) == 0
        ? 1
        : v!.duration.inMilliseconds;
    final p = ((v?.position.inMilliseconds ?? 0) / total).clamp(0.0, 1.0);
    final b = 0.0; // video_player 不暴露精确缓冲区间
    return LayoutBuilder(
      builder: (ctx, box) {
        void seekTo(double dx) {
          final r = (dx / box.maxWidth).clamp(0.0, 1.0);
          _c?.seekTo(Duration(milliseconds: (total * r).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => seekTo(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(46),
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
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSpeed() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D26),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                '播放速度',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final s in _speeds)
              ListTile(
                dense: true,
                title: Text(
                  '${s}x',
                  style: TextStyle(
                    color: s == _speed ? C.brandBright : Colors.white,
                    fontSize: 14,
                    fontWeight: s == _speed ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                trailing: s == _speed
                    ? Icon(Icons.check_rounded, size: 18, color: C.brandBright)
                    : null,
                onTap: () {
                  _c?.setPlaybackSpeed(s);
                  setState(() => _speed = s);
                  Navigator.pop(c);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _loadingView() {
    return Container(
      color: const Color(0xFF07080B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.poster != null && widget.poster!.isNotEmpty)
            Image.network(
              widget.poster!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Container(color: Colors.black.withAlpha(150)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '正在加载…',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (_waitSec >= 8) ...[
                  const SizedBox(height: 6),
                  Text(
                    '已等待 $_waitSec 秒，源站较慢',
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Container(
      color: const Color(0xFF07080B),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: C.rose.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_disabled_rounded, color: C.rose, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              '播放失败',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _err,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionBtn('重试', C.brand, _boot),
                const SizedBox(width: 10),
                _actionBtn('复制链接', Colors.white24, () {
                  Clipboard.setData(ClipboardData(text: widget.url));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String t, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: c == Colors.white24 ? Colors.white.withAlpha(26) : c,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
