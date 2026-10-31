import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_palette.dart';
import 'ui.dart';

/// 主题控制器
///
/// 管两件事：
///   ① 明暗模式（浅色 / 深色 / 跟随系统）
///   ② **全局配色方案**（品牌主色模板）—— 需求 v43 #1
///
/// 切换配色方案时，会改写 `C.brand` 等可变静态色，
/// 并刷新 `rebuildTick` 触发全 App 重建，实现「全局生效」。
class ThemeController extends GetxController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'app_theme_mode';
  static const _keyPalette = 'app_theme_palette';

  final Rx<ThemeMode> mode = ThemeMode.light.obs;
  final Rx<ThemePalette> palette = ThemePalette.all.first.obs;

  /// 每次切换配色方案 +1，作为全 App 重建的信号
  final RxInt rebuildTick = 0.obs;

  //   后台下发 theme_palette=wallpaper 且平台支持时启用；
  //   平台色由 main.dart 的 DynamicColorBuilder 捕获后灌进来。
  static const wallpaperKey = 'wallpaper';
  ColorScheme? _androidScheme;
  ColorScheme? _iosScheme;

  /// 由 DynamicColorBuilder 回调注入平台动态色
  void setDynamicSchemes({ColorScheme? android, ColorScheme? ios}) {
    _androidScheme = android;
    _iosScheme = ios;
    if (palette.value.key == wallpaperKey) _applyWallpaper();
  }

  /// 平台是否真的支持动态取色
  bool get dynamicAvailable =>
      palette.value.key == wallpaperKey &&
      (_androidScheme != null || _iosScheme != null);

  void _applyWallpaper() {
    final s = _androidScheme ?? _iosScheme;
    if (s == null) {
      // 平台不支持（如老安卓/iOS<17）→ 落回默认蓝紫
      _applyPalette(ThemePalette.byKey(null));
      return;
    }
    final b = s.primary;
    final bb = Color.lerp(b, Colors.white, .22)!;
    final bd = Color.lerp(b, Colors.black, .22)!;
    C.applyPalette(b: b, bb: bb, bd: bd, ac: s.secondary == b ? bb : s.secondary);
    palette.value = ThemePalette.all.firstWhere(
      (p) => p.key == wallpaperKey,
      orElse: () => ThemePalette.all.first,
    );
    // ★ 自包含：动态色晚到时也要触发全 App 重建（setDynamicSchemes 入口）
    rebuildTick.value++;
  }

  Future<void> restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final v = sp.getString(_key);
      mode.value = switch (v) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
      // ★ 配色不再由用户本地决定，启动时先用默认，
      //   拿到后台配置后再 applyServerPalette()
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key, switch (m) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        _ => 'light',
      });
    } catch (_) {}
  }

  /// 应用后台下发的配色方案（★ 由管理员控制，用户不可自行切换）
  /// 只在确实变化时才刷新，避免每次启动都全量重建。
  void applyServerPalette(String? key) {
    // ★ 1031r：动态取色配色——优先吃平台壁纸色
    if (key == wallpaperKey) {
      if (palette.value.key == wallpaperKey) return;
      _applyWallpaper(); // 内部已 rebuildTick++
      return;
    }
    final p = ThemePalette.byKey(key);
    if (p.key == palette.value.key) return;
    _applyPalette(p);
    rebuildTick.value++;
  }

  void _applyPalette(ThemePalette p) {
    palette.value = p;
    C.applyPalette(
      b: p.brand,
      bb: p.brandBright,
      bd: p.brandDeep,
      ac: p.accent,
    );
    // 同步旧别名（app_theme.dart 的 AppColor）—— 内部转发同源，无需额外处理
  }

  String get label => switch (mode.value) {
    ThemeMode.dark => '深色',
    ThemeMode.system => '跟随系统',
    _ => '浅色',
  };
}
