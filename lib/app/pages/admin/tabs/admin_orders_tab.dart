import 'package:flutter/material.dart';
import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 后台 · 订单管理
/// 收入概览 + 状态筛选 + 关键词搜索 + 分页 + 订单详情（补单 / 删除）
/// ★ 1014 需求1：完整显示「购买者」（昵称 / 邮箱 / 用户ID），
///   并可点开订单详情查看流水号、套餐天数等全量信息。
class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab>
    with AutomaticKeepAliveClientMixin {
  final _svc = AdminService.instance;
  bool _loading = true;
  bool _loadingMore = false;
  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic> _stats = {};
  int? _status; // null=全部 0=待支付 1=已支付
  final _kwCtrl = TextEditingController();
  final _scroll = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
        _hasMore = true;
      });
    }
    try {
      final results = await Future.wait([
        _svc.orders(status: _status, keyword: _kwCtrl.text.trim(), page: _page),
        if (reset) _svc.orderStats() else Future.value(_stats),
      ]);
      if (!mounted) return;
      final list = results[0] as List<Map<String, dynamic>>;
      setState(() {
        _list = list;
        _stats = results[1] as Map<String, dynamic>;
        _hasMore = list.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final list = await _svc.orders(
        status: _status,
        keyword: _kwCtrl.text.trim(),
        page: next,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _list = [..._list, ...list];
        _hasMore = list.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _statsRow(),
        _searchRow(),
        _filterRow(),
        Expanded(
          child: _loading
              ? const LoadingState(text: '加载订单…')
              : (_list.isEmpty
                    ? const EmptyState(
                        text: '暂无订单',
                        hint: '用户购买会员或充值余额后订单会显示在这里',
                        icon: Icons.receipt_long_rounded,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            4,
                            context.pagePadding,
                            24,
                          ),
                          itemCount: _list.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i >= _list.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return _orderCard(_list[i]);
                          },
                        ),
                      )),
        ),
      ],
    );
  }

  /// 收入概览（总/今日/已付/待付）
  Widget _statsRow() {
    final items = [
      ('总收入', '¥${_stats['total_money'] ?? '0.00'}', C.gold),
      ('今日', '¥${_stats['today_money'] ?? '0.00'}', C.success),
      ('已支付', '${_stats['paid_count'] ?? 0}', C.brand),
      ('待支付', '${_stats['unpaid_count'] ?? 0}', C.warning),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        6,
      ),
      child: AdCard(
        radius: R.lg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 28,
                  color: context.isDark
                      ? Colors.white.withAlpha(14)
                      : Colors.black.withAlpha(8),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      items[i].$2,
                      style: Ty.h3.copyWith(fontSize: 15, color: items[i].$3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$1,
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ★ 1014 需求1：关键词搜索（订单号 / 买家邮箱 / 买家昵称）
  Widget _searchRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        2,
        context.pagePadding,
        4,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _kwCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索订单号 / 买家邮箱 / 昵称',
                  hintStyle: Ty.small.copyWith(color: context.t3),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _kwCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _kwCtrl.clear();
                            _load();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SoftButton(
            label: '搜索',
            icon: Icons.search_rounded,
            height: 40,
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    const labels = ['全部', '待支付', '已支付'];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        6,
        context.pagePadding,
        8,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            GestureDetector(
              onTap: () {
                setState(() => _status = i == 0 ? null : i - 1);
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: (_status == (i == 0 ? null : i - 1))
                      ? C.brand
                      : (context.isDark ? C.bg2 : Colors.white),
                  borderRadius: BorderRadius.circular(R.full),
                  border: Border.all(
                    color: (_status == (i == 0 ? null : i - 1))
                        ? C.brand
                        : (context.isDark
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(8)),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: Ty.tiny.copyWith(
                    fontWeight: FontWeight.w800,
                    color: (_status == (i == 0 ? null : i - 1))
                        ? Colors.white
                        : context.t2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, size: 20, color: context.t2),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  /// 买家展示名：优先昵称 → 邮箱 → 用户ID → 「游客」
  String _buyerName(Map<String, dynamic> o) {
    final nick = (o['nickname'] ?? '').toString().trim();
    if (nick.isNotEmpty) return nick;
    final mail = (o['email'] ?? '').toString().trim();
    if (mail.isNotEmpty) return mail;
    final uid = int.tryParse('${o['user_id'] ?? 0}') ?? 0;
    if (uid > 0) return '用户 #$uid';
    return '未知买家';
  }

  /// 买家副标题（邮箱 / ID）
  String _buyerSub(Map<String, dynamic> o) {
    final nick = (o['nickname'] ?? '').toString().trim();
    final mail = (o['email'] ?? '').toString().trim();
    final uid = int.tryParse('${o['user_id'] ?? 0}') ?? 0;
    final parts = <String>[];
    if (nick.isNotEmpty && mail.isNotEmpty) parts.add(mail);
    if (uid > 0) parts.add('ID $uid');
    return parts.join(' · ');
  }

  /// 订单类型：会员套餐 / 余额充值
  String _orderKind(Map<String, dynamic> o) {
    final plan = (o['plan_id'] ?? '').toString();
    if (plan == 'recharge') return '余额充值';
    return '会员套餐';
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final paid = o['status'] == 1 || o['status'] == '1';
    final money = (o['money'] ?? '').toString();
    final name = (o['name'] ?? '').toString();
    final no = (o['out_trade_no'] ?? '').toString();
    final buyer = _buyerName(o);
    final buyerSub = _buyerSub(o);
    final kind = _orderKind(o);
    final payType =
        {'alipay': '支付宝', 'wxpay': '微信', 'qqpay': 'QQ'}[(o['pay_type'] ?? '')
            .toString()] ??
        (o['pay_type'] ?? '').toString();
    final time =
        (paid ? (o['paytime_text'] ?? '') : (o['createtime_text'] ?? ''))
            .toString();

    return AdCard(
      radius: R.md,
      padding: const EdgeInsets.all(13),
      onTap: () => _showDetail(o),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Ty.h3.copyWith(fontSize: 14.5, color: context.t1),
                ),
              ),
              Text(
                '¥$money',
                style: Ty.h3.copyWith(fontSize: 16, color: C.gold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Pill(
                paid ? '已支付' : '待支付',
                color: paid ? C.success : C.warning,
                small: true,
              ),
              const SizedBox(width: 6),
              Pill(
                kind,
                color: kind == '余额充值' ? C.cyan : C.violet,
                small: true,
              ),
              if (payType.isNotEmpty) ...[
                const SizedBox(width: 6),
                Pill(payType, color: C.brand, small: true),
              ],
              const Spacer(),
              Text(time, style: Ty.tiny.copyWith(color: context.t3)),
            ],
          ),
          const SizedBox(height: 9),
          // ★ 需求1：购买者信息（昵称/邮箱开头字母头像 + 昵称 + 邮箱/ID）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.isDark
                  ? Colors.white.withAlpha(8)
                  : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(R.sm),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [C.brand.withAlpha(200), C.violet.withAlpha(180)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    buyer.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '购买者：$buyer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ty.small.copyWith(
                          color: context.t1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (buyerSub.isNotEmpty)
                        Text(
                          buyerSub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: context.t3),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '订单号 $no',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ty.tiny.copyWith(color: context.t3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              MiniAction(
                label: '复制订单号',
                icon: Icons.copy_rounded,
                color: C.t3,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: no));
                  ToastUtil.success('订单号已复制');
                },
              ),
              if (!paid) ...[
                const SizedBox(width: 8),
                MiniAction(
                  label: '补单',
                  icon: Icons.check_circle_outline_rounded,
                  color: C.success,
                  onTap: () => _deliver(no),
                ),
              ],
              const Spacer(),
              MiniAction(
                label: '详情',
                icon: Icons.info_outline_rounded,
                color: C.brand,
                onTap: () => _showDetail(o),
              ),
              const SizedBox(width: 8),
              MiniAction(
                label: '删除',
                icon: Icons.delete_outline_rounded,
                color: C.danger,
                onTap: () => _delete((o['id'] ?? 0) as int),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ★ 1014 需求1：订单详情（全量字段，便于对账）
  void _showDetail(Map<String, dynamic> o) {
    final paid = o['status'] == 1 || o['status'] == '1';
    final rows = <(String, String)>[
      ('订单号', '${o['out_trade_no'] ?? '-'}'),
      (
        '网关流水号',
        '${(o['trade_no'] ?? '').toString().isEmpty ? '—' : o['trade_no']}',
      ),
      ('商品名称', '${o['name'] ?? '-'}'),
      ('订单类型', _orderKind(o)),
      ('金额', '¥${o['money'] ?? '0.00'}'),
      ('状态', paid ? '已支付' : '待支付'),
      (
        '支付方式',
        {'alipay': '支付宝', 'wxpay': '微信', 'qqpay': 'QQ'}[(o['pay_type'] ?? '')
                .toString()] ??
            '${(o['pay_type'] ?? '').toString().isEmpty ? '—' : o['pay_type']}',
      ),
      (
        '会员天数',
        '${int.tryParse('${o['days'] ?? 0}') == 0 ? '—（充值单）' : '${o['days']} 天'}',
      ),
      ('购买者', _buyerName(o)),
      ('买家邮箱', (o['email'] ?? '').toString().isEmpty ? '—' : '${o['email']}'),
      (
        '用户 ID',
        '${int.tryParse('${o['user_id'] ?? 0}') == 0 ? '—' : o['user_id']}',
      ),
      ('下单时间', '${o['createtime_text'] ?? '-'}'),
      (
        '支付时间',
        '${(o['paytime_text'] ?? '').toString().isEmpty ? '—' : o['paytime_text']}',
      ),
    ];
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg1 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 20, color: C.brand),
                  const SizedBox(width: 8),
                  Text(
                    '订单详情',
                    style: Ty.h2.copyWith(fontSize: 17, color: context.t1),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: context.t3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.isDark
                        ? Colors.white.withAlpha(12)
                        : Colors.black.withAlpha(6),
                  ),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(
                            rows[i].$1,
                            style: Ty.small.copyWith(color: context.t3),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rows[i].$2,
                            style: Ty.small.copyWith(
                              color: context.t1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: '复制订单号',
                      icon: Icons.copy_rounded,
                      height: 44,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: '${o['out_trade_no'] ?? ''}'),
                        );
                        ToastUtil.success('订单号已复制');
                      },
                    ),
                  ),
                  if (!paid) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: '补单',
                        icon: Icons.check_circle_outline_rounded,
                        height: 44,
                        color: C.success,
                        onPressed: () {
                          Get.back();
                          _deliver('${o['out_trade_no'] ?? ''}');
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deliver(String no) async {
    final go = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认补单'),
        content: Text('将把该订单标记为已支付，并给用户开通对应会员。\n订单号：$no'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('确认补单'),
          ),
        ],
      ),
    );
    if (go != true) return;
    try {
      await _svc.deliverOrder(no);
      ToastUtil.success('补单成功，会员已到账');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _delete(int id) async {
    final go = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除订单'),
        content: const Text('仅删除记录，不会回收已开通的会员。确认删除？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (go != true) return;
    try {
      await _svc.deleteOrder(id);
      ToastUtil.success('已删除');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }
}
