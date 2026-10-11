import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../api/pay_service.dart';
import '../../api/user_service.dart';
import '../../utils/toast_util.dart';
import '../../routes/app_pages.dart';
import '../vip_center/pay_notice_dialog.dart';

/// 余额充值（与「开通会员」完全分开的独立页面）
class RechargePage extends StatefulWidget {
  const RechargePage({super.key});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final _amtCtrl = TextEditingController();
  final _svc = PayService.instance;

  List<PayPlan> _plans = [];
  bool _loading = true;
  bool _enabled = false;
  bool _busy = false;
  String _payType = 'alipay';
  Map<String, bool> _methods = {};
  double? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _svc.rechargePlans();
      if (!mounted) return;
      setState(() {
        _plans = r.plans;
        _enabled = r.enabled;
        _methods = r.methods;
        _loading = false;
        if (_plans.isNotEmpty) {
          _selected = double.tryParse(_plans.first.money);
          _amtCtrl.text = _plans.first.money;
        }
        for (final k in ['alipay', 'wxpay', 'qqpay']) {
          if (_methods[k] == true) {
            _payType = k;
            break;
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (amt < 1) {
      ToastUtil.info('最低充值 1 元');
      return;
    }
    if (!_enabled) {
      ToastUtil.info('支付功能未开启');
      return;
    }
    setState(() => _busy = true);
    try {
      // ★ 需求3：支付确认弹窗（美化版，后台 pay_notice 可配）
      final confirmed = await PayNoticeDialog.confirm(
        amount: amt.toStringAsFixed(2),
        methodLabel:
            {'alipay': '支付宝', 'wxpay': '微信', 'qqpay': 'QQ'}[_payType] ??
            _payType,
        methodIcon: _payType == 'wxpay'
            ? Icons.chat_bubble_rounded
            : (_payType == 'qqpay'
                  ? Icons.pets_rounded
                  : Icons.account_balance_wallet_rounded),
      );
      if (!mounted) return;
      if (!confirmed) {
        setState(() => _busy = false);
        return;
      }
      final url = await _svc.createRecharge(
        money: amt.toStringAsFixed(2),
        payType: _payType,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await Get.toNamed(
        Routes.payWeb,
        arguments: {
          'pay_url': url,
          'title': '余额充值',
          'money': amt.toStringAsFixed(2),
          'onReturn': () async {
            await UserService.instance.refreshProfile();
          },
        },
      );
      await UserService.instance.refreshProfile();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final me = UserService.instance.user;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          if (_loading)
            const LoadingState(text: '加载充值配置…')
          else
            ListView(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                topInset + 60,
                context.pagePadding,
                30,
              ),
              children: [
                _balanceCard(me?.money ?? '0.00'),
                const SizedBox(height: 14),
                if (_plans.isNotEmpty) ...[
                  const SectionHeader(title: '选择充值金额', accent: C.mint),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _plans.map((p) {
                      final v = double.tryParse(p.money) ?? 0;
                      final sel = _selected == v;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selected = v;
                          _amtCtrl.text = p.money;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            gradient: sel ? Deco.brandGradient : null,
                            color: sel ? null : context.cardBg,
                            borderRadius: BorderRadius.circular(R.md),
                            border: sel ? null : Border.all(color: C.stroke),
                          ),
                          child: Text(
                            '¥${p.money}',
                            style: Ty.h3.copyWith(
                              fontSize: 15,
                              color: sel ? Colors.white : context.t1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                SectionHeader(title: '自定义金额', accent: C.brand),
                const SizedBox(height: 10),
                TextField(
                  controller: _amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    prefixText: '¥ ',
                    hintText: '输入充值金额',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.md),
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _selected = double.tryParse(v)),
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: '支付方式', accent: C.violet),
                const SizedBox(height: 10),
                KitCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _payChip(
                        '支付宝',
                        'alipay',
                        Icons.account_balance_wallet_rounded,
                      ),
                      const SizedBox(width: 10),
                      _payChip('微信', 'wxpay', Icons.chat_rounded),
                      const SizedBox(width: 10),
                      _payChip('QQ', 'qqpay', Icons.pets_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: '立即充值',
                  icon: Icons.account_balance_wallet_rounded,
                  height: 52,
                  loading: _busy,
                  onPressed: _enabled ? _submit : null,
                ),
                if (!_enabled) ...[
                  const SizedBox(height: 10),
                  Text(
                    '支付功能未开启，请联系管理员',
                    textAlign: TextAlign.center,
                    style: Ty.tiny.copyWith(color: C.warning),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  '余额可用于购买会员或站内消费。充值即时到账，'
                  '如遇问题请到「QQ通知群」联系客服。',
                  style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
                ),
              ],
            ),
          _topBar(topInset),
        ],
      ),
    );
  }

  Widget _balanceCard(String money) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: Deco.brandGradient,
        borderRadius: BorderRadius.circular(R.lg),
        boxShadow: [
          BoxShadow(
            color: C.brand.withAlpha(90),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('当前余额', style: Ty.small.copyWith(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '¥$money',
            style: Ty.display.copyWith(color: Colors.white, fontSize: 30),
          ),
        ],
      ),
    );
  }

  Widget _payChip(String label, String value, IconData icon) {
    final sel = _payType == value;
    final ok = _methods[value] == true;
    return Expanded(
      child: GestureDetector(
        onTap: ok ? () => setState(() => _payType = value) : null,
        child: Opacity(
          opacity: ok ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              gradient: sel ? Deco.brandGradient : null,
              color: sel ? null : (context.isDark ? C.bg3 : C.lbg2),
              borderRadius: BorderRadius.circular(R.md),
              border: sel ? null : Border.all(color: C.stroke),
            ),
            child: Column(
              children: [
                Icon(icon, size: 19, color: sel ? Colors.white : context.t2),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Ty.tiny.copyWith(
                    color: sel ? Colors.white : context.t2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(double topInset) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(
          top: topInset + 8,
          left: 12,
          right: 12,
          bottom: 8,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: Get.back,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.isDark ? C.bg2 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.stroke),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: context.t1,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '充值余额',
              style: Ty.h3.copyWith(color: context.t1, fontSize: 15),
            ),
            const Spacer(),
            const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }
}
