import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/qq_login.dart';
import '../../api/soft_service.dart';

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

  /// 进页面时拉到的配置（appId 等），点击登录时直接复用，省一次往返
  Map<String, dynamic>? _qqCfg;

  /// ★ 1016：点下去立刻有反馈（原来点完界面毫无反应，等 QQ 冷启动像卡死）
  bool _qqLoading = false;
  /// 阶段文案：正在唤起 QQ… / 正在登录…
  String _qqStage = '正在唤起 QQ…';

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
      // ★ 1016：进页面时就拉一次配置并留用 —— 原来点「QQ 登录」时又拉了一遍，
      //   白白多等一个网络往返（体感就是「点了半天没反应」）。
      _qqCfg = r;
      final on = r['qq_login_on'] == true || r['qq_login_on'] == 1;
      final aid = '${r['qq_app_id'] ?? ''}';
      if (on && aid.isNotEmpty) {
        // ★ 1016：进页面就**预热**原生 SDK（建 Tencent 实例 + 声明授权），
        //   点登录时直接 login()，省掉初始化那段时间。不 await，别拖慢进页面。
        QQLogin.appId = aid;
        QQLogin.preheat();
      }
      setState(() => _qqOn = on);
    } catch (_) {}
  }

  /// ★ 1016：登录成功后同步刷新「我的」页 —— 原来只有密码登录做了这件事，
  ///   QQ 登录不做 → 明明登录成功，「我的」还是未登录的样子。
  Future<void> _notifyMine() async {
    try {
      final mine = Get.find<MineLogic>(tag: 'mine');
      await mine.load();
    } catch (_) {}
  }

  Future<void> _qqLogin() async {
    // ★★★ 1015：优先 QQ 原生 SDK（直接调起 QQ App 一键登录）
    // ★★ 1016：① 点下去立刻给反馈  ② 进页面已预热 SDK  ③ 不再多拉一次配置
    if (_qqLoading) return;
    final cfg = _qqCfg ?? await UserService.instance.fetchConfig();
    _qqCfg = cfg;
    final appId = '${cfg['qq_app_id'] ?? ''}';
    if (appId.isEmpty) {
      ToastUtil.error('QQ 登录未配置（后台缺少 AppID）');
      return;
    }
    QQLogin.appId = appId;
    if (mounted) {
      setState(() {
        _qqLoading = true;
        _qqStage = '正在唤起 QQ…';
      });
    }

    // ★ 1016 真机计时：分阶段耗时，上报服务器（用于定位「为什么不够快」）
    final sw = Stopwatch()..start();
    String err = '';
    try {
      final r = await QQLogin.login();
      final msNative = sw.elapsedMilliseconds; // 点击 → 授权回调
      if (r == null) {
        _reportQqTime('取消/失败 | 点击→回调=${msNative}ms');
        ToastUtil.info('已取消 QQ 登录');
        return;
      }
      final uiMs = r.uiMs;   // 原生测得的「拉起QQ→用户确认→回调」全程
      final initMs = r.initMs; // 原生初始化耗时
      // 授权已回来，接下来是服务端换 token —— 转圈不停，只换文案
      if (mounted) setState(() => _qqStage = '正在登录…');

      final beforeAuth = sw.elapsedMilliseconds;
      final res = await UserService.instance.qqAuthBySdk(
        openid: r.openid,
        accessToken: r.accessToken,
      );
      final msServer = sw.elapsedMilliseconds - beforeAuth; // 服务端换 token

      // ★ 1016：这个 QQ 还没有绑定账号 —— 不再自动建号，引导去注册
      //   （带着 openid/token 过去，注册成功即完成绑定，下次直接一键登录）
      if ('${res['need_register'] ?? ''}' == '1') {
        QQLogin.pendingOpenid = r.openid;
        QQLogin.pendingAccessToken = r.accessToken;
        ToastUtil.info('这个 QQ 还没绑定账号，请先注册（会自动绑定）');
        if (!mounted) return;
        await Get.toNamed(Routes.register);
        await _notifyMine();
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

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
      await _notifyMine();
      // ★ 1016：把真机各阶段耗时上报服务器（后台直接可读）
      final total = sw.elapsedMilliseconds;
      _reportQqTime(
        '成功 | 点击→回调=${msNative}ms（原生初始化=${initMs}ms '
        '授权页全程=${uiMs}ms）| 服务端换token=${msServer}ms '
        '| 其余=${total - msNative - msServer}ms | 总计=${total}ms',
      );
      if (!mounted) return;
      ToastUtil.success('QQ 登录成功');
      Navigator.of(context).pop(true);
      return;
    } catch (e) {
      err = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted && _qqLoading) setState(() => _qqLoading = false);
    }

    // ── 原生不可用 → App 内网页授权兜底（不丢去系统浏览器）──
    try {
      SoftService.reportLogStatic(
        tag: 'qq',
        error: '[qq-native] $err',
      ).catchError((_) {});
    } catch (_) {}
    ToastUtil.info('原生登录不可用（$err），改用网页授权');

    final res = await Get.to(() => const QQLoginPage());
    if (res is Map && (res['token'] ?? '').toString().isNotEmpty) {
      await UserService.instance.loginByToken(
        res['token'].toString(),
        nickname: (res['nickname'] ?? '').toString(),
        avatar: (res['avatar'] ?? '').toString(),
      );
      await _notifyMine();
      if (!mounted) return;
      ToastUtil.success('QQ 登录成功');
      Navigator.of(context).pop(true);
    }
  }

  /// ★ 1016：把 QQ 登录各阶段耗时上报服务器（我在后台直接读真机数据）
  void _reportQqTime(String detail) {
    try {
      SoftService.reportLogStatic(
        tag: 'qq-time',
        error: '[qq-time] $detail',
      ).catchError((_) {});
    } catch (_) {}
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
                child: Text(
                  '忘记密码？',
                  style: TextStyle(fontSize: 13, color: context.t3),
                ),
              ),
            ),
            AuthError(message: _errServer),
            AuthButton(label: '登 录', loading: _loading, onPressed: _login),
            const SizedBox(height: 10),
          ],
        ),
        const SizedBox(height: 20),
        if (_qqOn) ...[
          Row(
            children: [
              Expanded(
                child: Divider(color: context.t3.withAlpha(50), height: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '其他方式登录',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
              ),
              Expanded(
                child: Divider(color: context.t3.withAlpha(50), height: 1),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  // ★ 1016：点击后立即给反馈（转圈 + 文案变化），
                  //   避免「点了没反应，等 QQ 冷启动」的假死感
                  onTap: _qqLoading ? null : _qqLogin,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12B7F5).withAlpha(26),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF12B7F5).withAlpha(90),
                        width: 1.2,
                      ),
                    ),
                    child: _qqLoading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF12B7F5),
                            ),
                          )
                        : const Icon(
                            Icons.pets_rounded,
                            color: Color(0xFF12B7F5),
                            size: 26,
                          ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _qqLoading ? _qqStage : 'QQ 快捷登录',
                  style: Ty.tiny.copyWith(
                    color: _qqLoading ? const Color(0xFF12B7F5) : context.t3,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('还没有账号？', style: Ty.small.copyWith(color: context.t3)),
            TextButton(
              onPressed: () async {
                // 注册成功会带回账号，自动回填到输入框
                final acc = await Get.toNamed(Routes.register);
                if (!mounted) return;
                // ★ 1016：注册接口本身就会下发 token（等于已登录），
                //   这时不该再让用户「输入密码登录」，直接关掉登录页回去。
                if (UserService.instance.isLoggedIn) {
                  await _notifyMine();
                  if (!mounted) return;
                  Navigator.of(context).pop(true);
                  return;
                }
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
          child: Text(
            '注册即表示同意《用户协议》与《隐私政策》',
            style: Ty.tiny.copyWith(fontSize: 11, color: context.t3),
          ),
        ),
      ],
    );
  }
}
