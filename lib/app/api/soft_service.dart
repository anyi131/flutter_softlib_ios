import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import 'api_host.dart';

import '../models/app_cat.dart';
import '../models/app_config.dart';
import '../models/app_item.dart';
import 'user_service.dart';

/// 软件数据服务（Dio 直连，不依赖 retrofit 生成代码）
class SoftService {
  SoftService._();
  static final SoftService instance = SoftService._();

  static const String baseUrl = ApiHost.base;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 12),
      // 连接复用（加快连续请求）
      persistentConnection: true,
    ),
  )..interceptors.add(_RetryInterceptor());

  /// 供工具模块复用同一个 Dio（连接复用 + 重试策略一致）
  Dio get dio => _dio;

  /// 工具 Tab 数据（分类 + 条目）—— 需求 v43 #5
  Future<List<Map<String, dynamic>>> fetchTools() async {
    try {
      final r = await dio.get('/api/softlib/tool/index');
      if (r.data is Map && r.data['code'] == 1) {
        final d = r.data['data'];
        if (d is List) {
          return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('[Softlib] tools: $e');
    }
    return [];
  }

  /// 拉取全局配置（开屏/公告/远程控制）
  /// ★ 带内存缓存 + 并发去重：同一次会话内多个页面同时调用只发一次网络请求
  /// ★ 1015：设备型号（崩溃日志用）
  static String deviceModel = '';

  AppConfig? _configCache;
  DateTime? _configAt;
  Future<AppConfig?>? _configInflight;
  static const _configTtl = Duration(minutes: 10);

  /// v52m #11：同步取最近一次配置（未拉取过返回 null）
  AppConfig? get cachedConfig => _configCache;

  /// v52p #11：配置版本号 —— 每次成功拉取+1，UI 监听它即时重建
  final RxInt configVersion = 0.obs;

  Future<AppConfig?> fetchConfig({bool force = false}) async {
    if (!force &&
        _configCache != null &&
        _configAt != null &&
        DateTime.now().difference(_configAt!) < _configTtl) {
      return _configCache;
    }
    // 并发去重：已有请求在飞就复用
    if (_configInflight != null) return _configInflight;
    final fut = _fetchConfigInner();
    _configInflight = fut;
    try {
      return await fut;
    } finally {
      _configInflight = null;
    }
  }

  Future<AppConfig?> _fetchConfigInner() async {
    try {
      final resp = await dio.get('/api/softlib/config/index');
      final data = resp.data;
      if (data is Map && data['code'] == 1 && data['data'] is Map) {
        final cfg = AppConfig.fromJson(Map<String, dynamic>.from(data['data']));
        _configCache = cfg;
        _configAt = DateTime.now();
        configVersion.value++;
        return cfg;
      }
    } catch (e) {
      debugPrint('[Softlib] $e');
    }
    return _configCache; // 失败时退回旧缓存（若有）
  }

  /// 本地缓存（避免重复请求，加快页面切换）
  static final Map<String, _CacheEntry> _cache = {};
  static const _cacheTtl = Duration(minutes: 3);

  /// 软件列表（catId=0 / keyword 为空表示全部）
  /// force=true 时跳过缓存
  Future<List<AppItem>> fetchApps({
    int catId = 0,
    String keyword = '',
    String provider = '',
    bool force = false,
  }) async {
    final key = 'apps_${catId}_${keyword}_$provider';
    if (!force) {
      final hit = _cache[key];
      if (hit != null && !hit.expired) return hit.data as List<AppItem>;
    }
    final t0 = DateTime.now();
    final resp = await dio.get(
      '/api/softlib/app/index',
      queryParameters: {
        if (catId > 0) 'cat_id': catId,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (provider.isNotEmpty) 'provider': provider,
      },
    );
    final data = resp.data;
    if (data is Map && data['code'] == 1) {
      final list = AppItem.listFrom(data['data']);
      _cache[key] = _CacheEntry(list);
      debugPrint(
        '[Softlib] fetchApps ${DateTime.now().difference(t0).inMilliseconds}ms (${list.length}条)',
      );
      return list;
    }
    throw Exception((data is Map ? data['msg'] : '获取软件列表失败') ?? '获取失败');
  }

  /// 清空缓存（下拉刷新时用）
  static void clearCache() => _cache.clear();

  /// 工具箱配置缓存（由文件末尾的 ToolboxService 扩展维护，这里给类一个同步入口）
  static Map<String, dynamic>? get toolboxCache => ToolboxService._jzsCache;

  /// 检查更新（兼容后端返回 List 或 Map）
  /// 返回：null=已是最新；Map=有新版本
  Future<Map<String, dynamic>?> checkVersion(String currentVersion) async {
    try {
      final resp = await dio.get(
        '/api/softlib/version/index',
        queryParameters: {'oldversion': currentVersion},
      );
      final d = resp.data;
      if (d is! Map || d['code'] != 1) return null;
      final data = d['data'];
      Map<String, dynamic>? latest;
      if (data is List) {
        for (final it in data) {
          if (it is Map) latest = Map<String, dynamic>.from(it);
        }
      } else if (data is Map) {
        latest = Map<String, dynamic>.from(data);
      }
      if (latest == null) return null;
      final url = (latest['dow_url'] ?? '').toString();
      if (url.isEmpty) return null;
      return latest;
    } catch (_) {
      return null;
    }
  }

  /// 软件分类（含数量）
  Future<List<AppCat>> fetchCats() async {
    try {
      final resp = await dio.get('/api/softlib/app/cats');
      final data = resp.data;
      if (data is Map && data['code'] == 1)
        return AppCat.listFrom(data['data']);
    } catch (e) {
      debugPrint('[Softlib] $e');
    }
    return [];
  }

  /// 拉取蓝奏云文件夹里的软件列表
  Future<List<AppItem>> fetchFolder(
    String url, {
    String pwd = '',
    int pgs = 1,
  }) async {
    final resp = await dio.get(
      '/api/softlib/app/folder',
      queryParameters: {'url': url, 'pgs': pgs, if (pwd.isNotEmpty) 'pwd': pwd},
      options: Options(receiveTimeout: const Duration(seconds: 50)),
    );
    final data = resp.data;
    if (data is Map && data['code'] == 1) return AppItem.listFrom(data['data']);
    throw Exception((data is Map ? data['msg'] : '获取文件夹失败') ?? '获取失败');
  }

  /// 软件详情
  Future<AppItem?> fetchAppDetail({int id = 0, String url = ''}) async {
    final resp = await dio.get(
      '/api/softlib/app/detail',
      queryParameters: {if (id > 0) 'id': id, if (url.isNotEmpty) 'url': url},
    );
    final data = resp.data;
    if (data is Map && data['code'] == 1 && data['data'] is Map) {
      return AppItem.fromJson(Map<String, dynamic>.from(data['data']));
    }
    return null;
  }

  /// 自建蓝奏云解析服务
  static const String kLzyProxy = ApiHost.lzyProxy;

  /// 最近一次解析失败的具体原因（来自解析服务 msg / 异常摘要），
  /// 供调用方 toast/弹窗展示，避免用户只看到笼统的「解析失败」
  static String lastParseError = '';

  /// 后端解析兜底（★ 1014：带 token + 票据，服务端强制校验）
  /// 支持两种地址：
  ///   ① 单文件分享页（形如 /iXXXX）→ 走 lzy_file_parse
  ///   ② 文件夹分享页（形如 /bXXXX）→ 走 lzydirparse 取首个 apk
  /// ★ App 更新包常配成文件夹地址，原实现只调单文件解析 → 更新永远失败。
  Future<String?> resolveLzyByServer(String lzyUrl, {String? ticket}) async {
    final token = UserService.instance.token;
    if (token.isEmpty) {
      lastParseError = '请先登录后再下载';
      return null;
    }

    // ① 先按单文件解析
    final single = await _parseSingle(lzyUrl, token, ticket);
    if (single != null && single.isNotEmpty) return single;

    // ② 单文件失败 → 按文件夹解析，取里面第一个安装包
    final dirFile = await _parseFolder(lzyUrl, token, ticket);
    if (dirFile != null && dirFile.isNotEmpty) return dirFile;

    return null;
  }

  /// 单文件解析
  Future<String?> _parseSingle(
    String lzyUrl,
    String token,
    String? ticket,
  ) async {
    try {
      final resp = await dio.post(
        '/api/softlib/lzy_file_parse',
        data: {
          'token': token,
          'url': lzyUrl,
          if (ticket != null) 'ticket': ticket,
        },
        options: Options(receiveTimeout: const Duration(seconds: 40)),
      );
      final data = resp.data;
      if (data is Map && data['code'] == 1) {
        final u = (data['data'] is Map) ? (data['data']['url'] ?? '') : '';
        if (u.toString().isNotEmpty) return u.toString();
      } else if (data is Map && data['msg'] is String) {
        lastParseError = data['msg'] as String;
      }
    } catch (e) {
      debugPrint('[Softlib] single: $e');
    }
    return null;
  }

  /// 文件夹解析：取里面第一个 .apk 的直链
  Future<String?> _parseFolder(
    String lzyUrl,
    String token,
    String? ticket,
  ) async {
    try {
      final resp = await dio.post(
        '/api/softlib/lzydirparse',
        data: {
          'token': token,
          'url': lzyUrl,
          'pwd': 'password',
          if (ticket != null) 'ticket': ticket,
        },
        options: Options(receiveTimeout: const Duration(seconds: 50)),
      );
      final data = resp.data;
      if (data is Map && data['code'] == 1 && data['data'] is List) {
        final list = (data['data'] as List).whereType<Map>().toList();
        if (list.isEmpty) return null;
        // 优先取 apk/ipa，其次取第一个文件
        Map? pick;
        for (final f in list) {
          final nm = '${f['name_all'] ?? f['name'] ?? ''}'.toLowerCase();
          if (nm.endsWith('.apk') || nm.endsWith('.ipa')) {
            pick = f;
            break;
          }
        }
        pick ??= list.firstWhere(
          (f) => '${f['is_dir'] ?? 0}' != '1',
          orElse: () => list.first,
        );
        final down = '${pick['down'] ?? ''}';
        if (down.isEmpty) return null;
        // ★ 票据与 url 绑定且一次性 → 必须为这个文件页「重新领票」再解析
        final t2 = await _applyParseTicket(down);
        if (t2 == null) return null;
        // 先走自建接口（解析能力更强），再走主站
        final viaApi = await resolveLzyByApi(down, ticket: t2);
        if (viaApi != null && viaApi.isNotEmpty) return viaApi;
        final t3 = await _applyParseTicket(down);
        if (t3 == null) return null;
        return await _parseSingle(down, token, t3);
      }
      if (data is Map && data['msg'] is String) {
        lastParseError = data['msg'] as String;
      }
    } catch (e) {
      debugPrint('[Softlib] folder: $e');
    }
    return null;
  }

  /// 蓝奏云解析
  /// ★ 1014 安全：两级解析都保留（自建 API 优先，后端兜底），
  ///   但两者都必须先通过服务端鉴权 —— 否则解析直链就成了付费绕过口。
  ///   鉴权由服务端 /api/softlib/lzy/auth 统一裁决，客户端无法跳过。
  Future<String?> resolveLzy(String lzyUrl) async {
    lastParseError = '';
    // ① 先向服务端申请「本次解析放行票据」
    final ticket = await _applyParseTicket(lzyUrl);
    if (ticket == null) return null; // 未登录 / 无权限 / 网络异常 → 一律不解析

    // ② 自建 API 优先（运维可随时更新，无需发版）
    final a = await resolveLzyByApi(lzyUrl, ticket: ticket);
    if (a != null && a.isNotEmpty) return a;
    // ③ 后端解析兜底
    return resolveLzyByServer(lzyUrl, ticket: ticket);
  }

  /// ★ 1014：向服务端申请解析放行票据。
  /// 服务端会校验登录态 + 该资源是否付费/会员专享 + 是否已购买，
  /// 通过才返回票据；客户端拿不到票据就不解析，从根上堵死绕过。
  Future<String?> _applyParseTicket(String lzyUrl) async {
    try {
      final token = UserService.instance.token;
      if (token.isEmpty) {
        lastParseError = '请先登录后再下载';
        return null;
      }
      final resp = await dio.post(
        '/api/softlib/lzy/auth',
        data: {'token': token, 'url': lzyUrl},
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      final d = resp.data;
      if (d is Map && d['code'] == 1) {
        final t = (d['data'] is Map) ? (d['data']['ticket'] ?? '') : '';
        if (t.toString().isNotEmpty) return t.toString();
      }
      if (d is Map && d['msg'] is String) lastParseError = d['msg'] as String;
    } catch (e) {
      debugPrint('[Softlib] auth: $e');
      lastParseError = '无法连接服务器完成校验';
    }
    return null;
  }

  /// 自建 API 解析直链（运维入口，服务端已发票据后才调用）
  Future<String?> resolveLzyByApi(String lzyUrl, {String? ticket}) async {
    try {
      // ★ 1014：自建解析接口只需 url + 服务端签发的票据，
      //   不再传递站点登录 token（第三方域名不该拿到用户凭证）。
      //   鉴权已由主站 /lzy/auth 完成，票据一次性有效。
      final resp = await dio.post(
        kLzyProxy,
        data: {
          'url': lzyUrl,
          if (ticket != null) 'ticket': ticket,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          // 兼容只读 $_POST/$_REQUEST 的简单脚本
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      final d = resp.data;
      if (d is Map) {
        final okCode = d['code'] == 200 || d['code'] == 1 || d['code'] == '200';
        if (!okCode && d['msg'] is String && (d['msg'] as String).isNotEmpty) {
          lastParseError = d['msg'] as String; // 如「文件取消分享了」
        }
        if (okCode) {
          for (final k in [
            'downUrl',
            'downurl',
            'downURL',
            'url',
            'Url',
            'URL',
            'download',
            'link',
            'data',
          ]) {
            final v = d[k];
            if (v is String && v.startsWith('http')) return v;
            if (v is Map) {
              for (final k2 in [
                'downUrl',
                'downurl',
                'url',
                'download',
                'link',
              ]) {
                final v2 = v[k2];
                if (v2 is String && v2.startsWith('http')) return v2;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Softlib] $e');
    }
    return null;
  }

  /// 软件浏览量 +1
  Future<void> addAppView(int id) async {
    if (id <= 0) return;
    try {
      await dio.get('/api/softlib/app/view', queryParameters: {'id': id});
    } catch (e) {
      debugPrint('[Softlib] $e');
    }
  }

  /// 蓝奏云文件信息（文件名/大小/图标/描述）
  /// ★ 带内存缓存，同一链接 10 分钟内不重复请求
  Future<Map<String, dynamic>?> lzyFileInfo(String lzyUrl) async {
    final ck = 'lzyinfo_$lzyUrl';
    final hit = _cache[ck];
    if (hit != null && !hit.expired) return hit.data as Map<String, dynamic>?;
    final resp = await dio.get(
      '/api/softlib/lzy_file_info',
      queryParameters: {'url': lzyUrl},
      options: Options(receiveTimeout: const Duration(seconds: 12)),
    );
    final data = resp.data;
    if (data is Map && data['code'] == 1 && data['data'] is Map) {
      final map = Map<String, dynamic>.from(data['data']);
      _cache[ck] = _CacheEntry(map);
      return map;
    }
    return null;
  }

  /// 统一解析：返回可直接下载的 URL
  /// - 服务器直传：直接返回 file
  /// - 蓝奏云：走解析接口
  Future<String?> resolveDownloadUrl(AppItem item) async {
    if (item.canDirectDownload) return item.file;
    if (item.url.isNotEmpty) return resolveLzy(item.url);
    return null;
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime at;
  _CacheEntry(this.data) : at = DateTime.now();
  bool get expired => DateTime.now().difference(at) > SoftService._cacheTtl;
}

/// 自动重试拦截器
// ═══════════════════════════════════════════════════════════════
//  工具体系（v56 恢复 + 做扎实）—— 简助手 / 工具箱 系列接口
//  后端：/api/softlib/jzs/*、/api/softlib/toolbox/*、/api/softlib/toolbox2/*
// ═══════════════════════════════════════════════════════════════

extension ToolboxService on SoftService {

  // ─────────── 工具页配置（分类 + 工具 + 横幅） ───────────

  /// ⚠ 历史方法名保留，内部同 fetchJzsConfig，避免旧调用点报错
  Future<Map<String, dynamic>?> fetchJzsConfig({bool force = false}) =>
      SoftService.instance.toolboxConfig(force: force);

  /// 工具配置缓存
  static Map<String, dynamic>? _jzsCache;
  static DateTime? _jzsAt;
  static Map<String, dynamic>? get cachedToolboxConfig => _jzsCache;

  /// 拉取工具箱配置（分组 + 工具 + 横幅）；带 10 分钟内存缓存
  /// 拉取工具箱配置（分组 + 工具 + 横幅）
  /// ★ 1015：缓存从 10 分钟缩到 2 分钟 —— 后台加了新工具能更快在 App 里看到。
  ///   （切回前台时仍会 force 刷新，这里只是兜底「长时间不切换」的场景）
  Future<Map<String, dynamic>?> toolboxConfig({bool force = false}) async {
    if (!force &&
        _jzsCache != null &&
        _jzsAt != null &&
        DateTime.now().difference(_jzsAt!) < const Duration(minutes: 2)) {
      return _jzsCache;
    }
    try {
      final r = await dio.get(
        '/api/softlib/jzs/config',
        options: Options(receiveTimeout: const Duration(seconds: 18)),
      );
      if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
        _jzsCache = Map<String, dynamic>.from(r.data['data'] as Map);
        _jzsAt = DateTime.now();
        return _jzsCache;
      }
    } catch (e) {
      debugPrint('[Softlib] toolbox config: $e');
    }
    return _jzsCache;
  }

  /// ★ 1015：把崩溃日志上报到服务器（release 版看不到 debugPrint）
  /// 用于排查真机闪退，后台可查 fa_softlib_crash_log
  Future<void> reportLog({
    required String tag,
    required String error,
    String stack = '',
    String version = '',
  }) async {
    try {
      await dio.post(
        '/api/softlib/log/report',
        data: {
          'tag': tag,
          'error': error.length > 1800 ? error.substring(0, 1800) : error,
          'stack': stack.length > 5000 ? stack.substring(0, 5000) : stack,
          'device': SoftService.deviceModel,
          'version': version,
        },
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
    } catch (_) {
      // 上报失败就算了，绝不能因为上报再崩一次
    }
  }

  /// ★ 1015：图片代理 —— 某些图床（网易云 CDN）对部分运营商 403，
  ///   走自己的服务器中转，App 只连本站，彻底绕开网络屏蔽。
  ///   只对白名单域名生效（服务端校验）。
  static String proxyImage(String url) {
    if (url.isEmpty || !url.startsWith('http')) return url;
    // 只代理已知会 403 的域名，其他直连（省服务器带宽）
    const need = ['music.126.net', 'baozimh.com', 'lzipic.com'];
    if (!need.any((d) => url.contains(d))) return url;
    try {
      return '${dio.options.baseUrl}/api/softlib/proxy/img?url=${Uri.encodeComponent(url)}';
    } catch (_) {
      return url;
    }
  }

  /// ★ 1015：通用接口代理 —— 后台配好地址就能出工具
  /// （走服务端中转，避免第三方 UA/CORS 拦截；服务端带 5 分钟缓存）
  Future<Map<String, dynamic>> toolboxProxy(String url, {bool fresh = false}) async {
    final r = await dio.get(
      '/api/softlib/toolbox/proxy',
      queryParameters: {'url': url, if (fresh) 'fresh': 1},
      options: Options(receiveTimeout: const Duration(seconds: 25)),
    );
    if (r.data is Map && r.data['code'] == 1) {
      return Map<String, dynamic>.from(r.data as Map);
    }
    throw Exception((r.data is Map ? r.data['msg'] : null)?.toString() ?? '接口请求失败');
  }

  /// 工具搜索
  Future<List<Map<String, dynamic>>> jzsSearch(String kw) async {
    try {
      final r = await dio.get(
        '/api/softlib/jzs/search',
        queryParameters: {'kw': kw},
      );
      if (r.data is Map && r.data['code'] == 1) {
        final list = (r.data['data']?['list'] as List?) ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[Softlib] jzs search: $e');
    }
    return [];
  }

  /// 收藏 / 取消收藏（需登录）→ 返回收藏后的状态
  Future<bool> jzsToggleFav(int toolId) async {
    final r = await dio.post(
      '/api/softlib/jzs/fav',
      data: {'tool_id': toolId, 'token': UserService.instance.token},
    );
    if (r.data is Map && r.data['code'] == 1) {
      return r.data['data']?['fav'] == true;
    }
    throw Exception(
      r.data is Map ? (r.data['msg'] ?? '操作失败') : '操作失败',
    );
  }

  /// 我的收藏
  Future<List<Map<String, dynamic>>> jzsFavList() async {
    try {
      final r = await dio.get(
        '/api/softlib/jzs/fav_list',
        queryParameters: {'token': UserService.instance.token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        final list = (r.data['data']?['list'] as List?) ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[Softlib] jzs fav: $e');
    }
    return [];
  }

  /// 记录使用历史（失败静默）
  Future<void> jzsAddHistory(int toolId) async {
    if (toolId <= 0) return;
    try {
      await dio.post(
        '/api/softlib/jzs/history',
        data: {'tool_id': toolId, 'token': UserService.instance.token},
      );
    } catch (_) {}
  }

  /// 使用历史
  Future<List<Map<String, dynamic>>> jzsHistory() async {
    try {
      final r = await dio.get(
        '/api/softlib/jzs/history_list',
        queryParameters: {'token': UserService.instance.token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        final list = (r.data['data']?['list'] as List?) ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[Softlib] jzs history: $e');
    }
    return [];
  }

  // ─────────── 工具箱 v2 数据代理（30 个工具的真实数据源） ───────────

  /// 通用 GET：/api/softlib/toolbox2/{action}
  Future<Map<String, dynamic>?> toolbox2(
    String action, {
    Map<String, dynamic>? query,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final r = await dio.get(
        '/api/softlib/toolbox2/$action',
        queryParameters: query,
        options: Options(receiveTimeout: timeout),
      );
      if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
        return Map<String, dynamic>.from(r.data['data'] as Map);
      }
      return null;
    } catch (e) {
      debugPrint('[Softlib] toolbox2/$action: $e');
      return null;
    }
  }

  /// 通用 GET：/api/softlib/media/{action}
  Future<Map<String, dynamic>?> media(
    String action, {
    Map<String, dynamic>? query,
    Duration timeout = const Duration(seconds: 40),
  }) async {
    try {
      final r = await dio.get(
        '/api/softlib/media/$action',
        queryParameters: query,
        options: Options(receiveTimeout: timeout),
      );
      if (r.data is Map && r.data['code'] == 1) {
        final d = r.data['data'];
        if (d is Map) return Map<String, dynamic>.from(d);
        // ★ 1015 修复：data 是数组时（music_search / comic_tags 等）也要能解包。
        //   原来只接受 Map，数组直接返回 null → 列表永远为空 → 用户看到「没数据」。
        if (d is List) return {'list': d};
      }
      return null;
    } catch (e) {
      debugPrint('[Softlib] media/$action: $e');
      return null;
    }
  }

  /// 通用 GET：/api/softlib/toolbox/{action}
  Future<Map<String, dynamic>?> toolbox1(
    String action, {
    Map<String, dynamic>? query,
    Duration timeout = const Duration(seconds: 40),
  }) async {
    try {
      final r = await dio.get(
        '/api/softlib/toolbox/$action',
        queryParameters: query,
        options: Options(receiveTimeout: timeout),
      );
      if (r.data is Map && r.data['code'] == 1) {
        final d = r.data['data'];
        if (d is Map) return Map<String, dynamic>.from(d);
        if (d is List) return {'list': d};
      }
      return null;
    } catch (e) {
      debugPrint('[Softlib] toolbox/$action: $e');
      return null;
    }
  }
}

/// 对「连接超时 / 连接错误 / 5xx」自动重试一次（第二次仍失败才抛错），
/// 显著降低弱网下的加载失败率。
class _RetryInterceptor extends Interceptor {
  static const _maxRetry = 1;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final opt = err.requestOptions;
    final tried = (opt.extra['_retry'] as int?) ?? 0;
    final retriable =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response != null && (err.response!.statusCode ?? 0) >= 500);

    if (retriable && tried < _maxRetry) {
      opt.extra['_retry'] = tried + 1;
      await Future.delayed(Duration(milliseconds: 400 * (tried + 1)));
      try {
        final resp =
            await Dio(
              BaseOptions(
                baseUrl: opt.baseUrl,
                connectTimeout: opt.connectTimeout,
                receiveTimeout: opt.receiveTimeout,
                headers: opt.headers,
                persistentConnection: true,
              ),
            ).request<dynamic>(
              opt.path,
              data: opt.data,
              queryParameters: opt.queryParameters,
              options: Options(method: opt.method),
            );
        return handler.resolve(resp);
      } catch (_) {
        // 重试仍失败 → 走原始错误
      }
    }
    handler.next(err);
  }
}
