import 'dart:async';
import '../../utils/err_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/user_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'widgets/auth_widgets.dart';

/// 找回密码（v40 重构）
///
/// 流程：邮箱 → 验证码 → 新密码，三步在同一页完成，视觉与登录/注册统一
class ResetPage extends StatefulWidget {
  const ResetPage({super.key});

  @override
  State<ResetPage> createState() => _ResetPageState();
}

class _ResetPageState extends State<ResetPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();

  bool _obscure = true;
  bool _obscure2 = true;
  bool _loading = false;
  bool _sending = false;
  int _countdown = 0;
  Timer? _timer;

  String _errEmail = '';
  String _errCode = '';
  String _errPwd = '';
  String _errServer = '';

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    super.dispose();
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
      await UserService.instance.sendCode(email, scene: 'reset');
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
          () => _errServer = ErrText.of(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    final code = _code.text.trim();
    final pwd = _pwd.text;

    setState(() {
      _errEmail = '';
      _errCode = '';
      _errPwd = '';
      _errServer = '';
      if (email.isEmpty || !email.contains('@')) _errEmail = '请输入注册邮箱';
      if (code.isEmpty) _errCode = '请输入验证码';
      if (pwd.length < 6) _errPwd = '密码至少 6 位';
      else if (pwd != _pwd2.text) _errPwd = '两次输入的密码不一致';
    });
    if (_errEmail.isNotEmpty || _errCode.isNotEmpty || _errPwd.isNotEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      await UserService.instance
          .resetPassword(email: email, code: code, password: pwd);
      if (!mounted) return;
      ToastUtil.success('密码重置成功，请用新密码登录');
      // 回传账号，登录页自动填充（与注册页一致）
      Navigator.of(context).pop(email);
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _errServer = ErrText.of(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: '找回密码',
      subtitle: '通过注册邮箱验证后设置新密码',
      icon: Icons.lock_reset_rounded,
      children: [
        AuthCard(
          children: [
            AuthField(
              controller: _email,
              label: '注册邮箱',
              hint: '请输入注册时使用的邮箱',
              icon: Icons.mail_outline_rounded,
              keyboard: TextInputType.emailAddress,
              error: _errEmail.isEmpty ? null : _errEmail,
              onChanged: (_) {
                if (_errEmail.isNotEmpty) setState(() => _errEmail = '');
              },
            ),
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
            AuthField(
              controller: _pwd,
              label: '新密码',
              hint: '至少 6 位',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              error: _errPwd.isEmpty ? null : _errPwd,
            ),
            AuthField(
              controller: _pwd2,
              label: '确认新密码',
              icon: Icons.lock_person_outlined,
              obscure: _obscure2,
              onToggleObscure: () => setState(() => _obscure2 = !_obscure2),
              action: TextInputAction.done,
              onSubmitted: _reset,
            ),
            AuthError(message: _errServer),
            AuthButton(
              label: '重置密码',
              loading: _loading,
              onPressed: _reset,
            ),
            const SizedBox(height: 10),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('重置成功后将自动返回登录页',
              style: Ty.tiny.copyWith(color: context.t3)),
        ),
      ],
    );
  }
}
