import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'buttons.dart';
import 'lucide.dart';
import 'ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// 1109：全局基础组件
///   统一空状态 / 分区标题 / 统计块 / 卡片 / 确认弹窗
///   目的：把散落各页的「裸 Container + Text」收敛成一套视觉语言
/// ═══════════════════════════════════════════════════════════════

/// 空状态：渐变圆托 + 图标 + 标题 + 副标题 + 可选操作
class AppEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final double iconSize;

  const AppEmpty({
    super.key,
    this.icon = Lz.inbox,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.iconSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  C.brand.withAlpha(dark ? 46 : 26),
                  C.violet.withAlpha(dark ? 30 : 16),
                ],
              ),
              border: Border.all(
                color: C.brand.withAlpha(dark ? 40 : 22),
                width: 1,
              ),
            ),
            child: Icon(icon, size: iconSize, color: C.brand.withAlpha(dark ? 220 : 190)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: context.t1,
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.6, color: context.t3),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            AppBtn(actionLabel!, onTap: onAction, icon: actionIcon),
          ],
        ],
      ),
    );
  }
}

/// 分区标题：左侧品牌竖条 + 标题 + 右侧说明/操作
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTrailing;
  final EdgeInsets padding;

  const AppSectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.icon,
    this.color,
    this.onTrailing,
    this.padding = const EdgeInsets.fromLTRB(0, 16, 0, 10),
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.brand;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c, c.withAlpha(150)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          if (icon != null) ...[
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.t1,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Row(children: [
                Text(trailing!,
                    style: TextStyle(fontSize: 11.5, color: context.t3)),
                if (onTrailing != null)
                  Icon(Lz.chevronRight, size: 12, color: context.t3),
              ]),
            ),
        ],
      ),
    );
  }
}

/// 统计块（后台/个人页顶部小卡）
class AppStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  const AppStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final color = this.color ?? C.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: dark ? C.bg2 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? C.bg3 : C.lbg2),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withAlpha(dark ? 40 : 22),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: context.t1,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: context.t3)),
        ],
      ),
    );
  }
}

/// 通用卡片：统一圆角/描边/阴影（深色不投影）
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 10),
    this.onTap,
    this.radius = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (dark ? C.bg2 : Colors.white),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: dark ? C.bg3 : Colors.transparent, width: 1),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withAlpha(9),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
              ],
      ),
      child: child,
    );
    return Container(
      margin: margin,
      child: onTap == null
          ? body
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: body),
              ),
            ),
    );
  }
}

/// 统一的确认弹窗（危险操作标红按钮）
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String okText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final r = await Get.dialog<bool>(
    Dialog(
      backgroundColor: dark ? C.bg2 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (danger ? C.danger : C.brand).withAlpha(dark ? 44 : 22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  danger ? Lz.alertTriangle : Lz.info,
                  size: 18,
                  color: danger ? C.danger : C.brand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: dark ? C.t1 : C.lt1)),
              ),
            ]),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message,
                  style: TextStyle(
                      fontSize: 13.5, height: 1.6, color: dark ? C.t2 : C.lt2)),
            ],
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: AppBtn(cancelText,
                    onTap: () => Get.back(result: false), ghost: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppBtn(okText,
                    onTap: () => Get.back(result: true), danger: danger),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
  return r == true;
}
