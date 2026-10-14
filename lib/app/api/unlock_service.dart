import 'package:dio/dio.dart';

import 'api_host.dart';
import 'user_service.dart';

/// 付费软件解锁状态
class UnlockStatus {
  final bool isPaid;
  final String price;
  final bool owned;
  final bool isVipUser;
  final bool canDownload;
  final String balance;
  final String reason;

  UnlockStatus({
    required this.isPaid,
    required this.price,
    required this.owned,
    required this.isVipUser,
    required this.canDownload,
    required this.balance,
    required this.reason,
  });

  static int _i(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  factory UnlockStatus.fromJson(Map j) => UnlockStatus(
        isPaid: _i(j['is_paid']) == 1,
        price: (j['price'] ?? '0.00').toString(),
        owned: _i(j['owned']) == 1,
        isVipUser: _i(j['is_vip_user']) == 1,
        canDownload: _i(j['can_download']) == 1,
        balance: (j['balance'] ?? '0.00').toString(),
        reason: (j['reason'] ?? '').toString(),
      );
}

/// 付费软件解锁（余额支付）
class UnlockService {
  UnlockService._();
  static final UnlockService instance = UnlockService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiHost.base,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));

  Future<UnlockStatus> status(int appId) async {
    // ★ 1014 关键修复：服务端已强制「token 只能放请求体」（不再读 URL，
    //   避免 token 落到访问日志）。原来这里用 GET + URL 传 token，
    //   导致服务端取不到身份 → 误判成未登录 → 会员/管理员下载被要求付费！
    final r = await _dio.post('/api/softlib/unlock/status', data: {
      'app_id': appId,
      'token': UserService.instance.token,
    });
    if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
      return UnlockStatus.fromJson(Map<String, dynamic>.from(r.data['data']));
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '获取失败') : '获取失败');
  }

  /// 用余额购买
  Future<Map<String, dynamic>> buy(int appId) async {
    final r = await _dio.post('/api/softlib/unlock/buy', data: {
      'token': UserService.instance.token,
      'app_id': appId,
    });
    if (r.data is Map && r.data['code'] == 1) {
      return Map<String, dynamic>.from(r.data['data'] ?? {});
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '购买失败') : '购买失败');
  }
}
