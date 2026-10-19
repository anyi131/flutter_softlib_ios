import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_anim.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_kit.dart';

// ═══════════════════════════════════════════════════════════════
// 工具箱 · 第八批（1015）：补齐到 150 个真工具
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 车贷计算 ───────────────
class CarLoanPage extends StatefulWidget {
  const CarLoanPage({super.key});
  @override
  State<CarLoanPage> createState() => _CarLoanPageState();
}

class _CarLoanPageState extends State<CarLoanPage> {
  final _price = TextEditingController(text: '150000');
  final _down = TextEditingController(text: '30');
  final _years = TextEditingController(text: '3');
  final _rate = TextEditingController(text: '4.5');

  @override
  void dispose() {
    _price.dispose();
    _down.dispose();
    _years.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(_price.text) ?? 0;
    final downPct = double.tryParse(_down.text) ?? 0;
    final y = double.tryParse(_years.text) ?? 3;
    final r = (double.tryParse(_rate.text) ?? 4.5) / 100;
    final loan = price * (1 - downPct / 100);
    final n = y * 12;
    final mr = r / 12;
    final monthly = mr == 0
        ? loan / n
        : loan * mr * math.pow(1 + mr, n) / (math.pow(1 + mr, n) - 1);
    final total = monthly * n;
    final interest = total - loan;
    return ToolScaffold(
      title: '车贷计算',
      subtitle: '首付比例 / 月供 / 总利息',

      child: Column(
        children: [
          ToolField(
            controller: _price,
            label: '车价（元）',
            keyboard: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: [
              Expanded(
                child: ToolField(
                  controller: _down,
                  label: '首付比例(%)',
                  keyboard: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolField(
                  controller: _years,
                  label: '年限',
                  keyboard: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolField(
                  controller: _rate,
                  label: '年利率(%)',
                  keyboard: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _r('首付金额', '¥${(price * downPct / 100).toStringAsFixed(2)}'),
                _r('贷款金额', '¥${loan.toStringAsFixed(2)}'),
                const Divider(height: 20),
                _r('每月月供', '¥${monthly.toStringAsFixed(2)}', big: true),
                _r('总利息', '¥${interest.toStringAsFixed(2)}', color: C.danger),
                _r('还款总额', '¥${total.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 19 : 15,
            fontWeight: FontWeight.w900,
            color: color ?? (big ? C.brand : context.t1),
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ② 年终奖个税 ───────────────
class BonusTaxPage extends StatefulWidget {
  const BonusTaxPage({super.key});
  @override
  State<BonusTaxPage> createState() => _BonusTaxPageState();
}

class _BonusTaxPageState extends State<BonusTaxPage> {
  final _c = TextEditingController(text: '30000');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = double.tryParse(_c.text) ?? 0;
    // 年终奖单独计税：月均 = 奖金/12，找税率
    final monthly = b / 12;
    const brackets = [
      (3000.0, 0.03, 0.0),
      (12000.0, 0.10, 210.0),
      (25000.0, 0.20, 1410.0),
      (35000.0, 0.25, 2660.0),
      (55000.0, 0.30, 4410.0),
      (80000.0, 0.35, 7160.0),
      (double.infinity, 0.45, 15160.0),
    ];
    double rate = 0.03, deduct = 0;
    for (final (cap, rt, dd) in brackets) {
      if (monthly <= cap) {
        rate = rt;
        deduct = dd;
        break;
      }
    }
    final tax = b * rate - deduct;
    return ToolScaffold(
      title: '年终奖个税',
      subtitle: '单独计税方式计算',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '年终奖金额（元）',
            keyboard: TextInputType.number,
            icon: Icons.card_giftcard_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                _r('月均奖金', '¥${monthly.toStringAsFixed(2)}'),
                _r('适用税率', '${(rate * 100).toStringAsFixed(0)}%'),
                _r('速算扣除数', '¥${deduct.toStringAsFixed(0)}'),
                const Divider(height: 20),
                _r('应缴个税', '¥${tax.toStringAsFixed(2)}', color: C.danger),
                _r('到手金额', '¥${(b - tax).toStringAsFixed(2)}', big: true),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '注：单独计税与并入综合所得结果不同，可在个税 App 里两种都试一下选少的',
            style: Ty.tiny.copyWith(color: context.t3),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 19 : 15,
            fontWeight: FontWeight.w900,
            color: color ?? (big ? C.brand : context.t1),
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ③ 社保计算 ───────────────
class SocialPage extends StatefulWidget {
  const SocialPage({super.key});
  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final _base = TextEditingController(text: '8000');
  int _type = 0; // 0 职工 1 灵活就业

  @override
  void dispose() {
    _base.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = double.tryParse(_base.text) ?? 0;
    // 典型比例（各地有差异）
    final pension = b * 0.08;
    final medical = b * 0.02;
    final unemploy = b * 0.005;
    final housing = b * 0.12;
    final total = pension + medical + unemploy + housing;
    return ToolScaffold(
      title: '五险一金',
      subtitle: '个人缴纳部分估算',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _base,
            label: '缴费基数（元）',
            keyboard: TextInputType.number,
            icon: Icons.work_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                _r('养老保险 8%', '¥${pension.toStringAsFixed(2)}'),
                _r('医疗保险 2%', '¥${medical.toStringAsFixed(2)}'),
                _r('失业保险 0.5%', '¥${unemploy.toStringAsFixed(2)}'),
                _r('住房公积金 12%', '¥${housing.toStringAsFixed(2)}'),
                const Divider(height: 20),
                _r('个人合计', '¥${total.toStringAsFixed(2)}', big: true),
                _r(
                  '占比',
                  '${(total / (b == 0 ? 1 : b) * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '注：各地比例不同（如公积金 5%-12%），以当地政策为准',
            style: Ty.tiny.copyWith(color: context.t3),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 18 : 14.5,
            fontWeight: FontWeight.w900,
            color: big ? C.brand : context.t1,
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ④ 工资到手 ───────────────
class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key});
  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  final _gross = TextEditingController(text: '15000');
  final _housing = TextEditingController(text: '12');

  @override
  void dispose() {
    _gross.dispose();
    _housing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = double.tryParse(_gross.text) ?? 0;
    final hp = (double.tryParse(_housing.text) ?? 12) / 100;
    final social = g * (0.08 + 0.02 + 0.005);
    final housing = g * hp;
    final taxable = math.max(0.0, g - social - housing - 5000);
    const brackets = [
      (3000.0, 0.03, 0.0),
      (12000.0, 0.10, 210.0),
      (25000.0, 0.20, 1410.0),
      (35000.0, 0.25, 2660.0),
      (55000.0, 0.30, 4410.0),
      (80000.0, 0.35, 7160.0),
      (double.infinity, 0.45, 15160.0),
    ];
    double tax = 0;
    for (final (cap, rt, dd) in brackets) {
      if (taxable <= cap) {
        tax = math.max(0, taxable * rt - dd);
        break;
      }
    }
    final net = g - social - housing - tax;
    return ToolScaffold(
      title: '工资到手',
      subtitle: '税前 → 税后到手估算',

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ToolField(
                  controller: _gross,
                  label: '税前工资',
                  keyboard: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolField(
                  controller: _housing,
                  label: '公积金%',
                  keyboard: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _r('五险(个人)', '-¥${social.toStringAsFixed(2)}'),
                _r('公积金(个人)', '-¥${housing.toStringAsFixed(2)}'),
                _r('个税', '-¥${tax.toStringAsFixed(2)}'),
                const Divider(height: 20),
                _r(
                  '实际到手',
                  '¥${net.toStringAsFixed(2)}',
                  big: true,
                  color: C.success,
                ),
                _r(
                  '到手比例',
                  '${(net / (g == 0 ? 1 : g) * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 19 : 15,
            fontWeight: FontWeight.w900,
            color: color ?? context.t1,
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ⑤ 瓷砖用量 ───────────────
class TilePage extends StatefulWidget {
  const TilePage({super.key});
  @override
  State<TilePage> createState() => _TilePageState();
}

class _TilePageState extends State<TilePage> {
  final _area = TextEditingController(text: '60');
  int _size = 0;
  static const _sizes = [
    (300, 300),
    (400, 400),
    (600, 600),
    (800, 800),
    (600, 1200),
    (750, 1500),
  ];

  @override
  void dispose() {
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = double.tryParse(_area.text) ?? 0;
    final (w, h) = _sizes[_size];
    final perTile = w * h / 1000000.0;
    final count = area / perTile;
    final withLoss = count * 1.08;
    return ToolScaffold(
      title: '瓷砖用量',
      subtitle: '按面积和规格算片数',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _area,
            label: '铺贴面积（㎡）',
            keyboard: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          ToolChips<int>(
            items: List.generate(
              _sizes.length,
              (i) => (i, '${_sizes[i].$1}×${_sizes[i].$2}'),
            ),
            current: _size,
            onPick: (v) => setState(() => _size = v),
          ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _r('单片面积', '${perTile.toStringAsFixed(3)} ㎡'),
                _r('理论用量', '${count.ceil()} 片'),
                const Divider(height: 20),
                _r('建议购买（含 8% 损耗）', '${withLoss.ceil()} 片', big: true),
                _r('约合箱数（按 4 片/箱）', '${(withLoss / 4).ceil()} 箱'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 18 : 14.5,
            fontWeight: FontWeight.w900,
            color: big ? C.brand : context.t1,
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ⑥ 涂料用量 ───────────────
class PaintPage extends StatefulWidget {
  const PaintPage({super.key});
  @override
  State<PaintPage> createState() => _PaintPageState();
}

class _PaintPageState extends State<PaintPage> {
  final _area = TextEditingController(text: '100');
  int _coats = 2;

  @override
  void dispose() {
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = double.tryParse(_area.text) ?? 0;
    // 1L 约涂 10 ㎡（一遍）
    final liters = area * _coats / 10;
    return ToolScaffold(
      title: '涂料用量',
      subtitle: '墙漆用量估算',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _area,
            label: '涂刷面积（㎡）',
            keyboard: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          ToolChips<int>(
            items: const [(1, '刷 1 遍'), (2, '刷 2 遍'), (3, '刷 3 遍')],
            current: _coats,
            onPick: (v) => setState(() => _coats = v),
          ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _r('需要涂料', '${liters.toStringAsFixed(1)} L', big: true),
                _r('约合（5L 装）', '${(liters / 5).ceil()} 桶'),
                _r('约合（15L 装）', '${(liters / 15).ceil()} 桶'),
                const Divider(height: 20),
                _r('底漆（1 遍）', '${(area / 10).toStringAsFixed(1)} L'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 18 : 14.5,
            fontWeight: FontWeight.w900,
            color: big ? C.brand : context.t1,
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ⑦ 油耗换算（每公里/百公里） ───────────────
class FuelConvPage extends StatefulWidget {
  const FuelConvPage({super.key});
  @override
  State<FuelConvPage> createState() => _FuelConvPageState();
}

class _FuelConvPageState extends State<FuelConvPage> {
  final _v = TextEditingController(text: '8');
  int _type = 0; // 0 L/100km → mpg  1 mpg → L/100km

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(_v.text) ?? 0;
    double a, b;
    if (_type == 0) {
      // L/100km → mpg(美) 与 mpg(英)
      a = v == 0 ? 0 : 235.214583 / v;
      b = v == 0 ? 0 : 282.480936 / v;
    } else {
      a = v == 0 ? 0 : 235.214583 / v;
      b = v == 0 ? 0 : 282.480936 / v;
    }
    return ToolScaffold(
      title: '油耗换算',
      subtitle: 'L/100km ↔ mpg',
      scrollable: true,
      child: Column(
        children: [
          ToolChips<int>(
            items: const [(0, 'L/100km → mpg'), (1, 'mpg → L/100km')],
            current: _type,
            onPick: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 12),
          ToolField(
            controller: _v,
            label: '数值',
            keyboard: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                _r('美制 mpg', a.toStringAsFixed(2)),
                _r('英制 mpg', b.toStringAsFixed(2)),
                _r('L/100km', (_type == 0 ? v : a).toStringAsFixed(2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: C.brand,
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ⑧ 进制时间（毫秒） ───────────────
class MsTimePage extends StatefulWidget {
  const MsTimePage({super.key});
  @override
  State<MsTimePage> createState() => _MsTimePageState();
}

class _MsTimePageState extends State<MsTimePage> {
  final _c = TextEditingController(text: '5000');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = double.tryParse(_c.text) ?? 0;
    final d = Duration(milliseconds: ms.round());
    String fmt(Duration x) {
      final parts = <String>[];
      if (x.inDays > 0) parts.add('${x.inDays}天');
      if (x.inHours % 24 > 0) parts.add('${x.inHours % 24}小时');
      if (x.inMinutes % 60 > 0) parts.add('${x.inMinutes % 60}分');
      if (x.inSeconds % 60 > 0) parts.add('${x.inSeconds % 60}秒');
      if (x.inMilliseconds % 1000 > 0)
        parts.add('${x.inMilliseconds % 1000}毫秒');
      return parts.isEmpty ? '0' : parts.join('');
    }

    return ToolScaffold(
      title: '时长换算',
      subtitle: '毫秒/秒/分/时/天',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '毫秒数',
            keyboard: TextInputType.number,
            icon: Icons.timer_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                _r('易读格式', fmt(d), big: true),
                const Divider(height: 20),
                _r('秒', (ms / 1000).toStringAsFixed(3)),
                _r('分钟', (ms / 60000).toStringAsFixed(4)),
                _r('小时', (ms / 3600000).toStringAsFixed(5)),
                _r('天', (ms / 86400000).toStringAsFixed(6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 18 : 14.5,
            fontWeight: FontWeight.w900,
            color: big ? C.brand : context.t1,
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ⑨ 数字单位（万/亿/万亿） ───────────────
class BigNumPage extends StatefulWidget {
  const BigNumPage({super.key});
  @override
  State<BigNumPage> createState() => _BigNumPageState();
}

class _BigNumPageState extends State<BigNumPage> {
  final _c = TextEditingController(text: '123456789');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static String _unit(double v) {
    final a = v.abs();
    if (a >= 1e12) return '${(v / 1e12).toStringAsFixed(2)} 万亿';
    if (a >= 1e8) return '${(v / 1e8).toStringAsFixed(2)} 亿';
    if (a >= 1e4) return '${(v / 1e4).toStringAsFixed(2)} 万';
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(_c.text) ?? 0;
    return ToolScaffold(
      title: '数字单位',
      subtitle: '数字 → 万 / 亿 简写',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '数字',
            keyboard: TextInputType.number,
            icon: Icons.numbers_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                Text('简写形式', style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 8),
                SelectableText(
                  _unit(v),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: C.brand,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _r('千', (v / 1e3).toStringAsFixed(2)),
                _r('万', (v / 1e4).toStringAsFixed(4)),
                _r('百万', (v / 1e6).toStringAsFixed(6)),
                _r('亿', (v / 1e8).toStringAsFixed(8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.t1,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ⑩ 小费/服务费 ───────────────
class TipPage extends StatefulWidget {
  const TipPage({super.key});
  @override
  State<TipPage> createState() => _TipPageState();
}

class _TipPageState extends State<TipPage> {
  final _amt = TextEditingController(text: '200');
  final _n = TextEditingController(text: '1');
  int _pct = 10;

  @override
  void dispose() {
    _amt.dispose();
    _n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = double.tryParse(_amt.text) ?? 0;
    final n = int.tryParse(_n.text) ?? 1;
    final tip = a * _pct / 100;
    final total = a + tip;
    return ToolScaffold(
      title: '小费计算',
      subtitle: '按比例算小费（国外旅行用）',

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ToolField(
                  controller: _amt,
                  label: '账单金额',
                  keyboard: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolField(
                  controller: _n,
                  label: '人数',
                  keyboard: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ToolChips<int>(
            items: const [
              (5, '5%'),
              (10, '10%'),
              (15, '15%'),
              (18, '18%'),
              (20, '20%'),
            ],
            current: _pct,
            onPick: (v) => setState(() => _pct = v),
          ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _r('小费（$_pct%）', '${tip.toStringAsFixed(2)}'),
                _r('总计', '${total.toStringAsFixed(2)}', big: true),
                if (n > 1) ...[
                  const Divider(height: 20),
                  _r(
                    '每人付',
                    '${(total / n).toStringAsFixed(2)}',
                    color: C.brand,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: big ? 19 : 15,
            fontWeight: FontWeight.w900,
            color: color ?? (big ? C.brand : context.t1),
          ),
        ),
      ],
    ),
  );
}
