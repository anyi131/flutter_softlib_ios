import 'dart:io';
import 'api_http.dart';

import 'package:flutter/foundation.dart';

import 'api_host.dart';

import 'package:dio/dio.dart';

import '../utils/device_info_util.dart';
import '../models/post_item.dart';
import 'user_service.dart';

/// 广场社区服务
class PostService {
  PostService._();
  static final PostService instance = PostService._();

  static const String baseUrl = ApiHost.base;
  final Dio _dio = ApiHttp.create(
    BaseOptions(
      headers: DeviceInfo.headers,
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// 分类
  Future<List<PostCat>> fetchCats() async {
    try {
      final r = await _dio.get('/api/softlib/post/cats');
      if (r.data is Map && r.data['code'] == 1) {
        return PostCat.listFrom(r.data['data']);
      }
    } catch (e) {
      debugPrint('[Softlib] $e');
    }
    return [];
  }

  /// 动态列表
  ///
  /// ★ 加时间戳参数：绕过任何中间层(CDN/代理)的 HTTP 缓存，
  ///   避免「发了新动态刷新还是旧内容」（用户反馈 #3）
  Future<List<PostItem>> fetchPosts({int page = 1, int catId = 0}) async {
    final r = await _dio.get(
      '/api/softlib/post/index',
      queryParameters: {
        'pages': page,
        if (catId > 0) 'cat_id': catId,
        '_t': DateTime.now().millisecondsSinceEpoch,
      },
      options: Options(
        headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      ),
    );
    if (r.data is Map && r.data['code'] == 1) {
      return PostItem.listFrom(r.data['data']);
    }
    throw Exception('加载失败');
  }

  /// 动态详情
  Future<PostItem?> fetchDetail(int id) async {
    final r = await _dio.get(
      '/api/softlib/post/detail',
      queryParameters: {'id': id},
    );
    if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
      return PostItem.fromJson(Map<String, dynamic>.from(r.data['data']));
    }
    return null;
  }

  /// 发布
  /// 返回 reviewing（1013d：服务端审核开关开时=1，发布后进入待审）
  Future<bool> create({
    required String nickname,
    required String content,
    List<String> images = const [],
    int catId = 0,
    String avatar = '',
    String videoUrl = '',
    String videoType = '',
  }) async {
    final r = await _dio.post(
      '/api/softlib/post/create',
      data: {
        'token': UserService.instance.token,
        'nickname': nickname,
        'content': content,
        'images': images.join(','),
        'cat_id': catId,
        'avatar': avatar,
        if (videoUrl.isNotEmpty) 'video_url': videoUrl,
        if (videoType.isNotEmpty) 'video_type': videoType,
      },
    );
    if (r.data is Map && r.data['code'] != 1) {
      throw Exception(r.data['msg'] ?? '发布失败');
    }
    return (r.data is Map && '${r.data['data']?['review'] ?? '0'}' == '1');
  }

  /// 点赞（服务端为「切换」语义，返回当前最新总数）
  ///
  /// ★ 1014 P0 修复：不再静默吞错。未登录/网络异常时抛出带可读文案的
  ///   异常，由 UI 层统一 toast，避免用户「点了没反应」以为是卡死。
  ///   同时必须带 token —— 服务端只从请求体读 token。
  Future<int?> like(int id) async {
    final r = await _dio.post(
      '/api/softlib/post/like',
      data: {'id': id, 'token': UserService.instance.token},
    );
    if (r.data is Map && r.data['code'] == 1) {
      return int.tryParse('${r.data['data']?['like_count']}');
    }
    final msg = (r.data is Map ? r.data['msg'] : null)?.toString() ?? '';
    throw Exception(msg.isEmpty ? '点赞失败，请稍后重试' : msg);
  }

  /// 评论列表
  Future<List<Map<String, dynamic>>> comments(int postId) async {
    try {
      final r = await _dio.get(
        '/api/softlib/post/comment_list',
        queryParameters: {'post_id': postId},
      );
      if (r.data is Map && r.data['code'] == 1 && r.data['data'] is List) {
        return List<Map<String, dynamic>>.from(
          ((r.data['data'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (e) {
      debugPrint('[Softlib] $e');
    }
    return [];
  }

  /// 发评论（支持 @回复）
  Future<bool> comment({
    required int postId,
    required String nickname,
    required String content,
    String avatar = '',
    List<String> images = const [],
    int replyTo = 0,
  }) async {
    final r = await _dio.post(
      '/api/softlib/post/comment',
      data: {
        'token': UserService.instance.token,
        'post_id': postId,
        'nickname': nickname,
        'content': content,
        'avatar': avatar,
        'images': images.join(','),
        if (replyTo > 0) 'reply_to': replyTo,
      },
    );
    return r.data is Map && r.data['code'] == 1;
  }

  /// 删除评论（仅作者或管理员）
  Future<bool> deleteComment(int id) async {
    final r = await _dio.post(
      '/api/softlib/post/comment_del',
      data: {'token': UserService.instance.token, 'id': id},
    );
    return r.data is Map && r.data['code'] == 1;
  }

  /// 删除动态（仅作者或管理员）
  Future<bool> deletePost(int id) async {
    final r = await _dio.post(
      '/api/softlib/post/delete',
      data: {'token': UserService.instance.token, 'id': id},
    );
    return r.data is Map && r.data['code'] == 1;
  }

  /// 测试蓝奏云文件夹解析（返回软件数量）
  Future<int> fetchFolderForTest(String url) async {
    final r = await _dio.get(
      '/api/softlib/app/folder',
      queryParameters: {'url': url},
      options: Options(receiveTimeout: const Duration(seconds: 50)),
    );
    if (r.data is Map) {
      final m = r.data as Map;
      if (m['code'] == 1 && m['data'] is List)
        return ((m['data'] as List?) ?? const []).length;
      throw Exception((m['msg'] ?? '解析失败').toString());
    }
    throw Exception('解析失败');
  }

  /// 上传图片
  Future<String> uploadImage(File file) async {
    final form = FormData.fromMap({
      // ★ 1014 P2：服务端已加登录校验，上传必须带 token
      'token': UserService.instance.token,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final r = await _dio.post(
      '/api/softlib/pic/index',
      data: form,
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    if (r.data is Map && r.data['code'] == 1) {
      return (r.data['data']['url'] ?? '').toString();
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '上传失败') : '上传失败');
  }

  /// 上传视频（本地模式）
  Future<String> uploadVideo(File file) async {
    final form = FormData.fromMap({
      // ★ 1014 P2：服务端已加登录校验，上传必须带 token
      'token': UserService.instance.token,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final r = await _dio.post(
      '/api/softlib/video/index',
      data: form,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    if (r.data is Map && r.data['code'] == 1) {
      return (r.data['data']['url'] ?? '').toString();
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '视频上传失败') : '视频上传失败');
  }

  /// 解析视频分享链接（链接模式）
  Future<Map<String, dynamic>> parseVideoLink(String url) async {
    final r = await _dio.get(
      '/api/softlib/videoparse/index',
      queryParameters: {'url': url},
    );
    if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
      final m = Map<String, dynamic>.from(r.data['data']);
      if ((m['url'] ?? '').toString().isEmpty) {
        // 后端已给出具体原因时直接用
        throw Exception((m['error'] ?? '没有识别到链接').toString());
      }
      return m;
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '解析失败') : '解析失败');
  }

  /// v52g #2：视频直链过期 → 用原始链接重新解析
  Future<Map<String, dynamic>> videoRefresh(int postId) async {
    final r = await _dio.post(
      '/api/softlib/post/video_refresh',
      data: {'id': postId},
    );
    if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
      return Map<String, dynamic>.from(r.data['data']);
    }
    throw Exception((r.data is Map ? r.data['msg'] : '') ?? '刷新失败');
  }
}
