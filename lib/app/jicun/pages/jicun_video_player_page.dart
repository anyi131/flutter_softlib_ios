import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/mpv_core.dart';
import '../jicun_playback_headers.dart';

/// 即存解析 · 全屏视频播放页
///
/// 黑底 Scaffold，自动播放；中央播放/暂停，底部进度条可拖动 seek，
/// 顶部返回；关闭时 dispose 播放器；加载转圈，失败给错误提示 + 重试。
///
/// ★ 1028 补的几件事（都在真机/渲染测试里出过问题）：
///   · 控制条 3 秒自动隐藏，点画面再叫出来 —— 之前一直压在画面上不动
///   · 缓冲时给转圈：网络卡住时画面停住、没有任何反馈，看起来就是「卡死」
///   · 播完显示重播：之前停在最后一帧，播放键按了没反应（seek 原地）
///   · 全屏按钮切横屏（竖屏视频保持竖屏），退出页面恢复竖屏
///   · 播放中途 403/断流也会走错误页，不再是一块黑屏
class JicunVideoPlayerPage extends StatefulWidget {
  const JicunVideoPlayerPage({super.key, required this.url});

  /// 视频直链（所选清晰度或默认第一条）
  final String url;

  @override
  State<JicunVideoPlayerPage> createState() => _JicunVideoPlayerPageState();
}

class _JicunVideoPlayerPageState extends State<JicunVideoPlayerPage>
    with WidgetsBindingObserver {
  MpvController? _ctrl;
  bool _initialized = false;
  bool _failed = false;
  String _error = '';
  bool _controlsHidden = false;
  bool _fullscreen = false;
  Timer? _hideTimer;

  /// ★ 1028 拖动进度条时用拖动值渲染，否则 _onTick 的播放位置会把拇指拽回去
  bool _dragging = false;
  double _dragMs = 0;

  /// 断点续看：同一链接退出再进，回到上次位置（静态表，页面销毁后仍在）
  static final Map<String, Duration> _resumeMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
  }

  /// 退到后台就暂停：否则锁屏后视频声音还在响
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _savePosition();
      _ctrl?.pause();
      _cancelHide();
      if (mounted) setState(() => _controlsHidden = false);
    }
  }

  void _savePosition() {
    final c = _ctrl;
    if (c == null) return;
    final pos = c.value.position;
    if (pos.inSeconds > 2) _resumeMap[widget.url] = pos;
  }

  Future<void> _initPlayer() async {
    _cancelHide();
    final old = _ctrl;
    if (old != null) {
      old.removeListener(_onTick);
      try {
        await old.dispose();
      } catch (_) {}
      _ctrl = null;
    }
    if (!mounted) return;
    setState(() {
      _initialized = false;
      _failed = false;
      _error = '';
      _controlsHidden = false;
    });
    // ★ 1028：直链播放必须带与解析一致的请求头，B 站缺 referer 会 403
    final ctrl = MpvController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: jicunPlaybackHeaders(widget.url),
    );
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      if (!mounted || _ctrl != ctrl) {
        // 期间用户退出或已重试（controller 被换掉），别再动它
        if (_ctrl != ctrl) {
          try {
            await ctrl.dispose();
          } catch (_) {}
        }
        return;
      }
      // ★ 1016：内核换成 video_player 后需要手动监听才能刷新进度/播放状态
      ctrl.addListener(_onTick);
      final resume = _resumeMap[widget.url];
      if (resume != null && resume < ctrl.value.duration) {
        await ctrl.seekTo(resume);
      }
      setState(() => _initialized = true);
      await ctrl.play();
      _scheduleHide();
    } catch (e) {
      if (!mounted || _ctrl != ctrl) return;
      // ★ 1028：先把界面切到错误态，再释放 controller。
      // 初始化失败时 dispose 自己也可能抛（_creatingCompleter 带错误），
      // 之前写在 setState 前面，一旦抛异常就永远停在转圈。
      setState(() {
        _failed = true;
        _error = _friendly(e);
      });
      if (_ctrl == ctrl) _ctrl = null;
      unawaited(ctrl.dispose().catchError((Object _) {}));
    }
  }

  void _onTick() {
    if (!mounted) return;
    final v = _ctrl?.value;
    // 播放中途出错（403 / 断流 / 解码失败）也要落到错误页，不能只留一块黑屏
    if (v != null && v.hasError && !_failed) {
      _cancelHide();
      setState(() {
        _failed = true;
        _error = _friendly(v.errorDescription);
      });
      _ctrl?.pause();
      return;
    }
    if (_dragging) return;
    setState(() {});
  }

  /// 把原始异常翻成人话
  String _friendly(Object? e) {
    final s = e?.toString() ?? '';
    if (e is SocketException || s.contains('SocketException')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (s.contains('403') || s.contains('404') || s.contains('410')) {
      return '视频链接已失效，可重新解析后再试';
    }
    if (s.toLowerCase().contains('timeout') || s.contains('超时')) {
      return '加载超时，请重试';
    }
    return '视频加载失败，请重试';
  }

  bool get _atEnd {
    final v = _ctrl?.value;
    if (v == null || !v.isInitialized) return false;
    if (v.duration <= const Duration(milliseconds: 500)) return false;
    return v.position >= v.duration - const Duration(milliseconds: 400);
  }

  void _cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  /// 只在「正在播 + 没拖进度 + 没播完」时才自动隐藏，否则控制条该一直留着
  void _scheduleHide() {
    _cancelHide();
    final v = _ctrl?.value;
    if (v == null || !v.isPlaying || _failed || _atEnd) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _controlsHidden = true);
    });
  }

  void _showControls() {
    setState(() => _controlsHidden = false);
    _scheduleHide();
  }

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      // ★ 竖屏短视频（短剧/抖音）全屏时保持竖屏，只有横屏视频才转横屏
      final v = _ctrl?.value;
      final portrait = v != null && v.size.height > v.size.width;
      await SystemChrome.setPreferredOrientations(
        portrait
            ? const [DeviceOrientation.portraitUp]
            : const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
      );
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _scheduleHide();
  }

  @override
  void dispose() {
    _cancelHide();
    _savePosition();
    WidgetsBinding.instance.removeObserver(this);
    final c = _ctrl;
    _ctrl = null;
    if (c != null) {
      c.removeListener(_onTick);
      unawaited(c.dispose().catchError((Object _) {}));
    }
    // 离开播放页一定把方向和系统栏还回去，否则整个 App 停在横屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
    if (_atEnd) {
      // 播完再按：从头再来，否则 seek 到末尾等于没动
      c.seekTo(Duration.zero);
      c.play();
    } else if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    if (mounted) setState(() => _controlsHidden = false);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final v = _ctrl?.value;
    final buffering = _initialized && !_failed && (v?.isBuffering ?? false);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _videoArea(),
          // 点画面：隐藏时叫出控制条，显示时藏起来
          if (_initialized && !_failed)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_controlsHidden) {
                    _showControls();
                  } else {
                    _cancelHide();
                    setState(() => _controlsHidden = true);
                  }
                },
              ),
            ),
          if (buffering)
            const IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // 顶部返回（常显，保证任何状态都退得出去）
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
          // 中央播放 / 暂停 / 重播
          if (_initialized && !_failed && !_controlsHidden) _centerPlayButton(),
          // 底部进度条
          if (_initialized && !_failed && !_controlsHidden) _bottomBar(),
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
        child: MpvView(c),
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
    final v = _ctrl!.value;
    final atEnd = _atEnd;
    // 正在播就不要再压一个看不见的大按钮上去（会吃掉画面中央的点击）
    if (v.isPlaying && !atEnd) return const SizedBox.shrink();
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(110),
            shape: BoxShape.circle,
          ),
          child: Icon(
            atEnd ? Icons.replay_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 40,
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
          child: Builder(
            builder: (context) {
              final v = c.value;
              final pos = _atEnd ? v.duration : v.position;
              final dur = v.duration;
              final maxMs = dur.inMilliseconds.toDouble();
              return Row(
                children: [
                  Text(
                    _fmt(pos),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    // ★ 1028：Slider 在「高度有界」的 Row 里会撑满整行高度
                    // （Slider 的 dry layout 直接取 maxHeight），整条控制条因此
                    // 变成整屏高、进度条和按钮飘到屏幕正中，还挡住画面点击。
                    // 必须显式限高。
                    child: SizedBox(
                      height: 34,
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
                      // ★ 1028 拖动时用 _dragMs 而不是 v.position：
                      // 否则每秒刷新的播放位置会把拇指拽回原处（拖不动/回弹）
                      child: Slider(
                        min: 0,
                        max: maxMs > 0 ? maxMs : 1,
                        value:
                            (_dragging
                                    ? _dragMs
                                    : v.position.inMilliseconds.toDouble())
                                .clamp(0, maxMs > 0 ? maxMs : 1),
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withAlpha(70),
                        onChangeStart: (ms) {
                          _cancelHide();
                          setState(() {
                            _dragging = true;
                            _dragMs = ms;
                          });
                        },
                        onChanged: (ms) => setState(() => _dragMs = ms),
                        onChangeEnd: (ms) {
                          setState(() => _dragging = false);
                          c.seekTo(Duration(milliseconds: ms.round()));
                          _scheduleHide();
                        },
                      ),
                      ),
                    ),
                  ),
                  Text(
                    _fmt(dur),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  IconButton(
                    color: Colors.white,
                    iconSize: 22,
                    onPressed: _togglePlay,
                    icon: Icon(
                      _atEnd
                          ? Icons.replay_rounded
                          : (v.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                    ),
                  ),
                  IconButton(
                    color: Colors.white,
                    iconSize: 22,
                    onPressed: _toggleFullscreen,
                    icon: Icon(
                      _fullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
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
