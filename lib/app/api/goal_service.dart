import 'package:dio/dio.dart';

import 'api_host.dart';
import 'user_service.dart';

/// 1108z W1：任务/成就条目（user/goals 下发）
class GoalItem {
  final int id;
  final int kind; // 0 任务 1 成就
  final String title;
  final String desc;
  final String category;
  final String icon;
  final int target;
  final int progress;
  final int percent;
  final int reached;
  final int claimed;
  final int hidden;
  final bool titleMasked;
  final String rewardType; // score/money/vip_days/title
  final int rewardValue;

  const GoalItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.desc,
    required this.category,
    required this.icon,
    required this.target,
    required this.progress,
    required this.percent,
    required this.reached,
    required this.claimed,
    required this.hidden,
    required this.titleMasked,
    required this.rewardType,
    required this.rewardValue,
  });

  bool get isTask => kind == 0;
  bool get isAchievement => kind == 1;
  bool get canClaim => reached == 1 && claimed == 0;
  bool get done => claimed == 1;

  static int _i(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  factory GoalItem.fromJson(Map j) {
    final reward = (j['reward'] as Map?) ?? const {};
    return GoalItem(
      id: _i(j['id']),
      kind: _i(j['kind']),
      title: (j['title'] ?? '').toString(),
      desc: (j['desc'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      icon: (j['icon'] ?? '').toString(),
      target: _i(j['target']),
      progress: _i(j['progress']),
      percent: _i(j['percent']),
      reached: _i(j['reached']),
      claimed: _i(j['claimed']),
      hidden: _i(j['hidden']),
      titleMasked: _i(j['title_masked']) == 1,
      rewardType: (reward['type'] ?? '').toString(),
      rewardValue: _i(reward['value']),
    );
  }
}

/// 统一事件引擎（任务中心 + 成就墙）
class GoalService {
  GoalService._();
  static final GoalService instance = GoalService._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiHost.base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// 任务中心 + 成就墙（未登录也返回，progress 全 0）
  Future<List<GoalItem>> list() async {
    final r = await _dio.post(
      '/api/softlib/user/goals',
      data: {'token': UserService.instance.token},
    );
    if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
      final goals = (r.data['data']['goals'] as List?) ?? const [];
      return goals
          .map((e) => GoalItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '获取失败') : '获取失败');
  }

  /// 领取奖励
  Future<String> claim(int goalId) async {
    final r = await _dio.post(
      '/api/softlib/user/goal_claim',
      data: {'token': UserService.instance.token, 'goal_id': goalId},
    );
    if (r.data is Map && r.data['code'] == 1) {
      final d = r.data['data'];
      return d is Map ? (d['msg'] ?? '已领取').toString() : '已领取';
    }
    throw Exception(r.data is Map ? (r.data['msg'] ?? '领取失败') : '领取失败');
  }
}
