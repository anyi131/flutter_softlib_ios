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
import 'jicun_config.dart';
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
  Future<ParseResult> parse(String shareUrl) async {
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
    ParseException? mainError;
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
    } on ParseException catch (e) {
      mainError = e;
      lastRoute = 'main-failed';
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
      } on ParseException catch (e) {
        lastRoute = '$lastRoute→backup-failed';
        if (kDebugMode) debugPrint('[jicun] 备用接口也失败: $e');
        throw mainError;
      }
    }
    throw mainError ?? ParseException('解析失败,换个链接或稍后再试');
  }

  Future<ParseResult> _request(
    String endpoint,
    String shareUrl,
    Duration timeout, {
    ParsePlatform? platform,
    required bool fromUpstream,
  }) async {
    if (endpoint.trim().isEmpty) {
      throw ParseException('未配置解析接口:请在后台「解析配置」填写 api_host');
    }
    final uri = Uri.parse(endpoint).replace(
      queryParameters: <String, String>{
        ...Uri.parse(endpoint).queryParameters,
        'url': shareUrl,
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
