import 'package:flutter/material.dart';
import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 采集账号（版权梦）—— 配置 / 修改 / 解除登录
///
/// 主路径：填账号密码 → 后端自动识别验证码登录（推荐，一劳永逸）
/// 备用路径：手工粘贴浏览器 Cookie（验证码识别失败时兜底）
class CollectAccountCard extends StatefulWidget {
  /// 当前登录态（由父组件传入，也支持本地刷新）
  final bool loggedIn;
  final int totalPages;

  /// 数据变化时通知父组件刷新
  final VoidCallback onChanged;

  const CollectAccountCard({
    super.key,
    required this.loggedIn,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  State<CollectAccountCard> createState() => _CollectAccountCardState();
}

class _CollectAccountCardState extends State<CollectAccountCard> {
  final _svc = AdminService.instance;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _cookieCtrl = TextEditingController();

  /// 编辑模式：已配置时默认收起为「摘要」，点「修改」才展开表单
  bool _editing = false;

  bool _busy = false;
  bool _loadingCfg = true;
  bool _showCookie = false;
  bool _showPass = false;
  bool _hasPass = false;
  bool _loggedIn = false;
  int _totalPages = 0;
  String _lastLogin = '';
  String _user = '';

  @override
  void initState() {
    super.initState();
    _loggedIn = widget.loggedIn;
    _totalPages = widget.totalPages;
    // 未登录时直接进入编辑态，省一次点击
    _editing = !widget.loggedIn;
    _loadCfg();
  }

  @override
  void didUpdateWidget(covariant CollectAccountCard old) {
    super.didUpdateWidget(old);
    if (old.loggedIn != widget.loggedIn) {
      setState(() {
        _loggedIn = widget.loggedIn;
        _totalPages = widget.totalPages;
      });
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _cookieCtrl.dispose();
    super.dispose();
  }

  /// ★ 每次都重新拉配置，保证「修改」时看到的是服务器上的最新值
  Future<void> _loadCfg() async {
    try {
      final cfg = await _svc.collectConfig();
      if (!mounted) return;
      setState(() {
        final u = (cfg['collect_user'] ?? '').toString();
        _user = u;
        _userCtrl.text = u;
        _hasPass = cfg['has_pass'] == true || cfg['has_pass'] == 1;
        _lastLogin = (cfg['last_login'] ?? '').toString();
        _loggedIn = cfg['logged_in'] == true || cfg['logged_in'] == 1;
        _totalPages = (cfg['total_pages'] as num?)?.toInt() ?? 0;
        _loadingCfg = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCfg = false);
    }
  }

  /// 把后端/网络的原始异常翻成人话
  String _friendly(Object e) {
    final s = ErrText.of(e);
    if (s.contains('500')) return '服务器处理出错，请稍后重试或改用 Cookie 方式';
    if (s.contains('超时') || s.contains('timeout')) return '网络异常，请检查连接后重试';
    return s;
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) ToastUtil.error(_friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 登录 / 保存修改
  Future<void> _loginByPassword() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text.trim();
    if (u.isEmpty) {
      ToastUtil.info('请填写采集平台账号');
      return;
    }
    // 首次配置必须给密码；已配置过则可留空表示不改密码
    if (p.isEmpty && !_hasPass) {
      ToastUtil.info('请填写采集平台密码');
      return;
    }
    await _run(() async {
      final r = await _svc.collectLogin(user: u, pass: p);
      if (!mounted) return;
      _passCtrl.clear();
      setState(() {
        _editing = false;
        _hasPass = true;
        _loggedIn = true;
        _user = u;
        _totalPages = (r['total_pages'] as num?)?.toInt() ?? _totalPages;
        _lastLogin = '刚刚';
      });
      ToastUtil.success('已保存并登录成功（共 $_totalPages 页可采集）');
      widget.onChanged();
    });
  }

  Future<void> _saveCookie() async {
    final v = _cookieCtrl.text.trim();
    if (v.isEmpty) {
      ToastUtil.info('请粘贴 Cookie');
      return;
    }
    await _run(() async {
      final ok = await _svc.saveCollectCookie(v);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _editing = false;
          _loggedIn = true;
          _lastLogin = '刚刚';
        });
        ToastUtil.success('登录态有效，可以采集了');
        widget.onChanged();
      } else {
        ToastUtil.error('Cookie 无效或已过期');
      }
    });
  }

  /// ★ 解除登录（清掉本地会话）
  Future<void> _logout() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('解除采集登录'),
        content: const Text('解除后需要重新登录才能采集。账号密码会保留，重新登录只需一次点击。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Get.back(result: true),
            child: const Text('解除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await _svc.collectLogout();
      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _lastLogin = '';
      });
      ToastUtil.success('已解除登录');
      widget.onChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCfg) {
      return AdCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('读取采集账号…', style: Ty.small.copyWith(color: context.t2)),
          ],
        ),
      );
    }
    return AdCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 10),
          if (!_editing) _summary() else _form(),
        ],
      ),
    );
  }

  // ───────── 头部 ─────────
  Widget _header() {
    return Row(
      children: [
        Icon(
          _loggedIn ? Icons.verified_user_rounded : Icons.link_off_rounded,
          color: _loggedIn ? C.success : C.warning,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text('采集账号（版权梦）', style: Ty.h3.copyWith(color: context.t1)),
        const Spacer(),
        Pill(
          _loggedIn ? '已登录' : '未登录',
          color: _loggedIn ? C.success : C.warning,
          small: true,
        ),
      ],
    );
  }

  // ───────── 摘要态（已配置）─────────
  Widget _summary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('账号', _user.isEmpty ? '—' : _user),
        _row('密码', _hasPass ? '已保存●●●●●●' : '未设置'),
        if (_totalPages > 0) _row('可采集', '$_totalPages 页'),
        if (_lastLogin.isNotEmpty) _row('上次登录', _lastLogin),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SoftButton(
                label: '修改账号',
                icon: Icons.edit_outlined,
                height: 40,
                onPressed: _busy
                    ? null
                    : () {
                        _loadCfg();
                        setState(() {
                          _editing = true;
                          _passCtrl.clear();
                        });
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftButton(
                label: '解除登录',
                icon: Icons.logout_rounded,
                height: 40,
                color: C.danger,
                onPressed: _busy ? null : _logout,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(k, style: Ty.tiny.copyWith(color: context.t3)),
        ),
        Expanded(
          child: Text(
            v,
            style: Ty.small.copyWith(fontSize: 12.5, color: context.t1),
          ),
        ),
      ],
    ),
  );

  // ───────── 编辑态 ─────────
  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _hasPass
              ? '修改账号密码后点「保存并登录」。密码留空表示不修改。'
              : '填写采集平台的账号密码，保存后即可一键登录（含验证码自动识别），'
                    '不用再手工从浏览器复制 Cookie。',
          style: Ty.small.copyWith(color: context.t2, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _field(
                ctrl: _userCtrl,
                label: '账号',
                icon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                ctrl: _passCtrl,
                label: _hasPass ? '密码（留空不改）' : '密码',
                icon: Icons.lock_outline_rounded,
                obscure: !_showPass,
                suffix: IconButton(
                  icon: Icon(
                    _showPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: context.t3,
                  ),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_hasPass) ...[
              Expanded(
                child: SoftButton(
                  label: '取消',
                  height: 46,
                  onPressed: _busy
                      ? null
                      : () => setState(() => _editing = false),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: _loggedIn ? '保存并重新登录' : '保存并登录',
                icon: Icons.login_rounded,
                height: 46,
                loading: _busy,
                onPressed: _loginByPassword,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // ── Cookie 兜底 ──
        TextButton.icon(
          onPressed: () => setState(() => _showCookie = !_showCookie),
          icon: Icon(
            _showCookie ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 18,
          ),
          label: const Text('登录失败？改用浏览器 Cookie 方式'),
        ),
        if (_showCookie) ...[
          Text(
            '1. 在浏览器登录 app.125ks.cn\n'
            '2. F12 → Network → 任意请求 → 复制 Cookie\n'
            '3. 粘贴到下面（需含 PHPSESSID）',
            style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cookieCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'PHPSESSID=xxx; ol_token=xxx; ...',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(R.md),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SoftButton(
            label: '保存 Cookie 并验证',
            icon: Icons.check_circle_outline_rounded,
            height: 42,
            onPressed: _busy ? null : _saveCookie,
          ),
        ],
      ],
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md)),
      ),
    );
  }
}
