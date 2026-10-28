// 把网络图片存进相册：先落到临时文件，再交给相册模块。
//
// 相册插件只认本地路径，而图集里的图是远程地址；走临时文件是唯一不需要
// 新增依赖的办法。临时文件存完就删 —— 用户要的是相册里的那份。
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'jicun_download_naming.dart';
import 'jicun_playback_headers.dart';
import 'jicun_save_album.dart';

/// 下载 [url] 并保存到相册。失败一律以 [JicunSaveResult] 返回，不抛异常。
///
/// [displayName] 不带扩展名；扩展名按 URL 推断（认不出按图片兜底 jpg）。
Future<JicunSaveResult> jicunSaveToAlbumFromUrl(
  String url, {
  required String kind,
  String? displayName,
  String album = '安逸软件汇',
  Duration timeout = const Duration(seconds: 30),
}) async {
  final target = url.trim();
  if (target.isEmpty) {
    return const JicunSaveResult(ok: false, message: '图片地址为空');
  }
  File? temp;
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(Uri.parse(target)).timeout(timeout);
    // 图床大多要 Referer（B 站/小红书尤其），不带就是 403。
    jicunPlaybackHeaders(target).forEach(request.headers.set);
    final response = await request.close().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return JicunSaveResult(
        ok: false,
        message: '图片下载失败（HTTP ${response.statusCode}）',
      );
    }
    final bytes = await _readBytes(response).timeout(timeout);
    if (bytes.isEmpty) {
      return const JicunSaveResult(ok: false, message: '图片下载失败：内容为空');
    }
    final dir = await getTemporaryDirectory();
    final ext = jicunExtForUrl(target, kind: kind);
    temp = File('${dir.path}/jicun_${DateTime.now().microsecondsSinceEpoch}.$ext');
    await temp.writeAsBytes(bytes, flush: true);
    return await jicunSaveToAlbum(
      temp.path,
      kind: kind,
      displayName: displayName,
      album: album,
    );
  } on SocketException {
    return const JicunSaveResult(ok: false, message: '网络连接失败，请检查网络后重试');
  } catch (error) {
    final text = error.toString();
    if (text.contains('TimeoutException') || text.contains('超时')) {
      return const JicunSaveResult(ok: false, message: '图片下载超时，请重试');
    }
    return JicunSaveResult(ok: false, message: '保存失败：$text');
  } finally {
    client.close(force: true);
    // 临时文件删失败无所谓，系统会清理缓存目录。
    try {
      if (temp != null && await temp.exists()) await temp.delete();
    } catch (_) {}
  }
}

/// 读出整个响应体。
Future<List<int>> _readBytes(HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
