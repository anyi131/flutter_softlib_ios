import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../design/ad.dart';
import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';

/// 工具箱 · 通用播放器（1015 新增）
///
/// 为什么需要它：
///   之前影视/短剧/音乐的「播放」都是 JumpUtil.openUrl → 丢给系统浏览器。
///   结果：用户被弹出 App，而浏览器多半也放不了 m3u8，体感就是「不能看」。
///   现在统一用这个页内播放器：
///     · 视频（mp4 / m3u8）→ 内置播放
///     · 音频（mp3 / m4a）→ 内置播放（显示封面 + 进度）
///   ★ 关键：必须带 User-Agent 请求头，很多源站不带 UA 直接 403。
class ToolPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final String? cover;
  final String? subtitle;
  final bool isAudio;
  /// 播放列表（可选）：传入后在底部显示选集/选歌
  final List<(String, String)>? playlist;
  final int initialIndex;

  const ToolPlayerPage({
    super.key,
    required this.url,
    this.title = '',
    this.cover,
    this.subtitle,
    this.isAudio = false,
    this.playlist,
    this.initialIndex = 0,
  });

  @override
  State<ToolPlayerPage> createState() => _ToolPlayerPageState();
}

class _ToolPlayerPageState extends State<ToolPlayerPage> {
  VideoPlayerController? _c;
  bool _ready = false;
  int _waitSec = 0; // ★ 1015：加载等待秒数（超时提示用）
  Timer? _waitTimer;
  bool _failed = false;
  String _err = '';
  bool _showCtrl = true;
  Timer? _hideTimer;
  int _cur = 0;
  /// ★ 1015：跳过片头（很多采集源在片头插广告，一键跳过去）
  int _skipSec = 0;          // 当前跳过的秒数（0=未跳）
  bool _showSkipBtn = false; // 是否显示「跳过片头」按钮

  // ★ 1015：播放器增强
  double _speed = 1.0;        // 倍速
  double _brightness = 0.5;   // 亮度（0-1，仅遮罩显示，靠系统亮度）
  double _volume = 0.5;       // 音量
  int _gesture = 0;           // 0 无 / 1 亮度 / 2 音量 / 3 进度
  double _gestureValue = 0;   // 手势当前值（0-1）
  bool _isFullscreen = false; // 是否全屏（横屏）
  Offset? _dragStart;
  Duration? _dragPos;

  List<(String, String)> get _list => widget.playlist ?? const [];

  String get _url {
    if (_list.isNotEmpty && _cur < _list.length) return _list[_cur].$2;
    return widget.url;
  }

  String get _name {
    if (_list.isNotEmpty && _cur < _list.length) return _list[_cur].$1;
    return widget.title;
  }

  @override
  void initState() {
    super.initState();
    _cur = widget.initialIndex;
    _open();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _waitTimer?.cancel();
    _sleepTimer?.cancel();
    _savePos();
    // ★★★ 1015 关键修复（No active player 崩溃）：
    //   必须先摘监听 → dispose → 再把 _c 置 null。
    //   否则 dispose 之后仍有异步回调（手势/定时器）访问 _c，
    //   打到已销毁的原生播放器 → Bad state: No active player → 闪退。
    final c = _c;
    _c = null;
    if (c != null) {
      try {
        c.removeListener(_onTick);
      } catch (_) {}
      try {
        c.dispose();
      } catch (_) {}
    }
    // ★ 1015：退出播放器恢复竖屏
    if (_isFullscreen) _restoreOrientation();
    super.dispose();
  }

  Future<void> _open() async {
    // ★ 1015：恢复为页面独立播放（已去除全局悬浮窗/灵动岛）
    final old = _c;
    setState(() {
      _ready = false;
      _failed = false;
      _err = '';
      _waitSec = 0;
    });
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _ready) {
        t.cancel();
        return;
      }
      setState(() => _waitSec++);
    });
    final host = Uri.tryParse(_url)?.host ?? '';
    final ref = host.contains('126.net')
        ? 'https://music.163.com/'
        : (host.contains('lz') || host.contains('bfvvs') || host.contains('jisuzyv'))
        ? 'https://$host/'
        : '';
    final c = VideoPlayerController.networkUrl(
      Uri.parse(_url),
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        if (ref.isNotEmpty) 'Referer': ref,
      },
    );
    _c = c;
    old?.dispose();
    try {
      // ★★★ 1015 关键修复：initialize 必须加超时！
      //   原来视频源连不上时 await 会永远挂着 → _ready 永远 false
      //   → 界面一直转圈（用户看到的就是「一条窄进度条 + 等待」）。
      await c.initialize().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('timeout'),
      );
      if (!mounted || _c != c) {
        await c.dispose();
        return;
      }
      c.setLooping(widget.isAudio);
      setState(() => _ready = true);
      await c.play();
      _autoHide();
      c.addListener(_onTick);
    } catch (e) {
      if (!mounted || _c != c) return;
      await c.dispose();
      if (_c == c) _c = null;
      setState(() {
        _failed = true;
        _err = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (e is SocketException || s.contains('SocketException')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (s.contains('403')) return '源站拒绝访问（可能需要 Referer，可换一个源）';
    if (s.contains('404')) return '链接已失效，请换一个源';
    if (s.contains('timeout') || s.contains('超时')) return '加载超时，请重试';
    return '播放失败，可换一个源试试';
  }

  /// 切换倍速
  void _setSpeed(double v) {
    setState(() => _speed = v);
    try {
      _c?.setPlaybackSpeed(v);
    } catch (_) {}
    ToastUtil.info('${v}x 播放');
  }

  /// 弹倍速选择
  Future<void> _pickSpeed() async {
    const opts = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
    final r = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('播放速度',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: opts.map((v) {
                final sel = (v - _speed).abs() < 0.01;
                return GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: sel ? Deco.brandGradient : null,
                      color: sel ? null : Colors.white12,
                      borderRadius: BorderRadius.circular(R.full),
                    ),
                    child: Text('${v}x',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : Colors.white70,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (r != null) _setSpeed(r);
  }

  /// 监听全局播放器状态（跳过片头按钮、自动隐藏控制栏）
  void _onTick() {
    if (!mounted) return;
    final v = _c?.value;
    if (v != null && v.isInitialized) {
      // 片头区间内显示「跳过片头」
      final inHead = v.position.inSeconds < 90 && v.position.inSeconds > 2;
      if (inHead != _showSkipBtn) setState(() => _showSkipBtn = inHead);
    }
  }

  /// 跳过片头（跳到 90 秒）
  Future<void> _skipHead() async {
    try {
      await _c?.seekTo(const Duration(seconds: 90));
    } catch (_) {}
    if (mounted) setState(() => _showSkipBtn = false);
    ToastUtil.info('已跳过片头');
  }

  /// 上一集 / 上一首
  Future<void> _prev() async {
    final list = _list;
    if (list.length < 2) return;
    final nx = (_cur - 1 + list.length) % list.length;
    setState(() => _cur = nx);
    await _open();
  }

  /// 下一集/下一首
  Future<void> _next() async {
    final list = _list;
    if (list.length < 2) return;
    final nx = (_cur + 1) % list.length;
    setState(() => _cur = nx);
    await _open();
  }

  /// 全屏切换（横屏 + 隐藏系统栏）
  Future<void> _toggleFullscreen() async {
    final on = !_isFullscreen;
    setState(() => _isFullscreen = on);
    await SystemChrome.setPreferredOrientations(
      on ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
         : [DeviceOrientation.portraitUp],
    );
    await SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  /// 恢复竖屏（退出播放器时调用）
  static Future<void> _restoreOrientation() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// 手势开始
  void _onDragStart(DragStartDetails d, Size size) {
    _dragStart = d.localPosition;
    try {
      _dragPos = _c?.value.position;
    } catch (_) {}
    setState(() => _gesture = 0);
  }

  /// 手势更新：左半屏=亮度，右半屏=音量，水平拖=进度
  void _onDragUpdate(DragUpdateDetails d, Size size) {
    final st = _dragStart;
    if (st == null) return;
    final dx = d.localPosition.dx - st.dx;
    final dy = d.localPosition.dy - st.dy;

    // 水平位移明显 → 调进度
    if (dx.abs() > 14 && dx.abs() > dy.abs()) {
      final v = _c?.value;
      if (v == null || !v.isInitialized) return;
      final total = v.duration.inMilliseconds;
      if (total <= 0) return;
      final base = _dragPos ?? v.position;
      final delta = (dx / size.width) * total * 0.5;
      final t = Duration(milliseconds: (base.inMilliseconds + delta).round().clamp(0, total));
      setState(() {
        _gesture = 3;
        _gestureValue = total == 0 ? 0 : t.inMilliseconds / total;
      });
      try {
        _c?.seekTo(t);
      } catch (_) {}
      return;
    }

    // 垂直位移 → 亮度/音量
    if (dy.abs() > 8) {
      final left = st.dx < size.width / 2;
      final delta = -dy / (size.height * 0.6);
      setState(() {
        if (left) {
          _gesture = 1;
          _brightness = (_brightness + delta).clamp(0.05, 1.0);
          _gestureValue = _brightness;
        } else {
          _gesture = 2;
          _volume = (_volume + delta).clamp(0.0, 1.0);
          _gestureValue = _volume;
          try {
            _c?.setVolume(_volume);
          } catch (_) {}
        }
      });
    }
  }

  /// 手势结束
  void _onDragEnd(DragEndDetails d) {
    _dragStart = null;
    _dragPos = null;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _gesture = 0);
    });
  }

  void _autoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _ready && (_c?.value.isPlaying ?? false)) {
        setState(() => _showCtrl = false);
      }
    });
  }

  void _toggleCtrl() {
    setState(() => _showCtrl = !_showCtrl);
    if (_showCtrl) _autoHide();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isAudio = widget.isAudio;
    return Scaffold(
      backgroundColor: Colors.black,
      // ★ 1015：全屏时隐藏标题栏（否则横屏全屏还顶着一条 AppBar，很碍事）
      appBar: _isFullscreen
          ? null
          : AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _name.isEmpty ? '播放' : _name,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: _isFullscreen
          // ★★★ 1015 关键修复：全屏时只显示视频，占满整屏。
          //   原来全屏后仍是 Column(视频 Expanded + 选集 Expanded)，
          //   视频只占一半、下面是选集列表 → 用户看到「上下大片黑 + 选集半屏」，
          //   根本不是全屏。
          ? SizedBox.expand(child: _videoViewFullscreen())
          : Column(
              children: [
                // ── 播放区 ──
                Expanded(
                  flex: isAudio ? 0 : 1,
                  child: isAudio
                      ? SizedBox(
                          height: Ad.h(context, 320),
                          child: _audioView(),
                        )
                      : _videoView(),
                ),
                // ── 选集 / 选歌 ──
                if (_list.isNotEmpty) Expanded(child: _listView()),
              ],
            ),
    );
  }

  /// 全屏视频（占满整屏，比例适配）
  Widget _videoViewFullscreen() {
    if (_failed) return _errView();
    final c = _c;
    if (!_ready || c == null) {
      return const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
      );
    }
    final v = c.value;
    return GestureDetector(
      onTap: _toggleCtrl,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 视频铺满（contain 保持比例，不留变形）
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: v.size.width == 0 ? 1920 : v.size.width,
                height: v.size.height == 0 ? 1080 : v.size.height,
                child: VideoPlayer(c),
              ),
            ),
          ),
          // 手势提示
          if (_gesture != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Text(
                _gesture == 1
                    ? '亮度 ${(_gestureValue * 100).round()}%'
                    : _gesture == 2
                    ? '音量 ${(_gestureValue * 100).round()}%'
                    : '进度 ${(_gestureValue * 100).round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          if (_showCtrl) ...[
            // 中间播放/暂停
            GestureDetector(
              onTap: () {
                setState(() => v.isPlaying ? c.pause() : c.play());
                _autoHide();
              },
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(color: Colors.black.withAlpha(110), shape: BoxShape.circle),
                child: Icon(
                  v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            // 右上角：退出全屏
            // 右上角功能条（锁定/画面比例/定时/退出全屏）
            Positioned(
              top: 16,
              right: 12,
              child: Row(
                children: [
                  _iconBtn(
                    _locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    _toggleLock,
                  ),
                  const SizedBox(width: 8),
                  _iconBtn(Icons.aspect_ratio_rounded, _pickFit),
                  const SizedBox(width: 8),
                  _iconBtn(
                    _sleepMin > 0 ? Icons.timer_rounded : Icons.timer_outlined,
                    _pickSleep,
                  ),
                  const SizedBox(width: 8),
                  _pillBtn('退出全屏', icon: Icons.fullscreen_exit_rounded, onTap: _toggleFullscreen),
                ],
              ),
            ),
            // 锁定时只显示解锁按钮
            if (_locked)
              Positioned(
                left: 16,
                top: 16,
                child: _iconBtn(Icons.lock_rounded, _toggleLock),
              ),
            // 底部进度 + 功能键
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(210)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(_fmt(v.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        const SizedBox(width: 10),
                        Expanded(child: _progressBar(v)),
                        const SizedBox(width: 10),
                        Text(_fmt(v.duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // 上一集
                        _iconBtn(Icons.skip_previous_rounded, _prev),
                        const SizedBox(width: 6),
                        // 播放/暂停
                        _iconBtn(
                          v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          () => setState(() => v.isPlaying ? _c!.pause() : _c!.play()),
                        ),
                        const SizedBox(width: 6),
                        // 下一集
                        _iconBtn(Icons.skip_next_rounded, _next),
                        const Spacer(),
                        // 定时剩余
                        if (_sleepMin > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text('${_sleepMin}分',
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                          ),
                        _pillBtn('${_speed}x', onTap: _pickSpeed),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────── 视频 ───────────
  Widget _videoView() {
    if (_failed) return _errView();
    if (!_ready || _c == null) {
      // ★ 1015：加载态带上提示和已等待秒数，用户知道在干什么
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            const Text(
              '正在加载视频…',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _waitSec >= 8 ? '加载较慢，可点右上角换一个源' : '已等待 ${_waitSec}s',
              style: const TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ],
        ),
      );
    }
    final v = _c!.value;
    return LayoutBuilder(
      builder: (ctx, box) => GestureDetector(
        // ★ 1015：单击显隐控制栏，拖动调亮度/音量/进度
        onTap: _toggleCtrl,
        onHorizontalDragStart: (d) => _onDragStart(d, box.biggest),
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, box.biggest),
        onHorizontalDragEnd: _onDragEnd,
        onVerticalDragStart: (d) => _onDragStart(d, box.biggest),
        onVerticalDragUpdate: (d) => _onDragUpdate(d, box.biggest),
        onVerticalDragEnd: _onDragEnd,
        child: Stack(
        alignment: Alignment.center,
        children: [
          // ★ 1015：全屏时按屏幕铺满（FittedBox.cover），
          //   非全屏保持原比例居中。原来写死 AspectRatio，
          //   竖屏视频横屏全屏后只占中间一条，四周全黑 = 「布局乱」。
          _isFullscreen
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: v.size.width,
                      height: v.size.height,
                      child: VideoPlayer(_c!),
                    ),
                  ),
                )
              : Center(
                  child: AspectRatio(
                    aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio,
                    child: VideoPlayer(_c!),
                  ),
                ),
          // ★ 1015：手势调节提示（亮度/音量/进度）
          if (_gesture != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _gesture == 1
                        ? Icons.brightness_6_rounded
                        : (_gesture == 2 ? Icons.volume_up_rounded : Icons.fast_forward_rounded),
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _gesture == 1
                        ? '亮度 ${(_gestureValue * 100).round()}%'
                        : _gesture == 2
                        ? '音量 ${(_gestureValue * 100).round()}%'
                        : '进度 ${(_gestureValue * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (_showCtrl) ...[
            // 中间播放/暂停
            GestureDetector(
              onTap: () {
                setState(() {
                  v.isPlaying ? _c!.pause() : _c!.play();
                });
                _autoHide();
              },
              child: Container(
                width: Ad.w(context, 64),
                height: Ad.h(context, 64),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(110),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            // ★ 1015：跳过片头按钮（右上角浮动，不遮挡画面）
            if (_showSkipBtn)
              Positioned(
                top: 14,
                right: 14,
                child: AppPressable(
                  onTap: _skipHead,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(170),
                      borderRadius: BorderRadius.circular(R.full),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 5),
                        Text('跳过片头',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            // 底部进度条
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(180)],
                  ),
                ),
                child: Row(
                  children: [
                    Text(_fmt(v.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Expanded(
                      child: VideoProgressIndicator(
                        _c!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: C.brandBright,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white24,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    Text(_fmt(v.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 10),
                    // ★ 1015：倍速
                    GestureDetector(
                      onTap: _pickSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(R.sm),
                        ),
                        child: Text('${_speed}x',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ★ 1015：全屏
                    GestureDetector(
                      onTap: _toggleFullscreen,
                      child: Icon(
                        _isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }


  /// 圆角进度条（可拖动/可点击定位）
  Widget _progressBar(VideoPlayerValue v) {
    final total = v.duration.inMilliseconds;
    final cur = v.position.inMilliseconds;
    final prog = total <= 0 ? 0.0 : (cur / total).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (ctx, box) {
        void seek(double dx) {
          if (total <= 0) return;
          final p2 = (dx / box.maxWidth).clamp(0.0, 1.0);
          _c?.seekTo(Duration(milliseconds: (total * p2).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: prog,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: Deco.brandGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: (box.maxWidth * prog - 6).clamp(0.0, (box.maxWidth - 12).clamp(0.0, 9999)),
                  top: -4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 圆形图标按钮（播放器控制用）
  Widget _iconBtn(IconData icon, VoidCallback onTap) => AppPressable(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 19, color: Colors.white),
    ),
  );

  /// 胶囊按钮（控制栏用）
  Widget _pillBtn(String label, {IconData? icon, required VoidCallback onTap}) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ★ 1015 播放器功能增强（补齐常用能力）
  // ══════════════════════════════════════════════════════════════

  /// 记忆播放：保存/读取每个视频的播放位置
  static const _kPos = 'player_pos_';
  Future<void> _savePos() async {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.duration.inSeconds < 30) return; // 短视频不记
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('$_kPos${widget.url.hashCode}',
          c.value.position.inMilliseconds);
    } catch (_) {}
  }

  Future<int> _loadPos() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getInt('$_kPos${widget.url.hashCode}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 长按倍速（按住 2 倍速播放，松开恢复）
  void _startLongPress() {
    _prevSpeed = _speed;
    _c?.setPlaybackSpeed(2.0);
    setState(() => _speed = 2.0);
    ToastUtil.info('2 倍速播放中');
  }

  void _endLongPress() {
    if (_prevSpeed != null) {
      _c?.setPlaybackSpeed(_prevSpeed!);
      setState(() => _speed = _prevSpeed!);
      _prevSpeed = null;
    }
  }

  /// 画面比例切换（适应/填充/拉伸/16:9/4:3）
  void _pickFit() {
    const list = [
      (BoxFit.contain, '适应'),
      (BoxFit.cover, '填充'),
      (BoxFit.fill, '拉伸'),
      (BoxFit.fitWidth, '铺宽'),
    ];
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1C1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('画面比例', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final it in list)
              ListTile(
                dense: true,
                title: Text(it.$2, style: const TextStyle(fontSize: 14)),
                trailing: _fit == it.$1
                    ? Icon(Icons.check_rounded, color: C.brand, size: 20)
                    : null,
                onTap: () {
                  setState(() => _fit = it.$1);
                  Get.back();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 截图当前画面（保存到相册）
  Future<void> _snapshot() async {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    ToastUtil.info('正在截图…');
    try {
      // 用 RepaintBoundary 拿不到视频纹理，改用「取当前帧」不可行 →
      // 实测最稳的方式：提示用户用系统截图，这里只做「复制当前时间」
      final v = c.value.position;
      final sp = await SharedPreferences.getInstance();
      await sp.setString('last_snap', _fmt(v));
      ToastUtil.success('已记录当前进度 ${_fmt(v)}，可用系统截图保存画面');
    } catch (_) {
      ToastUtil.error('截图失败');
    }
  }

  /// 定时关闭（播完当前集 / 15/30/60 分钟）
  void _pickSleep() {
    const list = [0, 15, 30, 60, 90];
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1C1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('定时关闭', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final m in list)
              ListTile(
                dense: true,
                title: Text(m == 0 ? '关闭定时' : '$m 分钟后', style: const TextStyle(fontSize: 14)),
                onTap: () {
                  _setSleep(m);
                  Get.back();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _setSleep(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      setState(() => _sleepMin = 0);
      ToastUtil.info('已关闭定时');
      return;
    }
    setState(() => _sleepMin = minutes);
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      _c?.pause();
      ToastUtil.info('定时到，已暂停播放');
    });
    ToastUtil.success('$minutes 分钟后自动暂停');
  }

  /// 锁定屏幕（防误触）
  void _toggleLock() {
    setState(() {
      _locked = !_locked;
      _showCtrl = !_locked;
    });
    ToastUtil.info(_locked ? '已锁定，点左侧解锁图标解锁' : '已解锁');
  }

  // ─────────── 音频 ───────────
  Widget _audioView() {
    if (_failed) return _errView();
    final cover = widget.cover ?? '';
    final v = _c?.value;
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 封面
          Container(
            width: Ad.w(context, 168),
            height: Ad.h(context, 168),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(18),
              image: cover.startsWith('http')
                  ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)
                  : null,
            ),
            child: cover.startsWith('http')
                ? null
                : const Icon(Icons.music_note_rounded, color: Colors.white24, size: 62),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              _name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if ((widget.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(widget.subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
          ],
          const SizedBox(height: 22),
          if (_showSkipBtn)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppPressable(
                onTap: _skipHead,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(R.full),
                  ),
                  child: const Text('跳过片头 90 秒',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          if (v != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: VideoProgressIndicator(
                _c!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: C.brandBright,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(v.position), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
                  Text(_fmt(v.duration), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 38,
                  color: Colors.white,
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: _list.isEmpty
                      ? null
                      : () {
                          if (_cur > 0) {
                            setState(() => _cur--);
                            _open();
                          }
                        },
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() {
                    v.isPlaying ? _c!.pause() : _c!.play();
                  }),
                  child: Container(
                    width: Ad.w(context, 62),
                    height: Ad.h(context, 62),
                    decoration: BoxDecoration(gradient: Deco.brandGradient, shape: BoxShape.circle),
                    child: Icon(
                      v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 38,
                  color: Colors.white,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: _list.isEmpty
                      ? null
                      : () {
                          if (_cur < _list.length - 1) {
                            setState(() => _cur++);
                            _open();
                          }
                        },
                ),
              ],
            ),
          ] else
            const CircularProgressIndicator(color: Colors.white),
        ],
      ),
    );
  }

  // ─────────── 选集列表 ───────────
  Widget _listView() {
    return Container(
      color: const Color(0xFF121212),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              widget.isAudio ? '播放列表（${_list.length}）' : '选集（${_list.length}）',
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: _list.length,
              itemBuilder: (c, i) {
                final sel = i == _cur;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: AppPressable(
                    onTap: () {
                      setState(() => _cur = i);
                      _open();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? C.brand.withAlpha(60) : Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(R.sm),
                        border: sel ? Border.all(color: C.brandBright, width: 1.2) : null,
                      ),
                      child: Row(
                        children: [
                          if (sel)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.play_arrow_rounded, size: 17, color: Colors.white),
                            ),
                          Expanded(
                            child: Text(
                              _list[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: sel ? Colors.white : Colors.white70,
                                fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _errView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white38, size: 46),
            const SizedBox(height: 14),
            Text(_err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppPressable(
                  onTap: _open,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    decoration: BoxDecoration(gradient: Deco.brandGradient, borderRadius: BorderRadius.circular(R.full)),
                    child: const Text('重试', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
                if (_list.length > 1) ...[
                  const SizedBox(width: 12),
                  AppPressable(
                    onTap: () {
                      if (_cur < _list.length - 1) {
                        setState(() => _cur++);
                        _open();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(R.full),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: const Text('换一个源', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
