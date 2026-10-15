import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../design/adaptive.dart';
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
  bool _failed = false;
  String _err = '';
  bool _showCtrl = true;
  Timer? _hideTimer;
  int _cur = 0;

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
    _c?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final old = _c;
    setState(() {
      _ready = false;
      _failed = false;
      _err = '';
    });
    // ★ 关键：带上 UA，很多 m3u8 源没 UA 会 403
    final c = VideoPlayerController.networkUrl(
      Uri.parse(_url),
      httpHeaders: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': '',
      },
    );
    _c = c;
    old?.dispose();
    try {
      await c.initialize();
      if (!mounted || _c != c) {
        await c.dispose();
        return;
      }
      c.setLooping(widget.isAudio);
      setState(() => _ready = true);
      await c.play();
      _autoHide();
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
      appBar: AppBar(
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
      body: Column(
        children: [
          // ── 播放区 ──
          Expanded(
            flex: isAudio ? 0 : 1,
            child: isAudio
                ? SizedBox(
                    height: 320,
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

  // ─────────── 视频 ───────────
  Widget _videoView() {
    if (_failed) return _errView();
    if (!_ready || _c == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final v = _c!.value;
    return GestureDetector(
      onTap: _toggleCtrl,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio,
              child: VideoPlayer(_c!),
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
                width: 64,
                height: 64,
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
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
            width: 168,
            height: 168,
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
                    width: 62,
                    height: 62,
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
