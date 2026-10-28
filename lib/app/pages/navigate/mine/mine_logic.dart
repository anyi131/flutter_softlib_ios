import 'dart:convert';

import '../../../utils/sound_util.dart';
import '../../../utils/app_action.dart';
import '../../../utils/err_text.dart';

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../api/api_host.dart';
import '../../../design/kit.dart';
import '../../../design/theme_controller.dart';
import '../../../design/theme_palette.dart';
import '../../../design/app_style.dart';
import '../../../design/app_style_controller.dart';
import '../../../design/ui.dart';
import '../../../api/soft_service.dart';
import '../../../api/post_service.dart';
import '../../../api/message_service.dart';
import '../../../api/user_service.dart';
import '../../../api/qq_login.dart';
import '../../../utils/jump_util.dart';
import '../../../utils/local_splash.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/toast_util.dart';
import '../../../widgets/blocking_dialog.dart';

/// 我的页逻辑：登录态 + 本地资料
class MineLogic extends GetxController {
  static const _kSignDate = 'mine_sign_date';

  final UserService _userService = UserService.instance;

  String nickname = '';
  String uid = '';
  int points = 0;
  String money = '0.00';
  String vipExpire = '';
  String avatarUrl = '';
  bool isVipMember = false;
  String signedDate = '';

  int messageCount = 0;
  int followCount = 0;
  int fansCount = 0;

  @override
  void onInit() {
    super.onInit();
    load();
    // v52f #6：监听全局登录失效信号，立即刷新本页（回到未登录 UI）
    ever(_userService.expiredTick, (_) {
      nickname = '';
      avatarUrl = '';
      vipExpire = '';
      isVipMember = false;
      signedDate = '';
      update();
    });
  }

  /// ★ 1016：绑定 QQ 到当前账号 —— 以后 QQ 一键登录直接进这个号，
  ///   不会再被自动开一个新号。
  /// ★ 1020：QQ 是否已绑定（我的页显示状态 + 决定是「绑定」还是「解绑」）
  bool qqBound = false;

  Future<void> refreshQqBound() async {
    if (!_userService.isLoggedIn) {
      if (qqBound) {
        qqBound = false;
        update();
      }
      return;
    }
    final b = await _userService.qqBound();
    if (b != qqBound) {
      qqBound = b;
      update();
    }
  }

  /// ★ 1020：解绑 QQ（绑错了能自救）
  Future<void> unbindQQ() async {
    final ok = await Get.dialog<bool>(
      AppDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('解绑 QQ', style: TextStyle(fontSize: 16)),
        content: const Text(
          '解绑后，QQ 一键登录将不再进入当前账号。\n'
          '你的账号、积分、会员权益都不受影响。\n\n确定解绑吗？',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('解绑', style: TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await AppAction.act(
      () => _userService.unbindQQ(),
      loading: '正在解绑…',
      success: '已解绑 QQ',
    );
    if (done) {
      qqBound = false;
      update();
    }
  }

  /// ★ 1020（反馈 #2）：加锁 —— 等待期间重复点击直接忽略。
  ///   之前重复点击会并发发起多次 QQ 登录，原生回调错乱 → 用户说的「未知问题」。
  bool _binding = false;

  Future<void> bindQQ({bool sync = false}) async {
    if (!_userService.isLoggedIn) {
      ToastUtil.info('请先登录你自己的账号，再绑定 QQ');
      return;
    }
    if (_binding || BlockingDialog.isOpen) return;
    _binding = true;
    // ★★ 1020 修复「点击后没有任何加载动画」：
    //   原来先 await fetchConfig() 才弹加载层 —— 网络慢时用户点了像没反应，
    //   于是反复点、以为坏了。现在**先弹反馈，再做请求**。
    BlockingDialog.show(text: '正在准备 QQ 授权…', sub: '请稍候');
    try {
      final cfg = await UserService.instance.fetchConfig();
      final appId = '${cfg['qq_app_id'] ?? ''}';
      if (appId.isEmpty) {
        BlockingDialog.hide();
        ToastUtil.error('后台还没配置 QQ 互联 AppID');
        return;
      }
      QQLogin.appId = appId;
      // ★ 全屏阻塞：等 QQ 授权期间不允许返回/切页，避免回调打到已销毁的页面
      BlockingDialog.show(text: '正在打开 QQ 授权…', sub: '授权完成会自动回到 App，请不要离开本页面');
      final r = await QQLogin.login();
      BlockingDialog.hide();
      if (r == null) return; // 用户取消
      if (!isClosed) {
        BlockingDialog.show(text: '正在绑定…');
      }
      try {
        await _userService.bindQQ(openid: r.openid, accessToken: r.accessToken);
        // ★ 1028：点「同步资料」时真的去拉 QQ 昵称/头像（服务器 bind 不改昵称）
        if (sync) {
          final fix = await _userService.refreshQQProfile(auth: r);
          if (fix != null) {
            final n = fix['nickname'] ?? '';
            if (n.isNotEmpty) nickname = n;
            final f = fix['avatar'] ?? '';
            if (f.isNotEmpty) avatarUrl = f;
          }
        }
      } finally {
        BlockingDialog.hide();
      }
      // 页面已销毁（用户在等待时被路由带走）→ 只刷新数据，不弹提示
      if (isClosed) return;
      qqBound = true;
      ToastUtil.success(
        sync ? '已同步 QQ 昵称和头像' : '绑定成功，以后 QQ 一键登录直接进本账号',
      );
      await load();
    } catch (e) {
      BlockingDialog.hide();
      if (isClosed) return;
      ToastUtil.error(ErrText.of(e));
    } finally {
      BlockingDialog.hide();
      _binding = false;
    }
  }

  bool get isLoggedIn => _userService.isLoggedIn;
  bool get isAdmin => _userService.user?.isAdmin == true;
  UserInfo? get account => _userService.user;

  bool get isVip {
    if (isVipMember) return true;
    if (vipExpire.isEmpty) return false;
    final d = DateTime.tryParse(vipExpire.replaceAll(' ', 'T'));
    return d != null && d.isAfter(DateTime.now());
  }

  bool get signedToday => signedDate == _today();

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> load() async {
    await _userService.restore();
    if (_userService.isLoggedIn) {
      // ★ 1015 优化：原来 refreshProfile → SharedPreferences → unread 三个
      //   await 串行执行，每次进「我的」都要排队等 3 个往返（体感就是「卡一下」）。
      //   现在并发发起，总耗时 = 最慢那个，而不是三个相加。
      final results = await Future.wait<dynamic>([
        _userService.refreshProfile(),
        SharedPreferences.getInstance(),
        MessageService.instance.unread(),
      ]);
      var info = results[0] as dynamic;
      final sp = results[1] as SharedPreferences;
      final unreadN = results[2] as int;
      // ★ 1016：刚登录（QQ 快捷登录/注册回跳）时，refreshProfile 偶发拿不到
      //   用户资料（token 刚签发、服务端缓存未就绪）→ 会走到「清空为游客」，
      //   表现为「登录成功但我的页还是未登录，需要手动下拉」。
      //   这里补一次重试，仍失败再清空。
      if (info == null && _userService.isLoggedIn) {
        await Future.delayed(const Duration(milliseconds: 400));
        try {
          info = await _userService.refreshProfile();
        } catch (_) {}
      }
      final u = (info ?? _userService.user) as dynamic;
      if (u != null) {
        nickname = u.nickname;
        uid = u.account.isEmpty ? u.id.toString() : u.account;
        points = u.score;
        money = u.money;
        vipExpire = u.isVip ? u.vipExpire : '';
        avatarUrl = u.avatar;
        isVipMember = u.isVip;
        signedDate = sp.getString(_kSignDate) ?? '';
        // ★ 以服务端为准：换设备/重装后签到状态不漂移（服务端未返回时回退本地缓存）
        if (u.signedToday != null) {
          signedDate = u.signedToday! ? _today() : '';
          await sp.setString(_kSignDate, signedDate);
        }
        // 未读消息数（「消息」格子红点）
        messageCount = unreadN;
        // ★ 1028：老账号仍是自动昵称（QQ用户1234）→ 用本地缓存的 QQ 授权静默补一次，
        //   不弹授权框、不改用户自己起过的昵称。没有缓存时立即返回，开销可忽略。
        if (nickname.isEmpty || RegExp(r'^QQ用户\d+$').hasMatch(nickname)) {
          final fix = await _userService.refreshQQProfile();
          if (fix != null) {
            final n = fix['nickname'] ?? '';
            if (n.isNotEmpty) nickname = n;
            final f = fix['avatar'] ?? '';
            if (f.isNotEmpty) avatarUrl = f;
          }
        }
        update();
        // ★ 1020：顺带查一下 QQ 绑定状态（决定显示「绑定」还是「解绑」）
        refreshQqBound();
        return;
      }
    }
    // ★ 1020（反馈 #2）：只有「确实没登录」才清空为游客。
    //   绑定 QQ / 刷新资料时若网络抖动导致 refreshProfile 返回 null，
    //   之前会把已登录账号清成游客 → 用户看到「绑定完变回未登录」的未知问题。
    if (!_userService.isLoggedIn) {
      _clearToGuest();
    }
    update();
  }

  /// 重置为游客状态（不展示任何伪造数据）
  void _clearToGuest() {
    nickname = '';
    uid = '';
    points = 0;
    money = '0.00';
    vipExpire = '';
    avatarUrl = '';
    isVipMember = false;
    signedDate = '';
    followCount = 0;
    fansCount = 0;
    messageCount = 0;
  }

  /// 轻提示（用 SnackBar，避免 iOS 底部弹窗遮挡按钮）
  void toast(String msg) {
    ToastUtil.info(msg);
  }

  /// 打开消息中心
  ///
  /// ★ 修复「有时候点不进去」：
  ///   以前是 `await Get.toNamed(...)` 后再 `await unread()`，
  ///   跳转被网络请求阻塞；快速连点还会重复入栈。
  ///   改为：跳转不阻塞 + 未读数后台刷新。
  bool _msgOpening = false;
  Future<void> openMessages() async {
    if (!isLoggedIn) return openLogin();
    if (_msgOpening) return; // 防连点
    _msgOpening = true;
    try {
      Get.toNamed(Routes.message);
    } finally {
      // 短暂节流，避免同一瞬间重复打开
      Future.delayed(const Duration(milliseconds: 600), () {
        _msgOpening = false;
      });
    }
    // 未读数后台刷新，不阻塞界面
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    try {
      final n = await MessageService.instance.unread();
      if (n != messageCount) {
        // ★ 1028：来消息音效 —— 只在「原本就有未读、又变多」时响，
        //   首次进入不响（否则每次打开我的页都叮一声）。开关由后台下发。
        if (messageCount > 0 && n > messageCount) {
          SoundUtil.playMessage();
        }
        messageCount = n;
        update();
      }
    } catch (_) {}
  }

  /// 充值余额 —— 打开会员中心（复用现有支付通道）
  Future<void> recharge() async {
    if (!isLoggedIn) return openLogin();
    Get.toNamed(Routes.recharge);
  }

  Future<void> openLogin() async {
    await Get.toNamed('/login');
    await load();
  }

  Future<void> openRegister() async {
    await Get.toNamed('/register');
    await load();
  }

  /// 编辑资料（昵称 + QQ，改 QQ 自动同步头像）
  Future<void> openProfileEdit() async {
    if (!isLoggedIn) return openLogin();
    final u = account;
    final nickCtrl = TextEditingController(text: u?.nickname ?? '');
    final qqCtrl = TextEditingController(text: u?.qq ?? '');
    final ok = await Get.dialog<bool>(
      AppDialog(
        title: const Text('编辑资料'),
        content: StatefulBuilder(
          builder: (ctx, setSt) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '修改 QQ 号会自动同步 QQ 头像',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nickCtrl,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: qqCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'QQ 号',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await AppAction.act(
      () => _userService.updateProfile({
        'nickname': nickCtrl.text.trim(),
        'qq': qqCtrl.text.trim(),
      }),
      loading: '保存中…',
      success: '资料已更新',
    );
    if (done) await load();
  }

  /// 退出登录
  Future<void> logout() async {
    final yes = await Get.dialog<bool>(
      AppDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await AppAction.act(
      () => _userService.logout(),
      loading: '正在退出…',
      success: '已退出登录',
    );
    _clearToGuest();
    update();
  }

  /// 签到 +5（后端落库，每天一次）
  Future<void> signIn() async {
    if (!isLoggedIn) return openLogin();
    if (signedToday) return toast('今天已经签到过啦');
    // ★ 1020：签到加 loading（原来点完没反应，网络慢时用户会连点）
    AppAction.showLoading('签到中…');
    try {
      final score = await _userService.signIn();
      signedDate = _today();
      points = score;
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kSignDate, signedDate);
      update();
      AppAction.hideLoading();
      SoundUtil.playSign(); // ★ 音效：签到成功
      ToastUtil.success('签到成功 +5 积分');
    } catch (e) {
      AppAction.hideLoading();
      toast(ErrText.of(e));
    }
  }

  /// 使用卡密
  Future<void> redeem() async {
    if (!isLoggedIn) return openLogin();
    final ctrl = TextEditingController();
    final code = await Get.dialog<String>(
      AppDialog(
        title: const Text('使用卡密'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入卡密',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          FilledButton(
            onPressed: () => Get.back(result: ctrl.text.trim()),
            child: const Text('兑换'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final msg = await _userService.redeem(code);
      await load();
      ToastUtil.success(msg);
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// 打开内嵌管理系统（App 内，不跳浏览器）
  void openAdminPanel() {
    Get.toNamed('/admin');
  }

  /// 加入 QQ 通知群
  /// 加入 QQ 通知群
  /// ★ 1014 修复：原实现只复制链接、不跳转（用户反馈「点击是链接已复制」）。
  ///   现在与首页一致：解析群号 → mqqapi 直达加群界面 → 失败兜底开网页。
  Future<void> joinGroup() async {
    final cached = SoftService.instance.cachedConfig;
    final groupUrl = cached?.feedbackGroup ?? '';
    if (groupUrl.isEmpty) {
      ToastUtil.error('暂未配置群链接');
      return;
    }
    // 1) 已是 QQ 协议 → 直接跳
    if (groupUrl.startsWith('mqqapi://') || groupUrl.startsWith('tencent://')) {
      JumpUtil.openUrl(groupUrl);
      return;
    }
    // 2) 本地解析群号；解析不到再问服务端（qm.qq.com 短链必须服务端抓页面）
    var code = _extractGroupCode(groupUrl);
    code ??= await SoftService.instance.resolveQqGroup(groupUrl);
    if (code != null && code.isNotEmpty) {
      final ok = await JumpUtil.joinQQGroup(code);
      if (ok) return;
    }
    // 3) 兜底 → 网页打开
    JumpUtil.openUrl(groupUrl);
  }

  /// 从 QQ 群分享链接里解析群号
  /// 支持 qun.qq.com/universal-share?...busi_data=base64(...) 与 ?gc=群号
  String? _extractGroupCode(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      // ?gc= 直接给群号
      final gc = uri.queryParameters['gc'];
      if (gc != null && gc.isNotEmpty) return gc;
      // ?groupCode=
      final gcode = uri.queryParameters['groupCode'];
      if (gcode != null && gcode.isNotEmpty) return gcode;
      // busi_data（base64 JSON 里含 groupCode）
      final busi = uri.queryParameters['busi_data'];
      if (busi != null && busi.isNotEmpty) {
        var s = busi.replaceAll('-', '+').replaceAll('_', '/');
        while (s.length % 4 != 0) {
          s += '=';
        }
        final decoded = utf8.decode(base64.decode(s));
        final m = RegExp(r'"groupCode"\s*:\s*"?(\d+)"?').firstMatch(decoded);
        if (m != null) return m.group(1);
      }
    } catch (_) {}
    return null;
  }

  void about(BuildContext context) {
    Get.toNamed(Routes.about);
  }

  void showAgreement(String title, String content) {
    Get.dialog(
      AppDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(height: 1.7)),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('我知道了')),
        ],
      ),
    );
  }

  /// 用户协议 / 隐私政策（独立美化页面，内容来自后台）
  Future<void> showAgreementPage(String type) async {
    Get.toNamed(Routes.agreement, arguments: {'type': type});
  }

  /// 赞助排行榜（v40 重做：头像 / 称号 / 名次 / 金额明细）
  Future<void> sponsorRank() async {
    // 打开前先请求一次，弹窗内显示加载态
    List<Map<String, dynamic>> list = [];
    bool loading = true;
    String err = '';
    try {
      list = await _userService.donateRank();
    } catch (e) {
      err = ErrText.of(e);
    }
    loading = false;

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: Get.height * 0.78),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B1D2B), Color(0xFF12131C)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 头部 ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3A2E10), Color(0xFF1B1D2B)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD54F), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withAlpha(90),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '赞助排行榜',
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '感谢每一位支持者 ❤',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white.withAlpha(180),
                      ),
                      onPressed: Get.back,
                    ),
                  ],
                ),
              ),
              // ── 内容 ──
              Flexible(
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        ),
                      )
                    : (err.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                err,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(170),
                                ),
                              ),
                            )
                          : (list.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.volunteer_activism_rounded,
                                          size: 40,
                                          color: Colors.white.withAlpha(80),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '还没有赞助记录',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withAlpha(160),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '欢迎成为第一位支持者',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withAlpha(110),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      12,
                                      14,
                                      16,
                                    ),
                                    itemCount: list.length,
                                    itemBuilder: (c, i) => _rankRow(list[i], i),
                                  ))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 排行榜单行：名次奖牌 + 头像 + 昵称/称号 + 金额
  Widget _rankRow(Map<String, dynamic> r, int i) {
    final rank = int.tryParse('${r['rank']}') ?? (i + 1);
    final nick = '${r['nickname'] ?? '匿名'}';
    final avatar = '${r['avatar'] ?? ''}';
    final amount = '${r['amount'] ?? '0'}';
    final vipAmt = '${r['vip_amount'] ?? '0'}';
    final reAmt = '${r['recharge_amount'] ?? '0'}';
    final title = '${r['title'] ?? ''}';
    final isAdmin = '${r['is_admin']}' == '1';
    final isVip = '${r['is_vip']}' == '1';

    // 前三名特殊徽章
    final bool top3 = rank <= 3;
    final List<Color> medalColors = rank == 1
        ? [const Color(0xFFFFD54F), const Color(0xFFF59E0B)]
        : rank == 2
        ? [const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)]
        : [const Color(0xFFD7A06A), const Color(0xFFB07B4F)];

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: top3 ? medalColors[1].withAlpha(26) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: top3
              ? medalColors[1].withAlpha(110)
              : Colors.white.withAlpha(18),
          width: top3 ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        children: [
          // 名次
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: top3
                ? BoxDecoration(
                    gradient: LinearGradient(colors: medalColors),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: medalColors[1].withAlpha(110),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  )
                : null,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: top3 ? 14 : 13,
                fontWeight: FontWeight.w900,
                color: top3 ? Colors.white : Colors.white.withAlpha(150),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 头像
          ClipOval(
            child: avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    memCacheWidth: 96,
                    placeholder: (_, __) => _rankAvatarFallback(nick),
                    errorWidget: (_, __, ___) => _rankAvatarFallback(nick),
                  )
                : _rankAvatarFallback(nick),
          ),
          const SizedBox(width: 10),
          // 昵称 + 称号
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nick,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (title.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: C.violet.withAlpha(60),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFFC9BEFF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (isAdmin) _miniTag('管理', const Color(0xFFEF4444)),
                    if (isVip) ...[
                      const SizedBox(width: 4),
                      _miniTag('会员', const Color(0xFFF59E0B)),
                    ],
                    if (title.isEmpty && !isAdmin && !isVip)
                      Text(
                        '赞助者',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withAlpha(110),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 金额
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥$amount',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD54F),
                ),
              ),
              if ((double.tryParse(vipAmt) ?? 0) > 0 ||
                  (double.tryParse(reAmt) ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    (double.tryParse(vipAmt) ?? 0) > 0
                        ? '会员 ¥$vipAmt'
                        : '充值 ¥$reAmt',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.white.withAlpha(120),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
    decoration: BoxDecoration(
      color: c.withAlpha(60),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      t,
      style: TextStyle(fontSize: 9.5, color: c, fontWeight: FontWeight.w800),
    ),
  );

  Widget _rankAvatarFallback(String nick) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [C.brand.withAlpha(180), C.violet.withAlpha(160)],
      ),
    ),
    child: Text(
      nick.isNotEmpty ? nick.characters.first : '?',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );

  /// 积分兑换（★ 主题自适应 + 信息更清楚）
  Future<void> pointsExchange() async {
    // v331k：未登录不再硬跳登录页（用户反馈「点积分乱返回」），先提示
    if (!isLoggedIn) {
      toast('登录后可查看和兑换积分');
      return openLogin();
    }
    List<Map<String, dynamic>> goodsList = [];
    try {
      goodsList = await _userService.exchangeGoods();
    } catch (_) {}
    if (goodsList.isEmpty) {
      toast('暂无可兑换的商品，稍后再来看看');
      return;
    }
    final goods = await Get.dialog<String>(
      AppDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.monetization_on_rounded,
              color: Color(0xFFFB923C),
              size: 21,
            ),
            SizedBox(width: 9),
            Text(
              '积分兑换',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Builder(
          builder: (ctx) {
            final dark = Theme.of(ctx).brightness == Brightness.dark;
            final sub = dark ? C.t3 : C.lt3;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前积分：大号醒目卡片，一眼看清
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB923C).withAlpha(dark ? 36 : 22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFB923C).withAlpha(70),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.savings_rounded, size: 16, color: sub),
                      const SizedBox(width: 6),
                      Text(
                        '当前积分',
                        style: TextStyle(fontSize: 12.5, color: sub),
                      ),
                      const Spacer(),
                      Text(
                        '$points',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFB923C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '签到、邀请好友都能获得积分',
                  style: TextStyle(fontSize: 11, color: sub),
                ),
                const SizedBox(height: 12),
                for (final g in goodsList)
                  _exchangeItem(
                    ctx,
                    '${g['key']}',
                    '${g['name']}',
                    int.tryParse('${g['cost']}') ?? 100,
                  ),
              ],
            );
          },
        ),
        actions: [TextButton(onPressed: Get.back, child: const Text('取消'))],
      ),
    );
    if (goods == null) return;
    try {
      final msg = await _userService.exchange(goods);
      await load();
      ToastUtil.success(msg);
    } catch (e) {
      toast(ErrText.of(e));
    }
  }

  /// 兑换项（主题自适应；积分不够时提示「还差 N 积分」）
  Widget _exchangeItem(BuildContext ctx, String goods, String label, int cost) {
    final enough = points >= cost;
    final dark = Theme.of(ctx).brightness == Brightness.dark;
    const warn = Color(0xFFFBBF24);
    final sub = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: enough ? () => Get.back(result: goods) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enough
                ? warn.withAlpha(dark ? 30 : 22)
                : (dark
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(6)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enough
                  ? warn.withAlpha(110)
                  : (dark
                        ? Colors.white.withAlpha(20)
                        : Colors.black.withAlpha(14)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                size: 18,
                color: enough ? warn : sub,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: enough ? null : sub,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                enough ? '$cost 积分' : '还差 ${cost - points} 积分',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: enough ? const Color(0xFFC9A227) : sub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 设置自定义称号（广场展示）
  Future<void> setCustomTitle() async {
    if (!isLoggedIn) return openLogin();
    final ctrl = TextEditingController(text: account?.title ?? '');
    final v = await Get.dialog<String>(
      AppDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '自定义称号',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              maxLength: 12,
              decoration: const InputDecoration(
                hintText: '如：技术大佬 / 热心网友',
                labelText: '称号',
              ),
            ),
            Text(
              '称号会显示在你的广场动态旁',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          FilledButton(
            onPressed: () => Get.back(result: ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (v == null) return;
    try {
      await _userService.setTitle(v);
      await load();
      ToastUtil.success(v.isEmpty ? '已清除称号' : '称号已更新');
    } catch (e) {
      toast(ErrText.of(e));
    }
  }

  /// 替换开屏（上传自定义开屏图）
  Future<void> replaceSplash() async {
    if (!isLoggedIn) return openLogin();
    final action = await Get.dialog<String>(
      AppDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '替换开屏',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Text(
          _userService.user?.splashImage.isNotEmpty == true
              ? '当前已设置自定义开屏图'
              : '未设置（使用默认开屏）',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          if (_userService.user?.splashImage.isNotEmpty == true)
            TextButton(
              onPressed: () => Get.back(result: 'reset'),
              child: const Text('恢复默认'),
            ),
          TextButton(onPressed: Get.back, child: const Text('取消')),
          FilledButton(
            onPressed: () => Get.back(result: 'upload'),
            child: const Text('选择图片'),
          ),
        ],
      ),
    );
    if (action == null) return;
    if (action == 'reset') {
      try {
        // ★ 同时清除本地自定义开屏图（否则本地优先还会显示旧图）
        await LocalSplash.clear();
        await _userService.saveSplash('');
        await load();
        ToastUtil.success('已恢复默认开屏');
      } catch (e) {
        ToastUtil.error(ErrText.of(e));
      }
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (picked == null) return;
      // ★ 先存本地（启动时优先用本地图，秒开且不依赖网络）——用户 #9 的要求
      final localPath = await LocalSplash.save(picked.path);
      if (localPath.isEmpty) {
        ToastUtil.error('本地保存失败，请检查存储权限');
      }
      // 再上传服务器（换机/重装后仍能恢复）
      try {
        final up = await PostService.instance.uploadImage(File(picked.path));
        await _userService.saveSplash(up);
      } catch (e) {
        // 上传失败也不影响本地生效
        debugPrint('开屏图上传失败: $e');
      }
      await load();
      ToastUtil.success('开屏图已更新，下次启动生效');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// ★ 1014 需求3：分享本软件（文案后台可配，没配则用关于信息兜底）
  Future<void> shareApp() async {
    try {
      final cfg =
          SoftService.instance.cachedConfig ??
          await SoftService.instance.fetchConfig();
      final name = (cfg?.shareTitle.isNotEmpty == true)
          ? cfg!.shareTitle
          : (cfg?.aboutName.isNotEmpty == true ? cfg!.aboutName : '安逸软件汇');
      final desc = (cfg?.shareDesc.isNotEmpty == true)
          ? cfg!.shareDesc
          : (cfg?.aboutSlogan ?? '优质软件 · 持续更新');
      final url = (cfg?.shareUrl.isNotEmpty == true)
          ? cfg!.shareUrl
          : (cfg?.aboutWebsite ?? '');
      final buf = StringBuffer()
        ..writeln('推荐一个好用的软件库：$name')
        ..writeln(desc);
      if (url.isNotEmpty) buf.writeln(url);
      // 带上我的邀请码（有登录时），好友注册双方都有积分
      final myCode = _userService.user?.inviteCode ?? '';
      if (myCode.isNotEmpty) buf.writeln('邀请码：$myCode');
      final text = buf.toString().trim();
      // 后台配了分享图就带着图分享（图下载失败自动退回纯文字）
      final img = (cfg?.shareImage ?? '').trim();
      if (img.isNotEmpty) {
        try {
          final target = File(
            '${Directory.systemTemp.path}/softlib_share_'
            '${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          final cli = HttpClient();
          final resp = await (await cli.getUrl(Uri.parse(img))).close();
          final bytes = await resp.fold<List<int>>(
            <int>[],
            (a, b) => a..addAll(b),
          );
          cli.close();
          if (bytes.isNotEmpty) {
            await target.writeAsBytes(bytes, flush: true);
            await Share.shareXFiles(
              [XFile(target.path)],
              text: text,
              subject: name,
            );
            return;
          }
        } catch (_) {
          // 忽略，走下面的纯文字分享
        }
      }
      await Share.share(text, subject: name);
    } catch (e) {
      ToastUtil.error('分享失败：${ErrText.of(e)}');
    }
  }
}
