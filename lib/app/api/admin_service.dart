import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'api_host.dart';
import 'user_service.dart';
import '../utils/device_info_util.dart';


/// 内嵌管理系统服务（需管理员账号登录）
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final Dio _dio = Dio(BaseOptions(
    headers: DeviceInfo.headers,
    baseUrl: ApiHost.base,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 25),
  ));

  /// 统一 POST（自动带 token）
  Future<Map<String, dynamic>> _post(String action,
      [Map<String, dynamic> extra = const {}]) async {
    try {
      final r = await _dio.post('/api/softlib/admin/$action',
          data: {...extra, 'token': UserService.instance.token});
      if (r.data is Map) {
        final m = Map<String, dynamic>.from(r.data);
        if (m['code'] != 1) throw Exception(m['msg'] ?? '操作失败');
        return m;
      }
    } on DioException catch (e) {
      throw Exception(e.message ?? '网络异常');
    }
    throw Exception('返回格式异常');
  }

  Future<Map<String, dynamic>> dashboard() async =>
      Map<String, dynamic>.from((await _post('dashboard'))['data'] ?? {});

  Future<List<Map<String, dynamic>>> apps({String keyword = ''}) async {
    final d = (await _post('apps', {'keyword': keyword}))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> saveApp(Map<String, dynamic> data) async => _post('app_save', data);

  /// ★ 一键补全缺失参数（单选/多选/全部）
  /// ids 为空且 all=false 时会报错；返回 {total, filled, skipped, failed, details}
  Future<Map<String, dynamic>> appFill({List<int>? ids, bool all = false, int limit = 100}) async {
    final d = (await _post('app_fill', {
      if (all) 'all': 1,
      if (ids != null && ids.isNotEmpty) 'ids': ids.join(','),
      'limit': limit,
    }))['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// ★ 自定义 IP 显示（管理员覆盖用户展示的 IP/归属地）
  Future<void> userCustomIp({
    required int id,
    String? customIp,
    String? customAddr,
    bool? on,
  }) async =>
      _post('user_custom_ip', {
        'id': id,
        if (customIp != null) 'custom_ip': customIp,
        if (customAddr != null) 'custom_addr': customAddr,
        if (on != null) 'custom_ip_on': on ? 1 : 0,
      });

  /// 解析蓝奏云链接 / 本地文件 → 自动带出软件信息
  Future<Map<String, dynamic>> parse({required String type, String url = '', String filePath = ''}) async {
    final d = (await _post('parse', {
      'type': type,
      if (url.isNotEmpty) 'url': url,
      if (filePath.isNotEmpty) 'file_path': filePath,
    }))['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// 上传图片（图标/截图/横幅）
  Future<String> uploadImage(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path,
          filename: file.path.split('/').last),
      'token': UserService.instance.token,
    });
    final r = await _dio.post('/api/softlib/admin/upload_image',
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 90)));
    if (r.data is Map && r.data['code'] == 1) {
      return (r.data['data']['url'] ?? '').toString();
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '上传失败') : '上传失败');
  }

  /// 上传本地安装包（multipart）
  Future<Map<String, dynamic>> uploadFile(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path,
          filename: file.path.split('/').last),
      'token': UserService.instance.token,
    });
    final r = await _dio.post('/api/softlib/admin/upload',
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 120)));
    if (r.data is Map && r.data['code'] == 1) {
      return Map<String, dynamic>.from(r.data['data'] ?? {});
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '上传失败') : '上传失败');
  }

  Future<void> deleteApp(int id) async => _post('app_del', {'id': id});

  Future<void> saveCat(Map<String, dynamic> data) async =>
      _post('cat_save', data);

  Future<void> deleteCat(int id) async => _post('cat_del', {'id': id});

  Future<List<Map<String, dynamic>>> carousels() async {
    final d = (await _post('carousels'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> saveCarousel(Map<String, dynamic> data) async =>
      _post('carousel_save', data);

  Future<void> deleteCarousel(int id) async =>
      _post('carousel_del', {'id': id});

  Future<List<Map<String, dynamic>>> reports() async {
    final d = (await _post('reports'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> deleteReport(int id) async => _post('report_del', {'id': id});

  Future<List<Map<String, dynamic>>> cards() async {
    final d = (await _post('cards'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> generateCards(int count, String type, int value) async =>
      _post('card_gen', {'count': count, 'type': type, 'value': value});

  Future<void> deleteCard(int id) async => _post('card_del', {'id': id});

  // ── 线报详情/分类 ──
  Future<Map<String, dynamic>> reportDetail(int id) async =>
      Map<String, dynamic>.from((await _post('report_detail', {'id': id}))['data'] ?? {});

  Future<List<Map<String, dynamic>>> reportCats() async {
    final d = (await _post('report_cats'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  // ── 首页推荐位 ──
  Future<List<Map<String, dynamic>>> referrals() async {
    final d = (await _post('referrals'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> saveReferral(Map<String, dynamic> data) async =>
      _post('referral_save', data);

  Future<void> deleteReferral(int id) async =>
      _post('referral_del', {'id': id});

  // ── 版本更新 ──
  Future<List<Map<String, dynamic>>> versions() async {
    final d = (await _post('versions'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> saveVersion(Map<String, dynamic> data) async =>
      _post('version_save', data);

  Future<void> deleteVersion(int id) async =>
      _post('version_del', {'id': id});

  Future<void> saveReport(Map<String, dynamic> data) async =>
      _post('report_save', data);

  /// 数据源（蓝奏云文件夹）
  Future<List<Map<String, dynamic>>> sources() async {
    final d = (await _post('sources'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> saveSource(Map<String, dynamic> data) async =>
      _post('source_save', data);

  Future<void> deleteSource(int id) async => _post('source_del', {'id': id});

  /// 同步数据源（分批抓取蓝奏云文件夹内容到本地缓存）
  Future<Map<String, dynamic>> syncSource(int id,
      {int fromPage = 1, int pages = 10}) async {
    final d = (await _post('source_sync',
        {'id': id, 'from_page': fromPage, 'pages': pages}))['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  Future<List<Map<String, dynamic>>> appCats() async {
    final d = (await _post('app_cats'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<List<Map<String, dynamic>>> users({
    String keyword = '',
    String filter = 'all',
    int page = 1,
    int size = 30,
  }) async {
    final d = (await _post('users', {
      'keyword': keyword,
      'filter': filter,
      'page': page,
      'size': size,
    }))['data'];
    if (d is Map && d['list'] is List) {
      return (d['list'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    // 兼容旧版后端直接返回数组
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  /// 用户统计（总数/VIP/管理员/封禁/今日新增/累计余额）
  Future<Map<String, dynamic>> userStat({
    String keyword = '',
    String filter = 'all',
  }) async {
    final d = (await _post('users', {
      'keyword': keyword,
      'filter': filter,
      'page': 1,
      'size': 10,
    }))['data'];
    if (d is Map && d['stat'] is Map) {
      return Map<String, dynamic>.from(d['stat']);
    }
    return {};
  }

  /// 批量操作：op = vip | ban | unban | delete
  Future<void> userBatch(List<int> ids, String op, {int days = 30}) async =>
      _post('user_batch', {
        'ids': jsonEncode(ids),
        'op': op,
        'days': days,
      });

  /// 导出用户 CSV 文本
  Future<String> userExportCsv({String filter = 'all'}) async {
    final d = (await _post('user_export', {'filter': filter}))['data'];
    return d is Map ? (d['csv'] ?? '').toString() : '';
  }

  /// 会员天数调整：mode = add（赠送）| sub（扣减）| forever（永久）
  Future<Map<String, dynamic>> grantVip(
    int id,
    int days, {
    String mode = 'add',
  }) async =>
      Map<String, dynamic>.from((await _post('user_vip', {
        'id': id,
        'days': days,
        'mode': mode,
      }))['data'] ?? {});

  /// 查看用户明文密码（管理员协助找回）
  Future<Map<String, dynamic>> userPassword(int id) async =>
      Map<String, dynamic>.from(
          (await _post('user_password', {'id': id}))['data'] ?? {});

  /// 重置用户密码（同时保存可查看的加密副本）
  Future<void> resetUserPassword(int id, String password) async =>
      _post('user_reset_password', {'id': id, 'password': password});

  Future<void> setAdmin(int id, bool value) async =>
      _post('user_admin', {'id': id, 'value': value ? 1 : 0});

  Future<void> toggleUserStatus(int id) async =>
      _post('user_status', {'id': id});

  Future<void> deleteUser(int id) async => _post('user_del', {'id': id});

  Future<void> saveUser(Map<String, dynamic> data) async =>
      _post('user_save', data);

  Future<List<Map<String, dynamic>>> posts() async {
    final d = (await _post('posts'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> deletePost(int id) async => _post('post_del', {'id': id});

  /// 编辑帖子（正文 / 分类）
  Future<void> savePost(Map<String, dynamic> data) async =>
      _post('post_save', data);

  /// 评论列表（后台管理）
  Future<List<Map<String, dynamic>>> comments() async {
    final d = (await _post('comments'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> deleteComment(int id) async => _post('comment_del', {'id': id});

  // ───────── 操作日志 ─────────
  /// 操作日志列表（可按用户/动作/关键词筛选）
  Future<Map<String, dynamic>> opLogs({
    int userId = 0,
    String action = '',
    String keyword = '',
    int page = 1,
  }) async {
    final d = (await _post('op_logs', {
      if (userId > 0) 'user_id': userId,
      if (action.isNotEmpty) 'action': action,
      if (keyword.isNotEmpty) 'keyword': keyword,
      'page': page,
    }))['data'];
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// 某用户的详细日志（含设备/IP 汇总）
  Future<Map<String, dynamic>> userLogs(int id) async =>
      Map<String, dynamic>.from((await _post('user_logs', {'id': id}))['data'] ?? {});

  /// 清理日志：all=true 清空全部；否则清理 N 天前
  Future<void> clearOpLogs({int days = 30, bool all = false}) async =>
      _post('op_log_clear', all ? {'mode': 'all'} : {'days': days});

  Future<List<Map<String, dynamic>>> reviews() async {
    final d = (await _post('reviews'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> deleteReview(int id) async => _post('review_del', {'id': id});

  Future<Map<String, dynamic>> splash() async =>
      Map<String, dynamic>.from((await _post('splash'))['data'] ?? {});

  Future<void> saveSplash(Map<String, dynamic> data) async =>
      _post('splash_save', data);

  Future<Map<String, dynamic>> config() async =>
      Map<String, dynamic>.from((await _post('config'))['data'] ?? {});

  Future<void> saveConfig(Map<String, dynamic> data) async =>
      _post('config_save', data);

  // ───────── 订单 ─────────
  Future<List<Map<String, dynamic>>> orders({
    int? status,
    String keyword = '',
    int page = 1,
  }) async {
    final d = (await _post('orders', {
      if (status != null) 'status': status,
      if (keyword.isNotEmpty) 'keyword': keyword,
      'page': page,
    }))['data'];
    if (d is Map && d['list'] is List) {
      return (d['list'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> orderStats() async =>
      Map<String, dynamic>.from((await _post('order_stats'))['data'] ?? {});

  /// 手动补单（确认收款后给用户加会员）
  Future<void> deliverOrder(String outTradeNo) async =>
      _post('order_deliver', {'out_trade_no': outTradeNo});

  Future<void> deleteOrder(int id) async => _post('order_del', {'id': id});

  // ───────── 版权梦采集 ─────────
  Future<Map<String, dynamic>> collectConfig() async =>
      Map<String, dynamic>.from((await _post('collect_config'))['data'] ?? {});

  /// 账号密码自动登录（后端会识别验证码）；pass 留空表示用已保存的密码
  Future<Map<String, dynamic>> collectLogin({
    required String user,
    String pass = '',
  }) async =>
      Map<String, dynamic>.from((await _post('collect_login', {
        'user': user,
        if (pass.isNotEmpty) 'pass': pass,
      }))['data'] ?? {});

  /// 退出采集平台登录
  Future<void> collectLogout() async => _post('collect_logout');

  Future<bool> saveCollectConfig(Map<String, dynamic> data) async {
    final r = await _post('collect_save', data);
    final d = r['data'];
    return d is Map && (d['logged_in'] == true || d['logged_in'] == 1);
  }

  /// 保存采集平台的登录 Cookie 并验证
  Future<bool> saveCollectCookie(String cookie) async {
    final r = await _post('collect_cookie', {'cookie': cookie});
    final d = r['data'];
    return d is Map && (d['logged_in'] == true || d['logged_in'] == 1);
  }

  /// 采集平台的软件列表
  Future<Map<String, dynamic>> collectList({int page = 1, String keyword = ''}) async {
    final r = await _post('collect_list', {'page': page, 'keyword': keyword});
    final d = r['data'];
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// 发起采集（上传到自己的蓝奏云）
  Future<String> collectStart(List<Map<String, dynamic>> apps) async {
    final r = await _post('collect_start', {'apps': jsonEncode(apps)});
    final d = r['data'];
    return d is Map ? (d['task_id'] ?? '').toString() : '';
  }

  /// 查询采集进度（含结果链接）
  Future<Map<String, dynamic>> collectStatus(String taskId) async =>
      Map<String, dynamic>.from(
          (await _post('collect_status', {'task_id': taskId}))['data'] ?? {});

  /// ★ 补齐采集结果：站点 task_status 不返回已完成任务的 results，
  ///   完成后调用这里，从站点「采集日志」页按名称匹配出蓝奏云链接
  Future<Map<String, dynamic>> collectResults(
    List<String> names, {
    int at = 0,
  }) async =>
      Map<String, dynamic>.from((await _post('collect_results', {
        'names': jsonEncode(names),
        'at': at,
      }))['data'] ?? {});

  /// 采集平台的目录配置（哪个目录 / 关键词 / 屏蔽词 / 兜底 / 启用状态）
  Future<List<Map<String, dynamic>>> collectDirs() async {
    final d = (await _post('collect_dirs'))['data'];
    if (d is Map && d['dirs'] is List) {
      return (d['dirs'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// 新增 / 编辑目录
  Future<void> collectDirSave(Map<String, dynamic> data) async =>
      _post('collect_dir_save', data);

  /// 启用 / 禁用目录
  Future<void> collectDirToggle(int configId, bool enabled) async =>
      _post('collect_dir_toggle',
          {'config_id': configId, 'status': enabled ? 1 : 0});

  /// 删除目录
  Future<void> collectDirDelete(int configId) async =>
      _post('collect_dir_delete', {'config_id': configId});

  /// 采集日志（全部历史结果，含蓝奏云链接）
  Future<Map<String, dynamic>> collectLogs() async =>
      Map<String, dynamic>.from((await _post('collect_logs'))['data'] ?? {});

  /// 采集平台的「蓝奏云 Cookie」配置状态
  Future<Map<String, dynamic>> collectLzyCookie() async =>
      Map<String, dynamic>.from(
          (await _post('collect_lzycookie'))['data'] ?? {});

  /// 提交蓝奏云账号密码，让采集平台去获取并保存 Cookie
  Future<Map<String, dynamic>> collectLzyCookieSave({
    required String user,
    required String pass,
  }) async =>
      Map<String, dynamic>.from((await _post('collect_lzycookie_save', {
        'lzy_user': user,
        'lzy_pass': pass,
      }))['data'] ?? {});

  /// 清空采集平台上的蓝奏云 Cookie
  Future<void> collectLzyCookieClear() async =>
      _post('collect_lzycookie_clear');

  /// 把采集结果导入软件库
  Future<Map<String, dynamic>> collectImport(List<Map<String, dynamic>> items,
          {int catId = 0}) async =>
      Map<String, dynamic>.from((await _post('collect_import',
          {'items': jsonEncode(items), 'cat_id': catId}))['data'] ?? {});

  // ───────── 工具管理（v43 #5）─────────
  Future<List<Map<String, dynamic>>> toolCats() async {
    final d = (await _post('tool_cats'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> saveToolCat(Map<String, dynamic> data) async =>
      _post('tool_cat_save', data);

  Future<void> deleteToolCat(int id) async =>
      _post('tool_cat_del', {'id': id});

  Future<List<Map<String, dynamic>>> tools({int catId = 0}) async {
    final d = (await _post('tools', {if (catId > 0) 'cat_id': catId}))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> saveTool(Map<String, dynamic> data) async =>
      _post('tool_save', data);

  Future<void> deleteTool(int id) async => _post('tool_del', {'id': id});

  // ═══════════ 工具体系 v45（复刻样本「简助手」）═══════════

  Future<List<Map<String, dynamic>>> jzsCats() async {
    final d = (await _post('jzs_cats'))['data'];
    if (d is Map && d['list'] is List) {
      return (d['list'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<void> saveJzsCat(Map<String, dynamic> data) async =>
      _post('jzs_cat_save', data);

  Future<void> deleteJzsCat(int id) async =>
      _post('jzs_cat_del', {'id': id});

  Future<List<Map<String, dynamic>>> jzsTools(
      {int catId = 0, String keyword = ''}) async {
    final d = (await _post('jzs_tools', {
      if (catId > 0) 'cat_id': catId,
      if (keyword.isNotEmpty) 'kw': keyword,
    }))['data'];
    if (d is Map && d['list'] is List) {
      return (d['list'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<void> saveJzsTool(Map<String, dynamic> data) async =>
      _post('jzs_tool_save', data);

  Future<void> deleteJzsTool(int id) async =>
      _post('jzs_tool_del', {'id': id});

  Future<List<Map<String, dynamic>>> jzsBanners() async {
    final d = (await _post('jzs_banners'))['data'];
    if (d is Map && d['list'] is List) {
      return (d['list'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<void> saveJzsBanner(Map<String, dynamic> data) async =>
      _post('jzs_banner_save', data);

  Future<void> deleteJzsBanner(int id) async =>
      _post('jzs_banner_del', {'id': id});
}
