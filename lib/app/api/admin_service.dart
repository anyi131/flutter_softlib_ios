import 'dart:convert';
import 'api_http.dart';
import 'dart:io';

import 'package:dio/dio.dart';

import 'api_host.dart';
import 'user_service.dart';
import '../utils/device_info_util.dart';
import '../utils/json_safe.dart';

/// 内嵌管理系统服务（需管理员账号登录）
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final Dio _dio = ApiHttp.create(
    BaseOptions(
      headers: DeviceInfo.headers,
      baseUrl: ApiHost.base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );

  /// 统一 POST（自动带 token）
  Future<Map<String, dynamic>> _post(
    String action, [
    Map<String, dynamic> extra = const {},
  ]) async {
    try {
      final r = await _dio.post(
        '/api/softlib/admin/$action',
        data: {...extra, 'token': UserService.instance.token},
      );
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

  // ───── 安全防护（1011）─────
  Future<Map<String, dynamic>> secReport() async =>
      Map<String, dynamic>.from((await _post('sec_report'))['data'] ?? {});

  Future<void> secBanIp(String ip, {String reason = '管理员手动封禁'}) async =>
      _post('sec_ban_ip', {'ip': ip, 'reason': reason});

  Future<void> secUnbanIp(String ip) async => _post('sec_unban_ip', {'ip': ip});

  Future<Map<String, dynamic>> secKillall() async => Map<String, dynamic>.from(
    (await _post('sec_killall', {'confirm': 'yes'}))['data'] ?? {},
  );

  Future<void> secSign(String signMd5, {String note = '线上APK签名'}) async =>
      _post('sec_sign', {'sign_md5': signMd5, 'note': note});

  Future<Map<String, dynamic>> secSignCheck(String signMd5) async =>
      Map<String, dynamic>.from(
        (await _post('sec_sign_check', {'sign_md5': signMd5}))['data'] ?? {},
      );

  // ───── 安全增强 v1011b（审计/登录保护/限流）─────

  /// 审计日志（分页）
  Future<Map<String, dynamic>> secLogs({int page = 1, int size = 20}) async =>
      Map<String, dynamic>.from(
        (await _post('sec_logs', {'page': page, 'size': size}))['data'] ?? {},
      );

  /// ★ 1016：接口自测 —— 一键检测所有关键接口
  Future<Map<String, dynamic>> apiSelftest() async {
    final m = await _post('api_selftest');
    return J.map(m['data']);
  }

  /// ★ 1016：解析记录（蓝奏云解析成功/失败 + 原因 + 耗时）
  Future<Map<String, dynamic>> parseLogs({int page = 1}) async {
    final m = await _post('parse_logs', {'page': page});
    return J.map(m['data']);
  }

  /// ★ 1016：错误/崩溃日志（后台「日志 → 错误日志」）
  /// ★ 1020：全部在线用户（分页 + 时间筛选 + 搜索）
  Future<Map<String, dynamic>> onlineUsers({
    int mins = 60,
    int page = 1,
    int size = 50,
    String kw = '',
  }) async {
    final m = await _post('online_users', {
      'mins': mins,
      'page': page,
      'size': size,
      'kw': kw,
    });
    return J.map(m['data']);
  }

  /// 接口文档（自动扫描生成）
  Future<Map<String, dynamic>> apiDoc() async {
    final m = await _post('api_doc');
    return J.map(m['data']);
  }

  /// 重新生成接口文档
  Future<Map<String, dynamic>> apiDocRegen() async {
    final m = await _post('api_doc_regen');
    return J.map(m['data']);
  }

  /// 数据一致性审计
  Future<Map<String, dynamic>> dataAudit() async {
    final m = await _post('data_audit');
    return J.map(m['data']);
  }

  /// 一键重算（清孤儿评价 + 同步评分）
  Future<Map<String, dynamic>> dataFix() async {
    final m = await _post('data_fix');
    return J.map(m['data']);
  }

  /// 开屏接口自测（后台「测试」按钮）
  Future<Map<String, dynamic>> splashTest() async {
    final m = await _post('splash_test');
    return J.map(m['data']);
  }

  /// ★ 1020：积分排行榜（仅后台，用户明确要求不在 App 公开）
  Future<Map<String, dynamic>> scoreRank({
    int days = 30,
    int limit = 50,
  }) async {
    final m = await _post('score_rank', {'days': days, 'limit': limit});
    return J.map(m['data']);
  }

  /// ★ 1020：性能监控汇总
  Future<Map<String, dynamic>> perfSummary({int days = 7}) async {
    final m = await _post('perf_summary', {'days': days});
    return J.map(m['data']);
  }

  /// 清理性能日志
  Future<void> perfClean({int days = 14}) async {
    await _post('perf_clean', {'days': days});
  }

  // ═══════════ 配置版本化与回滚（★ 1020）═══════════

  /// 配置历史列表
  Future<List<Map<String, dynamic>>> configHistory() async {
    final m = await _post('config_history');
    final d = J.map(m['data']);
    return ((d['list'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// 查看某版本（含与当前配置的差异）
  Future<Map<String, dynamic>> configHistoryView(String file) async {
    final m = await _post('config_history_view', {'file': file});
    return J.map(m['data']);
  }

  /// 回滚到某版本
  Future<void> configRollback(String file) async {
    await _post('config_rollback', {'file': file});
  }

  /// 删除某历史版本
  Future<void> configHistoryDelete(String file) async {
    await _post('config_history_delete', {'file': file});
  }

  /// ★ 1020：管理员强制解绑某用户的 QQ
  Future<void> qqUnbind(int userId) async {
    await _post('qq_unbind', {'user_id': userId});
  }

  /// ★ 1020：已绑定 QQ 的账号列表（排查「一个 QQ 绑多个号」）
  Future<Map<String, dynamic>> qqBindings({
    String keyword = '',
    int page = 1,
  }) async {
    final m = await _post('qq_bindings', {'keyword': keyword, 'page': page});
    return J.map(m['data']);
  }

  /// ★ 1020（待办 #2）：需求投票（求软件）
  Future<Map<String, dynamic>> wishList({String status = 'all'}) async {
    final m = await _post('wish_admin_list', {'status': status});
    return J.map(m['data']);
  }

  Future<void> wishReview({
    required int id,
    required String status,
    String note = '',
  }) async {
    await _post('wish_admin_review', {
      'id': id,
      'status': status,
      'admin_note': note,
    });
  }

  Future<void> wishDelete(int id) async {
    await _post('wish_admin_delete', {'id': id});
  }

  /// ★ 1020：崩溃聚合 —— 按堆栈指纹分组，按影响用户数排序
  Future<Map<String, dynamic>> errorGroups({
    int days = 30,
    int limit = 20,
  }) async {
    final m = await _post('error_groups', {'days': days, 'limit': limit});
    return J.map(m['data']);
  }

  Future<Map<String, dynamic>> errorLogs({int page = 1, int size = 30}) async {
    final m = await _post('error_logs', {'page': page, 'size': size});
    return J.map(m['data']);
  }

  /// ★ 1016：版权梦配置统一入口
  ///   sub = banquan / banquan_save / quanju / quanju_save / auto / auto_save
  ///       / send_code / apps_list / app_stats / app_stats_all
  Future<Map<String, dynamic>> collectEx(
    String sub, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final m = await _post('collect_ex', {...extra, 'sub': sub});
    return J.map(m['data']);
  }

  /// ★ 1016：下载记录（成功/失败 + 失败原因）
  Future<Map<String, dynamic>> downloadLogs({
    int page = 1,
    int size = 20,
    String status = '',
    String keyword = '',
    int? vip,
  }) async => Map<String, dynamic>.from(
    (await _post('download_logs', {
          'page': page,
          'size': size,
          if (status.isNotEmpty) 'status': status,
          if (keyword.isNotEmpty) 'keyword': keyword,
          if (vip != null) 'vip': vip,
        }))['data'] ??
        {},
  );

  /// ★ 1016：切换签名守卫模式（0=观察 1=拦截）
  Future<Map<String, dynamic>> secSignGuardSave(int mode) async =>
      Map<String, dynamic>.from(
        (await _post('sec_sign_guard_save', {'mode': mode}))['data'] ?? {},
      );

  /// 被限 IP 列表（登录保护）
  Future<List<Map<String, dynamic>>> secLoginfails() async {
    final d = (await _post('sec_loginfails'))['data'];
    return List<Map<String, dynamic>>.from(
      ((d?['list'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  /// 手动解封被限 IP（登录保护）
  Future<void> secLoginfailClear(String ip) async =>
      _post('sec_loginfail_clear', {'ip': ip});

  /// 限流阈值保存（sys_config: sec_rate_limit，0=不限流）
  Future<void> secRateSave(int rate) async =>
      _post('sec_rate_save', {'rate': rate});

  /// 清理过期 token
  Future<Map<String, dynamic>> secCleanToken() async =>
      Map<String, dynamic>.from((await _post('sec_clean_token'))['data'] ?? {});

  Future<List<Map<String, dynamic>>> apps({String keyword = ''}) async {
    final d = (await _post('apps', {'keyword': keyword}))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  /// ★ 批量设置分类/会员下载/网页跳转类型/置顶（只更新传入的字段）
  Future<Map<String, dynamic>> appBatch({
    required List<int> ids,
    int? catId,
    int? isVip,
    String? vipPrice,
    String? urlType,
    int? isTop,
  }) async {
    final d = (await _post('app_batch', {
      'ids': ids.join(','),
      if (catId != null) 'cat_id': catId,
      if (isVip != null) 'is_vip': isVip,
      if (vipPrice != null) 'vip_price': vipPrice,
      if (urlType != null) 'url_type': urlType,
      if (isTop != null) 'is_top': isTop,
    }))['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// ★ 批量置顶 / 取消置顶（1014 需求2）
  Future<Map<String, dynamic>> appTop({
    required List<int> ids,
    bool on = true,
  }) async {
    final d = (await _post('app_top', {
      'ids': ids.join(','),
      'on': on ? 1 : 0,
    }))['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  Future<void> saveApp(Map<String, dynamic> data) async =>
      _post('app_save', data);

  /// ★ 一键补全缺失参数（单选/多选/全部）
  /// ids 为空且 all=false 时会报错；返回 {total, filled, skipped, failed, details}
  Future<Map<String, dynamic>> appFill({
    List<int>? ids,
    bool all = false,
    int limit = 100,
  }) async {
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
  }) async => _post('user_custom_ip', {
    'id': id,
    if (customIp != null) 'custom_ip': customIp,
    if (customAddr != null) 'custom_addr': customAddr,
    if (on != null) 'custom_ip_on': on ? 1 : 0,
  });

  /// 解析蓝奏云链接 / 本地文件 → 自动带出软件信息
  Future<Map<String, dynamic>> parse({
    required String type,
    String url = '',
    String filePath = '',
  }) async {
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
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
      'token': UserService.instance.token,
    });
    final r = await _dio.post(
      '/api/softlib/admin/upload_image',
      data: form,
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    if (r.data is Map && r.data['code'] == 1) {
      return (r.data['data']['url'] ?? '').toString();
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '上传失败') : '上传失败');
  }

  /// 上传本地安装包（multipart）
  Future<Map<String, dynamic>> uploadFile(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
      'token': UserService.instance.token,
    });
    final r = await _dio.post(
      '/api/softlib/admin/upload',
      data: form,
      options: Options(receiveTimeout: const Duration(seconds: 120)),
    );
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
      Map<String, dynamic>.from(
        (await _post('report_detail', {'id': id}))['data'] ?? {},
      );

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

  Future<void> deleteVersion(int id) async => _post('version_del', {'id': id});

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
  Future<Map<String, dynamic>> syncSource(
    int id, {
    int fromPage = 1,
    int pages = 10,
  }) async {
    final d = (await _post('source_sync', {
      'id': id,
      'from_page': fromPage,
      'pages': pages,
    }))['data'];
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
      _post('user_batch', {'ids': jsonEncode(ids), 'op': op, 'days': days});

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
    String? expireDate,
  }) async => Map<String, dynamic>.from(
    (await _post('user_vip', {
          'id': id,
          'days': days,
          'mode': mode,
          if (expireDate != null && expireDate.isNotEmpty)
            'expire_date': expireDate,
        }))['data'] ??
        {},
  );

  /// 查看用户明文密码（管理员协助找回）
  Future<Map<String, dynamic>> userPassword(int id) async =>
      Map<String, dynamic>.from(
        (await _post('user_password', {'id': id}))['data'] ?? {},
      );

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
      Map<String, dynamic>.from(
        (await _post('user_logs', {'id': id}))['data'] ?? {},
      );

  /// 清理日志：all=true 清空全部；否则清理 N 天前
  Future<void> clearOpLogs({int days = 30, bool all = false}) async =>
      _post('op_log_clear', all ? {'mode': 'all'} : {'days': days});

  Future<List<Map<String, dynamic>>> reviews() async {
    final d = (await _post('reviews'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> deleteReview(int id) async => _post('review_del', {'id': id});

  // ───── 广场动态审核（1013d）─────
  /// 审核列表：filter = all | pending | passed | rejected
  Future<Map<String, dynamic>> postReviewList({String filter = 'all'}) async =>
      Map<String, dynamic>.from(
        (await _post('post_review_list', {'filter': filter}))['data'] ?? {},
      );

  /// 审核：ids 单条或批量；action = pass | reject
  Future<void> postReview(List<int> ids, {required String action}) async =>
      _post('post_review', {'ids': ids.join(','), 'action': action});

  /// 审核开关（post_review_on）
  Future<void> postReviewSave({required bool on}) async =>
      _post('post_review_save', {'post_review_on': on ? 1 : 0});

  Future<Map<String, dynamic>> splash() async =>
      Map<String, dynamic>.from((await _post('splash'))['data'] ?? {});

  /// ★ 1020：返回校验结果 {verified, missed, missed_count}
  Future<Map<String, dynamic>> saveSplash(Map<String, dynamic> data) async {
    final m = await _post('splash_save', data);
    final d = m['data'];
    if (d is Map) return Map<String, dynamic>.from(d);
    return {'verified': true, 'missed_count': 0};
  }

  Future<Map<String, dynamic>> config() async =>
      Map<String, dynamic>.from((await _post('config'))['data'] ?? {});

  Future<Map<String, dynamic>> saveConfig(Map<String, dynamic> data) async {
    final m = await _post('config_save', data);
    final d = m['data'];
    if (d is Map) return Map<String, dynamic>.from(d);
    return {'verified': true, 'missed_count': 0};
  }

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
  }) async => Map<String, dynamic>.from(
    (await _post('collect_login', {
          'user': user,
          if (pass.isNotEmpty) 'pass': pass,
        }))['data'] ??
        {},
  );

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
  Future<Map<String, dynamic>> collectList({
    int page = 1,
    String keyword = '',
  }) async {
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
        (await _post('collect_status', {'task_id': taskId}))['data'] ?? {},
      );

  /// ★ 补齐采集结果：站点 task_status 不返回已完成任务的 results，
  ///   完成后调用这里，从站点「采集日志」页按名称匹配出蓝奏云链接
  Future<Map<String, dynamic>> collectResults(
    List<String> names, {
    int at = 0,
  }) async => Map<String, dynamic>.from(
    (await _post('collect_results', {
          'names': jsonEncode(names),
          'at': at,
        }))['data'] ??
        {},
  );

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
  Future<void> collectDirToggle(int configId, bool enabled) async => _post(
    'collect_dir_toggle',
    {'config_id': configId, 'status': enabled ? 1 : 0},
  );

  /// 删除目录
  Future<void> collectDirDelete(int configId) async =>
      _post('collect_dir_delete', {'config_id': configId});

  /// 采集日志（全部历史结果，含蓝奏云链接）
  Future<Map<String, dynamic>> collectLogs() async =>
      Map<String, dynamic>.from((await _post('collect_logs'))['data'] ?? {});

  /// 采集平台的「蓝奏云 Cookie」配置状态
  Future<Map<String, dynamic>> collectLzyCookie() async =>
      Map<String, dynamic>.from(
        (await _post('collect_lzycookie'))['data'] ?? {},
      );

  /// 提交蓝奏云账号密码，让采集平台去获取并保存 Cookie
  Future<Map<String, dynamic>> collectLzyCookieSave({
    required String user,
    required String pass,
  }) async => Map<String, dynamic>.from(
    (await _post('collect_lzycookie_save', {
          'lzy_user': user,
          'lzy_pass': pass,
        }))['data'] ??
        {},
  );

  /// 清空采集平台上的蓝奏云 Cookie
  Future<void> collectLzyCookieClear() async =>
      _post('collect_lzycookie_clear');

  /// 把采集结果导入软件库
  Future<Map<String, dynamic>> collectImport(
    List<Map<String, dynamic>> items, {
    int? catId,
    int? isVip,
    String? vipPrice,
    bool skipExisting = true,
    bool updateExisting = false,
  }) async {
    final d = (await _post('collect_import', {
      'items': jsonEncode(items),
      if (catId != null) 'cat_id': catId,
      if (isVip != null) 'is_vip': isVip,
      if (vipPrice != null) 'vip_price': vipPrice,
      'skip_existing': skipExisting ? 1 : 0,
      'update_existing': updateExisting ? 1 : 0,
    }))['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// ★ 需求2：批量预检（传入名称/版本列表，返回哪些已在库及库内版本）
  Future<Map<String, dynamic>> collectCheck(
    List<Map<String, dynamic>> items,
  ) async {
    final d = (await _post('collect_check', {
      'names': jsonEncode(items),
    }))['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  // ───────── 工具管理（v43 #5）─────────
  Future<List<Map<String, dynamic>>> toolCats() async {
    final d = (await _post('tool_cats'))['data'];
    return d is List ? d.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> saveToolCat(Map<String, dynamic> data) async =>
      _post('tool_cat_save', data);

  Future<void> deleteToolCat(int id) async => _post('tool_cat_del', {'id': id});

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

  Future<void> deleteJzsCat(int id) async => _post('jzs_cat_del', {'id': id});

  Future<List<Map<String, dynamic>>> jzsTools({
    int catId = 0,
    String keyword = '',
  }) async {
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

  Future<void> deleteJzsTool(int id) async => _post('jzs_tool_del', {'id': id});

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

  // ═══════════ 工具箱管理（1014 补全）═══════════

  /// 后台工具的「总览统计」
  Future<Map<String, dynamic>> toolboxStats() async {
    final d = (await _post('jzs_tools', {'limit': 1000}))['data'];
    final list = (d is Map && d['list'] is List)
        ? (d['list'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
        : <Map<String, dynamic>>[];
    final cats = await jzsCats();
    final enabled = list.where((t) => _on(t['enable_switch'])).length;
    final online = list.where((t) => '${t['api_url'] ?? ''}'.isNotEmpty).length;
    return {
      'cats': cats.length,
      'tools': list.length,
      'enabled': enabled,
      'disabled': list.length - enabled,
      'online': online,
      'local': list.length - online,
    };
  }

  static bool _on(dynamic v) => v == 1 || v == '1' || v == true;

  /// 安全取整（后端返回可能是 int / String / double）
  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  /// 分类树（含每个分类下的工具数量）
  Future<List<Map<String, dynamic>>> toolboxCats() async {
    final cats = await jzsCats();
    final tools = await jzsTools();
    for (final c in cats) {
      c['tools'] = tools
          .where((t) => (t['cat_id'] ?? 0) == (c['id'] ?? 0))
          .toList();
    }
    return cats;
  }

  /// 调整排序（上移 / 下移：与相邻同类工具交换 weigh）
  Future<void> moveJzsTool(Map<String, dynamic> tool, int delta) async {
    final all = await jzsTools(catId: _int(tool['cat_id']));
    if (all.isEmpty) return;
    final i = all.indexWhere((t) => t['id'] == tool['id']);
    if (i < 0) return;
    final j = i + delta;
    if (j < 0 || j >= all.length) return;
    final a = all[i];
    final b = all[j];
    // weigh 相同会导致顺序不稳，这里用序号保证单调
    final wa = _int(a['weigh']);
    final wb = _int(b['weigh']);
    final na = wb;
    final nb = wa == wb ? (delta > 0 ? wa - 1 : wa + 1) : wa;
    await saveJzsTool({...a, 'weigh': na});
    await saveJzsTool({...b, 'weigh': nb});
  }

  /// 调整分类排序
  Future<void> moveJzsCat(Map<String, dynamic> cat, int delta) async {
    final all = await jzsCats();
    final i = all.indexWhere((c) => c['id'] == cat['id']);
    if (i < 0) return;
    final j = i + delta;
    if (j < 0 || j >= all.length) return;
    final a = all[i];
    final b = all[j];
    final wa = _int(a['weigh']);
    final wb = _int(b['weigh']);
    final na = wb;
    final nb = wa == wb ? (delta > 0 ? wa - 1 : wa + 1) : wa;
    await saveJzsCat({...a, 'weigh': na});
    await saveJzsCat({...b, 'weigh': nb});
  }
}
