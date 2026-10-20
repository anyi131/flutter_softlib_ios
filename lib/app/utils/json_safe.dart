import 'dart:convert';

import 'package:flutter/foundation.dart';

/// JSON 安全取值
///
/// ★★ 1020：之前反复出现「空数组导致崩溃」——
///   PHP 的空数组会编码成 JSON 的 `[]`，而 Dart 端写的是 `as Map?`，
///   类型转换直接抛 `type 'List<dynamic>' is not a subtype of type 'Map?'`。
///
///   这类问题一旦发生就是整页「内容加载异常」，而且很难从堆栈定位。
///   这里提供一组「永不抛异常」的取值方法。
class J {
  J._();

  /// 安全取 Map（数组 / null / 字符串都返回空 Map）
  static Map<String, dynamic> map(dynamic v) {
    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((k, val) => out['$k'] = val);
      return out;
    }
    if (v is String && v.trim().startsWith('{')) {
      try {
        final d = jsonDecode(v);
        if (d is Map) return map(d);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  /// 安全取 List
  static List<dynamic> list(dynamic v) {
    if (v is List) return v;
    if (v is Map && v.containsKey('list')) return list(v['list']);
    return const [];
  }

  /// 安全取 List<Map>
  static List<Map<String, dynamic>> mapList(dynamic v) {
    final raw = list(v);
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      final m = map(e);
      if (m.isNotEmpty) out.add(m);
    }
    return out;
  }

  /// 安全取 int
  static int intOf(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? def;
  }

  /// 安全取 double
  static double doubleOf(dynamic v, [double def = 0]) {
    if (v == null) return def;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? def;
  }

  /// 安全取 String
  static String str(dynamic v, [String def = '']) {
    if (v == null) return def;
    if (v is String) return v;
    return '$v';
  }

  /// 安全取 bool
  static bool boolOf(dynamic v, [bool def = false]) {
    if (v == null) return def;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = '$v'.toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return def;
  }
}

/// 接口字段契约检查
///
/// 把「服务端返回的类型」和「App 期望的类型」比对，
/// 不符就往 crash_log 上报（tag=contract），在后台「错误日志」能看到，
/// 不用等崩溃了才发现。
void checkContract(
  String api,
  Map<String, dynamic> data,
  Map<String, String> expect, // 字段 → 期望类型 map/list/int/string/bool
) {
  final bad = <String>[];
  expect.forEach((k, t) {
    if (!data.containsKey(k)) return; // 缺字段视为可选
    final v = data[k];
    if (v == null) {
      bad.add('$k=null(期望$t)');
      return;
    }
    final ok = switch (t) {
      'map' => v is Map,
      'list' => v is List,
      'int' => v is num || int.tryParse('$v') != null,
      'string' => v is String,
      'bool' => v is bool || v is num,
      _ => true,
    };
    if (!ok) bad.add('$k=${v.runtimeType}(期望$t)');
  });
  if (bad.isNotEmpty) {
    final detail = bad.join(', ');
    debugPrint('[契约] $api 字段类型异常: $detail');
    contractReporter?.call(api, detail);
  }
}

/// 上报函数（在 main 里注入，避免循环依赖）
void Function(String api, String detail)? contractReporter;
