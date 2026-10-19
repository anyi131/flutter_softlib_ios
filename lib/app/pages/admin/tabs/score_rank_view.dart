import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';
import '../admin_ui_kit.dart';

/// 后台 · 积分排行榜
///
/// ★ 用户明确要求：**只做后台，仅管理员可见**。
///   用途：① 看谁是真活跃用户 ② 发现刷分账号
class ScoreRankView extends StatefulWidget {
  const ScoreRankView({super.key});

  @override
  State<ScoreRankView> createState() => _ScoreRankViewState();
}

class _ScoreRankViewState extends State<ScoreRankView> {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _suspect = [];
  Map<String, dynamic> _meta = {};
  bool _loading = true;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _svc.scoreRank(days: _days, limit: 50);
      if (!mounted) return;
      setState(() {
        _list = ((r['list'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _suspect = ((r['suspect'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _meta = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: const Text(
                    '积分排行榜',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  actions: [
                    PopupMenuButton<int>(
                      initialValue: _days,
                      onSelected: (v) {
                        setState(() => _days = v);
                        _load();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 7, child: Text('近 7 天')),
                        PopupMenuItem(value: 30, child: Text('近 30 天')),
                        PopupMenuItem(value: 90, child: Text('近 90 天')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Text(
                            '近 $_days 天',
                            style: TextStyle(fontSize: 12, color: C.brand),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: _loading
                      ? const LoadingState(text: '加载积分榜…')
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: C.brand,
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                              context.pagePadding,
                              4,
                              context.pagePadding,
                              24,
                            ),
                            children: [
                              _summary(),
                              if (_suspect.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _suspectCard(),
                              ],
                              const SizedBox(height: 12),
                              ..._list.map(_row),
                            ],
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

  Widget _summary() {
    return AdCard(
      radius: R.md,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _cell('总积分', '${_meta['total_score'] ?? 0}', C.brand),
          _div(),
          _cell('人均', '${_meta['avg_score'] ?? 0}', C.violet),
          _div(),
          _cell('上榜人数', '${_list.length}', C.mint),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: c,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Ty.tiny.copyWith(fontSize: 10, color: context.t3)),
      ],
    ),
  );

  Widget _div() => Container(
    width: 1,
    height: 24,
    color: context.isDark ? Colors.white12 : Colors.black.withAlpha(10),
  );

  Widget _suspectCard() {
    return AdCard(
      radius: R.md,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 15, color: C.amber),
              const SizedBox(width: 5),
              Text(
                '异常增长（建议核查）',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: C.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._suspect
              .take(5)
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${s['nickname']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: context.t1),
                        ),
                      ),
                      Text(
                        '+${s['month_gain']} 分',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: C.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    final gain = (r['month_gain'] as num?)?.toInt() ?? 0;
    final avatar = '${r['avatar'] ?? ''}';
    // ★ 1020 修复：PHP 的空数组会编码成 JSON 的 `[]`（数组），
    //   这里 `as Map?` 会直接抛
    //   「type 'List<dynamic>' is not a subtype of type 'Map<dynamic,dynamic>?'」
    //   → 整个「积分排行」页变成「内容加载异常」。
    //   改为：不是 Map 就当空处理。
    final rawSources = r['sources'];
    final sources = rawSources is Map
        ? Map<String, dynamic>.from(rawSources)
        : <String, dynamic>{};
    final vip = r['vip'] == true;

    final Color rankColor = rank == 1
        ? const Color(0xFFFFB300)
        : (rank == 2
              ? const Color(0xFF9E9E9E)
              : (rank == 3 ? const Color(0xFFB87333) : context.t3));

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AdCard(
        radius: R.md,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: rank <= 3 ? 15 : 13,
                  fontWeight: FontWeight.w900,
                  color: rankColor,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: avatar.isEmpty
                  ? Container(
                      width: 34,
                      height: 34,
                      color: C.brand.withAlpha(20),
                      child: Icon(Icons.person, size: 18, color: C.brand),
                    )
                  : CachedNetworkImage(
                      imageUrl: avatar,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 34,
                        height: 34,
                        color: C.brand.withAlpha(20),
                        child: Icon(Icons.person, size: 18, color: C.brand),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${r['nickname']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.t1,
                          ),
                        ),
                      ),
                      if (vip) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: C.amber.withAlpha(28),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: C.amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sources.isEmpty
                        ? '本月无变动'
                        : sources.entries
                              .take(3)
                              .map(
                                (e) =>
                                    '${e.key} ${e.value > 0 ? '+' : ''}${e.value}',
                              )
                              .join('  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.tiny.copyWith(fontSize: 9.5, color: context.t3),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${r['score']}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.t1,
                  ),
                ),
                Text(
                  '${gain >= 0 ? '+' : ''}$gain',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: gain > 0
                        ? C.mint
                        : (gain < 0 ? C.danger : context.t3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
