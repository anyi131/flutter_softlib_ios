import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:flutter_softlib/app/jicun/pages/jicun_video_player_page.dart';

/// 只负责把播放器「外壳」渲染出来看版式：视频画面用一块渐变假画面代替。
class _FakeVideoValue {
  Duration duration = Duration.zero;
  Size size = Size.zero;
  bool isInitialized = false;
  bool isPlaying = false;
  bool isBuffering = false;
  bool isLooping = false;
  double volume = 1;
  double aspectRatio = 16 / 9;
  Duration position = Duration.zero;
  String? errorDescription;
}

class _FakeVideoPlatform extends VideoPlayerPlatform {
  int _nextId = 1;
  final Map<int, StreamController<VideoEvent>> _events = {};
  final Map<int, _FakeVideoValue> _values = {};
  Duration position = Duration.zero;
  bool failCreate = false;

  List<int> get ids => _events.keys.toList();

  @override
  Future<void> init() async {}

  @override
  Future<int> create(DataSource source) async {
    if (failCreate) {
      throw PlatformException(code: 'unavailable', message: 'boom');
    }
    final id = _nextId++;
    late StreamController<VideoEvent> ctrl;
    ctrl = StreamController<VideoEvent>(
      onListen: () {
        ctrl.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 100),
            size: const Size(1920, 1080),
          ),
        );
      },
    );
    _events[id] = ctrl;
    _values[id] = _FakeVideoValue()
      ..duration = const Duration(seconds: 100)
      ..size = const Size(1920, 1080)
      ..isInitialized = true
      ..aspectRatio = 16 / 9;
    return id;
  }

  void emit(int playerId, VideoEvent event) => _events[playerId]?.add(event);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async => _values[playerId]!.isPlaying = true;

  @override
  Future<void> pause(int playerId) async =>
      _values[playerId]!.isPlaying = false;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration to) async {
    _values[playerId]!.position = to;
    position = to;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildView(int playerId) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B2F3A), Color(0xFF101218)],
      ),
    ),
    child: const Center(
      child: Text('16:9 假画面', style: TextStyle(color: Colors.white38)),
    ),
  );
}

/// 加载中文字体与图标字体；缺任何一个直接抛，别让「全是方框」的图混过去。
Future<void> _loadFonts() async {
  final cjk = <String>[
    '/app/fonts/wqy-zenhei.ttc',
    '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',
    '/usr/share/fonts/noto/NotoSansCJK-Regular.ttc',
  ].map(File.new).where((f) => f.existsSync()).firstOrNull;
  if (cjk == null) throw StateError('找不到中文字体，图里会是方框');
  // ★ 必须用同步读：测试体跑在 FakeAsync 区里，真正的异步 I/O 永远不会完成，
  // 表现就是测试卡在第一例不动（2026-10-28 踩过，卡了 3 分钟 +0）。
  final bytes = cjk.readAsBytesSync();
  for (final family in <String>['Roboto', 'sans-serif', 'PingFang SC']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
  final icon = <String>[
    '/app/fonts/MaterialIcons-Regular.otf',
    '/root/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ].map(File.new).where((f) => f.existsSync()).firstOrNull;
  if (icon == null) throw StateError('找不到 MaterialIcons 字体');
  final ib = icon.readAsBytesSync();
  final il = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(ib.buffer)));
  await il.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render player chrome（播放中）', (tester) async {
    await _loadFonts();
    final fake = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = fake;

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const MaterialApp(
          home: JicunVideoPlayerPage(url: 'https://example.com/r1.mp4'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));
    // 刚打开时控制条是显示的（3 秒后自动收起），这一刻就是用户看到的样子
    await _shot(tester, key, '/tmp/pl_player.png');
  });

  testWidgets('render player chrome（播完重播态）', (tester) async {
    await _loadFonts();
    final fake = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = fake;

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const MaterialApp(
          home: JicunVideoPlayerPage(url: 'https://example.com/r2.mp4'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    fake.position = const Duration(seconds: 100);
    fake.emit(
      fake.ids.first,
      VideoEvent(eventType: VideoEventType.completed),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _shot(tester, key, '/tmp/pl_done.png');
  });

  testWidgets('render player chrome（加载失败态）', (tester) async {
    await _loadFonts();
    final fake = _FakeVideoPlatform()..failCreate = true;
    VideoPlayerPlatform.instance = fake;

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const MaterialApp(
          home: JicunVideoPlayerPage(url: 'https://example.com/r3.mp4'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _shot(tester, key, '/tmp/pl_error.png');
  });
}
