import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/mpv_core.dart';

/// ★ 1028：播放页推翻重做（音乐 / 影视共用一套）
///
/// 旧版的问题：把 16:9 画面钉死在页面顶部，标题、按钮、选集全堆在下面，
/// 屏幕下半截是一整片死黑 —— 影视看着像半成品；音乐更离谱，拿视频壳子套了个黑方块。
///
/// 新版：
///   影视 → 全屏播放器：画面居中铺满，控件浮在画面上，选集走底部抽屉，可一键横屏
///   音乐 → 唱片页式：封面 + 毛玻璃背景 + 大字歌名 + 底部大播放键 + 播放列表抽屉
class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.url,
    this.title = '',
    this.poster,
    this.subtitle = '',
    this.episodes = const [],
    this.onSelectEpisode,
    this.isAudio,
    this.initialIndex = 0,
    this.resolveUrl,
  });

  final String url;
  final String title;
  final String? poster;
  final String subtitle;
  final List<(String, String)> episodes;
  final ValueChanged<String>? onSelectEpisode;

  /// null = 按地址后缀自动判断
  final bool? isAudio;

  /// 起始序号（音乐列表从第 i 首点进来时用）
  final int initialIndex;

  /// 动态取地址（音乐列表只有歌名/歌手，没有每首歌的直链）
  final Future<String> Function(int index)? resolveUrl;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  MpvController? _c;
  bool _inited = false;
  bool _loading = true;
  bool _failed = false;
  String _err = '';

  bool _ui = true;
  Timer? _hide;
  bool _sysLand = false;
  double _speed = 1.0;

  int _idx = 0;
  bool _dragging = false;
  Duration _drag = Duration.zero;

  bool get _isAudio => widget.isAudio ?? _looksAudio(_url);

  /// 当前真正在播的地址。★ 1028：以前是从 episodes[_idx].$2 推出来的，
  /// 音乐列表的第二项是「歌手」→ 结果拿「周杰伦」当 URL 去加载，必然播放失败。
  late String _curUrl = widget.url;
  String get _url => _curUrl;

  String get _epName {
    if (widget.episodes.isEmpty) return '';
    if (_idx < 0 || _idx >= widget.episodes.length) return '';
    return widget.episodes[_idx].$1;
  }

  String get _headline =>
      widget.title.isNotEmpty ? widget.title : (_epName.isNotEmpty ? _epName : '正在播放');

  String get _subline {
    if (widget.subtitle.isNotEmpty) return widget.subtitle;
    if (_epName.isNotEmpty && _epName != widget.title) return _epName;
    return '';
  }

  /// 真实屏幕方向（跟随陀螺仪/系统旋转，不再用按钮状态猜）
  bool get _land => MediaQuery.of(context).orientation == Orientation.landscape;

  @override
  void initState() {
    super.initState();
    _idx = _matchIndex(widget.url);
    // ★ 1028：视频页放开横屏（iOS 需要在 Info.plist 里也声明支持横向）；
    //         音频页保持竖屏，避免封面页横过来变形
    if (_isAudio) {
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _boot();
  }

  int _matchIndex(String u) {
    if (widget.episodes.isEmpty) return 0;
    for (var i = 0; i < widget.episodes.length; i++) {
      if (widget.episodes[i].$2 == u) return i;
    }
    // 音乐列表的 $2 是歌手，匹配不上 → 用调用方给的起始序号
    return widget.initialIndex.clamp(0, widget.episodes.length - 1);
  }

  static bool _looksAudio(String u) {
    final s = u.toLowerCase().split('?').first;
    for (final e in const ['.mp3', '.m4a', '.flac', '.wav', '.aac', '.ogg', '.opus']) {
      if (s.endsWith(e)) return true;
    }
    return false;
  }

  static Map<String, String> _headers(String u) {
    final h = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    };
    final s = u.toLowerCase();
    if (s.contains('bilibili') || s.contains('bilivideo')) {
      h['Referer'] = 'https://www.bilibili.com';
    } else if (s.contains('jisu') || s.contains('lzi') || s.contains('bfvvs') || s.contains('hongniu')) {
      h['Referer'] = Uri.parse(u).origin;
    }
    return h;
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c?.removeListener(_onVal);
    _c?.dispose();
    // 退出播放页一律回到 App 默认竖直方向
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onVal() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _boot() async {
    final old = _c;
    _c = null;
    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
        _inited = false;
        _err = '';
      });
    }
    if (old != null) {
      old.removeListener(_onVal);
      // ★ 先断开监听再销毁：销毁失败的 controller 会抛异常，别让它污染初始化流程
      unawaited(old.dispose().catchError((_) {}));
    }

    final c = MpvController.networkUrl(
      Uri.parse(_url),
      httpHeaders: _headers(_url),
      autoPlay: true,
      audioOnly: _isAudio,
    );
    c.addListener(_onVal);
    _c = c;
    try {
      await c.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || _c != c) return;
      setState(() {
        _inited = true;
        _loading = false;
      });
      if (_speed != 1.0) unawaited(c.setPlaybackSpeed(_speed));
      _armHide();
    } catch (e) {
      if (!mounted || _c != c) return;
      setState(() {
        _failed = true;
        _loading = false;
        _err = '$e';
      });
    }
  }

  void _armHide() {
    _hide?.cancel();
    final v = _c?.value;
    if (v == null || !v.isPlaying) return;
    _hide = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) setState(() => _ui = false);
    });
  }

  void _toggleUi() {
    setState(() => _ui = !_ui);
    if (_ui) _armHide();
  }

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    c.playOrPause();
    setState(() => _ui = true);
    _armHide();
  }

  void _seekBy(int sec) {
    final c = _c;
    if (c == null) return;
    final total = c.value.duration;
    var t = c.value.position + Duration(seconds: sec);
    if (t < Duration.zero) t = Duration.zero;
    if (total > Duration.zero && t > total) t = total;
    c.seekTo(t);
    setState(() {});
    _armHide();
  }

  Future<void> _pick(int i) async {
    if (i < 0 || i >= widget.episodes.length) return;
    String u;
    if (widget.resolveUrl != null) {
      setState(() {
        _idx = i;
        _loading = true;
        _failed = false;
        _err = '';
      });
      try {
        u = await widget.resolveUrl!(i);
      } catch (e) {
        u = '';
      }
      if (!mounted) return;
      if (u.isEmpty) {
        setState(() {
          _loading = false;
          _failed = true;
          _err = '该歌曲暂无可用音源';
        });
        return;
      }
    } else {
      u = widget.episodes[i].$2;
    }
    if (!mounted) return;
    setState(() => _curUrl = u);
    widget.onSelectEpisode?.call(u);
    _boot();
  }

  void _next() => unawaited(_pick(_idx + 1));
  void _prev() => unawaited(_pick(_idx - 1));

  Future<void> _toggleLandscape() async {
    if (_land) {
      await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _armHide();
  }

  void _back() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final tall = _isAudio;
    // ★ 1028：跟着真实方向切系统栏 —— 横屏沉浸、竖屏显示状态栏
    final land = _land;
    if (!tall && land != _sysLand) {
      _sysLand = land;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SystemChrome.setEnabledSystemUIMode(
          land ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
        );
      });
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (tall) _audioBackdrop(),
          if (tall) _audioBody() else _videoBody(),
          _stateLayer(),
        ],
      ),
    );
  }

  // ================= 影视 =================

  Widget _videoBody() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleUi,
      onDoubleTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_c != null && _inited)
            Center(
              child: AspectRatio(
                aspectRatio: _ratio,
                child: MpvView(_c!, fit: BoxFit.contain),
              ),
            ),
          _topBar(),
          _videoControls(),
        ],
      ),
    );
  }

  double get _ratio {
    final r = _c?.value.aspectRatio ?? (16 / 9);
    if (r.isNaN || r <= 0.1) return 16 / 9;
    return r.clamp(0.42, 2.6);
  }

  Widget _topBar() {
    final padTop = MediaQuery.of(context).padding.top;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        ignoring: !_ui,
        child: AnimatedOpacity(
          opacity: _ui ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: Container(
            padding: EdgeInsets.only(top: padTop + 4, left: 2, right: 6, bottom: 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xD9000000), Color(0x00000000)],
              ),
            ),
            child: Row(
              children: [
                _roundBtn(Icons.arrow_back_ios_new_rounded, _back, size: 17),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .2,
                        ),
                      ),
                      if (_subline.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _subline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5),
                          ),
                        ),
                    ],
                  ),
                ),
                _roundBtn(
                  _land ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  _toggleLandscape,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoControls() {
    final v = _c?.value;
    final pos = _dragging ? _drag : (v?.position ?? Duration.zero);
    final dur = v?.duration ?? Duration.zero;
    final padBottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_ui,
        child: AnimatedOpacity(
          opacity: _ui ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: Container(
            padding: EdgeInsets.only(left: 14, right: 14, top: 26, bottom: padBottom + 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xE6000000), Color(0x00000000)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(_fmt(pos), style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11.5)),
                    Expanded(child: _slider(pos, dur)),
                    Text(_fmt(dur), style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _miniBtn(Icons.skip_previous_rounded, _idx > 0 ? _prev : null),
                    const SizedBox(width: 18),
                    _miniBtn(Icons.replay_10_rounded, () => _seekBy(-10)),
                    const SizedBox(width: 10),
                    _playBtn(v?.isPlaying ?? false, 54),
                    const SizedBox(width: 10),
                    _miniBtn(Icons.forward_10_rounded, () => _seekBy(10)),
                    const SizedBox(width: 18),
                    _miniBtn(
                      Icons.skip_next_rounded,
                      _idx + 1 < widget.episodes.length ? _next : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _chip(_speedText, _speedSheet),
                    const Spacer(),
                    if (widget.episodes.isNotEmpty)
                      _chip('选集 · ${_idx + 1}/${widget.episodes.length}', _episodeSheet),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= 音乐 =================

  Widget _audioBackdrop() {
    final p = widget.poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0B0B0F)),
        if (p != null && p.isNotEmpty)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 42, sigmaY: 42),
            child: Image.network(
              p,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        const ColoredBox(color: Color(0xB3000000)),
      ],
    );
  }

  Widget _audioBody() {
    final c = _c;
    final v = c?.value;
    final pos = _dragging ? _drag : (v?.position ?? Duration.zero);
    final dur = v?.duration ?? Duration.zero;
    final padBottom = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: padBottom + 10),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 10, 0),
              child: Row(
                children: [
                  _roundBtn(Icons.keyboard_arrow_down_rounded, _back, size: 26),
                  const Spacer(),
                  _rotatingDot(v?.isPlaying ?? false),
                ],
              ),
            ),
            const Spacer(flex: 2),
            _cover(),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                children: [
                  Text(
                    _headline,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (_subline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _subline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  _slider(pos, dur, thick: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos), style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
                        Text(_fmt(dur), style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _miniBtn(Icons.skip_previous_rounded, _idx > 0 ? _prev : null, size: 32),
                      const SizedBox(width: 34),
                      _playBtn(v?.isPlaying ?? false, 72),
                      const SizedBox(width: 34),
                      _miniBtn(
                        Icons.skip_next_rounded,
                        _idx + 1 < widget.episodes.length ? _next : null,
                        size: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _chip(_speedText, _speedSheet),
                      const SizedBox(width: 10),
                      if (widget.episodes.isNotEmpty)
                        _chip('播放列表 ${_idx + 1}/${widget.episodes.length}', _episodeSheet),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover() {
    final p = widget.poster;
    final playing = _c?.value.isPlaying ?? false;
    final mq = MediaQuery.of(context).size;
    final side = (mq.width - 96).clamp(180.0, 320.0).toDouble();
    return AnimatedScale(
      scale: playing ? 1 : .94,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 18)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: p != null && p.isNotEmpty
            ? Image.network(
                p,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _coverFallback(),
              )
            : _coverFallback(),
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A3A46), Color(0xFF15151B)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, size: 76, color: Color(0x66FFFFFF)),
      ),
    );
  }

  Widget _rotatingDot(bool playing) => AnimatedOpacity(
        opacity: playing ? 1 : .35,
        duration: const Duration(milliseconds: 240),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                size: 13,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                playing ? '播放中' : '已暂停',
                style: const TextStyle(color: Colors.white, fontSize: 10.5),
              ),
            ],
          ),
        ),
      );

  // ================= 共用零件 =================

  Widget _slider(Duration pos, Duration dur, {bool thick = false}) {
    final total = dur.inMilliseconds;
    final cur = total <= 0 ? 0.0 : pos.inMilliseconds.clamp(0, total).toDouble();
    return SizedBox(
      height: 34,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: thick ? 4 : 2.5,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: thick ? 6 : 4.5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: Colors.white,
          inactiveTrackColor: const Color(0x3DFFFFFF),
          thumbColor: Colors.white,
          overlayColor: const Color(0x26FFFFFF),
        ),
        child: Slider(
          min: 0,
          max: total <= 0 ? 1 : total.toDouble(),
          value: total <= 0 ? 0.0 : cur.clamp(0.0, total.toDouble()).toDouble(),
          onChanged: total <= 0
              ? null
              : (x) {
                  setState(() {
                    _dragging = true;
                    _drag = Duration(milliseconds: x.round());
                  });
                },
          onChangeEnd: total <= 0
              ? null
              : (x) {
                  _c?.seekTo(Duration(milliseconds: x.round()));
                  setState(() => _dragging = false);
                  _armHide();
                },
        ),
      ),
    );
  }

  Widget _playBtn(bool playing, double size) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: size * .56,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback? tap, {double size = 26}) {
    return Opacity(
      opacity: tap == null ? .26 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: size, color: Colors.white),
        ),
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback tap, {double size = 20}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle),
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }

  Widget _chip(String text, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
      ),
    );
  }

  Widget _ghostBtn(String text, VoidCallback tap, {bool primary = false}) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? Colors.white : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: primary ? Colors.black : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String get _speedText {
    final s = _speed;
    return s == s.roundToDouble() ? '${s.toStringAsFixed(1)}x' : '${s}x';
  }

  static String _fmt(Duration d) {
    if (d <= Duration.zero) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  // ================= 弹层 =================

  Future<void> _speedSheet() async {
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF14141A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              '播放速度',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final s in const [0.75, 1.0, 1.25, 1.5, 2.0])
              ListTile(
                dense: true,
                title: Text(
                  '${s}x',
                  style: TextStyle(
                    color: s == _speed ? const Color(0xFF6EE7A8) : Colors.white,
                    fontSize: 14,
                  ),
                ),
                trailing: s == _speed
                    ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF6EE7A8))
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _speed = picked);
    await _c?.setPlaybackSpeed(picked);
  }

  Future<void> _episodeSheet() async {
    if (widget.episodes.isEmpty) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF14141A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .58,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Text(
                      _isAudio ? '播放列表' : '选集',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${widget.episodes.length}',
                      style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 11.5),
                    ),
                    const Spacer(),
                    _roundBtn(Icons.close_rounded, () => Navigator.pop(ctx), size: 18),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: widget.episodes.length,
                  itemBuilder: (c, i) {
                    final cur = i == _idx;
                    return ListTile(
                      dense: true,
                      onTap: () => Navigator.pop(ctx, i),
                      leading: SizedBox(
                        width: 26,
                        child: cur
                            ? const Icon(Icons.graphic_eq_rounded,
                                size: 16, color: Color(0xFF6EE7A8))
                            : Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0x59FFFFFF), fontSize: 11.5),
                              ),
                      ),
                      title: Text(
                        widget.episodes[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cur ? const Color(0xFF6EE7A8) : const Color(0xE6FFFFFF),
                          fontSize: 13.5,
                          fontWeight: cur ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != _idx) unawaited(_pick(picked));
  }

  // ================= 状态层 =================

  Widget _stateLayer() {
    if (_failed) {
      return Container(
        color: const Color(0xE6000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Color(0xCCFFFFFF), size: 38),
                const SizedBox(height: 14),
                const Text(
                  '播放失败',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _err.isEmpty ? '音视频源暂时不可用，换一个试试' : _err,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ghostBtn('返回', _back),
                    const SizedBox(width: 12),
                    _ghostBtn('重新加载', _boot, primary: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return IgnorePointer(
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white.withAlpha(210),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
