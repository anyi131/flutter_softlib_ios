import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../api/admin_service.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 开屏与远程控制管理
class AdminSplashTab extends StatefulWidget {
  const AdminSplashTab({super.key});

  @override
  State<AdminSplashTab> createState() => _AdminSplashTabState();
}

class _AdminSplashTabState extends State<AdminSplashTab> {
  final _svc = AdminService.instance;
  bool _loading = true;
  bool _inited = false;

  bool splashEnable = true;
  bool noticeEnable = false;
  bool noticeForce = false;
  bool maintainEnable = false;

  final imgCtrl = TextEditingController();
  final secondsCtrl = TextEditingController(text: '2');
  final urlCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final noticeTitleCtrl = TextEditingController(text: '公告');
  final noticeContentCtrl = TextEditingController();
  final maintainCtrl = TextEditingController();

  // ── 支付配置 ──
  bool payEnable = false;
  bool qqOn = false;
  bool qqKeySet = false;
  bool rechargeOn = true;
  bool registerOn = true;
  bool payAlipay = true;
  bool payWxpay = true;
  bool payQqpay = true;
  bool payKeySet = false; // 密钥是否已设置（不回显）
  bool payNotifyOn = false; // ★ 支付成功通知管理员
  final payApiCtrl = TextEditingController();
  final payPidCtrl = TextEditingController();
  final payKeyCtrl = TextEditingController();
  final qqAppIdCtrl = TextEditingController();
  final qqAppKeyCtrl = TextEditingController();
  final qqRedirectCtrl = TextEditingController();
  final recharge1Ctrl = TextEditingController();
  final recharge2Ctrl = TextEditingController();
  final recharge3Ctrl = TextEditingController(); // 留空 = 不修改
  final payPlan1NameCtrl = TextEditingController(text: '一周会员');
  final payPlan1MoneyCtrl = TextEditingController(text: '8');
  final payPlan1DaysCtrl = TextEditingController(text: '7');
  final payPlan2NameCtrl = TextEditingController(text: '三个月会员');
  final payPlan2MoneyCtrl = TextEditingController(text: '28.88');
  final payPlan2DaysCtrl = TextEditingController(text: '90');
  final payPlan3NameCtrl = TextEditingController(text: '永久会员');
  final payPlan3MoneyCtrl = TextEditingController(text: '45.99');
  final payPlan3DaysCtrl = TextEditingController(text: '0');
  final payNotifyEmailCtrl = TextEditingController(); // ★ 收件邮箱（逗号分隔多个）

  // ── 主页右上角两个圆形按钮（加群 / 客服）──
  bool feedGroupOn = true;
  bool feedUserOn = true;
  final feedGroupCtrl = TextEditingController();
  final feedUserCtrl = TextEditingController();

  // ── 关于软件（后台可配）──
  bool aboutEnable = true;
  // ★ 1014：分享文案 + 卡密商城开关
  final shareTitleCtrl = TextEditingController();
  final shareDescCtrl = TextEditingController();
  final shareUrlCtrl = TextEditingController();
  bool cardShopOn = true;
  /// ★ 1014：卡密商城商品列表（可增删改）
  /// 每项：{key,name,type(vip|score),value,price,stock,desc}
  List<Map<String, dynamic>> _cardGoods = [];
  final aboutNameCtrl = TextEditingController();
  // ── 注册邮箱限制 + UI 风格（需求 #1 / #9）──
  final emailDomainsCtrl = TextEditingController();
  bool emailNonQqOn = false;
  String uiStyle = 'glass';
  String themePalette = 'aurora';
  final aboutVersionCtrl = TextEditingController();
  final aboutLogCtrl = TextEditingController();
  final aboutSloganCtrl = TextEditingController();
  final aboutDescCtrl = TextEditingController();
  final aboutCopyrightCtrl = TextEditingController();
  final aboutContactCtrl = TextEditingController();
  final aboutWebsiteCtrl = TextEditingController();
  final aboutUpdateCtrl = TextEditingController();

  // ── 用户协议 / 隐私政策 ──
  final agreementCtrl = TextEditingController();
  final privacyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    imgCtrl.dispose();
    secondsCtrl.dispose();
    urlCtrl.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    noticeTitleCtrl.dispose();
    noticeContentCtrl.dispose();
    maintainCtrl.dispose();
    payApiCtrl.dispose();
    payPidCtrl.dispose();
    payKeyCtrl.dispose();
    payPlan1NameCtrl.dispose();
    payPlan1MoneyCtrl.dispose();
    payPlan1DaysCtrl.dispose();
    payPlan2NameCtrl.dispose();
    payPlan2MoneyCtrl.dispose();
    payPlan2DaysCtrl.dispose();
    payPlan3NameCtrl.dispose();
    payPlan3MoneyCtrl.dispose();
    payPlan3DaysCtrl.dispose();
    payNotifyEmailCtrl.dispose();
    feedGroupCtrl.dispose();
    feedUserCtrl.dispose();
    aboutNameCtrl.dispose();
    emailDomainsCtrl.dispose();
    aboutVersionCtrl.dispose();
    aboutLogCtrl.dispose();
    aboutSloganCtrl.dispose();
    aboutDescCtrl.dispose();
    aboutCopyrightCtrl.dispose();
    aboutContactCtrl.dispose();
    aboutWebsiteCtrl.dispose();
    aboutUpdateCtrl.dispose();
    shareTitleCtrl.dispose();
    shareDescCtrl.dispose();
    shareUrlCtrl.dispose();
    agreementCtrl.dispose();
    privacyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await _svc.splash();
      // 支付配置走 config 接口（与开屏配置分属不同接口）
      Map<String, dynamic> cfg = {};
      try {
        cfg = await _svc.config();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        splashEnable = '${d['splash_enable']}' == '1';
        noticeEnable = '${d['notice_enable']}' == '1';
        noticeForce = '${d['notice_force']}' == '1';
        maintainEnable = '${d['maintain_enable']}' == '1';
        imgCtrl.text = '${d['splash_image'] ?? ''}';
        secondsCtrl.text = '${d['splash_seconds'] ?? 2}';
        urlCtrl.text = '${d['splash_url'] ?? ''}';
        titleCtrl.text = '${d['splash_title'] ?? ''}';
        descCtrl.text = '${d['splash_desc'] ?? ''}';
        noticeTitleCtrl.text = '${d['notice_title'] ?? '公告'}';
        noticeContentCtrl.text = '${d['notice_content'] ?? ''}';
        maintainCtrl.text = '${d['maintain_text'] ?? ''}';
        // 支付
        payEnable = '${cfg['pay_enabled']}' == '1';
        qqOn = '${cfg['qq_login_on']}' == '1';
        qqKeySet =
            '${cfg['qq_app_key_set']}' == 'true' ||
            '${cfg['qq_app_key_set']}' == '1';
        qqAppIdCtrl.text = '${cfg['qq_app_id'] ?? ''}';
        qqRedirectCtrl.text = '${cfg['qq_redirect'] ?? ''}';
        rechargeOn = '${cfg['recharge_on']}' != '0';
        recharge1Ctrl.text = '${cfg['recharge_money1'] ?? '10'}';
        recharge2Ctrl.text = '${cfg['recharge_money2'] ?? '30'}';
        recharge3Ctrl.text = '${cfg['recharge_money3'] ?? '100'}';
        registerOn = '${cfg['register_on']}' != '0';
        payAlipay = '${cfg['pay_alipay']}' == '1';
        payWxpay = '${cfg['pay_wxpay']}' == '1';
        payQqpay = '${cfg['pay_qqpay']}' == '1';
        payKeySet = '${cfg['pay_key_set']}' == '1';
        payApiCtrl.text = '${cfg['pay_apiurl'] ?? ''}';
        payPidCtrl.text = '${cfg['pay_pid'] ?? ''}';
        payPlan1NameCtrl.text = '${cfg['pay_plan1_name'] ?? '一周会员'}';
        payPlan1MoneyCtrl.text = '${cfg['pay_plan1_money'] ?? '8'}';
        payPlan1DaysCtrl.text = '${cfg['pay_plan1_days'] ?? 7}';
        payPlan2NameCtrl.text = '${cfg['pay_plan2_name'] ?? '三个月会员'}';
        payPlan2MoneyCtrl.text = '${cfg['pay_plan2_money'] ?? '28.88'}';
        payPlan2DaysCtrl.text = '${cfg['pay_plan2_days'] ?? 90}';
        payPlan3NameCtrl.text = '${cfg['pay_plan3_name'] ?? '永久会员'}';
        payPlan3MoneyCtrl.text = '${cfg['pay_plan3_money'] ?? '45.99'}';
        payPlan3DaysCtrl.text = '${cfg['pay_plan3_days'] ?? 0}';
        // ★ 支付成功通知
        payNotifyOn = '${cfg['pay_notify_on']}' == '1';
        payNotifyEmailCtrl.text = '${cfg['pay_notify_email'] ?? ''}';
        // 主页右上角两个按钮（对应需求 #14）
        feedGroupOn = '${cfg['feedback_group_on']}' != '0';
        feedUserOn = '${cfg['feedback_user_on']}' != '0';
        feedGroupCtrl.text = '${cfg['feedback_group'] ?? ''}';
        feedUserCtrl.text = '${cfg['feedback_user'] ?? ''}';
        // 关于软件
        aboutEnable = '${cfg['about_enable']}' != '0';
        shareTitleCtrl.text = '${cfg['share_title'] ?? ''}';
        shareDescCtrl.text = '${cfg['share_desc'] ?? ''}';
        shareUrlCtrl.text = '${cfg['share_url'] ?? ''}';
        cardShopOn = '${cfg['card_shop_on'] ?? 1}' != '0';
        // ★ 1014：卡密商品配置（JSON 数组）
        final rawGoods = '${cfg['card_shop'] ?? ''}';
        _cardGoods = [];
        if (rawGoods.trim().isNotEmpty) {
          try {
            final j = jsonDecode(rawGoods);
            if (j is List) {
              _cardGoods = j
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          } catch (_) {}
        }
        // 没配过 → 给一份默认商品，方便直接改价
        if (_cardGoods.isEmpty) {
          _cardGoods = [
            {'key': 'vip7', 'name': '7天会员卡', 'type': 'vip', 'value': 7, 'price': '5.00', 'stock': -1, 'desc': '兑换后会员 +7 天'},
            {'key': 'vip30', 'name': '30天会员卡', 'type': 'vip', 'value': 30, 'price': '15.00', 'stock': -1, 'desc': '兑换后会员 +30 天'},
            {'key': 'vip90', 'name': '90天会员卡', 'type': 'vip', 'value': 90, 'price': '38.00', 'stock': -1, 'desc': '兑换后会员 +90 天'},
            {'key': 'score100', 'name': '100积分卡', 'type': 'score', 'value': 100, 'price': '5.00', 'stock': -1, 'desc': '兑换后积分 +100'},
          ];
        }
        aboutNameCtrl.text = '${cfg['about_name'] ?? '安逸软件汇'}';
        // 注册邮箱限制 + UI 风格（需求 #1 / #9）
        emailDomainsCtrl.text = '${cfg['email_allow_domains'] ?? ''}';
        emailNonQqOn = '${cfg['email_nonqq_on']}' == '1';
        uiStyle = '${cfg['app_ui_style'] ?? 'glass'}';
        themePalette = '${cfg['theme_palette'] ?? 'aurora'}';
        aboutVersionCtrl.text = '${cfg['about_version'] ?? '1.0.0'}';
        aboutLogCtrl.text = '${cfg['about_logo'] ?? ''}';
        aboutSloganCtrl.text = '${cfg['about_slogan'] ?? ''}';
        aboutDescCtrl.text = '${cfg['about_desc'] ?? ''}';
        aboutCopyrightCtrl.text = '${cfg['about_copyright'] ?? ''}';
        aboutContactCtrl.text = '${cfg['about_contact'] ?? ''}';
        aboutWebsiteCtrl.text = '${cfg['about_website'] ?? ''}';
        aboutUpdateCtrl.text = '${cfg['about_update_url'] ?? ''}';
        // 协议（在 splash 接口里）
        agreementCtrl.text = '${d['agreement'] ?? ''}';
        privacyCtrl.text = '${d['privacy'] ?? ''}';
        _loading = false;
        _inited = true;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _save() async {
    try {
      await _svc.saveSplash({
        'splash_enable': splashEnable ? 1 : 0,
        'splash_image': imgCtrl.text.trim(),
        'splash_seconds': int.tryParse(secondsCtrl.text) ?? 2,
        'splash_url': urlCtrl.text.trim(),
        'splash_title': titleCtrl.text.trim(),
        'splash_desc': descCtrl.text.trim(),
        'notice_enable': noticeEnable ? 1 : 0,
        'notice_title': noticeTitleCtrl.text.trim(),
        'notice_content': noticeContentCtrl.text,
        'notice_force': noticeForce ? 1 : 0,
        'maintain_enable': maintainEnable ? 1 : 0,
        'maintain_text': maintainCtrl.text.trim(),
        // 用户协议 / 隐私政策
        'agreement': agreementCtrl.text,
        'privacy': privacyCtrl.text,
      });
      // 支付配置（pay_key 留空表示不修改）
      await _svc.saveConfig({
        'pay_enabled': payEnable ? 1 : 0,
        'pay_apiurl': payApiCtrl.text.trim(),
        'pay_pid': payPidCtrl.text.trim(),
        if (payKeyCtrl.text.trim().isNotEmpty)
          'pay_key': payKeyCtrl.text.trim(),
        'pay_alipay': payAlipay ? 1 : 0,
        'pay_wxpay': payWxpay ? 1 : 0,
        'pay_qqpay': payQqpay ? 1 : 0,
        'pay_plan1_name': payPlan1NameCtrl.text.trim(),
        'pay_plan1_money': payPlan1MoneyCtrl.text.trim(),
        'pay_plan1_days': int.tryParse(payPlan1DaysCtrl.text) ?? 7,
        'pay_plan2_name': payPlan2NameCtrl.text.trim(),
        'pay_plan2_money': payPlan2MoneyCtrl.text.trim(),
        'pay_plan2_days': int.tryParse(payPlan2DaysCtrl.text) ?? 90,
        'pay_plan3_name': payPlan3NameCtrl.text.trim(),
        'pay_plan3_money': payPlan3MoneyCtrl.text.trim(),
        'pay_plan3_days': int.tryParse(payPlan3DaysCtrl.text) ?? 0,
        // ★ 支付成功通知管理员
        'pay_notify_on': payNotifyOn ? 1 : 0,
        'pay_notify_email': payNotifyEmailCtrl.text.trim(),
        // QQ 快捷登录（AppKey 留空表示不修改）
        'qq_login_on': qqOn ? 1 : 0,
        'qq_app_id': qqAppIdCtrl.text.trim(),
        if (qqAppKeyCtrl.text.trim().isNotEmpty)
          'qq_app_key': qqAppKeyCtrl.text.trim(),
        'qq_redirect': qqRedirectCtrl.text.trim(),
        // 余额充值档位
        'recharge_on': rechargeOn ? 1 : 0,
        'recharge_money1': recharge1Ctrl.text.trim(),
        'recharge_money2': recharge2Ctrl.text.trim(),
        'recharge_money3': recharge3Ctrl.text.trim(),
        // 功能开关
        'register_on': registerOn ? 1 : 0,
        // 主页右上角两个按钮（对应需求 #14）
        'feedback_group_on': feedGroupOn ? 1 : 0,
        'feedback_user_on': feedUserOn ? 1 : 0,
        'feedback_group': feedGroupCtrl.text.trim(),
        'feedback_user': feedUserCtrl.text.trim(),
        // 关于软件
        'about_enable': aboutEnable ? 1 : 0,
        'share_title': shareTitleCtrl.text.trim(),
        'share_desc': shareDescCtrl.text.trim(),
        'share_url': shareUrlCtrl.text.trim(),
        'card_shop_on': cardShopOn ? 1 : 0,
        'card_shop': jsonEncode(_cardGoods),
        'about_name': aboutNameCtrl.text.trim(),
        'about_version': aboutVersionCtrl.text.trim(),
        'about_logo': aboutLogCtrl.text.trim(),
        'about_slogan': aboutSloganCtrl.text.trim(),
        'about_desc': aboutDescCtrl.text.trim(),
        'about_copyright': aboutCopyrightCtrl.text.trim(),
        'about_contact': aboutContactCtrl.text.trim(),
        'about_website': aboutWebsiteCtrl.text.trim(),
        'about_update_url': aboutUpdateCtrl.text.trim(),
        // 注册邮箱限制 + UI 风格（需求 #1 / #9）
        'email_allow_domains': emailDomainsCtrl.text.trim(),
        'email_nonqq_on': emailNonQqOn ? 1 : 0,
        'app_ui_style': uiStyle,
        'theme_palette': themePalette,
      });
      if (mounted) {
        setState(() {
          if (payKeyCtrl.text.trim().isNotEmpty) {
            payKeySet = true;
            payKeyCtrl.clear();
          }
          if (qqAppKeyCtrl.text.trim().isNotEmpty) {
            qqKeySet = true;
            qqAppKeyCtrl.clear();
          }
        });
      }
      // v331z：保存成功后回读线上配置，输入框与线上一致（杜绝「保存又返回旧值」错觉）
      try {
        final fresh = await _svc.config();
        final cfg = Map<String, dynamic>.from((fresh['data'] ?? {}) as Map);
        // 直接复用 _load 的赋值段太重，这里只回填关键开关/输入框
        payNotifyOn = '${cfg['pay_notify_on'] ?? 0}' == '1';
        payNotifyEmailCtrl.text = '${cfg['pay_notify_email'] ?? ''}';
        feedGroupCtrl.text = '${cfg['feedback_group'] ?? ''}';
        feedGroupOn = '${cfg['feedback_group_on'] ?? 0}' != '0';
        setState(() {});
      } catch (_) {}
      if (mounted) {
        ToastUtil.success('保存成功，App 下次启动生效');
      }
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState(text: '加载开屏配置…');
    }
    if (!_inited) {
      return ErrorState(text: '加载配置失败', hint: '请检查网络连接后重试', onRetry: _load);
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _card(
          title: '开屏页',
          children: [
            _switch(
              '启用开屏页',
              splashEnable,
              (v) => setState(() => splashEnable = v),
            ),
            _field('开屏图片 URL', imgCtrl),
            _field('停留秒数（1-10）', secondsCtrl, keyboard: TextInputType.number),
            _field('点击跳转网址（选填）', urlCtrl),
            _field('标题（选填）', titleCtrl),
            _field('副标题（选填）', descCtrl),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '主页右上角按钮',
          children: [
            _switch(
              '显示「加群」按钮',
              feedGroupOn,
              (v) => setState(() => feedGroupOn = v),
            ),
            _field('QQ群链接（加群/通知群，主页右上角按钮）', feedGroupCtrl),
            const SizedBox(height: 6),
            _switch(
              '显示「客服」按钮',
              feedUserOn,
              (v) => setState(() => feedUserOn = v),
            ),
            _field('客服图片 URL / 链接', feedUserCtrl),
            Text(
              '用户点击后弹窗展示对应图片（留空会提示「暂未配置」）',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '关于软件',
          children: [
            _switch(
              '启用「关于软件」页',
              aboutEnable,
              (v) => setState(() => aboutEnable = v),
            ),
            _field('应用名称', aboutNameCtrl),
            _field('版本号（展示用）', aboutVersionCtrl),
            _field('Logo 图片 URL', aboutLogCtrl),
            _field('一句话简介', aboutSloganCtrl),
            _field('详细介绍', aboutDescCtrl, lines: 4),
            _field('版权信息', aboutCopyrightCtrl),
            _field('联系方式（邮箱/QQ）', aboutContactCtrl),
            _field('官方网站', aboutWebsiteCtrl),
            _field('检查更新地址（App 内跳转）', aboutUpdateCtrl),
          ],
        ),
        const SizedBox(height: 12),
        // ★ 1014 需求6：分享本软件文案（后台可配，关于页与我的页共用）
        _card(
          title: '分享设置',
          children: [
            _field('分享标题', shareTitleCtrl),
            _field('分享描述', shareDescCtrl),
            _field('分享链接（留空则用官方网站）', shareUrlCtrl),
            Text(
              '用户在「关于软件 → 分享本软件」和「我的 → 分享软件」时，'
              '会用这三项内容唤出系统分享面板。',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ★ 1014 需求5：卡密商城（开关 + 商品与售价配置）
        _card(
          title: '卡密商城',
          children: [
            _switch(
              '开启卡密商城（用户可用余额购买卡密）',
              cardShopOn,
              (v) => setState(() => cardShopOn = v),
            ),
            Text(
              '关闭后用户端「卡密商城」入口仍显示，但无法购买；'
              '「使用卡密」不受影响，用户仍可兑换别人给的卡密。',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('卡密商品与售价',
                    style: Ty.small.copyWith(
                        color: context.t1, fontWeight: FontWeight.w800)),
                const Spacer(),
                SoftButton(
                  label: '添加商品',
                  icon: Icons.add_rounded,
                  height: 32,
                  onPressed: _addCardGoods,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_cardGoods.isEmpty)
              Text('暂无商品，点「添加商品」配置（用户可用余额购买）',
                  style: Ty.tiny.copyWith(color: context.t3))
            else
              for (int i = 0; i < _cardGoods.length; i++)
                _cardGoodsRow(i),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '注册与界面风格',
          children: [
            _switch(
              '允许使用非 QQ 邮箱注册',
              emailNonQqOn,
              (v) => setState(() => emailNonQqOn = v),
            ),
            if (!emailNonQqOn)
              Text(
                '关闭时：注册页只显示 @qq.com，且其他邮箱会被拒绝',
                style: Ty.tiny.copyWith(color: C.warning),
              ),
            if (emailNonQqOn) ...[
              _field('允许注册的邮箱域名（逗号分隔，留空=不限）', emailDomainsCtrl),
            ],
            Text(
              '例：qq.com,163.com,gmail.com —— 只允许这些邮箱注册；留空则任意邮箱都可注册',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '用户协议 / 隐私政策',
          children: [
            _field('用户协议内容（支持 HTML）', agreementCtrl, lines: 6),
            const SizedBox(height: 8),
            _field('隐私政策内容（支持 HTML）', privacyCtrl, lines: 6),
            Text(
              'App 端「我的 → 用户协议/隐私政策」会以美化页面展示这些内容',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '公告弹窗',
          children: [
            _switch(
              '启用公告弹窗',
              noticeEnable,
              (v) => setState(() => noticeEnable = v),
            ),
            _switch(
              '强制阅读（不可关闭）',
              noticeForce,
              (v) => setState(() => noticeForce = v),
            ),
            _field('公告标题', noticeTitleCtrl),
            _field('公告内容（支持 HTML）', noticeContentCtrl, lines: 4),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '远程控制',
          children: [
            _switch(
              '开启维护模式（App 显示维护页）',
              maintainEnable,
              (v) => setState(() => maintainEnable = v),
            ),
            _field('维护提示文案', maintainCtrl, lines: 2),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '会员支付',
          children: [
            _switch('开启在线支付', payEnable, (v) => setState(() => payEnable = v)),
            _field('支付接口地址 apiurl', payApiCtrl),
            _field('商户 PID', payPidCtrl),
            _field('商户 KEY（留空表示不修改）', payKeyCtrl),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    payKeySet
                        ? Icons.verified_user_rounded
                        : Icons.warning_amber_rounded,
                    size: 14,
                    color: payKeySet ? C.success : C.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    payKeySet ? '密钥已设置' : '密钥尚未设置，支付无法使用',
                    style: Ty.tiny.copyWith(
                      color: payKeySet ? C.success : C.warning,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _switch(
                    '支付宝',
                    payAlipay,
                    (v) => setState(() => payAlipay = v),
                  ),
                ),
                Expanded(
                  child: _switch(
                    '微信',
                    payWxpay,
                    (v) => setState(() => payWxpay = v),
                  ),
                ),
                Expanded(
                  child: _switch(
                    'QQ',
                    payQqpay,
                    (v) => setState(() => payQqpay = v),
                  ),
                ),
              ],
            ),
            if (!payEnable)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '未开启时 App 会员页会提示「支付暂未开放」',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '支付成功通知',
          children: [
            _switch(
              '订单支付成功后邮件通知管理员',
              payNotifyOn,
              (v) => setState(() => payNotifyOn = v),
            ),
            _field('收件邮箱（多个用英文逗号分隔）', payNotifyEmailCtrl),
            Text(
              '发件 SMTP 沿用「邮件配置」；发送失败不影响支付到账，'
              '会记入后台操作日志（pay_notify）',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '会员套餐',
          children: [
            _field('套餐一 名称', payPlan1NameCtrl),
            Row(
              children: [
                Expanded(child: _field('价格（元）', payPlan1MoneyCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _field('天数', payPlan1DaysCtrl)),
              ],
            ),
            const Divider(height: 20),
            _field('套餐二 名称', payPlan2NameCtrl),
            Row(
              children: [
                Expanded(child: _field('价格（元）', payPlan2MoneyCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _field('天数', payPlan2DaysCtrl)),
              ],
            ),
            const Divider(height: 20),
            _field('套餐三 名称', payPlan3NameCtrl),
            Row(
              children: [
                Expanded(child: _field('价格（元）', payPlan3MoneyCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _field('天数（0=永久）', payPlan3DaysCtrl)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: 'QQ 快捷登录',
          children: [
            _switch('登录页显示 QQ 登录', qqOn, (v) => setState(() => qqOn = v)),
            _field('QQ 互联 AppID', qqAppIdCtrl),
            _field('QQ 互联 AppKey（留空表示不修改）', qqAppKeyCtrl),
            _field('授权回调地址（留空用默认）', qqRedirectCtrl),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '在 QQ 互联（connect.qq.com）创建网站应用后，把 AppID/AppKey 填这里。\n'
                '回调地址需在 QQ 互联后台登记为：\n'
                'https://你的域名/api/softlib/user/qq_callback',
                style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '余额充值档位',
          children: [
            _switch(
              '允许余额充值',
              rechargeOn,
              (v) => setState(() => rechargeOn = v),
            ),
            Row(
              children: [
                Expanded(child: _field('档位一（元）', recharge1Ctrl)),
                const SizedBox(width: 10),
                Expanded(child: _field('档位二（元）', recharge2Ctrl)),
                const SizedBox(width: 10),
                Expanded(child: _field('档位三（元）', recharge3Ctrl)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '用户在「我的 → 充值余额」看到这三档（也可自己输入金额）',
                style: Ty.tiny.copyWith(color: context.t3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          title: '功能开关',
          children: [
            _switch('开放注册', registerOn, (v) => setState(() => registerOn = v)),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: '保存全部配置',
          icon: Icons.save_rounded,
          onPressed: _save,
        ),
        const SizedBox(height: 30),
      ],
    );
  }


  /// ★ 1014：单条卡密商品编辑行（名称 / 面值 / 售价 / 类型）
  Widget _cardGoodsRow(int i) {
    final g = _cardGoods[i];
    final isVip = '${g['type'] ?? 'vip'}' == 'vip';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withAlpha(8) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withAlpha(18)
              : Colors.black.withAlpha(8),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${g['name'] ?? ''}',
                    style: Ty.small.copyWith(
                        color: context.t1, fontWeight: FontWeight.w800)),
              ),
              Pill(isVip ? '会员卡' : '积分卡',
                  color: isVip ? C.gold : C.mint, small: true),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _cardGoods.removeAt(i)),
                child: const Icon(Icons.close_rounded,
                    size: 17, color: C.danger),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _miniField('名称', '${g['name'] ?? ''}', (v) {
                  setState(() => _cardGoods[i]['name'] = v);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniField('面值(天/分)', '${g['value'] ?? 0}', (v) {
                  setState(() =>
                      _cardGoods[i]['value'] = int.tryParse(v) ?? 0);
                }, number: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniField('售价(元)', '${g['price'] ?? ''}', (v) {
                  setState(() => _cardGoods[i]['price'] = v);
                }, number: true, decimal: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _cardGoods[i]['type'] = isVip ? 'score' : 'vip';
                  }),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(R.sm),
                      border: Border.all(color: C.brand.withAlpha(120)),
                    ),
                    child: Text(isVip ? '类型：会员卡' : '类型：积分卡',
                        style: Ty.tiny.copyWith(
                            color: C.brand, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 小输入框（失焦时回写）
  Widget _miniField(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    bool number = false,
    bool decimal = false,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: number
          ? TextInputType.numberWithOptions(decimal: decimal)
          : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm)),
      ),
      onChanged: onChanged,
    );
  }

  /// 添加一条卡密商品
  void _addCardGoods() {
    setState(() {
      _cardGoods.add({
        'key': 'card_${DateTime.now().millisecondsSinceEpoch}',
        'name': '新会员卡',
        'type': 'vip',
        'value': 30,
        'price': '10.00',
        'stock': -1,
        'desc': '',
      });
    });
    ToastUtil.info('已添加，请填写名称/面值/售价后点底部「保存全部配置」');
  }

  Widget _card({required String title, required List<Widget> children}) {
    return KitCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          ...children,
        ],
      ),
    );
  }

  /// 样式选择 chip
  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
          Switch(value: value, activeThumbColor: C.brand, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    int lines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: c,
        maxLines: lines,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md)),
        ),
      ),
    );
  }
}
