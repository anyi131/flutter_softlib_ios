// 贴底面板（写评论 / 分享海报）真渲染 + 几何断言
//
// 背景：1028 真机截图里评论弹层和海报弹层都是「居中 Dialog + 上下 inset 40」，
// 内容一高就变成悬在中间的卡，底部把详情页的「会员免费下载」整条露出来。
// 这里验证 BottomPanel 贴底、铺满、只圆上角，并且下载栏被完全盖住。
//
// 跑法：docker exec -w /app ftestx bash -lc "cd /app && /flutter/bin/flutter test --no-pub test/render_sheet_test.dart"
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_softlib/app/design/glass.dart';

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

/// 详情页底部的下载栏（截图里被露出来的那一条）
Widget _detailPage({required VoidCallback onOpen}) {
  return Scaffold(
    backgroundColor: const Color(0xFFF4F6FA),
    body: Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 120),
            children: List.generate(
              6,
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(14),
                child: Text('软件介绍段落 ${i + 1}',
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: onOpen,
            child: Container(
              height: 74,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD9A441), Color(0xFFF0C674)],
                ),
              ),
              child: const Text(
                '会员免费下载',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 模拟写评论弹层的高度（真机约 780pt）
Widget _tallContent() {
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('写评论',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(
          children: List.generate(
            5,
            (i) => const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.star_rounded, size: 30, color: Color(0xFFFFC107)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.topLeft,
          child: const Text('说说这个软件用起来怎么样…（至少 5 个字）',
              style: TextStyle(fontSize: 13, color: Color(0xFF9AA3B2))),
        ),
        const SizedBox(height: 30),
        Row(
          children: List.generate(
            8,
            (i) => Container(
              margin: const EdgeInsets.only(right: 8),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF3B6EF5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('发布评论',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(_fonts);

  testWidgets('BottomPanel 贴底铺满，下载栏被完全盖住', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late BuildContext pageCtx;
    final key = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              pageCtx = ctx;
              return _detailPage(onOpen: () {});
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 打开贴底弹层
    showDialog<void>(
      context: pageCtx,
      barrierDismissible: false,
      builder: (_) => BottomPanel(child: _tallContent()),
    );
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byType(PanelSurface));
    // 1) 面板必须一路铺到屏幕底边
    expect(panel.bottom, closeTo(844, 0.5),
        reason: '面板底部 ${panel.bottom} 没贴到屏幕底边 844');
    // 2) 面板顶边在下载栏之上，说明下载栏整条被盖住
    expect(panel.top, lessThan(770),
        reason: '面板顶边 ${panel.top} 低于下载栏顶边 770，仍会露出下载栏');

    // 3) 屏幕最底部（下载栏位置）的命中测试落在弹层里，而不是下载栏
    final result = HitTestResult();
    tester.binding.hitTestInView(
      result,
      const Offset(195, 800),
      tester.view.viewId,
    );
    final panelRender = tester.renderObject(find.byType(PanelSurface));
    var hitPanel = false;
    for (final entry in result.path) {
      if (identical(entry.target, panelRender)) hitPanel = true;
    }
    expect(hitPanel, isTrue, reason: '屏幕底部命中的不是面板，说明底部还漏着页面');

    // 存图
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/sheet_comment.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });

  testWidgets('showGlassDialog(bare:true) 不再套一层玻璃壳', (tester) async {
    late BuildContext pageCtx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            pageCtx = ctx;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    showGlassDialog<void>(
      context: pageCtx,
      bare: true,
      builder: (_) => BottomPanel(child: _tallContent()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PanelSurface), findsOneWidget);
    expect(find.byType(GlassShell), findsNothing,
        reason: 'bare 模式还是套了 GlassShell，就是「两层底」');
  });
}
