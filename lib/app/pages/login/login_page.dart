import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../api/api_host.dart';
import '../../api/qq_login.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../routes/app_pages.dart';
import '../../utils/toast_util.dart';
import '../../api/user_service.dart';
import '../navigate/mine/mine_logic.dart';
import 'qq_login_page.dart';
import 'widgets/auth_widgets.dart';

/// 登录页（v40 重构）
///
/// 视觉：光晕背景 + 玻璃卡片 + 大圆角输入框（与全站设计语言一致）
/// 逻辑优化：
///   · 注册成功后自动回填账号并聚焦密码框（由 RegisterPage pop 结果回传）
///   · 字段级内联错误，不用遮挡式弹窗
///   · 登录成功后通知「我的」页刷新
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _account = TextEditingController();
  final _pwd = TextEditingController();
  final _pwdFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;
  bool _qqOn = false;

  String _errAccount = '';
  String _errServer = '';

  @override
  void initState() {
    super.initState();
    _checkQq();
    // ★ 注册成功后回填账号（需求 #5：省去自己输入）
    final args = Get.arguments;
    if (args is Map && (args['account'] ?? '').toString().isNotEmpty) {
      _account.text = args['account'].toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ToastUtil.success('注册成功，请输入密码登录');
        _pwdFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _account.dispose();
    _pwd.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  Future<void> _checkQq() async {
    try {
      final r = await UserService.instance.fetchConfig();
      if (!mounted) return;
      setState(() => _qqOn = r['qq_login_on'] == true || r['qq_login_on'] == 1);
    } catch (_) {}
  }

  Future<void> _qqLogin() async {
    // ★★★ 1015：改为**优先使用 QQ 原生 SDK**（直接调起 QQ App 一键登录）。
    //   原来只能走 WebView —— 但 QQ 授权页在第三方 WebView 里检测不到 QQ App，
    //   会提示「请安装 QQ 手机版」并卡在「正在拉起QQ手机版…」，根本登录不了。
    try {
      // 取 AppID（服务端下发）
      final cfg = await UserService.instance.fetchConfig();
      final appId = '${cfg['qq_app_id'] ?? ''}';
      if (appId.isEmpty) {
        ToastUtil.error('QQ 登录未配置（后台缺少 AppID）');
        return;
      }
      QQLogin.appId = appId;

      // ★★★ 1015 修复：不再「先探测再登录」。
      //   原来先调 isQQInstalled()，但 Android 11+ 包可见性限制下
      //   这个方法可能误报 false → 直接回退 WebView → 用户看到「网页无法打开」。
      //   正确做法：直接调原生登录，SDK 自己会判断并抛明确异常。
      final r = await QQLogin.login();
      if (r == null) {
        ToastUtil.info('已取消 QQ 登录');
        return;
      }

      // 把 openid + access_token 交给服务端换本站 token
      final res = await UserService.instance.qqAuthBySdk(
        openid: r.openid,
        accessToken: r.accessToken,
      );
      final token = '${res['token'] ?? ''}';
      if (token.isEmpty) {
        ToastUtil.error('QQ 登录失败：${res['msg'] ?? '服务端未返回 token'}');
        return;
      }
      await UserService.instance.loginByToken(
        token,
        nickname: '${res['nickname'] ?? ''}',
        avatar: '${res['avatar'] ?? ''}',
      );
      if (!mounted) return;
      ToastUtil.success('QQ 登录成功');
      Navigator.of(context).pop(true);
    } catch (e) {
      // ★ 1015：原生失败 → 改用**系统浏览器**打开授权页。
      //   原来回退到 App 内 WebView，但 QQ 授权页会跳 wtloginmqq:// 私有协议，
      //   WebView 打不开（ERR_UNKNOWN_URL_SCHEME）→ 用户看到「网页无法打开」。
      //   系统浏览器能正确处理这个跳转（能拉起 QQ App 或给可用的登录页）。
      final msg = e.toString().replaceFirst('Exception: ', '');
      final authUrl =
          '${ApiHost.base}/api/softlib/user/qq_authorize';
      ToastUtil.info('原生登录不可用（$msg），已改用浏览器登录');

      try {
        // 用外部浏览器打开（能正确响应 wtloginmqq:// 协议）
        await launchUrlString(
          authUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        // 提示用户在浏览器里完成授权后回到 App
        ToastUtil.info('请在浏览器中完成 QQ 授权，完成后回到 App 刷新');
      } catch (_) {
        // 浏览器也打不开 → 最后兜底用 App 内 WebView
        final res = await Get.to(() => const QQLoginPage());
        if (res is Map && (res['token'] ?? '').toString().isNotEmpty) {
          await UserService.instance.loginByToken(
            res['token'].toString(),
            nickname: (res['nickname'] ?? '').toString(),
            avatar: (res['avatar'] ?? '').toString(),
          );
          if (!mounted) return;
          ToastUtil.success('QQ 登录成功');
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  Future<void> _login() async {
    String account = _account.text.trim();
    final pwd = _pwd.text;
    setState(() {
      _errAccount = account.isEmpty ? '请输入邮箱、QQ号或用户名' : '';
      _errServer = '';
    });
    if (account.isEmpty || pwd.isEmpty) {
      if (pwd.isEmpty) _errServer = '请输入密码';
      return;
    }
    // ★ 需求 #2：省去自己输入 @qq.com
    //   纯数字（5-12位）当成 QQ 号 → 自动补全为 QQ 邮箱后登录
    if (RegExp(r'^\d{5,12}$').hasMatch(account)) {
      account = '$account@qq.com';
    }

    setState(() => _loading = true);
    try {
      await UserService.instance.login(account, pwd);
      if (!mounted) return;
      try {
        final mine = Get.find<MineLogic>(tag: 'mine');
        await mine.load();
      } catch (_) {}
      ToastUtil.success('登录成功');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errServer = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: '欢迎回来',
      subtitle: '登录后可下载资源、参与社区互动',
      icon: Icons.person_rounded,
      children: [
        AuthCard(
          children: [
            AuthField(
              controller: _account,
              label: '邮箱 / 用户名',
              hint: '请输入注册邮箱或用户名',
              icon: Icons.alternate_email_rounded,
              keyboard: TextInputType.emailAddress,
              action: TextInputAction.next,
              error: _errAccount.isEmpty ? null : _errAccount,
              onChanged: (_) {
                if (_errAccount.isNotEmpty) {
                  setState(() => _errAccount = '');
                }
              },
            ),
            AuthField(
              controller: _pwd,
              label: '密码',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              action: TextInputAction.done,
              onSubmitted: _login,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.toNamed(Routes.reset),
                child: Text('忘记密码？',
                    style: TextStyle(fontSize: 13, color: context.t3)),
              ),
            ),
            AuthError(message: _errServer),
            AuthButton(
              label: '登 录',
              loading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 10),
          ],
        ),
        const SizedBox(height: 20),
        if (_qqOn) ...[
          Row(
            children: [
              Expanded(
                  child: Divider(color: context.t3.withAlpha(50), height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('其他方式登录',
                    style: Ty.tiny.copyWith(color: context.t3)),
              ),
              Expanded(
                  child: Divider(color: context.t3.withAlpha(50), height: 1)),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _qqLogin,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12B7F5).withAlpha(26),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF12B7F5).withAlpha(90),
                          width: 1.2),
                    ),
                    child: const Icon(Icons.pets_rounded,
                        color: Color(0xFF12B7F5), size: 26),
                  ),
                ),
                const SizedBox(height: 7),
                Text('QQ 快捷登录',
                    style: Ty.tiny.copyWith(color: context.t3)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('还没有账号？',
                style: Ty.small.copyWith(color: context.t3)),
            TextButton(
              onPressed: () async {
                // 注册成功会带回账号，自动回填到输入框
                final acc = await Get.toNamed(Routes.register);
                if (acc is String && acc.isNotEmpty && mounted) {
                  setState(() => _account.text = acc);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _pwdFocus.requestFocus();
                  });
                }
              },
              child: const Text('立即注册'),
            ),
          ],
        ),
        Center(
          child: Text('注册即表示同意《用户协议》与《隐私政策》',
              style: Ty.tiny.copyWith(fontSize: 11, color: context.t3)),
        ),
      ],
    );
  }
}
