import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/soft_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../models/app_config.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';

/// 关于软件（v40 重做）
///
/// 全部内容由后台「关于软件」配置下发：
///   应用名 / 版本号 / Logo / 一句话简介 / 详细介绍 /
///   版权 / 联系方式 / 官网 / 检查更新地址 / 自定义条目
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  AppConfig? _cfg;
  String _localVersion = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _localVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    try {
      _cfg = await SoftService.instance.fetchConfig();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(context.pagePadding, 8,
                        context.pagePadding, context.tabSpace + 30),
                    children: [
                      _topBar(),
                      const SizedBox(height: 20),
                      // v52m #7：关于页三模板
                      ..._aboutBody(cfg),
                      const SizedBox(height: 22),
                      _footer(cfg),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── 顶栏 ──
  Widget _topBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withAlpha(14) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(8),
              ),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: context.t1),
          ),
        ),
        const SizedBox(width: 12),
        ShaderMask(
          shaderCallback: (r) => Deco.aurora().createShader(r),
          child: Text('关于软件',
              style: Ty.h2.copyWith(color: Colors.white, fontSize: 21)),
        ),
      ],
    );
  }

  // ── 头部：Logo + 名称 + 版本 ──
  /// v52m #7：关于页三模板 card / hero / minimal
  List<Widget> _aboutBody(AppConfig? cfg) {
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.aboutTemplate ?? 'card';
    if (tpl == 'hero') {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            gradient: C.brandGradient,
            borderRadius: BorderRadius.circular(R.xl),
          ),
          child: Column(
            children: [
              Text(cfg?.aboutName ?? '安逸软件汇',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              if ((cfg?.aboutSlogan ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(cfg!.aboutSlogan,
                    style: TextStyle(
                        color: Colors.white.withAlpha(210), fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _hero(cfg),
        const SizedBox(height: 22),
        if ((cfg?.aboutDesc ?? '').isNotEmpty) ...[
          _descCard(cfg!.aboutDesc),
          const SizedBox(height: 14),
        ],
        _infoList(cfg),
        const SizedBox(height: 16),
        _extraEntries(cfg),
      ];
    }
    if (tpl == 'minimal') {
      return [
        _hero(cfg),
        const SizedBox(height: 16),
        _infoList(cfg),
        const SizedBox(height: 16),
        _extraEntries(cfg),
      ];
    }
    if (tpl == 'dark_card') {
      // v52t：深色卡模板
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.isDark ? C.bg0 : const Color(0xFF15181F),
            borderRadius: BorderRadius.circular(R.xl),
          ),
          child: Column(
            children: [
              Text(cfg?.aboutName ?? '安逸软件汇',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              if ((cfg?.aboutSlogan ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(cfg!.aboutSlogan,
                    style: TextStyle(
                        color: Colors.white.withAlpha(170),
                        fontSize: 12.5)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _hero(cfg),
        const SizedBox(height: 22),
        if ((cfg?.aboutDesc ?? '').isNotEmpty) ...[
          _descCard(cfg!.aboutDesc),
          const SizedBox(height: 14),
        ],
        _infoList(cfg),
        const SizedBox(height: 16),
        _extraEntries(cfg),
      ];
    }
    if (tpl == 'plain') {
      // v52w：纯文字排版（无卡无边框，编辑器风）
      return [
        Text(cfg?.aboutName ?? '安逸软件汇',
            style: Ty.display.copyWith(color: context.t1)),
        if ((cfg?.aboutSlogan ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(cfg!.aboutSlogan,
              style: TextStyle(fontSize: 13.5, color: context.t3)),
        ],
        const SizedBox(height: 22),
        if ((cfg?.aboutDesc ?? '').isNotEmpty) ...[
          Text(cfg!.aboutDesc,
              style: TextStyle(fontSize: 14, height: 1.8, color: context.t2)),
          const SizedBox(height: 22),
        ],
        _infoList(cfg),
        const SizedBox(height: 16),
        _extraEntries(cfg),
      ];
    }
    if (tpl == 'dark_card') {
      // v52t：桌面风模板（左logo右信息横向卡）
      final logo = cfg?.aboutLogo ?? '';
      return [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.isDark
                ? Colors.white.withAlpha(10)
                : Colors.white,
            borderRadius: BorderRadius.circular(R.xl),
            border: Border.all(
                color: context.isDark
                    ? Colors.white.withAlpha(18)
                    : Colors.black.withAlpha(12)),
          ),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                clipBehavior: Clip.antiAlias,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(18)),
                child: logo.isEmpty
                    ? _logoFallback()
                    : CachedNetworkImage(
                        imageUrl: logo,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _logoFallback(),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cfg?.aboutName ?? '安逸软件汇',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: context.t1)),
                    const SizedBox(height: 4),
                    Text(cfg?.aboutSlogan ?? '',
                        style: TextStyle(
                            fontSize: 12, color: context.t3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if ((cfg?.aboutDesc ?? '').isNotEmpty) ...[
          _descCard(cfg!.aboutDesc),
          const SizedBox(height: 14),
        ],
        _infoList(cfg),
        const SizedBox(height: 16),
        _extraEntries(cfg),
      ];
    }
    return [
      _hero(cfg),
      const SizedBox(height: 22),
      if ((cfg?.aboutDesc ?? '').isNotEmpty) ...[
        _descCard(cfg!.aboutDesc),
        const SizedBox(height: 14),
      ],
      _infoList(cfg),
      const SizedBox(height: 16),
      _extraEntries(cfg),
    ];
  }

  Widget _hero(AppConfig? cfg) {
    final name = cfg?.aboutName ?? '安逸软件汇';
    final logo = cfg?.aboutLogo ?? '';
    final slogan = cfg?.aboutSlogan ?? '';
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: C.brand.withAlpha(context.isDark ? 90 : 60),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: logo.isEmpty
                ? _logoFallback()
                : CachedNetworkImage(
                    imageUrl: logo,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    placeholder: (_, __) => _logoFallback(),
                    errorWidget: (_, __, ___) => _logoFallback(),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(name, style: Ty.h1.copyWith(fontSize: 22, color: context.t1)),
        const SizedBox(height: 6),
        if (slogan.isNotEmpty)
          Text(slogan, style: Ty.small.copyWith(color: context.t3)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _localVersion));
            ToastUtil.success('版本号已复制');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: C.brand.withAlpha(context.isDark ? 40 : 26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.brand.withAlpha(80), width: 0.8),
            ),
            child: Text('v${cfg?.aboutVersion ?? _localVersion}',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: C.brand)),
          ),
        ),
      ],
    );
  }

  Widget _logoFallback() => Container(
        decoration: BoxDecoration(gradient: Deco.brandGradient),
        alignment: Alignment.center,
        child: const Icon(Icons.android_rounded, color: Colors.white, size: 40),
      );

  // ── 详细介绍 ──
  Widget _descCard(String desc) {
    return KitCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 3.5,
                  height: 14,
                  decoration: BoxDecoration(
                      color: C.brand, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('软件介绍',
                  style: Ty.h3.copyWith(fontSize: 14.5, color: context.t1)),
            ],
          ),
          const SizedBox(height: 10),
          Text(desc,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.8,
                  color: context.isDark
                      ? Colors.grey[300]
                      : const Color(0xFF41454B))),
        ],
      ),
    );
  }

  // ── 信息列表 ──
  Widget _infoList(AppConfig? cfg) {
    // ★ 每行带自己的 onTap（修复「按键没功能」）
    final rows = <({IconData icon, Color color, String label, String value, VoidCallback? onTap})>[];
    void add(IconData i, Color c, String label, String value,
        {VoidCallback? onTap}) {
      if (value.isEmpty) return;
      rows.add((icon: i, color: c, label: label, value: value, onTap: onTap));
    }

    final contact = cfg?.aboutContact ?? '';
    final website = cfg?.aboutWebsite ?? '';
    final updateUrl = cfg?.aboutUpdateUrl ?? '';
    add(Icons.alternate_email_rounded, C.cyan, '联系方式', contact,
        onTap: contact.isEmpty ? null : () => _copy(contact));
    add(Icons.language_rounded, C.mint, '官方网站', website,
        onTap: website.isEmpty ? null : () => _openUrl(website));
    add(Icons.system_update_rounded, C.violet, '检查更新',
        updateUrl.isEmpty ? '' : '前往下载最新版',
        onTap: updateUrl.isEmpty ? null : () => _openUrl(updateUrl));
    add(Icons.share_rounded, C.brandBright, '分享本软件', '推荐给朋友',
        onTap: _shareApp);
    add(Icons.description_rounded, C.violet, '用户协议', '查看详情',
        onTap: () => Get.toNamed('/agreement', arguments: {'type': 'agreement'}));
    add(Icons.privacy_tip_rounded, C.pink, '隐私政策', '查看详情',
        onTap: () => Get.toNamed('/agreement', arguments: {'type': 'privacy'}));

    if (rows.isEmpty) return const SizedBox.shrink();

    return KitCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: context.isDark
                      ? Colors.white.withAlpha(14)
                      : Colors.black.withAlpha(8)),
            InkWell(
              onTap: rows[i].onTap ??
                  (rows[i].value.isEmpty ? null : () => _copy(rows[i].value)),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: rows[i].color
                            .withAlpha(context.isDark ? 38 : 24),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child:
                          Icon(rows[i].icon, size: 15, color: rows[i].color),
                    ),
                    const SizedBox(width: 11),
                    Text(rows[i].label,
                        style: Ty.body
                            .copyWith(fontSize: 13.5, color: context.t2)),
                    const Spacer(),
                    Flexible(
                      child: Text(rows[i].value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: Ty.small.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: rows[i].onTap != null
                                  ? C.brand
                                  : context.t1)),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: context.t3),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 打开链接（带错误提示）
  void _openUrl(String url) {
    if (url.isEmpty) return;
    try {
      JumpUtil.openUrl(url);
    } catch (e) {
      ToastUtil.error('无法打开链接');
    }
  }

  /// 分享本软件（系统分享面板）
  Future<void> _shareApp() async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        '推荐一个好用的软件库：${_cfg?.aboutName ?? '安逸软件汇'}\n${_cfg?.aboutWebsite ?? ''}',
        subject: _cfg?.aboutName ?? '安逸软件汇',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      ToastUtil.error('分享失败');
    }
  }

  void _copy(String s) {
    Clipboard.setData(ClipboardData(text: s));
    ToastUtil.success('已复制：$s');
  }

  // ── 后台自定义条目（about_extra: [{"title","content","url"}]）──
  Widget _extraEntries(AppConfig? cfg) {
    final raw = cfg?.aboutExtra ?? '';
    if (raw.trim().isEmpty) return const SizedBox.shrink();
    final items = <Map<String, String>>[];
    try {
      final reg = RegExp(r'\{[^{}]*\}');
      for (final m in reg.allMatches(raw)) {
        final o = m.group(0)!;
        String pick(String k) {
          final r = RegExp('"' + k + r'"\s*:\s*"([^"]*)"');
          final mm = r.firstMatch(o);
          return mm?.group(1) ?? '';
        }

        final t = pick('title');
        if (t.isEmpty) continue;
        items.add({'title': t, 'content': pick('content'), 'url': pick('url')});
      }
    } catch (_) {}
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final it in items) ...[
          KitCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            onTap: (it['url'] ?? '').isEmpty
                ? null
                : () => JumpUtil.openUrl(it['url']!),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it['title']!,
                          style: Ty.h3
                              .copyWith(fontSize: 14, color: context.t1)),
                      if ((it['content'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(it['content']!,
                            style: Ty.small.copyWith(color: context.t3)),
                      ],
                    ],
                  ),
                ),
                if ((it['url'] ?? '').isNotEmpty)
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: context.t3),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── 页脚（全部由后台配置，无写死内容）──
  Widget _footer(AppConfig? cfg) {
    final copyright = cfg?.aboutCopyright ?? '';
    final footer = cfg?.aboutFooter ?? '';
    return Column(
      children: [
        if (copyright.isNotEmpty)
          Text(copyright,
              textAlign: TextAlign.center,
              style: Ty.tiny.copyWith(color: context.t3)),
        if (footer.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(footer,
              textAlign: TextAlign.center,
              style: Ty.tiny.copyWith(fontSize: 10, color: context.t3)),
        ],
      ],
    );
  }
}
