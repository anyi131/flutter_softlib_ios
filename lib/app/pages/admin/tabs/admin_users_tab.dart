import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 用户管理（统计概览 + 筛选 + 分页 + 批量操作 + CSV 导出）
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab>
    with AutomaticKeepAliveClientMixin {
  final _svc = AdminService.instance;
  final _kwCtrl = TextEditingController();

  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic> _stat = {};
  bool _loading = true;
  int _page = 1;
  int _size = 30;
  int _total = 0;
  String _filter = 'all';

  /// 批量选择模式
  bool _selectMode = false;
  final Set<int> _selected = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
    // ★ 数据实时性：Tab 切回来就重新拉一次，避免看到旧数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final l = await _svc.users(
        keyword: _kwCtrl.text.trim(),
        filter: _filter,
        page: _page,
        size: _size,
      );
      final st = await _svc.userStat(
        keyword: _kwCtrl.text.trim(),
        filter: _filter,
      );
      if (!mounted) return;
      setState(() {
        _list = l;
        _stat = st;
        _total = (st['total'] as num?)?.toInt() ?? l.length;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _switchFilter(String f) {
    if (_filter == f) return;
    setState(() {
      _filter = f;
      _page = 1;
      _selected.clear();
    });
    _load();
  }

  int get _maxPage => _total > 0 ? ((_total + _size - 1) ~/ _size) : 1;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _list.isEmpty) {
      return const LoadingState(text: '加载用户列表…');
    }
    return Column(
      children: [
        _searchBar(),
        _statBar(),
        _filterBar(),
        if (_selectMode) _batchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _list.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      text: '没有匹配的用户',
                      hint: '换个关键词或筛选条件试试',
                      icon: Icons.person_search_outlined,
                    ),
                  ])
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        context.pagePadding, 4, context.pagePadding, 20),
                    itemCount: _list.length,
                    itemBuilder: (context, i) => _userCard(_list[i]),
                  ),
          ),
        ),
        if (_total > _size) _pager(),
      ],
    );
  }

  // ───────── 顶部搜索 ─────────
  Widget _searchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.pagePadding, 10, context.pagePadding, 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _kwCtrl,
                onSubmitted: (_) {
                  _page = 1;
                  _load();
                },
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索昵称 / 邮箱 / QQ / 账号',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.full)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _iconBtn(
            _selectMode ? Icons.close_rounded : Icons.checklist_rounded,
            () => setState(() {
              _selectMode = !_selectMode;
              _selected.clear();
            }),
            active: _selectMode,
            tip: '批量操作',
          ),
          const SizedBox(width: 6),
          _iconBtn(Icons.ios_share_rounded, _exportCsv, tip: '导出 CSV'),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData i, VoidCallback f,
      {bool active = false, String? tip}) {
    return GestureDetector(
      onTap: f,
      child: Tooltip(
        message: tip ?? '',
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active
                ? C.brand.withAlpha(context.isDark ? 60 : 30)
                : (context.isDark ? Colors.white.withAlpha(10) : Colors.white),
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.stroke),
          ),
          child: Icon(i, size: 19, color: active ? C.brand : context.t2),
        ),
      ),
    );
  }

  // ───────── 统计条 ─────────
  Widget _statBar() {
    if (_stat.isEmpty) return const SizedBox.shrink();
    int v(String k) => (_stat[k] as num?)?.toInt() ?? 0;
    final money = (_stat['money'] ?? '0').toString();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.pagePadding, 2, context.pagePadding, 6),
      child: KitCard(
        radius: R.md,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            _statItem('用户', '${v('total')}', C.brand),
            _divider(),
            _statItem('会员', '${v('vip')}', C.gold),
            _divider(),
            _statItem('今日', '${v('today')}', C.mint),
            _divider(),
            _statItem('封禁', '${v('banned')}', C.danger),
            _divider(),
            _statItem('累计', '¥$money', C.success),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 26,
        color: context.isDark
            ? Colors.white.withAlpha(18)
            : Colors.black.withAlpha(10),
      );

  Widget _statItem(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ty.h3.copyWith(fontSize: 14, color: color)),
            const SizedBox(height: 2),
            Text(label, style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3)),
          ],
        ),
      );

  // ───────── 筛选胶囊 ─────────
  Widget _filterBar() {
    const items = [
      ('all', '全部'),
      ('vip', '会员'),
      ('admin', '管理员'),
      ('today', '今日新增'),
      ('banned', '已封禁'),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
            context.pagePadding, 4, context.pagePadding, 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final sel = _filter == items[i].$1;
          return GestureDetector(
            onTap: () => _switchFilter(items[i].$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel ? Deco.brandGradient : null,
                color: sel
                    ? null
                    : (context.isDark ? Colors.white.withAlpha(10) : Colors.white),
                borderRadius: BorderRadius.circular(R.full),
                border: sel ? null : Border.all(color: C.stroke),
              ),
              child: Text(
                items[i].$2,
                style: Ty.tiny.copyWith(
                  fontSize: 12.5,
                  color: sel ? Colors.white : context.t2,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────── 批量操作条 ─────────
  Widget _batchBar() {
    final n = _selected.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.pagePadding, 4, context.pagePadding, 6),
      child: KitCard(
        radius: R.md,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Column(
          children: [
            Row(
              children: [
                Text('已选 $n 位',
                    style: Ty.tiny.copyWith(
                        color: C.brand, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() {
                    if (_selected.length == _list.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(
                          _list.map((u) => int.tryParse('${u['id']}') ?? 0));
                      _selected.remove(0);
                    }
                  }),
                  child: Text(
                    _selected.length == _list.length ? '取消全选' : '全选本页',
                    style: Ty.tiny.copyWith(
                        color: context.t2, fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                if (n > 0)
                  GestureDetector(
                    onTap: () => setState(_selected.clear),
                    child: Text('清空',
                        style: Ty.tiny.copyWith(color: C.danger)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  MiniAction(
                    label: '送30天VIP',
                    icon: Icons.workspace_premium_outlined,
                    color: C.gold,
                    onTap: n == 0 ? () {} : () => _batch('vip', 30),
                  ),
                  const SizedBox(width: 7),
                  MiniAction(
                    label: '解禁',
                    icon: Icons.lock_open_rounded,
                    color: C.mint,
                    onTap: n == 0 ? () {} : () => _batch('unban'),
                  ),
                  const SizedBox(width: 7),
                  MiniAction(
                    label: '封禁',
                    icon: Icons.block_rounded,
                    color: C.warning,
                    onTap: n == 0 ? () {} : () => _batch('ban'),
                  ),
                  const SizedBox(width: 7),
                  MiniAction(
                    label: '删除',
                    icon: Icons.delete_outline_rounded,
                    color: C.danger,
                    onTap: n == 0 ? () {} : () => _batch('delete'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batch(String op, [int days = 30]) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    if (op != 'unban') {
      final label = const {
            'vip': '赠送 30 天会员',
            'ban': '禁用',
            'delete': '删除',
          }[op] ??
          op;
      final ok = await Get.dialog<bool>(AlertDialog(
        title: Text('批量$label'),
        content: Text('将对选中的 ${ids.length} 位用户执行「$label」，是否继续？'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消')),
          FilledButton(
            style: op == 'delete'
                ? FilledButton.styleFrom(backgroundColor: C.danger)
                : null,
            onPressed: () => Get.back(result: true),
            child: const Text('确定'),
          ),
        ],
      ));
      if (ok != true) return;
    }
    try {
      await _svc.userBatch(ids, op, days: days);
      ToastUtil.success('批量操作完成');
      setState(_selected.clear);
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _exportCsv() async {
    try {
      final csv = await _svc.userExportCsv(filter: _filter);
      if (csv.isEmpty) {
        ToastUtil.info('没有可导出的数据');
        return;
      }
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.xl)),
          title: const Text('用户数据 CSV',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                csv,
                style: const TextStyle(fontSize: 11, height: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
                if (ctx.mounted) Navigator.pop(ctx);
                ToastUtil.success('已复制到剪贴板');
              },
              child: const Text('复制'),
            ),
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          ],
        ),
      );
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ───────── 用户卡片 ─────────
  Widget _userCard(Map u) {
    final id = int.tryParse('${u['id']}') ?? 0;
    final isAdmin = u['is_admin'] == true;
    final isVip = u['is_vip'] == true;
    final banned = u['status'] == 'hidden';
    final sel = _selected.contains(id);

    return KitCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      border: sel,
      onTap: _selectMode ? () => setState(() {
        if (sel) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      }) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_selectMode) ...[
                Icon(
                  sel
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: sel ? C.brand : context.t3,
                ),
                const SizedBox(width: 9),
              ],
              ClipOval(
                child: (u['avatar'] ?? '').toString().isEmpty
                    ? Container(
                        width: 40,
                        height: 40,
                        color: C.brand.withAlpha(context.isDark ? 40 : 26),
                        child:
                            Icon(Icons.person, size: 21, color: C.brand))
                    : CachedNetworkImage(
                        imageUrl: '${u['avatar']}',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${u['nickname'] ?? '未设置昵称'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.h3.copyWith(
                                fontSize: 14.5, color: context.t1)),
                        if (isAdmin)
                          Pill('管理员', color: C.brand, small: true),
                        if (isVip)
                          const Pill('VIP', color: C.gold, small: true),
                        if (banned)
                          const Pill('已禁用', color: C.danger, small: true),
                        if ((u['title'] ?? '').toString().isNotEmpty)
                          Pill('${u['title']}',
                              color: C.violet, small: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if ((u['email'] ?? '').toString().isNotEmpty)
                          '${u['email']}',
                        if ((u['qq'] ?? '').toString().isNotEmpty)
                          'QQ ${u['qq']}',
                        'ID $id',
                      ].join(' · '),
                      style: Ty.tiny.copyWith(color: context.t3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 数据行：积分 / 余额 / 注册时间 / 会员到期 / 最后登录
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _meta(Icons.stars_outlined, '积分 ${u['score'] ?? 0}'),
              _meta(Icons.account_balance_wallet_outlined,
                  '余额 ¥${u['money'] ?? '0.00'}'),
              _meta(Icons.event_outlined,
                  '注册 ${u['createtime_text'] ?? '-'}'),
              if (isVip)
                _meta(Icons.workspace_premium_outlined,
                    '会员至 ${u['vip_expire_text']}', color: C.gold),
              _meta(Icons.login_rounded, '${u['login_time_text'] ?? '-'}'),
            ],
          ),
          if (_selectMode) const SizedBox.shrink() else ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                MiniAction(
                    label: '详情',
                    icon: Icons.info_outline_rounded,
                    onTap: () => _showDetail(u)),
                MiniAction(
                    label: '操作日志',
                    icon: Icons.history_rounded,
                    color: C.cyan,
                    onTap: () => _showUserLogs(id, '${u['nickname']}')),
                MiniAction(
                    label: '编辑',
                    icon: Icons.edit_outlined,
                    onTap: () => _editUser(u)),
                MiniAction(
                    label: '自定义IP',
                    icon: Icons.location_on_outlined,
                    color: C.cyan,
                    onTap: () => _editCustomIp(u)),
                MiniAction(
                  label: '重置密码',
                  icon: Icons.key_rounded,
                  color: C.violet,
                  onTap: () => _resetPassword(u),
                ),
                MiniAction(
                  label: '余额',
                  icon: Icons.account_balance_wallet_outlined,
                  color: C.success,
                  onTap: () => _editMoney(u),
                ),
                MiniAction(
                  label: '会员',
                  icon: Icons.workspace_premium_outlined,
                  color: C.gold,
                  onTap: () => _grantVip(id, 30),
                ),
                MiniAction(
                  label: isAdmin ? '取消管理' : '设为管理',
                  icon: isAdmin
                      ? Icons.person_remove_alt_1_outlined
                      : Icons.admin_panel_settings_outlined,
                  onTap: () async {
                    await _svc.setAdmin(id, !isAdmin);
                    ToastUtil.success(isAdmin ? '已取消' : '已设为管理员');
                    _load();
                  },
                ),
                MiniAction(
                  label: banned ? '解禁' : '禁用',
                  icon: banned
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
                  color: C.warning,
                  onTap: () async {
                    await _svc.toggleUserStatus(id);
                    ToastUtil.success(banned ? '已解禁' : '已禁用');
                    _load();
                  },
                ),
                MiniAction(
                  label: '删除',
                  icon: Icons.delete_outline_rounded,
                  color: C.danger,
                  onTap: () async {
                    final ok = await Get.dialog<bool>(AlertDialog(
                      title: const Text('删除用户'),
                      content: Text(
                          '确定删除「${u['nickname']}」？\n该操作不可恢复，其登录态会一并清除。'),
                      actions: [
                        TextButton(
                            onPressed: () => Get.back(result: false),
                            child: const Text('取消')),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: C.danger),
                          onPressed: () => Get.back(result: true),
                          child: const Text('删除'),
                        ),
                      ],
                    ));
                    if (ok != true) return;
                    await _svc.deleteUser(id);
                    ToastUtil.success('已删除');
                    _load();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData i, String text, {Color? color}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 12, color: color ?? context.t3),
          const SizedBox(width: 3),
          Text(text,
              style: Ty.tiny.copyWith(fontSize: 11, color: color ?? context.t3)),
        ],
      );

  /// 会员天数调整：赠送 / 扣减 / 设为永久
  Future<void> _grantVip(int id, int days) async {
    String mode = 'add'; // add | sub | forever
    final dayCtrl = TextEditingController(text: '30');
    String err = '';

    final ok = await Get.dialog<bool>(
      StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: const Text('会员天数调整',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('「赠送」在现有到期日上叠加；「扣减」从到期日往前扣。',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _modeChip('赠送', 'add', mode, ctx,
                          (m) => setD(() => mode = m)),
                      _modeChip('扣减', 'sub', mode, ctx,
                          (m) => setD(() => mode = m)),
                      _modeChip('设为永久', 'forever', mode, ctx,
                          (m) => setD(() => mode = m)),
                    ],
                  ),
                  if (mode != 'forever') ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [1, 7, 30, 90, 365].map((n) {
                        final sel = dayCtrl.text == '$n';
                        return GestureDetector(
                          onTap: () => setD(() => dayCtrl.text = '$n'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: sel ? Deco.brandGradient : null,
                              color: sel ? null : Theme.of(ctx).cardColor,
                              borderRadius: BorderRadius.circular(R.full),
                              border: sel ? null : Border.all(color: C.stroke),
                            ),
                            child: Text('$n 天',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? Colors.white : ctx.t2)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '天数（也可自己输入）',
                        isDense: true,
                      ),
                      onChanged: (_) => setD(() {}),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: C.gold.withAlpha(24),
                        borderRadius: BorderRadius.circular(R.sm),
                      ),
                      child: const Text('设为永久会员（到期日 2099-12-31）',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: C.gold)),
                    ),
                  ],
                  if (err.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(err,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: C.danger,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (mode != 'forever') {
                  final n = int.tryParse(dayCtrl.text.trim()) ?? 0;
                  if (n <= 0) {
                    setD(() => err = '请输入大于 0 的天数');
                    return;
                  }
                }
                Get.back(result: true);
              },
              child: const Text('确定'),
            ),
          ],
        );
      }),
    );
    if (ok != true) return;
    final n = mode == 'forever' ? 0 : (int.tryParse(dayCtrl.text.trim()) ?? 0);
    try {
      final r = await _svc.grantVip(id, n, mode: mode);
      ToastUtil.success(mode == 'forever'
          ? '已设为永久会员'
          : (mode == 'sub' ? '已扣减 $n 天' : '已赠送 $n 天'));
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 密码管理：查看原密码 + 重置新密码（两个 Tab）
  /// ★ 自定义 IP 显示：覆盖用户展示的 IP / 归属地
  Future<void> _editCustomIp(Map u) async {
    final id = int.tryParse('${u['id']}') ?? 0;
    if (id <= 0) return;
    final ipCtrl = TextEditingController(text: '${u['custom_ip'] ?? ''}');
    final addrCtrl = TextEditingController(text: '${u['custom_addr'] ?? ''}');
    bool on = '${u['custom_ip_on'] ?? 0}' == '1';
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('自定义IP显示 · ${u['nickname'] ?? ''}'),
      content: StatefulBuilder(
        builder: (ctx, setD) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipCtrl,
              decoration: const InputDecoration(
                labelText: '显示 IP',
                hintText: '留空 = 用真实登录 IP',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              decoration: const InputDecoration(
                labelText: '归属地',
                hintText: '如：广东·深圳',
                isDense: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('启用自定义显示', style: TextStyle(fontSize: 14)),
              value: on,
              onChanged: (v) => setD(() => on = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('保存')),
      ],
    ));
    if (ok != true) return;
    try {
      await _svc.userCustomIp(
        id: id,
        customIp: ipCtrl.text.trim(),
        customAddr: addrCtrl.text.trim(),
        on: on,
      );
      ToastUtil.success('自定义IP显示已保存');
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _resetPassword(Map u) async {
    final id = int.tryParse('${u['id']}') ?? 0;
    final c1 = TextEditingController();
    String err = '';
    bool hide = true;
    bool loadingOld = true;
    String oldPwd = '';
    bool oldAvailable = false;
    bool showOld = false;
    String tab = 'view'; // view | set

    await Get.dialog<bool>(
      StatefulBuilder(builder: (ctx, setD) {
        // 首次打开时拉取原密码
        if (loadingOld) {
          AdminService.instance.userPassword(id).then((r) {
            if (!ctx.mounted) return;
            setD(() {
              loadingOld = false;
              oldPwd = (r['password'] ?? '').toString();
              oldAvailable = r['available'] == true;
            });
          }).catchError((e) {
            if (ctx.mounted) {
              setD(() {
                loadingOld = false;
                oldAvailable = false;
              });
            }
          });
        }

        return AlertDialog(
          title: Text('密码管理：${u['nickname']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _modeChip('查看原密码', 'view', tab, ctx,
                          (m) => setD(() => tab = m)),
                      const SizedBox(width: 8),
                      _modeChip('重置密码', 'set', tab, ctx,
                          (m) => setD(() => tab = m)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (tab == 'view') ...[
                    if (loadingOld)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('读取中…', style: TextStyle(fontSize: 12.5)),
                        ]),
                      )
                    else if (!oldAvailable)
                      const Text(
                        '该账号没有可查看的密码。\n'
                        '原因：这是站点上注册或早期创建的账号，只存了单向加密的密码哈希，'
                        '无法还原。可以切到「重置密码」设一个新密码。',
                        style: TextStyle(fontSize: 12.5, height: 1.6),
                      )
                    else ...[
                      const Text('该用户当前密码：',
                          style: TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: C.brand.withAlpha(20),
                          borderRadius: BorderRadius.circular(R.sm),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                showOld ? oldPwd : '●' * oldPwd.length.clamp(6, 16),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace'),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                showOld
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                              ),
                              onPressed: () => setD(() => showOld = !showOld),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: oldPwd));
                                ToastUtil.success('已复制');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '仅用于协助用户找回密码，请勿泄露。',
                        style: TextStyle(fontSize: 11, color: C.warning),
                      ),
                    ],
                  ] else ...[
                    const Text('设置一个新的登录密码（至少 6 位）。',
                        style: TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: c1,
                      obscureText: hide,
                      decoration: InputDecoration(
                        labelText: '新密码',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setD(() => hide = !hide),
                        ),
                      ),
                    ),
                    if (err.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(err,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: C.danger,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('关闭')),
            if (tab == 'set')
              FilledButton(
                onPressed: () {
                  if (c1.text.trim().length < 6) {
                    setD(() => err = '密码至少 6 位');
                    return;
                  }
                  Get.back(result: true);
                },
                child: const Text('保存'),
              ),
          ],
        );
      }),
    );

    // 只有点了「保存」且密码非空才提交
    if (c1.text.trim().length >= 6) {
      try {
        await _svc.resetUserPassword(id, c1.text.trim());
        ToastUtil.success('密码已重置为新密码');
      } catch (e) {
        ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// 修改余额（充值 / 扣减 / 直接设定）
  Future<void> _editMoney(Map u) async {
    final id = int.tryParse('${u['id']}') ?? 0;
    final cur = double.tryParse('${u['money'] ?? 0}') ?? 0;
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String mode = 'add'; // add | sub | set

    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('修改余额：${u['nickname']}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: StatefulBuilder(builder: (ctx, setD) {
        final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
        double preview = cur;
        if (mode == 'add') preview = cur + amt;
        if (mode == 'sub') preview = cur - amt;
        if (mode == 'set') preview = amt;
        if (preview < 0) preview = 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前余额  ¥${cur.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _modeChip('充值', 'add', mode, ctx, (m) => setD(() => mode = m)),
                _modeChip('扣减', 'sub', mode, ctx, (m) => setD(() => mode = m)),
                _modeChip('直接设定', 'set', mode, ctx,
                    (m) => setD(() => mode = m)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amtCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额（元）',
                isDense: true,
                prefixText: '¥ ',
              ),
              onChanged: (_) => setD(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                hintText: '如：活动奖励 / 退款',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: C.success.withAlpha(22),
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Text('改后余额  ¥${preview.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: C.success)),
            ),
          ],
        );
      }),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Get.back(result: true), child: const Text('确定')),
      ],
    ));
    if (ok != true) return;

    final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
    double target = cur;
    if (mode == 'add') target = cur + amt;
    if (mode == 'sub') target = cur - amt;
    if (mode == 'set') target = amt;
    if (target < 0) target = 0;
    try {
      await _svc.saveUser({
        'id': id,
        'money': target.toStringAsFixed(2),
      });
      ToastUtil.success('余额已更新为 ¥${target.toStringAsFixed(2)}');
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _modeChip(String label, String value, String cur, BuildContext ctx,
      ValueChanged<String> onTap) {
    final sel = cur == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: sel ? Deco.brandGradient : null,
          color: sel ? null : Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.circular(R.full),
          border: sel ? null : Border.all(color: C.stroke),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : ctx.t2)),
      ),
    );
  }

  /// 某用户的详细操作日志（需求 #4）
  Future<void> _showUserLogs(int id, String nickname) async {
    Map<String, dynamic> data = {};
    bool loading = true;
    try {
      data = await _svc.userLogs(id);
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
    loading = false;
    if (!mounted) return;

    final user = Map<String, dynamic>.from(data['user'] ?? {});
    final logs = ((data['logs'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final stat = Map<String, dynamic>.from(data['stat'] ?? {});
    final devices = ((stat['devices'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final ips = ((stat['ips'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.86,
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? C.bg1
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: C.cyan, size: 21),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$nickname · 操作日志',
                      style: Ty.h2.copyWith(fontSize: 17, color: ctx.t1)),
                ),
                IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            // 汇总信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.cyan.withAlpha(ctx.isDark ? 26 : 16),
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('共 ${stat['total'] ?? 0} 条记录',
                      style: Ty.h3.copyWith(fontSize: 14, color: ctx.t1)),
                  const SizedBox(height: 6),
                  if (user['email'] != null && '${user['email']}'.isNotEmpty)
                    Text('邮箱：${user['email']}',
                        style: Ty.tiny.copyWith(color: ctx.t3)),
                  if (devices.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '设备：${devices.map((d) => '${d['device']}(${d['n']})').join('、')}',
                        style: Ty.tiny.copyWith(color: ctx.t3),
                      ),
                    ),
                  if (ips.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'IP：${ips.take(3).map((d) => '${d['ip']}（${d['address']}）').join(' / ')}',
                        style: Ty.tiny.copyWith(color: ctx.t3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: loading
                  ? const Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4)))
                  : (logs.isEmpty
                      ? const Center(child: Text('暂无操作记录'))
                      : ListView.separated(
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 7),
                          itemBuilder: (_, i) {
                            final L = logs[i];
                            return Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: ctx.isDark
                                    ? Colors.white.withAlpha(8)
                                    : C.bg2,
                                borderRadius: BorderRadius.circular(R.md),
                                border: Border.all(
                                    color: C.stroke.withAlpha(50), width: 0.8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Pill('${L['action']}',
                                          color: C.brand, small: true),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text('${L['detail'] ?? ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Ty.small.copyWith(
                                                fontSize: 12.5,
                                                color: ctx.t2)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    children: [
                                      _miniMeta(ctx,
                                          Icons.access_time_rounded,
                                          '${L['createtime_text'] ?? ''}'),
                                      _miniMeta(ctx, Icons.location_on_outlined,
                                          '${L['ip']} ${L['address']}'),
                                      if ('${L['device'] ?? ''}'.isNotEmpty)
                                        _miniMeta(ctx,
                                            Icons.phone_android_rounded,
                                            '${L['device']}'),
                                      if ('${L['os'] ?? ''}'.isNotEmpty)
                                        _miniMeta(ctx, Icons.memory_rounded,
                                            '${L['os']}'),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMeta(BuildContext ctx, IconData i, String t) {
    if (t.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 11, color: ctx.t3),
        const SizedBox(width: 3),
        Text(t.trim(),
            style: Ty.tiny.copyWith(fontSize: 10.5, color: ctx.t3)),
      ],
    );
  }

  /// 用户详情（只读，展示全部字段）
  Future<void> _showDetail(Map u) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.xl)),
        title: Text('${u['nickname'] ?? '用户详情'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('ID', '${u['id']}'),
                _detailRow('账号', '${u['username'] ?? '-'}'),
                _detailRow('昵称', '${u['nickname'] ?? '-'}'),
                _detailRow('邮箱', '${u['email'] ?? '-'}'),
                _detailRow('QQ', '${u['qq'] ?? '-'}'),
                _detailRow('称号', '${u['title'] ?? '-'}'),
                _detailRow('积分', '${u['score'] ?? 0}'),
                _detailRow('余额', '¥${u['money'] ?? '0.00'}'),
                _detailRow('身份', u['is_admin'] == true ? '管理员' : '普通用户'),
                _detailRow('状态',
                    u['status'] == 'hidden' ? '已禁用' : '正常'),
                _detailRow('会员',
                    u['is_vip'] == true
                        ? 'VIP 至 ${u['vip_expire_text']}'
                        : '非会员'),
                _detailRow('注册时间', '${u['createtime_text'] ?? '-'}'),
                _detailRow('最后登录', '${u['login_time_text'] ?? '-'}'),
                _detailRow('登录 IP', '${u['login_ip'] ?? '-'}'),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _detailRow(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 66,
              child: Text(k,
                  style: Ty.tiny.copyWith(color: context.t3, fontSize: 12)),
            ),
            Expanded(
              child: SelectableText(v,
                  style: Ty.small.copyWith(fontSize: 12.5, color: context.t1)),
            ),
          ],
        ),
      );

  // ───────── 分页 ─────────
  Widget _pager() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.pagePadding, 2, context.pagePadding, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SoftButton(
            label: '上一页',
            height: 36,
            color: _page > 1 ? C.brand : context.t3,
            onPressed: _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : () {},
          ),
          const SizedBox(width: 14),
          Text('$_page / $_maxPage  ·  共 $_total 人',
              style: Ty.tiny.copyWith(color: context.t2)),
          const SizedBox(width: 14),
          SoftButton(
            label: '下一页',
            height: 36,
            color: _page < _maxPage ? C.brand : context.t3,
            onPressed: _page < _maxPage
                ? () {
                    _page++;
                    _load();
                  }
                : () {},
          ),
        ],
      ),
    );
  }

  // ───────── 编辑用户 ─────────
  Future<void> _editUser(Map u) async {
    final nickCtrl = TextEditingController(text: '${u['nickname'] ?? ''}');
    final emailCtrl = TextEditingController(text: '${u['email'] ?? ''}');
    final qqCtrl = TextEditingController(text: '${u['qq'] ?? ''}');
    final scoreCtrl = TextEditingController(text: '${u['score'] ?? 0}');
    final moneyCtrl = TextEditingController(text: '${u['money'] ?? '0'}');
    final titleCtrl = TextEditingController(text: '${u['title'] ?? ''}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.xl)),
        title: Text('编辑用户：${u['nickname']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nickCtrl,
                    decoration: const InputDecoration(labelText: '昵称')),
                const SizedBox(height: 10),
                TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: '邮箱')),
                const SizedBox(height: 10),
                TextField(
                    controller: qqCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'QQ号')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: scoreCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: '积分')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: moneyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: '余额')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: titleCtrl,
                    maxLength: 12,
                    decoration: const InputDecoration(
                        labelText: '自定义称号',
                        helperText: '显示在广场动态旁，留空则清除')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Get.back(result: true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.saveUser({
        'id': u['id'],
        'nickname': nickCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'qq': qqCtrl.text.trim(),
        'score': int.tryParse(scoreCtrl.text) ?? 0,
        'money': moneyCtrl.text.trim(),
        'title': titleCtrl.text.trim(),
      });
      ToastUtil.success('保存成功');
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
