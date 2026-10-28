import 'dart:io';

/// 播放（以及兜底抓取）用的请求头规则 —— 从上游 `lib/ui/playback.dart` 等价移植。
///
/// 不带头会怎样：B 站 CDN 直接 403，播放器表现为「一直转圈 / 整块灰」，
/// 下载也一样 403。所以预览、下载必须共用同一份判据。

/// B 站 CDN 认的 UA。
const String kJicunBilibiliUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// 普通浏览器 UA（抖音系 CDN 认这个）。
const String kJicunBrowserUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

const Map<String, String> _bilibiliHeaders = <String, String>{
  'Referer': 'https://www.bilibili.com/',
  'User-Agent': kJicunBilibiliUserAgent,
};

const List<String> _bilibiliHostSuffixes = <String>[
  'bilivideo.com',
  'bilivideo.cn',
  'bilibili.com',
];

/// 抖音系（含西瓜）CDN。
const List<String> _byteDanceHostSuffixes = <String>[
  'douyinstatic.com',
  'douyinpic.com',
  'douyinvod.com',
  'douyincdn.com',
  'ixigua.com',
  'ixiguavideo.com',
  'amemv.com',
  'bdxiguavod.com',
  'byteimg.com',
  'bytedance.com',
  'zjcdn.com',
  'pstatp.com',
  'snssdk.com',
];

String _hostOf(String url) => Uri.tryParse(url)?.host.toLowerCase() ?? '';

/// host 等于 suffix 或它的子域。**不能用 endsWith 直接比**：
/// `evilbilivideo.com` 也以 `bilivideo.com` 结尾，那样会把 B 站头发给无关域名。
bool _hostIsUnder(String host, String suffix) =>
    host == suffix || host.endsWith('.$suffix');

bool _isBilibiliHost(String host) {
  if (_bilibiliHostSuffixes.any((s) => _hostIsUnder(host, s))) return true;
  // B 站在 Akamai 上的镜像主机名形如 upos-xxx.akamaized.net；
  // Akamai 是公共 CDN，不带 upos- 前缀的一律不加 Referer。
  return host.startsWith('upos-') && _hostIsUnder(host, 'akamaized.net');
}

bool _isByteDanceHost(String host) =>
    _byteDanceHostSuffixes.any((s) => _hostIsUnder(host, s));

/// 给定媒体地址，返回该带的请求头；不需要的返回空 map。
Map<String, String> jicunPlaybackHeaders(String url) {
  // 本地文件不带任何头
  if (!url.startsWith('http')) return const {};

  final host = _hostOf(url);
  if (host.isEmpty) return const {};

  if (_isBilibiliHost(host)) return _bilibiliHeaders;
  if (_isByteDanceHost(host)) {
    return const {'User-Agent': kJicunBrowserUserAgent};
  }
  return const {};
}

/// 判断这个地址能不能「直接当媒体播」——有些返回的是网页而不是媒体流。
/// 仅供 UI 决定要不要给播放按钮兜底，不做网络请求。
bool jicunLooksPlayable(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return false;
  if (u.scheme == 'file') return true;
  if (u.scheme != 'http' && u.scheme != 'https') return false;
  final p = u.path.toLowerCase();
  return p.endsWith('.mp4') ||
      p.endsWith('.m4v') ||
      p.endsWith('.mov') ||
      p.endsWith('.m3u8') ||
      p.endsWith('.mp3') ||
      p.endsWith('.m4a') ||
      p.endsWith('.aac') ||
      p.endsWith('.flv') ||
      // B 站是 .m4s 分片，直链后缀不带扩展名的也常见，交给播放器试
      p.endsWith('.m4s') ||
      p.isEmpty;
}

/// 供测试与调试：拿到当前平台的可写根目录名（仅 Android 有意义）。
String? jicunAndroidExternalRoot() {
  if (!Platform.isAndroid) return null;
  return '/storage/emulated/0';
}
