import 'package:flutter/material.dart';

/// 全局主题配色方案
///
/// ★ 需求（v43 #1）：外观修改要能**全局**生效，不只是列表样式。
///
/// 提供一个「模板」概念：一套配色方案 = 品牌主色 + 强调色，
/// 切换后全 App 的按钮、渐变、光晕、选中态都会跟着变。
class ThemePalette {
  final String key;
  final String name;
  final String desc;
  final Color brand;
  final Color brandBright;
  final Color brandDeep;
  final Color accent; // 次要强调色（渐变用）

  const ThemePalette({
    required this.key,
    required this.name,
    required this.desc,
    required this.brand,
    required this.brandBright,
    required this.brandDeep,
    required this.accent,
  });

  /// 内置配色方案
  static const List<ThemePalette> all = [
    ThemePalette(
      key: 'aurora',
      name: '极光蓝紫',
      desc: '经典品牌色（默认）',
      brand: Color(0xFF4B5EF5),
      brandBright: Color(0xFF6E7DFF),
      brandDeep: Color(0xFF3A4BD8),
      accent: Color(0xFFA78BFA),
    ),
    ThemePalette(
      key: 'ocean',
      name: '深海青',
      desc: '清爽的蓝绿调',
      brand: Color(0xFF0891B2),
      brandBright: Color(0xFF22D3EE),
      brandDeep: Color(0xFF0E7490),
      accent: Color(0xFF34D399),
    ),
    ThemePalette(
      key: 'sunset',
      name: '落日橙',
      desc: '温暖的橙红调',
      brand: Color(0xFFF97316),
      brandBright: Color(0xFFFB923C),
      brandDeep: Color(0xFFEA580C),
      accent: Color(0xFFFBBF24),
    ),
    ThemePalette(
      key: 'forest',
      name: '森野绿',
      desc: '自然的绿色调',
      brand: Color(0xFF059669),
      brandBright: Color(0xFF34D399),
      brandDeep: Color(0xFF047857),
      accent: Color(0xFF84CC16),
    ),
    ThemePalette(
      key: 'sakura',
      name: '樱花粉',
      desc: '柔和的粉紫调',
      brand: Color(0xFFEC4899),
      brandBright: Color(0xFFF472B6),
      brandDeep: Color(0xFFDB2777),
      accent: Color(0xFFA78BFA),
    ),
    ThemePalette(
      key: 'midnight',
      name: '午夜紫',
      desc: '深邃的紫罗兰',
      brand: Color(0xFF7C3AED),
      brandBright: Color(0xFFA78BFA),
      brandDeep: Color(0xFF6D28D9),
      accent: Color(0xFF22D3EE),
    ),
    ThemePalette(
      key: 'crimson',
      name: '烈焰红',
      desc: '饱满的红色调',
      brand: Color(0xFFDC2626),
      brandBright: Color(0xFFEF4444),
      brandDeep: Color(0xFFB91C1C),
      accent: Color(0xFFF59E0B),
    ),
    ThemePalette(
      key: 'graphite',
      name: '石墨灰',
      desc: '低调的黑白灰',
      brand: Color(0xFF374151),
      brandBright: Color(0xFF6B7280),
      brandDeep: Color(0xFF1F2937),
      accent: Color(0xFF9CA3AF),
    ),
  ];

  static ThemePalette byKey(String? k) {
    for (final p in all) {
      if (p.key == k) return p;
    }
    return all.first;
  }

  /// 品牌渐变（按钮 / 渐变头图用）
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, accent],
  );

  /// 极光渐变（标题 ShaderMask 用，三色更长）
  LinearGradient get aurora => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBright, accent, brand],
  );
}
