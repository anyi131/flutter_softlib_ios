import 'dart:convert';

import 'ui_config.dart';

import '../jicun/jicun_config.dart';

/// App 全局配置（来自 /api/softlib/config/index，后台可远程下发）
class AppConfig {
  final String placard;
  final String feedbackGroup;
  final String feedbackUser;

  // ===== 开屏页 =====
  final bool splashEnable;
  final String splashImage;
  final int splashSeconds;
  final String splashUrl;
  final String splashTitle;
  final String splashDesc;

  // ===== 公告弹窗 =====
  final bool noticeEnable;
  final String noticeTitle;
  final String noticeContent;
  final String noticeUrl;
  final bool noticeForce;

  /// ★ 1028：同一用户每天最多弹几次公告（0 = 不限次数）
  final int noticeDailyLimit;

  // ===== 远程控制 =====
  final bool maintainEnable;
  final String maintainText;

  /// ★ v3.3.4：维护页模板（engineer/countdown/glass/brand/checklist）
  final String maintainTemplate;
  final String serviceUrl;
  final String agreement;
  final String privacy;
  final bool groupBtnOn;
  final bool userBtnOn;

  /// 软件列表数据源: all / local / lzy
  final String appSource;

  // ===== 关于软件（后台可配）=====
  final bool aboutEnable;
  final String aboutName;
  final String aboutVersion;
  final String aboutLogo;
  final String aboutSlogan;
  final String aboutDesc;
  final String aboutCopyright;
  final String aboutContact;
  final String aboutWebsite;
  final String aboutUpdateUrl;
  final String aboutExtra;

  /// 页脚文案（后台可配，避免写死）
  final String aboutFooter;

  // ===== ★ 1014：分享文案（后台可配，关于页/我的页「分享本软件」）=====
  final String shareTitle;
  final String shareDesc;
  final String shareUrl;
  final String shareImage;

  /// 注册邮箱域名白名单（空=不限）
  final String emailAllowDomains;

  /// 是否允许非 QQ 邮箱注册（false = 仅 QQ 邮箱）
  final bool emailNonQqOn;

  /// ★ 1016：注册是否需要邮箱验证码（后台开关，默认 true）
  final bool regCodeOn;

  /// 后台下发的主题配色方案（管理员控制，用户不可改）
  final String themePalette;

  /// 工具首页风格（group/list/card）
  final String toolHomeStyle;

  /// 服务端可切换的 UI 风格（glass / classic / minimal）
  final String appUiStyle;

  /// ★ 全局界面配置（Tab开关/功能开关/主题/深色模式 —— 后台「界面配置」下发）
  final UiConfig uiConfig;

  /// 即存「解析配置」（后台 ui_config.jicun 节点;拉不到为 null,客户端用默认值）
  final dynamic jicunConfig;

  AppConfig({
    this.placard = '',
    this.feedbackGroup = '',
    this.feedbackUser = '',
    this.splashEnable = true,
    this.splashImage = '',
    this.splashSeconds = 3,
    this.splashUrl = '',
    this.splashTitle = '',
    this.splashDesc = '',
    this.noticeEnable = false,
    this.noticeTitle = '公告',
    this.noticeContent = '',
    this.noticeUrl = '',
    this.noticeForce = false,
    this.noticeDailyLimit = 0,
    this.maintainEnable = false,
    this.maintainText = '',
    this.maintainTemplate = 'engineer',
    this.serviceUrl = '',
    this.agreement = '',
    this.privacy = '',
    this.groupBtnOn = true,
    this.userBtnOn = true,
    this.appSource = 'all',
    this.aboutEnable = true,
    this.aboutName = '安逸软件汇',
    this.aboutVersion = '', // ★ 1015：空=跟随 App 真实版本
    this.aboutLogo = '',
    this.aboutSlogan = '优质软件 · 持续更新',
    this.aboutDesc = '',
    this.aboutCopyright = '',
    this.aboutContact = '',
    this.aboutWebsite = '',
    this.aboutUpdateUrl = '',
    this.aboutExtra = '',
    this.aboutFooter = '',
    this.shareTitle = '',
    this.shareDesc = '',
    this.shareUrl = '',
    this.shareImage = '',
    this.emailAllowDomains = '',
    this.emailNonQqOn = false,
    this.regCodeOn = true,
    this.appUiStyle = 'glass',
    this.themePalette = 'aurora',
    this.toolHomeStyle = 'group',
    this.uiConfig = const UiConfig(),
    this.jicunConfig,
  });

  /// ★ v52g #6：ui_config 是嵌套 JSON（后台「界面」Tab 整体下发）
  ///   之前 fromLegacy 只认根级 theme_palette/app_ui_style 旧字段，
  ///   嵌套结构完全没读到 —— 后台改了配置 App 永远不生效。
  static UiConfig _parseUiConfig(Map json) {
    final raw = json['ui_config'];
    if (raw is Map) {
      return UiConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.trim().startsWith('{')) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return UiConfig.fromJson(Map<String, dynamic>.from(d));
      } catch (_) {}
    }
    return UiConfig.fromLegacy(json);
  }

  static bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
  static int _i(dynamic v) => int.tryParse((v ?? '').toString()) ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();

  factory AppConfig.fromJson(Map json) => AppConfig(
    placard: _s(json['placard']),
    feedbackGroup: _s(json['feedback_group']),
    feedbackUser: _s(json['feedback_user']),
    splashEnable: json.containsKey('splash_enable')
        ? _b(json['splash_enable'])
        : true,
    splashImage: _s(json['splash_image']),
    // ★ 1020：默认 3 秒（原来 2 秒太短，来不及看清图）
    splashSeconds: _i(json['splash_seconds']) <= 0
        ? 3
        : _i(json['splash_seconds']),
    splashUrl: _s(json['splash_url']),
    splashTitle: _s(json['splash_title']),
    splashDesc: _s(json['splash_desc']),
    noticeEnable: _b(json['notice_enable']),
    noticeTitle: _s(json['notice_title']).isEmpty
        ? '公告'
        : _s(json['notice_title']),
    noticeContent: _s(json['notice_content']),
    noticeUrl: _s(json['notice_url']),
    noticeForce: _b(json['notice_force']),
    noticeDailyLimit: _i(json['notice_daily_limit']),
    maintainEnable: _b(json['maintain_enable']),
    maintainText: _s(json['maintain_text']),
    maintainTemplate: _s(json['maintain_template']).isEmpty
        ? 'engineer'
        : _s(json['maintain_template']),
    serviceUrl: _s(json['service_url']),
    agreement: _s(json['agreement']),
    privacy: _s(json['privacy']),
    groupBtnOn: json.containsKey('feedback_group_on')
        ? _b(json['feedback_group_on'])
        : true,
    userBtnOn: json.containsKey('feedback_user_on')
        ? _b(json['feedback_user_on'])
        : true,
    appSource: _s(json['app_source']).isEmpty ? 'all' : _s(json['app_source']),
    aboutEnable: json.containsKey('about_enable')
        ? _b(json['about_enable'])
        : true,
    aboutName: _s(json['about_name']).isEmpty
        ? '安逸软件汇'
        : _s(json['about_name']),
    aboutVersion: _s(json['about_version']).isEmpty
        ? '3.3.0'
        : _s(json['about_version']),
    aboutLogo: _s(json['about_logo']),
    aboutSlogan: _s(json['about_slogan']),
    aboutDesc: _s(json['about_desc']),
    aboutCopyright: _s(json['about_copyright']),
    aboutContact: _s(json['about_contact']),
    aboutWebsite: _s(json['about_website']),
    aboutUpdateUrl: _s(json['about_update_url']),
    aboutExtra: _s(json['about_extra']),
    aboutFooter: _s(json['about_footer']),
    shareTitle: _s(json['share_title']),
    shareDesc: _s(json['share_desc']),
    shareUrl: _s(json['share_url']),
    shareImage: _s(json['share_image']),
    emailAllowDomains: _s(json['email_allow_domains']),
    emailNonQqOn: _b(json['email_nonqq_on']),
    regCodeOn: json['reg_code_on'] == null ? true : _b(json['reg_code_on']),
    themePalette: _s(json['theme_palette']).isEmpty
        ? 'aurora'
        : _s(json['theme_palette']),
    toolHomeStyle: _s(json['tool_home_style']).isEmpty
        ? 'group'
        : _s(json['tool_home_style']),
    appUiStyle: _s(json['app_ui_style']).isEmpty
        ? 'glass'
        : _s(json['app_ui_style']),
    uiConfig: _parseUiConfig(json),
    jicunConfig: _parseJicunConfig(json),
  );

  /// 即存「解析配置」(后台 ui_config.jicun 节点;没有则 null,由客户端兜底默认)
  static dynamic _parseJicunConfig(Map json) {
    final raw = json['ui_config'];
    Map? ui;
    if (raw is Map) {
      ui = raw;
    } else if (raw is String && raw.trim().startsWith('{')) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) ui = d;
      } catch (_) {}
    }
    if (ui == null) return null;
    final j = ui['jicun'];
    if (j is Map) return JicunConfig.fromJson(Map<String, dynamic>.from(j));
    return null;
  }
}
