import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/soft_service.dart' show SoftService;
import '../../api/toolbox_service.dart';
import '../../design/ad.dart';
import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';
import '../../utils/img_saver.dart';
import '../../widgets/media_preview.dart';
import 'tool_browser_page.dart';
import 'tool_kit.dart';
import 'tool_player_page.dart';

/// ═══════════════════════════════════════════════════════════════
/// 工具箱 · 联网工具（v3.3.4）
///
/// ★ 一律走**后端代理**（服务端直采官方站 + 缓存），不直连第三方聚合站
///   —— 那些站点限流/失效极频繁，客户端直连必然出现空列表。
///
/// 已实测可用的上游：百度热榜页内嵌 JSON、B站官方接口、wttr.in、
/// 今日诗词、MyMemory 翻译、open.er-api 汇率、USGS 地震，
/// 以及后端聚合的影视/音乐/短剧/新闻/王者图集/漫画。
/// ═══════════════════════════════════════════════════════════════

// ═══════════ 热榜（百度多榜 + B站） ═══════════
/// ★ 1015：App 内打开外链（不跳系统浏览器）
///   工具页里所有「内容/详情类」链接都走这里，统一用内置 WebView 打开
/// ★★★ 1015 致命修复（热搜点条目闪退）：
///   原来用 App 内 WebView 打开热搜链接。
///   但热搜条目指向的是**百度/微博/抖音的手机页面** —— 这类页面极重
///   （大量 JS、自动播放视频、广告），在 WebView 里内存暴涨；
///   用户连点几条 → Native 层 OOM → **直接闪退回桌面**（Dart 层抓不到）。
///   改为交给**系统浏览器**打开：不占 App 内存，也符合"看资讯"的使用习惯。
void _openInApp(String url) {
  if (url.isEmpty || !url.startsWith('http')) return;
  try {
    // 交给系统浏览器（不占 App 内存，杜绝 OOM 闪退）
    launchUrlString(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    ToastUtil.error('无法打开链接');
  }
}

/// 工具箱公共
class HotPage extends StatefulWidget {
  final String title;
  final String apiUrl;
  const HotPage({super.key, required this.title, this.apiUrl = ''});

  @override
  State<HotPage> createState() => _HotPageState();
}

class _HotPageState extends State<HotPage> {
  final _svc = ToolboxService.instance;
  /// ★ 1015：板块改为「服务端下发 + 内置兜底」。
  ///   原来写死 6 个，导致微博/抖音/头条这些必须各占一条工具（3 条功能重复）。
  ///   现在一条「全网热搜」就能覆盖所有平台/板块，板块随服务端增加而自动变多。
  static const _fallbackTabs = <(String, String, String)>[
    ('baidu', 'realtime', '百度热搜'),
    ('weibo', '', '微博热搜'),
    ('douyin', '', '抖音热点'),
    ('toutiao', '', '头条热榜'),
    ('zhihu', '', '知乎热榜'),
    ('bili', '', 'B站热搜'),
    ('baidu', 'finance', '财经'),
    ('baidu', 'sports', '体育'),
    ('baidu', 'new_entertainment', '文娱'),
    ('baidu', 'livelihood', '民生'),
  ];
  List<(String, String, String)> _tabs = List.of(_fallbackTabs);
  int _i = 0;
  List<Map<String, dynamic>> _list = [];
  String _label = '';
  bool _loading = true;
  String _err = '';
  /// ★ 1015：请求序号 —— 快速切板块时丢弃过期响应，防止旧数据覆盖新数据
  ///   （原来每次切 Tab 都发新请求且不取消旧的，连点会堆积 → 卡顿/卡死）
  int _reqSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // ★ 1015：记录本次请求序号，响应回来时比对，过期就丢弃
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final idx = _i; // 记住发起时的板块下标
      final d = await _svc.hot(type: _tabs[idx].$1, board: _tabs[idx].$2);
      // ★ 1015 诊断：上报实际拿到什么（排查「热搜刷新也不切换」）
      try {
        SoftService.reportLogStatic(
          tag: 'hot',
          error: '[hot-res] tab=${_tabs[idx].$3} type=${_tabs[idx].$1} board=${_tabs[idx].$2} '
              'null=${d == null} keys=${d?.keys.toList()} '
              'listLen=${((d?["list"] as List?) ?? []).length}',
        ).catchError((_) {});
      } catch (_) {}
      // 过期响应（用户已经切到别的板块了）→ 直接丢弃，不 setState
      if (!mounted || seq != _reqSeq || idx != _i) return;
      // ★ 1015 加固：逐条容错 —— 任何一条数据格式异常都不允许拖垮整页
      //   （原来 .map(...as Map) 一旦某条不是 Map 就抛异常 → 整屏渲染失败 → 卡死）
      final l = <Map<String, dynamic>>[];
      for (final e in ((d?['list'] as List?) ?? [])) {
        try {
          if (e is Map) {
            l.add(Map<String, dynamic>.from(e));
          } else if (e is String) {
            l.add({'title': e});
          }
        } catch (_) {}
      }
      setState(() {
        _list = l;
        _label = '${d?['label'] ?? ''}';
        _loading = false;
        _err = l.isEmpty ? '暂时没有拿到榜单数据' : '';
      });
    } catch (e) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: widget.title.isEmpty ? '热榜' : widget.title,
      subtitle: _label.isEmpty ? '实时更新' : _label,
      actions: [_refresh(_load, context)],
      child: Column(
        children: [
          ToolChips<int>(
            items: [for (int i = 0; i < _tabs.length; i++) (i, _tabs[i].$3)],
            current: _i,
            onPick: (i) {
              // ★ 1015 诊断：切换板块时上报
              try {
                SoftService.reportLogStatic(
                  tag: 'hot',
                  error: '[hot-tab] $i (${_tabs[i].$3})',
                ).catchError((_) {});
              } catch (_) {}
              setState(() => _i = i);
              _load();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const LoadingState(text: '正在拉取榜单…')
                : _list.isEmpty
                ? EmptyState(
                    icon: Icons.local_fire_department_outlined,
                    text: _err.isEmpty ? '暂无数据' : _err,
                    hint: '点击右上角刷新重试',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: C.brand,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: _list.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: context.isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(6),
                      ),
                      itemBuilder: (c, i) {
                        final it = _list[i];
                        final rank = int.tryParse('${it['rank']}') ?? (i + 1);
                        final top3 = rank <= 3;
                        final hot = '${it['hot'] ?? ''}';
                        return AppPressable(
                          onTap: () {
                            final u = '${it['url'] ?? ''}';
                            if (u.isNotEmpty) _openInApp(u);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    '$rank',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: top3 ? C.danger : context.t3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${it['title'] ?? ''}',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          height: 1.45,
                                          fontWeight: top3
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: context.t1,
                                        ),
                                      ),
                                      if ('${it['desc'] ?? ''}'
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${it['desc']}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Ty.tiny.copyWith(
                                            color: context.t3,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (hot.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      hot,
                                      style: Ty.tiny.copyWith(
                                        color: context.t3,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 通用刷新按钮
Widget _refresh(Future<void> Function() onTap, BuildContext context) =>
    AppPressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(Icons.refresh_rounded, size: 21, color: context.t2),
      ),
    );

// ═══════════ 每日 60 秒 ═══════════
class Daily60Page extends StatefulWidget {
  final String title;
  const Daily60Page({super.key, required this.title});

  @override
  State<Daily60Page> createState() => _Daily60PageState();
}

class _Daily60PageState extends State<Daily60Page> {
  final _svc = ToolboxService.instance;
  Map<String, dynamic>? _d;
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
      final d = await _svc.daily60();
      if (!mounted) return;
      setState(() {
        _d = d;
        _loading = false;
        _err = d == null ? '日报拉取失败，请稍后重试' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final news = ((d?['news'] as List?) ?? []).map((e) => '$e').toList();
    return ToolScaffold(
      title: widget.title.isEmpty ? '每日 60 秒' : widget.title,
      subtitle: news.isEmpty
          ? '一分钟读懂今天'
          : '${d?['date'] ?? ''} ${d?['lunar'] ?? ''}',
      actions: [_refresh(_load, context)],
      child: _loading
          ? const LoadingState(text: '正在拉取日报…')
          : news.isEmpty
          ? EmptyState(
              icon: Icons.newspaper_outlined,
              text: _err.isEmpty ? '暂无日报' : _err,
              hint: '点击右上角刷新重试',
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: C.brand,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  ...news.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 21,
                            height: 21,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: C.brand.withAlpha(24),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: C.brand,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.65,
                                color: context.t1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if ('${d?['tip'] ?? ''}'.isNotEmpty)
                    ToolCard(
                      margin: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 17,
                            color: C.amber,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '${d?['tip']}',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color: context.t2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ═══════════ Epic 喜加一 ═══════════
class EpicPage extends StatefulWidget {
  final String title;
  const EpicPage({super.key, required this.title});

  @override
  State<EpicPage> createState() => _EpicPageState();
}

class _EpicPageState extends State<EpicPage> {
  final _svc = ToolboxService.instance;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String _err = '';

  /// 把 ISO 时间转成 MM-dd（界面显示「至 10-23」）
  String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

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
      final l = await _svc.epic();
      if (!mounted) return;
      setState(() {
        _list = l;
        _loading = false;
        _err = l.isEmpty ? '当前没有免费游戏' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: widget.title.isEmpty ? 'Epic 喜加一' : widget.title,
      subtitle: '限时免费游戏',
      actions: [_refresh(_load, context)],
      child: _loading
          ? const LoadingState(text: '正在拉取…')
          : _list.isEmpty
          ? EmptyState(
              icon: Icons.videogame_asset_outlined,
              text: _err.isEmpty ? '暂无数据' : _err,
              hint: '点击右上角刷新重试',
            )
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: context.tabSpace + 20),
              itemCount: _list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (c, i) {
                final it = _list[i];
                // ★ 1015 修复：服务端字段是 cover/link，原来读 image/url 导致封面和跳转全失效
                final img = '${it['cover'] ?? it['image'] ?? ''}';
                final link = '${it['link'] ?? it['url'] ?? ''}';
                final desc = '${it['desc'] ?? ''}';
                final orig = '${it['original'] ?? ''}';
                final isNow = '${it['status'] ?? 'now'}' == 'now';
                final end = _fmtDate('${it['end'] ?? ''}');
                return ToolCard(
                  padding: EdgeInsets.zero,
                  onTap: link.isEmpty
                      ? null
                      : () => Get.to(() => ToolBrowserPage(title: '${it['title'] ?? ''}', url: link)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 封面（16:9 大图）
                      if (img.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(R.lg)),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: CachedNetworkImage(
                              imageUrl: img,
                              fit: BoxFit.cover,
                              memCacheWidth: 800,
                              placeholder: (_, __) => Container(color: C.brand.withAlpha(16)),
                              errorWidget: (_, __, ___) => Container(
                                color: C.brand.withAlpha(16),
                                child: const Center(child: Icon(Icons.videogame_asset_rounded, size: 34)),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题 + 状态标签
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${it['title'] ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      height: 1.35,
                                      color: context.t1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isNow ? C.success : C.warning).withAlpha(30),
                                    borderRadius: BorderRadius.circular(R.full),
                                  ),
                                  child: Text(
                                    isNow ? '本周免费' : '即将免费',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: isNow ? C.success : C.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Ty.tiny.copyWith(color: context.t3, height: 1.55),
                              ),
                            ],
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                if (orig.isNotEmpty && orig != '0.00') ...[
                                  Text('¥$orig',
                                      style: Ty.tiny.copyWith(
                                        color: context.t3,
                                        decoration: TextDecoration.lineThrough,
                                      )),
                                  const SizedBox(width: 7),
                                ],
                                Text('免费',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: C.success,
                                    )),
                                const Spacer(),
                                if (end.isNotEmpty) ...[
                                  Icon(Icons.schedule_rounded, size: 13, color: context.t3),
                                  const SizedBox(width: 3),
                                  Text('至 $end', style: Ty.tiny.copyWith(color: context.t3)),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: Deco.brandGradient,
                                    borderRadius: BorderRadius.circular(R.full),
                                  ),
                                  child: const Text('去领取',
                                      style: TextStyle(
                                          fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ═══════════ 地震数据 ═══════════
class EarthquakePage extends StatefulWidget {
  const EarthquakePage({super.key});
  @override
  State<EarthquakePage> createState() => _EarthquakePageState();
}

class _EarthquakePageState extends State<EarthquakePage> {
  final _svc = ToolboxService.instance;
  List<Map<String, dynamic>> _list = [];
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
      final l = await _svc.earthquake();
      if (!mounted) return;
      setState(() {
        _list = l;
        _loading = false;
        _err = l.isEmpty ? '暂时没有地震数据' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Color _color(double m) {
    if (m >= 7) return C.danger;
    if (m >= 6) return C.accentOrange;
    if (m >= 5) return C.warning;
    return C.mint;
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '地震数据',
      subtitle: '近 40 条 · M4.5 以上（USGS 实时）',
      actions: [_refresh(_load, context)],
      child: _loading
          ? const LoadingState(text: '正在拉取地震数据…')
          : _list.isEmpty
          ? EmptyState(
              icon: Icons.public_off_outlined,
              text: _err.isEmpty ? '暂无数据' : _err,
              hint: '点击右上角刷新重试',
            )
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (c, i) {
                final it = _list[i];
                final mag = double.tryParse('${it['mag'] ?? 0}') ?? 0;
                final col = _color(mag);
                return ToolCard(
                  padding: const EdgeInsets.all(13),
                  onTap: () {
                    final u = '${it['url'] ?? ''}';
                    if (u.isNotEmpty) _openInApp(u);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: col.withAlpha(30),
                          borderRadius: BorderRadius.circular(R.md),
                        ),
                        child: Text(
                          mag.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: col,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${it['place'] ?? it['title'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                                color: context.t1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '深度 ${it['depth'] ?? '--'} km · ${it['time'] ?? ''}',
                              style: Ty.tiny.copyWith(color: context.t3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ═══════════ 每日诗句 ═══════════
class PoemPage extends StatefulWidget {
  const PoemPage({super.key});
  @override
  State<PoemPage> createState() => _PoemPageState();
}

class _PoemPageState extends State<PoemPage> {
  final _svc = ToolboxService.instance;
  Map<String, dynamic>? _d;
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
    final d = await _svc.poem();
    if (!mounted) return;
    setState(() {
      _d = d;
      _loading = false;
      _err = d == null ? '诗句拉取失败' : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return ToolScaffold(
      title: '每日诗句',
      subtitle: '今日诗词',
      actions: [_refresh(_load, context)],
      child: _loading
          ? const LoadingState(text: '正在取诗…')
          : _err.isNotEmpty
          ? EmptyState(
              icon: Icons.auto_stories_outlined,
              text: _err,
              hint: '点击右上角刷新',
            )
          : Center(
              child: ToolCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 34,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 30,
                      color: C.brand.withAlpha(120),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '${d?['content'] ?? ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: context.t1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '—— ${d?['author'] ?? ''}《${d?['origin'] ?? ''}》',
                      style: Ty.small.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ═══════════ 每日一言 ═══════════
class HitokotoPage extends StatefulWidget {
  const HitokotoPage({super.key});
  @override
  State<HitokotoPage> createState() => _HitokotoPageState();
}

class _HitokotoPageState extends State<HitokotoPage> {
  final _svc = ToolboxService.instance;
  Map<String, dynamic>? _d;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _svc.hitokoto();
    if (!mounted) return;
    setState(() {
      _d = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final from = '${d?['from'] ?? ''}';
    return ToolScaffold(
      title: '每日一言',
      actions: [_refresh(_load, context)],
      child: _loading
          ? const LoadingState(text: '正在取一句话…')
          : Center(
              child: ToolCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      '${d?['text'] ?? ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.9,
                        fontWeight: FontWeight.w600,
                        color: context.t1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${d?['who'] ?? ''}${from.isEmpty ? '' : '《$from》'}',
                      style: Ty.small.copyWith(color: context.t3),
                    ),
                    const SizedBox(height: 20),
                    ToolButton(
                      label: '复制',
                      icon: Icons.copy_rounded,
                      outline: true,
                      height: 42,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: '${d?['text'] ?? ''}'),
                        );
                        ToastUtil.success('已复制');
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ═══════════ 在线翻译 ═══════════
class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});
  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final _in = TextEditingController();
  final _out = TextEditingController();
  String _from = '自动';
  String _to = '英语';
  bool _loading = false;

  static const _langs = ['中文', '英语', '日语', '韩语', '法语', '德语', '西班牙语', '俄语'];

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  String _code(String n) => switch (n) {
    '中文' => 'zh-CN',
    '英语' => 'en',
    '日语' => 'ja',
    '韩语' => 'ko',
    '法语' => 'fr',
    '德语' => 'de',
    '西班牙语' => 'es',
    '俄语' => 'ru',
    _ => 'en',
  };

  Future<void> _go() async {
    final text = _in.text.trim();
    if (text.isEmpty) {
      ToastUtil.error('请输入要翻译的内容');
      return;
    }
    setState(() => _loading = true);
    try {
      final src = _from == '自动' ? 'zh-CN' : _code(_from);
      final r = await ToolboxService.instance.translate(
        text,
        pair: '$src|${_code(_to)}',
      );
      if (!mounted) return;
      final t = '${r?['text'] ?? ''}';
      setState(() {
        _out.text = t.isEmpty ? '（没有拿到翻译结果）' : t;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '在线翻译',
      subtitle: '多语言互译',
      // ★ 1015：去掉 scrollable（内含 Expanded，滚动容器里放 Expanded 会布局死循环→卡死）
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _pick(_from, true)),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, size: 18, color: context.t3),
              const SizedBox(width: 10),
              Expanded(child: _pick(_to, false)),
            ],
          ),
          const SizedBox(height: 14),
          ToolField(
            controller: _in,
            label: '原文',
            hint: '输入要翻译的文本',
            lines: 4,
          ),
          ToolButton(
            label: '翻译',
            icon: Icons.translate_rounded,
            loading: _loading,
            onPressed: _go,
          ),
          const SizedBox(height: 16),
          ToolField(
            controller: _out,
            label: '译文',
            lines: 5,
            suffixIcon: Icons.copy_rounded,
            onSuffixTap: () {
              if (_out.text.isEmpty) return;
              Clipboard.setData(ClipboardData(text: _out.text));
              ToastUtil.success('已复制译文');
            },
          ),
        ],
      ),
    );
  }

  Widget _pick(String cur, bool isFrom) => PopupMenuButton<String>(
    initialValue: cur,
    onSelected: (v) => setState(() {
      if (isFrom) {
        _from = v;
      } else {
        _to = v;
      }
    }),
    color: context.cardBg,
    itemBuilder: (c) => [
      for (final l in _langs)
        PopupMenuItem(
          value: l,
          child: Text(
            l,
            style: TextStyle(
              fontSize: 14,
              color: l == cur ? C.brand : context.t1,
              fontWeight: l == cur ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
    ],
    child: Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: C.brand.withAlpha(16),
        borderRadius: BorderRadius.circular(R.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cur,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: C.brand,
            ),
          ),
          Icon(Icons.arrow_drop_down_rounded, size: 18, color: C.brand),
        ],
      ),
    ),
  );
}

// ═══════════ 汇率换算 ═══════════
class ExchangePage extends StatefulWidget {
  const ExchangePage({super.key});
  @override
  State<ExchangePage> createState() => _ExchangePageState();
}

class _ExchangePageState extends State<ExchangePage> {
  final _svc = ToolboxService.instance;
  final _amt = TextEditingController(text: '100');
  Map<String, dynamic>? _rates;
  bool _loading = true;
  String _err = '';
  String _from = 'CNY';
  String _to = 'USD';

  static const _names = <String, String>{
    'CNY': '人民币',
    'USD': '美元',
    'EUR': '欧元',
    'JPY': '日元',
    'GBP': '英镑',
    'HKD': '港币',
    'KRW': '韩元',
    'AUD': '澳元',
    'CAD': '加元',
    'SGD': '新加坡元',
    'RUB': '卢布',
    'THB': '泰铢',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amt.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final r = await _svc.exchange('CNY');
      if (!mounted) return;
      final rates = r?['rates'];
      setState(() {
        _rates = rates is Map ? Map<String, dynamic>.from(rates) : null;
        _loading = false;
        _err = _rates == null ? '汇率获取失败' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double get _result {
    final r = _rates;
    if (r == null) return 0;
    final v = double.tryParse(_amt.text.trim()) ?? 0;
    final fr = _from == 'CNY' ? 1.0 : (double.tryParse('${r[_from]}') ?? 1);
    final tr = double.tryParse('${r[_to]}') ?? 1;
    return fr == 0 ? 0 : v / fr * tr;
  }

  List<String> get _keys {
    final r = _rates;
    if (r == null) return ['CNY', 'USD'];
    final k = r.keys.where((e) => _names.containsKey(e)).toList();
    if (!k.contains('CNY')) k.insert(0, 'CNY');
    return k;
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '汇率换算',
      subtitle: '实时汇率 · 每日更新',
      actions: [_refresh(_load, context)],
      // ★ 1015：去掉 scrollable（内含 Expanded，滚动容器里放 Expanded 会布局死循环→卡死）
      child: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          : Column(
              children: [
                if (_err.isNotEmpty)
                  ToolCard(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: C.warning,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _err,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.t2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ToolCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amt,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: context.t1,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _pick(_from, true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _line(context)),
                          AppPressable(
                            onTap: () => setState(() {
                              final t = _from;
                              _from = _to;
                              _to = t;
                            }),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: Deco.brandGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.swap_vert_rounded,
                                size: 19,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(child: _line(context)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _result == 0
                                  ? '0'
                                  : _result
                                        .toStringAsFixed(4)
                                        .replaceAll(RegExp(r'0+$'), '')
                                        .replaceAll(RegExp(r'\.$'), ''),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: C.brand,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _pick(_to, false),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_rates != null)
                  ToolCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '常用参考',
                          style: Ty.h3.copyWith(color: context.t1),
                        ),
                        const SizedBox(height: 10),
                        for (final k in ['USD', 'EUR', 'JPY', 'HKD', 'GBP'])
                          if (_rates!.containsKey(k))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '1 ${_names[k]}（$k）',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: context.t2,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '≈ ${double.tryParse('${_rates![k]}')?.toStringAsFixed(4) ?? '--'} CNY',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.t1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _line(BuildContext c) => Container(
    height: 1,
    color: c.isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
  );

  Widget _pick(String cur, bool isFrom) => PopupMenuButton<String>(
    initialValue: cur,
    onSelected: (v) => setState(() {
      if (isFrom) {
        _from = v;
      } else {
        _to = v;
      }
    }),
    color: context.cardBg,
    itemBuilder: (c) => [
      for (final k in _keys)
        PopupMenuItem(
          value: k,
          child: Text(
            '${_names[k] ?? k}（$k）',
            style: TextStyle(
              fontSize: 14,
              color: k == cur ? C.brand : context.t1,
              fontWeight: k == cur ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.brand.withAlpha(18),
        borderRadius: BorderRadius.circular(R.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cur,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: C.brand,
            ),
          ),
          Icon(Icons.arrow_drop_down_rounded, size: 18, color: C.brand),
        ],
      ),
    ),
  );
}

// ═══════════ IP 查询 ═══════════
class IpPage extends StatefulWidget {
  const IpPage({super.key});
  @override
  State<IpPage> createState() => _IpPageState();
}

class _IpPageState extends State<IpPage> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _d;
  bool _loading = false;
  String _err = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final r = await ToolboxService.instance.ipQuery(_ctrl.text.trim());
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (r == null) {
          _d = null;
          _err = '查询失败，请填写具体 IP（例：8.8.8.8）';
        } else {
          _d = r;
          _err = '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return ToolScaffold(
      title: 'IP 查询',
      subtitle: '归属地 / 运营商',
      // ★ 1015：去掉 scrollable（内含 Expanded，滚动容器里放 Expanded 会布局死循环→卡死）
      child: Column(
        children: [
          ToolField(
            controller: _ctrl,
            label: 'IP 地址',
            hint: '例：8.8.8.8',
            icon: Icons.location_on_outlined,
            onSubmitted: (_) => _go(),
          ),
          ToolButton(
            label: '查询',
            icon: Icons.search_rounded,
            loading: _loading,
            onPressed: _go,
          ),
          const SizedBox(height: 18),
          if (_err.isNotEmpty)
            ToolCard(
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 17, color: C.danger),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _err,
                      style: TextStyle(fontSize: 13, color: context.t2),
                    ),
                  ),
                ],
              ),
            ),
          if (d != null)
            ToolCard(
              child: Column(
                children: [
                  for (final e in [
                    ('IP', '${d['query'] ?? ''}'),
                    ('国家 / 地区', '${d['country'] ?? ''}'),
                    ('省份', '${d['regionName'] ?? ''}'),
                    ('城市', '${d['city'] ?? ''}'),
                    ('运营商', '${d['isp'] ?? ''}'),
                    ('时区', '${d['timezone'] ?? ''}'),
                    ('经纬度', '${d['lat'] ?? ''}, ${d['lon'] ?? ''}'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: Ad.w(context, 84),
                            child: Text(
                              e.$1,
                              style: Ty.small.copyWith(color: context.t3),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.$2.isEmpty ? '--' : e.$2,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.t1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════ 天气查询 ═══════════
class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});
  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final _svc = ToolboxService.instance;
  final _ctrl = TextEditingController(text: '北京');
  Map<String, dynamic>? _d;
  bool _loading = false;
  String _err = '';
  static const _cities = ['北京', '上海', '广州', '深圳', '杭州', '成都', '武汉', '西安'];

  @override
  void initState() {
    super.initState();
    _go();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final city = _ctrl.text.trim();
    if (city.isEmpty) return;
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final d = await _svc.weather(city);
      if (!mounted) return;
      setState(() {
        _d = d;
        _loading = false;
        _err = d == null ? '没有查到「$city」的天气' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final days = ((d?['days'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return ToolScaffold(
      title: '天气查询',
      subtitle: '实时天气 + 3 日预报',
      // ★ 1015：去掉 scrollable（内含 Expanded，滚动容器里放 Expanded 会布局死循环→卡死）
      child: Column(
        children: [
          ToolField(
            controller: _ctrl,
            label: '城市',
            hint: '中文或拼音，例：北京 / beijing',
            icon: Icons.location_city_rounded,
            onSubmitted: (_) => _go(),
          ),
          ToolButton(
            label: '查询',
            icon: Icons.search_rounded,
            loading: _loading,
            onPressed: _go,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cities
                .map<Widget>(
                  (c) => AppPressable(
                    onTap: () {
                      _ctrl.text = c;
                      _go();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: C.brand.withAlpha(14),
                        borderRadius: BorderRadius.circular(R.full),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(fontSize: 12.5, color: C.brand),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          if (_err.isNotEmpty)
            ToolCard(
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 17, color: C.danger),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _err,
                      style: TextStyle(fontSize: 13, color: context.t2),
                    ),
                  ),
                ],
              ),
            ),
          if (d != null)
            ToolCard(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  Text(
                    '${d['city'] ?? ''}',
                    style: Ty.h3.copyWith(color: context.t1),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${d['temp'] ?? '--'}°',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: C.brand,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${d['desc'] ?? ''}',
                    style: TextStyle(fontSize: 15, color: context.t2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '体感 ${d['feels'] ?? '--'}° · 湿度 ${d['humidity'] ?? '--'}% · '
                    '风速 ${d['wind'] ?? '--'} km/h',
                    style: Ty.tiny.copyWith(color: context.t3),
                  ),
                ],
              ),
            ),
          if (days.isNotEmpty) ...[
            const SizedBox(height: 14),
            ToolCard(
              child: Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${day['date'] ?? ''}',
                            style: Ty.tiny.copyWith(
                              fontSize: 10,
                              color: context.t3,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${day['max'] ?? '--'}°',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: C.brand,
                            ),
                          ),
                          Text(
                            '${day['min'] ?? '--'}°',
                            style: TextStyle(fontSize: 13, color: context.t3),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${day['desc'] ?? ''}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.tiny.copyWith(
                              fontSize: 10.5,
                              color: context.t2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════ 影视 / 短剧 ═══════════
class MoviePage extends StatefulWidget {
  final String title;
  final bool drama;
  const MoviePage({super.key, this.title = '影视大全', this.drama = false});

  @override
  State<MoviePage> createState() => _MoviePageState();
}

class _MoviePageState extends State<MoviePage> {
  final _svc = ToolboxService.instance;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String _err = '';
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final List<Map<String, dynamic>> l;
      if (widget.drama) {
        final d = await _svc.dramaList();
        l = ((d?['list'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        final d = await _svc.movieHome();
        final out = <Map<String, dynamic>>[];
        for (final b in ((d?['blocks'] as List?) ?? [])) {
          if (b is Map && b['list'] is List) {
            for (final e in (b['list'] as List)) {
              if (e is Map) out.add(Map<String, dynamic>.from(e));
            }
          }
        }
        l = out;
      }
      if (!mounted) return;
      setState(() {
        _list = l;
        _loading = false;
        _err = l.isEmpty ? '暂时没有拿到数据' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _search(String kw) async {
    final q = kw.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
      _err = '';
    });
    try {
      List<Map<String, dynamic>> l;
      if (widget.drama) {
        final d = await _svc.dramaList();
        l = ((d?['list'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => '${e['name'] ?? ''}'.contains(q))
            .toList();
      } else {
        l = await _svc.movieSearch(q);
      }
      if (!mounted) return;
      setState(() {
        _list = l;
        _loading = false;
        _err = l.isEmpty ? '没有找到「$q」相关内容' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: widget.title,
      subtitle: _searched ? '搜索结果' : '多源聚合 · 在线观看',
      actions: [
        if (_searched)
          AppPressable(
            onTap: () {
              _ctrl.clear();
              setState(() => _searched = false);
              _boot();
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(Icons.close_rounded, size: 20, color: context.t2),
            ),
          ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? Colors.white.withAlpha(10)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(R.full),
                    border: Border.all(
                      color: context.isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 19, color: context.t3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _search,
                          style: TextStyle(fontSize: 14.5, color: context.t1),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: widget.drama ? '搜短剧名称' : '搜电影 / 电视剧 / 综艺',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: context.t3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ToolButton(
                label: '搜索',
                height: 44,
                onPressed: () => _search(_ctrl.text),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const LoadingState(text: '正在加载…')
                : _list.isEmpty
                ? EmptyState(
                    icon: Icons.movie_filter_outlined,
                    text: _err.isEmpty ? '暂无数据' : _err,
                    hint: '换个关键词试试',
                  )
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.62,
                        ),
                    itemCount: _list.length,
                    itemBuilder: (c, i) {
                      final it = _list[i];
                      final img = '${it['pic'] ?? it['cover'] ?? ''}';
                      return AppPressable(
                        onTap: () => Get.to(
                          () => MovieDetailPage(
                            src: '${it['src'] ?? ''}',
                            id: '${it['id'] ?? ''}',
                            name: '${it['name'] ?? ''}',
                            cover: img,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(R.md),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: img.isEmpty
                                      ? Container(
                                          color: C.brand.withAlpha(16),
                                          child: Icon(
                                            Icons.movie_outlined,
                                            color: C.brand.withAlpha(120),
                                          ),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: img,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 400,
                                          placeholder: (_, __) => Container(
                                            color: C.brand.withAlpha(14),
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                                color: C.brand.withAlpha(14),
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  color: context.t3,
                                                  size: 20,
                                                ),
                                              ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '${it['name'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: context.t1,
                              ),
                            ),
                            if ('${it['remarks'] ?? it['year'] ?? ''}'
                                .isNotEmpty)
                              Text(
                                '${it['remarks'] ?? it['year'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ty.tiny.copyWith(
                                  fontSize: 10.5,
                                  color: context.t3,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 短剧（复用影视网格）
class DramaPage extends StatelessWidget {
  const DramaPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const MoviePage(title: '热剧短剧', drama: true);
}

/// 影视详情
class MovieDetailPage extends StatefulWidget {
  final String src;
  final String id;
  final String name;
  final String cover;
  const MovieDetailPage({
    super.key,
    required this.src,
    required this.id,
    required this.name,
    this.cover = '',
  });

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  final _svc = ToolboxService.instance;
  Map<String, dynamic>? _d;
  bool _loading = true;
  String _err = '';

  /// ★ 1015：播放源分组（服务端返回 play_groups，原来只读 play_url 导致「不能看」）
  List<Map<String, dynamic>> _groups = [];
  int _g = 0;

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
      // ★ 1015：带上片名 + all=1 → 服务端跨源找同一部，返回多个源供换源
      final d = await _svc.movieDetail(
        widget.src,
        widget.id,
        name: widget.name,
        all: true,
      );
      if (!mounted) return;
      final raw = d?['play_groups'];
      final gs = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final g in raw) {
          if (g is Map) gs.add(Map<String, dynamic>.from(g));
        }
      }
      setState(() {
        _d = d;
        _groups = gs;
        _g = 0;
        _loading = false;
        _err = d == null ? '详情加载失败' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// 当前源的剧集列表
  List<(String, String)> get _episodes {
    if (_groups.isEmpty || _g >= _groups.length) return const [];
    final eps = _groups[_g]['episodes'];
    if (eps is! List) return const [];
    final out = <(String, String)>[];
    for (final e in eps) {
      if (e is Map) {
        final n = '${e['name'] ?? ''}';
        final u = '${e['url'] ?? ''}';
        if (u.startsWith('http')) out.add((n.isEmpty ? '第${out.length + 1}集' : n, u));
      }
    }
    return out;
  }

  /// ★ 关键：用内置播放器播（原来是 JumpUtil → 跳浏览器，用户以为「不能看」）
  void _play(int index) {
    final eps = _episodes;
    if (eps.isEmpty) {
      ToastUtil.error('该源暂无可用播放地址，换个源试试');
      return;
    }
    final d = _d;
    Get.to(() => ToolPlayerPage(
      url: eps[index].$2,
      title: '${d?['name'] ?? widget.name}',
      cover: '${d?['pic'] ?? widget.cover}',
      subtitle: eps[index].$1,
      playlist: eps,
      initialIndex: index,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final cover = '${d?['pic'] ?? widget.cover}';
    final name = '${d?['name'] ?? widget.name}';
    final intro = '${d?['content'] ?? d?['intro'] ?? ''}';
    final eps = _episodes;

    return ToolScaffold(
      title: name.isEmpty ? '影片详情' : name,
      subtitle: '${d?['type'] ?? ''} ${d?['year'] ?? ''}'.trim(),
      // ★ 1015：去掉 scrollable（内含 Expanded）
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: LoadingState(text: '加载详情…'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：封面 + 基本信息
                ToolCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(R.md),
                        child: cover.startsWith('http')
                            ? Image.network(
                                cover,
                                width: Ad.w(context, 110),
                                height: Ad.h(context, 155),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: Ad.w(context, 110),
                                  height: Ad.h(context, 155),
                                  color: C.brand.withAlpha(24),
                                  child: const Icon(Icons.movie_rounded, size: 34),
                                ),
                              )
                            : Container(
                                width: Ad.w(context, 110),
                                height: Ad.h(context, 155),
                                color: C.brand.withAlpha(24),
                                child: const Icon(Icons.movie_rounded, size: 34),
                              ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15.5, fontWeight: FontWeight.w900, color: context.t1, height: 1.35)),
                            const SizedBox(height: 7),
                            if ('${d?['score'] ?? ''}'.isNotEmpty && '${d?['score']}' != '0.0')
                              _kv(context, '评分', '${d?['score']}'),
                            if ('${d?['area'] ?? ''}'.isNotEmpty) _kv(context, '地区', '${d?['area']}'),
                            if ('${d?['remarks'] ?? ''}'.isNotEmpty) _kv(context, '状态', '${d?['remarks']}'),
                            if ('${d?['director'] ?? ''}'.isNotEmpty)
                              _kv(context, '导演', '${d?['director']}'),
                            if ('${d?['actor'] ?? ''}'.isNotEmpty)
                              _kv(context, '主演', '${d?['actor']}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 播放源选择（多源时显示）
                // ★ 1015：服务端字段是 src_name（原来读 from 显示不出来）
                if (_groups.length > 1) ...[
                  Row(
                    children: [
                      Text('播放源', style: Ty.small.copyWith(fontWeight: FontWeight.w800, color: context.t1)),
                      const SizedBox(width: 8),
                      Text('${_groups.length} 个可选 · 换源可避开广告',
                          style: Ty.tiny.copyWith(color: context.t3)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ToolChips<int>(
                    items: [
                      for (int i = 0; i < _groups.length; i++)
                        (
                          i,
                          '${_groups[i]['src_name'] ?? _groups[i]['from'] ?? '源${i + 1}'}'
                              '${(_groups[i]['episodes'] is List && (_groups[i]['episodes'] as List).isNotEmpty) ? ' · ${(_groups[i]['episodes'] as List).length}集' : ''}',
                        ),
                    ],
                    current: _g,
                    onPick: (v) => setState(() => _g = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // 选集
                if (eps.isNotEmpty) ...[
                  Row(
                    children: [
                      Text('选集', style: Ty.small.copyWith(fontWeight: FontWeight.w800, color: context.t1)),
                      const SizedBox(width: 8),
                      Text('共 ${eps.length} 集', style: Ty.tiny.copyWith(color: context.t3)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < eps.length; i++)
                        AppPressable(
                          onTap: () => _play(i),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 58),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: C.brand.withAlpha(context.isDark ? 26 : 12),
                              borderRadius: BorderRadius.circular(R.sm),
                            ),
                            child: Text(
                              eps[i].$1,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.brand),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ToolButton(
                    label: '从第 1 集开始播放',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => _play(0),
                  ),
                ] else if (!_loading)
                  ToolCard(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 19, color: C.warning),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _err.isNotEmpty ? _err : '该影片暂无可用播放地址，可返回换一个源',
                            style: Ty.small.copyWith(color: context.t2),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (intro.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('剧情简介', style: Ty.small.copyWith(fontWeight: FontWeight.w800, color: context.t1)),
                  const SizedBox(height: 8),
                  Text(intro,
                      style: Ty.small.copyWith(color: context.t2, height: 1.75)),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 34, child: Text(k, style: Ty.tiny.copyWith(color: context.t3))),
            Expanded(
              child: Text(v,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.tiny.copyWith(color: context.t2, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});
  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final _svc = ToolboxService.instance;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String _err = '';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final d = await _svc.musicHome();
      final out = <Map<String, dynamic>>[];
      for (final b in ((d?['blocks'] as List?) ?? [])) {
        if (b is Map && b['list'] is List) {
          for (final e in (b['list'] as List)) {
            if (e is Map) out.add(Map<String, dynamic>.from(e));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _list = out;
        _loading = false;
        _err = out.isEmpty ? '暂时没有拿到歌单' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _search(String kw) async {
    final q = kw.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _err = '';
    });
    final l = await _svc.musicSearch(q);
    if (!mounted) return;
    setState(() {
      _list = l;
      _loading = false;
      _err = l.isEmpty ? '没有找到「$q」' : '';
    });
  }

  Future<void> _play(Map<String, dynamic> it) async {
    final id = '${it['id'] ?? ''}';
    final src = '${it['src'] ?? 'netease'}';
    if (id.isEmpty) return;
    setState(() => _busyId = id);
    try {
      final d = await _svc.musicUrl(src, id);
      final url = '${d?['url'] ?? ''}';
      if (!mounted) return;
      setState(() => _busyId = null);
      if (url.isEmpty) {
        ToastUtil.error('该歌曲暂无可用音源');
        return;
      }
      // ★ 1015：改为 App 内播放（原来 openUrl 跳浏览器，用户以为「不能听」）
      final list = _list
          .where((e) => '${e['name'] ?? ''}'.isNotEmpty)
          .map((e) => ('${e['name'] ?? ''}', ''))
          .toList();
      Get.to(() => ToolPlayerPage(
        url: url,
        title: '${it['name'] ?? ''}',
        subtitle: '${it['artist'] ?? ''}',
        cover: '${it['pic'] ?? ''}',
        isAudio: true,
        playlist: list.length > 1 ? list : null,
        initialIndex: list.indexWhere((e) => e.$1 == '${it['name'] ?? ''}').clamp(0, list.isEmpty ? 0 : list.length - 1),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '音乐播放器',
      subtitle: '在线试听 · 多源搜索',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? Colors.white.withAlpha(10)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(R.full),
                    border: Border.all(
                      color: context.isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 19, color: context.t3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _search,
                          style: TextStyle(fontSize: 14.5, color: context.t1),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '搜歌名 / 歌手',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: context.t3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ToolButton(
                label: '搜索',
                height: 44,
                onPressed: () => _search(_ctrl.text),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const LoadingState(text: '正在加载歌单…')
                : _list.isEmpty
                ? EmptyState(
                    icon: Icons.library_music_outlined,
                    text: _err.isEmpty ? '暂无数据' : _err,
                    hint: '换个关键词试试',
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      final it = _list[i];
                      final img = '${it['pic'] ?? ''}';
                      final busy = _busyId == '${it['id']}';
                      return ToolCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => _play(it),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: img.isEmpty
                                    ? Container(
                                        color: C.brand.withAlpha(16),
                                        child: Icon(
                                          Icons.music_note_rounded,
                                          color: C.brand.withAlpha(140),
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: img,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 200,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${it['name'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.t1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${it['artist'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Ty.tiny.copyWith(
                                      color: context.t3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.play_circle_fill_rounded,
                                    size: 30,
                                    color: C.brand,
                                  ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════ 王者图集 ═══════════
class HeroGalleryPage extends StatefulWidget {
  const HeroGalleryPage({super.key});
  @override
  State<HeroGalleryPage> createState() => _HeroGalleryPageState();
}

class _HeroGalleryPageState extends State<HeroGalleryPage> {
  final _svc = ToolboxService.instance;
  List<Map<String, dynamic>> _heroes = [];
  bool _loading = true;
  String _err = '';
  Map<String, dynamic>? _picked;

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
      final l = await _svc.heroes();
      if (!mounted) return;
      setState(() {
        _heroes = l;
        _loading = false;
        _err = l.isEmpty ? '英雄数据加载失败' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _picked;
    if (p != null) {
      final skins = ((p['skins'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return ToolScaffold(
        title: '${p['name'] ?? ''}',
        subtitle: '${p['title'] ?? ''} · 共 ${skins.length} 款皮肤',
        actions: [
          AppPressable(
            onTap: () => setState(() => _picked = null),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(Icons.grid_view_rounded, size: 20, color: context.t2),
            ),
          ),
        ],
        child: skins.isEmpty
            ? const EmptyState(
                icon: Icons.image_not_supported_outlined,
                text: '该英雄暂无皮肤图',
                hint: '换一个英雄看看',
              )
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: skins.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (c, i) {
                  final s = skins[i];
                  return ToolCard(
                    padding: EdgeInsets.zero,
                    onTap: () => MediaPreview.showImage(context, '${s['url'] ?? ''}'),
                                            onLongPress: () => ImgSaver.saveUrl('${s['url'] ?? ''}'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(R.lg),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: '${s['url'] ?? ''}',
                            height: Ad.h(context, 170),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            memCacheWidth: 900,
                            placeholder: (_, __) => Container(
                              height: Ad.h(context, 170),
                              color: C.brand.withAlpha(14),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: Ad.h(context, 170),
                              color: C.brand.withAlpha(14),
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: context.t3,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                borderRadius: BorderRadius.circular(R.full),
                              ),
                              child: Text(
                                '${s['name'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
    }
    return ToolScaffold(
      title: '王者图集',
      subtitle: '英雄皮肤高清原画（${_heroes.length} 位英雄）',
      child: _loading
          ? const LoadingState(text: '正在加载英雄列表…')
          : _heroes.isEmpty
          ? EmptyState(
              icon: Icons.sports_martial_arts_outlined,
              text: _err.isEmpty ? '暂无数据' : _err,
              hint: '稍后重试',
            )
          : GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: _heroes.length,
              itemBuilder: (c, i) {
                final h = _heroes[i];
                return AppPressable(
                  onTap: () => setState(() => _picked = h),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(R.md),
                          child: SizedBox(
                            width: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: '${h['icon'] ?? ''}',
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              placeholder: (_, __) =>
                                  Container(color: C.brand.withAlpha(14)),
                              errorWidget: (_, __, ___) => Container(
                                color: C.brand.withAlpha(14),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: context.t3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${h['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.t1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ═══════════ 漫画书城 ═══════════
class ComicPage extends StatefulWidget {
  const ComicPage({super.key});
  @override
  State<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends State<ComicPage> {
  final _svc = ToolboxService.instance;
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _list = [];
  String _tag = '';
  bool _loading = true;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final tags = await _svc.comicTags();
      final list = await _svc.comicList(tag: _tag);
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _list = list;
        _loading = false;
        _err = list.isEmpty ? '漫画列表加载失败' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _switch(String tag) async {
    setState(() {
      _tag = tag;
      _loading = true;
    });
    final l = await _svc.comicList(tag: tag);
    if (!mounted) return;
    setState(() {
      _list = l;
      _loading = false;
      _err = l.isEmpty ? '该分类暂无漫画' : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '漫画书城',
      subtitle: '在线漫画 · 分类浏览',
      child: Column(
        children: [
          if (_tags.isNotEmpty)
            ToolChips<String>(
              items: [
                ('', '全部'),
                for (final t in _tags)
                  ('${t['name'] ?? ''}', '${t['name'] ?? ''}'),
              ],
              current: _tag,
              onPick: _switch,
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const LoadingState(text: '正在加载漫画…')
                : _list.isEmpty
                ? EmptyState(
                    icon: Icons.menu_book_outlined,
                    text: _err.isEmpty ? '暂无数据' : _err,
                    hint: '换个分类试试',
                  )
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.62,
                        ),
                    itemCount: _list.length,
                    itemBuilder: (c, i) {
                      final it = _list[i];
                      return AppPressable(
                        onTap: () => Get.to(
                          () => ComicReadPage(
                            id: '${it['id'] ?? ''}',
                            title: '${it['title'] ?? ''}',
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(R.md),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: CachedNetworkImage(
                                    imageUrl: '${it['cover'] ?? ''}',
                                    fit: BoxFit.cover,
                                    memCacheWidth: 360,
                                    placeholder: (_, __) => Container(
                                      color: C.brand.withAlpha(14),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: C.brand.withAlpha(14),
                                      child: Icon(
                                        Icons.menu_book_outlined,
                                        color: context.t3,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${it['title'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: context.t1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 漫画阅读
class ComicReadPage extends StatefulWidget {
  final String id;
  final String title;
  const ComicReadPage({super.key, required this.id, required this.title});

  @override
  State<ComicReadPage> createState() => _ComicReadPageState();
}

class _ComicReadPageState extends State<ComicReadPage> {
  final _svc = ToolboxService.instance;
  List<Map<String, dynamic>> _chapters = [];
  List<String> _images = [];
  String _chapter = '';
  bool _loading = true;
  bool _imgLoading = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final ch = await _svc.comicChapters(widget.id);
      if (!mounted) return;
      setState(() {
        _chapters = ch;
        _loading = false;
        _err = ch.isEmpty ? '没有拿到章节列表' : '';
      });
      if (ch.isNotEmpty) _open('${ch.first['id'] ?? ''}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _open(String chapter) async {
    if (chapter.isEmpty) return;
    setState(() {
      _chapter = chapter;
      _imgLoading = true;
    });
    final imgs = await _svc.comicImages(widget.id, chapter);
    if (!mounted) return;
    setState(() {
      _images = imgs;
      _imgLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final idx = _chapters.indexWhere((e) => '${e['id']}' == _chapter);
    return ToolScaffold(
      title: widget.title.isEmpty ? '漫画' : widget.title,
      subtitle: _imgLoading
          ? '正在加载章节…'
          : '共 ${_chapters.length} 话 · 当前第 ${idx < 0 ? '--' : idx + 1} 话',
      child: _loading
          ? const LoadingState(text: '正在加载章节…')
          : _err.isNotEmpty
          ? EmptyState(icon: Icons.menu_book_outlined, text: _err, hint: '稍后重试')
          : Column(
              children: [
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _chapters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (c, i) {
                      final id = '${_chapters[i]['id'] ?? ''}';
                      final sel = _chapter == id;
                      return AppPressable(
                        onTap: () => _open(id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: sel ? Deco.brandGradient : null,
                            color: sel
                                ? null
                                : (context.isDark
                                      ? Colors.white.withAlpha(10)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                          child: Text(
                            '第 ${i + 1} 话',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: sel
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: sel ? Colors.white : context.t2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _imgLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : _images.isEmpty
                      ? const EmptyState(
                          icon: Icons.image_not_supported_outlined,
                          text: '本话没有图片',
                          hint: '换一话看看',
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _images.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 3),
                          itemBuilder: (c, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(R.sm),
                            child: CachedNetworkImage(
                              imageUrl: _images[i],
                              fit: BoxFit.fitWidth,
                              placeholder: (_, __) => Container(
                                height: Ad.h(context, 220),
                                color: C.brand.withAlpha(12),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: Ad.h(context, 120),
                                color: C.brand.withAlpha(12),
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: context.t3,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ═══════════ 壁纸大全 ═══════════
class WallpaperPage extends StatefulWidget {
  final String apiUrl;
  const WallpaperPage({super.key, this.apiUrl = ''});

  @override
  State<WallpaperPage> createState() => _WallpaperPageState();
}

class _WallpaperPageState extends State<WallpaperPage> {
  static const _cats = <(String, String)>[
    ('dongman', '动漫'),
    ('meizi', '美女'),
    ('fengjing', '风景'),
    ('suiji', '随机'),
  ];

  int _cat = 0;
  final List<String> _urls = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_busy) return;
    setState(() => _busy = true);
    final base =
        'http://api.btstu.cn/sjbz/api.php?lx=${_cats[_cat].$1}&format=images';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final add = List.generate(9, (i) => '$base&t=$ts$i');
    if (!mounted) return;
    setState(() {
      _urls.addAll(add);
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '壁纸大全',
      subtitle: '高清随机壁纸 · 点图看原图',
      child: Column(
        children: [
          ToolChips<int>(
            items: [for (int i = 0; i < _cats.length; i++) (i, _cats[i].$2)],
            current: _cat,
            onPick: (i) {
              setState(() {
                _cat = i;
                _urls.clear();
              });
              _more();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _urls.isEmpty
                ? const LoadingState(text: '正在获取壁纸…')
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.62,
                        ),
                    itemCount: _urls.length,
                    itemBuilder: (c, i) => AppPressable(
                      onTap: () => MediaPreview.showImages(context, _urls, index: i),
                      // ★ 1015：长按直接保存到相册
                      onLongPress: () => ImgSaver.saveUrl(_urls[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(R.md),
                        child: CachedNetworkImage(
                          imageUrl: _urls[i],
                          fit: BoxFit.cover,
                          memCacheWidth: 360,
                          placeholder: (_, __) =>
                              Container(color: C.brand.withAlpha(14)),
                          errorWidget: (_, __, ___) => Container(
                            color: C.brand.withAlpha(14),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: context.t3,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          ToolButton(
            label: '换一批',
            icon: Icons.refresh_rounded,
            outline: true,
            loading: _busy,
            onPressed: _more,
          ),
        ],
      ),
    );
  }
}
