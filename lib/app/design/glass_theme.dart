import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// 全局玻璃主题（Liquid Glass）—— 含**自动降级**
///
/// 背景（用户反馈 #4）：
///   只有底部导航是液态玻璃，上面全是实心白卡 → 风格断层。
///   这里把「玻璃感」做成全局资产：卡片 / 顶栏 / 弹窗 / 底栏 统一走 Glass。
///
/// ★★ 性能红线（安卓上尤其重要）：
///   BackdropFilter 每次都要「把背后整块重绘 + 高斯模糊」，
///   玻璃卡片大范围铺开会直接掉帧，甚至卡死（302 个工具图标那类网格尤其危险）。
///   所以这里分两层：
///     - 大容器（导航栏/头图/弹窗/BottomSheet）→ 真模糊
///     - 卡片（列表项，数量多）→ 只做「半透明 + 高光描边 + 极淡渐变」，
///       视觉上是玻璃，性能开销几乎为零（不加 BackdropFilter）
///
/// ★★ 自动降级：
///   启动时探测设备能力 → 决定玻璃档位。用户也可在后台/设置里强制指定。
///   - high   : 真模糊 + 玻璃卡片（旗舰/中高端）
///   - medium : 真模糊只用于导航栏与弹窗，卡片纯半透明（中端，默认）
///   - low    : 全部退化为「近实心 + 细描边」（低端/老系统/省电模式）
/// ═══════════════════════════════════════════════════════════════
enum GlassLevel {
  /// 关闭玻璃（后台可强制）
  off,

  /// 低端：近实心 + 细描边，零模糊
  low,

  /// 中端（默认）：导航/弹窗用真模糊，卡片半透明
  medium,

  /// 高端：全量玻璃
  high,
}

class GlassTheme {
  GlassTheme._();

  /// 当前生效档位（启动时由 [init] 决定，也可后台覆盖）
  static GlassLevel _level = GlassLevel.medium;
  static GlassLevel get level => _level;

  /// 是否用户/后台强制过（强制后自动降级不再改写）
  static bool _locked = false;
  static bool get locked => _locked;

  /// 探测到的设备信息（后台「关于」可以展示，便于排查卡顿反馈）
  static String deviceHint = '';

  static bool get enabled => _level != GlassLevel.off;
  static bool get isDarkMode => false;

  /// 卡片是否允许真模糊
  ///
  /// ★★ 1020 修复「字体发虚」：
  ///   之前 high 档给**每张卡片**套 BackdropFilter。BackdropFilter 会把
  ///   卡片内的内容（包括文字）一起纳入模糊采样，在高分屏上表现为
  ///   「文字边缘发灰、整体不清晰」—— 用户反馈的就是这个。
  ///
  ///   现在：**卡片一律不做真模糊**，只用「半透明 + 高光边 + 极淡渐变」
  ///   模拟玻璃质感（观感接近，文字 100% 清晰）。
  ///   真模糊只留给导航栏 / 弹窗 / 头图这类没有正文的大容器。
  static bool get cardBlur => false;

  /// 大容器（导航栏/弹窗/头图）是否允许真模糊
  static bool get bigBlur =>
      _level == GlassLevel.high || _level == GlassLevel.medium;

  /// 模糊强度（sigma）
  static double get sigma => switch (_level) {
    GlassLevel.high => 26,
    GlassLevel.medium => 22,
    _ => 0,
  };

  /// 卡片透明度：档位越高越透
  static double cardOpacity(BuildContext c) {
    final dark = c.isDark;
    switch (_level) {
      case GlassLevel.high:
        return dark ? 0.42 : 0.58;
      case GlassLevel.medium:
        return dark ? 0.72 : 0.84;
      case GlassLevel.low:
        return 1.0;
      case GlassLevel.off:
        return 1.0;
    }
  }

  /// 玻璃卡片底色 = 基础卡片色按透明度叠加（low/off 时完全不透明）
  static Color cardColor(BuildContext c) {
    final base = c.isDark ? const Color(0xFF1A1D26) : Colors.white;
    final a = cardOpacity(c);
    if (a >= 1.0) return base;
    return base.withAlpha((a * 255).round());
  }

  /// 玻璃描边（高光边，比实心卡更亮）
  static Color borderColor(BuildContext c) {
    if (_level == GlassLevel.low || _level == GlassLevel.off) {
      return c.isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12);
    }
    return c.isDark
        ? Colors.white.withAlpha(_level == GlassLevel.high ? 40 : 28)
        : Colors.white.withAlpha(_level == GlassLevel.high ? 210 : 170);
  }

  /// 卡片顶部内高光渐变（模拟玻璃边缘折光）
  static Gradient? edgeGradient(BuildContext c) {
    if (_level == GlassLevel.low || _level == GlassLevel.off) return null;
    final dark = c.isDark;
    final strong = _level == GlassLevel.high;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: const Alignment(0.35, 1.15),
      colors: [
        Colors.white.withAlpha(dark ? (strong ? 34 : 18) : (strong ? 120 : 70)),
        Colors.white.withAlpha(0),
      ],
      stops: const [0.0, 0.62],
    );
  }

  // ───────────────────── 初始化 / 探测 ─────────────────────

  /// 启动时调用一次（main() 里，MediaKit/FlutterBinding 之后）
  /// [serverMode] 后台下发：off/low/medium/high/auto（默认 auto）
  static Future<void> init({String serverMode = 'auto'}) async {
    final probed = await _probe();
    var want = probed;
    final mode = serverMode.trim().toLowerCase();
    switch (mode) {
      case 'off':
      case 'low':
      case 'medium':
      case 'high':
        // 后台强制指定 → 只允许「不高于探测结果」，避免给低端机硬开高配
        _locked = true;
        want = _min(_parse(mode), probed);
        break;
      default:
        _locked = false;
        want = probed;
    }
    _level = want;
    deviceHint = '${Platform.operatingSystem} · $probed · 设定 $mode';
    debugPrint('[Glass] level=$_level ($deviceHint)');
  }

  /// 设置里手动切换（用户可在「我的 → 外观」覆盖，仅本次运行）
  static void setLevel(GlassLevel l) {
    _level = l;
    _locked = true;
  }

  static GlassLevel _parse(String s) => switch (s) {
    'off' => GlassLevel.off,
    'low' => GlassLevel.low,
    'high' => GlassLevel.high,
    _ => GlassLevel.medium,
  };

  static GlassLevel _min(GlassLevel a, GlassLevel b) =>
      a.index <= b.index ? a : b;

  /// 设备能力探测（全部失败也安全回落到 medium）
  static Future<GlassLevel> _probe() async {
    if (kIsWeb) return GlassLevel.medium;
    try {
      // ── ① 安卓系统版本 ──
      if (Platform.isAndroid) {
        int sdk = 0;
        try {
          const ch = MethodChannel('com.soft.anyi/device');
          final v = await ch.invokeMethod<int>('sdkInt');
          sdk = v ?? 0;
        } catch (_) {}
        // 低版本 Android（< 9 / API 28）：Blur 走 GPU 降采样，明显发糊且耗电
        if (sdk > 0 && sdk < 28) return GlassLevel.low;

        // ── ② 内存（低内存机放弃真模糊）──
        final memMb = await _totalMemoryMb();
        if (memMb > 0 && memMb <= 3072) return GlassLevel.low;
        if (memMb > 0 && memMb <= 4096) return GlassLevel.medium;

        // ── ③ 屏幕密度（超高密度 + 大屏 = 像素多，模糊成本高）──
        final w = PlatformDispatcher.instance.views.isNotEmpty
            ? PlatformDispatcher.instance.views.first.physicalSize
            : Size.zero;
        final dpr = PlatformDispatcher.instance.views.isNotEmpty
            ? PlatformDispatcher.instance.views.first.devicePixelRatio
            : 1.0;
        final px = w.width * w.height;
        if (px > 2.5e6 && dpr > 3.0) return GlassLevel.medium; // 2K+ 高分屏
        return GlassLevel.high;
      }

      // ── iOS：Metal 模糊很便宜，按设备内存判断 ──
      final memMb = await _totalMemoryMb();
      if (memMb > 0 && memMb <= 2048) return GlassLevel.low;
      if (memMb > 0 && memMb <= 3072) return GlassLevel.medium;
      return GlassLevel.high;
    } catch (_) {
      return GlassLevel.medium;
    }
  }

  /// 读取总内存（MB，失败返回 0）
  static Future<int> _totalMemoryMb() async {
    try {
      if (Platform.isAndroid) {
        const ch = MethodChannel('com.soft.anyi/device');
        final v = await ch.invokeMethod<int>('totalRamMb');
        if (v != null && v > 0) return v;
      }
      if (Platform.isIOS) {
        // iOS 没有公开 API，用 phys_footprint 上限的近似：机型分档
        final ua = Platform.operatingSystemVersion;
        if (ua.isEmpty) return 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// 运行时再降一级（连续掉帧时由 GlassPerfGuard 调用）
  static void degrade({String reason = ''}) {
    if (_locked) return;
    final next = switch (_level) {
      GlassLevel.high => GlassLevel.medium,
      GlassLevel.medium => GlassLevel.low,
      _ => _level,
    };
    if (next == _level) return;
    _level = next;
    debugPrint('[Glass] 自动降级 → $_level ($reason)');
  }
}
