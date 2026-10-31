/// 1031r：flutter_image_compress 接入——上传前压缩，原生实现（Android libjpeg-turbo / iOS 串行队列）
///
/// 用法：把原来直接 `MultipartFile.fromFile(file.path)` 的上传点改为
/// `MultipartFile.fromFile((await ImgCompress.upload(file)).path)`。
/// 压缩失败时原样返回原文件，不阻塞上传。
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImgCompress {
  ImgCompress._();

  /// 上传前压缩：长边 ≤1280、quality 78、仅 JPEG/PNG/HEIC/WebP 参与压缩，
  /// 其他格式（GIF 等）原样返回。
  static Future<File> upload(File file) async {
    try {
      final p = file.path.toLowerCase();
      final isImg = p.endsWith('.jpg') ||
          p.endsWith('.jpeg') ||
          p.endsWith('.png') ||
          p.endsWith('.webp');
      if (!isImg) return file;

      final orig = await file.length();
      // 已足够小就不折腾
      if (orig <= 200 * 1024) return file;

      final target = '${file.parent.path}/'
          'c_${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final out = await FlutterImageCompress.compressAndGetFile(
        file.path,
        target,
        quality: 78,
        minWidth: 1280,
        minHeight: 1280,
        keepExif: false,
      );
      if (out == null) return file;
      final f = File(out.path);
      // 压缩反而变大（已经是压过的图）→ 丢产物回原文件
      if (await f.length() >= orig) {
        try {
          f.deleteSync();
      } catch (_) {}
        return file;
      }
      return f;
    } catch (_) {
      return file;
    }
  }
}
