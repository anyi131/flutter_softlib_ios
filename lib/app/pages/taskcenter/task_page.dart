import 'dart:async';

import '../../design/app_anim.dart';
import '../../utils/err_text.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/task_service.dart';
import '../../design/adaptive.dart';
import '../../design/ui.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';
import '../../design/kit.dart';

/// ★ 1016：赏帮赚新手任务 → 领会员
class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final _svc = TaskService.instance;
  final _pwd = TextEditingController();
  final _pid = TextEditingController();
  final _note = TextEditingController();

  Map<String, dynamic>? _cfg;
  bool _loading = true;
  bool _submitting = false;
  bool _claiming = false;
  String _shotUrl = '';
  String _shotLocal = '';
  List<Map<String, dynamic>> _applies = [];
  int _applyState = -1; // -1 未申请 0 待审 1 通过 2 驳回

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pwd.dispose();
    _pid.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await _svc.config(force: true);
    final a = await _svc.myApplies();
    if (!mounted) return;
    setState(() {
      _cfg = c;
      _applies = a;
      _applyState = a.isEmpty
          ? -1
          : (int.tryParse('${a.first['status']}') ?? -1);
      _loading = false;
      if (a.isNotEmpty) {
        _pid.text = '${a.first['platform_id'] ?? ''}';
      }
    });
  }

  String _s(String k) => '${_cfg?[k] ?? ''}';
  int get _i => int.tryParse('${_cfg?['reward_value'] ?? 0}') ?? 0;
  bool get _isVipReward => _s('reward_type') != 'score';
  List get _tasks => (_cfg?['task_list'] as List?) ?? const [];

  Future<void> _claim() async {
    final v = _pwd.text.trim();
    if (v.isEmpty) {
      ToastUtil.error('请输入任务密码');
      return;
    }
    setState(() => _claiming = true);
    try {
      final d = await _svc.claim(v);
      if (!mounted) return;
      _showSuccess(d);
      _pwd.clear();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _showSuccess(Map<String, dynamic> d) {
    final isVip = '${d['reward_type'] ?? 'vip'}' == 'vip';
    final val = d['reward_value'] ?? _i;
    String expire = '';
    final ex = int.tryParse('${d['vip_expire'] ?? 0}') ?? 0;
    if (ex > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ex * 1000);
      expire =
          '到期时间：${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    }
    showDialog<void>(
      context: context,
      builder: (c) => AppDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.only(top: 22),
        title: const Text(
          '🎉',
          style: TextStyle(fontSize: 40),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '领取成功',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.t1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVip
                  ? '你已获得 $val 天会员${expire.isEmpty ? '' : '\n$expire'}'
                  : '你已获得 $val 积分',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.6, color: context.t2),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: 200,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.brand),
              onPressed: () => Navigator.pop(c),
              child: const Text('开心收下'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickShot() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (f == null) return;
      setState(() => _shotLocal = f.path);
      ToastUtil.info('正在上传截图…');
      final url = await _svc.uploadShot(f.path);
      if (!mounted) return;
      setState(() => _shotUrl = url);
      ToastUtil.success('截图已上传');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _submit() async {
    final id = _pid.text.trim();
    if (id.isEmpty) {
      ToastUtil.error('请填写赏帮赚「我的ID」');
      return;
    }
    if ('${_cfg?['require_shot'] ?? 1}' == '1' && _shotUrl.isEmpty) {
      ToastUtil.error('请上传新手福利页截图');
      return;
    }
    setState(() => _submitting = true);
    try {
      final msg = await _svc.apply(
        platformId: id,
        shotUrl: _shotUrl,
        note: _note.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ToastUtil.success(msg);
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ★ 1028 深色适配：原整页浅底 + 白卡，深色模式下文字仍是浅色 → 白字白底看不见
      backgroundColor: context.isDark ? C.bg0 : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  _navBar(),
                  _banner(),
                  _flow(),
                  if ('${_cfg?['enable'] ?? 0}' == '1') ...[
                    _passwordCard(),
                    _inputPanel(),
                  ] else
                    _disabledTip(),
                ],
              ),
      ),
    );
  }

  Widget _navBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          AppPressable(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.isDark ? C.bg2 : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: context.t1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${_s('platform').isEmpty ? '获取任务密码' : '${_s('platform')}新手任务'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.t1,
              ),
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  Widget _banner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A45).withAlpha(50),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF7A45),
                    Color(0xFFFF9F43),
                    Color(0xFFFFC53D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(60),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '限时福利 · 仅限新用户',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _s('title').isEmpty ? '做完新手任务，免费领会员' : _s('title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _s('content').isEmpty ? '必须完成全部新手任务，才可领取' : _s('content'),
                    style: TextStyle(
                      color: Colors.white.withAlpha(235),
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(36),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '⏰ 注册后 7 天内完成，过期作废',
                      style: TextStyle(
                        color: Colors.white.withAlpha(240),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: context.isDark ? C.bg2 : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  _metaCell('${_tasks.length} 项', '新手任务'),
                  _metaCell('约 10 分钟', '预计耗时'),
                  _metaCell('$_i ${_isVipReward ? '天' : '积分'}', '本站奖励'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaCell(String v, String l) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFF7A45),
          ),
        ),
        const SizedBox(height: 2),
        Text(l, style: TextStyle(fontSize: 11, color: context.t3)),
      ],
    ),
  );

  Widget _flow() {
    final steps = <Widget>[
      _step(
        1,
        '用我的链接下载注册',
        '点下方按钮 → 下载${_s('platform')} → 手机号注册（老用户无效）',
        action: _inviteBtn(),
      ),
      _step(
        2,
        '确认已绑定邀请人',
        '注册后进入「新手福利」页，顶部应显示「我的邀请人：${_s('invite_code')}」',
        warning: '没显示这串数字 = 注册方式错了，需重新注册',
      ),
      _step(
        3,
        '完成全部 ${_tasks.length} 项新手任务',
        '每一项都要做完，缺一项不可领',
        child: _taskChecklist(),
      ),
      _step(4, '加管理员微信，发送 2 样东西', '把你的「我的ID」和截图发给管理员', child: _submitBox()),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      decoration: BoxDecoration(
        color: context.isDark ? C.bg2 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withAlpha(16)
              : Colors.black.withAlpha(12),
        ),
      ),
      child: Column(children: steps),
    );
  }

  Widget _step(
    int n,
    String title,
    String desc, {
    Widget? action,
    Widget? child,
    String? warning,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF7A45), Color(0xFFFFC53D)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$n',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w700,
                    color: context.t1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12.3,
                    height: 1.65,
                    color: context.t2,
                  ),
                ),
                if (warning != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '⚠️ $warning',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC77700),
                      height: 1.5,
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 10), action],
                if (child != null) ...[const SizedBox(height: 9), child],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _inviteBtn() {
    final url = _s('invite_url');
    if (url.isEmpty) return const SizedBox.shrink();
    return AppPressable(
      onTap: () => JumpUtil.openUrl(url),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A45), Color(0xFFFFA53D)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7A45).withAlpha(70),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          '立即下载${""}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _taskChecklist() {
    if (_tasks.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withAlpha(10)
            : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final t in _tasks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFD0D5E2),
                        width: 1.6,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t['title'] ?? ''}',
                          style: TextStyle(
                            fontSize: 12.4,
                            color: context.t1,
                            height: 1.5,
                          ),
                        ),
                        if ('${t['desc'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${t['desc']}',
                            style: TextStyle(fontSize: 11, color: context.t3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _submitBox() {
    final wx = _s('wechat');
    final hours = _s('reply_hours');
    if (_applyState == 0) {
      return _statusBox('⏳ 申请已提交，等待管理员核实', '通过后会收到站内消息，含任务密码', C.amber);
    }
    if (_applyState == 1) {
      return _statusBox('✅ 已通过审核', '任务密码已发到「消息中心」，去输入领取', C.mint);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_applyState == 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _statusBox(
              '❌ 上次申请被驳回',
              '${_applies.isNotEmpty ? (_applies.first['admin_note'] ?? '') : ''}',
              C.rose,
            ),
          ),
        TextField(
          controller: _pid,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: '填写你的「我的ID」（如 34838755）',
            hintStyle: TextStyle(fontSize: 12.5, color: context.t3),
            isDense: true,
            filled: true,
            fillColor: context.isDark
                ? Colors.white.withAlpha(10)
                : const Color(0xFFF8F9FC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.black.withAlpha(14)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.black.withAlpha(14)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AppPressable(
          onTap: _pickShot,
          child: Container(
            height: _shotUrl.isEmpty ? 46 : null,
            padding: _shotUrl.isEmpty ? null : const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.isDark
                  ? Colors.white.withAlpha(10)
                  : const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _shotUrl.isEmpty
                    ? Colors.black.withAlpha(14)
                    : C.mint.withAlpha(120),
              ),
            ),
            child: _shotUrl.isEmpty
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 17,
                        color: context.t3,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '上传新手福利页截图（必传）',
                        style: TextStyle(fontSize: 12.5, color: context.t3),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_shotLocal),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            color: context.isDark
                                ? Colors.white.withAlpha(14)
                                : const Color(0xFFEDEFF5),
                            child: Icon(
                              Icons.image_rounded,
                              size: 20,
                              color: context.t3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '截图已上传 ✓',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: C.mint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickShot,
                        child: const Text('重选', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: C.brand,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _submitting ? '提交中…' : '提交申请核实',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFFFF7A45).withAlpha(26)
                : const Color(0xFFFFF9F0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: context.isDark
                  ? const Color(0xFFFFB74D).withAlpha(80)
                  : const Color(0xFFFFD9A8),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '管理员微信：$wx',
                      style: TextStyle(
                        fontSize: 12.4,
                        color: context.isDark
                            ? const Color(0xFFFFC078)
                            : const Color(0xFFB0793A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '核实通过后 $hours 小时内发密码',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.isDark
                            ? const Color(0xFFFFD9B0).withAlpha(190)
                            : const Color(0xFFB8A084),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: wx));
                  ToastUtil.success('微信号已复制');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A45), Color(0xFFFFA53D)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '复制微信',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBox(String title, String sub, Color c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.6,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              sub,
              style: TextStyle(fontSize: 11.5, color: context.t2, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _passwordCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? C.bg2 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? const Color(0xFF2E7D52).withAlpha(150)
              : const Color(0xFFC7F0D8),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✅ 审核通过后会在这里收到密码',
            style: TextStyle(fontSize: 12, color: context.t2),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _applyState == 1 ? '已发送到消息中心' : '待审核',
                  style: TextStyle(
                    fontSize: _applyState == 1 ? 18 : 16,
                    fontWeight: FontWeight.w800,
                    color: _applyState == 1
                        ? const Color(0xFF0C8A4C)
                        : context.t3,
                  ),
                ),
              ),
              if (_applyState == 1)
                AppPressable(
                  onTap: () => Get.toNamed('/message'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF12B76A), Color(0xFF0C8A4C)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '去查看',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.isDark
                  ? const Color(0xFF34D399).withAlpha(22)
                  : const Color(0xFFF4FBF7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '密码 30 天内有效 · 仅限本人使用',
              style: TextStyle(
                fontSize: 11.2,
                color: context.isDark
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFF4B8B6A).withAlpha(230),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: C.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '输入密码领取',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: context.t1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withAlpha(14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '把管理员发给你的密码填到这里',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.t2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pwd,
                        style: const TextStyle(fontSize: 14, letterSpacing: 2),
                        onSubmitted: (_) => _claim(),
                        decoration: InputDecoration(
                          hintText: '请输入任务密码',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: context.t3,
                            letterSpacing: 0,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: context.isDark ? C.bg3 : const Color(0xFFF8F9FC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(18),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(18),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: _claiming ? null : _claim,
                        style: FilledButton.styleFrom(
                          backgroundColor: C.brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: Text(
                          _claiming ? '领取中…' : '领取',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '每个账号 ${_s('limit_days')} 天内可领取 ${_s('limit_count')} 次 · 密码区分大小写',
                  style: TextStyle(fontSize: 11.5, color: context.t3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _disabledTip() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(
          '活动暂未开启，敬请期待',
          style: TextStyle(fontSize: 13, color: context.t3),
        ),
      ),
    );
  }
}
