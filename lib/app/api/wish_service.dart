import 'package:dio/dio.dart';
import 'api_http.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'api_host.dart';

/// 需求投票服务（求软件）
///
/// ★ 1020（待办 #2）：用户在搜索页找不到想要的软件时，
///   可以提交需求并互相点赞；后台按票数决定采集什么。
class WishService extends GetxService {
  static WishService get instance => Get.find<WishService>();

  static const String baseUrl = ApiHost.base;

  final Dio _dio = ApiHttp.create(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  /// 列表：sort = votes | new
  Future<Map<String, dynamic>> list({
    String sort = 'votes',
    int page = 1,
    int size = 20,
    String kw = '',
  }) async {
    try {
      final r = await _dio.get(
        '/api/softlib/wishlist',
        queryParameters: {
          'sort': sort,
          'page': page,
          'size': size,
          if (kw.isNotEmpty) 'kw': kw,
        },
      );
      if (r.data is Map && r.data['code'] == 1) {
        return Map<String, dynamic>.from(r.data['data'] ?? {});
      }
    } catch (e) {
      debugPrint('[Wish] list: $e');
    }
    return {};
  }

  /// 提交需求
  Future<Map<String, dynamic>> add({
    required String title,
    String content = '',
    String catName = '',
    String token = '',
  }) async {
    final r = await _dio.post(
      '/api/softlib/wishadd',
      data: {
        'title': title,
        'content': content,
        'cat_name': catName,
        'token': token,
      },
    );
    if (r.data is! Map) throw Exception('提交失败：返回格式异常');
    final d = Map<String, dynamic>.from(r.data as Map);
    if (d['code'] != 1) throw Exception('${d['msg'] ?? '提交失败'}');
    return Map<String, dynamic>.from((d['data'] as Map?) ?? {});
  }

  /// 点赞 / 取消
  Future<Map<String, dynamic>> vote(int id, {String token = ''}) async {
    final r = await _dio.post(
      '/api/softlib/wishvote',
      data: {'id': id, 'token': token},
    );
    if (r.data is! Map) throw Exception('投票失败');
    final d = Map<String, dynamic>.from(r.data as Map);
    if (d['code'] != 1) throw Exception('${d['msg'] ?? '投票失败'}');
    return Map<String, dynamic>.from((d['data'] as Map?) ?? {});
  }

  /// 我提交的
  Future<List<Map<String, dynamic>>> mine({String token = ''}) async {
    try {
      final r = await _dio.post(
        '/api/softlib/wishmine',
        data: {'token': token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        final list = (r.data['data']?['list'] as List?) ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[Wish] mine: $e');
    }
    return [];
  }
}
