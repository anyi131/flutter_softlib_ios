import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';
import '../admin_ui_kit.dart';

/// 后台 · 全部在线用户
///
/// ★ 1020（用户要求「不能只看 8 个，要能点进去看全部」）
///   · 分时段筛选：5 分钟 / 15 分钟 / 60 分钟 / 24 小时 / 全部
///   · 搜索昵称 / 账号 / IP
///   · 分页加载（每页 50）
///   · 每行显示：头像、昵称、VIP、IP、最近活跃、注册日期
class OnlineUsersView extends StatefulWidget {
  const OnlineUsersView({super.key});

  @override
  State<OnlineUsersView> createState() => _OnlineUsersViewState();
}

class _OnlineUsersViewState extends State<OnlineUsersView> {
  final _svc = AdminService.instance;
  final _kwCtrl = TextEditingController();

  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic> _buckets = {};
  int _total = 0;
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  int _mins = 60;
  String _kw = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) {
      setState(() => _loading = true);
      _page = 1;
    }
    try {
      final r = await _svc.onlineUsers(
        mins: _mins,
        page: _page,
        size: 50,
        kw: _kw,
      );
      if (!mounted) return;
      final list = ((r['list'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _list = more ? [..._list, ...list] : list;
        // ★ 1020：空对象会被 PHP 编码成 []，as Map? 会崩
        final rawB = r['buckets'];
        _buckets = rawB is Map
            ? Map<String, dynamic>.from(rawB)
            : <String, dynamic>{};
        _total = (r['total'] as num?)?.toInt() ?? 0;
        _hasMore = r['has_more'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  int _b(String k) => (_buckets[k] as num?)?.toInt() ?? 0;

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
                // 顶栏
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    6,
                    context.pagePadding,
                    4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: context.t1,
                        ),
                      ),
                      Text(
                        '全部在线用户',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: context.t1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: C.mint.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_total',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: C.mint,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _load(),
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: context.t3,
                        ),
                      ),
                    ],
                  ),
                ),
                // 分时段筛选
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.pagePadding,
                    ),
                    children: [
                      _chip('5 分钟', 5, _b('m5')),
                      _chip('15 分钟', 15, _b('m15')),
                      _chip('60 分钟', 60, _b('m60')),
                      _chip('24 小时', 1440, _b('m1440')),
                      _chip('全部', 0, null),
                    ],
                  ),
                ),
                // 搜索
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    8,
                    context.pagePadding,
                    6,
                  ),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? Colors.white.withAlpha(14)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: context.isDark
                            ? Colors.white10
                            : Colors.black.withAlpha(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 16, color: context.t3),
                        const SizedBox(width: 7),
                        Expanded(
                          child: TextField(
                            controller: _kwCtrl,
                            onSubmitted: (v) {
                              _kw = v.trim();
                              _load();
                            },
                            style: TextStyle(fontSize: 13, color: context.t1),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: '搜索昵称 / 账号 / IP',
                              hintStyle: TextStyle(
                                fontSize: 12.5,
                                color: context.t3,
                              ),
                            ),
                          ),
                        ),
                        if (_kw.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _kwCtrl.clear();
                              _kw = '';
                              _load();
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: context.t3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const LoadingState(text: '加载在线用户…')
                      : (_list.isEmpty
                            ? const EmptyState(
                                text: '这个时间段没有在线用户',
                                hint: '换个时间范围试试',
                              )
                            : RefreshIndicator(
                                onRefresh: () => _load(),
                                color: C.brand,
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.fromLTRB(
                                    context.pagePadding,
                                    4,
                                    context.pagePadding,
                                    24,
                                  ),
                                  itemCount: _list.length + (_hasMore ? 1 : 0),
                                  itemBuilder: (c, i) {
                                    if (i >= _list.length) {
                                      _page++;
                                      _load(more: true);
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return _row(_list[i]);
                                  },
                                ),
                              )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int mins, int? count) {
    final sel = _mins == mins;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: () {
          if (_mins == mins) return;
          setState(() => _mins = mins);
          _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel
                ? C.brand
                : (context.isDark ? Colors.white10 : Colors.white),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: sel
                  ? C.brand
                  : (context.isDark
                        ? Colors.white12
                        : Colors.black.withAlpha(7)),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : context.t2,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white70 : C.brand,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> u) {
    final booting = u['booting'] == true;
    final vip = u['vip'] == true;
    final avatar = '${u['avatar'] ?? ''}';
    final nick = '${u['nickname'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AdCard(
        radius: R.md,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 头像
            avatar.isEmpty
                ? Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (booting ? C.mint : C.brand).withAlpha(
                        context.isDark ? 50 : 22,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      nick.isEmpty ? '?' : nick.characters.first,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: booting ? C.mint : C.brand,
                      ),
                    ),
                  )
                : ClipOval(
                    child: CachedNetworkImage(
                               memCacheWidth: 102,
                      imageUrl: avatar,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 34,
                        height: 34,
                        color: C.brand.withAlpha(22),
                        child: Icon(Icons.person, size: 17, color: C.brand),
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
                          nick,
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
                            vertical: 0.5,
                          ),
                          decoration: BoxDecoration(
                            color: C.amber.withAlpha(36),
                            borderRadius: BorderRadius.circular(3),
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
                    '${u['ip'] ?? ''} · 注册 ${u['joined'] ?? '-'}',
                    style: TextStyle(fontSize: 9.5, color: context.t3),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${u['time_text'] ?? ''}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: booting ? FontWeight.w800 : FontWeight.w500,
                    color: booting ? C.mint : context.t3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID ${u['id']}',
                  style: TextStyle(fontSize: 9, color: context.t3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
