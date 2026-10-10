////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 后台配置消费中心
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植改造。
// 后台 ui_config.jicun 节点（管理后台「解析配置」Tab 编辑）全量下发到这里,
// 客户端真实消费每一个字段 —— 不是摆设:
//   enable / tab_name      → navigate_logic.dart(第 5 个 Tab 的显隐与名字)
//   api_host / api_backup  → jicun_parse_service.dart(主/备解析接口)
//   api_headers            → jicun_parse_service.dart(自定义请求头)
//   upstream_override      → jicun_parse_service.dart(平台级覆盖/关闭)
//   platform_enable        → jicun_parse_service.dart(各平台开关)
//   max_concurrent         → jicun_downloader.dart(并发文件数)
//   timeout / retry        → jicun_parse_service.dart + jicun_downloader.dart
//   min_split_size         → jicun_downloader.dart(分段阈值 segmentedFromBytes)
//   save_dir_name          → jicun_downloader.dart(应用下载目录名)
//   history_limit          → jicun_history_store.dart(历史条数)
//   clear_on_exit          → jicun_page.dart(退出页面清历史)
//   quality_default        → jicun_page.dart(清晰度策略 highest/ask)
//   auto_paste             → jicun_page.dart(自动读剪贴板)
//   notice                 → jicun_page.dart(公告文案)
////////////////////////////////////////////////////////////////////////////////
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../api/soft_service.dart';

/// 「解析配置」的一个快照(不可变,来自后台 ui_config.jicun 节点)。
class JicunConfig {
  const JicunConfig({
    this.enable = true,
    this.tabName = '即存',
    this.apiHost = '',
    this.apiBackup = '',
    this.apiHeaders = '',
    this.upstreamOverride = '',
    this.platformEnable = '',
    this.maxConcurrent = 4,
    this.timeout = 20,
    this.retry = 3,
    this.minSplitSize = 8,
    this.saveDirName = 'JicunDownload',
    this.historyLimit = 200,
    this.clearOnExit = false,
    this.qualityDefault = 'highest',
    this.autoPaste = true,
    this.notice = '',
  });

  /// 功能开关(false = 隐藏第 5 个 Tab)。
  final bool enable;

  /// Tab 显示名,默认「即存」。
  final String tabName;

  /// 自定义解析接口(空 = 上游默认)。
  final String apiHost;

  /// 备用接口(主接口失败时用)。
  final String apiBackup;

  /// 自定义请求头 JSON({"Key":"Value"})。
  final String apiHeaders;

  /// 平台级覆盖 JSON({"抖音":{"api":"https://..","enable":true}})。
  final String upstreamOverride;

  /// 各平台开关 JSON({"抖音":true,"快手":false})。
  final String platformEnable;

  /// 并发文件数。
  final int maxConcurrent;

  /// 解析/单段超时(秒)。
  final int timeout;

  /// 段重试次数。
  final int retry;

  /// 分段阈值(MB,小于此不分段)。
  final int minSplitSize;

  /// 应用内下载目录名。
  final String saveDirName;

  /// 历史条数上限。
  final int historyLimit;

  /// 退出页面是否清历史。
  final bool clearOnExit;

  /// 默认清晰度策略:highest(直接取最高) / ask(每次弹选择)。
  final String qualityDefault;

  /// 自动读剪贴板。
  final bool autoPaste;

  /// 公告文案(空 = 不显示)。
  final String notice;

  static bool _b(dynamic v, [bool def = true]) =>
      v == null ? def : (v == true || v == 1 || v == '1' || v == 'true');
  static String _s(dynamic v, String def) {
    final x = (v ?? '').toString();
    return x.isEmpty ? def : x;
  }

  static int _i(dynamic v, int def) {
    if (v is num) return v.toInt();
    final n = int.tryParse('${v ?? ''}'.trim());
    return n == null ? def : n;
  }

  factory JicunConfig.fromJson(Map json) => JicunConfig(
    enable: _b(json['enable'], true),
    tabName: _s(json['tab_name'], '即存'),
    apiHost: _s(json['api_host'], ''),
    apiBackup: _s(json['api_backup'], ''),
    apiHeaders: _s(json['api_headers'], ''),
    upstreamOverride: _s(json['upstream_override'], ''),
    platformEnable: _s(json['platform_enable'], ''),
    maxConcurrent: _i(json['max_concurrent'], 4),
    timeout: _i(json['timeout'], 20),
    retry: _i(json['retry'], 3),
    minSplitSize: _i(json['min_split_size'], 8),
    saveDirName: _s(json['save_dir_name'], 'JicunDownload'),
    historyLimit: _i(json['history_limit'], 200),
    clearOnExit: _b(json['clear_on_exit'], false),
    qualityDefault: _s(json['quality_default'], 'highest'),
    autoPaste: _b(json['auto_paste'], true),
    notice: _s(json['notice'], ''),
  );

  /// api_headers JSON → Map(解析失败给空)。
  Map<String, String> headersMap() =>
      _jsonMap(apiHeaders).map((k, v) => MapEntry(k, '$v'));

  /// upstream_override JSON → Map<String, Map>。
  Map<String, Map<String, dynamic>> overrideMap() => _jsonMap(upstreamOverride)
      .map(
        (k, v) => MapEntry(
          k,
          v is Map
              ? Map<String, dynamic>.from(v)
              : <String, dynamic>{'api': '$v'},
        ),
      );

  /// platform_enable JSON → Map<String, bool>。
  Map<String, bool> platformEnableMap() =>
      _jsonMap(platformEnable).map((k, v) => MapEntry(k, _b(v, true)));

  Map<String, dynamic> _jsonMap(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final d = jsonDecode(raw);
      return d is Map ? Map<String, dynamic>.from(d) : const {};
    } catch (e) {
      if (kDebugMode) debugPrint('[jicun] JSON 配置解析失败: $e');
      return const {};
    }
  }
}

/// 全局单例:最近一次成功的后台配置 + 可监听版本号。
class JicunSettings extends GetxController {
  JicunSettings._();
  static final JicunSettings instance = JicunSettings._();

  /// 默认配置(后台拉不到时的兜底)。
  JicunConfig _cfg = const JicunConfig();
  JicunConfig get cfg => _cfg;

  // —— 便捷只读入口(下载器等非 UI 代码直接用,避免到处 .cfg) ——
  String get apiHost => _cfg.apiHost;
  String get apiBackup => _cfg.apiBackup;
  int get historyLimit => _cfg.historyLimit;
  String get saveDirName =>
      _cfg.saveDirName.isEmpty ? 'JicunDownload' : _cfg.saveDirName;

  /// 配置版本号:每次刷新 +1,UI 可监听。
  final RxInt version = 0.obs;

  /// 从后台拉一次配置(SoftService 自带缓存与并发去重)。
  Future<JicunConfig> refresh({bool force = false}) async {
    try {
      final app = await SoftService.instance.fetchConfig(force: force);
      final j = app?.jicunConfig;
      if (j != null) {
        _cfg = j;
        version.value++;
        update(['jicun']);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[jicun] 配置拉取失败: $e');
    }
    return _cfg;
  }

  /// 同步取当前配置(未拉取过则给默认值)。
  static JicunSettings get I => instance;
}
