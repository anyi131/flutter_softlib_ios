import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// ★ 1016：媒体内核适配层（video_player / ExoPlayer · AVPlayer）
///
/// 历史：先试过 media_kit（libmpv，+40MB 体积）与 better_player（要求 Dart 3.12+），
/// 两者在本项目环境里都不合适，最终回到 **video_player**：
///   · 零额外原生库 → 包体稳定在 ~27MB
///   · 支持 mp4 / m3u8(HLS) / 主流编码（影视源基本够用）
///
/// 对外保持统一写法（播放页 UI 完全不用改）：
///   c.value.isPlaying / position / duration / size / aspectRatio
///   c.play() / pause() / seekTo() / setVolume() / setPlaybackSpeed()
///   MpvView(c)  ← 画面
class MpvValue {
  const MpvValue({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isInitialized = false,
    this.size = Size.zero,
    this.aspectRatio = 16 / 9,
    this.hasError = false,
    this.errorDescription = '',
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isBuffering;
  final bool isInitialized;
  final Size size;
  final double aspectRatio;
  final bool hasError;
  final String errorDescription;
  final double volume;
  final double playbackSpeed;

  MpvValue copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isBuffering,
    bool? isInitialized,
    Size? size,
    double? aspectRatio,
    bool? hasError,
    String? errorDescription,
    double? volume,
    double? playbackSpeed,
  }) => MpvValue(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    isPlaying: isPlaying ?? this.isPlaying,
    isBuffering: isBuffering ?? this.isBuffering,
    isInitialized: isInitialized ?? this.isInitialized,
    size: size ?? this.size,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    hasError: hasError ?? this.hasError,
    errorDescription: errorDescription ?? this.errorDescription,
    volume: volume ?? this.volume,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
  );
}

class MpvController {
  MpvController._(this._url, this._headers, this._loop, this._autoPlay);

  factory MpvController.networkUrl(
    Uri uri, {
    Map<String, String> httpHeaders = const {},
    bool loop = false,
    bool autoPlay = true,
  }) => MpvController._(uri.toString(), httpHeaders, loop, autoPlay);

  factory MpvController.file(String path, {bool loop = false}) =>
      MpvController._(path, const {}, loop, true);

  final String _url;
  final Map<String, String> _headers;
  final bool _loop;
  final bool _autoPlay;

  VideoPlayerController? _vc;
  MpvValue value = const MpvValue();
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;
  bool _inited = false;
  double _volume = 1.0;
  double _speed = 1.0;

  VideoPlayerController? get video => _vc;

  Future<void> initialize() async {
    if (_inited) return;
    _inited = true;

    final isLocal = !_url.startsWith('http');
    final c = isLocal
        ? VideoPlayerController.file(File(_url))
        : VideoPlayerController.networkUrl(
            Uri.parse(_url),
            httpHeaders: _headers,
          );
    _vc = c;

    c.addListener(_sync);
    try {
      await c.initialize();
      await c.setVolume(_volume);
      await c.setLooping(_loop);
      if (_speed != 1.0) await c.setPlaybackSpeed(_speed);
      if (_autoPlay) await c.play();
      _sync();
    } catch (e) {
      _set(value.copyWith(hasError: true, errorDescription: '$e'));
      rethrow;
    }
  }

  void _sync() {
    final c = _vc;
    if (c == null || _disposed) return;
    try {
      final v = c.value;
      _set(
        value.copyWith(
          position: v.position,
          duration: v.duration,
          isPlaying: v.isPlaying,
          isBuffering: v.isBuffering,
          isInitialized: v.isInitialized,
          size: v.size,
          aspectRatio: (v.aspectRatio == 0 || v.aspectRatio.isNaN)
              ? 16 / 9
              : v.aspectRatio,
          hasError: v.hasError,
          errorDescription: v.errorDescription ?? '',
        ),
      );
    } catch (_) {}
  }

  void _set(MpvValue v) {
    if (_disposed) return;
    value = v;
    for (final cb in List<VoidCallback>.from(_listeners)) {
      try {
        cb();
      } catch (_) {}
    }
  }

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  bool get isInitialized => value.isInitialized && !_disposed;

  Future<void> play() async => _vc?.play();
  Future<void> pause() async => _vc?.pause();
  Future<void> playOrPause() async =>
      (value.isPlaying ? _vc?.pause() : _vc?.play());
  Future<void> seekTo(Duration d) async => _vc?.seekTo(d);

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    try {
      await _vc?.setVolume(_volume);
    } catch (_) {}
    _set(value.copyWith(volume: _volume));
  }

  Future<void> setPlaybackSpeed(double s) async {
    _speed = s;
    try {
      await _vc?.setPlaybackSpeed(s);
    } catch (_) {}
    _set(value.copyWith(playbackSpeed: s));
  }

  Future<void> setLooping(bool v) async {
    try {
      await _vc?.setLooping(v);
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    _listeners.clear();
    final c = _vc;
    _vc = null;
    try {
      c?.removeListener(_sync);
      await c?.dispose();
    } catch (_) {}
  }
}

/// 画面（对应原来的 VideoPlayer(controller)）
class MpvView extends StatelessWidget {
  const MpvView(this.controller, {super.key, this.fit = BoxFit.contain});

  final MpvController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final vc = controller.video;
    if (vc == null || !vc.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return FittedBox(
      fit: fit,
      child: SizedBox(
        width: vc.value.size.width,
        height: vc.value.size.height,
        child: VideoPlayer(vc),
      ),
    );
  }
}

/// 兼容旧的进度条组件
class VideoProgressColors {
  const VideoProgressColors({
    this.playedColor = const Color(0xFF4B5EF5),
    this.bufferedColor = const Color(0xFF9E9E9E),
    this.backgroundColor = const Color(0x33000000),
  });
  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;
}

class VideoProgressIndicator extends StatelessWidget {
  const VideoProgressIndicator(
    this.controller, {
    super.key,
    this.allowScrubbing = false,
    this.colors = const VideoProgressColors(),
    this.padding = const EdgeInsets.all(8),
  });

  final MpvController controller;
  final bool allowScrubbing;
  final VideoProgressColors colors;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final v = controller.value;
    final total = v.duration.inMilliseconds == 0
        ? 1
        : v.duration.inMilliseconds;
    final p = (v.position.inMilliseconds / total).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (c2, box) {
        void seek(double dx) {
          final r = (dx / box.maxWidth).clamp(0.0, 1.0);
          controller.seekTo(Duration(milliseconds: (total * r).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: allowScrubbing ? (d) => seek(d.localPosition.dx) : null,
          onHorizontalDragUpdate: allowScrubbing
              ? (d) => seek(d.localPosition.dx)
              : null,
          child: Padding(
            padding: padding,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: colors.backgroundColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: p,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.playedColor,
                      borderRadius: BorderRadius.circular(2),
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
}
