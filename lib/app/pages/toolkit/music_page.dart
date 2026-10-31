import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/soft_service.dart' show SoftService;
import '../../api/toolbox_service.dart';
import '../../design/ad.dart';
import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_kit.dart';
import 'tool_player_page.dart';

// ═══════════════════════════════════════════════════════════════
// 音乐模块 · 主页面（1015 重做，对标样本 App）
//
//   结构（与样本一致）：
//     · 底部两个 Tab：首页 / 收藏夹
//     · 首页：榜单横滑卡 + 推荐歌单网格 + 新歌速递
//     · 收藏夹：我的喜欢（本地 SharedPreferences 存储）
//     · 常驻底部迷你播放条（歌名+歌手+上/播/下）
//     · 点击歌曲 → 全屏播放页（ToolPlayerPage，带播放列表）
// ═══════════════════════════════════════════════════════════════
class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});
  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  int _tab = 0; // 0 首页 1 收藏夹

  List<Map<String, dynamic>> toplists = [];
  List<Map<String, dynamic>> playlists = [];
  List<Map<String, dynamic>> newsongs = [];
  bool loading = true;
  String err = '';

  /// 当前播放（迷你条用）
  static Map<String, dynamic>? current;
  static List<Map<String, dynamic>> currentList = [];
  static Map<String, dynamic>? get currentSong => current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await Future.wait([
        MusicSvc.toplists(),
        MusicSvc.playlists(),
        MusicSvc.newSongs(),
      ]);
      if (!mounted) return;
      setState(() {
        toplists = r[0];
        playlists = r[1];
        newsongs = r[2];
        loading = false;
        err = toplists.isEmpty && playlists.isEmpty ? '数据加载失败，请下拉重试' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = '数据加载失败';
      });
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
                _topbar(),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : err.isNotEmpty
                      ? _errView()
                      : _tab == 0
                      ? _homeView()
                      : _favView(),
                ),
                if (current != null) _miniBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 顶部：返回 + 标题 + Tab ──
  Widget _topbar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding - 10,
        6,
        context.pagePadding,
        0,
      ),
      child: Row(
        children: [
          AppPressable(
            onTap: () => Get.back(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: context.t1,
              ),
            ),
          ),
          const SizedBox(width: 2),
          Text(
            _tab == 0 ? '音乐' : '收藏夹',
            style: Ty.h2.copyWith(
              color: context.t1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          _tabChip(0, '首页'),
          const SizedBox(width: 8),
          _tabChip(1, '收藏'),
        ],
      ),
    );
  }

  Widget _tabChip(int i, String label) => AppPressable(
    onTap: () => setState(() => _tab = i),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: _tab == i ? Deco.brandGradient : null,
        color: _tab == i ? null : C.brand.withAlpha(context.isDark ? 24 : 10),
        borderRadius: BorderRadius.circular(R.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: _tab == i ? Colors.white : C.brand,
        ),
      ),
    ),
  );

  // ── 首页 ──
  Widget _homeView() {
    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand,
      child: ListView(
        padding: EdgeInsets.only(bottom: context.tabSpace + 90),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          // 榜单横滑
          if (toplists.isNotEmpty) ...[
            _sectionTitle('热门榜单'),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                itemCount: toplists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (c, i) {
                  final t = toplists[i];
                  final cover = '${t['cover'] ?? ''}';
                  return AppPressable(
                    onTap: () => _openToplist(t),
                    child: SizedBox(
                      width: Ad.w(context, 108),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(R.md),
                            child: cover.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: SoftService.proxyImage(cover),
                                    httpHeaders: const {
                                      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
                                      'Referer': 'https://music.163.com/',
                                    },
                                    width: Ad.w(context, 108),
                                    height: Ad.h(context, 100),
                                    fit: BoxFit.cover,
                                    memCacheWidth: 320,
                                    placeholder: (_, __) => Container(
                                      width: Ad.w(context, 108),
                                      height: Ad.h(context, 100),
                                      color: C.brand.withAlpha(20),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: Ad.w(context, 108),
                                      height: Ad.h(context, 100),
                                      color: C.brand.withAlpha(20),
                                      child: const Icon(
                                        Icons.music_note_rounded,
                                        size: 28,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: Ad.w(context, 108),
                                    height: Ad.h(context, 100),
                                    color: C.brand.withAlpha(20),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${t['name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.t1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // 推荐歌单（两列大图）
          if (playlists.isNotEmpty) ...[
            _sectionTitle('推荐歌单'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
              child: LayoutBuilder(
                builder: (ctx, c) {
                  final w = (c.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: playlists.map<Widget>((p) {
                      final cover = '${p['cover'] ?? ''}';
                      final cnt = (p['count'] as num?)?.toInt() ?? 0;
                      return SizedBox(
                        width: w,
                        child: AppPressable(
                          onTap: () => _openPlaylist(p),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(R.md),
                                    child: cover.startsWith('http')
                                        ? CachedNetworkImage(
                                            imageUrl: SoftService.proxyImage(
                                              cover,
                                            ),
                                            httpHeaders: const {
                                              'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
                                              'Referer':
                                                  'https://music.163.com/',
                                            },
                                            width: w,
                                            height: w,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 480,
                                            placeholder: (_, __) => Container(
                                              width: w,
                                              height: w,
                                              color: C.brand.withAlpha(20),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                                  width: w,
                                                  height: w,
                                                  color: C.brand.withAlpha(20),
                                                ),
                                          )
                                        : Container(
                                            width: w,
                                            height: w,
                                            color: C.brand.withAlpha(20),
                                          ),
                                  ),
                                  if (cnt > 0)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(130),
                                          borderRadius: BorderRadius.circular(
                                            R.full,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.play_arrow_rounded,
                                              size: 11,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              _fmtCount(cnt),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${p['name'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: context.t1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],

          // 新歌速递
          if (newsongs.isNotEmpty) ...[
            _sectionTitle('新歌速递'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
              child: Column(
                children: newsongs
                    .take(10)
                    .map<Widget>((s) => _songTile(s, newsongs))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 收藏夹 ──
  Widget _favView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: MusicSvc.favorites(),
      builder: (c, snap) {
        final list = snap.data ?? const <Map<String, dynamic>>[];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 46,
                  color: context.t3,
                ),
                const SizedBox(height: 12),
                Text('还没有收藏的歌曲', style: Ty.h3.copyWith(color: context.t1)),
                const SizedBox(height: 6),
                Text(
                  '在歌曲右侧点心形即可收藏',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.only(
            left: context.pagePadding,
            right: context.pagePadding,
            bottom: context.tabSpace + 90,
          ),
          children: list.map<Widget>((s) => _songTile(s, list)).toList(),
        );
      },
    );
  }

  // ── 歌曲行 ──
  Widget _songTile(Map<String, dynamic> s, List<Map<String, dynamic>> list) {
    final cover = '${s['cover'] ?? ''}';
    final name = '${s['name'] ?? ''}';
    final artist = '${s['artist'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppPressable(
        onTap: () => _play(list, s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(context.isDark ? 16 : 7),
            borderRadius: BorderRadius.circular(R.md),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(R.sm),
                child: cover.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: SoftService.proxyImage(cover),
                        httpHeaders: const {
                          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
                          'Referer': 'https://music.163.com/',
                        },
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        memCacheWidth: 160,
                        placeholder: (_, __) => Container(
                          width: 46,
                          height: 46,
                          color: C.brand.withAlpha(20),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 46,
                          height: 46,
                          color: C.brand.withAlpha(20),
                          child: const Icon(Icons.music_note_rounded, size: 20),
                        ),
                      )
                    : Container(
                        width: 46,
                        height: 46,
                        color: C.brand.withAlpha(20),
                        child: const Icon(Icons.music_note_rounded, size: 20),
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ),
              // 收藏
              AppPressable(
                onTap: () async {
                  await MusicSvc.toggleFav(s);
                  if (mounted) setState(() {});
                  ToastUtil.success('已更新收藏');
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: FutureBuilder<bool>(
                    future: MusicSvc.isFav('${s['id'] ?? ''}'),
                    builder: (c, snap) => Icon(
                      snap.data == true
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 19,
                      color: snap.data == true ? C.danger : context.t3,
                    ),
                  ),
                ),
              ),
              AppPressable(
                onTap: () => _play(list, s),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: Deco.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: EdgeInsets.fromLTRB(
      context.pagePadding,
      20,
      context.pagePadding,
      11,
    ),
    child: Row(
      children: [
        Container(
          width: 3.5,
          height: 15,
          decoration: BoxDecoration(
            color: C.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          t,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: context.t1,
          ),
        ),
      ],
    ),
  );

  // ── 迷你播放条 ──
  Widget _miniBar() {
    final s = current!;
    final cover = '${s['cover'] ?? ''}';
    return AppPressable(
      onTap: () => _play(currentList, s),
      child: Container(
        margin: EdgeInsets.fromLTRB(
          context.pagePadding,
          0,
          context.pagePadding,
          8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg2 : C.lbg1,
          borderRadius: BorderRadius.circular(R.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(context.isDark ? 60 : 24),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: cover.startsWith('http')
                  ? CachedNetworkImage(
                        memCacheWidth: 114,
                      imageUrl: SoftService.proxyImage(cover),
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 38,
                        height: 38,
                        color: C.brand.withAlpha(30),
                      ),
                    )
                  : Container(
                      width: 38,
                      height: 38,
                      color: C.brand.withAlpha(30),
                      child: const Icon(Icons.music_note_rounded, size: 18),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.t1,
                    ),
                  ),
                  Text(
                    '${s['artist'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.tiny.copyWith(color: context.t3),
                  ),
                ],
              ),
            ),
            Icon(Icons.skip_previous_rounded, size: 24, color: context.t2),
            const SizedBox(width: 12),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: Deco.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.skip_next_rounded, size: 24, color: context.t2),
          ],
        ),
      ),
    );
  }

  Widget _errView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_off_rounded, size: 44, color: context.t3),
        const SizedBox(height: 12),
        Text(err, style: Ty.h3.copyWith(color: context.t1)),
        const SizedBox(height: 18),
        ToolButton(label: '重试', icon: Icons.refresh_rounded, onPressed: _load),
      ],
    ),
  );

  // ── 播放 ──
  Future<void> _play(
    List<Map<String, dynamic>> list,
    Map<String, dynamic> song,
  ) async {
    final id = '${song['id'] ?? ''}';
    if (id.isEmpty) return;
    ToastUtil.info('正在获取播放地址…');
    try {
      final d = await MusicSvc.url(id);
      final url = '${d?['url'] ?? ''}';
      if (url.isEmpty) {
        ToastUtil.error('该歌曲暂无可用音源');
        return;
      }
      setState(() {
        current = song;
        currentList = list;
      });
      final idx = list.indexWhere((e) => '${e['id']}' == id);
      Get.to(
        () => ToolPlayerPage(
          url: url,
          title: '${song['name'] ?? ''}',
          subtitle: '${song['artist'] ?? ''}',
          cover: '${song['cover'] ?? ''}',
          isAudio: true,
          playlist: <(String, String)>[
            for (final e in list)
              ('${e['name'] ?? ''}', '${e['artist'] ?? ''}'),
          ],
          initialIndex: idx < 0 ? 0 : idx,
          // ★ 1028：切歌要按 id 现取直链，不能把歌手名当 URL
          resolveUrl: (i) async {
            if (i < 0 || i >= list.length) return '';
            final d = await MusicSvc.url('${list[i]['id'] ?? ''}');
            return '${d?['url'] ?? ''}';
          },
        ),
      );
    } catch (e) {
      ToastUtil.error('播放失败：$e');
    }
  }

  void _openToplist(Map<String, dynamic> t) {
    Get.to(
      () => MusicListPage(
        title: '${t['name'] ?? ''}',
        cover: '${t['cover'] ?? ''}',
        type: 'toplist',
        id: '${t['id'] ?? ''}',
      ),
    );
  }

  void _openPlaylist(Map<String, dynamic> p) {
    Get.to(
      () => MusicListPage(
        title: '${p['name'] ?? ''}',
        cover: '${p['cover'] ?? ''}',
        type: 'playlist',
        id: '${p['id'] ?? ''}',
      ),
    );
  }

  static String _fmtCount(int n) {
    if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return '$n';
  }
}

// ═══════════════════════════════════════════════════════════════
// 榜单 / 歌单 列表页
// ═══════════════════════════════════════════════════════════════
class MusicListPage extends StatefulWidget {
  final String title;
  final String cover;
  final String type; // toplist | playlist
  final String id;
  const MusicListPage({
    super.key,
    required this.title,
    required this.cover,
    required this.type,
    required this.id,
  });

  @override
  State<MusicListPage> createState() => _MusicListPageState();
}

class _MusicListPageState extends State<MusicListPage> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final d = widget.type == 'toplist'
          ? await MusicSvc.toplistDetail(widget.id)
          : await MusicSvc.playlistDetail(widget.id);
      if (!mounted) return;
      final raw = d?['list'];
      setState(() {
        list = (raw is List)
            ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        loading = false;
        err = list.isEmpty ? '暂无歌曲' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = '加载失败';
      });
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
                // 头部
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding - 10,
                    6,
                    context.pagePadding,
                    0,
                  ),
                  child: Row(
                    children: [
                      AppPressable(
                        onTap: () => Get.back(),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: context.t1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.h2.copyWith(
                            color: context.t1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 歌单信息
                if (widget.cover.startsWith('http'))
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      10,
                      context.pagePadding,
                      0,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(R.md),
                          child: CachedNetworkImage(
                                     memCacheWidth: 400,
                            imageUrl: SoftService.proxyImage(widget.cover),
                            width: Ad.w(context, 92),
                            height: Ad.h(context, 92),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: Ad.w(context, 92),
                              height: Ad.h(context, 92),
                              color: C.brand.withAlpha(30),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '共 ${list.length} 首',
                                style: Ty.small.copyWith(color: context.t3),
                              ),
                              const SizedBox(height: 10),
                              AppPressable(
                                onTap: () {
                                  if (list.isNotEmpty) _playFirst();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: Deco.brandGradient,
                                    borderRadius: BorderRadius.circular(R.full),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        size: 17,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '播放全部',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : list.isEmpty
                      ? Center(
                          child: Text(
                            err,
                            style: Ty.small.copyWith(color: context.t3),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            left: context.pagePadding,
                            right: context.pagePadding,
                            bottom: context.tabSpace + 20,
                          ),
                          itemCount: list.length,
                          itemBuilder: (c, i) => _row(list[i], i),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> s, int i) {
    final cover = '${s['cover'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppPressable(
        onTap: () => _playAt(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(context.isDark ? 14 : 6),
            borderRadius: BorderRadius.circular(R.md),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: i < 3 ? C.danger : context.t3,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(R.sm),
                child: cover.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: SoftService.proxyImage(cover),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        memCacheWidth: 140,
                        errorWidget: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: C.brand.withAlpha(20),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        color: C.brand.withAlpha(20),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${s['artist'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, size: 20, color: C.brand),
            ],
          ),
        ),
      ),
    );
  }

  void _playFirst() => _playAt(0);

  Future<void> _playAt(int i) async {
    if (i < 0 || i >= list.length) return;
    final s = list[i];
    ToastUtil.info('正在获取播放地址…');
    try {
      final d = await MusicSvc.url('${s['id'] ?? ''}');
      final url = '${d?['url'] ?? ''}';
      if (url.isEmpty) {
        ToastUtil.error('该歌曲暂无可用音源');
        return;
      }
      _MusicHomePageState.current = s;
      _MusicHomePageState.currentList = list;
      Get.to(
        () => ToolPlayerPage(
          url: url,
          title: '${s['name'] ?? ''}',
          subtitle: '${s['artist'] ?? ''}',
          cover: '${s['cover'] ?? ''}',
          isAudio: true,
          playlist: <(String, String)>[
            for (final e in list)
              ('${e['name'] ?? ''}', '${e['artist'] ?? ''}'),
          ],
          initialIndex: i,
          resolveUrl: (k) async {
            if (k < 0 || k >= list.length) return '';
            final d = await MusicSvc.url('${list[k]['id'] ?? ''}');
            return '${d?['url'] ?? ''}';
          },
        ),
      );
    } catch (e) {
      ToastUtil.error('播放失败');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 音乐数据服务（含本地收藏）
// ═══════════════════════════════════════════════════════════════
class MusicSvc {
  MusicSvc._();
  static final _svc = ToolboxService.instance;
  static const _kFav = 'music_favorites_v1';

  static Future<List<Map<String, dynamic>>> toplists() async {
    try {
      return await _svc.musicToplists();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> playlists() async {
    try {
      return await _svc.musicPlaylists();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> newSongs() async {
    try {
      return await _svc.musicNewSongs();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> toplistDetail(String id) async {
    try {
      return await _svc.musicToplistDetail(id);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> playlistDetail(String id) async {
    try {
      return await _svc.musicPlaylistDetail(id);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> url(String id) async {
    try {
      return await _svc.musicUrl('netease', id);
    } catch (_) {
      return null;
    }
  }

  // ── 本地收藏（SharedPreferences 存 JSON）──
  static Future<List<Map<String, dynamic>>> favorites() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kFav);
      if (raw == null || raw.isEmpty) return [];
      final l = jsonDecode(raw);
      if (l is! List) return [];
      return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isFav(String id) async {
    final l = await favorites();
    return l.any((e) => '${e['id']}' == id);
  }

  static Future<void> toggleFav(Map<String, dynamic> song) async {
    try {
      final sp = await SharedPreferences.getInstance();
      var l = await favorites();
      final id = '${song['id'] ?? ''}';
      if (l.any((e) => '${e['id']}' == id)) {
        l = l.where((e) => '${e['id']}' != id).toList();
      } else {
        l.insert(0, song);
      }
      await sp.setString(_kFav, jsonEncode(l));
    } catch (_) {}
  }
}
