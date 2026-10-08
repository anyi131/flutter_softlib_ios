import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/post_service.dart';
import '../design/ui.dart';

/// 动态视频播放器
///
/// 两种来源：
///   file   —— 直链视频（本地上传 mp4 / 抖音解析出的 mp4），用 video_player 内嵌播放
///   iframe —— 分享链接解析后的播放页（B站/YouTube），用 WebView 内嵌
///
/// ★ v40 优化（用户反馈「视频太大、加载太慢」）：
///   1. 尺寸可控：默认按 16:9 + 最大高度限制，不再无限撑高；
///      有宽高信息时按真实比例自适应（横屏视频不会变成巨型竖条）。
///   2. 懒加载：列表里默认只显示「封面 + 播放按钮」，
///      用户点了才真正初始化播放器（避免滚动时同时拉多个视频流）。
///   3. 封面占位：加载前显示封面图，视觉上不再空白/跳动。
class PostVideoPlayer extends StatefulWidget {
  final String url;
  final String type;

  /// 动态 id（直链过期时用原始链接重新解析，v52g #2）
  final int postId;
  final String source;

  /// 封面（可选，抖音解析结果会带）
  final String cover;

  /// 视频宽高（可选，用于按真实比例显示）
  final int videoWidth;
  final int videoHeight;

  /// 最大高度限制（默认 360，避免竖屏视频占满整屏）
  final double maxHeight;

  /// true = 列表态：默认不自动加载，点击后才播放
  final bool lazy;

  const PostVideoPlayer({
    super.key,
    required this.url,
    this.type = 'file',
    this.postId = 0,
    this.source = '',
    this.cover = '',
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.maxHeight = 360,
    this.lazy = false,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  WebViewController? _web;
  bool _ready = false;
  bool _failed = false;
  String _err = '';
  // v52g #2：直链可变（过期刷新后替换）
  late String _url = widget.url;
  late String _cover = widget.cover;
  bool _refreshed = false;

  /// 是否已「激活」（懒加载模式下点击后才 true）
  bool _activated = false;
  // v52f #5：静音开关 + 控制条显隐
  bool _muted = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.url.isEmpty) {
      _failed = true;
      return;
    }
    // 懒加载模式：先不初始化，等用户点击
    if (widget.lazy) {
      _activated = false;
    } else {
      _activated = true;
      _boot();
    }
  }

  void _boot() {
    if (widget.type == 'iframe') {
      _initWeb();
    } else {
      _initFile();
    }
  }

  void _activate() {
    if (_activated) return;
    setState(() {
      _activated = true;
      _failed = false;
      _err = '';
    });
    _boot();
  }

  void _initWeb() {
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
          onWebResourceError: (e) {
            // 只把「主文档」的错误当失败，子资源(图片/统计)失败忽略
            if (e.isForMainFrame != false && mounted) {
              setState(() {
                _failed = true;
                _err = e.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    _web = c;
  }

  Future<void> _initFile() async {
    try {
      // ★ UA 头：部分 CDN 无 UA 直接 403；用 _url（刷新后可变）
      final c = VideoPlayerController.networkUrl(
        Uri.parse(_url),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
        },
      );
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _ready = true;
      });
      c.setLooping(true);
      await c.play();
    } catch (e) {
      // v52g #2：直链过期（抖音等有时效）→ 用原始链接重新解析一次再试
      if (mounted &&
          !_refreshed &&
          widget.postId > 0 &&
          widget.source.isNotEmpty) {
        _refreshed = true;
        try {
          final r = await PostService.instance.videoRefresh(widget.postId);
          final nu = (r['url'] ?? '').toString();
          if (nu.isNotEmpty && mounted) {
            setState(() {
              _url = nu;
              if ((r['cover'] ?? '').toString().isNotEmpty) {
                _cover = (r['cover']).toString();
              }
              _failed = false;
              _err = '';
            });
            await _initFile();
            return;
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _failed = true;
          _err = '视频加载失败';
        });
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _armHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
    setState(() => _showControls = true);
    _armHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  /// 计算显示宽高比（优先真实宽高，兜底 16:9）
  double get _aspect {
    if (widget.videoWidth > 0 && widget.videoHeight > 0) {
      return widget.videoWidth / widget.videoHeight;
    }
    final c = _controller;
    if (c != null && c.value.isInitialized && c.value.aspectRatio > 0) {
      return c.value.aspectRatio;
    }
    return 16 / 9;
  }

  /// 是否竖屏视频（竖屏要更克制，否则又高又大）
  bool get _isPortrait => _aspect < 1;

  @override
  Widget build(BuildContext context) {
    if (_failed) return _fallback();

    // 懒加载：未激活时显示封面 + 播放按钮
    if (!_activated) return _coverPoster();

    if (!_ready) {
      return _shell(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.cover.isNotEmpty)
              CachedNetworkImage(imageUrl: widget.cover, fit: BoxFit.cover),
            Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.type == 'iframe') {
      return _shell(
        maxHeight: widget.maxHeight,
        child: SizedBox(
          height: widget.maxHeight,
          width: double.infinity,
          child: WebViewWidget(controller: _web!),
        ),
      );
    }

    final c = _controller!;
    final pos = c.value.position;
    final dur = c.value.duration;
    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$sec';
    }

    return _shell(
      maxHeight: widget.maxHeight,
      child: AspectRatio(
        aspectRatio: _aspect <= 0 ? 16 / 9 : _aspect,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            // 单击 = 控制条显隐；双击 = 播放/暂停（v52f #5）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _showControls = !_showControls);
                if (_showControls) _armHide();
              },
              onDoubleTap: _togglePlay,
            ),
            // 居中播放键（暂停时）
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: (!c.value.isPlaying || _showControls) ? 1 : 0,
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(90),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    c.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // 控制条：静音 + 进度 + 时长
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showControls ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xD9000000), Color(0x00000000)],
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          c.setVolume(_muted ? 1.0 : 0.0);
                          setState(() => _muted = !_muted);
                        },
                        child: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: C.brandBright,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white10,
                          ),
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${fmt(pos)}/${fmt(dur)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 统一外壳：限高 + 圆角，竖屏视频给更矮的上限
  Widget _shell({required Widget child, double? maxHeight}) {
    final limit = maxHeight ?? widget.maxHeight;
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: limit),
        child: child,
      ),
    );
  }

  /// 懒加载态：封面 + 播放按钮（点击后才加载视频）
  Widget _coverPoster() {
    // 竖屏视频给更矮的封面高度，避免列表里一大块
    final h = _isPortrait ? 220.0 : (widget.maxHeight * 0.62);
    return GestureDetector(
      onTap: _activate,
      child: _shell(
        maxHeight: h,
        child: SizedBox(
          height: h,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_cover.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: _cover,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black12),
                  errorWidget: (_, __, ___) => Container(color: Colors.black26),
                )
              else
                Container(color: Colors.black26),
              // 播放按钮
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
              // 底部提示
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xAA000000), Color(0x00000000)],
                    ),
                  ),
                  child: const Text(
                    '点击播放视频',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 播放失败兜底：给出可点开的链接，不让用户看到空白
  Widget _fallback() {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(20),
        borderRadius: BorderRadius.circular(R.sm),
        border: Border.all(color: C.stroke),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_off_outlined, color: C.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '视频无法播放',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _err.isEmpty ? '该链接可能已失效' : _err,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _failed = false;
                _err = '';
                _activated = true;
              });
              _boot();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
