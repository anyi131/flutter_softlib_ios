// 文件名规则：标题清洗 → 扩展名推断 → 重名避让。
//
// 这里刻意不碰 IO 也不碰平台通道：输入是字符串，输出是名字，所以能直接单测。
// 文件名只做「能被系统接受 + 用户认得出」两件事，不改动标题里的文字本身。

/// 标题保留的最大字符数。按 Unicode 码点算，不是 UTF-16 单元 —— 按单元截会把
/// emoji 的代理对劈成两半，落盘就是乱码方块。
const int _kMaxTitleChars = 80;

/// 认得的媒体扩展名（不带点）。不在表里的（如 `.m4s`）一律按类型兜底，
/// 因为错后缀比没后缀更麻烦：播放器/相册会按后缀决定要不要接管。
const Set<String> _kKnownExts = <String>{
  // 视频
  'mp4', 'm4v', 'mov', 'webm', 'mkv', 'flv', 'ts',
  // 音频
  'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg',
  // 图片
  'jpg', 'jpeg', 'png', 'webp', 'gif',
};

/// 文件系统不接受的字符。换成空格而不是直接删：`标题/副标题` 删完会粘成
/// 一个词，隔开还能读。
final RegExp _kIllegal = RegExp(r'[\\/:*?"<>|]');

/// 控制字符。换成空格是为了让换行、制表符仍然起分隔作用。
final RegExp _kControl = RegExp(r'[\x00-\x1F\x7F]');

/// 零宽字符在相册列表里不可见，纯属噪声；ZWJ（U+200D）不能删 —— emoji 组合靠它。
final RegExp _kInvisible = RegExp('[\u200B\uFEFF]');

final RegExp _kSpaces = RegExp(r'\s+');

/// 首尾的点与空格。点要清是因为隐藏文件/结尾点在某些系统上表现不一致。
final RegExp _kEdgeDots = RegExp(r'^[.\s]+|[.\s]+$');

/// 清洗标题：解码、去非法字符、压空白、去首尾点空格、限长。
///
/// 保留中文和 emoji —— 用户就是靠这些在相册里认出文件的，删了等于没名字。
String jicunCleanTitle(String raw) {
  var text = raw;
  try {
    // 链接/接口带过来的标题常是百分号编码；遇到裸 `%`（`100%好评`）会解析失败，
    // 那就按原样用，不能因为一个百分号把整条标题丢了。
    text = Uri.decodeComponent(text);
  } catch (_) {
    text = raw;
  }
  text = text
      .replaceAll(_kInvisible, '')
      .replaceAll(_kControl, ' ')
      .replaceAll(_kIllegal, ' ')
      .replaceAll(_kSpaces, ' ')
      .replaceAll(_kEdgeDots, '');
  if (text.isEmpty) return '';

  // 按码点截断，代理对永远是完整的一个码点，不会被劈开。
  final runes = text.runes.toList(growable: false);
  var cut = runes.length > _kMaxTitleChars
      ? String.fromCharCodes(runes.take(_kMaxTitleChars))
      : text;
  // 截断点可能正好落在 emoji 组合的连接符/变体选择符上，退一格比留半个组合好。
  while (cut.isNotEmpty &&
      (cut.endsWith('\u200D') || cut.endsWith('\uFE0F'))) {
    cut = cut.substring(0, cut.length - 1);
  }
  return cut.replaceAll(_kEdgeDots, '');
}

/// 从 URL 推扩展名（不带点）。
///
/// 先剥 query/fragment 再取最后一段：签名参数里常带 `.mp4` 之类的字眼，直接
/// 对整条 URL 取后缀会拿到 `sign=1` 这种垃圾。认不出就按 [kind] 兜底。
String jicunExtForUrl(String url, {required String kind}) {
  final leaf = _leafOf(_pathOf(url));
  final dot = leaf.lastIndexOf('.');
  if (dot >= 0 && dot < leaf.length - 1) {
    final ext = leaf.substring(dot + 1).toLowerCase();
    if (_kKnownExts.contains(ext)) return ext;
  }
  return _fallbackExt(kind);
}

/// 取 URL 的路径部分。`Uri.tryParse` 失败（分享文案里夹了空格之类）时退回手剥。
String _pathOf(String url) {
  final text = url.trim();
  final uri = Uri.tryParse(text);
  if (uri != null && uri.path.isNotEmpty) return uri.path;
  return text.split('#').first.split('?').first;
}

/// 路径最后一段。
String _leafOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? path : path.substring(slash + 1);
}

/// 重名避让：`名字.ext` 已被占用就试 `名字_2.ext`、`名字_3.ext`……
///
/// [taken] 由调用方给（下载目录里已有的名字 / 本次任务已经排过的名字），
/// 这里不改它，只读。
String jicunUniqueName(String stem, String ext, Set<String> taken) {
  final base = stem.trim().isEmpty ? '文件' : stem.trim();
  var suffix = ext.trim().toLowerCase();
  if (suffix.startsWith('.')) suffix = suffix.substring(1);
  final dotExt = suffix.isEmpty ? '' : '.$suffix';

  final first = '$base$dotExt';
  if (!taken.contains(first)) return first;
  // 从 2 开始：不撞的时候名字里不该出现序号。
  for (var i = 2; i <= 9999; i++) {
    final candidate = '${base}_$i$dotExt';
    if (!taken.contains(candidate)) return candidate;
  }
  // 撞到这个份上基本是调用方给了个病态的 taken，用时间戳收尾保证能用。
  return '${base}_${DateTime.now().millisecondsSinceEpoch}$dotExt';
}

/// 组合出最终文件名（带扩展名）。
///
/// [title] 是原始标题（没洗过），[url] 用来推扩展名，[kind] 是
/// `'video' | 'audio' | 'image'`。多条目一起下时请传同一个 [taken]，否则同一秒
/// 落盘的同名条目会互相覆盖。
String jicunFileNameFor({
  required String title,
  required String url,
  required String kind,
  Set<String> taken = const <String>{},
}) {
  final ext = jicunExtForUrl(url, kind: kind);
  var stem = _stripMediaExt(jicunCleanTitle(title));
  if (stem.isEmpty) stem = _fallbackStem(kind);
  return jicunUniqueName(stem, ext, taken);
}

/// 剥掉标题末尾的媒体后缀。
///
/// 有的平台标题本身就是文件名（`…冬日高画.mp4`），不剥就会拼出 `xxx.mp4.mp4`。
/// 只认 [_kKnownExts] 里的后缀：标题里的点太常见（`1.2 万人点赞`），乱剥会截掉正文。
String _stripMediaExt(String title) {
  final dot = title.lastIndexOf('.');
  if (dot <= 0 || dot == title.length - 1) return title;
  final ext = title.substring(dot + 1).toLowerCase();
  if (!_kKnownExts.contains(ext)) return title;
  return title.substring(0, dot).replaceAll(_kEdgeDots, '');
}

/// 空标题的兜底：`视频_20261028_140501`。带时间戳是为了用户能区分不同次保存，
/// 真正的唯一性仍由 [jicunUniqueName] 保证。
String _fallbackStem(String kind) {
  final label = switch (_normalizedKind(kind)) {
    'audio' => '音频',
    'image' => '图片',
    _ => '视频',
  };
  return '${label}_${_stamp()}';
}

String _stamp() {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}'
      '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

String _normalizedKind(String kind) {
  final k = kind.trim().toLowerCase();
  if (k == 'audio' || k == 'image') return k;
  return 'video';
}

String _fallbackExt(String kind) => switch (_normalizedKind(kind)) {
  'audio' => 'm4a',
  'image' => 'jpg',
  _ => 'mp4',
};
