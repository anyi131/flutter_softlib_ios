import 'dart:io';
import 'api_http.dart';

import 'package:dio/dio.dart';

import '../models/review_item.dart';
import '../utils/img_compress.dart';
import 'api_host.dart';
import 'user_service.dart';

/// 软件评价服务
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  final Dio _dio = ApiHttp.create(
    BaseOptions(
      baseUrl: ApiHost.base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// 评分统计
  Future<ReviewSummary> summary(int appId) async {
    try {
      final r = await _dio.get(
        '/api/softlib/review/summary',
        queryParameters: {'app_id': appId},
      );
      if (r.data is Map && r.data['code'] == 1) {
        return ReviewSummary.fromJson(
          Map<String, dynamic>.from(r.data['data']),
        );
      }
    } catch (_) {}
    return ReviewSummary.empty();
  }

  /// 评价列表
  Future<List<ReviewItem>> list(
    int appId, {
    String filter = 'all',
    String sort = 'latest',
    int page = 1,
  }) async {
    try {
      final r = await _dio.get(
        '/api/softlib/review/list',
        queryParameters: {
          'app_id': appId,
          'filter': filter,
          'sort': sort,
          'pages': page,
        },
      );
      if (r.data is Map && r.data['code'] == 1) {
        return ReviewItem.listFrom(r.data['data']);
      }
    } catch (_) {}
    return [];
  }

  /// 发布评价
  Future<void> create({
    required int appId,
    required int score,
    required String content,
    List<String> images = const [],
  }) async {
    final r = await _dio.post(
      '/api/softlib/review/create',
      data: {
        'token': UserService.instance.token,
        'app_id': appId,
        'score': score,
        'content': content,
        'images': images.join(','),
      },
    );
    if (r.data is Map && r.data['code'] != 1) {
      throw Exception(r.data['msg'] ?? '发布失败');
    }
  }

  /// 点赞
  Future<int?> like(int id) async {
    try {
      final r = await _dio.post('/api/softlib/review/like', data: {'id': id});
      if (r.data is Map && r.data['code'] == 1) {
        return int.tryParse('${r.data['data']?['like_count']}');
      }
    } catch (_) {}
    return null;
  }

  /// 删除自己的评价
  Future<bool> remove(int id) async {
    final r = await _dio.post(
      '/api/softlib/review/delete',
      data: {'token': UserService.instance.token, 'id': id},
    );
    return r.data is Map && r.data['code'] == 1;
  }

  /// 发布回复
  Future<void> reply({
    required int reviewId,
    required String content,
    String replyTo = '',
  }) async {
    final r = await _dio.post(
      '/api/softlib/review/reply',
      data: {
        'token': UserService.instance.token,
        'review_id': reviewId,
        'content': content,
        'reply_to': replyTo,
      },
    );
    if (r.data is Map && r.data['code'] != 1) {
      throw Exception(r.data['msg'] ?? '回复失败');
    }
  }

  /// 删除回复
  Future<bool> removeReply(int id) async {
    final r = await _dio.post(
      '/api/softlib/review/reply_delete',
      data: {'token': UserService.instance.token, 'id': id},
    );
    return r.data is Map && r.data['code'] == 1;
  }

  /// 上传评价图片
  Future<String> uploadImage(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        (await ImgCompress.upload(file)).path,
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
}
