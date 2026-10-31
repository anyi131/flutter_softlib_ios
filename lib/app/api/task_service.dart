import 'dart:io';

import 'package:dio/dio.dart';
import 'api_http.dart';

import 'api_host.dart';
import 'user_service.dart';
import '../utils/device_info_util.dart';
import '../utils/img_compress.dart';

/// ★ 1016：任务奖励（做任务 → 输密码 → 领会员）
class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  final Dio _dio = ApiHttp.create(
    BaseOptions(
      headers: DeviceInfo.headers,
      baseUrl: ApiHost.base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  Map<String, dynamic>? _cfg;

  /// 读任务配置（后台可随时改，带短缓存）
  Future<Map<String, dynamic>?> config({bool force = false}) async {
    if (!force && _cfg != null) return _cfg;
    try {
      final r = await _dio.post(
        '/api/softlib/taskpwdinfo',
        data: {'token': UserService.instance.token},
      );
      if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
        _cfg = Map<String, dynamic>.from(r.data['data']);
        return _cfg;
      }
    } catch (_) {}
    return _cfg;
  }

  /// 输入密码领取奖励
  Future<Map<String, dynamic>> claim(String password) async {
    final r = await _dio.post(
      '/api/softlib/taskpwd',
      data: {'token': UserService.instance.token, 'password': password},
    );
    final m = r.data is Map ? Map<String, dynamic>.from(r.data) : null;
    if (m == null) throw Exception('返回格式异常');
    if (m['code'] != 1) throw Exception(m['msg'] ?? '领取失败');
    final d = m['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// 提交申请（我的ID + 截图 + 备注）
  Future<String> apply({
    required String platformId,
    String shotUrl = '',
    String note = '',
  }) async {
    final r = await _dio.post(
      '/api/softlib/taskapply',
      data: {
        'token': UserService.instance.token,
        'platform_id': platformId,
        'shot_url': shotUrl,
        'note': note,
      },
    );
    final m = r.data is Map ? Map<String, dynamic>.from(r.data) : null;
    if (m == null) throw Exception('返回格式异常');
    if (m['code'] != 1) throw Exception(m['msg'] ?? '提交失败');
    return '${m['msg'] ?? '已提交'}';
  }

  /// 查自己的申请状态
  Future<List<Map<String, dynamic>>> myApplies() async {
    try {
      final r = await _dio.post(
        '/api/softlib/taskapplymine',
        data: {'token': UserService.instance.token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        final l = (r.data['data'] as Map?)?['list'];
        if (l is List) {
          return l.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// 上传截图（复用项目已有的 /api/softlib/pic/index）
  Future<String> uploadShot(String path) async {
    final cf = await ImgCompress.upload(File(path));
    final form = FormData.fromMap({
      'token': UserService.instance.token,
      'file': await MultipartFile.fromFile(
        cf.path,
        filename: path.split('/').last,
      ),
    });
    final r = await _dio.post(
      '/api/softlib/pic/index',
      data: form,
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    if (r.data is Map && r.data['code'] == 1) {
      return '${(r.data['data'] as Map?)?['url'] ?? ''}';
    }
    throw Exception(r.data is Map ? '${r.data['msg'] ?? '上传失败'}' : '上传失败');
  }
}
