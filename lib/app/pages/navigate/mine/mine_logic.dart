import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
import '../../../utils/jump_util.dart';
import '../../../utils/local_splash.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/toast_util.dart';

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
      final info = await _userService.refreshProfile();
      final u = info ?? _userService.user;
      if (u != null) {
        nickname = u.nickname;
        uid = u.account.isEmpty ? u.id.toString() : u.account;
        points = u.score;
        money = u.money;
        vipExpire = u.isVip ? u.vipExpire : '';
        avatarUrl = u.avatar;
        isVipMember = u.isVip;
        final sp = await SharedPreferences.getInstance();
        signedDate = sp.getString(_kSignDate) ?? '';
        // ★ 以服务端为准：换设备/重装后签到状态不漂移（服务端未返回时回退本地缓存）
        if (u.signedToday != null) {
          signedDate = u.signedToday! ? _today() : '';
          await sp.setString(_kSignDate, signedDate);
        }
        // 未读消息数（「消息」格子红点）
        messageCount = await MessageService.instance.unread();
        update();
        return;
      }
    }
    _clearToGuest();
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
      AlertDialog(
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
    try {
      await _userService.updateProfile({
        'nickname': nickCtrl.text.trim(),
        'qq': qqCtrl.text.trim(),
      });
      await load();
      ToastUtil.success('资料已更新');
    } catch (e) {
      toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 退出登录
  Future<void> logout() async {
    final yes = await Get.dialog<bool>(
      AlertDialog(
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
    await _userService.logout();
    _clearToGuest();
    update();
    ToastUtil.success('已退出登录');
  }

  /// 签到 +5（后端落库，每天一次）
  Future<void> signIn() async {
    if (!isLoggedIn) return openLogin();
    if (signedToday) return toast('今天已经签到过啦');
    try {
      final score = await _userService.signIn();
      signedDate = _today();
      points = score;
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kSignDate, signedDate);
      update();
      ToastUtil.success('签到成功 +5 积分');
    } catch (e) {
      toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 使用卡密
  Future<void> redeem() async {
    if (!isLoggedIn) return openLogin();
    final ctrl = TextEditingController();
    final code = await Get.dialog<String>(
      AlertDialog(
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
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 打开内嵌管理系统（App 内，不跳浏览器）
  void openAdminPanel() {
    Get.toNamed('/admin');
  }

  /// 加入 QQ 通知群
  void joinGroup() {
    final url = _userService.user?.qq.isNotEmpty == true
        ? 'https://qun.qq.com/'
        : ApiHost.base;
    Clipboard.setData(ClipboardData(text: url));
    toast('链接已复制，可在浏览器打开');
  }

  void about(BuildContext context) {
    Get.toNamed(Routes.about);
  }

  void showAgreement(String title, String content) {
    Get.dialog(
      AlertDialog(
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
      err = e.toString().replaceFirst('Exception: ', '');
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
    if (!isLoggedIn) return openLogin();
    List<Map<String, dynamic>> goodsList = [];
    try {
      goodsList = await _userService.exchangeGoods();
    } catch (_) {}
    if (goodsList.isEmpty) {
      toast('暂无可兑换的商品，稍后再来看看');
      return;
    }
    final goods = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on_rounded,
                color: Color(0xFFFB923C), size: 21),
            SizedBox(width: 9),
            Text('积分兑换',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB923C).withAlpha(dark ? 36 : 22),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFFB923C).withAlpha(70)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.savings_rounded, size: 16, color: sub),
                      const SizedBox(width: 6),
                      Text('当前积分', style: TextStyle(fontSize: 12.5, color: sub)),
                      const Spacer(),
                      Text('$points',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFB923C),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('签到、邀请好友都能获得积分',
                    style: TextStyle(fontSize: 11, color: sub)),
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
      toast(e.toString().replaceFirst('Exception: ', ''));
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
                : (dark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(6)),
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
              Icon(Icons.card_giftcard_rounded,
                  size: 18, color: enough ? warn : sub),
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
      AlertDialog(
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
      toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 替换开屏（上传自定义开屏图）
  Future<void> replaceSplash() async {
    if (!isLoggedIn) return openLogin();
    final action = await Get.dialog<String>(
      AlertDialog(
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
        ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
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
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
