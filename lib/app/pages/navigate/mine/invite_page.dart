
import '../../../api/soft_service.dart';
import '../../../api/user_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';

/// ═══════════════════════════════════════════════════════════════
/// 邀请好友页（v52q）—— 三套模板 classic / hero / minimal
///
/// 功能：
///   · 我的邀请码（一键复制 / 系统分享）
///   · 已邀请人数 / 累计赚积分 / 每位奖励
///   · 分享文案带邀请码
/// ═══════════════════════════════════════════════════════════════
class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final r = await UserService.instance.inviteStats();
      if (mounted) setState(() => _stats = r);
    } catch (e) {
      if (mounted) _err = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _code => (_stats?['code'] ?? '').toString();
  int get _count => int.tryParse('${_stats?['count'] ?? 0}') ?? 0;
  int get _score => int.tryParse('${_stats?['score'] ?? 0}') ?? 0;
  int get _each => int.tryParse('${_stats?['score_each'] ?? 50}') ?? 50;

  String get _shareText =>
      '【安逸软件库】发现一个宝藏软件库，资源全、更新快！'
      '注册时填我的邀请码 $_code，你我都能得 $_each 积分~';

  Future<void> _copy() async {
    if (_code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _code));
    ToastUtil.success('邀请码已复制');
  }

  Future<void> _share() async {
    await Share.share(_shareText, subject: '安逸软件库邀请');
  }

  @override
  Widget build(BuildContext context) {
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.inviteTemplate ?? 'classic';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _topBar(context),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : _err.isNotEmpty
                      ? _errorView()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              context.pagePadding,
                              8,
                              context.pagePadding,
                              30,
                            ),
                            children: switch (tpl) {
                              'hero' => _bodyHero(context),
                              'minimal' => _bodyMinimal(context),
                              _ => _bodyClassic(context),
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 顶栏 ──
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        8,
        context.pagePadding,
        0,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(8),
                ),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _load,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(8),
                ),
              ),
              child: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 42, color: context.t3),
          const SizedBox(height: 10),
          Text(_err, style: TextStyle(fontSize: 13, color: context.t2)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }

  // ── 模板一：classic（经典卡片）──
  List<Widget> _bodyClassic(BuildContext context) {
    return [
      _codeCard(context),
      const SizedBox(height: 14),
      _statsRow(context),
      const SizedBox(height: 14),
      _ruleCard(context),
      const SizedBox(height: 14),
      _actions(context),
    ];
  }

  // ── 模板二：hero（渐变大横幅）──
  List<Widget> _bodyHero(BuildContext context) {
    return [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: C.brandGradient,
          borderRadius: BorderRadius.circular(R.xl),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(70),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(height: 8),
            const Text(
              '邀请好友 · 双方得积分',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            // 白底邀请码条
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '我的邀请码',
                          style: TextStyle(fontSize: 10.5, color: context.t3),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _code.isEmpty ? '—' : _code,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: C.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppPressable(
                    onTap: _copy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: C.brandGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '复制',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _statsRow(context),
      const SizedBox(height: 14),
      _ruleCard(context),
      const SizedBox(height: 14),
      _actions(context),
    ];
  }

  // ── 模板三：minimal（极简排版）──
  List<Widget> _bodyMinimal(BuildContext context) {
    return [
      Text('邀请好友', style: Ty.display.copyWith(color: context.t1)),
      const SizedBox(height: 6),
      Text(
        '每成功邀请 1 位好友注册，双方各得 $_each 积分',
        style: Ty.small.copyWith(color: context.t3),
      ),
      const SizedBox(height: 20),
      _codeCard(context),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _statCell(context, '已邀请', '$_count 人')),
          const SizedBox(width: 10),
          Expanded(child: _statCell(context, '累计奖励', '$_score 积分')),
        ],
      ),
      const SizedBox(height: 16),
      _actions(context),
    ];
  }

  // ── 邀请码卡（classic/minimal 共用）──
  Widget _codeCard(BuildContext context) {
    return KitCard(
      radius: R.xl,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我的邀请码', style: Ty.tiny.copyWith(color: context.t3)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _code.isEmpty ? '—' : _code,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: C.brand,
                  ),
                ),
              ),
              AppPressable(
                onTap: _copy,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: C.brandGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '复制',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 数据行 ──
  Widget _statsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _statCell(context, '已邀请好友', '$_count 位')),
        const SizedBox(width: 10),
        Expanded(child: _statCell(context, '累计赚积分', '$_score 分')),
      ],
    );
  }

  Widget _statCell(BuildContext context, String label, String value) {
    return KitCard(
      radius: R.lg,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ty.tiny.copyWith(color: context.t3)),
          const SizedBox(height: 5),
          AppCountUp(
            value:
                double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: context.t1,
            ),
            formatter: (v) => value.contains('分')
                ? '${v.toStringAsFixed(0)} 分'
                : value.contains('位')
                ? '${v.toStringAsFixed(0)} 位'
                : v.toStringAsFixed(0),
          ),
        ],
      ),
    );
  }

  // ── 规则说明 ──
  Widget _ruleCard(BuildContext context) {
    return KitCard(
      radius: R.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: C.brandBright),
              const SizedBox(width: 6),
              Text(
                '活动规则',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: context.t1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ruleItem(context, '1', '把邀请码分享给好友'),
          _ruleItem(context, '2', '好友注册时填写你的邀请码'),
          _ruleItem(context, '3', '双方各得 $_each 积分，上不封顶'),
        ],
      ),
    );
  }

  Widget _ruleItem(BuildContext context, String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.brand.withAlpha(26),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              n,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: C.brand,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.8, color: context.t2),
            ),
          ),
        ],
      ),
    );
  }

  // ── 底部行动区 ──
  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppPressable(
            onTap: _share,
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 7),
                  Text(
                    '立即邀请好友',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
