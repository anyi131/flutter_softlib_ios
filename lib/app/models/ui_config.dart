import 'package:flutter/material.dart';

/// 会员促销横幅（后台 ui_config.promo）
///
/// ★ 1030「大促刺激充值」：纯展示层——划线原价 = 套餐现价 × 倍数，
///   实际下单金额仍走 pay/plans 的套餐价，扣款一分不变。
class PromoConfig {
  final bool on;
  final String title; // 横幅标题，如「限时特惠」
  final String end; // 结束时间 yyyy-MM-dd HH:mm:ss，空=不显示倒计时
  final String tip; // 横幅小字，如「全场会员 5 折起」
  final double mul; // 划线倍数：原价 = 现价 × mul

  const PromoConfig({
    this.on = false,
    this.title = '限时特惠',
    this.end = '',
    this.tip = '',
    this.mul = 2,
  });

  factory PromoConfig.fromJson(Map json) => PromoConfig(
    on:
        json['on'] == true ||
        json['on'] == 1 ||
        json['on'] == '1',
    title: (json['title'] ?? '').toString(),
    end: (json['end'] ?? '').toString(),
    tip: (json['tip'] ?? '').toString(),
    mul: () {
      final v = double.tryParse('${json['mul'] ?? ''}');
      return (v == null || v <= 1) ? 2.0 : v;
    }(),
  );
}

/// 支付确认弹窗文案（后台 ui_config.pay_notice，enabled=0 时跳过弹窗）
class PayNoticeConfig {
  final bool enabled;
  final String title;
  final String subtitle;
  final String cardNote; // 网站支付完成后…
  final String appNote; // APP支付完成后…
  final String button;

  const PayNoticeConfig({
    this.enabled = true,
    this.title = '欢迎使用安全支付',
    this.subtitle = '请仔细阅读以下支付说明',
    this.cardNote = '网站支付完成后，会员状态会自动同步到账户。',
    this.appNote = 'APP支付完成后，请勿关闭页面，稍等片刻即可到账。',
    this.button = '我已了解，开始支付',
  });

  factory PayNoticeConfig.fromJson(Map json) => PayNoticeConfig(
    enabled:
        json['enabled'] == null ||
        json['enabled'] == true ||
        json['enabled'] == 1 ||
        json['enabled'] == '1',
    title: (json['title'] ?? '').toString(),
    subtitle: (json['subtitle'] ?? '').toString(),
    cardNote: (json['card_note'] ?? '').toString(),
    appNote: (json['app_note'] ?? '').toString(),
    button: (json['button'] ?? '').toString(),
  );

  /// 文案为空时回退内置默认（仅取展示字段）
  PayNoticeConfig withDefaults() => PayNoticeConfig(
    enabled: enabled,
    title: title.isNotEmpty ? title : '欢迎使用安全支付',
    subtitle: subtitle.isNotEmpty ? subtitle : '请仔细阅读以下支付说明',
    cardNote: cardNote.isNotEmpty ? cardNote : '网站支付完成后，会员状态会自动同步到账户。',
    appNote: appNote.isNotEmpty ? appNote : 'APP支付完成后，请勿关闭页面，稍等片刻即可到账。',
    button: button.isNotEmpty ? button : '我已了解，开始支付',
  );
}

/// 音效开关（后台 ui_config.sfx 下发）
///
/// ★ 1028 修「音效开关没用」：原来这 5 个开关只写本机 SharedPreferences，
///   管理员在后台关掉只影响他自己那台手机，用户端读的还是本地默认 true。
///   现在随 ui_config 一起下发，才是真正全站生效。
class SfxConfig {
  final bool master; // 总开关
  final bool download; // 下载完成
  final bool sign; // 签到成功
  final bool message; // 来消息
  final bool update; // 版本更新
  final String voiceStyle; // 人声音色：yunxi/xiaoxiao/yunyang

  const SfxConfig({
    this.master = true,
    this.download = true,
    this.sign = true,
    this.message = true,
    this.update = true,
    this.voiceStyle = 'yunxi',
  });

  static bool _b(dynamic v) => v == null
      ? true
      : (v == true || v == 1 || v == '1' || v == 'true' || v == 'on');

  factory SfxConfig.fromJson(Map json) => SfxConfig(
    master: _b(json['master']),
    download: _b(json['download']),
    sign: _b(json['sign']),
    message: _b(json['message']),
    update: _b(json['update']),
    voiceStyle: (json['voice_style'] ?? 'yunxi').toString(),
  );

  Map<String, dynamic> toJson() => {
    'master': master ? 1 : 0,
    'download': download ? 1 : 0,
    'sign': sign ? 1 : 0,
    'message': message ? 1 : 0,
    'update': update ? 1 : 0,
    'voice_style': voiceStyle,
  };
}

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

  /// ★ v3.3.4：工具箱 Tab（分类大卡 + 胶囊工具）
  final bool tabTools;
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
  final bool featureCardRedeem; // 使用卡密
  final bool featureCardShop; // 卡密商城（购买卡密）
  final bool featureShareApp; // 分享软件
  final bool featureQqGroup; // QQ通知群
  final bool featureReplaceSplash; // 替换开屏

  // ── ★ 1020 新增功能开关 ──
  final bool featureWish; // 求软件（需求投票）
  final bool featureFavorites; // 我的收藏（软件+工具）
  final bool featureHistory; // 使用历史
  final bool featureAppFav; // 软件详情页收藏按钮
  final bool featureSilentRetry; // 下载失败静默重试
  final bool featureApiCache; // 接口列表缓存

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
  final String inviteShareText; // ★ 邀请分享文案（后台可自定义，空=用内置默认）

  // ── v54 界面模板体系 ──
  final String navTemplate; // 底部导航模板：classic/glass/float/dock/curve

  /// 全局玻璃（Liquid Glass）档位：auto/off/low/medium/high
  final String glassMode;
  final String
  adminTemplate; // 管理后台模板：light_card/dark_console/minimal/brand/desk

  // ── 支付确认弹窗文案（后台可配，空=用内置默认）──
  final PayNoticeConfig payNotice;

  // ── 音效开关（后台下发，全站生效）──
  final SfxConfig sfx;

  /// 会员促销（纯展示，不改真实扣款价）
  final PromoConfig promo;

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
    this.tabTools = true,
    this.tabSquare = true,
    this.tabTips = true,
    this.tabMine = true,
    this.featureCheckin = true,
    this.featureExchange = true,
    this.featureDonateRank = true,
    this.featureInvite = true,
    this.featureNotice = true,
    this.featureReferral = true,
    this.featureCardRedeem = true,
    this.featureCardShop = true,
    this.featureShareApp = true,
    this.featureQqGroup = true,
    this.featureReplaceSplash = true,
    this.featureWish = true,
    this.featureFavorites = true,
    this.featureHistory = true,
    this.featureAppFav = true,
    this.featureSilentRetry = true,
    this.featureApiCache = true,
    this.listStyle = 'glass',
    this.promo = const PromoConfig(),
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
    this.inviteShareText = '',
    this.navTemplate = 'classic',
    this.glassMode = 'auto',
    this.adminTemplate = 'light_card',
    this.payNotice = const PayNoticeConfig(),
    this.sfx = const SfxConfig(),

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
      tabTools: _b(tabs['tools'], true),
      tabSquare: _b(tabs['square'], true),
      tabTips: _b(tabs['tips'], true),
      tabMine: _b(tabs['mine'], true),
      featureCheckin: _b(feat['checkin'], true),
      featureExchange: _b(feat['exchange'], true),
      featureDonateRank: _b(feat['donate_rank'], true),
      featureInvite: _b(feat['invite'], true),
      // 兼容旧后台：home.notice = off 与 features.notice 任一关闭都不弹
      featureNotice: _b(feat['notice'], true) && _s(home['notice'], 'on') != 'off',
      featureReferral: _b(feat['referral'], true),
      featureCardRedeem: _b(feat['card_redeem'], true),
      featureCardShop: _b(feat['card_shop'], true),
      featureShareApp: _b(feat['share_app'], true),
      featureQqGroup: _b(feat['qq_group'], true),
      featureReplaceSplash: _b(feat['replace_splash'], true),
      featureWish: _b(feat['wish'], true),
      featureFavorites: _b(feat['favorites'], true),
      featureHistory: _b(feat['history'], true),
      featureAppFav: _b(feat['app_fav'], true),
      featureSilentRetry: _b(feat['silent_retry'], true),
      featureApiCache: _b(feat['api_cache'], true),
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
      inviteShareText: _s(json['invite_share_text'], ''),
      navTemplate: _s(json['nav_template'], 'classic'),
      // ★ 1020 全局玻璃档位：auto/off/low/medium/high（auto = 按设备能力自动）
      glassMode: _s(json['glass_mode'], 'auto'),
      adminTemplate: _s(json['admin_template'], 'light_card'),
      payNotice: PayNoticeConfig.fromJson(
        json['pay_notice'] is Map ? (json['pay_notice'] as Map) : const {},
      ),
      sfx: SfxConfig.fromJson(
        json['sfx'] is Map ? Map<String, dynamic>.from(json['sfx'] as Map) : const {},
      ),
      promo: PromoConfig.fromJson(
        json['promo'] is Map ? Map<String, dynamic>.from(json['promo'] as Map) : const {},
      ),

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
      inviteShareText: base.inviteShareText,
      navTemplate: base.navTemplate,
      glassMode: base.glassMode,
      adminTemplate: base.adminTemplate,
      payNotice: base.payNotice,
      quickSign: base.quickSign,
      quickVip: base.quickVip,
      quickService: base.quickService,
      quickUpdate: base.quickUpdate,
      // ★ 1020：补全功能开关，避免 fromLegacy 把后台关闭的功能重置回默认值
      featureCheckin: base.featureCheckin,
      featureExchange: base.featureExchange,
      featureDonateRank: base.featureDonateRank,
      featureInvite: base.featureInvite,
      featureNotice: base.featureNotice,
      featureReferral: base.featureReferral,
      featureCardRedeem: base.featureCardRedeem,
      featureCardShop: base.featureCardShop,
      featureShareApp: base.featureShareApp,
      featureQqGroup: base.featureQqGroup,
      featureReplaceSplash: base.featureReplaceSplash,
      featureWish: base.featureWish,
      featureFavorites: base.featureFavorites,
      featureHistory: base.featureHistory,
      featureAppFav: base.featureAppFav,
      featureSilentRetry: base.featureSilentRetry,
      featureApiCache: base.featureApiCache,
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
    'promo': {
      'on': promo.on ? 1 : 0,
      'title': promo.title,
      'end': promo.end,
      'tip': promo.tip,
      'mul': promo.mul,
    },
  };
}
