import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/soft_service.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../models/ui_config.dart';

/// 支付确认弹窗（美化版，替代系统风格弹窗）
///
/// 设计：品牌渐变头 + 金额大字高亮 + 支付方式徽标 + 说明分组卡片 + 渐变主按钮
/// 文案后台可配（ui_config.pay_notice），enabled=0 时调用方直接跳过弹窗。
class PayNoticeDialog extends StatelessWidget {
  const PayNoticeDialog({
    super.key,
    required this.notice,
    required this.amount,
    required this.methodLabel,
    this.methodIcon = Icons.account_balance_wallet_rounded,
  });

  final PayNoticeConfig notice;
  final String amount;
  final String methodLabel;
  final IconData methodIcon;

  /// 读取当前生效配置并弹出；返回 true = 用户确认继续支付
  /// 返回 false 或 null = 取消/跳过
  static Future<bool> confirm({
    required String amount,
    required String methodLabel,
    IconData methodIcon = Icons.account_balance_wallet_rounded,
  }) async {
    final cfg = SoftService.instance.cachedConfig?.uiConfig;
    final raw = cfg?.payNotice ?? const PayNoticeConfig();
    if (!raw.enabled) return true; // 后台关闭 → 直接支付
    final notice = raw.withDefaults(); // 文案空 → 内置默认
    final r = await Get.dialog<bool>(
      PayNoticeDialog(
        notice: notice,
        amount: amount,
        methodLabel: methodLabel,
        methodIcon: methodIcon,
      ),
      barrierDismissible: false,
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cardBg = isDark ? C.bg1 : Colors.white;
    final dialogBg = isDark ? C.bg2 : Colors.white;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 90 : 40),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 品牌渐变头 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: const BoxDecoration(gradient: Deco.brandGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notice.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (notice.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      notice.subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: Colors.white.withAlpha(215),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── 金额大字高亮 ──
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '支付金额',
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '¥',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: C.gold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              amount.isEmpty ? '--' : amount,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: C.gold,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // ── 支付方式徽标 ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(14)
                                : C.brand.withAlpha(18),
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(methodIcon, size: 15, color: C.brand),
                              const SizedBox(width: 6),
                              Text(
                                '支付方式：$methodLabel',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? context.t1 : C.brand,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── 说明分组卡片 ──
                  _noteCard(
                    context,
                    cardBg,
                    Icons.language_rounded,
                    '网站支付',
                    notice.cardNote,
                  ),
                  const SizedBox(height: 10),
                  _noteCard(
                    context,
                    cardBg,
                    Icons.smartphone_rounded,
                    'APP 支付',
                    notice.appNote,
                  ),
                  const SizedBox(height: 18),
                  // ── 渐变主按钮 ──
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: Deco.brandGradient,
                        borderRadius: BorderRadius.circular(R.full),
                        boxShadow: [
                          BoxShadow(
                            color: C.brand.withAlpha(isDark ? 70 : 60),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(R.full),
                          onTap: () => Navigator.of(context).pop(true),
                          child: Center(
                            child: Text(
                              notice.button,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        '再想想',
                        style: Ty.tiny.copyWith(color: context.t3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteCard(
    BuildContext context,
    Color bg,
    IconData icon,
    String title,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withAlpha(12)
              : Colors.black.withAlpha(10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: C.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: context.t1,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: Ty.tiny.copyWith(color: context.t3, height: 1.55),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
