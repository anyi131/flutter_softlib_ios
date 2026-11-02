import 'dart:async';
import 'dart:io';

/// ★ 1029i：蓝奏直链多节点换线（零成本）
///
/// 背景：蓝奏同一 token 在 h1051~h1062 各节点**通用**，同一条路径换任何
/// 节点都能下载。之前下载失败只会死磕同一个节点，重试三次等于白试。
///
/// 用途：
///   ① 下载前并发探测，挑一条真能连通的线路（顺带绕开解析到坏 IPv6 的节点）
///   ② 失败重试时按 index 换下一个节点，而不是复用同一条
///
/// 探测开销：每个候选只取 1KB（Range: bytes=0-1023），几乎不耗流量。
class LzyLine {
  LzyLine._();

  // ★ 1103：h1056 / h1062 的 DNS 已不存在（换线时踩空=0 字节秒失败），
  //   实测 206 的只留这 13 个。
  static const List<String> hosts = <String>[
    'h1048', 'h1049', 'h1050', 'h1051', 'h1052', 'h1053', 'h1054',
    'h1055', 'h1057', 'h1058', 'h1059', 'h1060', 'h1061',
  ];

  /// 直链的签发时间（Unix 秒），读不出来返回 0。
  ///
  /// ★ 1103：lanosso 直链是 /32位签名/8位时间戳/年/月/日/文件.apk，
  ///   原来的 `/([0-9a-f]{8})/` 会**先命中 32 位哈希的尾巴**（如 /304e5401/），
  ///   hexdec 出来只有 8 亿 → 一律判 0 → 「新鲜就不重解析」这条优化从没生效过，
  ///   每次重试都去重新解析（白烧一次性票据 + 撞回同一个 15 分钟缓存）。
  static int issuedAt(String url) {
    final m = RegExp(
      r'^https?://[^/]+/[0-9a-fA-F]{16,64}/([0-9a-fA-F]{8})(?:/|\?|$)',
    ).firstMatch(url);
    if (m != null) {
      final h = int.tryParse(m.group(1)!, radix: 16);
      if (h != null && h > 1000000000 && h < 2000000000) return h;
    }
    // 兜底：任意段落里的 8 位 hex（老式直链）
    for (final mm
        in RegExp(r'/([0-9a-fA-F]{8})(?=/|\.|$)').allMatches(url)) {
      final h = int.tryParse(mm.group(1)!, radix: 16);
      if (h != null && h > 1000000000 && h < 2000000000) return h;
    }
    return 0;
  }

  /// 直链剩余寿命（秒），读不出签发时间返回 -1
  static int remainSec(String url) {
    final at = issuedAt(url);
    if (at <= 0) return -1;
    return at + 1800 - DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  static final RegExp _re =
      RegExp(r'^https?://(h\d+)\.lanosso\.com(/[^\s]*)$', caseSensitive: false);

  /// 是否蓝奏 CDN 直链（只有这种才谈得上换节点）
  static bool isDirect(String url) => _re.hasMatch(url);

  /// 取第 index 个节点（不联网）；非蓝奏直链原样返回
  static String rotate(String url, int index) {
    final m = _re.firstMatch(url);
    if (m == null) return url;
    final host = hosts[index.abs() % hosts.length];
    return 'https://$host.lanosso.com${m.group(2)}';
  }

  /// 并发探测前 [tries] 个节点，返回最快的一条；全不通返回 null
  static Future<String?> pickAlive(
    String url, {
    Duration timeout = const Duration(milliseconds: 2500),
    int tries = 4,
  }) async {
    if (!isDirect(url)) return url;
    final List<String> cands = <String>[];
    for (var i = 0; i < tries; i++) {
      final c = rotate(url, i);
      if (!cands.contains(c)) cands.add(c);
    }
    final results = await Future.wait(
      cands.map((u) => _probe(u, timeout)),
    );
    int bestMs = 1 << 30;
    String? best;
    for (var i = 0; i < cands.length; i++) {
      final ms = results[i];
      if (ms != null && ms < bestMs) {
        bestMs = ms;
        best = cands[i];
      }
    }
    return best;
  }

  /// 探测单条直链，返回 HTTP 状态码（200/206=可下，403/410/451=签名失效），
  /// 网络层异常返回 0。重试前用它区分「该续传」还是「该重新解析」。
  static Future<int> probe(String url, {Duration timeout = const Duration(milliseconds: 2500)}) async {
    final code = await _probe(url, timeout);
    if (code != null) return 200;
    // _probe 把非 200/206 也归成 null，无法区分失效/网络断；这里单独再探一次拿真实码
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..userAgent = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
      final resp = await req.close().timeout(timeout);
      try {
        await resp.drain<void>().timeout(timeout);
      } catch (_) {}
      return resp.statusCode;
    } catch (_) {
      return 0;
    } finally {
      client.close(force: true);
    }
  }

  /// 返回耗时（毫秒），不可用返回 null
  static Future<int?> _probe(String url, Duration timeout) async {
    final sw = Stopwatch()..start();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..userAgent = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
      final resp = await req.close().timeout(timeout);
      final code = resp.statusCode;
      try {
        await resp.drain<void>().timeout(timeout);
      } catch (_) {}
      if (code == 200 || code == 206) {
        sw.stop();
        return sw.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
