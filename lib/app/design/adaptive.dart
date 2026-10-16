import 'package:flutter/material.dart';

/// 屏幕自适应工具
///
/// 解决：不同尺寸/比例设备上布局挤压、文字溢出、间距不协调
extension Adaptive on BuildContext {
  // ★★ 1016 关键修复：这里原来用的是 MediaQuery.of(this)，
  //   一旦当前 context 没有 MediaQuery 祖先（GetBuilder 重建、Overlay、
  //   页面切换的过渡帧等）就会抛「Null check operator used on a null value」，
  //   而且是**在 build 阶段抛** → 整块 UI 变成错误页（真机日志里就是这么报的）。
  //   改成 maybeOf + 兜底默认值：拿不到也用合理值继续渲染，绝不崩。
  MediaQueryData? get _mq => MediaQuery.maybeOf(this);

  /// 屏幕宽（拿不到时按常见手机宽度兜底）
  double get sw => _mq?.size.width ?? 390;

  /// 屏幕高
  double get sh => _mq?.size.height ?? 844;

  /// 底部安全区
  double get safeBottom => _mq?.padding.bottom ?? 0;
  double get safeTop => _mq?.padding.top ?? 0;

  /// 设备类型
  bool get isCompact => sw < 360; // 小屏
  bool get isSmall => sw < 400; // 常见手机
  bool get isWide => sw >= 600; // 平板/折叠展开

  /// 按屏宽缩放的数值（基准 390）
  double sp(double v, {double min = 0.85, double max = 1.15}) {
    final r = (sw / 390).clamp(min, max);
    return v * r;
  }

  /// 字体缩放（限制上限，避免系统字体过大导致溢出）
  double get fontScale =>
      (_mq?.textScaler.scale(1.0) ?? 1.0).clamp(0.9, 1.2);

  /// 卡片横向间距（小屏收窄）
  double get pagePadding => isCompact ? 14 : (isWide ? 28 : 18);

  /// 网格列数（按屏宽自适应）
  int get gridCols {
    if (sw >= 900) return 4;
    if (sw >= 600) return 3;
    return 2;
  }

  /// 服务宫格列数
  int get serviceCols => isCompact ? 3 : 4;

  /// 底部 Tab 需要的留白
  double get tabSpace => 74 + safeBottom;
}

/// 自适应网格代理
class AdaptiveGrid {
  AdaptiveGrid._();

  /// 推荐区网格
  static SliverGridDelegate referral(BuildContext c) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: c.isWide ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: c.isCompact ? 1.15 : 1.32,
      );
}

/// 防止文字溢出的小工具
Widget ellipsis(String text,
    {int maxLines = 1, TextStyle? style, TextAlign? align}) {
  return Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    textAlign: align,
    style: style,
  );
}
