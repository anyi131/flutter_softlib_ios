import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// ★ 1016：media_kit 内核 + **兼容 video_player API 的壳**
///
/// 目的：项目里几百行播放 UI（手势/倍速/选集/睡眠定时）都基于
/// `VideoPlayerController.value` 的写法。直接换内核改动面太大、容易崩。
/// 这里做一层同形 API：
///
///   final c = MpvController.networkUrl(uri, httpHeaders: {...});
///   await c.initialize();
///   c.value.isPlaying / c.value.position / c.value.duration / c.value.size ...
///   c.play() / pause() / seekTo() / setVolume() / setPlaybackSpeed()
///   MpvView(c)            // 对应原来的 VideoPlayer(c)
///
/// 底层全部走 media_kit（libmpv）：硬解、HLS、mkv、字幕、任意影视源 headers。
class MpvValue {
  const MpvValue({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = const [],
    this.isPlaying = false,
    this.isBuffering = false,
    this.isInitialized = false,
    this.size = Size.zero,
    this.aspectRatio = 16 / 9,
    this.hasError = false,
    this.errorDescription = '',
    double volume = 1.0,
    double playbackSpeed = 1.0,
  })  : volume = volume,
        playbackSpeed = playbackSpeed;

  final Duration position;
  final Duration duration;
  final List<DurationRange> buffered;
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
    List<DurationRange>? buffered,
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
        buffered: buffered ?? this.buffered,
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

/// 与 video_player 的 DurationRange 同名，方便旧代码直接复用
class DurationRange {
  const DurationRange(this.start, this.end);
  final Duration start;
  final Duration end;
}

class MpvController {
  MpvController._(this._url, this._headers, this._loop);

  factory MpvController.networkUrl(
    Uri uri, {
    Map<String, String> httpHeaders = const {},
    bool loop = false,
  }) =>
      MpvController._(uri.toString(), httpHeaders, loop);

  factory MpvController.file(String path, {bool loop = false}) =>
      MpvController._(path, const {}, loop);

  final String _url;
  final Map<String, String> _headers;
  final bool _loop;

  late final Player _player = Player();
  late final VideoController videoController = VideoController(_player);
  final List<StreamSubscription> _subs = [];
  final List<VoidCallback> _listeners = [];

  MpvValue value = const MpvValue();
  bool _initialized = false;
  bool _disposed = false;
  double _volume = 1.0;

  Future<void> initialize() async {
    if (_initialized) return;
    _subs.add(_player.stream.position.listen((v) => _set(value.copyWith(position: v))));
    _subs.add(_player.stream.duration.listen((v) => _set(value.copyWith(duration: v))));
    _subs.add(_player.stream.playing.listen((v) => _set(value.copyWith(isPlaying: v))));
    _subs.add(_player.stream.buffering.listen((v) => _set(value.copyWith(isBuffering: v))));
    _subs.add(_player.stream.width.listen((w) {
      final h = _player.state.height;
      final ww = (w ?? 0).toDouble();
      final hh = (h ?? 0).toDouble();
      _set(value.copyWith(
        size: Size(ww, hh),
        aspectRatio: (ww > 0 && hh > 0) ? ww / hh : 16 / 9,
      ));
    }));
    _subs.add(_player.stream.error.listen((e) {
      if (e.isNotEmpty) {
        _set(value.copyWith(hasError: true, errorDescription: e));
      }
    }));

    try {
      if (_headers.isNotEmpty) {
        final hs = _headers.entries.map((e) => '${e.key}: ${e.value}').join(',');
        await _player.setProperty('http-header-fields', hs);
      }
      await _player.setVolume(_volume * 100);
      await _player.open(Media(_url), play: true);
      await _player.setPlaylistMode(_loop ? PlaylistMode.loop : PlaylistMode.none);
      _initialized = true;
      _set(value.copyWith(isInitialized: true));
    } catch (e) {
      _set(value.copyWith(hasError: true, errorDescription: '$e'));
      rethrow;
    }
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

  bool get isInitialized => _initialized && !_disposed;

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> playOrPause() => _player.playOrPause();
  Future<void> seekTo(Duration d) => _player.seek(d);

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _player.setVolume(_volume * 100);
    _set(value.copyWith(volume: _volume));
  }

  Future<void> setPlaybackSpeed(double s) async {
    await _player.setRate(s);
    _set(value.copyWith(playbackSpeed: s));
  }

  Future<void> setLooping(bool v) =>
      _player.setPlaylistMode(v ? PlaylistMode.loop : PlaylistMode.none);

  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _listeners.clear();
    await _player.dispose();
  }
}

/// 对应原来的 `VideoPlayer(controller)`
class MpvView extends StatelessWidget {
  const MpvView(this.controller, {super.key, this.fit = BoxFit.contain});

  final MpvController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: controller.videoController,
      controls: NoVideoControls,
      fit: fit,
    );
  }
}

/// 对应原来的 `VideoProgressIndicator`（可拖动的进度条）
class VideoProgressColors {
  const VideoProgressColors({
    this.playedColor = const Color(0xFF6200EE),
    this.bufferedColor = const Color(0xFF9E9E9E),
    this.backgroundColor = const Color(0xFFFF0000),
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
    return ListenableBuilder(
      listenable: _MpvNotifier(controller),
      builder: (ctx, _) {
        final v = controller.value;
        final total = v.duration.inMilliseconds == 0 ? 1 : v.duration.inMilliseconds;
        final p = (v.position.inMilliseconds / total).clamp(0.0, 1.0);
        final b = v.buffered.isEmpty
            ? 0.0
            : (v.buffered.last.end.inMilliseconds / total).clamp(0.0, 1.0);
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
                    widthFactor: b,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: colors.bufferedColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
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
      },
    );
  }
}

/// 让 MpvController 能被 ListenableBuilder 使用
class _MpvNotifier extends ChangeNotifier {
  _MpvNotifier(this.c) {
    c.addListener(_onChange);
  }
  final MpvController c;

  void _onChange() => notifyListeners();

  @override
  void dispose() {
    c.removeListener(_onChange);
    super.dispose();
  }
}
