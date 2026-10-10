////////////////////////////////////////////////////////////////////////////////
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植，
// 宿主化改写：上游 api_host.dart 是「自建域名池 + 优选 IP」，依赖编译期私有
// secrets.dart（不入库）。宿主版改为由后台「解析配置」下发（JicunSettings），
// 域名/接口在管理后台热更，不需要重新发版。
// 版权与许可遵循上游 MIT License，见仓库 LICENSE。
////////////////////////////////////////////////////////////////////////////////
/// 上游 api_host.dart 的宿主化垫片:只保留 upstream_mapping.dart 用到的两个函数。
///
/// 「当前域名」由 [JicunSettings](后台 jicun.api_host / api_backup 下发)决定。
library;

import 'jicun_config.dart';

/// 把路径拼成解析服务的绝对地址。
String apiUrl(String path) {
  final host = JicunSettings.instance.apiHost.trim();
  final base = host.isEmpty ? kJicunDefaultApiHost : host;
  return base.endsWith('/')
      ? '${base.substring(0, base.length - 1)}$path'
      : '$base$path';
}

/// 把应答里的相对地址补成绝对地址(jicun_upstream_mapping.dart 调用)。
String? jicunAbsoluteMediaUrl(String? url) {
  if (url == null || url.isEmpty || !url.startsWith('/')) return url;
  return apiUrl(url);
}

/// 上游默认解析接口(上游 media-parser 的公开形状;真正的服务端地址由后台配置)。
const String kJicunDefaultApiHost = 'https://media-parser.example.com';
