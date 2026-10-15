import 'package:flutter/foundation.dart';

import 'soft_service.dart';
import 'user_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// 工具箱服务（v3.3.4）
///
/// 设计：**不另开 Dio**，全部复用 [SoftService.dio] —— 连接复用 + 统一重试策略。
///
/// 数据来源：
///   · jzs/*      —— 工具目录（分类+条目，后台可增删改）
///   · toolbox/*  —— 真实数据代理（热榜/天气/诗句/单位换算/王者图集/漫画…）
///   · media/*    —— 影视/音乐/短剧/新闻/地震
///
/// 为什么联网工具走后端代理而不是客户端直连第三方：
///   第三方聚合站（60s-api / vvhan / tenapi）限流与失效非常频繁，
///   客户端直连必然出现空列表。服务端直采官方站点 + 缓存，一次抓取全体共享。
/// ═══════════════════════════════════════════════════════════════
class ToolboxService {
  ToolboxService._();
  static final ToolboxService instance = ToolboxService._();

  SoftService get _ss => SoftService.instance;

  /// 兼容旧调用点（历史上由 main.dart 注入 baseUrl；现在直接用 SoftService）
  static void configure(String base) {
    // no-op：baseUrl 已由 ApiHost / SoftService 统一管理
  }

  // ═══════════ 工具目录（jzs） ═══════════

  /// 工具目录：{groups:[{id,title,hint,tools:[...]}], default_style, banners, total}
  Future<Map<String, dynamic>?> fetchConfig({bool force = false}) =>
      _ss.toolboxConfig(force: force);

  /// 本地缓存的工具目录（未拉取过返回 null）
  Map<String, dynamic>? get cachedConfig => SoftService.toolboxCache;

  /// 工具搜索
  Future<List<Map<String, dynamic>>> search(String kw) =>
      _ss.jzsSearch(kw);

  /// 收藏 / 取消收藏（需登录），返回收藏后的状态
  Future<bool> toggleFav(int toolId) => _ss.jzsToggleFav(toolId);

  /// 我的收藏
  Future<List<Map<String, dynamic>>> favList() => _ss.jzsFavList();

  /// 记录使用历史（失败静默）
  Future<void> addHistory(int toolId) => _ss.jzsAddHistory(toolId);

  /// 使用历史
  Future<List<Map<String, dynamic>>> history() => _ss.jzsHistory();

  // ═══════════ 真实数据代理（toolbox/*） ═══════════

  /// 热榜：type = baidu | bili；board 仅 baidu 用
  /// 返回 {type, board, label, list:[{rank,title,hot,url,desc,cover}]}
  Future<Map<String, dynamic>?> hot({
    String type = 'baidu',
    String board = 'realtime',
  }) => _ss.toolbox1('hot', query: {'type': type, 'board': board});

  /// 百度榜单目录：[{board,label}]
  Future<List<Map<String, dynamic>>> hotBoards() async {
    final r = await _ss.toolbox1('hot_boards');
    return _asList(r?['list'] ?? r?['data']);
  }

  /// 天气：{city,temp,feels,desc,humidity,wind,days}
  Future<Map<String, dynamic>?> weather(String city) =>
      _ss.toolbox1('weather', query: {'q': city});

  /// 每日诗句
  Future<Map<String, dynamic>?> poem() => _ss.toolbox1('poem');

  /// 每日一言
  Future<Map<String, dynamic>?> hitokoto() => _ss.toolbox1('hitokoto');

  /// 单位换算系数表
  Future<Map<String, dynamic>?> unitTable() => _ss.toolbox1('unit_table');

  /// 翻译（后端代理 MyMemory + 缓存）
  /// pair 形如 'zh-CN|en'
  Future<Map<String, dynamic>?> translate(
    String q, {
    String pair = 'zh-CN|en',
  }) => _ss.toolbox1('translate', query: {'q': q, 'pair': pair});

  /// 汇率（后端代理 open.er-api + 缓存）
  Future<Map<String, dynamic>?> exchange([String base = 'CNY']) =>
      _ss.toolbox1('exchange', query: {'base': base});

  /// IP 查询（后端代理 ip-api + 缓存）；ip 留空会失败（服务端出口无意义）
  Future<Map<String, dynamic>?> ipQuery(String ip) =>
      _ss.toolbox1('ipquery', query: {'ip': ip});

  /// 每日 60 秒图文日报 {date,lunar,news:[],tip,image}
  Future<Map<String, dynamic>?> daily60() => _ss.toolbox1('daily60');

  /// Epic 喜加一（限免游戏列表）
  Future<List<Map<String, dynamic>>> epic() async {
    final r = await _ss.toolbox1('epic');
    return _asList(r?['list'] ?? r?['data']);
  }

  /// 王者荣耀英雄图集
  Future<List<Map<String, dynamic>>> heroes() async {
    final r = await _ss.toolbox1('heroes');
    return _asList(r?['list'] ?? r?['data']);
  }

  /// 漫画分类
  Future<List<Map<String, dynamic>>> comicTags() async {
    final r = await _ss.toolbox1('comic_tags');
    return _asList(r?['list'] ?? r?['data']);
  }

  /// 漫画列表
  Future<List<Map<String, dynamic>>> comicList({
    String tag = '',
    int page = 1,
  }) async {
    final r = await _ss.toolbox1(
      'comic_list',
      query: {'tag': tag, 'page': page},
    );
    return _asList(r?['list'] ?? r?['data']);
  }

  /// 漫画章节
  Future<List<Map<String, dynamic>>> comicChapters(String id) async {
    final r = await _ss.toolbox1('comic_chapters', query: {'id': id});
    return _asList(r?['list'] ?? r?['data']);
  }

  /// 漫画图片（纯字符串列表）
  Future<List<String>> comicImages(String id, String chapter) async {
    final r = await _ss.toolbox1(
      'comic_images',
      query: {'id': id, 'chapter': chapter},
    );
    final d = r?['list'] ?? r?['data'];
    if (d is List) return d.map((e) => '$e').toList();
    return const [];
  }

  // ═══════════ 影视 / 音乐 / 短剧 / 新闻 / 地震（media/*） ═══════════

  Future<Map<String, dynamic>?> movieHome() => _ss.media('movie_home');

  Future<List<Map<String, dynamic>>> movieSearch(
    String kw, {
    int page = 1,
  }) async {
    final r = await _ss.media(
      'movie_search',
      query: {'q': kw, 'page': page},
    );
    return _asList(r?['list'] ?? r?['data']);
  }

  /// ★ 1015：传 name → 服务端跨源聚合，返回 play_groups（多源换源用）
  Future<Map<String, dynamic>?> movieDetail(
    String src,
    String id, {
    String name = '',
    bool all = false,
  }) =>
      _ss.media('movie_detail', query: {
        'src': src,
        'id': id,
        if (name.isNotEmpty) 'name': name,
        if (all) 'all': 1,
      });

  Future<Map<String, dynamic>?> musicHome() => _ss.media('music_home');

  Future<List<Map<String, dynamic>>> musicSearch(String kw) async {
    final r = await _ss.media('music_search', query: {'q': kw});
    return _asList(r?['list'] ?? r?['data']);
  }

  Future<Map<String, dynamic>?> musicUrl(String src, String id) =>
      _ss.media('music_url', query: {'src': src, 'id': id});

  Future<Map<String, dynamic>?> dramaList({int page = 1}) =>
      _ss.media('drama_list', query: {'page': page});

  Future<Map<String, dynamic>?> dramaChannels({String id = ''}) =>
      _ss.media('drama_channels', query: {'id': id});

  Future<List<Map<String, dynamic>>> newsList() async {
    final r = await _ss.media('news_list');
    return _asList(r?['list'] ?? r?['data']);
  }

  Future<List<Map<String, dynamic>>> earthquake() async {
    final r = await _ss.media('earthquake');
    return _asList(r?['list'] ?? r?['data']);
  }

  // ═══════════ 本地工具（纯 Dart，不联网） ═══════════

  /// 随机壁纸直链（第三方直给图片，无需代理）
  String randomWallpaper({String type = 'dongman'}) =>
      'http://api.btstu.cn/sjbz/api.php?lx=$type&format=images';

  // ═══════════ 内部 ═══════════

  List<Map<String, dynamic>> _asList(dynamic d) {
    if (d is List) {
      try {
        return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        debugPrint('[Toolbox] list cast: $e');
      }
    }
    return const [];
  }

  /// 当前登录 token（上传/收藏等写接口需要）
  String get token => UserService.instance.token;
}
