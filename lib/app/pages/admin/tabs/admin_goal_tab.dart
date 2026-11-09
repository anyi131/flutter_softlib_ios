import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/app_anim.dart';
import '../../../design/ui.dart';
import '../../../utils/app_action.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';
import '../admin_ui_kit.dart';

/// 1109：App 后台 · 任务与成就管理
/// 任务/成就的定义增删改、启停、神秘标记；带用户达成/领取统计
class AdminGoalTab extends StatefulWidget {
  const AdminGoalTab({super.key});

  @override
  State<AdminGoalTab> createState() => _AdminGoalTabState();
}

class _AdminGoalTabState extends State<AdminGoalTab> {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  static const _events = <String, String>{
    'login': '登录',
    'softDownload': '下载软件',
    'softBuy': '购买软件',
    'post': '发帖',
    'postComment': '帖子评论',
    'comment': '软件评论',
    'contribute': '投稿过审',
    'invite': '邀请注册',
    'recharge': '充值',
    'clock': '签到',
  };
  static const _rewards = <String, String>{
    'score': '积分',
    'money': '余额',
    'vip_days': '会员天数',
    'title': '称号',
  };
  static const _windows = <String, String>{'all': '累计', 'day': '每日', 'week': '每周'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _svc.goals();
      if (!mounted) return;
      setState(() {
        _rows = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _toggle(Map<String, dynamic> g, bool on) async {
    try {
      await _svc.goalToggle(int.tryParse('${g['id']}') ?? 0, on);
      if (!mounted) return;
      setState(() => g['enable_switch'] = on ? 1 : 0);
      ToastUtil.success(on ? '已启用' : '已停用');
    } catch (e) {
      if (mounted) ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _del(Map<String, dynamic> g) async {
    final okd = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('删除目标'),
      content: Text('确定删除「${g['title']}」？用户已领奖励不受影响。'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: const Text('删除', style: TextStyle(color: C.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (okd != true) return;
    try {
      await _svc.goalDel(int.tryParse('${g['id']}') ?? 0);
      if (!mounted) return;
      ToastUtil.success('已删除');
      _load();
    } catch (e) {
      if (mounted) ToastUtil.error(ErrText.of(e));
    }
  }

  /// 编辑/新增弹窗（商业化表单：分组 + 说明 + 校验）
  Future<void> _edit([Map<String, dynamic>? g]) async {
    final isNew = g == null;
    final title = TextEditingController(text: '${g?['title'] ?? ''}');
    final desc = TextEditingController(text: '${g?['desc'] ?? ''}');
    final target = TextEditingController(text: '${g?['target'] ?? 1}');
    final weigh = TextEditingController(text: '${g?['weigh'] ?? 0}');
    final rewardTitle = TextEditingController(text: '${g?['reward_title'] ?? ''}');
    final rewardValue = TextEditingController(text: '${g?['reward_value'] ?? 0}');
    int kind = int.tryParse('${g?['kind'] ?? 0}') ?? 0;
    String event = '${g?['event'] ?? 'login'}';
    String window = '${g?['window'] ?? 'all'}';
    String rewardType = '${g?['reward_type'] ?? 'score'}';
    bool hidden = '${g?['hidden'] ?? 0}' == '1';
    bool enabled = '${g?['enable_switch'] ?? 1}' == '1';
    final category = TextEditingController(text: '${g?['category'] ?? 'default'}');

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (ctx, setD) {
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 头
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        C.brand.withAlpha(28),
                        C.gold.withAlpha(18),
                      ]),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      Icon(isNew ? Lz.plus : Lz.pencil, size: 19, color: C.brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(isNew ? '新建任务 / 成就' : '编辑目标',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800, color: ctx.t1)),
                      ),
                      IconButton(
                        icon: Icon(Lz.x, size: 20, color: ctx.t3),
                        onPressed: () => Get.back(),
                      ),
                    ]),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                      children: [
                        // 类型
                        Row(children: [
                          _seg('任务', kind == 0, () => setD(() => kind = 0)),
                          const SizedBox(width: 8),
                          _seg('成就', kind == 1, () => setD(() => kind = 1)),
                        ]),
                        const SizedBox(height: 12),
                        _field(title, '名称', '如：下载达人'),
                        const SizedBox(height: 10),
                        _field(desc, '描述', '如：今日完成 3 次软件下载'),
                        const SizedBox(height: 10),
                        _field(category, '分类标签', '如：daily / consume（用于分组）'),
                        const SizedBox(height: 14),
                        _label('触发条件'),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: event,
                              isExpanded: true,
                              decoration: _dec('事件'),
                              items: _events.entries
                                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: (v) => setD(() => event = v ?? 'login'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: window,
                              isExpanded: true,
                              decoration: _dec('周期'),
                              items: _windows.entries
                                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: (v) => setD(() => window = v ?? 'all'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 74,
                            child: TextField(
                              controller: target,
                              keyboardType: TextInputType.number,
                              decoration: _dec('次数'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _label('奖励'),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: rewardType,
                              isExpanded: true,
                              decoration: _dec('类型'),
                              items: _rewards.entries
                                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: (v) => setD(() => rewardType = v ?? 'score'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (rewardType == 'title')
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: rewardTitle,
                                decoration: _dec('称号名'),
                              ),
                            )
                          else
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: rewardValue,
                                keyboardType: TextInputType.number,
                                decoration: _dec('数值'),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          const Expanded(child: Text('神秘成就（未达成显示 ？？？）')),
                          Switch(
                            value: hidden,
                            activeThumbColor: C.violet,
                            onChanged: (v) => setD(() => hidden = v),
                          ),
                        ]),
                        Row(children: [
                          const Expanded(child: Text('启用')),
                          Switch(
                            value: enabled,
                            activeThumbColor: C.mint,
                            onChanged: (v) => setD(() => enabled = v),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        _field(weigh, '排序权重', '越大越靠前'),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  // 底部按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () async {
                            if (title.text.trim().isEmpty) {
                              ToastUtil.info('请填写名称');
                              return;
                            }
                            Get.back();
                            AppAction.showLoading('正在保存…');
                            try {
                              await _svc.goalSave({
                                'id': g == null ? 0 : int.tryParse('${g['id']}') ?? 0,
                                'kind': kind,
                                'title': title.text.trim(),
                                'desc': desc.text.trim(),
                                'category': category.text.trim(),
                                'event': event,
                                'target': int.tryParse(target.text) ?? 1,
                                'window': window,
                                'reward_type': rewardType,
                                'reward_value': int.tryParse(rewardValue.text) ?? 0,
                                'reward_title': rewardTitle.text.trim(),
                                'hidden': hidden ? 1 : 0,
                                'enable_switch': enabled ? 1 : 0,
                                'weigh': int.tryParse(weigh.text) ?? 0,
                              });
                              AppAction.hideLoading();
                              ToastUtil.success('已保存');
                              _load();
                            } catch (e) {
                              AppAction.hideLoading();
                              ToastUtil.error(ErrText.of(e));
                            }
                          },
                          child: const Text('保存'),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _seg(String text, bool on, VoidCallback onTap) => AppPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: on ? C.brand : C.brand.withAlpha(18),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : C.brand)),
        ),
      );

  Widget _label(String t) => Text(t,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.t2));

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      );

  Widget _field(TextEditingController c, String label, String hint) => TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final tasks = _rows.where((r) => '${r['kind']}' == '0').toList();
    final achs = _rows.where((r) => '${r['kind']}' != '0').toList();
    final onCount = _rows.where((r) => '${r['enable_switch']}' == '1').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          // 统计头
          Row(children: [
            Expanded(child: _stat('任务', '${tasks.length}', C.brand)),
            const SizedBox(width: 10),
            Expanded(child: _stat('成就', '${achs.length}', C.gold)),
            const SizedBox(width: 10),
            Expanded(child: _stat('启用中', '$onCount', C.mint)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 3, height: 15,
                decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 7),
            Text('全部目标', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
            const Spacer(),
            AppPressable(
              onTap: () => _edit(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: C.brand.withAlpha(22), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Lz.plus, size: 14, color: C.brand),
                  const SizedBox(width: 3),
                  Text('新建', style: TextStyle(fontSize: 12, color: C.brand, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_rows.isEmpty)
            AdCard(
              padding: const EdgeInsets.symmetric(vertical: 34),
              child: Center(
                child: Column(children: [
                  Icon(Lz.trophy, size: 34, color: context.t3.withAlpha(90)),
                  const SizedBox(height: 8),
                  Text('还没有任务/成就', style: TextStyle(fontSize: 12.5, color: context.t3)),
                ]),
              ),
            ),
          for (final g in _rows) _goalCard(g),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => AdCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: context.t3)),
        ]),
      );

  Widget _goalCard(Map<String, dynamic> g) {
    final on = '${g['enable_switch']}' == '1';
    final isAch = '${g['kind']}' != '0';
    final rewardColor = switch ('${g['reward_type']}') {
      'money' => C.mint,
      'vip_days' => C.gold,
      'title' => C.violet,
      _ => C.warning,
    };
    final rewardText = '${g['reward_type']}' == 'title'
        ? '称号「${g['reward_title'] ?? ''}」'
        : '${_rewards[g['reward_type']] ?? g['reward_type']} +${g['reward_value'] ?? 0}';
    return AdCard(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      child: Opacity(
        opacity: on ? 1 : 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Pill(isAch ? '成就' : '任务', color: isAch ? C.gold : C.brand, small: true),
              if ('${g['hidden']}' == '1') ...[
                const SizedBox(width: 5),
                Pill('神秘', color: C.violet, small: true),
              ],
              const SizedBox(width: 6),
              Expanded(
                child: Text('${g['title'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.t1)),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: on,
                  activeThumbColor: C.mint,
                  onChanged: (v) => _toggle(g, v),
                ),
              ),
            ]),
            if ('${g['desc'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${g['desc']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: context.t2)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (context.isDark ? C.bg3 : C.lbg1).withAlpha(90),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _meta('${_events[g['event']] ?? g['event']} × ${g['target']}（${_windows[g['window']] ?? g['window']}）'),
                _meta(rewardText, color: rewardColor),
                _meta('达成 ${g['user_reached'] ?? 0} · 领取 ${g['user_claimed'] ?? 0}'),
              ]),
            ),
            const SizedBox(height: 9),
            Row(children: [
              _act('编辑', () => _edit(g)),
              const SizedBox(width: 8),
              const Spacer(),
              _act('删除', () => _del(g), danger: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _meta(String t, {Color? color}) => Text(t,
      style: TextStyle(fontSize: 10.5, color: color ?? context.t3, fontWeight: FontWeight.w600));

  Widget _act(String t, VoidCallback onTap, {bool danger = false}) => AppPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: (danger ? C.danger : C.brand).withAlpha(24),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(t,
              style: TextStyle(
                  fontSize: 11.5,
                  color: danger ? C.danger : C.brand,
                  fontWeight: FontWeight.w700)),
        ),
      );
}
