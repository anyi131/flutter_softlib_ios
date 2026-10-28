import 'package:flutter/material.dart';

import '../../api/admin_service.dart';
import '../../design/ui.dart';
import 'admin_ui_kit.dart';

/// 下载记录全量页
///
/// 后台首页只显示最近 10 条，且看不出下载的人是不是会员；
/// 这里按「全部 / 会员 / 普通」筛选，带分页续加载与详情。
class AdminDownloadsPage extends StatefulWidget {
  const AdminDownloadsPage({super.key});

  @override
  State<AdminDownloadsPage> createState() => _AdminDownloadsPageState();
}

class _AdminDownloadsPageState extends State<AdminDownloadsPage> {
  static const int _size = 20;

  final _svc = AdminService.instance;
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _rows = [];

  /// null=全部，1=会员，0=普通
  int? _vip;
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _hasMore = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || !_hasMore) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 240) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loading = true;
      _error = '';
      if (reset) {
        _page = 1;
        _hasMore = true;
        _rows.clear();
      }
    });
    try {
      final data = await _svc.downloadLogs(
        page: _page,
        size: _size,
        vip: _vip,
      );
      final list = (data['list'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _total = (data['total'] as num?)?.toInt() ?? _rows.length + list.length;
        _rows.addAll(list);
        _hasMore = list.length >= _size && _rows.length < _total;
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchVip(int? vip) {
    if (_vip == vip) return;
    setState(() => _vip = vip);
    _load(reset: true);
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
                _header(context),
                _filters(context),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.t1),
          ),
          Text(
            '下载记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.t1,
            ),
          ),
          const Spacer(),
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '共 $_total 条',
                style: TextStyle(fontSize: 12, color: context.t3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    const items = <(String, int?)>[
      ('全部', null),
      ('会员', 1),
      ('普通', 0),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(context, item.$1, item.$2),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, int? vip) {
    final on = _vip == vip;
    return GestureDetector(
      onTap: () => _switchVip(vip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? C.brand : Ad.cardBg(context),
          borderRadius: BorderRadius.circular(Ad.rChip),
          border: Border.all(
            color: on ? C.brand : Ad.stroke(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? Colors.white : context.t2,
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_rows.isEmpty && _loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error.isEmpty ? '还没有下载记录' : _error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.t3),
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _rows.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _rows.length) return _footer(context);
        return _row(context, _rows[index]);
      },
    );
  }

  Widget _footer(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton(
            onPressed: () => _load(),
            child: Text(_error),
          ),
        ),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            '没有更多了',
            style: TextStyle(fontSize: 12, color: context.t3),
          ),
        ),
      );
    }
    return const SizedBox(height: 1);
  }

  Widget _row(BuildContext context, Map<String, dynamic> r) {
    final vip = (r['is_vip'] as num?)?.toInt() ?? -1;
    final title = (r['app_title'] ?? r['title'] ?? '未知软件').toString();
    final nickname = (r['nickname'] ?? '').toString();
    final uid = (r['user_id'] as num?)?.toInt() ?? 0;
    final who = nickname.isNotEmpty
        ? nickname
        : (uid > 0 ? '用户#$uid' : '未登录');
    final ok = (r['status'] ?? '') == 'ok';
    return AdCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => _showDetail(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.t1,
                  ),
                ),
              ),
              if (vip == 1) _vipBadge(context),
              const SizedBox(width: 6),
              Text(
                ok ? '成功' : '失败',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ok ? C.success : C.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 13, color: context.t3),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.t2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                (r['time_text'] ?? '').toString(),
                style: TextStyle(fontSize: 11.5, color: context.t3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vipBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: C.gold.withAlpha(context.isDark ? 46 : 30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: C.gold.withAlpha(context.isDark ? 120 : 90)),
      ),
      child: Text(
        '会员',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: C.gold,
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> r) {
    final vipText = (r['vip_text'] ?? '').toString();
    final expire = (r['vip_expire'] as num?)?.toInt() ?? 0;
    final expireText = expire > 0
        ? DateTime.fromMillisecondsSinceEpoch(expire * 1000)
            .toString()
            .substring(0, 10)
        : '';
    final isVip = (r['is_vip'] as num?)?.toInt() ?? -1;
    final vipLine = isVip == 1
        ? (expireText.isEmpty ? '会员' : '会员 · 到期 $expireText')
        : (vipText.isEmpty ? '普通用户' : '$vipText用户');
    final lines = <(String, String)>[
      ('软件', (r['app_title'] ?? r['title'] ?? '-').toString()),
      ('用户', (r['user_id'] as num?)?.toInt() == 0
          ? '未登录'
          : '${r['nickname'] ?? ''} (#${r['user_id']})'),
      ('身份', vipLine),
      ('时间', (r['time_text'] ?? '-').toString()),
      ('状态', (r['status'] ?? '') == 'ok' ? '成功' : '失败'),
      ('方式', (r['source'] ?? r['channel'] ?? '-').toString()),
      ('IP', (r['ip'] ?? '-').toString()),
      ('设备', (r['device'] ?? '-').toString()),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AdCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下载详情',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ctx.t1,
                  ),
                ),
                const SizedBox(height: 10),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            line.$1,
                            style: TextStyle(fontSize: 12.5, color: ctx.t3),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line.$2.isEmpty ? '-' : line.$2,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: ctx.t1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
