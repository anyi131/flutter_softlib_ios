import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_softlib/app/jicun/pages/jicun_video_player_page.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// 假播放器平台：把「真正播」换成可观测的调用记录，
/// 这样在无真机的测试里也能验证 自动播放 / 请求头 / 拖动 seek / 后台暂停 / 释放。
class FakePlayer extends VideoPlayerPlatform with MockPlatformInterfaceMixin {
  final Map<int, StreamController<VideoEvent>> _events = {};
  final List<Map<String, String>> createdHeaders = <Map<String, String>>[];
  int _nextId = 1;
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;
  Duration? lastSeek;
  Duration position = Duration.zero;

  /// 让 create 抛错，模拟「地址失效 / 初始化失败」
  bool failCreate = false;

  List<int> get ids => _events.keys.toList();

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {
    disposeCalls++;
    await _events.remove(playerId)?.close();
  }

  @override
  Future<int> create(DataSource dataSource) async {
    if (failCreate) {
      throw PlatformException(code: 'unavailable', message: 'boom');
    }
    createdHeaders.add(Map<String, String>.from(dataSource.httpHeaders));
    final id = _nextId++;
    // ★ initialized 必须等真正有人 listen 之后再发：
    // microtask 会在 initialize() 的 await 让出时先跑掉，那时 videoEventsFor 还没订阅，
    // 事件直接丢失 → 页面永远停在「加载中」，Slider 也不会出现（首版测试就是这么全红的）
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
    return id;
  }

  /// 手动给某个播放器发事件（完成 / 缓冲开始 / 缓冲结束）
  void emit(int playerId, VideoEvent event) => _events[playerId]?.add(event);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _events[playerId]?.stream ?? const Stream<VideoEvent>.empty();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playCalls++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls++;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration to) async {
    lastSeek = to;
    position = to;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

void main() {
  late FakePlayer fake;

  setUp(() {
    fake = FakePlayer();
    VideoPlayerPlatform.instance = fake;
  });

  // ★ 每次给不同 URL：页面有「同一链接续播」的静态表，用例复用同一 URL
  // 会让后一个用例从上一个的进度开始，断言就飘了。
  var seq = 0;
  Future<void> pumpPlayer(WidgetTester tester, {String? url}) async {
    final target = url ?? 'https://cdn.example.com/v${seq++}.mp4';
    await tester.pumpWidget(
      MaterialApp(home: JicunVideoPlayerPage(url: target)),
    );
    // 播放器里有 500ms 的进度定时器，pumpAndSettle 永远等不到静止 → 用定量 pump
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('B站视频自动带上 Referer 与桌面 UA', (tester) async {
    await pumpPlayer(tester, url: 'https://upos-sz-mirror.bilivideo.com/x.m4s');
    expect(fake.createdHeaders, isNotEmpty);
    final h = fake.createdHeaders.first;
    expect(h['Referer'], contains('bilibili.com'));
    expect(h['User-Agent'], contains('Mozilla'));
  });

  testWidgets('普通 mp4 不带 B 站头', (tester) async {
    await pumpPlayer(tester);
    expect(fake.createdHeaders.first['Referer'], isNull);
  });

  testWidgets('进入即自动播放', (tester) async {
    await pumpPlayer(tester);
    expect(fake.playCalls, greaterThan(0));
  });

  testWidgets('拖动进度条会 seek 到目标位置', (tester) async {
    await pumpPlayer(tester);
    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    await tester.drag(slider, const Offset(120, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.lastSeek, isNotNull);
    expect(fake.lastSeek!.inSeconds, greaterThan(0));
  });

  testWidgets('退出页面会释放播放器', (tester) async {
    await pumpPlayer(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    // dispose 是 fire-and-forget 的异步链（MpvController.dispose -> VideoPlayerController.dispose
    // -> platform.dispose），要显式把微任务跑完才能观测到
    await tester.runAsync(
      () async => await Future<void>.delayed(Duration.zero),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.disposeCalls, greaterThan(0));
  });

  testWidgets('界面结构：进度条 / 时长 / 播放按钮都在', (tester) async {
    await pumpPlayer(tester);
    expect(find.byType(Slider), findsOneWidget);
    // 假平台时长 100s → 右侧显示 1:40
    expect(find.text('0:00'), findsWidgets);
    expect(find.text('1:40'), findsOneWidget);
    // 页面初始化后自动播放 → 显示暂停图标
    expect(find.byIcon(Icons.pause_rounded), findsWidgets);
    await tester.tap(find.byIcon(Icons.pause_rounded).first);
    await tester.pump();
    expect(fake.pauseCalls, greaterThan(0));
  });

  testWidgets('控制条 3 秒后自动隐藏，点画面又能叫出来', (tester) async {
    await pumpPlayer(tester);
    expect(find.byType(Slider), findsOneWidget);

    await tester.pump(const Duration(seconds: 3, milliseconds: 300));
    expect(find.byType(Slider), findsNothing);

    // 控制条藏起来时点画面 → 重新出现
    await tester.tapAt(const Offset(195, 300));
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);

    // 再点一次 → 收起
    await tester.tapAt(const Offset(195, 300));
    await tester.pump();
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('播放中缓冲时给出转圈反馈', (tester) async {
    await pumpPlayer(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    fake.emit(
      fake.ids.first,
      VideoEvent(eventType: VideoEventType.bufferingStart),
    );
    // 事件是异步投递的：第一帧只是把事件送进 controller，第二帧才重建 UI
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.emit(
      fake.ids.first,
      VideoEvent(eventType: VideoEventType.bufferingEnd),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('播完显示重播，点重播从头开始', (tester) async {
    await pumpPlayer(tester);
    fake.position = const Duration(seconds: 100);
    fake.emit(
      fake.ids.first,
      VideoEvent(eventType: VideoEventType.completed),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.replay_rounded), findsWidgets);

    final before = fake.playCalls;
    await tester.tap(find.byIcon(Icons.replay_rounded).first);
    await tester.pump();
    expect(fake.lastSeek, Duration.zero);
    expect(fake.playCalls, greaterThan(before));
  });

  testWidgets('初始化失败显示错误页，点重试能恢复', (tester) async {
    fake.failCreate = true;
    await pumpPlayer(tester);
    expect(find.text('视频加载失败，请重试'), findsOneWidget);

    fake.failCreate = false;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('全屏按钮请求横屏，竖屏视频保持竖屏', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpPlayer(tester);
    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pump();

    final orientations = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(orientations, isNotEmpty);
    // 假平台画面 1920×1080（横屏）→ 应请求 landscape
    expect(
      orientations.last.arguments,
      contains('DeviceOrientation.landscapeLeft'),
    );
    expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
  });
}
