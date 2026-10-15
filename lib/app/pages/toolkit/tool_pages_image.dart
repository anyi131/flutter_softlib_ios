import 'dart:io';
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

// ═══════════════════════════════════════════════════════════════
// 工具箱 · 图片工具（1015 新增）
//   全部在本机处理（image 包），不上传任何图片
//   共用：选图 → 处理 → 预览 → 保存到相册
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 图片压缩 ───────────────
class ImgCompressPage extends StatefulWidget {
  const ImgCompressPage({super.key});
  @override
  State<ImgCompressPage> createState() => _ImgCompressPageState();
}

class _ImgCompressPageState extends State<ImgCompressPage> with ImgToolMixin {
  int _quality = 70;
  int _maxW = 1080;

  Future<void> _go() => run(() => ImgJob.run(ImgJobArgs(srcBytes!,
      mode: 'compress', a: _quality, b: _maxW)));

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '图片压缩',
      subtitle: '降低分辨率 + 质量，体积可缩至 1/10',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('质量：$_quality%', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                Slider(
                  value: _quality.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  activeColor: C.brand,
                  onChanged: (v) => setState(() => _quality = v.round()),
                ),
                Text('最大宽度：$_maxW px', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                Slider(
                  value: _maxW.toDouble(),
                  min: 320,
                  max: 2160,
                  divisions: 23,
                  activeColor: C.brand,
                  onChanged: (v) => setState(() => _maxW = (v / 80).round() * 80),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolButton(label: '开始压缩', icon: Icons.compress_rounded, onPressed: _go),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ② 图片裁剪（按比例） ───────────────
class ImgCropPage extends StatefulWidget {
  const ImgCropPage({super.key});
  @override
  State<ImgCropPage> createState() => _ImgCropPageState();
}

class _ImgCropPageState extends State<ImgCropPage> with ImgToolMixin {
  int _ratio = 1; // 1=1:1 2=16:9 3=9:16 4=4:3 5=3:4 0=不裁

  static const _ratios = <(int, String)>[
    (1, '1:1 方形'),
    (2, '16:9 横版'),
    (3, '9:16 竖版'),
    (4, '4:3'),
    (5, '3:4'),
  ];

  Future<void> _go() => run(() async {
        final im = img.decodeImage(srcBytes!);
        if (im == null) return null;
        double target = switch (_ratio) {
          1 => 1.0,
          2 => 16 / 9,
          3 => 9 / 16,
          4 => 4 / 3,
          5 => 3 / 4,
          _ => im.width / im.height,
        };
        final cur = im.width / im.height;
        int w, h;
        if (cur > target) {
          h = im.height;
          w = (h * target).round();
        } else {
          w = im.width;
          h = (w / target).round();
        }
        final x = ((im.width - w) / 2).round();
        final y = ((im.height - h) / 2).round();
        final out = img.copyCrop(im, x: x, y: y, width: w, height: h);
        return Uint8List.fromList(img.encodeJpg(out, quality: 92));
      });

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '图片裁剪',
      subtitle: '按常用比例居中裁剪',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolChips<int>(
            items: _ratios,
            current: _ratio,
            onPick: (v) => setState(() => _ratio = v),
          ),
          const SizedBox(height: 12),
          ToolButton(label: '裁剪', icon: Icons.crop_rounded, onPressed: _go),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ③ 图片格式转换 ───────────────
class ImgConvPage extends StatefulWidget {
  const ImgConvPage({super.key});
  @override
  State<ImgConvPage> createState() => _ImgConvPageState();
}

class _ImgConvPageState extends State<ImgConvPage> with ImgToolMixin {
  int _fmt = 0; // 0=jpg 1=png 2=webp 3=bmp

  Future<void> _go() => run(() async {
        final im = img.decodeImage(srcBytes!);
        if (im == null) return null;
        return switch (_fmt) {
          1 => Uint8List.fromList(img.encodePng(im)),
          2 => Uint8List.fromList(img.encodeJpg(im, quality: 88)),
          3 => Uint8List.fromList(img.encodeBmp(im)),
          _ => Uint8List.fromList(img.encodeJpg(im, quality: 92)),
        };
      });

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '格式转换',
      subtitle: 'JPG / PNG / BMP 互转',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolChips<int>(
            items: const [(0, 'JPG'), (1, 'PNG'), (3, 'BMP')],
            current: _fmt,
            onPick: (v) => setState(() => _fmt = v),
          ),
          const SizedBox(height: 12),
          ToolButton(label: '转换', icon: Icons.swap_horiz_rounded, onPressed: _go),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// ─────────────── ④ 图片取色 ───────────────
class ImgColorPage extends StatefulWidget {
  const ImgColorPage({super.key});
  @override
  State<ImgColorPage> createState() => _ImgColorPageState();
}

class _ImgColorPageState extends State<ImgColorPage> with ImgToolMixin {
  List<String> palette = [];

  Future<void> _extract() => run(() async {
        final im = img.decodeImage(srcBytes!);
        if (im == null) return null;
        // 缩小后做颜色量化，取出主色
        final small = img.copyResize(im, width: 60);
        final map = <int, int>{};
        for (var y = 0; y < small.height; y++) {
          for (var x = 0; x < small.width; x++) {
            final p = small.getPixel(x, y);
            // 量化到 32 一档，减少近似色噪音
            final r = (p.r ~/ 32) * 32;
            final g = (p.g ~/ 32) * 32;
            final b = (p.b ~/ 32) * 32;
            final key = (r << 16) | (g << 8) | b;
            map[key] = (map[key] ?? 0) + 1;
          }
        }
        final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        palette = sorted.take(8).map((e) {
          final v = e.key;
          return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
        }).toList();
        return Uint8List.fromList(img.encodeJpg(im, quality: 90));
      });

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '图片取色',
      subtitle: '提取图片主色调（配色参考）',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolButton(label: '提取主色', icon: Icons.colorize_rounded, onPressed: _extract),
          if (palette.isNotEmpty) ...[
            const SizedBox(height: 14),
            ToolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主色调（点击复制）', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: palette.map<Widget>((hex) {
                      final v = int.parse(hex.substring(1), radix: 16);
                      return GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: hex));
                          ToastUtil.success('已复制 $hex');
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Color(0xff000000 | v),
                                borderRadius: BorderRadius.circular(R.md),
                                border: Border.all(color: C.stroke),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(hex, style: Ty.tiny.copyWith(color: context.t3)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────── ⑤ 图片加水印 ───────────────
class ImgWaterPage extends StatefulWidget {
  const ImgWaterPage({super.key});
  @override
  State<ImgWaterPage> createState() => _ImgWaterPageState();
}

class _ImgWaterPageState extends State<ImgWaterPage> with ImgToolMixin {
  final _txt = TextEditingController(text: '安逸软件汇');
  int _pos = 0; // 0右下 1左下 2右上 3左上 4居中

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  Future<void> _go() => run(() async {
        final im = img.decodeImage(srcBytes!);
        if (im == null) return null;
        final text = _txt.text.trim();
        if (text.isEmpty) return null;
        // 逐像素画字（简单 5x7 点阵，够用且不依赖字体文件）
        final font = _font;
        final scale = (im.width / 500).clamp(1, 6).toInt();
        final cw = 6 * scale, ch = 8 * scale;
        final tw = text.length * cw, th = ch;
        final pad = 12 * scale;
        final (x0, y0) = switch (_pos) {
          1 => (pad, im.height - th - pad),
          2 => (im.width - tw - pad, pad),
          3 => (pad, pad),
          4 => ((im.width - tw) ~/ 2, (im.height - th) ~/ 2),
          _ => (im.width - tw - pad, im.height - th - pad),
        };
        for (var ci = 0; ci < text.length; ci++) {
          final glyph = font[text[ci]] ?? font['?']!;
          for (var gy = 0; gy < 7; gy++) {
            for (var gx = 0; gx < 5; gx++) {
              if (glyph[gy * 5 + gx] != '1') continue;
              for (var sy = 0; sy < scale; sy++) {
                for (var sx = 0; sx < scale; sx++) {
                  final px = x0 + ci * cw + gx * scale + sx;
                  final py = y0 + gy * scale + sy;
                  if (px < 0 || py < 0 || px >= im.width || py >= im.height) continue;
                  // 半透明白字 + 描边效果（简单起见画两层）
                  im.setPixelRgba(px, py, 255, 255, 255, 210);
                }
              }
            }
          }
        }
        return Uint8List.fromList(img.encodeJpg(im, quality: 92));
      });

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '图片加水印',
      subtitle: '加上文字水印（本地处理）',
      scrollable: true,
      child: Column(
        children: [
          pickerCard(),
          const SizedBox(height: 12),
          ToolField(controller: _txt, label: '水印文字', icon: Icons.text_fields_rounded),
          ToolChips<int>(
            items: const [(0, '右下'), (1, '左下'), (2, '右上'), (3, '左上'), (4, '居中')],
            current: _pos,
            onPick: (v) => setState(() => _pos = v),
          ),
          const SizedBox(height: 12),
          ToolButton(label: '添加水印', icon: Icons.branding_watermark_rounded, onPressed: _go),
          previewCard(),
          saveBtn(),
        ],
      ),
    );
  }
}

// 5x7 点阵字库（够水印用的大写字母 + 数字 + 常用符号）
const Map<String, List<String>> _font = {
  'A': ['01110','10001','10001','11111','10001','10001','10001'],
  'B': ['11110','10001','10001','11110','10001','10001','11110'],
  'C': ['01111','10000','10000','10000','10000','10000','01111'],
  'D': ['11110','10001','10001','10001','10001','10001','11110'],
  'E': ['11111','10000','10000','11110','10000','10000','11111'],
  'F': ['11111','10000','10000','11110','10000','10000','10000'],
  'G': ['01111','10000','10000','10111','10001','10001','01111'],
  'H': ['10001','10001','10001','11111','10001','10001','10001'],
  'I': ['11111','00100','00100','00100','00100','00100','11111'],
  'J': ['00111','00010','00010','00010','00010','10010','01100'],
  'K': ['10001','10010','10100','11000','10100','10010','10001'],
  'L': ['10000','10000','10000','10000','10000','10000','11111'],
  'M': ['10001','11011','10101','10101','10001','10001','10001'],
  'N': ['10001','11001','10101','10011','10001','10001','10001'],
  'O': ['01110','10001','10001','10001','10001','10001','01110'],
  'P': ['11110','10001','10001','11110','10000','10000','10000'],
  'Q': ['01110','10001','10001','10001','10101','10010','01101'],
  'R': ['11110','10001','10001','11110','10100','10010','10001'],
  'S': ['01111','10000','10000','01110','00001','00001','11110'],
  'T': ['11111','00100','00100','00100','00100','00100','00100'],
  'U': ['10001','10001','10001','10001','10001','10001','01110'],
  'V': ['10001','10001','10001','10001','10001','01010','00100'],
  'W': ['10001','10001','10001','10101','10101','11011','10001'],
  'X': ['10001','01010','00100','00100','00100','01010','10001'],
  'Y': ['10001','01010','00100','00100','00100','00100','00100'],
  'Z': ['11111','00001','00010','00100','01000','10000','11111'],
  '0': ['01110','10001','10011','10101','11001','10001','01110'],
  '1': ['00100','01100','00100','00100','00100','00100','01110'],
  '2': ['01110','10001','00001','00010','00100','01000','11111'],
  '3': ['11111','00010','00100','00010','00001','10001','01110'],
  '4': ['00010','00110','01010','10010','11111','00010','00010'],
  '5': ['11111','10000','11110','00001','00001','10001','01110'],
  '6': ['00110','01000','10000','11110','10001','10001','01110'],
  '7': ['11111','00001','00010','00100','01000','01000','01000'],
  '8': ['01110','10001','10001','01110','10001','10001','01110'],
  '9': ['01110','10001','10001','01111','00001','00010','01100'],
  ' ': ['00000','00000','00000','00000','00000','00000','00000'],
  '?': ['01110','10001','00001','00010','00100','00000','00100'],
};

/// 让图片工具共用基类方法（mixin 包装，避免多继承限制）
mixin ImgToolMixin<T extends StatefulWidget> on State<T> {
  Uint8List? srcBytes;
  Uint8List? outBytes;
  String info = '';
  bool busy = false;

  Future<void> pickImage() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f == null) return;
      final b = await f.readAsBytes();
      setState(() {
        srcBytes = b;
        outBytes = null;
        info = '';
        final im = img.decodeImage(b);
        if (im != null) {
          info = '${im.width}×${im.height} · ${(b.length / 1024).toStringAsFixed(0)}KB';
        }
      });
    } catch (_) {
      ToastUtil.error('选图失败');
    }
  }

  Future<void> saveOut() async {
    final b = outBytes;
    if (b == null) return ToastUtil.info('先处理图片');
    try {
      await ImageGallerySaverPlus.saveImage(b, name: 'anyi_${DateTime.now().millisecondsSinceEpoch}');
      ToastUtil.success('已保存到相册');
    } catch (_) {
      try {
        final d = await getApplicationDocumentsDirectory();
        final p = '${d.path}/anyi_${DateTime.now().millisecondsSinceEpoch}.png';
        File(p).writeAsBytesSync(b);
        ToastUtil.success('已保存：$p');
      } catch (_) {
        ToastUtil.error('保存失败，请检查相册权限');
      }
    }
  }

  Future<void> run(Future<Uint8List?> Function() job) async {
    if (srcBytes == null) return ToastUtil.info('请先选择图片');
    setState(() => busy = true);
    try {
      final r = await job();
      if (!mounted) return;
      setState(() {
        outBytes = r;
        busy = false;
      });
      if (r == null) ToastUtil.error('处理失败（水印文字不能为空？）');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      ToastUtil.error('处理失败');
    }
  }

  Widget pickerCard() => ToolCard(
        onTap: busy ? null : pickImage,
        child: Row(
          children: [
            Icon(Icons.add_photo_alternate_rounded, size: 22, color: C.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(srcBytes == null ? '点击选择图片' : '已选图片 · 点击重选',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.t1)),
                  if (info.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(info, style: Ty.tiny.copyWith(color: context.t3)),
                  ],
                ],
              ),
            ),
            if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      );

  Widget previewCard() {
    if (srcBytes == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 12),
        ToolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(outBytes == null ? '原图' : '处理结果', style: Ty.tiny.copyWith(color: context.t3)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(R.md),
                child: Image.memory(outBytes ?? srcBytes!, height: 200, fit: BoxFit.contain),
              ),
              if (outBytes != null) ...[
                const SizedBox(height: 8),
                Text('${(outBytes!.length / 1024).toStringAsFixed(0)}KB',
                    style: Ty.tiny.copyWith(color: C.success)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget saveBtn() => outBytes == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ToolButton(label: '保存到相册', icon: Icons.download_rounded, onPressed: saveOut),
        );
}
