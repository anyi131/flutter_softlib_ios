import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

/// ★ 1016：媒体内核适配层（better_player / ExoPlayer · AVPlayer）
///
/// 为什么不用 media_kit：libmpv 单架构就 +40MB，包体 27MB → 66MB。
/// better_player 直接复用系统播放器（Android ExoPlayer / iOS AVPlayer），
/// 体积几乎不增加，同时支持 HLS、字幕、倍速、Referer/UA 透传。
///
/// 对外保持与 video_player 相同的写法：
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
  }) =>
      MpvValue(
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
  }) =>
      MpvController._(uri.toString(), httpHeaders, loop, autoPlay);

  factory MpvController.file(String path, {bool loop = false}) =>
      MpvController._(path, const {}, loop, true);

  final String _url;
  final Map<String, String> _headers;
  final bool _loop;
  final bool _autoPlay;

  BetterPlayerController? _bc;
  MpvValue value = const MpvValue();
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;
  bool _inited = false;
  double _volume = 1.0;
  double _speed = 1.0;

  BetterPlayerController? get better => _bc;

  Future<void> initialize() async {
    if (_inited) return;
    _inited = true;

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      _url,
      headers: _headers.isEmpty ? null : _headers,
      useAsmsSubtitles: false,
      videoFormatHint: null,
    );

    _bc = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: _autoPlay,
        looping: _loop,
        fit: BoxFit.contain,
        aspectRatio: null,
        allowedScreenSleep: false,
        handleLifecycle: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
          enableSkips: false,
          enableFullscreen: false,
          enablePlayPause: false,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    _bc!.addEventsListener((event, data) {
      _sync();
      if (event == BetterPlayerEventType.exception) {
        _set(value.copyWith(hasError: true, errorDescription: '$data'));
      }
      if (event == BetterPlayerEventType.initialized) {
        sizeIfNeeded(_bc?.videoPlayerController?.value);
      }
    });

    // 首帧后标记就绪
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_disposed) _set(value.copyWith(isInitialized: true));
    });
    _set(value.copyWith(isInitialized: true));
    unawaited(setVolume(_volume));
    unawaited(setPlaybackSpeed(_speed));
  }

  /// 尺寸同步（better_player 暴露 videoPlayerController）
  void sizeIfNeeded(dynamic v) {
    try {
      final w = (v?.size?.width ?? 0).toDouble();
      final h = (v?.size?.height ?? 0).toDouble();
      if (w > 0 && h > 0) {
        _set(value.copyWith(
          size: Size(w, h),
          aspectRatio: w / h,
          duration: v.duration ?? value.duration,
        ));
      }
    } catch (_) {}
  }

  void _sync() {
    try {
      final v = _bc?.videoPlayerController?.value;
      if (v == null) return;
      final w = (v.size?.width ?? 0).toDouble();
      final h = (v.size?.height ?? 0).toDouble();
      _set(value.copyWith(
        position: v.position ?? Duration.zero,
        duration: v.duration ?? Duration.zero,
        isPlaying: v.isPlaying ?? false,
        isBuffering: v.isBuffering ?? false,
        isInitialized: true,
        size: (w > 0 && h > 0) ? Size(w, h) : value.size,
        aspectRatio: (w > 0 && h > 0) ? w / h : value.aspectRatio,
      ));
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

  Future<void> play() async => _bc?.play();
  Future<void> pause() async => _bc?.pause();
  Future<void> playOrPause() async =>
      (value.isPlaying ? _bc?.pause() : _bc?.play());
  Future<void> seekTo(Duration d) async => _bc?.seekTo(d);

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    try {
      await _bc?.setVolume(_volume);
    } catch (_) {}
    _set(value.copyWith(volume: _volume));
  }

  Future<void> setPlaybackSpeed(double s) async {
    _speed = s;
    try {
      await _bc?.setSpeed(s);
    } catch (_) {}
    _set(value.copyWith(playbackSpeed: s));
  }

  Future<void> setLooping(bool v) async {
    try {
      _bc?.setLooping(v);
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    _listeners.clear();
    try {
      await _bc?.dispose();
    } catch (_) {}
    _bc = null;
  }
}

/// 画面（对应原来的 VideoPlayer(controller)）
class MpvView extends StatelessWidget {
  const MpvView(this.controller, {super.key, this.fit = BoxFit.contain});

  final MpvController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final bc = controller.better;
    if (bc == null) {
      return const ColoredBox(color: Colors.black);
    }
    return BetterPlayer(controller: bc);
  }
}

/// 兼容旧的进度条组件名
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
    final total = v.duration.inMilliseconds == 0 ? 1 : v.duration.inMilliseconds;
    final p = (v.position.inMilliseconds / total).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (c2, box) {
      void seek(double dx) {
        final r = (dx / box.maxWidth).clamp(0.0, 1.0);
        controller.seekTo(Duration(milliseconds: (total * r).round()));
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: allowScrubbing ? (d) => seek(d.localPosition.dx) : null,
        onHorizontalDragUpdate:
            allowScrubbing ? (d) => seek(d.localPosition.dx) : null,
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
    });
  }
}
