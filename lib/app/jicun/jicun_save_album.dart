// 保存到系统相册：视频/图片走相册插件，音频落到应用文档目录。
//
// 这里的原则是「绝不把异常抛给 UI」：下载页拿到的是一个结果对象，失败也只是一句
// 能给用户看的中文，不需要在每个调用点再包 try/catch。
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

/// 保存结果。失败也是正常返回值，不看异常。
class JicunSaveResult {
  const JicunSaveResult({
    required this.ok,
    required this.message,
    this.savedPath,
  });

  final bool ok;

  /// 给用户看的一句话：成功是「已保存到相册」，失败是中文原因。
  final String message;

  /// 落盘后的真实路径。相册不一定回报路径，音频则一定有。
  final String? savedPath;
}

/// 文件不在了时不值得再问一次系统：下载目录会被清理，用户点得晚就会遇到。
const JicunSaveResult _kMissing = JicunSaveResult(
  ok: false,
  message: '文件不存在，可能已被清理',
);

/// 把下载好的文件存进系统相册；音频改存应用文档目录。
///
/// [kind] 是 `'video' | 'audio' | 'image'`；[displayName] 是**不带扩展名**的
/// 展示名（调用方负责清洗，这里仍会兜一层非法字符）；[album] 是相册/文件夹名。
Future<JicunSaveResult> jicunSaveToAlbum(
  String filePath, {
  required String kind,
  String? displayName,
  String album = '安逸软件汇',
}) async {
  final path = filePath.trim();
  final k = kind.trim().toLowerCase();
  if (path.isEmpty) return _kMissing;
  try {
    final source = File(path);
    if (!await source.exists()) return _kMissing;
    // 相册插件不收音频（Android 的 MediaStore 音频也不是「相册」），
    // 硬塞会被平台拒掉，所以音频单独落目录。
    if (k == 'audio') {
      return await _copyAudioToFolder(
        source,
        displayName: displayName,
        album: album,
      );
    }
    return await _saveViaGallery(
        path, displayName: displayName, album: album);
  } catch (error) {
    // 权限、磁盘、平台通道……都在这里收口，调用方不需要再防。
    return JicunSaveResult(
      ok: false,
      message: _reasonFor(error, toAlbum: k != 'audio'),
    );
  }
}

/// 视频/图片：优先用 gal 存进指定相册（`Pictures/<相册>`、`Movies/<相册>`），
/// 它做不到时（老机型、不支持的格式、插件缺失）退回旧的 image_gallery_saver_plus，
/// 至少落到系统相册根目录，不让用户白等一次下载。
Future<JicunSaveResult> _saveViaGallery(
  String path, {
  String? displayName,
  required String album,
}) async {
  final folder = _safeAlbum(album);
  try {
    if (!await Gal.hasAccess(toAlbum: true)) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        return const JicunSaveResult(
          ok: false,
          message: '没有相册写入权限，请到系统设置里允许',
        );
      }
    }
    if (_kImageExts.contains(_extOf(path))) {
      await Gal.putImage(path, album: folder);
    } else {
      await Gal.putVideo(path, album: folder);
    }
    return JicunSaveResult(ok: true, message: '已保存到 $folder 相册');
  } on GalException catch (error) {
    if (error.type == GalExceptionType.accessDenied) {
      return const JicunSaveResult(
        ok: false,
        message: '没有相册写入权限，请到系统设置里允许',
      );
    }
    if (error.type == GalExceptionType.notEnoughSpace) {
      return const JicunSaveResult(ok: false, message: '存储空间不足，保存失败');
    }
    // 格式不支持 / 未预期错误：退回根目录，相册名这一层放弃
    return _saveViaLegacyPlugin(path, displayName: displayName);
  } on MissingPluginException {
    return _saveViaLegacyPlugin(path, displayName: displayName);
  }
}

/// 旧插件的保存路径：只能进系统相册根目录，作为兜底。
Future<JicunSaveResult> _saveViaLegacyPlugin(
  String path, {
  String? displayName,
}) async {
  // ★ 插件 4.0.1 的 saveFile 只有 name / isReturnPathOfIOS，没有 album 参数；
  // 安卓原生侧固定写 Movies/ 或 Pictures/（没有子目录），所以「相册名」这一层
  // 只对音频（文档目录）生效，视频/图片进系统相册根目录。
  final dynamic result = await ImageGallerySaverPlus.saveFile(
    path,
    name: _safeName(displayName),
  );
  final outcome = _readResult(result);
  if (!outcome.ok) {
    return JicunSaveResult(ok: false, message: outcome.reason);
  }
  return JicunSaveResult(
    ok: true,
    message: '已保存到相册',
    savedPath: outcome.path,
  );
}

/// 音频：复制到 `Documents/<album>/`。用复制而不是移动，下载目录里的原件留着，
/// 用户重试或换名字再存时不会发现源文件没了。
Future<JicunSaveResult> _copyAudioToFolder(
  File source, {
  String? displayName,
  required String album,
}) async {
  final folderName = _safeAlbum(album);
  final docs = await getApplicationDocumentsDirectory();
  final folder = Directory('${docs.path}/$folderName');
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final name = _audioFileName(
    displayName: displayName,
    sourcePath: source.path,
  );
  final direct = '${folder.path}/$name';
  // 已经躺在目标位置（比如用户对着文件夹里的文件再点一次保存）就不用再拷一份。
  if (source.absolute.path == direct) {
    return JicunSaveResult(
      ok: true,
      message: '已保存到 $folderName 文件夹',
      savedPath: source.absolute.path,
    );
  }
  final target = await _freeFile(folder, name);
  await source.copy(target.path);
  return JicunSaveResult(
    ok: true,
    message: '已保存到 $folderName 文件夹',
    savedPath: target.path,
  );
}

/// 解析插件返回值。
///
/// Android 回 `{isSuccess: true, filePath: uri}`，iOS 回路径字符串，个别版本回
/// bool。三种都认；`filePath` 有值本身就当成功，因为有些机型 isSuccess 字段缺失
/// 但文件确实入了库。
_GalleryOutcome _readResult(dynamic result) {
  if (result == null) {
    return const _GalleryOutcome.fail('保存失败：系统没有返回结果，请重试');
  }
  if (result is bool) {
    return result
        ? const _GalleryOutcome.ok()
        : const _GalleryOutcome.fail('相册写入被拒绝，请到系统设置里允许');
  }
  if (result is String) {
    final text = result.trim();
    return text.isEmpty
        ? const _GalleryOutcome.fail('保存失败：系统没有返回结果，请重试')
        : _GalleryOutcome.ok(text);
  }
  if (result is Map) {
    final path = _textOrNull(result['filePath']) ??
        _textOrNull(result['path']) ??
        _textOrNull(result['url']);
    final flag = result['isSuccess'];
    final success = flag == true || flag == 1 || flag == 'true';
    if (success || path != null) return _GalleryOutcome.ok(path);
    final detail = _textOrNull(result['errorMessage']) ??
        _textOrNull(result['error']) ??
        _textOrNull(result['message']);
    return _GalleryOutcome.fail(
      detail == null ? '相册写入被拒绝，请到系统设置里允许' : '保存失败：$detail',
    );
  }
  return const _GalleryOutcome.fail('保存失败：系统返回了无法识别的结果');
}

/// 相册插件的返回值翻译成统一结论。
class _GalleryOutcome {
  const _GalleryOutcome.ok([this.path])
      : ok = true,
        reason = '';

  const _GalleryOutcome.fail(this.reason)
      : ok = false,
        path = null;

  final bool ok;
  final String? path;
  final String reason;
}

/// 音频的最终文件名（带真实后缀）。调用方给的名字按约定不带后缀，但万一带了
/// 就先剥掉，免得存出 `歌曲.mp3.mp3`。
String _audioFileName({String? displayName, required String sourcePath}) {
  var base = _safeName(displayName);
  if (base == null) {
    final leaf = _leafOf(sourcePath);
    final dot = leaf.lastIndexOf('.');
    base = dot <= 0 ? leaf : leaf.substring(0, dot);
  }
  base = _stripMediaExt(base);
  if (base.isEmpty) base = '音频_${_stamp()}';
  return '$base.${_audioExt(sourcePath)}';
}

/// 后缀必须来自源文件，不能一律写 m4a：`flac`/`wav` 改名会误导播放器。
String _audioExt(String path) {
  final leaf = _leafOf(path);
  final dot = leaf.lastIndexOf('.');
  if (dot <= 0 || dot == leaf.length - 1) return 'm4a';
  final ext = leaf.substring(dot + 1).toLowerCase();
  return _kAudioExts.contains(ext) ? ext : 'm4a';
}

/// 能进相册的图片后缀；其余按视频交给 putVideo。
const Set<String> _kImageExts = <String>{
  'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'bmp',
};

String _extOf(String path) {
  final leaf = _leafOf(path);
  final dot = leaf.lastIndexOf('.');
  if (dot <= 0 || dot == leaf.length - 1) return '';
  return leaf.substring(dot + 1).toLowerCase();
}

const Set<String> _kAudioExts = <String>{
  'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus', 'amr',
};

/// 名字里不该出现的媒体后缀（避免 `a.mp3.mp3`）。
const Set<String> _kMediaExts = <String>{
  'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus', 'amr', //
  'mp4', 'm4v', 'mov', 'webm', 'mkv', 'flv', 'ts', //
  'jpg', 'jpeg', 'png', 'webp', 'gif', //
};

String _stripMediaExt(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return name;
  final ext = name.substring(dot + 1).toLowerCase();
  if (!_kMediaExts.contains(ext)) return name;
  return name.substring(0, dot).trim();
}

/// 目标目录里挑一个不撞的名字。音频是复制，覆盖掉上次存的那份用户就找不回了。
Future<File> _freeFile(Directory folder, String name) async {
  final dot = name.lastIndexOf('.');
  final stem = dot <= 0 ? name : name.substring(0, dot);
  final ext = dot <= 0 ? '' : name.substring(dot);
  var target = File('${folder.path}/$name');
  var i = 2;
  while (await target.exists()) {
    if (i > 999) {
      // 病态情况：别无限试下去，时间戳收尾。
      target = File(
        '${folder.path}/${stem}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      break;
    }
    target = File('${folder.path}/${stem}_$i$ext');
    i++;
  }
  return target;
}

/// 展示名清洗。相册名/文件名都由它落地，路径分隔符必须挡掉，否则能写到别处。
String? _safeName(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final cleaned = text
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  return cleaned.isEmpty ? null : cleaned;
}

/// 相册/文件夹名。`.` 与 `..` 单独挡掉，否则目录会跑到文档目录外面去。
String _safeAlbum(String album) {
  final cleaned = album
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), '_')
      .trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return '安逸软件汇';
  }
  return cleaned;
}

String? _textOrNull(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// 异常 → 用户能懂的一句话。权限和空间是最常见的两种失败，单独说清楚；
/// 其余的把平台原文带上，方便用户截图反馈。
String _reasonFor(Object error, {required bool toAlbum}) {
  final raw = error is PlatformException
      ? '${error.code} ${error.message ?? ''}'
      : error.toString();
  final text = raw.toLowerCase();
  if (text.contains('permission') ||
      text.contains('denied') ||
      text.contains('not authorized') ||
      text.contains('unauthorized') ||
      text.contains('access_denied')) {
    return toAlbum
        ? '没有相册写入权限，请到系统设置里允许'
        : '没有文件写入权限，请到系统设置里允许';
  }
  if (text.contains('no space') ||
      text.contains('enospc') ||
      text.contains('disk full') ||
      text.contains('storage full')) {
    return '存储空间不足，保存失败';
  }
  if (error is FileSystemException) {
    return '写入文件失败，请检查存储空间后重试';
  }
  if (error is PlatformException) {
    final message = error.message?.trim();
    return message == null || message.isEmpty
        ? '保存失败：${error.code}'
        : '保存失败：$message';
  }
  final message = error.toString().trim();
  return message.isEmpty ? '保存失败，请重试' : '保存失败：${_clip(message)}';
}

String _clip(String text) {
  if (text.length <= 60) return text;
  return '${String.fromCharCodes(text.runes.take(60))}…';
}

String _leafOf(String path) => path.split(RegExp(r'[/\\]')).last;

String _stamp() {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}'
      '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
}
