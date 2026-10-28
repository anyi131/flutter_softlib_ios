// 设置四页 / 图集 / 音频页的真渲染出图（服务器容器里跑，用来肉眼复核版式）
//
// 跑法：docker exec -w /app ftestx bash -lc "cd /app && /flutter/bin/flutter test --no-pub test/render_pages_test.dart"
// 产物：/tmp/pg_*.png，再 docker cp 出来看。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_softlib/app/jicun/jicun_prefs.dart';
import 'package:flutter_softlib/app/jicun/pages/jicun_audio_player_page.dart';
import 'package:flutter_softlib/app/jicun/pages/jicun_auto_paste_page.dart';
import 'package:flutter_softlib/app/jicun/pages/jicun_notify_page.dart';
import 'package:flutter_softlib/app/jicun/pages/jicun_settings_page.dart';
import 'package:flutter_softlib/app/jicun/pages/jicun_storage_page.dart';
import 'package:flutter_softlib/app/jicun/widgets/jicun_gallery.dart';

/// 加载中文字体与图标字体。
///
/// ★ 不能「找不到就跳过」—— 那样出来的图里中文全是方框，而测试照样通过，
/// 看着像渲染成功其实什么都没验证到（2026-10-28 就踩过一次：容器重建后
/// /usr/share/fonts 是只读挂载且没有 wqy，一整天出的图都是豆腐块）。
/// 这里缺字体直接抛，宁可测试红掉。
///
/// ★ 必须用同步读文件：测试跑在 FakeAsync 区里，真正的异步 I/O 永远不完成，
/// 表现是卡在第一例不动（+0 不动、也不报错）。
Future<void> _fonts() async {
  final candidates = <String>[
    '/app/fonts/wqy-zenhei.ttc',
    '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',
  ];
  final cjk = candidates.map(File.new).where((f) => f.existsSync()).firstOrNull;
  if (cjk == null) {
    throw StateError('找不到中文字体，渲染图会全是方框：${candidates.join(' / ')}');
  }
  final bytes = cjk.readAsBytesSync();
  // 'Roboto' 是 Material 默认族名，覆盖它就能让所有没指定族的文字有中文。
  for (final family in <String>['Roboto', 'sans-serif', 'PingFang SC']) {
    final l = FontLoader(family)
      ..addFont(Future<ByteData>.value(bytes.buffer.asByteData()));
    await l.load();
  }
  final icons = File(
    '/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!icons.existsSync()) {
    throw StateError('找不到 MaterialIcons 字体：${icons.path}');
  }
  final l = FontLoader('MaterialIcons')
    ..addFont(
      Future<ByteData>.value(icons.readAsBytesSync().buffer.asByteData()),
    );
  await l.load();
}

Future<void> _render(WidgetTester tester, Widget page, String path) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await JicunPrefs.instance.load();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_fonts);

  testWidgets('设置主页', (tester) async {
    await _render(tester, const JicunSettingsPage(), '/tmp/pg_settings.png');
  });

  testWidgets('存储位置', (tester) async {
    await _render(tester, const JicunStoragePage(), '/tmp/pg_storage.png');
  });

  testWidgets('自动粘贴', (tester) async {
    await _render(tester, const JicunAutoPastePage(), '/tmp/pg_autopaste.png');
  });

  testWidgets('通知管理', (tester) async {
    await _render(tester, const JicunNotifyPage(), '/tmp/pg_notify.png');
  });

  testWidgets('图集画廊', (tester) async {
    await _render(
      tester,
      JicunGalleryPage(
        images: const [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
          'https://example.com/c.jpg',
        ],
        initialIndex: 0,
        onSave: (_) async {},
      ),
      '/tmp/pg_gallery.png',
    );
  });

  testWidgets('在线收听', (tester) async {
    // 测试环境没有 audioplayers 原生实现，EventChannel 会抛
    // MissingPluginException；取走它，页面自身仍可正常绘制（这里只验版式）。
    FlutterError.onError = (FlutterErrorDetails d) {
      if (d.exception.toString().contains('MissingPluginException')) return;
      FlutterError.presentError(d);
    };
    addTearDown(() => FlutterError.onError = FlutterError.presentError);
    await _render(
      tester,
      const JicunAudioPlayerPage(
        url: 'https://example.com/a.m4a',
        title: '这里是一段比较长的音频标题，用来验证两行截断是否正常',
        cover: '',
      ),
      '/tmp/pg_audio.png',
    );
  });
}
