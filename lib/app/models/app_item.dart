import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 软件数据模型（对接 /api/softlib/app/index）
///
/// 双来源设计：
/// - provider == 'lzy'   蓝奏云：客户端用 url 调 lzy_file_parse 解析后再下载
/// - provider == 'local' 服务器：客户端直接用 file 直链下载，无需解析
class AppItem {
  final int id;
  final String title;

  /// 'lzy' | 'local'
  final String provider;

  /// 蓝奏云分享地址（provider=lzy）
  final String url;

  /// 服务器直链（provider=local）
  final String file;

  final String icon;
  final String size;
  final String version;
  final String description;
  final int catId;
  final int weigh;
  final int views;

  /// 真实下载量（服务端 down_count，1013d）
  final int downCount;
  final String uploadDate;
  final String ageRating;
  final List<String> screenshots;
  final double scoreAvg;
  final int scoreCount;

  /// 后台「会员专享」开关
  final bool isVipOnly;
  final String vipPrice;

  /// 是否新上传（7天内）
  final bool isNew;

  /// 是否来自蓝奏云文件夹（无数据库记录）
  final bool fromFolder;

  /// 是否置顶（后台 is_top，1014）
  final bool isTop;

  /// 内容类型：apk=安装包 / browser=跳浏览器打开 url / webview=内置打开 url
  final String urlType;

  /// 后台备注（仅后台展示）
  final String adminNote;

  AppItem({
    required this.id,
    required this.title,
    required this.provider,
    required this.url,
    required this.file,
    required this.icon,
    required this.size,
    required this.version,
    required this.description,
    required this.catId,
    required this.weigh,
    this.views = 0,
    this.downCount = 0,
    this.uploadDate = '',
    this.ageRating = '16+',
    this.screenshots = const [],
    this.scoreAvg = 0,
    this.scoreCount = 0,
    this.isVipOnly = false,
    this.vipPrice = '',
    this.isNew = false,
    this.fromFolder = false,
    this.isTop = false,
    this.urlType = 'apk',
    this.adminNote = '',
  });

  bool get isLocal => provider == 'local';

  /// 是否为会员专享资源（后台开关优先，兼容旧的"会员专区"分类）
  bool get isVipItem => isVipOnly || catId == 5;

  /// 是否设置了有效价格（>0）—— 用于判断是否必须走付费校验
  bool get hasPrice {
    final v = double.tryParse(vipPrice.trim());
    return v != null && v > 0;
  }

  /// 是否属于「需要校验才能下载」的资源（会员专享 或 有价格）
  bool get needUnlock => isVipItem || hasPrice;

  /// 是否为网页/文章类内容（不下载 apk）
  bool get isLinkType => urlType == 'browser' || urlType == 'webview';

  /// 跳转目标 url（browser/webview 类型）
  String get linkUrl {
    final u = url.trim();
    if (u.isNotEmpty) return u;
    return file.trim();
  }

  /// 下载是否可直接进行（无需解析）
  bool get canDirectDownload => isLocal && file.isNotEmpty;

  factory AppItem.fromJson(Map<String, dynamic> json) {
    String s(String k) => (json[k] ?? '').toString();
    int i(String k) => int.tryParse((json[k] ?? '0').toString()) ?? 0;
    return AppItem(
      id: i('id'),
      title: s('title'),
      provider: s('provider').isEmpty ? 'lzy' : s('provider'),
      url: s('url'),
      file: s('file'),
      icon: s('icon'),
      size: s('size'),
      version: s('version'),
      description: s('description'),
      catId: i('cat_id'),
      weigh: i('weigh'),
      views: i('views'),
      downCount: i('down_count'),
      uploadDate: s('upload_date'),
      ageRating: s('age_rating').isEmpty ? '16+' : s('age_rating'),
      screenshots: s('screenshots')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      scoreAvg: double.tryParse('${json['score_avg'] ?? 0}') ?? 0,
      scoreCount: i('score_count'),
      isVipOnly: json['is_vip'] == 1 || json['is_vip'] == true,
      vipPrice: s('vip_price'),
      isNew: json['is_new'] == 1 || json['is_new'] == true,
      fromFolder: json['from_folder'] == 1 || json['from_folder'] == true,
      isTop: json['is_top'] == 1 || json['is_top'] == true,
      urlType: s('url_type').isEmpty ? 'apk' : s('url_type'),
      adminNote: s('admin_note'),
    );
  }

  static List<AppItem> listFrom(dynamic data) {
    if (data is List) {
      final list = data
          .whereType<Map>()
          .map((e) => AppItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return sortByTop(list);
    }
    return [];
  }

  /// ★ 1014 需求2：置顶优先排序（稳定排序，保持原有相对顺序）
  ///    服务端已按 is_top DESC, weigh DESC, id DESC 排好；
  ///    这里再兜底一次，防止蓝奏云文件夹分类等客户端本地解析的来源漏排。
  static List<AppItem> sortByTop(List<AppItem> list) {
    if (list.length < 2) return list;
    final tops = <AppItem>[];
    final rest = <AppItem>[];
    for (final a in list) {
      (a.isTop ? tops : rest).add(a);
    }
    if (tops.isEmpty) return list;
    return [...tops, ...rest];
  }

  static List<AppItem> listFromRaw(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is Map && j['data'] != null) return listFrom(j['data']);
    } catch (e) {
      debugPrint('[Softlib] $e');
    }
    return [];
  }
}
