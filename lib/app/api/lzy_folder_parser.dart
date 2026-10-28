import 'package:dio/dio.dart';
import 'api_http.dart';
import 'package:flutter/foundation.dart';

import '../models/app_item.dart';

/// 蓝奏云文件夹解析器（★ 在 App 客户端本地解析）
///
/// 为什么放客户端：
///   服务端 IP 被蓝奏云限流（单次会话最多 10 页 / 500 条），
///   而用户手机 IP 是分散的，几乎不会被限流（实测可拿到全部 781 条）。
///
/// 翻页必须同时满足（实测结论）：
///   1) 手机 UA
///   2) Content-Type: application/x-www-form-urlencoded; charset=UTF-8
///   3) 每页间隔 ≥900ms
///   4) pg 从 1 连续递增（不能跳页）
///   5) 需要 puid 参数
class LzyFolderParser {
  LzyFolderParser._();
  static final LzyFolderParser instance = LzyFolderParser._();

  static const String _ua =
      'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

  Dio _dio() => ApiHttp.create(
    BaseOptions(
      headers: {
        'User-Agent': _ua,
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      followRedirects: true,
    ),
  );

  /// 解析文件夹，返回全部软件
  /// [onProgress] 回调：(当前页, 已获取数量)
  Future<List<AppItem>> parse(
    String folderUrl, {
    String pwd = 'password',
    int maxPages = 30,
    String defaultDesc = '',
    String defaultShots = '',
    String defaultIcon = '',
    void Function(int page, int count)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final dio = _dio();
    final uri = Uri.tryParse(folderUrl);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('链接格式不正确');
    }
    final base = '${uri.scheme}://${uri.host}';

    // ① 抓页面拿令牌
    final resp = await dio.get<String>(
      folderUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final html = resp.data ?? '';
    if (html.isEmpty) throw Exception('无法访问该文件夹');

    final t = _tplVar(html, "'t'");
    final k = _tplVar(html, "'k'");
    final fidRaw = _match(html, RegExp(r"'fid'\s*:\s*([^,\n]+)"));
    final fid = fidRaw == null ? '' : fidRaw.replaceAll(RegExp("[\\s'\"]"), '');
    final uid = _match(html, RegExp(r"'uid'\s*:\s*'([^']+)'")) ?? '';
    final puid = _match(html, RegExp(r"'puid'\s*:\s*'([^']+)'")) ?? '';

    debugPrint(
      '[LzyFolder] token: fid=$fid uid=$uid puid=${puid.isNotEmpty} t=$t k=${k.length}位',
    );
    if (fid.isEmpty || uid.isEmpty) {
      throw Exception('无法解析该文件夹（链接可能已失效）');
    }

    // ② 逐页拉取（必须从 1 开始连续）
    final out = <AppItem>[];
    final iconBase = 'https://image.woozooo.com/image/ico/';

    for (int pg = 1; pg <= maxPages; pg++) {
      if (isCancelled?.call() == true) break;

      final body = <String, dynamic>{
        'lx': 2,
        'fid': fid,
        'uid': uid,
        'rep': 0,
        't': t,
        'k': k,
        'up': 1,
        'vip': 0,
        'pg': pg,
        'pwd': pwd,
        'webfoldersign': '',
      };
      if (puid.isNotEmpty) body['puid'] = puid;

      debugPrint('[LzyFolder] page $pg 请求中…');
      Map<String, dynamic>? data;
      try {
        final r = await dio.post(
          '$base/filemoreajax.php?file=$fid',
          data: body,
          options: Options(
            contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
            headers: {
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': folderUrl,
            },
            responseType: ResponseType.json,
          ),
        );
        final d = r.data;
        if (d is Map) data = Map<String, dynamic>.from(d);
      } catch (_) {
        if (pg == 1) throw Exception('网络请求失败，请重试');
        break; // 后续页失败 = 到此为止
      }

      if (data == null || data['zt'] != 1) {
        debugPrint(
          '[LzyFolder] page $pg 失败: zt=${data?['zt']} info=${data?['info']}',
        );
        if (pg == 1) {
          throw Exception((data?['info'] ?? '解析失败').toString());
        }
        break;
      }

      final list = data['text'];
      if (list is! List || list.isEmpty) break;

      for (final it in list) {
        if (it is! Map) continue;
        if ((it['t'] ?? 0) == 2) continue; // 跳过子文件夹
        final name = (it['name_all'] ?? '').toString();
        final id = (it['id'] ?? '').toString();
        if (id.isEmpty) continue;
        out.add(
          AppItem(
            id: 0,
            title: name.replaceAll(
              RegExp(r'\.(apk|ipa|zip|rar|7z)$', caseSensitive: false),
              '',
            ),
            provider: 'lzy',
            url: '$base/$id',
            file: '',
            icon: defaultIcon.isNotEmpty
                ? defaultIcon
                : '$iconBase${it['ico'] ?? ''}',
            size: (it['size'] ?? '').toString(),
            version: _guessVersion(name),
            description: defaultDesc,
            catId: 0,
            weigh: 0,
            views: 0,
            uploadDate: (it['time'] ?? '').toString(),
            isNew: true,
            fromFolder: true,
            screenshots: defaultShots
                .split(',')
                .where((e) => e.trim().isNotEmpty)
                .toList(),
          ),
        );
      }

      debugPrint('[LzyFolder] page $pg 成功: ${list.length} 条, 累计 ${out.length}');
      onProgress?.call(pg, out.length);
      if (list.length < 50) break; // 不足一页 = 到底

      // ★ 间隔 900ms，否则被限流
      await Future.delayed(const Duration(milliseconds: 900));
    }

    if (out.isEmpty) throw Exception('文件夹为空');
    return out;
  }

  /// 从 HTML 里取 "变量名 的值"：例如 't':xxxKey → 再找 xxxKey = '值'
  static String _tplVar(String html, String keyPattern) {
    final key = _match(html, RegExp('$keyPattern\\s*:\\s*([^,\\n]+)'));
    if (key == null) return '';
    final k = key.trim();
    if (k.isEmpty) return '';
    // 如果本身就是字符串字面量
    final lit = RegExp("^'(.*)'\$").firstMatch(k);
    if (lit != null) return lit.group(1) ?? '';
    // 否则在页面里找 `k = '值'`
    final v = _match(html, RegExp('${RegExp.escape(k)}\\s*=\\s*\'([^\']+)\''));
    return v ?? '';
  }

  static String? _match(String src, RegExp re) {
    final m = re.firstMatch(src);
    return m == null ? null : m.group(1)?.trim();
  }

  /// 从文件名猜版本号
  static String _guessVersion(String name) {
    final v = RegExp(r'[vV]\s*(\d+(?:\.\d+){1,3})').firstMatch(name);
    if (v != null) return 'v${v.group(1)}';
    final n = RegExp(r'(?<![\d.])(\d+\.\d+(?:\.\d+){0,2})(?![\d.])')
        .firstMatch(name);
    if (n != null) {
      final s = n.group(1)!;
      if (!RegExp(r'^(19|20)\d{2}\.\d{1,2}\.\d{1,2}$').hasMatch(s))
        return 'v$s';
    }
    return '';
  }
}
