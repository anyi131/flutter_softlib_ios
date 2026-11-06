import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'ui.dart';
import 'lucide.dart';

/// ★ 1105u Lottie 通用播放组件
///
/// · 默认用 assets/lottie/loading.json（旋转环），可换任意 Lottie 文件
/// · [tint] 不为空时整体染色（Lottie 素材是单色时靠它跟随主题）
/// · 资源缺失/解析失败自动降级成静态图标，不会白屏
class LottieBox extends StatelessWidget {
  const LottieBox({
    super.key,
    this.asset = 'assets/lottie/loading.json',
    this.size = 28,
    this.tint,
    this.repeat = true,
    this.fallbackIcon,
  });

  final String asset;
  final double size;
  final Color? tint;
  final bool repeat;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    Widget anim = Lottie.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      repeat: repeat,
      errorBuilder: (_, __, ___) => Icon(
        fallbackIcon ?? Lz.refresh,
        size: size * 0.8,
        color: tint ?? C.brand,
      ),
    );
    if (tint != null) {
      anim = ColorFiltered(
        colorFilter: ColorFilter.mode(tint!, BlendMode.srcIn),
        child: anim,
      );
    }
    return SizedBox(width: size, height: size, child: anim);
  }
}
