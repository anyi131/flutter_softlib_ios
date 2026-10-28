// 后台改版真渲染出图：两级导航 / 骨架屏 / 结果条 / 长按菜单
//
// 跑法：docker exec -w /app ftestx bash -lc "cd /app && /flutter/bin/flutter test --no-pub test/render_admin_test.dart"
// 产物：/tmp/ad_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_softlib/app/pages/admin/admin_shell_v2.dart';
import 'package:flutter_softlib/app/pages/admin/admin_ui_kit.dart';

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

Future<void> _render(WidgetTester tester, Widget child, String path) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(key: key, child: MaterialApp(home: child)),
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

/// 骨架屏 + 结果条 + 卡片，拼一屏看留白与密度
class _KitDemo extends StatelessWidget {
  const _KitDemo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AdResultBar(text: '共 72 个 · 关键词「微信」· 已选 2 个筛选'),
          SizedBox(height: 12),
          AdListSkeleton(rows: 3),
          SizedBox(height: 20),
          AdResultBar(text: '共 0 个 · 关键词「不存在的关键词」'),
          SizedBox(height: 12),
          AdEmpty(text: '没有找到相关软件', hint: '换个关键词试试'),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_fonts);

  testWidgets('后台两级导航', (tester) async {
    final tab = TabController(length: 12, vsync: const TestVSync());
    await _render(
      tester,
      AdminShellV2(
        tab: tab,
        onRefresh: () {},
        children: List<Widget>.generate(
          12,
          (i) => Center(child: Text('页面 $i')),
        ),
      ),
      '/tmp/ad_shell.png',
    );
  });

  testWidgets('骨架屏与结果条', (tester) async {
    await _render(tester, const _KitDemo(), '/tmp/ad_kit.png');
  });
}
