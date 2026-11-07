import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_host.dart';

/// ★ 1107g 主题令牌（服务端下发，免发版调 UI）
///
/// 服务端：GET /api/softlib/theme/tokens
/// 文件：/www/wwwroot/flrjk.52yfx.cn/data/theme_tokens.json
/// 用法：main() 里 await Tokens.load(); 然后 Tokens.titleSize 等直接读。
class Tokens {
  Tokens._();

  // ── 圈子（默认值 = 当前设计） ──
  static double pagePad = 12;
  static double cardRadius = 18;
  static double titleSize = 16;
  static double bodySize = 13.5;
  static double metaSize = 11.5;
  static double rowPadV = 15;
  static double headerSize = 27;
  static double boardTile = 44;
  static double cardShadow = 22;

  // ── 全局 ──
  static double radiusSm = 8;
  static double radiusMd = 12;
  static double radiusLg = 18;

  static bool get loaded => _loaded;
  static bool _loaded = false;

  static Future<void> load() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiHost.base,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final r = await dio.get('/api/softlib/theme/tokens');
      final d = r.data;
      if (d is Map && d['code'] == 1 && d['data'] is Map) {
        _apply(Map<String, dynamic>.from(d['data'] as Map));
        _loaded = true;
      }
    } catch (e) {
      debugPrint('[Softlib] tokens: $e');
    }
  }

  static void _apply(Map<String, dynamic> j) {
    double n(dynamic v, double def) {
      if (v == null) return def;
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? def;
    }

    final c = j['circle'];
    if (c is Map) {
      pagePad = n(c['pagePad'], pagePad);
      cardRadius = n(c['cardRadius'], cardRadius);
      titleSize = n(c['titleSize'], titleSize);
      bodySize = n(c['bodySize'], bodySize);
      metaSize = n(c['metaSize'], metaSize);
      rowPadV = n(c['rowPadV'], rowPadV);
      headerSize = n(c['headerSize'], headerSize);
      boardTile = n(c['boardTile'], boardTile);
      cardShadow = n(c['cardShadow'], cardShadow);
    }
    final g = j['global'];
    if (g is Map) {
      radiusSm = n(g['radiusSm'], radiusSm);
      radiusMd = n(g['radiusMd'], radiusMd);
      radiusLg = n(g['radiusLg'], radiusLg);
    }
  }

  static String dump() => jsonEncode({
        'pagePad': pagePad,
        'cardRadius': cardRadius,
        'titleSize': titleSize,
        'bodySize': bodySize,
      });
}
