import 'dart:convert';
import 'dart:io';

/// ═══════════════════════════════════════════════════════════════
/// 蓝奏云**本地解析**（1016）
///
/// 复用「移植自 FastAdmin 插件」的算法（与服务端 api.php 同源）：
///   ① GET 分享页 → 提取 file_id / iframe / wp_sign / ajaxdata
///   ② POST {base}/ajaxm.php?file={file_id} → {zt:1, dom, url}
///   ③ GET {dom}/file/{url}（不跟随跳转）→ 取 Location 即真实直链
///
/// 用途：**免费资源**优先本地解析（少一次服务端往返，也不依赖外置接口）；
///   失败时上层会依次降级到「外置解析接口」→「原链接浏览器」。
/// 注意：付费/会员资源**不走本地**（客户端算法可被反编译，会破坏付费墙）。
/// ═══════════════════════════════════════════════════════════════
class LzyLocalParser {
  LzyLocalParser._();

  static const _ua =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

  /// 解析结果：成功返回直链；失败返回 null，并把原因写到 [lastError]
  static String lastError = '';

  static bool isLzyUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('lanzou') ||
        u.contains('lanzn') ||
        u.contains('lzy') && u.contains('52yfx.cn/lzy');
  }

  static Future<String?> parse(String shareUrl) async {
    lastError = '';
    try {
      final p = Uri.tryParse(shareUrl);
      if (p == null || p.host.isEmpty) {
        lastError = '无效的蓝奏云链接';
        return null;
      }
      final base = '${p.scheme}://${p.host}';

      // ── ① 分享页 ──
      final html = await _get(shareUrl, base: shareUrl);
      if (html == null || html.isEmpty) {
        lastError = '请求分享页失败（网络或链接失效）';
        return null;
      }
      // 蓝奏云常见「文件取消分享/不存在」提示
      if (html.contains('文件取消分享') ||
          html.contains('取消分享') ||
          html.contains('文件不存在') ||
          html.contains('来晚了')) {
        lastError = '文件已被取消分享或不存在（资源失效）';
        return null;
      }
      // 页面过短且没有下载入口 → 基本可判定链接失效
      if (html.length < 1800 && !html.contains('ddown') && !html.contains('link.href')) {
        lastError = '页面无下载入口（链接可能已失效）';
        return null;
      }

      // ── ★ 新版页面（蓝奏云已全面改版）：/tp/ 跳转 → vkjxld + hyggid ──
      //   实测链路：
      //     ① 分享页里有 link.href = '/tp/xxx?webtp=…'
      //     ② 请求该地址 → 中间页里 var vkjxld='https://xxx/file/'; var hyggid='?…'
      //     ③ 直链 = vkjxld + hyggid
      if (html.contains('/tp/') || html.contains('webtp=')) {
        final m = RegExp(r'''link\.href\s*=\s*['"]([^'"]+)['"]''').firstMatch(html);
        if (m == null) {
          lastError = '未找到下载跳转（页面结构变化）';
          return null;
        }
        final tp = m.group(1)!;
        final u0 = Uri.tryParse(url);
        final origin = u0 == null ? '' : '${u0.scheme}://${u0.host}';
        final full = tp.startsWith('http') ? tp : '$origin$tp';
        final mid = await _get(full, base: url);
        if (mid == null || mid.isEmpty) {
          lastError = '中间页请求失败';
          return null;
        }
        // 中间页可能是 302 直接给直链
        final direct = RegExp(r'''(https?://[^\s"']+\.(?:apk|zip|rar|7z))''')
            .firstMatch(mid);
        final host = RegExp(r'''var\s+vkjxld\s*=\s*['"]([^'"]+)['"]''').firstMatch(mid);
        final token = RegExp(r'''var\s+hyggid\s*=\s*['"]([^'"]+)['"]''').firstMatch(mid);
        if (host != null && token != null) {
          final link = '${host.group(1)}${token.group(1)}';
          return link;
        }
        if (direct != null) return direct.group(1);
        lastError = '新版解析未拿到地址';
        return null;
      }

      // ── ② 提取参数（旧版结构）──
      var fileId = _pick(html, [
        r'\?f=([^&"\x27]+)',
        r'[\/]f[\/]([a-zA-Z0-9]+)',
        r"'file_id'\s*:\s*'([^']+)'",
        r'fid["\x27]?\s*[:=]\s*["\x27]([a-zA-Z0-9]+)',
      ]);
      final iframeUrl = _pick(html, [
        r'<iframe[^>]*class="[^"]*n_downlink[^"]*"[^>]*src="([^"]+)"',
        r'<iframe[^>]*src="([^"]*(?:down|file)[^"]*)"',
        r'<iframe[^>]*src="([^"]+)"',
      ]);
      var wpSign = _pick(html, [
        r'wp_sign\s*=\s*[\x27"]([^\x27"]+)',
        r"'sign'\s*:\s*'([^']+)'",
        r'sign["\x27]?\s*[:=]\s*["\x27]([^"\x27]+)',
      ]);
      var ajaxdata = _pick(html, [
        r'ajaxdata\s*=\s*[\x27"]([^\x27"]+)',
        r"'websignkey'\s*:\s*'([^']+)'",
      ]);

      // 参数不全 → 再抓 iframe 页面
      if ((wpSign == null || ajaxdata == null) &&
          iframeUrl != null &&
          iframeUrl.isNotEmpty) {
        final full = iframeUrl.startsWith('http')
            ? iframeUrl
            : '$base${iframeUrl.startsWith('/') ? '' : '/'}$iframeUrl';
        final html2 = await _get(full, base: shareUrl);
        if (html2 != null && html2.isNotEmpty) {
          wpSign ??= _pick(html2, [
            r"wp_sign\s*=\s*'([^']+)'",
            r"'sign'\s*:\s*'([^']+)'",
          ]);
          ajaxdata ??= _pick(html2, [
            r"ajaxdata\s*=\s*'([^']+)'",
            r"'websignkey'\s*:\s*'([^']+)'",
          ]);
          fileId ??= _pick(html2, [r'\?f=([^&"\x27]+)']);
        }
      }
      ajaxdata ??= wpSign;

      if (fileId == null || fileId.isEmpty) {
        lastError = '未找到文件标识（页面结构可能已改版）';
        return null;
      }
      if (ajaxdata == null || ajaxdata.isEmpty) {
        lastError = '未找到签名参数（页面结构可能已改版）';
        return null;
      }

      // ── ③ 请求下载信息 ──
      final resp = await _postForm(
        '$base/ajaxm.php?file=$fileId',
        {
          'action': 'downprocess',
          'websignkey': ajaxdata,
          'signs': ajaxdata,
          'sign': wpSign ?? '',
          'websign': '',
          'kd': '1',
          'ves': '1',
        },
        referer: shareUrl,
        origin: base,
      );
      if (resp == null || resp.isEmpty) {
        lastError = '请求下载信息失败';
        return null;
      }
      final j = jsonDecode(resp);
      if (j is! Map ||
          '${j['zt']}' != '1' ||
          '${j['dom'] ?? ''}'.isEmpty ||
          '${j['url'] ?? ''}'.isEmpty) {
        final msg = j is Map ? '${j['inf'] ?? ''}' : '';
        lastError = msg.isEmpty ? '解析接口返回异常（$resp）' : '解析失败：$msg';
        return null;
      }

      // ── ④ 取真实直链（不跟随跳转，读 Location）──
      final direct = '${j['dom']}/file/${j['url']}';
      final loc = await _headLocation(direct, referer: shareUrl);
      if (loc != null && loc.isNotEmpty) {
        return loc;
      }
      // 有些情况下 302 不在第一跳，退回直接把 direct 交给下载器
      if (direct.isNotEmpty) return direct;
      lastError = '未取到直链';
      return null;
    } catch (e) {
      lastError = '本地解析异常：$e';
      return null;
    }
  }

  // ─────────────── HTTP ───────────────
  static Future<String?> _get(String url, {required String base}) async {
    final c = await _client();
    try {
      final req = await c.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', _ua);
      req.headers.set('Referer', base);
      req.headers.set('Accept',
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      req.headers.set('Accept-Language', 'zh-CN,zh;q=0.9');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await res.transform(utf8.decoder).join();
      return body;
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  static Future<String?> _postForm(
    String url,
    Map<String, String> data, {
    required String referer,
    required String origin,
  }) async {
    final c = await _client();
    try {
      final req = await c.postUrl(Uri.parse(url));
      req.headers.set('User-Agent', _ua);
      req.headers.set('Referer', referer);
      req.headers.set('Origin', origin);
      req.headers.set('X-Requested-With', 'XMLHttpRequest');
      req.headers.set('Accept', 'application/json, text/javascript, */*; q=0.01');
      req.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      req.write(data.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&'));
      final res = await req.close().timeout(const Duration(seconds: 20));
      return await res.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  static Future<String?> _headLocation(String url,
      {required String referer}) async {
    final c = await _client();
    try {
      final req = await c.openUrl('GET', Uri.parse(url));
      req.followRedirects = false;
      req.headers.set('User-Agent', _ua);
      req.headers.set('Referer', referer);
      req.headers.set('Accept', 'text/html,*/*;q=0.8');
      req.headers.set('Cookie', 'down_ip=1');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final loc = res.headers.value('location');
      if (loc != null && loc.isNotEmpty) return loc;
      return null;
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  static Future<HttpClient> _client() async {
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (cert, host, port) => true;
    return c;
  }

  static String? _pick(String src, List<String> patterns) {
    for (final p in patterns) {
      try {
        final m = RegExp(p, caseSensitive: false).firstMatch(src);
        if (m != null && m.groupCount >= 1) {
          final v = m.group(1);
          if (v != null && v.isNotEmpty) return v;
        }
      } catch (_) {}
    }
    return null;
  }
}
