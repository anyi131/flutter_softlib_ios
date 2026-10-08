import 'package:flutter/material.dart';

/// 全局界面配置（后台 admin「界面配置」下发，App 启动时应用）
///
/// 后端存储：sys_config['ui_config'] = JSON 字符串
/// config/index 展开: ui_config = {...}
class UiConfig {
  // ── 主题 ──
  final String
  themePalette; // aurora/ocean/sunset/forest/sakura/midnight/crimson/graphite
  final String themeMode; // light / dark / system
  final bool allowUserThemeToggle; // 是否允许用户在「我的」里自行改明暗（默认否）

  // ── 底部 Tab 开关 ──
  final bool tabHome;
  final bool tabSquare;
  final bool tabTips;
  final bool tabMine;

  // ── 功能开关 ──
  final bool featureCheckin; // 每日签到
  final bool featureExchange; // 积分兑换
  final bool featureDonateRank; // 赞助排行
  final bool featureInvite; // 邀请码
  final bool featureNotice; // 公告弹窗
  final bool featureReferral; // 首页推荐

  // ── 首页布局 ──
  final String listStyle; // glass / compact / grid / large / minimal
  final String homeBanner; // on / off
  final String homeNotice;

  // ── 更新弹窗模板（v52g #1：classic/minimal/dark/poster/compact）──
  final String updateTemplate;

  // ── 页面模板（v52i #4：每个界面都有可选模板）──
  final String homeTemplate; // classic 标准首页 / clean 极简首页
  final String detailStyle; // standard/poster/dark/minimal/compact 详情5模板

  // ── v52m 全页面模板（#1-#9）──
  final String tipsTemplate; // card 卡片 / compact 紧凑（线报）
  final String mineTemplate; // classic / clean / gradient（我的）
  final String splashTemplate; // fullscreen / banner / fade（开屏）
  final String aboutTemplate; // card / hero / minimal（关于）
  final String authTemplate; // classic / gradient / minimal（登录注册找回）
  final String noticeTemplate; // card / banner / minimal（公告弹窗）
  final String inviteTemplate; // classic / hero / minimal（邀请页）

  // ── 首页快捷入口开关（v52g #7 热更新布局）──
  final bool quickSign;
  final bool quickVip;
  final bool quickService;
  final bool quickUpdate;

  const UiConfig({
    this.themePalette = 'aurora',
    this.themeMode = 'light',
    this.allowUserThemeToggle = false,
    this.tabHome = true,
    this.tabSquare = true,
    this.tabTips = true,
    this.tabMine = true,
    this.featureCheckin = true,
    this.featureExchange = true,
    this.featureDonateRank = true,
    this.featureInvite = true,
    this.featureNotice = true,
    this.featureReferral = true,
    this.listStyle = 'glass',
    this.homeBanner = 'on',
    this.homeNotice = 'on',
    this.updateTemplate = 'classic',
    this.homeTemplate = 'classic',
    this.detailStyle = 'standard',
    this.tipsTemplate = 'card',
    this.mineTemplate = 'classic',
    this.splashTemplate = 'fullscreen',
    this.aboutTemplate = 'card',
    this.authTemplate = 'classic',
    this.noticeTemplate = 'card',
    this.inviteTemplate = 'classic',
    this.quickSign = true,
    this.quickVip = true,
    this.quickService = true,
    this.quickUpdate = true,
  });

  static bool _b(dynamic v, [bool def = true]) =>
      v == null ? def : (v == true || v == 1 || v == '1' || v == 'true');
  static String _s(dynamic v, String def) {
    final x = (v ?? '').toString();
    return x.isEmpty ? def : x;
  }

  factory UiConfig.fromJson(Map json) {
    final tabs = (json['tabs'] is Map) ? (json['tabs'] as Map) : const {};
    final feat = (json['features'] is Map)
        ? (json['features'] as Map)
        : const {};
    final theme = (json['theme'] is Map) ? (json['theme'] as Map) : const {};
    final home = (json['home'] is Map) ? (json['home'] as Map) : const {};
    return UiConfig(
      themePalette: _s(theme['palette'], 'aurora'),
      themeMode: _s(theme['mode'], 'light'),
      allowUserThemeToggle: _b(theme['user_toggle'], false),
      tabHome: _b(tabs['home'], true),
      tabSquare: _b(tabs['square'], true),
      tabTips: _b(tabs['tips'], true),
      tabMine: _b(tabs['mine'], true),
      featureCheckin: _b(feat['checkin'], true),
      featureExchange: _b(feat['exchange'], true),
      featureDonateRank: _b(feat['donate_rank'], true),
      featureInvite: _b(feat['invite'], true),
      featureNotice: _b(feat['notice'], true),
      featureReferral: _b(feat['referral'], true),
      listStyle: _s(home['list_style'], 'glass'),
      homeBanner: _s(home['banner'], 'on'),
      homeNotice: _s(home['notice'], 'on'),
      updateTemplate: _s(json['update_template'], 'classic'),
      homeTemplate: _s(home['template'], 'classic'),
      detailStyle: _s(home['detail_style'], 'standard'),
      tipsTemplate: _s(json['tips_template'], 'card'),
      mineTemplate: _s(json['mine_template'], 'classic'),
      splashTemplate: _s(json['splash_template'], 'fullscreen'),
      aboutTemplate: _s(json['about_template'], 'card'),
      authTemplate: _s(json['auth_template'], 'classic'),
      noticeTemplate: _s(json['notice_template'], 'card'),
      inviteTemplate: _s(json['invite_template'], 'classic'),
      quickSign: _b(home['quick_sign'], true),
      quickVip: _b(home['quick_vip'], true),
      quickService: _b(home['quick_service'], true),
      quickUpdate: _b(home['quick_update'], true),
    );
  }

  /// 兼容旧字段：theme_palette / app_ui_style 直接放在 config 根上
  factory UiConfig.fromLegacy(Map json) {
    final base = UiConfig.fromJson(json);
    final pal = (json['theme_palette'] ?? '').toString();
    final style = (json['app_ui_style'] ?? '').toString();
    return UiConfig(
      themePalette: pal.isNotEmpty ? pal : base.themePalette,
      themeMode: base.themeMode,
      listStyle: style.isNotEmpty ? style : base.listStyle,
      tabHome: base.tabHome,
      tabSquare: base.tabSquare,
      tabTips: base.tabTips,
      tabMine: base.tabMine,
      updateTemplate: base.updateTemplate,
      homeTemplate: base.homeTemplate,
      detailStyle: base.detailStyle,
      tipsTemplate: base.tipsTemplate,
      mineTemplate: base.mineTemplate,
      splashTemplate: base.splashTemplate,
      aboutTemplate: base.aboutTemplate,
      authTemplate: base.authTemplate,
      noticeTemplate: base.noticeTemplate,
      inviteTemplate: base.inviteTemplate,
      quickSign: base.quickSign,
      quickVip: base.quickVip,
      quickService: base.quickService,
      quickUpdate: base.quickUpdate,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': {
      'palette': themePalette,
      'mode': themeMode,
      'user_toggle': allowUserThemeToggle ? 1 : 0,
    },
    'tabs': {
      'home': tabHome ? 1 : 0,
      'square': tabSquare ? 1 : 0,
      'tips': tabTips ? 1 : 0,
      'mine': tabMine ? 1 : 0,
    },
    'features': {
      'checkin': featureCheckin ? 1 : 0,
      'exchange': featureExchange ? 1 : 0,
      'donate_rank': featureDonateRank ? 1 : 0,
      'invite': featureInvite ? 1 : 0,
      'notice': featureNotice ? 1 : 0,
      'referral': featureReferral ? 1 : 0,
    },
    'home': {
      'list_style': listStyle,
      'banner': homeBanner,
      'notice': homeNotice,
    },
  };
}
