////////////////////////////////////////////////////////////////////////////////
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）
// 本文件由即存（jicun）项目移植：平台枚举/平台识别/分享链接提取
// (上游 parse_service.dart 的模型与工具段),未做逻辑改动。
// 版权与许可遵循上游 MIT License,见仓库 LICENSE。
////////////////////////////////////////////////////////////////////////////////
enum ParsePlatform {
  douyin('抖音'),
  kuaishou('快手'),
  doubao('豆包'),
  wechatChannels('微信视频号'),

  /// 汽水音乐。**它有自己一条免密钥的第三方接口**(见
  /// [ParseService.publicUpstreamPaths]),不是走付费那家。
  qishuiMusic('汽水音乐'),

  /// 认不出/不在名单里。走 media-parser。
  unknown('');

  const ParsePlatform(this.label);

  /// 展示用的中文名。历史卡上「平台」那一栏就是它(见 lib/pages/history.dart
  /// 的 entrySubtitle)。
  final String label;
}

/// 短链域名 → 平台。
///
/// 判据只认**域名**,不认整段文本:分享文案里出现「抖音」两个字不代表这条链接
/// 是抖音的(用户转发别人的文案很常见)。域名认不出就交给兜底那条路,不会错——
/// media-parser 什么链接都吃。
const Map<String, ParsePlatform> _kPlatformHosts = <String, ParsePlatform>{
  // ⚠️ 汽水音乐**必须排在 douyin.com 前面**:它的分享短链是 `qishui.douyin.com/s/…`,
  // 而 [detectPlatform] 认子域(见下),顺序反了它就被当成抖音、送去抖音那条上游了。
  // 实测 2026-10-06:`https://qishui.douyin.com/s/…` 跳转后落在
  // `music.douyin.com/qishui/share/{track,album,playlist,mv,ugc_video}?…`。
  'qishui.douyin.com': ParsePlatform.qishuiMusic,
  // 汽水音乐网页版(www.qishui.com)。用户从浏览器里复制出来的就是这一类。
  'qishui.com': ParsePlatform.qishuiMusic,
  // 抖音:主站、短链、以及它的图集/去水印域名
  'douyin.com': ParsePlatform.douyin,
  'iesdouyin.com': ParsePlatform.douyin,
  'ixigua.com': ParsePlatform.douyin,
  // 快手:主站和它那两个短链
  'kuaishou.com': ParsePlatform.kuaishou,
  'gifshow.com': ParsePlatform.kuaishou,
  'chenzhongtech.com': ParsePlatform.kuaishou,
  'kwai.com': ParsePlatform.kuaishou,
  // 豆包
  'doubao.com': ParsePlatform.doubao,
  'doubao.cn': ParsePlatform.doubao,
  // 微信视频号
  'channels.weixin.qq.com': ParsePlatform.wechatChannels,
  'finder.video.qq.com': ParsePlatform.wechatChannels,
  'weixin.qq.com': ParsePlatform.wechatChannels,
};

/// 认这条链接属于哪个平台。认不出返回 [ParsePlatform.unknown]。
///
/// 大小写、子域名都归一到同一个平台:`v.douyin.com` → 抖音。
ParsePlatform detectPlatform(String url) {
  final uri = Uri.tryParse(url.trim());
  final host = uri?.host.toLowerCase() ?? '';
  if (host.isEmpty) return ParsePlatform.unknown;
  // 汽水音乐的分享页挂在 `music.douyin.com/qishui/…` 上(短链跳转后的地址就是它),
  // 而那个域名整体是抖音的 —— 这个只能连路径一起看,不然就得把整个域名让出去。
  if (host == 'music.douyin.com' &&
      (uri?.path.startsWith('/qishui') ?? false)) {
    return ParsePlatform.qishuiMusic;
  }
  for (final entry in _kPlatformHosts.entries) {
    if (host == entry.key || host.endsWith('.${entry.key}')) {
      return entry.value;
    }
  }
  return ParsePlatform.unknown;
}

// absoluteMediaUrl 搬去了 upstream_mapping.dart:它是“读应答字段”这一步的一部分
// (被 ParseResult._decode 调用),留在网络层会让模型层反过来依赖路由。

/// 平台中文名。认不出返回空串 —— 卡片上宁可不写,也别写「未知平台」。
String platformLabel(String url) => detectPlatform(url).label;

/// 链接尾部可能粘上的字符:中英文标点、引号、括号。
const String _kTrailingJunk = '.,;:!?)]}。，、！？）》」』"\'';

/// 从粘贴进来的分享文本里挑出真正的链接。
///
/// 各平台复制出来的分享内容都裹着一堆前后缀,例如:
///   「7.62 复制打开抖音,看看【某某的作品】https://v.douyin.com/abc/ 复制此链接…」
/// 整段塞给接口只会解析失败。这里只取第一个 http(s) 链接。
///
/// 返回 null 表示这段文本里没有链接 —— 调用方据此决定要不要改写输入框。
String? extractShareUrl(String raw) {
  // `\S+?` 非贪婪 + `(?=https?://|\s|$)` 前瞻:只在「下一个链接的开头 / 空白 /
  // 文本结尾」三处停下。
  //
  // 原来用的是贪婪的 `https?://\S+`,剪贴板里两条链接紧挨着(中间没有空格)时会把
  // 两条一起吞进来,实测占全部请求的 0.5%,例如:
  //   https://mp.weixin.qq.com/s/St09HkNiic2pKhttps://mp.weixin.qq.com/s/St09HkNiic2pK9ngxghOqw9ngxghOqw
  // 这种拼接串发给接口只会解析失败。
  //
  // 代价:如果某条链接的查询串里带**未做百分号编码**的 `https://`,会在那里被截断。
  // 实测这种写法没有出现过(浏览器和 APP 复制出来的查询串都是 %3A%2F%2F),
  // 而拼接串的 bug 是真实存在的,所以取这一边。
  final match = RegExp(
    r'https?://\S+?(?=https?://|\s|$)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;

  var url = match.group(0)!;

  // 中间没有空格时,链接后面会直接粘上中文(「…/abc/复制此链接」)。
  // 合法 URL 里不会出现裸的中日韩字符(要出现也是百分号编码),所以从这里截断。
  final cjk = RegExp(r'[\u2e80-\u9fff\u3000-\u303f\uff00-\uffef]')
      .firstMatch(url);
  if (cjk != null) url = url.substring(0, cjk.start);

  // 再削掉尾部粘着的标点:句号、逗号、右括号这些。
  while (url.isNotEmpty && _kTrailingJunk.contains(url[url.length - 1])) {
    url = url.substring(0, url.length - 1);
  }

  // 只有 scheme 没有主机名的残片不算链接。
  return url.length > 'https://'.length ? url : null;
}
