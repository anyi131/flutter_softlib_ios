import 'package:flutter/material.dart';

/// 软件列表 / 详情页的**多模块样式**
///
/// ★ 需求 #9：软件添加多模块多样式，软件管理后台可切换美化风格。
///
/// 提供 3 种列表风格（后台配置 app_ui_style 下发，用户也可在
/// 「我的 → 外观设置」里覆盖）：
///   glass   —— 玻璃拟态：大圆角卡片 + 光晕（默认，最有质感）
///   compact —— 紧凑列表：一行一款，信息密度高，适合快速浏览
///   grid    —— 双列网格：图标大、视觉冲击强，适合发现
enum AppListStyle {
  glass, // 玻璃卡片（经典）
  compact, // 紧凑列表
  grid, // 双列网格
  large, // 封面大图卡（v52f #9）
  minimal, // 极简单行（v52f #9）
}

extension AppListStyleX on AppListStyle {
  String get label => switch (this) {
    AppListStyle.glass => '玻璃卡片',
    AppListStyle.compact => '紧凑列表',
    AppListStyle.grid => '双列网格',
    AppListStyle.large => '封面大图',
    AppListStyle.minimal => '极简单行',
  };

  String get desc => switch (this) {
    AppListStyle.glass => '大圆角卡片 + 光晕，质感最好',
    AppListStyle.compact => '一行一款，信息密度高',
    AppListStyle.grid => '双列大图标，视觉冲击强',
    AppListStyle.large => '封面截图大图卡，沉浸浏览',
    AppListStyle.minimal => '只留名字与图标，极致简洁',
  };

  IconData get icon => switch (this) {
    AppListStyle.glass => Icons.view_agenda_rounded,
    AppListStyle.compact => Icons.view_list_rounded,
    AppListStyle.grid => Icons.grid_view_rounded,
    AppListStyle.large => Icons.image_rounded,
    AppListStyle.minimal => Icons.line_weight_rounded,
  };

  String get key => name;
}

/// 详情页布局样式
enum AppDetailStyle {
  standard, // 标准（图标 + 信息卡 + Tab）
  poster, // 海报式（大图头图 + 悬浮信息）
  dark, // 暗黑（v52m）
  minimal, // 极简（无头图，v52m）
  compact, // 紧凑（矮条头图，v52m）
  aurora, // ★ 1020 新增：极光渐变（四色网格渐变 + 毛玻璃数据卡）
  neon, // ★ 1020 新增：霓虹（冷色发光线条，深浅自适应）
}

extension AppDetailStyleX on AppDetailStyle {
  String get label => switch (this) {
    AppDetailStyle.standard => '标准',
    AppDetailStyle.poster => '海报式',
    AppDetailStyle.dark => '暗黑',
    AppDetailStyle.minimal => '极简',
    AppDetailStyle.compact => '紧凑',
    AppDetailStyle.aurora => '极光渐变',
    AppDetailStyle.neon => '霓虹',
  };
}

/// 从字符串解析样式（后台配置 / 本地设置）
AppListStyle parseListStyle(String? s) {
  switch ((s ?? '').trim().toLowerCase()) {
    case 'compact':
      return AppListStyle.compact;
    case 'grid':
      return AppListStyle.grid;
    case 'large':
      return AppListStyle.large;
    case 'minimal':
      return AppListStyle.minimal;
    default:
      return AppListStyle.glass;
  }
}

AppDetailStyle parseDetailStyle(String? s) {
  switch ((s ?? '').trim().toLowerCase()) {
    case 'poster':
      return AppDetailStyle.poster;
    case 'dark':
      return AppDetailStyle.dark;
    case 'minimal':
      return AppDetailStyle.minimal;
    case 'compact':
      return AppDetailStyle.compact;
    case 'aurora':
      return AppDetailStyle.aurora;
    case 'neon':
      return AppDetailStyle.neon;
    default:
      return AppDetailStyle.standard;
  }
}
