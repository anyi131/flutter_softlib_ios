import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../design/kit.dart';
import '../../design/ui.dart';
import '../jicun_playback_headers.dart';

/// 即存 · 音频播放页
///
/// 封面 + 标题 + 进度条 + 倍速 + 播放/暂停 + ±15 秒；进页面自动播放。
///
/// ★ 请求头：audioplayers 6.x 的 [UrlSource] 只有 `url` 和 `mimeType`，
///   没有 headers 参数（[AudioPlayer.setSourceUrl] 同样没有）。B 站音频
///   必须带 Referer / UA 才放行，这里照常起播，失败时把该带的头拼在错误页
///   上，说明是服务端限制（见 [_JicunAudioPlayerPageState._headerHint]）。
class JicunAudioPlayerPage extends StatefulWidget {
  const JicunAudioPlayerPage({
    super.key,
    required this.url,
    this.title = '',
    this.cover = '',
  });

  /// 音频直链
  final String url;

  /// 标题，最多两行
  final String title;

  /// 封面地址，空串则显示品牌色占位块
  final String? cover;

  @override
  State<JicunAudioPlayerPage> createState() => _JicunAudioPlayerPageState();
}

class _JicunAudioPlayerPageState extends State<JicunAudioPlayerPage> {
  /// 倍速档位：点一下切下一档，到 1.5 回到 0.75
  static const List<double> _rates = <double>[0.75, 1.0, 1.25, 1.5];

  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];
  Timer? _watchdog;

  bool _loading = true;
  bool _failed = false;
  String _error = '';
  bool _playing = false;

  /// 播完了：位置归零，再按播放要 seek(0) 重来
  bool _completed = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// 拖动中只改本地值，松手才 seek —— 否则播放位置会把拇指拽回去
  bool _dragging = false;
  double _dragMs = 0;

  double _rate = 1.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _cancelSubs();
    final player = _player;
    _player = null;
    if (player != null) {
      // fire-and-forget：退出时播放器可能已处于错误态，dispose 失败不该再抛
      unawaited(player.dispose().catchError((Object _) {}));
    }
    super.dispose();
  }

  void _cancelSubs() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
  }

  Future<void> _init() async {
    _watchdog?.cancel();
    _cancelSubs();
    final old = _player;
    _player = null;
    if (old != null) {
      unawaited(old.dispose().catchError((Object _) {}));
    }
    setState(() {
      _loading = true;
      _failed = false;
      _error = '';
      _playing = false;
      _completed = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    if (widget.url.trim().isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
        _error = '没有可播放的音频地址';
      });
      return;
    }

    final player = AudioPlayer();
    _player = player;
    _bind(player);

    // 20 秒还没 prepared 就先落错误页；底层随后若成功，会自动恢复
    _watchdog = Timer(const Duration(seconds: 20), () {
      if (!mounted || !identical(_player, player) || !_loading) return;
      setState(() {
        _loading = false;
        _failed = true;
        _error = '加载超时，可能是网络太慢或服务端拒绝了请求';
      });
    });

    try {
      // 播完保留音源：默认 ReleaseMode.release 会把资源放掉，再按播放就没声了
      await player.setReleaseMode(ReleaseMode.stop);
      // audioplayers 6.x 只认 url + mimeType，没有 headers 参数
      await player.setSource(UrlSource(widget.url, mimeType: null));
      if (!mounted || !identical(_player, player)) return;
      _watchdog?.cancel();
      setState(() {
        _loading = false;
        _failed = false;
        _error = '';
      });
      await player.resume();
    } catch (error) {
      if (!mounted || !identical(_player, player)) return;
      _watchdog?.cancel();
      setState(() {
        _loading = false;
        _failed = true;
        _error = _friendly(error);
      });
    }
  }

  /// 监听播放器：位置 / 时长 / 播完 / 状态
  void _bind(AudioPlayer player) {
    _subs.add(
      player.onPositionChanged.listen((position) {
        if (!mounted || _dragging || _completed) return;
        setState(() => _position = position);
      }),
    );
    _subs.add(
      player.onDurationChanged.listen((duration) {
        if (!mounted) return;
        setState(() => _duration = duration);
      }),
    );
    _subs.add(
      player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _completed = true;
          _position = Duration.zero;
        });
      }),
    );
    _subs.add(
      player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _completed = true;
            _position = Duration.zero;
          } else if (state == PlayerState.playing) {
            _completed = false;
          }
        });
      }),
    );
  }

  /// 把原始异常翻成人话，B 站这类地址再补一句请求头说明
  String _friendly(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    final String reason;
    if (lower.contains('403') || lower.contains('401')) {
      reason = '服务端拒绝访问（HTTP 403/401）';
    } else if (lower.contains('socket') || lower.contains('connection')) {
      reason = '网络连接失败，请检查网络后重试';
    } else if (lower.contains('timeout') || raw.contains('超时')) {
      reason = '加载超时，请重试';
    } else {
      reason = '请检查网络或链接后重试';
    }
    final hint = _headerHint();
    return hint.isEmpty ? reason : '$reason\n\n$hint';
  }

  /// audioplayers 6.x 不支持自定义请求头，把该带的头显示出来供排查
  String _headerHint() {
    final headers = jicunPlaybackHeaders(widget.url);
    if (headers.isEmpty) return '';
    final lines = headers.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
    return '该地址需要 Referer / User-Agent 请求头，而 audioplayers 6.x 的'
        ' UrlSource 不支持自定义请求头，服务端可能因此拒绝播放（403）：\n$lines';
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null || _loading || _failed) return;
    if (_playing) {
      try {
        await player.pause();
      } catch (_) {
        // 状态由 onPlayerStateChanged 兜底，这里不打断界面
      }
      return;
    }
    final atEnd =
        _completed ||
        (_duration > Duration.zero &&
            _position >= _duration - const Duration(milliseconds: 400));
    if (atEnd) {
      setState(() {
        _completed = false;
        _position = Duration.zero;
      });
      try {
        await player.seek(Duration.zero);
      } catch (_) {
        // 还没准备好时 seek 会失败，resume 之后仍从头播
      }
    }
    try {
      await player.resume();
    } catch (_) {
      // 失败态交给监听器，避免按钮卡在半截
    }
  }

  Future<void> _seekTo(Duration target) async {
    final player = _player;
    if (player == null) return;
    var next = target;
    if (next < Duration.zero) next = Duration.zero;
    if (_duration > Duration.zero && next > _duration) next = _duration;
    setState(() {
      _position = next;
      _completed = false;
    });
    try {
      await player.seek(next);
    } catch (_) {
      // 拖动到还没缓冲好的区间会失败，位置先按本地值显示
    }
  }

  void _skip(int seconds) {
    unawaited(_seekTo(_position + Duration(seconds: seconds)));
  }

  Future<void> _cycleRate() async {
    final previous = _rate;
    final index = _rates.indexOf(previous);
    final next = _rates[(index + 1) % _rates.length];
    setState(() => _rate = next);
    final player = _player;
    if (player == null) return;
    try {
      await player.setPlaybackRate(next);
    } catch (_) {
      // 个别平台不支持变速：退回原档，别让界面显示一个没生效的值
      if (mounted) setState(() => _rate = previous);
    }
  }

  String _fmt(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            child: Column(
              children: [
                _topBar(context),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 自定义顶栏：左返回 + 居中标题（与即存其它页面一致）
  Widget _topBar(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: context.t1,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              '音频播放',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: context.t1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        // 封面同时受宽、高约束：矮屏上先压缩封面，别把控制区顶到屏幕外
        final byWidth = constraints.maxWidth - 88;
        final byHeight = constraints.maxHeight - (compact ? 315 : 340);
        final coverSize =
            math.min(byWidth, byHeight).clamp(104.0, 260.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0.0, constraints.maxHeight - 32),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CoverArt(url: widget.cover ?? '', size: coverSize),
                SizedBox(height: compact ? 16 : 24),
                _titleArea(context),
                SizedBox(height: compact ? 12 : 18),
                if (_failed)
                  _errorArea(context)
                else if (_loading)
                  _loadingArea(context)
                else
                  _controls(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _titleArea(BuildContext context) {
    final title = widget.title.trim();
    final String status;
    if (_loading) {
      status = '准备中';
    } else if (_failed) {
      status = '加载失败';
    } else {
      status = _playing ? '正在播放' : '已暂停';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text(
            title.isEmpty ? '未知音频' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.3,
              color: context.t1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(fontSize: 12, color: context.t3),
          ),
        ],
      ),
    );
  }

  Widget _loadingArea(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        const SizedBox(height: 12),
        Text(
          '音频加载中…',
          style: TextStyle(fontSize: 13, color: context.t3),
        ),
      ],
    );
  }

  Widget _errorArea(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline_rounded, size: 34, color: C.danger),
        const SizedBox(height: 10),
        Text(
          '音频加载失败',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.t1,
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.55, color: context.t3),
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: '重试',
          icon: Icons.refresh_rounded,
          expand: false,
          height: 46,
          onPressed: () => _init(),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    return Column(
      children: [
        _progress(context),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SkipButton(
              forward: false,
              color: context.t2,
              onTap: () => _skip(-15),
            ),
            const SizedBox(width: 22),
            _playButton(context),
            const SizedBox(width: 22),
            _SkipButton(
              forward: true,
              color: context.t2,
              onTap: () => _skip(15),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _speedButton(context),
      ],
    );
  }

  Widget _progress(BuildContext context) {
    final maxMs = _duration > Duration.zero
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final rawMs = (_dragging ? _dragMs : _position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs);
    final enabled = _duration > Duration.zero;
    final shown = _dragging
        ? Duration(milliseconds: _dragMs.round())
        : _position;
    return Column(
      children: [
        // ★ Slider 在高度无界的父级里会撑满整屏，必须显式限高
        SizedBox(
          height: 34,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              min: 0,
              max: maxMs,
              value: rawMs,
              activeColor: C.brand,
              inactiveColor: (context.isDark ? Colors.white : Colors.black)
                  .withAlpha(28),
              onChangeStart: enabled
                  ? (ms) => setState(() {
                      _dragging = true;
                      _dragMs = ms;
                    })
                  : null,
              onChanged: enabled
                  ? (ms) => setState(() => _dragMs = ms)
                  : null,
              onChangeEnd: enabled
                  ? (ms) {
                      setState(() => _dragging = false);
                      unawaited(
                        _seekTo(Duration(milliseconds: ms.round())),
                      );
                    }
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                _fmt(shown),
                style: TextStyle(fontSize: 12, color: context.t3),
              ),
              const Spacer(),
              Text(
                _fmt(_duration),
                style: TextStyle(fontSize: 12, color: context.t3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playButton(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [C.brandBright, C.brand],
          ),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(context.isDark ? 96 : 64),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _speedButton(BuildContext context) {
    return TextButton(
      onPressed: _cycleRate,
      style: TextButton.styleFrom(
        foregroundColor: context.t2,
        minimumSize: const Size(72, 34),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: C.brand.withAlpha(context.isDark ? 70 : 46),
          ),
        ),
      ),
      child: Text(
        '${_rate}x',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 封面：有地址就加载网络图，没有（或加载失败）画品牌色方块 + 音符
class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.12);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: C.brand.withAlpha(context.isDark ? 70 : 40),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: url.isEmpty
            ? _fallback()
            : Image.network(
                url,
                headers: jicunPlaybackHeaders(url),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _fallback(spinner: true),
                errorBuilder: (context, error, stackTrace) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback({bool spinner = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.brandBright, C.brand, C.brandDeep],
        ),
      ),
      child: Center(
        child: spinner
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white70,
                ),
              )
            : Icon(
                Icons.music_note_rounded,
                size: size * 0.32,
                color: Colors.white.withAlpha(235),
              ),
      ),
    );
  }
}

/// 快退 / 快进 15 秒：Material 没有 replay_15 图标，用圆弧箭头 + 数字拼
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.forward,
    required this.color,
    required this.onTap,
  });

  final bool forward;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              forward ? Icons.refresh_rounded : Icons.replay_rounded,
              size: 34,
              color: color,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '15',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
