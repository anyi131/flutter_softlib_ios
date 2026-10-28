import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:flutter_softlib/app/widgets/mpv_core.dart';
import 'package:flutter_softlib/app/pages/toolkit/player_next.dart';

/// 假播放器平台：让真实播放页在没有真机/网络的情况下也能渲染出来
class FakeVideoPlatform extends VideoPlayerPlatform {
  int _next = 0;
  final Map<int, StreamController<VideoEvent>> _ctl = {};
  Duration duration = const Duration(minutes: 4, seconds: 33);
  Duration position = const Duration(minutes: 1, seconds: 8);
  final Set<int> playing = {};

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = ++_next;
    final c = StreamController<VideoEvent>.broadcast();
    var sent = false;
    c.onListen = () {
      if (sent) return;
      sent = true;
      c.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: duration,
        size: const Size(1920, 1080),
      ));
    };
    _ctl[id] = c;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _ctl[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    await _ctl.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async => playing.add(playerId);

  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration pos) async => position = pos;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildView(int playerId) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B3A55), Color(0xFF131A26)],
          ),
        ),
        child: const Center(
          child: Text('VIDEO',
              style: TextStyle(color: Color(0x55FFFFFF), fontSize: 26)),
        ),
      );

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

Future<void> _loadFonts() async {
  final zh = File('/app/fonts/wqy-zenhei.ttc');
  if (zh.existsSync()) {
    final bytes = await zh.readAsBytes();
    final fl = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await fl.load();
  }
  final ic = File(
      '/app/build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
  if (ic.existsSync()) {
    final bytes = await ic.readAsBytes();
    final fl = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await fl.load();
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => MpvController.audioViaVideoForTest = true);
  tearDown(() => MpvController.audioViaVideoForTest = false);

  testWidgets('播放页 · 影视全屏版式', (tester) async {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: VideoPage(
          url: 'https://example.com/a.m3u8',
          title: '偷天父子兵',
          isAudio: false,
          episodes: [
            ('HD中字', 'https://example.com/a.m3u8'),
            ('HD国语', 'https://example.com/b.m3u8'),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, key, '/tmp/p2_video.png');
  });

  testWidgets('播放页 · 音乐唱片版式', (tester) async {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: VideoPage(
          url: 'https://example.com/a.mp3',
          title: '幻听',
          subtitle: '许嵩 · 梦游计',
          episodes: [
            ('幻听', 'https://example.com/a.mp3'),
            ('淘汰', 'https://example.com/b.mp3'),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, key, '/tmp/p2_audio.png');
  });
}
