import 'dart:async';
import 'api_http.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_host.dart';
import 'user_service.dart';

/// 会员套餐
class PayPlan {
  final String id;
  final String name;
  final String money;
  final int days;
  const PayPlan({
    required this.id,
    required this.name,
    required this.money,
    required this.days,
  });

  factory PayPlan.fromJson(Map<String, dynamic> j) => PayPlan(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    money: (j['money'] ?? '').toString(),
    days: int.tryParse((j['days'] ?? 0).toString()) ?? 0,
  );
}

/// 创建订单的结果
class PayOrder {
  final String outTradeNo;
  final String payUrl;
  final String money;
  const PayOrder({
    required this.outTradeNo,
    required this.payUrl,
    required this.money,
  });
}

/// 支付服务（易支付协议，后端 /api/softlib/pay/*）
class PayService {
  PayService._();
  static final PayService instance = PayService._();

  final Dio _dio = ApiHttp.create(
    BaseOptions(
      baseUrl: ApiHost.base,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dynamic _unwrap(Response r) {
    final d = r.data;
    if (d is Map) {
      if (d['code'] == 1) return d['data'];
      throw Exception((d['msg'] ?? '请求失败').toString());
    }
    throw Exception('返回格式异常');
  }

  /// 套餐列表 + 支付开关状态
  Future<Map<String, dynamic>> plans() async {
    final data = _unwrap(await _dio.get('/api/softlib/pay/plans'));
    final m = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    m['planList'] = ((m['plans'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => PayPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return m;
  }

  /// 创建订单，返回收银台地址
  /// 余额充值套餐（与会员套餐分开）
  Future<RechargePlans> rechargePlans() async {
    final data = _unwrap(await _dio.get('/api/softlib/pay/recharge_plans'));
    final m = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    final list = ((m['plans'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => PayPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final methods = ((m['methods'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k.toString(), v == true || v == 1),
    );
    return RechargePlans(
      plans: list,
      enabled: m['enabled'] == true || m['enabled'] == 1,
      methods: methods,
    );
  }

  /// 创建余额充值订单 → 返回收银台地址
  Future<String> createRecharge({
    required String money,
    required String payType,
  }) async {
    final data = _unwrap(
      await _dio.post(
        '/api/softlib/pay/recharge',
        data: {
          'token': UserService.instance.token,
          'money': money,
          'pay_type': payType,
        },
      ),
    );
    final m = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    return (m['pay_url'] ?? '').toString();
  }

  Future<PayOrder> create({
    required String planId,
    required String payType,
  }) async {
    final token = UserService.instance.token;
    final data = _unwrap(
      await _dio.post(
        '/api/softlib/pay/create',
        data: {'plan_id': planId, 'pay_type': payType, 'token': token},
      ),
    );
    final m = Map<String, dynamic>.from(data as Map);
    return PayOrder(
      outTradeNo: (m['out_trade_no'] ?? '').toString(),
      payUrl: (m['pay_url'] ?? '').toString(),
      money: (m['money'] ?? '').toString(),
    );
  }

  /// 查询订单是否已支付
  Future<bool> isPaid(String outTradeNo) async {
    try {
      final token = UserService.instance.token;
      final data = _unwrap(
        await _dio.post(
          '/api/softlib/pay/status',
          data: {'out_trade_no': outTradeNo, 'token': token},
        ),
      );
      if (data is Map) return data['paid'] == true || data['status'] == 1;
      return false;
    } catch (e) {
      debugPrint('[Pay] $e');
      return false;
    }
  }

  /// 轮询等待支付完成（最多 [timeout]），返回是否成功
  /// 用户付完款切回 App 时能尽快感知到
  Future<bool> waitPaid(
    String outTradeNo, {
    Duration timeout = const Duration(minutes: 5),
    void Function(int seconds)? onTick,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var elapsed = 0;
    while (DateTime.now().isBefore(deadline)) {
      if (await isPaid(outTradeNo)) return true;
      await Future.delayed(const Duration(seconds: 3));
      elapsed += 3;
      onTick?.call(elapsed);
    }
    return false;
  }
}

/// 余额充值套餐集合
class RechargePlans {
  final List<PayPlan> plans;
  final bool enabled;
  final Map<String, bool> methods;

  RechargePlans({
    required this.plans,
    required this.enabled,
    required this.methods,
  });
}
