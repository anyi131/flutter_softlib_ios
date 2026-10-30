import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' show FontFeature;

import '../../design/app_anim.dart';
import '../../utils/err_text.dart';

import 'package:get/get.dart';

import '../../api/pay_service.dart';
import '../../api/soft_service.dart';
import '../../api/user_service.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'pay_notice_dialog.dart';

/// 开通会员 / VIP 中心页
/// VIP PRO 头卡 + 三档套餐 + 支付方式 + 立即开通 + 会员权益
/// 套餐与价格由后台配置下发（pay/plans），支付走易支付收银台
class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  /// 默认套餐（后端拉取失败时的兜底，保证页面可用）
  List<PayPlan> _plans = const [
    PayPlan(id: 'plan1', name: '一周会员', money: '8', days: 7),
    PayPlan(id: 'plan2', name: '三个月会员', money: '28.88', days: 90),
    PayPlan(id: 'plan3', name: '永久会员', money: '45.99', days: 0),
  ];
  bool _payEnabled = false;
  bool _loadingPlans = true;
  bool _submitting = false;
  Map<String, int> _methods = {'alipay': 1, 'wxpay': 1, 'qqpay': 1};

  int _selectedPlan = 1; // 默认选中「推荐」的三个月
  int _payMethod = 0; // 0 支付宝 1 微信 2 QQ

  /// 促销倒计时（横幅存在时每秒刷新）
  Timer? _promoTick;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    // ★ 1031：进页面刷一次资料，保证「已是会员/到期时间」展示最新
    if (UserService.instance.isLoggedIn) {
      UserService.instance.refreshProfile().then((_) {
        if (mounted) setState(() {});
      });
    }
    _promoTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cfg = SoftService.instance.cachedConfig?.promo;
      if (cfg == null || !cfg.on) return;
      final end = DateTime.tryParse(cfg.end.replaceFirst(' ', 'T'));
      if (end == null) return;
      setState(() {}); // 只为刷新倒计时文本
    });
  }

  @override
  void dispose() {
    _promoTick?.cancel();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final r = await PayService.instance.plans();
      final list = (r['planList'] as List?)?.cast<PayPlan>() ?? [];
      if (!mounted) return;
      setState(() {
        if (list.isNotEmpty) _plans = list;
        _payEnabled = r['enabled'] == 1 || r['enabled'] == true;
        final m = r['methods'];
        if (m is Map) {
          _methods = {
            'alipay': (m['alipay'] ?? 1) as int,
            'wxpay': (m['wxpay'] ?? 1) as int,
            'qqpay': (m['qqpay'] ?? 1) as int,
          };
        }
        _loadingPlans = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  bool _methodOn(int i) {
    final k = ['alipay', 'wxpay', 'qqpay'][i];
    return (_methods[k] ?? 1) == 1;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          Column(
            children: [
              // v55：内容区滚动 + 底部固定支付按钮（Expanded 父级为 Column，符合 Flex 红线）
              Expanded(
                child: ListView(
                  // ★ 顶部留出状态栏 + 悬浮返回栏的高度，避免内容被遮挡
                  padding: EdgeInsets.fromLTRB(14, topInset + 52, 14, 20),
                  children: [
                    _buildHeaderCard(),
                    _promoBanner(),
                    const SizedBox(height: 18),
                    SectionHeader(title: '选择套餐', accent: C.gold),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_plans.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i == _plans.length - 1 ? 0 : 10,
                            ),
                            child: _buildPlanCard(i),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: '支付方式'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildPayItem(
                          0,
                          '支付宝',
                          Icons.account_balance_wallet_outlined,
                        ),
                        const SizedBox(width: 10),
                        _buildPayItem(1, '微信', Icons.chat_bubble_outline),
                        const SizedBox(width: 10),
                        _buildPayItem(2, 'QQ', Icons.pets_outlined),
                      ],
                    ),
                    const SizedBox(height: 22),
                    KitCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: '会员权益', accent: C.gold),
                          _benefit('不限次数下载软件库资源'),
                          _benefit('新功能和资源优先体验'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        '支付完成后会员状态会自动同步到账户',
                        style: Ty.tiny.copyWith(color: context.t3),
                      ),
                    ),
                  ],
                ),
              ),
              // v55：底部固定支付栏（渐变 + 阴影 + loading 态）
              _payBar(context),
            ],
          ),
          // 悬浮返回栏（透明背景，仅一个圆形返回按钮）
          Positioned(
            top: topInset + 4,
            left: 12,
            child: AppPressable(
              onTap: () => Get.back(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.white.withAlpha(16)
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.isDark
                        ? Colors.white.withAlpha(24)
                        : Colors.black.withAlpha(8),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: context.t1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// v55：底部固定支付栏
  Widget _payBar(BuildContext context) {
    // ★ 1031：已登录会员 → 按钮变「续费」，并展示到期时间；
    //   到期前 7 天内额外提示「即将到期」。
    final u = UserService.instance.user;
    final isVip = u?.isVipActive ?? false;
    final exp = _vipExpireText();
    final daysLeft = _vipDaysLeft();
    final urgent = isVip && daysLeft >= 0 && daysLeft <= 7;
    final label = _submitting
        ? '正在下单…'
        : (isVip ? (urgent ? '会员即将到期 · 立即续费' : '续费会员') : '立即开通会员');
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.isDark ? C.bg1.withAlpha(245) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(context.isDark ? 60 : 20),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 会员有效期小字（仅已是会员时出现）
          if (isVip && exp.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 13,
                  color: C.gold,
                ),
                const SizedBox(width: 4),
                Text(
                  '当前会员有效期至 $exp${urgent ? '（剩 $daysLeft 天）' : ''}',
                  style: Ty.tiny.copyWith(
                    color: urgent ? C.accentOrange : context.t3,
                    fontWeight: urgent ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          PrimaryButton(
            label: label,
            icon: Icons.workspace_premium_rounded,
            gold: true,
            loading: _submitting,
            onPressed: _submitting ? null : _onBuy,
          ),
        ],
      ),
    );
  }

  /// ★ 1031 会员到期时间文本（无 / 解析失败返回空）
  String _vipExpireText() {
    final raw = UserService.instance.user?.vipExpire ?? '';
    if (raw.isEmpty) return '';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// ★ 1031 会员剩余天数（向下取整；非会员/解析失败 = -1）
  int _vipDaysLeft() {
    final raw = UserService.instance.user?.vipExpire ?? '';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return -1;
    return d.difference(DateTime.now()).inDays;
  }

  /// ★ 1031 套餐 i 是否参与促销（后台 promo_idx 配置；空 = 全部）
  bool _promoHit(int i) {
    final cfg = SoftService.instance.cachedConfig?.promo;
    return cfg != null && cfg.on && cfg.hit(i);
  }

  /// ★ 1031 套餐角标文案：后台 badge 优先，其次 tip，最后兜底
  String _planPromoLabel() {
    final cfg = SoftService.instance.cachedConfig?.promo;
    if (cfg == null) return '限时特惠';
    if (cfg.badge.isNotEmpty) return cfg.badge;
    if (cfg.tip.isNotEmpty) return cfg.tip;
    return '限时特惠';
  }

  /// ★ 1031 促销横幅（纯展示）—— 深底金字，克制的奢华：
  ///   左侧细金竖条锚点 + 标题/小字 + 右侧「距结束 xx:xx:xx」。
  ///   后台关掉 / 未配置 = 整块不渲染。倒计时走每秒 setState 的 _promoTick。
  Widget _promoBanner() {
    final cfg = SoftService.instance.cachedConfig?.promo;
    if (cfg == null || !cfg.on) return const SizedBox.shrink();
    final title = cfg.title.isNotEmpty ? cfg.title : '限时特惠';
    final end = DateTime.tryParse(cfg.end.replaceFirst(' ', 'T'));
    final hasCountdown = end != null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: context.isDark
              ? const Color(0xFF141210)
              : const Color(0xFF17130C),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(context.isDark ? 90 : 46),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧细金竖条（锚点，替代大图标）
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                gradient: Deco.goldGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE8CE93),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                  ),
                  if (cfg.tip.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      cfg.tip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFE8CE93).withAlpha(120),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasCountdown)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '距结束',
                    style: TextStyle(
                      color: const Color(0xFFE8CE93).withAlpha(110),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _promoCountdown(end),
                    style: const TextStyle(
                      color: Color(0xFFE8CE93),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _promoCountdown(DateTime end) {
    final d = end.difference(DateTime.now());
    if (d.isNegative) return '已结束';
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return d.inDays > 0 ? '${d.inDays}天$hh:$mm:$ss' : '$hh:$mm:$ss';
  }

  /// 顶部 VIP PRO 头卡（渐变金卡 + 权益图标行）
  Widget _buildHeaderCard() {
    final isDark = context.isDark;
    final benefits = const [
      (Icons.download_done_rounded, '无限下载'),
      (Icons.bolt_rounded, '极速通道'),
      (Icons.verified_rounded, '专属标识'),
      (Icons.support_agent_rounded, '优先客服'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        // 金色渐变 Hero（Deco.goldGradient 为 const 渐变，不可再包 const）
        gradient: Deco.goldGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: C.gold.withAlpha(isDark ? 60 : 70),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF241F18),
                  borderRadius: BorderRadius.circular(R.full),
                ),
                child: const Text(
                  'VIP PRO',
                  style: TextStyle(
                    color: Color(0xFFF7D57A),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFF241F18),
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ★ 1031：已是会员 → 标题变「您已是尊贵会员」，副行显示到期时间
          Builder(
            builder: (_) {
              final u = UserService.instance.user;
              final isVip = u?.isVipActive ?? false;
              if (!isVip) {
                return const Text(
                  '解锁完整软件库体验',
                  style: TextStyle(
                    color: Color(0xFF241F18),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                );
              }
              final exp = _vipExpireText();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '您已是尊贵会员',
                    style: TextStyle(
                      color: Color(0xFF241F18),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (exp.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '有效期至 $exp · 续费可在到期时间上顺延',
                      style: TextStyle(
                        color: const Color(0xFF241F18).withAlpha(190),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '会员资源、专属标识、优先服务一次开通，所有套餐均自动对接后台价格。',
            style: TextStyle(
              color: const Color(0xFF241F18).withAlpha(190),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          // 权益图标行（Row 全 Expanded，符合红线）
          Row(
            children: [
              for (int i = 0; i < benefits.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(90),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          benefits[i].$1,
                          size: 19,
                          color: const Color(0xFF241F18),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        benefits[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF241F18),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 套餐卡片（v55：中档「最受欢迎」角标 + 视觉放大 + 划线原价）
  Widget _buildPlanCard(int index) {
    final plan = _plans[index];
    final selected = _selectedPlan == index;
    final popular = index == 1; // 中间档 = 最受欢迎
    // ★ 1031：促销开着时整排统一多留 7px 顶部让位带（角签只画在参与卡上），
    //   保证同一排三张卡的套餐名永远水平对齐，不会歪歪扭扭
    final hasFlag = _promoHit(index);
    final promoOn = SoftService.instance.cachedConfig?.promo.on ?? false;
    return AppPressable(
      onTap: () => setState(() => _selectedPlan = index),
      child: Transform.scale(
        // 中间档视觉放大（Transform 不参与布局计算，不会触发重排循环）
        scale: popular ? 1.05 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.fromLTRB(
            6,
            (popular ? 22 : 18) + (promoOn ? 7 : 0),
            6,
            18,
          ),
          decoration: BoxDecoration(
            color: selected
                ? (context.isDark ? C.bg3 : C.gold.withAlpha(18))
                : (context.isDark ? C.bg2 : Colors.white),
            borderRadius: BorderRadius.circular(popular ? 16 : 12),
            border: Border.all(
              color: selected
                  ? C.gold
                  : (popular ? C.gold.withAlpha(90) : Colors.transparent),
              width: popular ? 1.6 : 1.5,
            ),
            boxShadow: popular
                ? [
                    BoxShadow(
                      color: C.gold.withAlpha(context.isDark ? 50 : 30),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.small.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: context.t1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '¥',
                        style: Ty.small.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: C.accentOrange,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          plan.money,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.h1.copyWith(
                            fontSize: popular ? 24 : 21,
                            color: C.accentOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // 划线原价 + 促销套餐加「立省 xx」（参与 = 现价 × 后台倍数；未参与 = ×1.5 锚点价）
                  Builder(builder: (_) {
                    final hit = _promoHit(index);
                    final save = _promoSave(plan.money, promo: hit);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            '¥${_origPrice(plan.money, promo: hit)}',
                            maxLines: 1,
                            style: Ty.tiny.copyWith(
                              color: context.t3,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: context.t3,
                            ),
                          ),
                        ),
                        if (hit && save != null) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF17130C),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '立省$save',
                              style: const TextStyle(
                                color: Color(0xFFE8CE93),
                                fontSize: 8.5,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ),
              // 「最受欢迎」角标（中档）；与促销角签同现时让位给角签（防重叠）
              if (popular && !hasFlag)
                Positioned(
                  top: -10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: Deco.goldGradient,
                        borderRadius: BorderRadius.circular(R.full),
                        boxShadow: [
                          BoxShadow(
                            color: C.gold.withAlpha(70),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        '最受欢迎',
                        style: TextStyle(
                          color: Color(0xFF241F18),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              // ★ 1031 促销角签（右上角小旗）：后台可勾选单套餐参与
              if (_promoHit(index))
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF17130C),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                    child: Text(
                      _planPromoLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE8CE93),
                        fontSize: 9.5,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ★ 1031 「立省」金额 = 划线价 − 现价，取整去掉拖尾 .00（促销套餐才显示）
  String? _promoSave(String money, {bool promo = false}) {
    if (!promo) return null;
    final v = double.tryParse(money);
    if (v == null) return null;
    final orig = v * (SoftService.instance.cachedConfig?.promo.mul ?? 2);
    final save = orig - v;
    if (save <= 0) return null;
    return save == save.roundToDouble()
        ? save.toInt().toString()
        : save.toStringAsFixed(save * 10 % 1 == 0 ? 1 : 2);
  }

  /// 展示用划线原价：促销时按后台倍数，未促销时 ×1.5 锚点价（仅展示，不参与下单）
  String _origPrice(String money, {bool promo = false}) {
    final v = double.tryParse(money);
    if (v == null) return money;
    var mul = 1.5;
    final cfg = SoftService.instance.cachedConfig?.promo;
    if (promo && cfg != null && cfg.mul > 1) mul = cfg.mul;
    return (v * mul).toStringAsFixed(2);
  }

  /// 支付方式项
  Widget _buildPayItem(int index, String label, IconData icon) {
    final on = _methodOn(index);
    final selected = _payMethod == index && on;
    final accent = C.brand;
    return Expanded(
      child: Opacity(
        opacity: on ? 1 : 0.4,
        child: GestureDetector(
          onTap: on
              ? () => setState(() => _payMethod = index)
              : () => ToastUtil.info('该支付方式暂未开放'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? accent.withAlpha(context.isDark ? 38 : 22)
                  : (context.isDark ? C.bg2 : Colors.white),
              borderRadius: BorderRadius.circular(R.sm),
              border: Border.all(
                color: selected
                    ? accent.withAlpha(150)
                    : (context.isDark
                          ? Colors.white.withAlpha(22)
                          : Colors.black.withAlpha(20)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? accent : context.t3),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Ty.small.copyWith(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? accent : context.t2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: C.gold),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Ty.body.copyWith(fontSize: 13.5))),
        ],
      ),
    );
  }

  /// 下单 → 打开收银台 → 轮询支付结果 → 刷新会员状态
  Future<void> _onBuy() async {
    if (_submitting) return;
    if (!UserService.instance.isLoggedIn) {
      ToastUtil.info('请先登录后再开通会员');
      Get.toNamed('/login');
      return;
    }
    if (!_payEnabled) {
      ToastUtil.info('支付功能暂未开启，请联系管理员');
      return;
    }
    final plan = _plans[_selectedPlan];
    final payType = ['alipay', 'wxpay', 'qqpay'][_payMethod];

    // ★ 需求3：支付确认弹窗（美化版，后台 ui_config.pay_notice 可配；
    //   enabled=0 时 confirm() 内部直接放行）
    final methodLabel = ['支付宝', '微信', 'QQ'][_payMethod];
    final confirmed = await PayNoticeDialog.confirm(
      amount: plan.money,
      methodLabel: methodLabel,
      methodIcon: ['alipay', 'wxpay', 'qqpay'].indexOf(payType) == 0
          ? Icons.account_balance_wallet_rounded
          : (payType == 'wxpay'
                ? Icons.chat_bubble_rounded
                : Icons.pets_rounded),
    );
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      final order = await PayService.instance.create(
        planId: plan.id,
        payType: payType,
      );
      if (order.payUrl.isEmpty) {
        ToastUtil.error('下单失败，请稍后重试');
        return;
      }
      // ★ App 内打开收银台（不跳转外部浏览器）
      Get.toNamed(
        '/payWeb',
        arguments: {
          'pay_url': order.payUrl,
          'out_trade_no': order.outTradeNo,
          'money': order.money,
        },
      );
      if (mounted) setState(() => _submitting = false);
      return;
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted && _submitting) setState(() => _submitting = false);
    }
  }
}
