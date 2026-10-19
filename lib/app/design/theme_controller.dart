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
