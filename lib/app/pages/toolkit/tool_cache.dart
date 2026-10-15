import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 工具箱 · 本地缓存（1015 新增，解决「数据加载太慢」）
///
/// 思路：**先显示缓存，再后台刷新**（stale-while-revalidate）
///   · 打开工具页 → 立刻用上次缓存渲染（0 延迟）
///   · 同时后台请求新数据 → 回来后无感替换
///   · 断网时也能看到上次内容
class ToolCache {
  ToolCache._();

  static const _kPrefix = 'tool_cache_';

  /// 读缓存（同步语义：先返回缓存让 UI 秒开）
  static Future<Map<String, dynamic>?> read(String key) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('$_kPrefix$key');
      if (raw == null || raw.isEmpty) return null;
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      // 过期检查：超过 24 小时当没有
      final at = (m['_at'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - at > 24 * 3600 * 1000) return null;
      return Map<String, dynamic>.from(m);
    } catch (_) {
      return null;
    }
  }

  /// 写缓存
  static Future<void> write(String key, Map<String, dynamic> data) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final m = Map<String, dynamic>.from(data);
      m['_at'] = DateTime.now().millisecondsSinceEpoch;
      await sp.setString('$_kPrefix$key', jsonEncode(m));
    } catch (_) {}
  }

  /// 清缓存
  static Future<void> clear() async {
    try {
      final sp = await SharedPreferences.getInstance();
      for (final k in sp.getKeys()) {
        if (k.startsWith(_kPrefix)) await sp.remove(k);
      }
    } catch (_) {}
  }
}
