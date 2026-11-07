import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/device_info_util.dart';
import 'api_host.dart';
import 'api_http.dart';
import 'user_service.dart';

/// ★ 1107a 圈子（Forum）服务 —— 复刻 ARC 的板块 / 帖子 / 评论体系
class ForumService {
  ForumService._();
  static final ForumService instance = ForumService._();

  final Dio _dio = ApiHttp.create(
    BaseOptions(
      headers: DeviceInfo.headers,
      baseUrl: ApiHost.base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  Map<String, dynamic> get _auth => {
        if (UserService.instance.token.isNotEmpty)
          'token': UserService.instance.token,
      };

  Future<List<Map<String, dynamic>>> sections() async {
    try {
      final r = await _dio.get('/api/softlib/forum/section_list');
      final d = r.data;
      if (d is Map && d['code'] == 1 && d['data'] is List) {
        return (d['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[Forum] sections: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> posts({
    int section = 0,
    String order = 'created',
    int page = 1,
    int limit = 15,
    String kw = '',
  }) async {
    try {
      final r = await _dio.get('/api/softlib/forum/post_list', queryParameters: {
        'section': section,
        'order': order,
        'page': page,
        'limit': limit,
        if (kw.isNotEmpty) 'kw': kw,
      });
      final d = r.data;
      if (d is Map && d['code'] == 1 && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data']);
      }
    } catch (e) {
      debugPrint('[Forum] posts: $e');
    }
    return {'list': [], 'has_more': false};
  }

  Future<Map<String, dynamic>?> postInfo(int id) async {
    try {
      final r = await _dio.get('/api/softlib/forum/post_info',
          queryParameters: {'id': id, ..._auth});
      final d = r.data;
      if (d is Map && d['code'] == 1 && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data']);
      }
    } catch (e) {
      debugPrint('[Forum] info: $e');
    }
    return null;
  }

  Future<int> publish({
    required String title,
    required int section,
    required String text,
    List<String> images = const [],
  }) async {
    final r = await _dio.post('/api/softlib/forum/publish', data: {
      'title': title,
      'section': section,
      'text': text,
      'images': images,
      ..._auth,
    });
    final d = r.data;
    if (d is Map && d['code'] == 1) {
      return int.tryParse('${(d['data'] ?? {})['id'] ?? 0}') ?? 0;
    }
    throw Exception('${(d is Map ? d['msg'] : '发布失败')}');
  }

  Future<List<Map<String, dynamic>>> comments(int postId, {int page = 1}) async {
    try {
      final r = await _dio.get('/api/softlib/forum/comment_list', queryParameters: {
        'postid': postId,
        'page': page,
        'limit': 50,
      });
      final d = r.data;
      if (d is Map && d['code'] == 1 && (d['data'] is Map)) {
        final list = (d['data'] as Map)['list'];
        if (list is List) {
          return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[Forum] comments: $e');
    }
    return [];
  }

  Future<void> addComment(int postId, String text, {int parent = 0}) async {
    final r = await _dio.post('/api/softlib/forum/comment', data: {
      'postid': postId,
      'text': text,
      'parent': parent,
      ..._auth,
    });
    final d = r.data;
    if (!(d is Map && d['code'] == 1)) {
      throw Exception('${(d is Map ? d['msg'] : '评论失败')}');
    }
  }

  Future<Map<String, dynamic>> toggleLike(int id) async {
    final r = await _dio.post('/api/softlib/forum/like', data: {'id': id, ..._auth});
    final d = r.data;
    if (d is Map && d['code'] == 1 && d['data'] is Map) {
      return Map<String, dynamic>.from(d['data']);
    }
    throw Exception('操作失败');
  }

  Future<Map<String, dynamic>> toggleMark(int id) async {
    final r = await _dio.post('/api/softlib/forum/mark', data: {'id': id, ..._auth});
    final d = r.data;
    if (d is Map && d['code'] == 1 && d['data'] is Map) {
      return Map<String, dynamic>.from(d['data']);
    }
    throw Exception('操作失败');
  }

  Future<List<Map<String, dynamic>>> myPosts({int page = 1}) async {
    try {
      final r = await _dio.get('/api/softlib/forum/my_posts',
          queryParameters: {'page': page, ..._auth});
      final d = r.data;
      if (d is Map && d['code'] == 1 && d['data'] is Map) {
        final list = (d['data'] as Map)['list'];
        if (list is List) {
          return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[Forum] my: $e');
    }
    return [];
  }

  /// 我的收藏
  Future<List<Map<String, dynamic>>> myMarks({int page = 1}) async {
    try {
      final r = await _dio.get('/api/softlib/forum/my_marks',
          queryParameters: {'page': page, ..._auth});
      final d = r.data;
      if (d is Map && d['code'] == 1 && d['data'] is Map) {
        final list = (d['data'] as Map)['list'];
        if (list is List) {
          return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[Forum] marks: $e');
    }
    return [];
  }

  // ───────── 后台 ─────────
  Future<List<Map<String, dynamic>>> adminSections() async {
    final r = await _dio.get('/api/softlib/forum/admin_sections', queryParameters: _auth);
    final d = r.data;
    if (d is Map && d['code'] == 1 && d['data'] is List) {
      return (d['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> adminSectionSave(Map<String, dynamic> data) async {
    final r = await _dio.post('/api/softlib/forum/admin_section_save',
        data: {...data, ..._auth});
    final d = r.data;
    if (!(d is Map && d['code'] == 1)) throw Exception('${(d is Map ? d['msg'] : '保存失败')}');
  }

  Future<void> adminSectionDel(int id) async {
    final r = await _dio.post('/api/softlib/forum/admin_section_del', data: {'id': id, ..._auth});
    final d = r.data;
    if (!(d is Map && d['code'] == 1)) throw Exception('${(d is Map ? d['msg'] : '删除失败')}');
  }

  Future<List<Map<String, dynamic>>> adminPosts({int page = 1, String kw = ''}) async {
    final r = await _dio.get('/api/softlib/forum/admin_posts',
        queryParameters: {'page': page, if (kw.isNotEmpty) 'kw': kw, ..._auth});
    final d = r.data;
    if (d is Map && d['code'] == 1 && d['data'] is Map) {
      final list = (d['data'] as Map)['list'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  Future<void> adminPostSet(int id, String field, int value) async {
    final r = await _dio.post('/api/softlib/forum/admin_post_set',
        data: {'id': id, 'field': field, 'value': value, ..._auth});
    final d = r.data;
    if (!(d is Map && d['code'] == 1)) throw Exception('${(d is Map ? d['msg'] : '操作失败')}');
  }

  Future<void> adminPostDel(int id) async {
    final r = await _dio.post('/api/softlib/forum/admin_post_del', data: {'id': id, ..._auth});
    final d = r.data;
    if (!(d is Map && d['code'] == 1)) throw Exception('${(d is Map ? d['msg'] : '删除失败')}');
  }

  Future<void> adminCommentDel(int id) async {
    final r = await _dio.post('/api/softlib/forum/admin_comment_del', data: {'id': id, ..._auth});
    final d = r.data;
    if (!(d is Map && d['code'] == 1)) throw Exception('${(d is Map ? d['msg'] : '删除失败')}');
  }
}
