import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// ★ 1015：图片处理统一放到后台 isolate 执行
///
/// 为什么必须这样：
///   马赛克/圆角/滤镜这类要逐像素遍历，一张 4000×3000 的图是 1200 万次循环。
///   在主线程跑会**直接卡死界面**（用户看到的就是「点了没反应/卡住」）。
///   compute 会把这些活儿丢到后台线程，界面保持流畅。
///
/// 用法：
///   final out = await ImgJob.run(ImgJobArgs(bytes, mode: 'mosaic', block: 16));

/// 任务参数（必须可序列化，isolate 之间只能传简单数据）
class ImgJobArgs {
  final Uint8List bytes;
  final String mode;
  final int a; // 主参数（质量/圆角/块大小/角度）
  final int b; // 副参数（最大宽度等）
  final bool flag; // 开关（圆形/翻转等）
  final bool flag2;
  final String text; // 水印文字

  const ImgJobArgs(
    this.bytes, {
    required this.mode,
    this.a = 0,
    this.b = 0,
    this.flag = false,
    this.flag2 = false,
    this.text = '',
  });
}

class ImgJob {
  ImgJob._();

  /// 入口：把任务丢到后台跑
  static Future<Uint8List?> run(ImgJobArgs args) {
    return compute(_worker, args);
  }
}

/// 后台执行体（必须是顶层函数）
Uint8List? _worker(ImgJobArgs args) {
  try {
    switch (args.mode) {
      case 'compress':
        return _compress(args);
      case 'crop':
        return _crop(args);
      case 'convert':
        return _convert(args);
      case 'rotate':
        return _rotate(args);
      case 'round':
        return _round(args);
      case 'mosaic':
        return _mosaic(args);
      case 'adjust':
        return _adjust(args);
      case 'gray':
        return _gray(args);
      case 'resize':
        return _resize(args);
      case 'watermark':
        return _watermark(args);
      case 'palette':
        return _palette(args);
      default:
        return null;
    }
  } catch (e) {
    return null;
  }
}

Uint8List? _decode(Uint8List b) => null; // 占位

Uint8List? _compress(ImgJobArgs a) {
  var im = img.decodeImage(a.bytes);
  if (im == null) return null;
  if (a.b > 0 && im.width > a.b) {
    im = img.copyResize(im, width: a.b, interpolation: img.Interpolation.average);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: a.a.clamp(10, 100)));
}

Uint8List? _crop(ImgJobArgs a) {
  final im = img.decodeImage(a.bytes);
  if (im == null) return null;
  double target;
  switch (a.a) {
    case 1:
      target = 1.0;
      break;
    case 2:
      target = 16 / 9;
      break;
    case 3:
      target = 9 / 16;
      break;
    case 4:
      target = 4 / 3;
      break;
    case 5:
      target = 3 / 4;
      break;
    default:
      target = im.width / im.height;
  }
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
  return Uint8List.fromList(img.encodeJpg(img.copyCrop(im, x: x, y: y, width: w, height: h), quality: 92));
}

Uint8List? _convert(ImgJobArgs a) {
  final im = img.decodeImage(a.bytes);
  if (im == null) return null;
  switch (a.a) {
    case 1:
      return Uint8List.fromList(img.encodePng(im, level: 6));
    case 3:
      return Uint8List.fromList(img.encodeBmp(im));
    default:
      return Uint8List.fromList(img.encodeJpg(im, quality: 92));
  }
}

Uint8List? _rotate(ImgJobArgs a) {
  var im = img.decodeImage(a.bytes);
  if (im == null) return null;
  if (a.a != 0) im = img.copyRotate(im, angle: a.a.toDouble());
  if (a.flag) im = img.flipHorizontal(im);
  if (a.flag2) im = img.flipVertical(im);
  return Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

Uint8List? _round(ImgJobArgs a) {
  final im = img.decodeImage(a.bytes);
  if (im == null) return null;
  final w = im.width, h = im.height;
  final radius = a.flag ? (w < h ? w : h) ~/ 2 : (a.a * w / 400).round();
  final out = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var inside = true;
      if (a.flag) {
        final cx = w / 2, cy = h / 2;
        final rr = (w < h ? w : h) / 2;
        final dx = x - cx, dy = y - cy;
        inside = dx * dx + dy * dy <= rr * rr;
      } else if (radius > 0) {
        double ox = 0, oy = 0;
        if (x < radius) ox = (radius - x).toDouble();
        if (x > w - radius - 1) ox = (x - (w - radius - 1)).toDouble();
        if (y < radius) oy = (radius - y).toDouble();
        if (y > h - radius - 1) oy = (y - (h - radius - 1)).toDouble();
        if (ox > 0 && oy > 0) {
          inside = (ox * ox + oy * oy) <= radius * radius;
        }
      }
      final p = im.getPixel(x, y);
      if (inside) {
        out.setPixelRgba(x, y, p.r, p.g, p.b, 255);
      } else {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(out, level: 6));
}

Uint8List? _mosaic(ImgJobArgs a) {
  final im = img.decodeImage(a.bytes);
  if (im == null) return null;
  final block = a.a <= 0 ? 16 : a.a;
  final out = img.Image.from(im);
  for (var by = 0; by < im.height; by += block) {
    for (var bx = 0; bx < im.width; bx += block) {
      var r = 0, g = 0, b = 0, n = 0;
      final ey = by + block > im.height ? im.height : by + block;
      final ex = bx + block > im.width ? im.width : bx + block;
      for (var y = by; y < ey; y++) {
        for (var x = bx; x < ex; x++) {
          final p = im.getPixel(x, y);
          r += p.r.toInt();
          g += p.g.toInt();
          b += p.b.toInt();
          n++;
        }
      }
      if (n == 0) continue;
      final ar = r ~/ n, ag = g ~/ n, ab = b ~/ n;
      for (var y = by; y < ey; y++) {
        for (var x = bx; x < ex; x++) {
          out.setPixelRgb(x, y, ar, ag, ab);
        }
      }
    }
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 90));
}

Uint8List? _adjust(ImgJobArgs a) {
  var im = img.decodeImage(a.bytes);
  if (im == null) return null;
  if (a.a != 0) im = img.adjustColor(im, brightness: 1 + a.a / 100);
  if (a.b != 0) im = img.adjustColor(im, contrast: 1 + a.b / 100);
  if (a.flag) im = img.adjustColor(im, saturation: 1.2);
  return Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

Uint8List? _gray(ImgJobArgs a) {
  var im = img.decodeImage(a.bytes);
  if (im == null) return null;
  im = img.grayscale(im);
  if (a.a == 1) {
    for (var y = 0; y < im.height; y++) {
      for (var x = 0; x < im.width; x++) {
        final p = im.getPixel(x, y);
        final v = p.r > 128 ? 255 : 0;
        im.setPixelRgb(x, y, v, v, v);
      }
    }
  } else if (a.a == 2) {
    im = img.sepia(im);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

Uint8List? _resize(ImgJobArgs a) {
  var im = img.decodeImage(a.bytes);
  if (im == null) return null;
  final nw = a.a > 0 ? a.a : im.width;
  final nh = a.flag ? (nw * im.height / im.width).round() : (a.b > 0 ? a.b : im.height);
  im = img.copyResize(im, width: nw, height: nh, interpolation: img.Interpolation.average);
  return Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

Uint8List? _watermark(ImgJobArgs a) {
  final im = img.decodeImage(a.bytes);
  if (im == null) return null;
  final text = a.text;
  if (text.isEmpty) return null;
  final font = _font;
  final scale = (im.width / 500).clamp(1, 6).toInt();
  final cw = 6 * scale, ch = 8 * scale;
  final tw = text.length * cw, th = ch;
  final pad = 12 * scale;
  int x0, y0;
  switch (a.a) {
    case 1:
      x0 = pad;
      y0 = im.height - th - pad;
      break;
    case 2:
      x0 = im.width - tw - pad;
      y0 = pad;
      break;
    case 3:
      x0 = pad;
      y0 = pad;
      break;
    case 4:
      x0 = (im.width - tw) ~/ 2;
      y0 = (im.height - th) ~/ 2;
      break;
    default:
      x0 = im.width - tw - pad;
      y0 = im.height - th - pad;
  }
  for (var ci = 0; ci < text.length; ci++) {
    final glyph = font[text[ci].toUpperCase()] ?? font['?']!;
    for (var gy = 0; gy < 7; gy++) {
      for (var gx = 0; gx < 5; gx++) {
        if (glyph[gy][gx] != '1') continue;
        for (var sy = 0; sy < scale; sy++) {
          for (var sx = 0; sx < scale; sx++) {
            final px = x0 + ci * cw + gx * scale + sx;
            final py = y0 + gy * scale + sy;
            if (px < 0 || py < 0 || px >= im.width || py >= im.height) continue;
            im.setPixelRgba(px, py, 255, 255, 255, 210);
          }
        }
      }
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

/// 取主色调（返回 hex 列表）
List<String>? _paletteList;

Uint8List? _palette(ImgJobArgs a) {
  final im = img.decodeImage(a.bytes);
  if (im == null) return null;
  final small = img.copyResize(im, width: 60);
  final map = <int, int>{};
  for (var y = 0; y < small.height; y++) {
    for (var x = 0; x < small.width; x++) {
      final p = small.getPixel(x, y);
      final r = (p.r.toInt() ~/ 32) * 32;
      final g = (p.g.toInt() ~/ 32) * 32;
      final b = (p.b.toInt() ~/ 32) * 32;
      final key = (r << 16) | (g << 8) | b;
      map[key] = (map[key] ?? 0) + 1;
    }
  }
  final sorted = map.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
  _paletteList = sorted.take(8).map((e) {
    return '#${e.key.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }).toList();
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

/// 取色结果（在主线程读取，因为 isolate 返回值需可序列化）
List<String> takePalette() {
  final r = _paletteList ?? const <String>[];
  _paletteList = null;
  return r;
}

// 5x7 点阵字库
const Map<String, List<String>> _font = {
  'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  'C': ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  'G': ['01111', '10000', '10000', '10111', '10001', '10001', '01111'],
  'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
  'J': ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
  'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  'N': ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  'W': ['10001', '10001', '10001', '10101', '10101', '11011', '10001'],
  'X': ['10001', '01010', '00100', '00100', '00100', '01010', '10001'],
  'Y': ['10001', '01010', '00100', '00100', '00100', '00100', '00100'],
  'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
  '?': ['01110', '10001', '00001', '00010', '00100', '00000', '00100'],
};
