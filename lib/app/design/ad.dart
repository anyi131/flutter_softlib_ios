import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// Ad —— 全局自适应尺寸（1015 新增）
///
/// 解决：原来 194 处写死 width/height，在窄屏撑破、宽屏留白
///
/// 用法：
///   Ad.h(context, 200)   → 按屏幕宽度比例缩放的「高度」
///   Ad.w(context, 148)   → 按屏幕宽度比例缩放的「宽度」
///   Ad.sp(context, 14)   → 字号
///   Ad.s(context, 12)    → 间距
///
/// 基准：设计稿宽 390（iPhone 14 / 主流安卓）
/// ═══════════════════════════════════════════════════════════════
class Ad {
  Ad._();

  /// 设计基准宽度
  static const double base = 390;

  /// 缩放比例（0.82 ~ 1.15，避免极端屏型变形过大）
  static double _k(BuildContext c) {
    final w = MediaQuery.of(c).size.width;
    return (w / base).clamp(0.82, 1.15);
  }

  /// 宽度：按屏幕等比缩放
  static double w(BuildContext c, double v) => v * _k(c);

  /// 高度：竖向尺寸用宽度比例（避免横竖屏切换抖动）
  static double h(BuildContext c, double v) => v * _k(c);

  /// 间距
  static double s(BuildContext c, double v) => v * _k(c);

  /// 字号（限制缩放幅度，防止字号过大/过小影响阅读）
  static double sp(BuildContext c, double v) {
    final k = (MediaQuery.of(c).size.width / base).clamp(0.9, 1.12);
    return v * k;
  }

  /// 屏幕宽度百分比
  static double wp(BuildContext c, double p) =>
      MediaQuery.of(c).size.width * p / 100;

  /// 屏幕高度百分比
  static double hp(BuildContext c, double p) =>
      MediaQuery.of(c).size.height * p / 100;

  /// 安全宽度（左右各留一点，不贴边）
  static double safeWidth(BuildContext c, {double min = 0, double max = 9999}) {
    final w = MediaQuery.of(c).size.width;
    return (w - 24).clamp(min, max);
  }

  /// 根据屏幕宽度决定列数（列表/网格自适应）
  static int columns(BuildContext c, {double minItem = 100, int max = 6}) {
    final w = MediaQuery.of(c).size.width - 28;
    final n = (w / minItem).floor();
    return n.clamp(2, max);
  }
}
