import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../api/soft_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/app_style_controller.dart';
import '../../../design/theme_controller.dart';
import '../../../design/theme_palette.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';
import '../../../pages/navigate/navigate_logic.dart';

/// ═══════════════════════════════════════════════════════════════
/// 界面配置 Tab（v52 #6 / #10）
///
/// 后台统一管理全局界面：
///   · 主题配色方案（8 套）  · 明暗模式（浅/深/跟随系统）
///   · 底部 Tab 开关         · 功能开关（签到/兑换/排行/邀请…）
///   · 软件列表默认样式
/// 保存到 ui_config JSON，App 启动时 applyUiConfig() 应用。
/// ═══════════════════════════════════════════════════════════════
class AdminUiTab extends StatefulWidget {
  const AdminUiTab({super.key});

  @override
  State<AdminUiTab> createState() => _AdminUiTabState();
}

class _AdminUiTabState extends State<AdminUiTab> {
  final _svc = AdminService.instance;

  // 主题
  String _palette = 'aurora';
  String _mode = 'light'; // light / dark / system
  bool _userToggle = false;
  // Tab
  bool _tabHome = true, _tabSquare = true, _tabTips = true, _tabMine = true;
  // 功能
  bool _checkin = true, _exchange = true, _donate = true, _invite = true;
  bool _notice = true, _referral = true;
  // 列表样式
  String _listStyle = 'glass';
  // 更新弹窗模板（v52g #1）
  String _updateTemplate = 'classic';
  // 页面模板（v52i #4）
  String _homeTemplate = 'classic';
  String _detailStyle = 'standard';
  // v52m 全页面模板
  String _tipsTemplate = 'card';
  String _mineTemplate = 'classic';
  String _splashTemplate = 'fullscreen';
  String _aboutTemplate = 'card';
  String _authTemplate = 'classic';
  String _noticeTemplate = 'card';
  String _inviteTemplate = 'classic';
  // v52w：邀请配置
  final _inviteScoreCtrl = TextEditingController();
  // 首页快捷入口（v52g #7）
  bool _qSign = true, _qVip = true, _qService = true, _qUpdate = true;

  bool _loading = true;
  bool _saving = false;
  String _loadErr = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cfg = await _svc.config();
      final raw = cfg['ui_config'];
      Map<String, dynamic> ui = {};
      if (raw is Map) {
        ui = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.trim().startsWith('{')) {
        // JSON 字符串容错
        try {
          ui = Map<String, dynamic>.from(jsonDecode(raw));
        } catch (_) {}
      }
      final theme = (ui['theme'] is Map)
          ? Map<String, dynamic>.from(ui['theme'] as Map)
          : <String, dynamic>{};
      final tabs = (ui['tabs'] is Map)
          ? Map<String, dynamic>.from(ui['tabs'] as Map)
          : <String, dynamic>{};
      final feat = (ui['features'] is Map)
          ? Map<String, dynamic>.from(ui['features'] as Map)
          : <String, dynamic>{};
      final home = (ui['home'] is Map)
          ? Map<String, dynamic>.from(ui['home'] as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _palette = '${theme['palette'] ?? cfg['theme_palette'] ?? 'aurora'}';
        _mode = '${theme['mode'] ?? 'light'}';
        _userToggle = '${theme['user_toggle'] ?? 0}' == '1';
        _tabHome = '${tabs['home'] ?? 1}' == '1';
        _tabSquare = '${tabs['square'] ?? 1}' == '1';
        _tabTips = '${tabs['tips'] ?? 1}' == '1';
        _tabMine = '${tabs['mine'] ?? 1}' == '1';
        _checkin = '${feat['checkin'] ?? 1}' == '1';
        _exchange = '${feat['exchange'] ?? 1}' == '1';
        _donate = '${feat['donate_rank'] ?? 1}' == '1';
        _invite = '${feat['invite'] ?? 1}' == '1';
        _notice = '${feat['notice'] ?? 1}' == '1';
        _referral = '${feat['referral'] ?? 1}' == '1';
        _listStyle = '${home['list_style'] ?? cfg['app_ui_style'] ?? 'glass'}';
        _updateTemplate = '${ui['update_template'] ?? 'classic'}';
        _homeTemplate = '${home['template'] ?? 'classic'}';
        _detailStyle = '${home['detail_style'] ?? 'standard'}';
        _tipsTemplate = '${ui['tips_template'] ?? 'card'}';
        _mineTemplate = '${ui['mine_template'] ?? 'classic'}';
        _splashTemplate = '${ui['splash_template'] ?? 'fullscreen'}';
        _aboutTemplate = '${ui['about_template'] ?? 'card'}';
        _authTemplate = '${ui['auth_template'] ?? 'classic'}';
        _noticeTemplate = '${ui['notice_template'] ?? 'card'}';
        _inviteTemplate = '${ui['invite_template'] ?? 'classic'}';
        _inviteScoreCtrl.text = '${ui['invite_score'] ?? 50}';
        _qSign = '${home['quick_sign'] ?? 1}' == '1';
        _qVip = '${home['quick_vip'] ?? 1}' == '1';
        _qService = '${home['quick_service'] ?? 1}' == '1';
        _qUpdate = '${home['quick_update'] ?? 1}' == '1';
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Map<String, dynamic> _payload() => {
    'ui_config': {
      'theme': {
        'palette': _palette,
        'mode': _mode,
        'user_toggle': _userToggle ? 1 : 0,
      },
      'tabs': {
        'home': _tabHome ? 1 : 0,
        'square': _tabSquare ? 1 : 0,
        'tips': _tabTips ? 1 : 0,
        'mine': _tabMine ? 1 : 0,
      },
      'features': {
        'checkin': _checkin ? 1 : 0,
        'exchange': _exchange ? 1 : 0,
        'donate_rank': _donate ? 1 : 0,
        'invite': _invite ? 1 : 0,
        'notice': _notice ? 1 : 0,
        'referral': _referral ? 1 : 0,
      },
      'home': {'list_style': _listStyle},
    },
  };

  Future<void> _save() async {
    if (_saving) return;
    if (_loadErr.isNotEmpty) {
      ToastUtil.error('配置未加载成功，禁止保存（避免覆盖线上配置），请先重试');
      return;
    }
    setState(() => _saving = true);
    try {
      await _svc.saveConfig(_payload());
      // v52k #2：保存后立即热应用（本会话直接生效，无需重启/重进）
      try {
        final cfg = await SoftService.instance.fetchConfig(force: true);
        if (cfg != null) {
          final ui = cfg.uiConfig;
          await ThemeController.instance.setMode(switch (ui.themeMode) {
            'dark' => ThemeMode.dark,
            'system' => ThemeMode.system,
            _ => ThemeMode.light,
          });
          ThemeController.instance.applyServerPalette(ui.themePalette);
          AppStyleController.instance.applyServerDefault(ui.listStyle);
          try {
            Get.find<NavigateLogic>().applyUiConfig(force: true);
          } catch (_) {}
        }
      } catch (_) {}
      if (mounted) {
        ToastUtil.success('已保存并即时生效');
      }
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (_loadErr.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: context.t3),
            const SizedBox(height: 10),
            Text('配置加载失败',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.t1)),
            const SizedBox(height: 4),
            Text(_loadErr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: context.t3)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('重试加载')),
          ],
        ),
      );
    }
    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
          children: [
            _card('主题配色', _palettePicker()),
            _card('明暗模式', _modePicker()),
            _card('底部导航开关', _tabSwitches()),
            _card('功能开关', _featureSwitches()),
            _card('软件列表默认样式', _listStylePicker()),
            _card('更新弹窗模板', _templatePicker()),
            _card('首页布局模板', _homeTemplatePicker()),
            _card('软件详情页模板', _detailStylePicker()),
            _card('首页快捷入口', _quickSwitches()),
          ],
        ),
        // v52k #2：保存按钮固定底部，随时可见
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: AppPressable(
            onTap: _saving ? null : _save,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: C.brandGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: C.brand.withAlpha(70),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '保存界面配置（即时生效）',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withAlpha(16)
              : Colors.black.withAlpha(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: context.t1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _palettePicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final p in ThemePalette.all)
          AppPressable(
            onTap: () => setState(() => _palette = p.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _palette == p.key
                    ? p.brand.withAlpha(30)
                    : context.isDark
                    ? Colors.white.withAlpha(10)
                    : Colors.black.withAlpha(5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _palette == p.key ? p.brand : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [p.brand, p.accent]),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: context.t1,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _modePicker() {
    const opts = [
      ('light', '浅色', Icons.light_mode_rounded),
      ('dark', '深色', Icons.dark_mode_rounded),
      ('system', '跟随系统', Icons.settings_brightness_rounded),
    ];
    return Row(
      children: [
        for (final o in opts) ...[
          Expanded(
            child: AppPressable(
              onTap: () => setState(() => _mode = o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _mode == o.$1
                      ? C.brand.withAlpha(26)
                      : context.isDark
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(4),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _mode == o.$1
                        ? C.brand.withAlpha(140)
                        : Colors.transparent,
                    width: 1.3,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      o.$3,
                      size: 19,
                      color: _mode == o.$1 ? C.brand : context.t3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      o.$2,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.t2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (o != opts.last) const SizedBox(width: 9),
        ],
      ],
    );
  }

  Widget _tabSwitches() {
    final items = [
      ('首页', _tabHome, (v) => _tabHome = v),
      ('广场', _tabSquare, (v) => _tabSquare = v),
      ('线报', _tabTips, (v) => _tabTips = v),
      ('我的', _tabMine, (v) => _tabMine = v),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final it in items)
          _chipToggle(it.$1, it.$2, (v) => setState(() => it.$3(v))),
      ],
    );
  }

  Widget _featureSwitches() {
    final items = [
      ('每日签到', _checkin, (v) => _checkin = v),
      ('积分兑换', _exchange, (v) => _exchange = v),
      ('赞助排行', _donate, (v) => _donate = v),
      ('邀请码', _invite, (v) => _invite = v),
      ('公告弹窗', _notice, (v) => _notice = v),
      ('首页推荐', _referral, (v) => _referral = v),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final it in items)
          _chipToggle(it.$1, it.$2, (v) => setState(() => it.$3(v))),
      ],
    );
  }

  Widget _chipToggle(String label, bool on, ValueChanged<bool> onChanged) {
    return AppPressable(
      onTap: () => onChanged(!on),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? C.brand.withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on ? C.brand.withAlpha(150) : context.t3.withAlpha(70),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 14,
              color: on ? C.brand : context.t3,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: on ? C.brand : context.t2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeTemplatePicker() {
    const opts = [('classic', '标准首页'), ('clean', '极简首页')];
    return Row(
      children: [
        for (final o in opts) ...[
          Expanded(
            child: AppPressable(
              onTap: () => setState(() => _homeTemplate = o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _homeTemplate == o.$1
                      ? C.brand.withAlpha(26)
                      : context.isDark
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(4),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _homeTemplate == o.$1
                        ? C.brand.withAlpha(140)
                        : Colors.transparent,
                    width: 1.3,
                  ),
                ),
                child: Text(
                  o.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _homeTemplate == o.$1 ? C.brand : context.t2,
                  ),
                ),
              ),
            ),
          ),
          if (o != opts.last) const SizedBox(width: 9),
        ],
      ],
    );
  }

  Widget _detailStylePicker() {
    const opts = [('standard', '标准'), ('poster', '海报式')];
    return Row(
      children: [
        for (final o in opts) ...[
          Expanded(
            child: AppPressable(
              onTap: () => setState(() => _detailStyle = o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _detailStyle == o.$1
                      ? C.brand.withAlpha(26)
                      : context.isDark
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(4),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _detailStyle == o.$1
                        ? C.brand.withAlpha(140)
                        : Colors.transparent,
                    width: 1.3,
                  ),
                ),
                child: Text(
                  o.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _detailStyle == o.$1 ? C.brand : context.t2,
                  ),
                ),
              ),
            ),
          ),
          if (o != opts.last) const SizedBox(width: 9),
        ],
      ],
    );
  }

  Widget _chipRow(List<(String, String)> opts, String cur,
      ValueChanged<String> onTap) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final o in opts)
          AppPressable(
            onTap: () => onTap(o.$1),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: cur == o.$1
                    ? C.brand.withAlpha(26)
                    : context.isDark
                        ? Colors.white.withAlpha(8)
                        : Colors.black.withAlpha(4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: cur == o.$1
                        ? C.brand.withAlpha(150)
                        : Colors.transparent,
                    width: 1.3),
              ),
              child: Text(o.$2,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cur == o.$1 ? C.brand : context.t2)),
            ),
          ),
      ],
    );
  }

  Widget _inviteConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('新用户注册填写邀请码后，邀请人与新用户各得多少积分',
            style: TextStyle(fontSize: 11.5, color: context.t3)),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextFormField(
                controller: _inviteScoreCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 14, color: context.t1),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: context.isDark
                      ? Colors.white.withAlpha(10)
                      : const Color(0xFFF5F6FA),
                  suffixText: '积分',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('填 0 = 关闭邀请奖励',
                style: TextStyle(fontSize: 11.5, color: context.t3)),
          ],
        ),
        const SizedBox(height: 8),
        Text('入口开关在上方「功能开关 → 邀请好友」',
            style: TextStyle(fontSize: 11, color: context.t3)),
      ],
    );
  }

  Widget _tipsTemplatePicker() => _chipRow(const [
        ('card', '卡片'),
        ('compact', '紧凑'),
        ('timeline', '时间轴'),
        ('minimal_row', '极简行'),
        ('rich', '大图卡'),
        ('chat', '聊天流'),
      ], _tipsTemplate, (v) => setState(() => _tipsTemplate = v));

  Widget _mineTemplatePicker() => _chipRow(const [
        ('classic', '经典'),
        ('clean', '极简'),
        ('gradient', '渐变描边'),
        ('dark_card', '深色卡'),
        ('split', '分样式'),
        ('stats_hero', '数据英雄'),
        ('simple', '纯列表'),
      ], _mineTemplate, (v) => setState(() => _mineTemplate = v));

  Widget _splashTemplatePicker() => _chipRow(const [
        ('fullscreen', '全屏图'),
        ('banner', '卡片图'),
        ('fade', '品牌渐变'),
        ('split', '左右分栏'),
        ('greeting', '时段问候'),
        ('poster_center', '居中海报'),
        ('brand_bar', '品牌底条'),
      ], _splashTemplate, (v) => setState(() => _splashTemplate = v));

  Widget _aboutTemplatePicker() => _chipRow(const [
        ('card', '经典'),
        ('hero', '渐变横幅'),
        ('minimal', '极简'),
        ('dark_card', '深色卡'),
        ('desk', '桌面风'),
        ('plain', '纯文字'),
      ], _aboutTemplate, (v) => setState(() => _aboutTemplate = v));

  Widget _authTemplatePicker() => _chipRow(const [
        ('classic', '经典'),
        ('gradient', '渐变横幅'),
        ('minimal', '极简'),
        ('banner_top', '顶部横幅'),
        ('centered', '居中卡'),
        ('centered_gradient', '居中渐变'),
      ], _authTemplate, (v) => setState(() => _authTemplate = v));

  Widget _noticeTemplatePicker() => _chipRow(const [
        ('card', '经典弹窗'),
        ('banner', '渐变横幅'),
        ('minimal', '极简'),
        ('sheet', '底部弹出'),
        ('fullscreen', '全屏页'),
        ('banner_card', '横幅+正文卡'),
      ], _noticeTemplate, (v) => setState(() => _noticeTemplate = v));

  Widget _inviteTemplatePicker() => _chipRow(const [
        ('classic', '经典卡片'),
        ('hero', '渐变横幅'),
        ('minimal', '极简'),
      ], _inviteTemplate, (v) => setState(() => _inviteTemplate = v));

  Widget _templatePicker() {
    const opts = [
      ('classic', '渐变卡'),
      ('minimal', '极简'),
      ('dark', '暗黑'),
      ('poster', '海报'),
      ('compact', '紧凑'),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final o in opts)
          AppPressable(
            onTap: () => setState(() => _updateTemplate = o.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: _updateTemplate == o.$1
                    ? C.brand.withAlpha(26)
                    : context.isDark
                    ? Colors.white.withAlpha(8)
                    : Colors.black.withAlpha(4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _updateTemplate == o.$1
                      ? C.brand.withAlpha(150)
                      : Colors.transparent,
                  width: 1.3,
                ),
              ),
              child: Text(
                o.$2,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _updateTemplate == o.$1 ? C.brand : context.t2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _quickSwitches() {
    final items = [
      ('每日签到', _qSign, (v) => _qSign = v),
      ('VIP会员', _qVip, (v) => _qVip = v),
      ('联系客服', _qService, (v) => _qService = v),
      ('检查更新', _qUpdate, (v) => _qUpdate = v),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final it in items)
          _chipToggle(it.$1, it.$2, (v) => setState(() => it.$3(v))),
      ],
    );
  }

  Widget _listStylePicker() {
    const opts = [
      ('glass', '玻璃卡片'),
      ('compact', '紧凑列表'),
      ('grid', '双列网格'),
      ('large', '封面大图'),
      ('minimal', '极简单行'),
    ];
    return Row(
      children: [
        for (final o in opts) ...[
          Expanded(
            child: AppPressable(
              onTap: () => setState(() => _listStyle = o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _listStyle == o.$1
                      ? C.brand.withAlpha(26)
                      : context.isDark
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(4),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _listStyle == o.$1
                        ? C.brand.withAlpha(140)
                        : Colors.transparent,
                    width: 1.3,
                  ),
                ),
                child: Text(
                  o.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _listStyle == o.$1 ? C.brand : context.t2,
                  ),
                ),
              ),
            ),
          ),
          if (o != opts.last) const SizedBox(width: 9),
        ],
      ],
    );
  }
}
