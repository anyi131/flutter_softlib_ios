import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import 'lucide.dart';
import 'ui.dart';

/// 1109：正文内联视频卡片（点击进入全屏播放）
class InlineVideoCard extends StatelessWidget {
  final String url;

  const InlineVideoCard({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => VideoBoxPage(url: url)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF10131A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Lz.play,
                size: 46, color: Colors.white.withAlpha(230)),
            Positioned(
              left: 12,
              bottom: 10,
              child: Row(children: [
                Icon(Icons.movie_rounded, size: 12, color: Colors.white.withAlpha(160)),
                const SizedBox(width: 5),
                Text('视频',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withAlpha(170))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全屏视频播放页
class VideoBoxPage extends StatefulWidget {
  final String url;
  const VideoBoxPage({super.key, required this.url});

  @override
  State<VideoBoxPage> createState() => _VideoBoxPageState();
}

class _VideoBoxPageState extends State<VideoBoxPage> {
  VideoPlayerController? _c;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() => _c = c);
      c.play();
    } catch (_) {
      if (mounted) setState(() => _err = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('视频', style: TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: _err
            ? Text('视频加载失败',
                style: TextStyle(color: Colors.white.withAlpha(160)))
            : _c == null
                ? const CircularProgressIndicator(strokeWidth: 2)
                : AspectRatio(
                    aspectRatio: _c!.value.aspectRatio == 0
                        ? 16 / 9
                        : _c!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_c!),
                        VideoProgressIndicator(_c!, allowScrubbing: true),
                        Positioned(
                          bottom: 8,
                          child: IconButton(
                            icon: Icon(
                              _c!.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: Colors.white,
                              size: 42,
                            ),
                            onPressed: () {
                              setState(() {
                                _c!.value.isPlaying ? _c!.pause() : _c!.play();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
