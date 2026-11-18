////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 解析服务(宿主版)
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植改造:
//  · 上游用 package:http + 优选 IP + 自建反代(域名池在私有 secrets.dart,不入库);
//    宿主版改为 dart:io HttpClient 直连,接口地址完全由后台「解析配置」下发:
//    api_host(主)/ api_backup(备)/ api_headers(自定义请求头)/
//    upstream_override(平台级覆盖)/ platform_enable(平台开关)。
//  · 上游「付费第三方聚合接口」依赖编译进客户端的密钥,宿主不移植(红线:不输出
//    密钥);平台的第三方接口地址可由后台 upstream_override 按平台下发。
//  · 应答归一化复用上游 jicun_upstream_mapping.dart(fromJson / fromUpstream /
//    fromQishuiMusic 三套形状都认)。
// 版权与许可遵循上游 MIT License,见仓库 LICENSE。
////////////////////////////////////////////////////////////////////////////////
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'jicun_api_host.dart';
import '../api/api_host.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'jicun_config.dart';
import '../api/user_service.dart';
import 'jicun_platform.dart';
import 'jicun_upstream_mapping.dart';

export 'jicun_platform.dart';
export 'jicun_upstream_mapping.dart'
    show ParseException, ParseResult, VideoQuality, VideoItem, LivePhoto;

/// 解析服务。
///
/// 路由(与上游同构):
///  1. 平台在 platform_enable 里被关掉 → 本地直接拒,一次请求都不发;
///  2. 平台在 upstream_override 里配了独立 api → 先打它(超时更短,失败回落主接口);
///  3. 其余平台 → 打主接口(api_host,空 = 上游默认),失败再打备用(api_backup)。
class JicunParseService {
  JicunParseService();

  /// 解析实际上走了哪条路,排障用。
  String? lastRoute;

  /// 主接口的兜底超时(后台 timeout,默认 20s)。
  Duration get _timeout => Duration(
    seconds: (JicunSettings.instance.cfg.timeout <= 0
        ? 20
        : JicunSettings.instance.cfg.timeout),
  );

  /// 第三方/覆盖接口的超时,比主接口短:失败还要回落,两次串起来不能让用户等太久。
  Duration get _upstreamTimeout => Duration(
    seconds: (JicunSettings.instance.cfg.timeout <= 0
        ? 12
        : (JicunSettings.instance.cfg.timeout * 3) ~/ 5),
  );

  /// 1109r：最近一次解析的配额（服务端下发 quota.remaining），
  ///   放在这里而不是塞进 ParseResult —— 避免动那个类的结构。
  static int lastRemaining = -1;
  static int lastLimit = -1;

  HttpClient? _shared;
  HttpClient get _client => _shared ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..idleTimeout = const Duration(seconds: 15);

  /// 主接口地址(后台 api_host,空 = 上游默认)。
  String get _mainEndpoint => apiUrl('/parse');

  /// 备用接口地址(后台 api_backup;按 media-parser 形状对接,同样以 /parse 收口)。
  String? get _backupEndpoint {
    final b = JicunSettings.instance.cfg.apiBackup.trim();
    if (b.isEmpty) return null;
    return b.endsWith('/') ? '${b}parse' : '$b/parse';
  }

  /// 自定义请求头(后台 api_headers)。
  Map<String, String> get _extraHeaders =>
      JicunSettings.instance.cfg.headersMap();

  /// 平台开关(后台 platform_enable)。名单拉不到(空)时不拦。
  Map<String, bool> get _platformEnable =>
      JicunSettings.instance.cfg.platformEnableMap();

  /// 平台级覆盖(后台 upstream_override):{「抖音」: {api:.., enable:..}}。
  Map<String, Map<String, dynamic>> get _override =>
      JicunSettings.instance.cfg.overrideMap();

  /// 解析一条分享链接。
  // ─────────────── 1109s：解析监控上报（fire-and-forget） ───────────────
  static Future<void> reportStat(String url, bool ok, String route,
      int ms, String err, String platform) async {
    HttpClient? c;
    try {
      c = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await c.postUrl(Uri.parse('${ApiHost.base}/api/softlib/jicun/report'));
      req.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      req.add(utf8.encode(Uri(queryParameters: {
        'url': url,
        'ok': ok ? '1' : '0',
        'route': route,
        'ms': '$ms',
        'err': err,
        'platform': platform,
      }).query));
      await req.close().timeout(const Duration(seconds: 6));
    } catch (_) {
    } finally {
      try {
        c?.close(force: true);
      } catch (_) {}
    }
  }

  Future<ParseResult> parse(String shareUrl) async {
    final _sw = Stopwatch()..start();
    final platform = detectPlatform(shareUrl);
    final label = platform.label;
    final enableMap = _platformEnable;

    // 1. 平台被后台关掉 → 本地拦掉(上游同款:只拦走主接口的请求)。
    if (enableMap.isNotEmpty && label.isNotEmpty) {
      final on = enableMap[label];
      if (on == false) {
        lastRoute = 'blocked-platform';
        throw ParseException('「$label」已被后台关闭,暂不支持解析');
      }
    }

    lastRoute = '';

    // 1.5 1109s：先直连 MeowSave（用各自 IP，不经过本站服务器）
    //   成功就直接返回；失败（网络/配额/风控）静默回落到服务端链路。
    try {
      final direct = await _parseDirect(shareUrl);
      if (direct != null &&
          (direct.hasVideo || direct.hasImages || direct.hasAudio)) {
        lastRoute = 'direct-meow';
        return direct;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[meow] 直连失败，回落服务端: $e');
    }

    // 2. 平台级覆盖。
    final ov = label.isNotEmpty ? _override[label] : null;
    if (ov != null) {
      final ovOn = ov['enable'];
      if (ovOn == false || ovOn == 0 || ovOn == '0') {
        lastRoute = 'blocked-override';
        throw ParseException('「$label」已被后台关闭,暂不支持解析');
      }
      final ovApi = '${ov['api'] ?? ''}'.trim();
      if (ovApi.isNotEmpty) {
        // 覆盖接口失败照样回落主接口 —— 上游同款语义。
        try {
          final r = await _request(
            ovApi.endsWith('/') ? '${ovApi}parse' : '$ovApi/parse',
            shareUrl,
            _upstreamTimeout,
            platform: platform,
            fromUpstream: true,
          );
          if (r.hasVideo || r.hasImages || r.hasAudio) {
            lastRoute = 'override:$label';
            return r;
          }
          lastRoute = 'override:$label-empty';
        } on ParseException catch (e) {
          lastRoute = 'override:$label-failed';
          if (kDebugMode) debugPrint('[jicun] 覆盖接口失败: $e');
        }
      }
    }

    // 3. 主接口 → 备用接口。
    // ★ v331w：主接口失败回落备用——网络异常(SocketException/Timeout/
    //   Handshake)也要回落(此前只 catch ParseException,SNI 阻断时备用接口
    //   根本没试,直接冒泡成「网络异常」)。
    Object? mainError;
    try {
      final r = await _request(
        _mainEndpoint,
        shareUrl,
        _timeout,
        platform: platform,
        fromUpstream: true,
      );
      lastRoute = 'main';
      return r;
    } catch (e) {
      mainError = e;
      lastRoute = 'main-failed';
      if (kDebugMode) debugPrint('[jicun] 主接口失败: $e');
    }
    final backup = _backupEndpoint;
    if (backup != null && backup != _mainEndpoint) {
      try {
        final r = await _request(
          backup,
          shareUrl,
          _timeout,
          platform: platform,
          fromUpstream: true,
        );
        lastRoute = '$lastRoute→backup';
        return r;
      } catch (e) {
        lastRoute = '$lastRoute→backup-failed';
        if (kDebugMode) debugPrint('[jicun] 备用接口也失败: $e');
      }
    }
    final msg = mainError?.toString() ?? '';
    final friendly = msg.contains('TimeoutException')
        ? '解析超时,请检查网络后重试'
        : msg.contains('SocketException') || msg.contains('Handshake')
        ? '网络连接失败(接口域名可能被阻断),请稍后重试'
        : msg.replaceFirst('Exception: ', '');
    throw mainError is ParseException
        ? mainError
        : ParseException(friendly.isEmpty ? '解析失败,请稍后再试' : friendly);
  }

  // ─────────────── 1109s：直连 MeowSave（各自 IP，不过本站服务器） ───────────────
  static const String _meowBase = 'https://api.videofix.top/meow';
  static const String _meowUa = 'MeowSave/1.1.5 (Android34;Pixel 7)';

  static int _meowVid = 0;
  static String _meowTok = '';
  static bool _meowLoaded = false;

  Future<void> _loadMeowIdentity() async {
    if (_meowLoaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      _meowVid = sp.getInt('meow_visitor_id') ?? 0;
      _meowTok = sp.getString('meow_visitor_token') ?? '';
    } catch (_) {}
    _meowLoaded = true;
  }

  Future<void> _saveMeowIdentity(int vid, String tok) async {
    _meowVid = vid;
    _meowTok = tok;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('meow_visitor_id', vid);
      await sp.setString('meow_visitor_token', tok);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _meowPost(
      String path, Map<String, dynamic> body) async {
    HttpClient? c;
    try {
      c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await c.postUrl(Uri.parse('$_meowBase$path'));
      req.headers.set('Content-Type', 'application/json; charset=utf-8');
      req.headers.set('Accept', 'application/json');
      req.headers.set('User-Agent', _meowUa);
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close().timeout(const Duration(seconds: 20));
      final txt = await resp.transform(utf8.decoder).join();
      final j = jsonDecode(txt);
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (e) {
      if (kDebugMode) debugPrint('[meow] $path 失败: $e');
      return null;
    } finally {
      try {
        c?.close(force: true);
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> _meowRegister() async {
    final j = await _meowPost('/api/v1/visitor/register', {
      'install_id': DateTime.now().microsecondsSinceEpoch.toRadixString(16),
      'model': 'Pixel 7',
      'brand': 'google',
      'manufacturer': 'Google',
      'android': '14',
      'sdk': 34,
      'app_version': '1.1.5',
      'app_code': 4,
      'screen': '1080x2400',
      'locale': 'zh-CN',
    });
    if (j == null || j['ok'] != true) return null;
    final d = j['data'];
    if (d is! Map) return null;
    final vid = (d['visitor_id'] as num?)?.toInt() ?? 0;
    final tok = '${d['token'] ?? ''}';
    if (vid <= 0 || tok.isEmpty) return null;
    await _saveMeowIdentity(vid, tok);
    return Map<String, dynamic>.from(d);
  }

  Map<String, dynamic> _meowToMediaParser(Map<String, dynamic> d) {
    final items = (d['items'] is List) ? d['items'] as List : const [];
    final videos = <Map<String, dynamic>>[];
    final images = <String>[];
    for (final it in items) {
      if (it is! Map) continue;
      final u = '${it['url'] ?? ''}';
      if (!u.startsWith('http')) continue;
      final kind = '${it['kind'] ?? 'video'}';
      if (kind == 'video' || kind == 'audio') {
        videos.add(Map<String, dynamic>.from(it));
      } else {
        images.add(u);
      }
    }
    final main = videos.isNotEmpty ? videos.first : null;
    return {
      'platform': '${d['platform'] ?? ''}',
      'title': '${d['title'] ?? ''}',
      'desc': '${d['desc'] ?? ''}',
      'cover': '${d['cover'] ?? ''}',
      'author': {'name': '${d['author'] ?? ''}'},
      'url': main != null ? '${main['url']}' : '',
      'label': main != null ? '${main['label'] ?? ''}' : '',
      'size': main != null ? (main['size'] ?? 0) : 0,
      'bit_rate': main != null ? (main['bit_rate'] ?? 0) : 0,
      'format': main != null ? '${main['format'] ?? 'mp4'}' : 'mp4',
      'images': images,
      'video_backup': videos
          .skip(1)
          .map((v) => {
                'url': '${v['url']}',
                'label': '${v['label'] ?? ''}',
                'size': v['size'] ?? 0,
              })
          .toList(),
      'quota': d['quota'],
    };
  }

  Future<ParseResult?> _parseDirect(String shareUrl) async {
    await _loadMeowIdentity();
    if (_meowTok.isEmpty) {
      final reg = await _meowRegister();
      if (reg == null) return null;
    }
    var j = await _meowPost('/api/v1/parse', {
      'url': shareUrl,
      'interface': 'jhjx3',
      'visitor_id': _meowVid,
      'visitor_token': _meowTok,
    });
    if (j != null && j['ok'] != true) {
      final err = j['error'];
      final code = (err is Map) ? '${err['code'] ?? ''}' : '';
      if (code == 'unauthorized') {
        await _saveMeowIdentity(0, '');
        final reg = await _meowRegister();
        if (reg != null) {
          j = await _meowPost('/api/v1/parse', {
            'url': shareUrl,
            'interface': 'jhjx3',
            'visitor_id': _meowVid,
            'visitor_token': _meowTok,
          });
        }
      }
    }
    if (j == null || j['ok'] != true) return null;
    final d = j['data'];
    if (d is! Map) return null;
    final mapped = _meowToMediaParser(Map<String, dynamic>.from(d));
    try {
      final q = mapped['quota'];
      if (q is Map) {
        final r = q['remaining'];
        final l = q['daily_limit'];
        if (r is num) lastRemaining = r.toInt();
        if (l is num) lastLimit = l.toInt();
      }
    } catch (_) {}
    if ('${mapped['url']}'.isEmpty && (mapped['images'] as List).isEmpty) {
      return null;
    }
    return ParseResult.fromUpstream(mapped);
  }

  Future<ParseResult> _request(
    String endpoint,
    String shareUrl,
    Duration timeout, {
    ParsePlatform? platform,
    required bool fromUpstream,
  }) async {
    if (endpoint.trim().isEmpty || endpoint.contains('example.com')) {
      // 1109n：默认 host 是占位域名 media-parser.example.com，
      //   请求过去只会拿回一段 HTML，最后报「返回内容无法识别」——用户根本看不懂。
      //   这里直接说清楚：后台没配解析接口。
      throw ParseException(
        '未配置解析接口\n请在后台「解析配置」填写 api_host（需支持 /parse 协议）',
      );
    }
    // 1109q：解析接口按用户分配配额，必须带上本站登录 token
    String _token = '';
    try {
      _token = UserService.instance.token;
    } catch (_) {}
    final uri = Uri.parse(endpoint).replace(
      queryParameters: <String, String>{
        ...Uri.parse(endpoint).queryParameters,
        'url': shareUrl,
        if (_token.isNotEmpty) 'token': _token,
      },
    );
    final req = await _client.getUrl(uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    _extraHeaders.forEach(req.headers.set);
    final resp = await req.close().timeout(timeout);
    final bodyText = await resp.transform(utf8.decoder).join().timeout(timeout);
    if (resp.statusCode != 200) {
      throw ParseException('服务器异常(${resp.statusCode}),请稍后再试');
    }
    Map<String, dynamic>? body;
    try {
      final d = jsonDecode(bodyText);
      if (d is Map) body = Map<String, dynamic>.from(d);
    } catch (_) {}
    if (body == null) {
      if (kDebugMode) {
        debugPrint(
          '[jicun] 解析应答不是 JSON($endpoint): '
          '${bodyText.length > 200 ? bodyText.substring(0, 200) : bodyText}',
        );
      }
      throw ParseException('返回内容无法识别');
    }
    // 1109r：记下剩余次数（不动 ParseResult）
    try {
      final q = body['quota'] ??
          (body['data'] is Map ? (body['data'] as Map)['quota'] : null);
      if (q is Map) {
        final r = q['remaining'];
        final l = q['daily_limit'];
        if (r is num) lastRemaining = r.toInt();
        if (l is num) lastLimit = l.toInt();
      }
    } catch (_) {}
    if (_isSuccess(body) && _dataOf(body) is Map) {
      // 明文地址在这里统一升 https(上游同款,Android 禁明文)。
      final data = secureMediaUrls(_dataOf(body)) as Map<String, dynamic>;
      if (!fromUpstream) return ParseResult.fromJson(data);
      return platform == ParsePlatform.qishuiMusic
          ? ParseResult.fromQishuiMusic(data)
          : ParseResult.fromUpstream(data, platform: platform?.label ?? '');
    }
    final retdesc =
        _str(body['retdesc']) ??
        _str(body['error']) ??
        _str(body['message']) ??
        _str(body['msg']);
    if (retdesc != null) throw ParseException(retdesc);
    throw ParseException('解析失败(${resp.statusCode}),换个链接或稍后再试');
  }

  static bool _isSuccess(Map<String, dynamic> body) {
    if (body['succ'] == true) return true;
    final code = body['code'] ?? body['retcode'] ?? body['status'];
    if (code is num) return code == 200 || code == 0;
    if (code is String) {
      final text = code.trim();
      return text == '200' || text == '0' || text.toLowerCase() == 'ok';
    }
    return _dataOf(body) is Map;
  }

  static Object? _dataOf(Map<String, dynamic> body) =>
      body['data'] is Map ? body['data'] : body['result'];

  static String? _str(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  void dispose() {
    _shared?.close(force: true);
    _shared = null;
  }
}

/// 全局一份解析服务。
final JicunParseService jicunParseService = JicunParseService();
