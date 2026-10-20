import 'package:flutter/material.dart';

import '../../../design/app_anim.dart';
import '../admin_ui_kit.dart';
import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';

/// ★ 1016：后台 · 任务活动配置
///
/// 对应服务端 `admin/task_pwd`（读）/ `admin/task_pwd_save`（写）
/// 可配置：开关 / 平台 / 邀请链接 / 邀请码 / 管理员微信 / 奖励 / 密码 / 限额 / 任务清单
class CollectTaskView extends StatefulWidget {
  const CollectTaskView({super.key});

  @override
  State<CollectTaskView> createState() => _CollectTaskViewState();
}

class _CollectTaskViewState extends State<CollectTaskView> {
  final _svc = AdminService.instance;
  bool _loading = true;
  bool _saving = false;

  bool enable = false;
  bool requireShot = true;

  final _platform = TextEditingController();
  final _inviteUrl = TextEditingController();
  final _inviteCode = TextEditingController();
  final _wechat = TextEditingController();
  final _password = TextEditingController();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _rewardValue = TextEditingController();
  final _limitDays = TextEditingController();
  final _limitCount = TextEditingController();
  final _replyHours = TextEditingController();
  String rewardType = 'vip';

  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _platform,
      _inviteUrl,
      _inviteCode,
      _wechat,
      _password,
      _title,
      _content,
      _rewardValue,
      _limitDays,
      _limitCount,
      _replyHours,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await _svc.collectEx('task_pwd_admin');
      if (!mounted) return;
      setState(() {
        enable = '${d['enable'] ?? 0}' == '1';
        requireShot = '${d['require_shot'] ?? 1}' == '1';
        rewardType = '${d['reward_type'] ?? 'vip'}';
        _platform.text = '${d['platform'] ?? '赏帮赚'}';
        _inviteUrl.text = '${d['invite_url'] ?? ''}';
        _inviteCode.text = '${d['invite_code'] ?? ''}';
        _wechat.text = '${d['wechat'] ?? ''}';
        _password.text = '${d['password'] ?? ''}';
        _title.text = '${d['title'] ?? ''}';
        _content.text = '${d['content'] ?? ''}';
        _rewardValue.text = '${d['reward_value'] ?? 3}';
        _limitDays.text = '${d['limit_days'] ?? 30}';
        _limitCount.text = '${d['limit_count'] ?? 1}';
        _replyHours.text = '${d['reply_hours'] ?? 1}';
        final t = d['task_list'];
        _tasks = t is List
            ? t.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.collectEx('task_pwd_save', {
        'enable': enable ? 1 : 0,
        'require_shot': requireShot ? 1 : 0,
        'platform': _platform.text.trim(),
        'invite_url': _inviteUrl.text.trim(),
        'invite_code': _inviteCode.text.trim(),
        'wechat': _wechat.text.trim(),
        'password': _password.text.trim(),
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'reward_type': rewardType,
        'reward_value': int.tryParse(_rewardValue.text.trim()) ?? 3,
        'limit_days': int.tryParse(_limitDays.text.trim()) ?? 30,
        'limit_count': int.tryParse(_limitCount.text.trim()) ?? 1,
        'reply_hours': int.tryParse(_replyHours.text.trim()) ?? 1,
        'task_list': _tasks,
      });
      if (mounted) ToastUtil.success('已保存，App 端立即生效');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        100,
      ),
      children: [
        AdSection(title: '任务活动', subtitle: 'App「我的 → 免费领会员」和付费弹窗入口都受此控制'),
        AdCard(
          child: Column(
            children: [
              _switchRow(
                '启用任务活动',
                '关闭后 App 里所有任务入口隐藏',
                enable,
                (v) => setState(() => enable = v),
              ),
              Divider(
                height: 20,
                color: (context.isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(12)),
              ),
              _switchRow(
                '要求上传截图',
                '审核时需要用户发新手福利页截图',
                requireShot,
                (v) => setState(() => requireShot = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdSection(title: '任务平台', subtitle: '用户要去哪里做任务'),
        AdCard(
          child: Column(
            children: [
              _field('平台名称', _platform, hint: '赏帮赚'),
              _field(
                '邀请下载链接',
                _inviteUrl,
                hint: 'https://...?code=你的推广码',
                maxLines: 2,
              ),
              _field('你的邀请码', _inviteCode, hint: '如 11922299'),
              _field('管理员微信', _wechat, hint: '用户加这个微信提交申请'),
              _field('承诺回复时长(小时)', _replyHours, hint: '1', number: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdSection(title: '任务清单', subtitle: '显示在 App 里的步骤，可增删改'),
        AdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _tasks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_tasks[i]['title'] ?? ''}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.t1,
                              ),
                            ),
                            if ('${_tasks[i]['desc'] ?? ''}'.isNotEmpty)
                              Text(
                                '${_tasks[i]['desc']}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.t3,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _tasks.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: _addTask,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加一项'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdSection(title: '奖励设置', subtitle: '审核通过后自动发放'),
        AdCard(
          child: Column(
            children: [
              Row(
                children: [
                  _typeChip(
                    '会员天数',
                    rewardType == 'vip',
                    () => setState(() => rewardType = 'vip'),
                  ),
                  const SizedBox(width: 8),
                  _typeChip(
                    '积分',
                    rewardType == 'score',
                    () => setState(() => rewardType = 'score'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _field(
                rewardType == 'vip' ? '奖励天数' : '奖励积分',
                _rewardValue,
                number: true,
              ),
              _field('每人可领天数(窗口)', _limitDays, number: true, hint: '30'),
              _field('窗口内可领次数', _limitCount, number: true, hint: '1'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdSection(title: '任务密码', subtitle: '用户在 App 里输入此密码领取奖励'),
        AdCard(child: _field('密码', _password, hint: '如 anyi0131')),
        const SizedBox(height: 16),
        AdSection(title: '文案', subtitle: 'App 顶部展示'),
        AdCard(
          child: Column(
            children: [
              _field('标题', _title, maxLines: 2),
              _field('说明', _content, maxLines: 3),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 46,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: C.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _saving ? '保存中…' : '保存设置',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _switchRow(String t, String sub, bool v, ValueChanged<bool> cb) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.t1,
                ),
              ),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 11, color: context.t3)),
            ],
          ),
        ),
        Switch.adaptive(value: v, onChanged: cb),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String hint = '',
    int maxLines = 1,
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.t3)),
          const SizedBox(height: 5),
          TextField(
            controller: c,
            maxLines: maxLines,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            style: TextStyle(fontSize: 13.5, color: context.t1),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: context.t3.withAlpha(140),
              ),
              isDense: true,
              filled: true,
              fillColor: context.isDark
                  ? Colors.white.withAlpha(10)
                  : const Color(0xFFF8F9FC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: (context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(12)),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: (context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String t, bool sel, VoidCallback onTap) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel
              ? C.brand
              : (context.isDark
                    ? Colors.white.withAlpha(12)
                    : const Color(0xFFF1F3F8)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? Colors.white : context.t2,
          ),
        ),
      ),
    );
  }

  Future<void> _addTask() async {
    final t = TextEditingController();
    final d = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('添加任务项', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: t,
              decoration: const InputDecoration(labelText: '标题'),
              style: const TextStyle(fontSize: 14),
            ),
            TextField(
              controller: d,
              decoration: const InputDecoration(labelText: '说明（可选）'),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (ok == true && t.text.trim().isNotEmpty) {
      setState(
        () => _tasks.add({'title': t.text.trim(), 'desc': d.text.trim()}),
      );
    }
  }
}
