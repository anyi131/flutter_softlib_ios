import 'dart:convert';

import '../admin_save_bus.dart';
import '../../../utils/app_action.dart';
import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../api/soft_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../navigate/navigate_logic.dart';
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

  /// ★ v3.3.4：维护页模板（5 款骨架级）
  String _maintainTemplate = 'engineer';

  static const _maintainTpls = [
    ('engineer', '工程进度', '深色+呼吸发光图标', Icons.settings_rounded),
    ('countdown', '维护倒计时', '金色徽标+进度条', Icons.timer_outlined),
    ('glass', '毛玻璃', '双色光晕+模糊卡', Icons.blur_on_rounded),
    ('brand', '品牌静默', 'LOGO+品牌字居中', Icons.branding_watermark_rounded),
    ('checklist', '服务清单', '提示条+编号列表', Icons.checklist_rounded),
  ];

  final imgCtrl = TextEditingController();

  /// ★ 1020：开屏图来源（off / bing / random / custom）
  String splashSource = 'off';
  final secondsCtrl = TextEditingController(text: '3');
  final urlCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final noticeTitleCtrl = TextEditingController(text: '公告');
  final noticeContentCtrl = TextEditingController();
  final maintainCtrl = TextEditingController();

  // ── 支付配置 ──
  bool payEnable = false;
  bool qqOn = false;

  /// ★ 1020：绑定 QQ 时是否用 QQ 昵称覆盖现有昵称
  bool qqNickForce = true;
  bool qqKeySet = false;
  // ★ 1016：QQ 网页登录（网站应用）——移动应用 AppID 不能走网页授权（100008）
  bool qqWebKeySet = false;
  bool rechargeOn = true;
  bool registerOn = true;

  /// ★ 1016：注册是否需要邮箱验证码（默认需要）
  bool regCodeOn = true;
  bool payAlipay = true;
  bool payWxpay = true;
  bool payQqpay = true;
  bool payKeySet = false; // 密钥是否已设置（不回显）
  bool payNotifyOn = false; // ★ 支付成功通知管理员
  bool payNotifyBuyerOn = true; // ★ 1015 购买成功通知买家本人（默认开）
  final payApiCtrl = TextEditingController();
  final payPidCtrl = TextEditingController();
  final payKeyCtrl = TextEditingController();
  final qqAppIdCtrl = TextEditingController();
  final qqAppKeyCtrl = TextEditingController();
  final qqWebAppIdCtrl = TextEditingController();
  final qqWebAppKeyCtrl = TextEditingController();
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
    // ★ 1020：把保存方法登记给外壳，右下角就会出现悬浮保存按钮
    AdminSaveBus.register(_save);
  }

  @override
  void dispose() {
    AdminSaveBus.clear();
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
        splashEnable = '${d['splash_enable'] ?? 0}' == '1';
        noticeEnable = '${d['notice_enable'] ?? 1}' != '0';
        noticeForce = '${d['notice_force'] ?? 0}' == '1';
        maintainEnable = '${d['maintain_enable'] ?? 0}' == '1';
        _maintainTemplate = '${d['maintain_template'] ?? 'engineer'}';
        imgCtrl.text = '${d['splash_image'] ?? ''}';
        splashSource = '${d['splash_source'] ?? 'off'}';
        secondsCtrl.text = '${d['splash_seconds'] ?? 3}';
        urlCtrl.text = '${d['splash_url'] ?? ''}';
        titleCtrl.text = '${d['splash_title'] ?? ''}';
        descCtrl.text = '${d['splash_desc'] ?? ''}';
        noticeTitleCtrl.text = '${d['notice_title'] ?? '公告'}';
        noticeContentCtrl.text = '${d['notice_content'] ?? ''}';
        maintainCtrl.text = '${d['maintain_text'] ?? ''}';
        // 支付
        payEnable = '${cfg['pay_enabled'] ?? 1}' != '0';
        qqOn = '${cfg['qq_login_on'] ?? 1}' != '0';
        qqNickForce = '${cfg['qq_nick_force'] ?? 1}' != '0';
        qqKeySet =
            '${cfg['qq_app_key_set']}' == 'true' ||
            '${cfg['qq_app_key_set'] ?? 1}' != '0';
        qqAppIdCtrl.text = '${cfg['qq_app_id'] ?? ''}';
        qqRedirectCtrl.text = '${cfg['qq_redirect'] ?? ''}';
        qqWebAppIdCtrl.text = '${cfg['qq_web_app_id'] ?? ''}';
        qqWebKeySet = '${cfg['qq_web_app_key_set'] ?? 0}' != '0';
        rechargeOn = '${cfg['recharge_on']}' != '0';
        recharge1Ctrl.text = '${cfg['recharge_money1'] ?? '10'}';
        recharge2Ctrl.text = '${cfg['recharge_money2'] ?? '30'}';
        recharge3Ctrl.text = '${cfg['recharge_money3'] ?? '100'}';
        registerOn = '${cfg['register_on']}' != '0';
        regCodeOn = '${cfg['reg_code_on'] ?? 1}' != '0';
        payAlipay = '${cfg['pay_alipay'] ?? 1}' != '0';
        payWxpay = '${cfg['pay_wxpay'] ?? 1}' != '0';
        payQqpay = '${cfg['pay_qqpay'] ?? 1}' != '0';
        payKeySet = '${cfg['pay_key_set'] ?? 1}' != '0';
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
        // ★★★ 1015 修复（支付通知"自己变成关的"）：
        //   原来写成 '${cfg['pay_notify_on'] ?? 1}' != '0'
        //   若接口未返回该字段 → '${null}' = "null" ≠ '1' → 静默变 false → 保存后真被关掉。
        //   统一改成与其他开关一致的 "!= '0'" 写法（缺省即开启）。
        payNotifyOn = '${cfg['pay_notify_on'] ?? 1}' != '0';
        payNotifyEmailCtrl.text = '${cfg['pay_notify_email'] ?? ''}';
        // ★ 1015 购买成功通知买家本人（默认开）
        payNotifyBuyerOn = '${cfg['pay_notify_buyer_on'] ?? 1}' != '0';
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
            {
              'key': 'vip7',
              'name': '7天会员卡',
              'type': 'vip',
              'value': 7,
              'price': '5.00',
              'stock': -1,
              'desc': '兑换后会员 +7 天',
            },
            {
              'key': 'vip30',
              'name': '30天会员卡',
              'type': 'vip',
              'value': 30,
              'price': '15.00',
              'stock': -1,
              'desc': '兑换后会员 +30 天',
            },
            {
              'key': 'vip90',
              'name': '90天会员卡',
              'type': 'vip',
              'value': 90,
              'price': '38.00',
              'stock': -1,
              'desc': '兑换后会员 +90 天',
            },
            {
              'key': 'score100',
              'name': '100积分卡',
              'type': 'score',
              'value': 100,
              'price': '5.00',
              'stock': -1,
              'desc': '兑换后积分 +100',
            },
          ];
        }
        aboutNameCtrl.text = '${cfg['about_name'] ?? '安逸软件汇'}';
        // 注册邮箱限制 + UI 风格（需求 #1 / #9）
        emailDomainsCtrl.text = '${cfg['email_allow_domains'] ?? ''}';
        emailNonQqOn = '${cfg['email_nonqq_on'] ?? 1}' != '0';
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
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// 测试开屏接口：显示来源、真实地址、HTTP 状态、字节数、耗时，并预览图片
  Future<void> _testSplash() async {
    AppAction.showLoading('正在测试…');
    try {
      final r = await AdminService.instance.splashTest();
      AppAction.hideLoading();
      if (!mounted) return;
      final ok = r['ok'] == true;
      final proxy = '${r['proxy'] ?? ''}';
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_rounded,
                color: ok ? C.success : C.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(ok ? '接口正常' : '接口异常', style: const TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('来源', '${r['source'] ?? '-'}'),
                _kv('时长', '${r['seconds'] ?? '-'} 秒'),
                _kv('HTTP', '${r['http'] ?? '-'}'),
                _kv('大小', '${r['bytes'] ?? 0} 字节'),
                _kv('耗时', '${r['ms'] ?? 0} ms'),
                _kv('类型', '${r['type'] ?? '-'}'),
                if (proxy.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '实际请求地址',
                    style: TextStyle(fontSize: 10.5, color: context.t3),
                  ),
                  SelectableText(proxy, style: const TextStyle(fontSize: 10.5)),
                ],
                if (ok && proxy.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      proxy,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 40,
                        child: Center(child: Text('预览加载失败')),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      AppAction.hideLoading();
      ToastUtil.error(ErrText.of(e));
    }
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(k, style: TextStyle(fontSize: 11.5, color: context.t3)),
        ),
        Expanded(
          child: Text(v, style: TextStyle(fontSize: 12, color: context.t1)),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    try {
      final splashPayload = {
        'splash_enable': splashEnable ? 1 : 0,
        'splash_image': imgCtrl.text.trim(),
        'splash_source': splashSource,
        'splash_custom_url': imgCtrl.text.trim(),
        'splash_seconds': int.tryParse(secondsCtrl.text) ?? 3,
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
        'maintain_template': _maintainTemplate,
        // 用户协议 / 隐私政策
        'agreement': agreementCtrl.text,
        'privacy': privacyCtrl.text,
      };
      await _svc.saveSplash(splashPayload);
      // 支付配置（pay_key 留空表示不修改）
      final cfgPayload = {
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
        // ★ 1015 购买成功通知买家本人（默认开）
        'pay_notify_buyer_on': payNotifyBuyerOn ? 1 : 0,
        // QQ 快捷登录（AppKey 留空表示不修改）
        'qq_login_on': qqOn ? 1 : 0,
        'qq_nick_force': qqNickForce ? 1 : 0,
        'qq_app_id': qqAppIdCtrl.text.trim(),
        if (qqAppKeyCtrl.text.trim().isNotEmpty)
          'qq_app_key': qqAppKeyCtrl.text.trim(),
        'qq_redirect': qqRedirectCtrl.text.trim(),
        // ★ 1016：网页登录（网站应用）——AppKey 留空表示不修改
        'qq_web_app_id': qqWebAppIdCtrl.text.trim(),
        if (qqWebAppKeyCtrl.text.trim().isNotEmpty)
          'qq_web_app_key': qqWebAppKeyCtrl.text.trim(),
        // 余额充值档位
        'recharge_on': rechargeOn ? 1 : 0,
        'recharge_money1': recharge1Ctrl.text.trim(),
        'recharge_money2': recharge2Ctrl.text.trim(),
        'recharge_money3': recharge3Ctrl.text.trim(),
        // 功能开关
        'register_on': registerOn ? 1 : 0,
        'reg_code_on': regCodeOn ? 1 : 0,
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
      };
      await _svc.saveConfig(cfgPayload);
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
          if (qqWebAppKeyCtrl.text.trim().isNotEmpty) {
            qqWebKeySet = true;
            qqWebAppKeyCtrl.clear();
          }
          // ★ 1015：AppKey 不回显是安全设计，但要让用户确认「确实存住了」
          final justSavedQqKey = qqKeySet;
          if (justSavedQqKey) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ToastUtil.success('AppKey 已保存到服务器（密钥不回显，输入框留空属正常）');
              }
            });
          }
        });
      }
      // v331z：保存成功后回读线上配置，输入框与线上一致（杜绝「保存又返回旧值」错觉）
      try {
        // ★ 1015 修复：先强制刷新客户端配置缓存并递增版本号，
        //   否则 App 其它页面读到的还是 10 分钟内的旧缓存 → 表现为「保存不生效」。
        await SoftService.instance.fetchConfig(force: true);
        final fresh = await _svc.config();
        final cfg = Map<String, dynamic>.from((fresh['data'] ?? {}) as Map);
        // 直接复用 _load 的赋值段太重，这里只回填关键开关/输入框
        payNotifyOn = '${cfg['pay_notify_on'] ?? 1}' != '0';
        payNotifyEmailCtrl.text = '${cfg['pay_notify_email'] ?? ''}';
        payNotifyBuyerOn = '${cfg['pay_notify_buyer_on'] ?? 1}' != '0';
        feedGroupCtrl.text = '${cfg['feedback_group'] ?? ''}';
        feedGroupOn = '${cfg['feedback_group_on'] ?? 0}' != '0';
        // ★ 1015：QQ 登录相关也回读，避免「填了又变空」的错觉
        qqOn = '${cfg['qq_login_on'] ?? 1}' != '0';
        qqNickForce = '${cfg['qq_nick_force'] ?? 1}' != '0';
        qqAppIdCtrl.text = '${cfg['qq_app_id'] ?? ''}';
        qqRedirectCtrl.text = '${cfg['qq_redirect'] ?? ''}';
        qqWebAppIdCtrl.text = '${cfg['qq_web_app_id'] ?? ''}';
        qqWebKeySet = '${cfg['qq_web_app_key_set'] ?? 0}' != '0';
        qqKeySet =
            '${cfg['qq_app_key_set']}' == 'true' ||
            '${cfg['qq_app_key_set'] ?? 1}' != '0';
        setState(() {});

        // ★★ 1016：保存后**逐字段核对**（治「存不上、回读是旧值」的老毛病）。
        //   把刚提交的值跟服务端现在真正存着的值比一遍，对不上就明确列出来。
        try {
          final splashNow = Map<String, dynamic>.from(
            (await _svc.splash())['data'] ?? {},
          );
          final got = <String, dynamic>{...splashNow, ...cfg};
          final sent = <String, dynamic>{...splashPayload, ...cfgPayload};
          const secrets = ['pay_key', 'qq_app_key', 'qq_web_app_key'];
          final bad = <String>[];
          sent.forEach((k, v) {
            if (secrets.contains(k)) return; // 密钥不回显，不参与核对
            if (!got.containsKey(k)) return; // 由别的接口下发，这里判不了
            if ('${got[k]}'.trim() != '$v'.trim()) {
              bad.add('$k：提交「$v」→ 实际「${got[k]}」');
            }
          });
          if (mounted) {
            // ★ 1016：保存后**总是**给出明确结论（不再只在出错时才提示）
            //   这样「生效没生效」一眼可见，不用猜。
            final sentCount = sent.keys
                .where(
                  (k) => !const [
                    'pay_key',
                    'qq_app_key',
                    'qq_web_app_key',
                  ].contains(k),
                )
                .length;
            if (bad.isEmpty) {
              ToastUtil.success('已保存 $sentCount 项，回读核对全部一致 ✓（App 端约 10 秒后生效）');
            }
          }
          if (bad.isNotEmpty && mounted) {
            showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('有字段没保存成功'),
                content: SingleChildScrollView(
                  child: SelectableText(
                    bad.join('\n\n'),
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            );
          }
        } catch (_) {}

        // ★ 1015：后台模板/主题等即时生效（与「界面」Tab 行为对齐）
        try {
          Get.find<NavigateLogic>().applyUiConfig(force: true);
        } catch (_) {}
      } catch (_) {}
      if (mounted) {
        ToastUtil.success('保存成功，App 下次启动生效');
      }
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
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
            // ★ 1020：开屏图来源（每日换图）
            _chipRow(
              const [
                ('off', '不使用'),
                ('bing', '必应每日'),
                ('random', '随机竖图'),
                ('custom', '自定义链接'),
              ],
              splashSource,
              (v) => setState(() => splashSource = v),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(switch (splashSource) {
                'bing' => '每天自动换成必应当日壁纸（已裁成手机竖图 1080×1920）',
                'random' => '每次启动随机一张竖图（第三方图源，可能加载稍慢）',
                'custom' => '使用下方「开屏图片 URL」里的地址',
                _ => '不显示网络开屏图，仅用 App 内打包的开屏页',
              }, style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3)),
            ),
            if (splashSource == 'custom') _field('开屏图片 URL', imgCtrl),
            // ★ 1020：接口自测 —— 一键验证「图片到底能不能取到」
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testSplash,
                  icon: const Icon(Icons.network_check_rounded, size: 17),
                  label: const Text('测试开屏接口'),
                ),
              ),
            ),
            _field(
              '停留秒数（1-10，默认 3）',
              secondsCtrl,
              keyboard: TextInputType.number,
            ),
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
            _field('版本号（留空=自动跟随软件真实版本）', aboutVersionCtrl),
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
                Text(
                  '卡密商品与售价',
                  style: Ty.small.copyWith(
                    color: context.t1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
              Text(
                '暂无商品，点「添加商品」配置（用户可用余额购买）',
                style: Ty.tiny.copyWith(color: context.t3),
              )
            else
              for (int i = 0; i < _cardGoods.length; i++) _cardGoodsRow(i),
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
            _field('维护提示文案（每行一条，会分别展示）', maintainCtrl, lines: 3),
            const SizedBox(height: 12),
            Text(
              '维护页模板 · 共 5 款（骨架不同，不是换色）。当前：'
              '${_maintainTpls.firstWhere((e) => e.$1 == _maintainTemplate, orElse: () => _maintainTpls.first).$2}',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in _maintainTpls)
                  AppPressable(
                    onTap: () => setState(() => _maintainTemplate = o.$1),
                    child: Container(
                      width: 148,
                      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                      decoration: BoxDecoration(
                        color: _maintainTemplate == o.$1
                            ? C.brand.withAlpha(22)
                            : context.isDark
                            ? Colors.white.withAlpha(8)
                            : Colors.black.withAlpha(4),
                        borderRadius: BorderRadius.circular(R.sm),
                        border: Border.all(
                          color: _maintainTemplate == o.$1
                              ? C.brand.withAlpha(150)
                              : Colors.transparent,
                          width: 1.3,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            o.$4,
                            size: 18,
                            color: _maintainTemplate == o.$1
                                ? C.brand
                                : context.t3,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _maintainTemplate == o.$1
                                        ? C.brand
                                        : context.t2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  o.$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ty.tiny.copyWith(
                                    fontSize: 9.5,
                                    color: context.t3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
            const SizedBox(height: 6),
            _switch(
              '同时通知购买者本人（发送到下单会员的注册邮箱）',
              payNotifyBuyerOn,
              (v) => setState(() => payNotifyBuyerOn = v),
            ),
            Text(
              '发件 SMTP 沿用「邮件配置」；发送失败不影响支付到账，'
              '会记入后台操作日志（pay_notify / pay_buyer）',
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
            // ★ 1020：绑定 QQ 时是否用 QQ 昵称覆盖
            _switch(
              '绑定时同步 QQ 昵称（覆盖现有昵称）',
              qqNickForce,
              (v) => setState(() => qqNickForce = v),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                qqNickForce
                    ? '开着：绑定后昵称和头像会变成 QQ 的。'
                    : '关着：只覆盖「QQ用户xxxx」这类自动昵称，你自己起的名字保留。',
                style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
              ),
            ),
            _field('QQ 互联 AppID', qqAppIdCtrl),
            _field(
              qqKeySet
                  ? 'QQ 互联 AppKey（已设置 ✓ 留空=不修改，要换才填）'
                  : 'QQ 互联 AppKey（必填，否则 QQ 登录不可用）',
              qqAppKeyCtrl,
            ),
            if (qqKeySet)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  '✓ AppKey 已保存在服务器（密钥不回显，界面显示空是正常的）',
                  style: Ty.tiny.copyWith(color: C.success),
                ),
              ),
            _field('授权回调地址（留空用默认）', qqRedirectCtrl),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '在 QQ 互联（connect.qq.com）创建应用后，把 AppID/AppKey 填这里。\n'
                '回调地址需在 QQ 互联后台登记为：\n'
                'https://你的域名/api/softlib/user/qq_callback',
                style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
              ),
            ),
            // ★ 1016：网页登录必须用「网站应用」的 AppID
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'QQ 网页登录（网站应用）',
                style: Ty.h3.copyWith(color: context.t1),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '① 上面那个 AppID 是「移动应用」的，只能用于 App 内一键登录；'
                'QQ 互联规定移动应用「不能走网页登录」（会报错误码 100008）。\n'
                '② 如果 App 内一键登录不可用，可以再建一个「网站应用」，'
                '把它的 AppID / AppKey 填在下面，App 内的网页授权就能正常走完。\n'
                '③ 网站应用的回调地址同样填：https://你的域名/api/softlib/user/qq_callback',
                style: Ty.tiny.copyWith(color: context.t3, height: 1.7),
              ),
            ),
            _field('网站应用 AppID（留空=不用网页登录）', qqWebAppIdCtrl),
            _field(
              qqWebKeySet ? '网站应用 AppKey（已设置 ✓ 留空=不修改，要换才填）' : '网站应用 AppKey',
              qqWebAppKeyCtrl,
            ),
            if (qqWebKeySet)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  '✓ 网站应用 AppKey 已保存在服务器（密钥不回显）',
                  style: Ty.tiny.copyWith(color: C.success),
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
            Row(
              children: [
                Expanded(
                  child: _switch(
                    '注册需要邮箱验证码',
                    regCodeOn,
                    (v) => setState(() => regCodeOn = v),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                regCodeOn ? '开启：注册必须填邮箱收到的验证码（更安全）' : '关闭：注册只需邮箱+密码，不用发验证码',
                style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
              ),
            ),
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
        color: context.isDark
            ? Colors.white.withAlpha(8)
            : const Color(0xFFF7F8FA),
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
                child: Text(
                  '${g['name'] ?? ''}',
                  style: Ty.small.copyWith(
                    color: context.t1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Pill(
                isVip ? '会员卡' : '积分卡',
                color: isVip ? C.gold : C.mint,
                small: true,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _cardGoods.removeAt(i)),
                child: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: C.danger,
                ),
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
                  setState(() => _cardGoods[i]['value'] = int.tryParse(v) ?? 0);
                }, number: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniField(
                  '售价(元)',
                  '${g['price'] ?? ''}',
                  (v) {
                    setState(() => _cardGoods[i]['price'] = v);
                  },
                  number: true,
                  decimal: true,
                ),
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
                    child: Text(
                      isVip ? '类型：会员卡' : '类型：积分卡',
                      style: Ty.tiny.copyWith(
                        color: C.brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
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

  /// 选项胶囊（单选）—— 开屏来源等
  Widget _chipRow(
    List<(String, String)> opts,
    String cur,
    ValueChanged<String> onPick,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in opts)
            GestureDetector(
              onTap: () => onPick(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cur == o.$1
                      ? C.brand.withAlpha(26)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: cur == o.$1
                        ? C.brand.withAlpha(150)
                        : context.t3.withAlpha(70),
                  ),
                ),
                child: Text(
                  o.$2,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: cur == o.$1 ? FontWeight.w700 : FontWeight.w500,
                    color: cur == o.$1 ? C.brand : context.t2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return AdCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdSection(title: title),
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
