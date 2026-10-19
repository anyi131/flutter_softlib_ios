import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../design/app_anim.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_img_isolate.dart';
import 'tool_kit.dart';
import 'tool_pages_image.dart';

// ═══════════════════════════════════════════════════════════════
// 工具箱 · 图片工具第二批（1015）
// ═══════════════════════════════════════════════════════════════

// ─────────────── ⑥ 图片旋转 / 翻转 ───────────────
class ImgRotatePage extends StatefulWidget {
  const ImgRotatePage({super.key});
  @override
  State<ImgRotatePage> createState() => _ImgRotatePageState();
}

class _ImgRotatePageState extends State<ImgRotatePage> with ImgToolMixin {
  int _angle = 0;
  bool _flipH = false;
  bool _flipV = false;

  Future<void> _go() => run(() async {
    var im = img.decodeImage(srcBytes!);
    if (im == null) return null;
    if (_angle != 0) im = img.copyRotate(im, angle: _angle.toDouble());
    if (_flipH) im = img.flipHorizontal(im);
    if (_flipV) im = img.flipVertical(im);
    return Uint8List.fromList(img.encodeJpg(im, quality: 92));
  });

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '旋转翻转',
      subtitle: '任意角度旋转 / 水平垂直翻转',

      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolChips<int>(
            items: const [
              (0, '不旋转'),
              (90, '90°'),
              (180, '180°'),
              (270, '270°'),
            ],
            current: _angle,
            onPick: (v) => setState(() => _angle = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Switch(
                      value: _flipH,
                      activeThumbColor: C.brand,
                      onChanged: (v) => setState(() => _flipH = v),
                    ),
                    Text('水平翻转', style: Ty.small.copyWith(color: context.t2)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Switch(
                      value: _flipV,
                      activeThumbColor: C.brand,
                      onChanged: (v) => setState(() => _flipV = v),
                    ),
                    Text('垂直翻转', style: Ty.small.copyWith(color: context.t2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToolButton(
            label: '应用',
            icon: Icons.rotate_right_rounded,
            onPressed: _go,
          ),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ⑦ 图片圆角 ───────────────
class ImgRoundPage extends StatefulWidget {
  const ImgRoundPage({super.key});
  @override
  State<ImgRoundPage> createState() => _ImgRoundPageState();
}

class _ImgRoundPageState extends State<ImgRoundPage> with ImgToolMixin {
  int _r = 30;
  bool _circle = false;

  // ★ 1015：改到后台 isolate
  Future<void> _go() => run(
    () =>
        ImgJob.run(ImgJobArgs(srcBytes!, mode: 'round', a: _r, flag: _circle)),
  );

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '圆角处理',
      subtitle: '加圆角或裁成圆形（输出 PNG 带透明）',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: [
                  Switch(
                    value: _circle,
                    activeThumbColor: C.brand,
                    onChanged: (v) => setState(() => _circle = v),
                  ),
                  Text('裁成圆形', style: Ty.small.copyWith(color: context.t2)),
                ],
              ),
            ],
          ),
          if (!_circle) ...[
            Text(
              '圆角大小：${(_r * 100 / 400).round()}%',
              style: Ty.small.copyWith(fontWeight: FontWeight.w800),
            ),
            Slider(
              value: _r.toDouble(),
              min: 10,
              max: 200,
              activeColor: C.brand,
              onChanged: (v) => setState(() => _r = v.round()),
            ),
          ],
          ToolButton(
            label: '应用',
            icon: Icons.rounded_corner_rounded,
            onPressed: _go,
          ),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ⑧ 图片马赛克 ───────────────
class ImgMosaicPage extends StatefulWidget {
  const ImgMosaicPage({super.key});
  @override
  State<ImgMosaicPage> createState() => _ImgMosaicPageState();
}

class _ImgMosaicPageState extends State<ImgMosaicPage> with ImgToolMixin {
  int _block = 16;

  // ★ 1015：逐像素处理改到后台 isolate，否则大图会卡死界面
  Future<void> _go() =>
      run(() => ImgJob.run(ImgJobArgs(srcBytes!, mode: 'mosaic', a: _block)));

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '马赛克',
      subtitle: '整图打码（隐私遮挡）',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolChips<int>(
            items: const [(8, '细'), (16, '中'), (32, '粗'), (64, '超粗')],
            current: _block,
            onPick: (v) => setState(() => _block = v),
          ),
          const SizedBox(height: 12),
          ToolButton(
            label: '打马赛克',
            icon: Icons.grid_on_rounded,
            onPressed: _go,
          ),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ⑨ 图片亮度 / 对比度 ───────────────
class ImgAdjustPage extends StatefulWidget {
  const ImgAdjustPage({super.key});
  @override
  State<ImgAdjustPage> createState() => _ImgAdjustPageState();
}

class _ImgAdjustPageState extends State<ImgAdjustPage> with ImgToolMixin {
  int _bright = 0; // -100 ~ 100
  int _contrast = 0;
  int _saturate = 0;

  Future<void> _go() => run(() async {
    var im = img.decodeImage(srcBytes!);
    if (im == null) return null;
    if (_bright != 0) im = img.adjustColor(im, brightness: 1 + _bright / 100);
    if (_contrast != 0) im = img.adjustColor(im, contrast: 1 + _contrast / 100);
    if (_saturate != 0)
      im = img.adjustColor(im, saturation: 1 + _saturate / 100);
    return Uint8List.fromList(img.encodeJpg(im, quality: 92));
  });

  Widget _slider(
    String label,
    int v,
    ValueChanged<int> onCh, {
    int min = -100,
    int max = 100,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(
            '${v > 0 ? '+' : ''}$v',
            style: Ty.small.copyWith(
              color: C.brand,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      Slider(
        value: v.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        activeColor: C.brand,
        onChanged: (x) => setState(() => onCh(x.round())),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '亮度对比度',
      subtitle: '调色（亮度/对比度/饱和度）',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              children: [
                _slider('亮度', _bright, (v) => _bright = v),
                _slider('对比度', _contrast, (v) => _contrast = v),
                _slider('饱和度', _saturate, (v) => _saturate = v),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolButton(label: '应用调整', icon: Icons.tune_rounded, onPressed: _go),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ⑩ 图片转黑白 ───────────────
class ImgGrayPage extends StatefulWidget {
  const ImgGrayPage({super.key});
  @override
  State<ImgGrayPage> createState() => _ImgGrayPageState();
}

class _ImgGrayPageState extends State<ImgGrayPage> with ImgToolMixin {
  int _mode = 0; // 0 灰度 1 黑白二值 2 复古

  Future<void> _go() => run(() async {
    var im = img.decodeImage(srcBytes!);
    if (im == null) return null;
    im = img.grayscale(im);
    if (_mode == 1) {
      for (var y = 0; y < im.height; y++) {
        for (var x = 0; x < im.width; x++) {
          final p = im.getPixel(x, y);
          final v = p.r > 128 ? 255 : 0;
          im.setPixelRgb(x, y, v, v, v);
        }
      }
    } else if (_mode == 2) {
      im = img.sepia(im);
    }
    return Uint8List.fromList(img.encodeJpg(im, quality: 92));
  });

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '黑白复古',
      subtitle: '灰度 / 二值 / 复古怀旧',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolChips<int>(
            items: const [(0, '灰度'), (1, '黑白'), (2, '复古')],
            current: _mode,
            onPick: (v) => setState(() => _mode = v),
          ),
          const SizedBox(height: 12),
          ToolButton(
            label: '应用',
            icon: Icons.filter_b_and_w_rounded,
            onPressed: _go,
          ),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ⑪ 图片缩放到指定尺寸 ───────────────
class ImgResizePage extends StatefulWidget {
  const ImgResizePage({super.key});
  @override
  State<ImgResizePage> createState() => _ImgResizePageState();
}

class _ImgResizePageState extends State<ImgResizePage> with ImgToolMixin {
  final _w = TextEditingController();
  final _h = TextEditingController();
  bool _keep = true;

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    super.dispose();
  }

  Future<void> _go() => run(() async {
    var im = img.decodeImage(srcBytes!);
    if (im == null) return null;
    final nw = int.tryParse(_w.text) ?? im.width;
    final nh = _keep
        ? (nw * im.height / im.width).round()
        : (int.tryParse(_h.text) ?? im.height);
    im = img.copyResize(im, width: nw, height: nh);
    return Uint8List.fromList(img.encodeJpg(im, quality: 92));
  });

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '尺寸调整',
      subtitle: '缩放到指定宽高（可锁定比例）',

      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ToolField(
                  controller: _w,
                  label: '宽度 px',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolField(
                  controller: _h,
                  label: '高度 px',
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Switch(
                value: _keep,
                activeThumbColor: C.brand,
                onChanged: (v) => setState(() => _keep = v),
              ),
              Text(
                '锁定宽高比（按宽度自动算高度）',
                style: Ty.small.copyWith(color: context.t2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ToolButton(
            label: '缩放',
            icon: Icons.photo_size_select_large_rounded,
            onPressed: _go,
          ),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ⑫ 图片信息查看 ───────────────
class ImgInfoPage extends StatefulWidget {
  const ImgInfoPage({super.key});
  @override
  State<ImgInfoPage> createState() => _ImgInfoPageState();
}

class _ImgInfoPageState extends State<ImgInfoPage> with ImgToolMixin {
  Map<String, String> facts = {};

  @override
  void initState() {
    super.initState();
    _pickHook = _readInfo;
  }

  VoidCallback? _pickHook;

  Future<void> _readInfo() async {
    final b = srcBytes;
    if (b == null) return;
    final im = img.decodeImage(b);
    final f = <String, String>{};
    f['格式'] = _sniff(b);
    if (im != null) {
      f['尺寸'] = '${im.width} × ${im.height}';
      f['宽高比'] = (im.width / im.height).toStringAsFixed(3);
      f['通道'] = '${im.numChannels}';
      f['像素总数'] = _withComma(im.width * im.height);
    }
    f['文件大小'] = '${(b.length / 1024).toStringAsFixed(1)} KB';
    f['文件大小(MB)'] = (b.length / 1048576).toStringAsFixed(3);
    if (mounted) setState(() => facts = f);
  }

  static String _withComma(int n) {
    final s = n.toString();
    final sb = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write(',');
      sb.write(s[i]);
    }
    return sb.toString();
  }

  static String _sniff(Uint8List b) {
    if (b.length < 4) return '未知';
    if (b[0] == 0xFF && b[1] == 0xD8) return 'JPEG';
    if (b[0] == 0x89 && b[1] == 0x50) return 'PNG';
    if (b[0] == 0x47 && b[1] == 0x49) return 'GIF';
    if (b[0] == 0x42 && b[1] == 0x4D) return 'BMP';
    if (b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57) return 'WEBP';
    return '未知';
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '图片信息',
      subtitle: '查看尺寸 / 格式 / 体积',

      child: Column(
        children: [
          ToolCard(
            onTap: () async {
              await pickImage();
              await _readInfo();
            },
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 22, color: C.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    srcBytes == null ? '点击选择图片' : '已选图片 · 点击重选',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.t1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ToolCard(
              child: Column(
                children: facts.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: Ty.small.copyWith(color: context.t3),
                              ),
                            ),
                            Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: context.t1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (srcBytes != null) ...[
            const SizedBox(height: 12),
            ToolCard(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(R.md),
                child: Image.memory(
                  srcBytes!,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
