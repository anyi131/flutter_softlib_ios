import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_softlib/app/api/soft_service.dart';
import 'package:flutter_softlib/app/pages/splash/maintain_page.dart';
import 'package:flutter_softlib/app/pages/splash/splash_page.dart';

/// 假网络：按路径返回 JSON，可设置延迟，用来模拟「配置比倒计时慢」
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.maintain, this.delay = Duration.zero});

  final bool maintain;
  final Duration delay;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final Map<String, dynamic> data;
    if (options.path.contains('config/index')) {
      data = <String, dynamic>{
        'maintain_enable': maintain ? 1 : 0,
        'maintain_text': '系统维护中，请稍后再试',
        'maintain_template': 'engineer',
        'splash_enable': 0,
      };
    } else {
      data = <String, dynamic>{};
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'code': 1, 'msg': 'ok', 'data': data}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 启动开屏页并推进假时钟；逐秒推进，避免依赖单次大跨度 pump 的时序细节
Future<void> _pumpSplash(
  WidgetTester tester, {
  required bool maintain,
  required Duration delay,
}) async {
  SoftService.instance.dio.httpClientAdapter = _FakeAdapter(
    maintain: maintain,
    delay: delay,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: const SplashPage(),
      routes: <String, WidgetBuilder>{
        '/index': (_) => const Scaffold(body: Text('HOME')),
      },
    ),
  );
  await tester.pump(); // initState 里的微任务先跑一拍
  for (var i = 0; i < 9; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // onboard_done=true：否则 _goNext 会跳引导页，测试里没有那个路由
    SharedPreferences.setMockInitialValues(<String, Object>{'onboard_done': true});
    // 加签通道在测试里不存在，给个固定值，避免任何 await 通道的分支卡住
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('softlib/installer'),
      (MethodCall call) async =>
          call.method == 'getSignature' ? 'TESTSIG' : null,
    );
  });

  tearDown(() {
    SoftService.instance.dio.httpClientAdapter = HttpClientAdapter();
  });

  testWidgets('配置比倒计时慢，仍然会进维护页（不会漏判）', (WidgetTester tester) async {
    // 3.6s：倒计时 3s 先结束，配置晚 0.6s 才回来（旧实现这时已经放进了主界面）
    await _pumpSplash(
      tester,
      maintain: true,
      delay: const Duration(milliseconds: 3600),
    );

    expect(find.byType(MaintainPage), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('系统维护中，请稍后再试'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('关闭维护模式可以正常进主界面', (WidgetTester tester) async {
    await _pumpSplash(
      tester,
      maintain: false,
      delay: const Duration(milliseconds: 1200),
    );

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(MaintainPage), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('维护页连点「重新加载」不会漏进主界面', (WidgetTester tester) async {
    // 用户实测：维护页连点几次重试就进主页了（旧的 onReload 直接接 _boot，
    // 重启 3 秒倒计时；倒计时到点 _enter() 就把人送进去了）
    await _pumpSplash(tester, maintain: true, delay: Duration.zero);
    expect(find.byType(MaintainPage), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      final page = tester.widget<MaintainPage>(find.byType(MaintainPage));
      page.onReload();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    // 旧实现在这 8 秒里必然已经 pushReplacement 到 /index
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.byType(MaintainPage), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
