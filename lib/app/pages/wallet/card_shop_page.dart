import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/user_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';

/// ★ 1014 需求5：卡密商城
///
/// 用户原来只能「使用卡密」（别人给的），没有地方自己买。
/// 这个页面让用户用余额直接购买卡密，买完在「我的卡密」里看到，
/// 点一下即可兑换成会员/积分。
class CardShopPage extends StatefulWidget {
  const CardShopPage({super.key});

  @override
  State<CardShopPage> createState() => _CardShopPageState();
}

class _CardShopPageState extends State<CardShopPage>
    with SingleTickerProviderStateMixin {
  final _svc = UserService.instance;
  late final TabController _tab = TabController(length: 2, vsync: this);

  bool _loading = true;
  String _err = '';
  List<Map<String, dynamic>> _goods = [];
  List<Map<String, dynamic>> _mine = [];
  String _balance = '0.00';
  bool _shopOn = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final r = await _svc.cardShop();
      final mine = await _svc.myCards();
      if (!mounted) return;
      setState(() {
        _goods = ((r['goods'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _balance = '${r['balance'] ?? '0.00'}';
        _shopOn = '${r['card_shop_on'] ?? 1}' == '1';
        _mine = mine;
        _loading = false;
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
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        title: const Text('卡密商城', style: TextStyle(fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, size: 20, color: context.t2),
            tooltip: '刷新',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: C.brand,
          unselectedLabelColor: context.t3,
          indicatorColor: C.brand,
          tabs: const [
            Tab(text: '购买卡密'),
            Tab(text: '我的卡密'),
          ],
        ),
      ),
      body: _loading
          ? const LoadingState(text: '加载卡密商城…')
          : (_err.isNotEmpty
              ? ErrorState(text: '加载失败', hint: _err, onRetry: _load)
              : TabBarView(
                  controller: _tab,
                  children: [_shopTab(), _mineTab()],
                )),
    );
  }

  // ════════ 购买 Tab ════════
  Widget _shopTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            context.pagePadding, 12, context.pagePadding, 24),
        children: [
          _balanceCard(),
          const SizedBox(height: 14),
          if (!_shopOn)
            const EmptyState(
              text: '卡密商城未开启',
              hint: '管理员已关闭卡密购买功能',
              icon: Icons.storefront_outlined,
            )
          else ...[
            Text('选择要购买的卡密',
                style: Ty.h3.copyWith(fontSize: 14.5, color: context.t1)),
            const SizedBox(height: 10),
            for (final g in _goods) _goodsCard(g),
            const SizedBox(height: 6),
            Text('购买后会出现在「我的卡密」，点一下即可兑换。',
                style: Ty.tiny.copyWith(color: context.t3)),
          ],
        ],
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B6CFF), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(R.lg),
        boxShadow: [
          BoxShadow(
            color: C.brand.withAlpha(90),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我的余额',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withAlpha(200))),
                const SizedBox(height: 6),
                Text('¥$_balance',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Get.toNamed('/recharge'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withAlpha(90)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 4),
                  Text('充值',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goodsCard(Map<String, dynamic> g) {
    final name = '${g['name'] ?? '会员卡'}';
    final price = '${g['price'] ?? '0.00'}';
    final desc = '${g['desc'] ?? ''}';
    final type = '${g['type'] ?? 'vip'}';
    final value = g['value'] ?? 0;
    final isVip = type == 'vip';
    final accent = isVip ? C.gold : C.mint;
    final canBuy = _shopOn;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: KitCard(
        radius: R.lg,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withAlpha(200), accent.withAlpha(120)],
                ),
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Icon(
                isVip
                    ? Icons.workspace_premium_rounded
                    : Icons.stars_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Ty.h3.copyWith(fontSize: 15, color: context.t1)),
                  const SizedBox(height: 4),
                  Text(
                    desc.isNotEmpty
                        ? desc
                        : (isVip ? '兑换后会员 +$value 天' : '兑换后积分 +$value'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.tiny.copyWith(color: context.t3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('¥$price',
                    style: Ty.h3.copyWith(fontSize: 17, color: accent)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: canBuy ? () => _buy(g) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: Deco.brandGradient,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: C.brand.withAlpha(90),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text('购买',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════ 我的卡密 Tab ════════
  Widget _mineTab() {
    if (_mine.isEmpty) {
      return const EmptyState(
        text: '还没有购买过卡密',
        hint: '去「购买卡密」看看，买完会出现在这里',
        icon: Icons.confirmation_number_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
            context.pagePadding, 12, context.pagePadding, 24),
        itemCount: _mine.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _myCardTile(_mine[i]),
      ),
    );
  }

  Widget _myCardTile(Map<String, dynamic> c) {
    final code = '${c['code'] ?? ''}';
    final name = '${c['name'] ?? ''}';
    final used = '${c['used'] ?? 0}' == '1';
    final price = '${c['buy_money'] ?? ''}';
    final buyTime = '${c['buy_time_text'] ?? ''}';
    return KitCard(
      radius: R.md,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: Ty.h3.copyWith(fontSize: 14.5, color: context.t1)),
              ),
              Pill(used ? '已兑换' : '未使用',
                  color: used ? C.t3 : C.success, small: true),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.isDark
                  ? Colors.white.withAlpha(8)
                  : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(R.sm),
              border: Border.all(
                color: context.isDark
                    ? Colors.white.withAlpha(18)
                    : Colors.black.withAlpha(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      color: used ? context.t3 : context.t1,
                      decoration: used ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    ToastUtil.success('卡密已复制');
                  },
                  child: Icon(Icons.copy_rounded, size: 17, color: C.brand),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text('购买价 ¥$price',
                  style: Ty.tiny.copyWith(color: context.t3)),
              if (buyTime.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(buyTime, style: Ty.tiny.copyWith(color: context.t3)),
              ],
              const Spacer(),
              if (!used)
                GestureDetector(
                  onTap: () => _redeem(code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: Deco.goldGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('立即兑换',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════ 操作 ════════
  Future<void> _buy(Map<String, dynamic> g) async {
    final name = '${g['name'] ?? ''}';
    final price = '${g['price'] ?? '0.00'}';
    final go = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认购买'),
        content: Text('购买「$name」\n\n将扣除余额 ¥$price\n当前余额 ¥$_balance'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Get.back(result: true),
              child: const Text('确认购买')),
        ],
      ),
    );
    if (go != true) return;
    try {
      final r = await _svc.buyCard('${g['key'] ?? ''}');
      final code = '${r['code'] ?? ''}';
      if (!mounted) return;
      // 购买成功 → 弹出卡密并可直接复制
      await Get.dialog(
        AlertDialog(
          title: const Text('购买成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$name 已发放，卡密：',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 10),
              Text('余额 ¥${r['balance'] ?? '0.00'}',
                  style: TextStyle(fontSize: 12, color: C.t3)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                ToastUtil.success('卡密已复制');
              },
              child: const Text('复制卡密'),
            ),
            FilledButton(
              onPressed: () {
                Get.back();
                _tab.animateTo(1);
              },
              child: const Text('去兑换'),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _redeem(String code) async {
    final go = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认兑换'),
        content: Text('将兑换卡密：\n$code\n\n兑换后不可撤销，确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Get.back(result: true),
              child: const Text('确认兑换')),
        ],
      ),
    );
    if (go != true) return;
    try {
      final msg = await _svc.redeem(code);
      ToastUtil.success(msg);
      await _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
