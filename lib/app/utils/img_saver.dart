import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'toast_util.dart';

/// ═══════════════════════════════════════════════════════════════
/// ImgSaver —— 图片保存到相册（1015 新增）
///
/// 解决：壁纸/图集/皮肤只能看不能存
///
/// 用法：
///   ImgSaver.saveUrl(context, imageUrl);          // 网络图 → 相册
///   ImgSaver.saveBytes(bytes, name: 'xx');        // 字节 → 相册
/// ═══════════════════════════════════════════════════════════════
class ImgSaver {
  ImgSaver._();

  /// 保存网络图片（带进度提示）
  static Future<void> saveUrl(String url, {String? name}) async {
    if (url.trim().isEmpty) {
      ToastUtil.error('图片地址为空');
      return;
    }
    ToastUtil.info('正在保存…');
    try {
      // 带 UA（很多图床防外链）
      final r = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Referer': Uri.tryParse(url)?.origin ?? '',
          },
        ),
      );
      final bytes = r.data;
      if (bytes == null || bytes.isEmpty) {
        ToastUtil.error('图片下载失败');
        return;
      }
      await saveBytes(
        Uint8List.fromList(bytes),
        name: name ?? _guessName(url),
      );
    } catch (e) {
      ToastUtil.error('保存失败：${_friendly(e)}');
    }
  }

  /// 保存字节到相册
  static Future<void> saveBytes(Uint8List bytes, {String? name}) async {
    final fileName = name ?? 'anyi_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final r = await ImageGallerySaverPlus.saveImage(bytes, name: fileName);
      // 部分机型返回 false 但仍写入成功
      if (r is Map && r['isSuccess'] == false) {
        throw Exception('相册写入被拒绝');
      }
      ToastUtil.success('已保存到相册');
    } catch (_) {
      // 兜底：写 App 文档目录（无需权限）
      try {
        final d = await getApplicationDocumentsDirectory();
        final p = '${d.path}/$fileName.png';
        File(p).writeAsBytesSync(bytes);
        ToastUtil.success('已保存到：$p');
      } catch (_) {
        ToastUtil.error('保存失败，请检查相册权限');
      }
    }
  }

  static String _guessName(String url) {
    final u = url.split('?').first;
    final seg = u.split('/').last;
    if (seg.contains('.')) {
      return 'anyi_${DateTime.now().millisecondsSinceEpoch}_$seg';
    }
    return 'anyi_${DateTime.now().millisecondsSinceEpoch}';
  }

  static String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('403')) return '图源拒绝访问（403）';
    if (s.contains('404')) return '图片已失效';
    if (s.contains('timeout') || s.contains('超时')) return '下载超时';
    if (s.contains('SocketException')) return '网络连接失败';
    return '请重试';
  }
}
