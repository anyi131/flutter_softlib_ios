import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/soft_service.dart';
import '../../api/user_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'widgets/auth_widgets.dart';

/// 注册页（v40 重构）
///
/// 逻辑优化：
///   · 填 QQ 号 → 自动预览 QQ 头像（qlogo 接口，稳定可用）
///   · 昵称智能默认：未填时用「QQ用户+尾号」/ 邮箱前缀，可自行修改
///   · 邮箱后缀快捷按钮（@qq.com / @163.com / @gmail.com）
///   · 注册成功 → pop 回传账号，登录页自动回填（需求 #5）
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _qq = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _nick = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();

  bool _obscure = true;
  final _invite = TextEditingController();
  bool _obscure2 = true;
  bool _loading = false;
  bool _sending = false;
  int _countdown = 0;
  Timer? _timer;

  /// 用户手动改过昵称后，不再用 QQ/邮箱自动覆盖
  bool _nickTouched = false;

  /// 后台允许的邮箱域名（空=不限）
  List<String> _allowDomains = const [];
  /// 是否允许非 QQ 邮箱注册
  bool _allowNonQq = false;

  /// 常用邮箱后缀（默认只给 QQ；后台开启「其他邮箱」后才给更多）
  List<String> get _emailSuffixes {
    if (_allowDomains.isNotEmpty) {
      return _allowDomains.map((d) => '@$d').toList();
    }
    if (!_allowNonQq) return const ['@qq.com'];
    return const [
      '@qq.com',
      '@163.com',
      '@126.com',
      '@gmail.com',
      '@outlook.com',
      '@foxmail.com',
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadEmailPolicy();
  }

  /// 读后台的邮箱域名白名单
  Future<void> _loadEmailPolicy() async {
    try {
      final cfg = await SoftService.instance.fetchConfig(force: true);
      final raw = cfg?.emailAllowDomains ?? '';
      if (!mounted) return;
      setState(() {
        _allowNonQq = cfg?.emailNonQqOn ?? false;
        _allowDomains = raw
            .split(RegExp(r'[,，\s]+'))
            .map((e) => e.trim().replaceAll('@', ''))
            .where((e) => e.isNotEmpty)
            .toList();
      });
    } catch (_) {}
  }

  String _errNick = '';
  String _errEmail = '';
  String _errCode = '';
  String _errPwd = '';
  String _errServer = '';

  @override
  void dispose() {
    _timer?.cancel();
    _qq.dispose();
    _email.dispose();
    _code.dispose();
    _nick.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    super.dispose();
  }

  /// QQ 头像地址（腾讯 qlogo，稳定）
  String get _qqAvatar {
    final q = _qq.text.trim();
    if (!RegExp(r'^\d{5,12}$').hasMatch(q)) return '';
    return 'https://q1.qlogo.cn/g?b=qq&nk=$q&s=640';
  }

  /// 根据 QQ / 邮箱生成建议昵称（仅在用户没手动改过时生效）
  void _autoNick() {
    if (_nickTouched) return;
    final q = _qq.text.trim();
    if (RegExp(r'^\d{5,12}$').hasMatch(q)) {
      // 用 QQ 尾号，避免重名又保留辨识度
      _nick.text = 'QQ用户${q.length >= 4 ? q.substring(q.length - 4) : q}';
      return;
    }
    final e = _email.text.trim();
    final at = e.indexOf('@');
    if (at > 0) _nick.text = e.substring(0, at);
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      setState(() => _errEmail = '请先填写正确的邮箱');
      return;
    }
    setState(() {
      _sending = true;
      _errEmail = '';
      _errServer = '';
    });
    try {
      await UserService.instance.sendCode(email, scene: 'register');
      if (!mounted) return;
      ToastUtil.success('验证码已发送，请查收邮箱');
      setState(() => _countdown = 60);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _countdown--);
        if (_countdown <= 0) t.cancel();
      });
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _errServer = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _register() async {
    final qq = _qq.text.trim();
    final email = _email.text.trim();
    final code = _code.text.trim();
    final nick = _nick.text.trim();
    final pwd = _pwd.text;

    setState(() {
      _errEmail = '';
      _errCode = '';
      _errPwd = '';
      _errServer = '';
      if (email.isEmpty || !email.contains('@')) _errEmail = '请输入正确的邮箱';
      if (code.isEmpty) _errCode = '请输入验证码';
      if (pwd.length < 6) _errPwd = '密码至少 6 位';
      else if (pwd != _pwd2.text) _errPwd = '两次输入的密码不一致';
    });
    if (_errEmail.isNotEmpty ||
        _errCode.isNotEmpty ||
        _errPwd.isNotEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      await UserService.instance.register(
        email: email,
        code: code,
        password: pwd,
        nickname: nick,
        qq: qq,
        invite: _invite.text.trim(),
      );
      if (!mounted) return;
      ToastUtil.success('注册成功，请登录');
      // ★ 回传账号给登录页，自动填充（需求 #5）
      Navigator.of(context).pop(email);
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _errServer = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _qqAvatar;
    return AuthScaffold(
      title: '创建账号',
      subtitle: '填写邮箱即可注册，QQ 号可选（用于获取头像）',
      icon: Icons.person_add_alt_1_rounded,
      children: [
        AuthCard(
          children: [
            // ── QQ 号 + 头像预览 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AuthField(
                    controller: _qq,
                    label: 'QQ 号（选填）',
                    hint: '填写后自动获取 QQ 头像',
                    icon: Icons.pets_rounded,
                    keyboard: TextInputType.number,
                    maxLength: 12,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {
                      setState(() {});
                      _autoNick();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: avatar.isEmpty
                          ? Container(
                              color: context.isDark
                                  ? Colors.white.withAlpha(12)
                                  : Colors.black.withAlpha(6),
                              child: Icon(Icons.person_outline_rounded,
                                  color: context.t3, size: 24),
                            )
                          : CachedNetworkImage(
                              imageUrl: avatar,
                              fit: BoxFit.cover,
                              memCacheWidth: 160,
                              placeholder: (_, __) => Container(
                                  color: Colors.black12,
                                  child: const Center(
                                      child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)))),
                              errorWidget: (_, __, ___) => Container(
                                color: context.isDark
                                    ? Colors.white.withAlpha(12)
                                    : Colors.black.withAlpha(6),
                                child: Icon(Icons.person_outline_rounded,
                                    color: context.t3, size: 24),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (avatar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('已自动获取 QQ 头像，注册后即为账号头像',
                    style: Ty.tiny.copyWith(color: C.mint)),
              ),

            // ── 邮箱 ──
            AuthField(
              controller: _email,
              label: '邮箱',
              hint: '用于接收验证码',
              icon: Icons.mail_outline_rounded,
              keyboard: TextInputType.emailAddress,
              error: _errEmail.isEmpty ? null : _errEmail,
              onChanged: (_) {
                if (_errEmail.isNotEmpty) setState(() => _errEmail = '');
                _autoNick();
              },
            ),
            // 邮箱后缀快捷（★ 需求 #1/#2：不再只给 QQ 邮箱）
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _emailSuffixes
                  .map((s) => GestureDetector(
                        onTap: () {
                          final cur = _email.text;
                          final at = cur.indexOf('@');
                          _email.text =
                              (at > 0 ? cur.substring(0, at) : cur) + s;
                          setState(() {});
                          _autoNick();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: C.brand.withAlpha(context.isDark ? 30 : 20),
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: C.brand,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ))
                  .toList(),
            ),
            // ★ 需求 #3：未开其他邮箱时明确提醒「目前仅支持 QQ 邮箱」
            if (!_allowNonQq && _allowDomains.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: C.warning.withAlpha(context.isDark ? 34 : 20),
                    borderRadius: BorderRadius.circular(R.md),
                    border: Border.all(
                        color: C.warning.withAlpha(90), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: C.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '目前仅支持 QQ 邮箱注册（@qq.com）\n'
                          '其他邮箱可在后台「注册与界面风格」中开启',
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: C.warning,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '本站仅支持这些邮箱：${_allowDomains.map((e) => '@$e').join('、')}',
                    style: Ty.tiny.copyWith(color: C.warning)),
              ),
            const SizedBox(height: 14),

            // ── 验证码 ──
            AuthField(
              controller: _code,
              label: '邮箱验证码',
              icon: Icons.verified_outlined,
              keyboard: TextInputType.number,
              maxLength: 6,
              error: _errCode.isEmpty ? null : _errCode,
              suffix: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: _countdown > 0 ? null : _sendCode,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(
                          _countdown > 0 ? '${_countdown}s' : '获取验证码',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            ),

            // ── 昵称 ──
            AuthField(
              controller: _nick,
              label: '昵称',
              hint: '可自定义，留空自动生成',
              icon: Icons.badge_outlined,
              error: _errNick.isEmpty ? null : _errNick,
              onChanged: (v) {
                _nickTouched = v.trim().isNotEmpty;
                if (_errNick.isNotEmpty) setState(() => _errNick = '');
              },
            ),

            // ── 密码 ──
            AuthField(
              controller: _pwd,
              label: '密码',
              hint: '至少 6 位',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              error: _errPwd.isEmpty ? null : _errPwd,
            ),
            AuthField(
              controller: _pwd2,
              label: '确认密码',
              icon: Icons.lock_person_outlined,
              obscure: _obscure2,
              onToggleObscure: () =>
                  setState(() => _obscure2 = !_obscure2),
              action: TextInputAction.next,
            ),
            // v52q：邀请码（选填，双方得积分）
            AuthField(
              controller: _invite,
              label: '邀请码（选填）',
              hint: '填写好友邀请码，双方各得积分',
              icon: Icons.card_giftcard_rounded,
              action: TextInputAction.done,
              onSubmitted: _register,
            ),

            AuthError(message: _errServer),
            AuthButton(
              label: '注 册',
              loading: _loading,
              onPressed: _register,
            ),
            const SizedBox(height: 10),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('已有账号？', style: Ty.small.copyWith(color: context.t3)),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
