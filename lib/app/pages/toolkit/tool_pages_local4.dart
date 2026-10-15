import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_kit.dart';

// ═══════════════════════════════════════════════════════════════
// 工具箱 · 第三批（1015）：单位换算全集 + 常用计算
//   全部纯本地，零依赖，永不失效
// ═══════════════════════════════════════════════════════════════

/// 通用「单位换算」骨架：给定单位表 + 基准，就能出一批换算工具
class _UnitDef {
  final String name;
  final double factor; // 相对于基准单位的倍数
  const _UnitDef(this.name, this.factor);
}

class _UnitConvPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<_UnitDef> units;
  final int defaultFrom;
  final int defaultTo;
  const _UnitConvPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.units,
    this.defaultFrom = 0,
    this.defaultTo = 1,
  });
  @override
  State<_UnitConvPage> createState() => _UnitConvPageState();
}

class _UnitConvPageState extends State<_UnitConvPage> {
  late int _from = widget.defaultFrom;
  late int _to = widget.defaultTo;
  final _ctrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _result {
    final v = double.tryParse(_ctrl.text.trim()) ?? 0;
    return v * widget.units[_from].factor / widget.units[_to].factor;
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    final a = v.abs();
    if (a >= 1e15 || (a < 1e-6)) return v.toStringAsExponential(6);
    var s = v.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      scrollable: true,
      child: Column(
        children: [
          ToolCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('从', style: Ty.tiny.copyWith(color: context.t3)),
                      const SizedBox(height: 4),
                      DropdownButton<int>(
                        value: _from,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: List.generate(widget.units.length, (i) => DropdownMenuItem(
                              value: i,
                              child: Text(widget.units[i].name, style: const TextStyle(fontSize: 13.5)),
                            )),
                        onChanged: (v) => setState(() => _from = v ?? 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 18, color: C.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('到', style: Ty.tiny.copyWith(color: context.t3)),
                      const SizedBox(height: 4),
                      DropdownButton<int>(
                        value: _to,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: List.generate(widget.units.length, (i) => DropdownMenuItem(
                              value: i,
                              child: Text(widget.units[i].name, style: const TextStyle(fontSize: 13.5)),
                            )),
                        onChanged: (v) => setState(() => _to = v ?? 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolField(
            controller: _ctrl,
            label: '数值',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.tag_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                Text('换算结果', style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 8),
                SelectableText(
                  _fmt(_result),
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: C.brand),
                ),
                const SizedBox(height: 6),
                Text('${widget.units[_from].name} → ${widget.units[_to].name}',
                    style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 10),
                AppPressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _fmt(_result)));
                    ToastUtil.success('已复制');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 15, color: context.t3),
                      const SizedBox(width: 4),
                      Text('复制结果', style: Ty.tiny.copyWith(color: context.t3)),
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

// ─────────────── 长度换算 ───────────────
class LengthPage extends StatelessWidget {
  const LengthPage({super.key});
  @override
  Widget build(BuildContext context) => const _UnitConvPage(
        title: '长度换算',
        subtitle: '米/厘米/英寸/英尺/里/海里 等',
        units: [
          _UnitDef('千米 km', 1000),
          _UnitDef('米 m', 1),
          _UnitDef('分米 dm', 0.1),
          _UnitDef('厘米 cm', 0.01),
          _UnitDef('毫米 mm', 0.001),
          _UnitDef('微米 μm', 1e-6),
          _UnitDef('英寸 in', 0.0254),
          _UnitDef('英尺 ft', 0.3048),
          _UnitDef('码 yd', 0.9144),
          _UnitDef('英里 mi', 1609.344),
          _UnitDef('里', 500),
          _UnitDef('海里 nmi', 1852),
          _UnitDef('光年 ly', 9.4607e15),
        ],
      );
}

// ─────────────── 重量换算 ───────────────
class WeightPage extends StatelessWidget {
  const WeightPage({super.key});
  @override
  Widget build(BuildContext context) => const _UnitConvPage(
        title: '重量换算',
        subtitle: '克/千克/斤/两/磅/盎司 等',
        units: [
          _UnitDef('吨 t', 1000000),
          _UnitDef('千克 kg', 1000),
          _UnitDef('克 g', 1),
          _UnitDef('毫克 mg', 0.001),
          _UnitDef('斤', 500),
          _UnitDef('两', 50),
          _UnitDef('钱', 5),
          _UnitDef('磅 lb', 453.59237),
          _UnitDef('盎司 oz', 28.349523125),
          _UnitDef('克拉 ct', 0.2),
        ],
      );
}

// ─────────────── 面积换算 ───────────────
class AreaPage extends StatelessWidget {
  const AreaPage({super.key});
  @override
  Widget build(BuildContext context) => const _UnitConvPage(
        title: '面积换算',
        subtitle: '平方米/亩/平方英尺/英亩 等',
        units: [
          _UnitDef('平方千米 km²', 1000000),
          _UnitDef('公顷 ha', 10000),
          _UnitDef('亩', 666.6666667),
          _UnitDef('平方米 m²', 1),
          _UnitDef('平方分米 dm²', 0.01),
          _UnitDef('平方厘米 cm²', 0.0001),
          _UnitDef('平方英尺 ft²', 0.09290304),
          _UnitDef('平方英寸 in²', 0.00064516),
          _UnitDef('英亩 acre', 4046.8564224),
          _UnitDef('平方英里 mi²', 2589988.110336),
        ],
      );
}

// ─────────────── 体积/容积换算 ───────────────
class VolumePage extends StatelessWidget {
  const VolumePage({super.key});
  @override
  Widget build(BuildContext context) => const _UnitConvPage(
        title: '体积换算',
        subtitle: '升/毫升/立方米/加仑 等',
        units: [
          _UnitDef('立方米 m³', 1000),
          _UnitDef('升 L', 1),
          _UnitDef('分升 dL', 0.1),
          _UnitDef('毫升 mL', 0.001),
          _UnitDef('立方厘米 cm³', 0.001),
          _UnitDef('加仑(美) gal', 3.785411784),
          _UnitDef('加仑(英) gal', 4.54609),
          _UnitDef('夸脱 qt', 0.946352946),
          _UnitDef('品脱 pt', 0.473176473),
          _UnitDef('液量盎司(美) fl oz', 0.0295735296),
        ],
      );
}

// ─────────────── 速度换算 ───────────────
class SpeedPage extends StatelessWidget {
  const SpeedPage({super.key});
  @override
  Widget build(BuildContext context) => const _UnitConvPage(
        title: '速度换算',
        subtitle: '米每秒/千米每小时/节 等',
        units: [
          _UnitDef('米/秒 m/s', 1),
          _UnitDef('千米/小时 km/h', 0.277777778),
          _UnitDef('英里/小时 mph', 0.44704),
          _UnitDef('英尺/秒 ft/s', 0.3048),
          _UnitDef('节 kn', 0.514444444),
          _UnitDef('马赫 Mach', 340.29),
          _UnitDef('光速 c', 299792458),
        ],
      );
}

// ─────────────── 存储换算 ───────────────
class DataPage extends StatelessWidget {
  const DataPage({super.key});
  @override
  Widget build(BuildContext context) => const _UnitConvPage(
        title: '存储换算',
        subtitle: 'B/KB/MB/GB/TB',
        units: [
          _UnitDef('Bit 位', 0.125),
          _UnitDef('Byte 字节 B', 1),
          _UnitDef('KB', 1024),
          _UnitDef('MB', 1048576),
          _UnitDef('GB', 1073741824),
          _UnitDef('TB', 1099511627776),
          _UnitDef('PB', 1125899906842624),
        ],
      );
}

// ─────────────── 时间换算 ───────────────
class TimeUnitPage extends StatelessWidget {
  const TimeUnitPage({super.key});
  @override
  Widget build(BuildContext context) => const _UnitConvPage(
        title: '时间换算',
        subtitle: '秒/分/时/天/周/年',
        units: [
          _UnitDef('毫秒 ms', 0.001),
          _UnitDef('秒 s', 1),
          _UnitDef('分钟 min', 60),
          _UnitDef('小时 h', 3600),
          _UnitDef('天 d', 86400),
          _UnitDef('周 w', 604800),
          _UnitDef('月(30天)', 2592000),
          _UnitDef('年(365天)', 31536000),
        ],
      );
}

// ─────────────── 温度换算 ───────────────
class TempPage extends StatefulWidget {
  const TempPage({super.key});
  @override
  State<TempPage> createState() => _TempPageState();
}

class _TempPageState extends State<TempPage> {
  final _c = TextEditingController(text: '25');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = double.tryParse(_c.text.trim()) ?? 0;
    final f = c * 9 / 5 + 32;
    final k = c + 273.15;
    return ToolScaffold(
      title: '温度换算',
      subtitle: '摄氏度 / 华氏度 / 开尔文',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '摄氏度 ℃',
            keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
            icon: Icons.thermostat_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                _row('华氏度 ℉', '${f.toStringAsFixed(2)} °F'),
                _row('开尔文 K', '${k.toStringAsFixed(2)} K'),
                const Divider(height: 20),
                _row('水的冰点', '0 ℃ = 32 ℉'),
                _row('人体常温', '37 ℃ = 98.6 ℉'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: C.brand)),
          ],
        ),
      );
}

// ─────────────── 个税计算 ───────────────
class TaxPage extends StatefulWidget {
  const TaxPage({super.key});
  @override
  State<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends State<TaxPage> {
  final _salary = TextEditingController(text: '15000');
  final _social = TextEditingController(text: '2000');
  final _special = TextEditingController(text: '0');

  @override
  void dispose() {
    _salary.dispose();
    _social.dispose();
    _special.dispose();
    super.dispose();
  }

  // 2019 起综合所得税率表（年度累计，这里按月速算）
  static const _brackets = [
    (3000.0, 0.03, 0.0),
    (12000.0, 0.10, 210.0),
    (25000.0, 0.20, 1410.0),
    (35000.0, 0.25, 2660.0),
    (55000.0, 0.30, 4410.0),
    (80000.0, 0.35, 7160.0),
    (double.infinity, 0.45, 15160.0),
  ];

  @override
  Widget build(BuildContext context) {
    final salary = double.tryParse(_salary.text) ?? 0;
    final social = double.tryParse(_social.text) ?? 0;
    final special = double.tryParse(_special.text) ?? 0;
    final taxable = math.max(0.0, salary - social - special - 5000);
    double tax = 0;
    for (final (cap, rate, deduct) in _brackets) {
      if (taxable <= cap) {
        tax = taxable * rate - deduct;
        break;
      }
    }
    if (tax < 0) tax = 0;
    final net = salary - social - tax;
    return ToolScaffold(
      title: '个税计算',
      subtitle: '工资个税（含起征点与专项扣除）',
      scrollable: true,
      child: Column(
        children: [
          ToolField(controller: _salary, label: '税前工资（元）', keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
          Row(
            children: [
              Expanded(child: ToolField(controller: _social, label: '五险一金（元）', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ToolField(controller: _special, label: '专项附加扣除', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _row('应纳税所得额', '¥${taxable.toStringAsFixed(2)}'),
                _row('应缴个税', '¥${tax.toStringAsFixed(2)}', color: C.danger),
                const Divider(height: 20),
                _row('到手工资', '¥${net.toStringAsFixed(2)}', color: C.success, big: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('说明', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  '· 起征点 5000 元/月\n'
                  '· 按月度速算表估算，实际以单位代扣为准\n'
                  '· 年度汇算清缴可能多退少补',
                  style: Ty.tiny.copyWith(color: context.t3, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {Color? color, bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 19 : 15.5, fontWeight: FontWeight.w900, color: color ?? context.t1)),
          ],
        ),
      );
}

// ─────────────── 房贷计算 ───────────────
class MortgagePage extends StatefulWidget {
  const MortgagePage({super.key});
  @override
  State<MortgagePage> createState() => _MortgagePageState();
}

class _MortgagePageState extends State<MortgagePage> {
  final _amount = TextEditingController(text: '1000000');
  final _years = TextEditingController(text: '30');
  final _rate = TextEditingController(text: '3.5');
  int _type = 0; // 0 等额本息 1 等额本金

  @override
  void dispose() {
    _amount.dispose();
    _years.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = double.tryParse(_amount.text) ?? 0;
    final y = double.tryParse(_years.text) ?? 30;
    final r = (double.tryParse(_rate.text) ?? 3.5) / 100;
    final n = y * 12;
    final mr = r / 12;
    double monthly, total, firstM, lastM;
    if (_type == 0) {
      monthly = mr == 0 ? p / n : p * mr * math.pow(1 + mr, n) / (math.pow(1 + mr, n) - 1);
      total = monthly * n;
      firstM = monthly;
      lastM = monthly;
    } else {
      final principal = p / n;
      firstM = principal + p * mr;
      lastM = principal + principal * mr;
      monthly = firstM;
      total = p * mr * (n + 1) / 2 + p;
    }
    final interest = total - p;
    return ToolScaffold(
      title: '房贷计算',
      subtitle: '等额本息 / 等额本金',
      scrollable: true,
      child: Column(
        children: [
          ToolChips<int>(
            items: const [(0, '等额本息'), (1, '等额本金')],
            current: _type,
            onPick: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 12),
          ToolField(controller: _amount, label: '贷款金额（元）', keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
          Row(
            children: [
              Expanded(child: ToolField(controller: _years, label: '年限（年）', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ToolField(controller: _rate, label: '年利率（%）', keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
              ),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _row(_type == 0 ? '每月月供' : '首月月供', '¥${monthly.toStringAsFixed(2)}', big: true, color: C.brand),
                if (_type == 1) _row('末月月供（递减）', '¥${lastM.toStringAsFixed(2)}'),
                const Divider(height: 20),
                _row('支付利息总额', '¥${interest.toStringAsFixed(2)}', color: C.danger),
                _row('还款总额', '¥${total.toStringAsFixed(2)}'),
                _row('还款月数', '${n.toInt()} 期'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {Color? color, bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 19 : 15.5, fontWeight: FontWeight.w900, color: color ?? context.t1)),
          ],
        ),
      );
}

// ─────────────── 存款利息 ───────────────
class InterestPage extends StatefulWidget {
  const InterestPage({super.key});
  @override
  State<InterestPage> createState() => _InterestPageState();
}

class _InterestPageState extends State<InterestPage> {
  final _p = TextEditingController(text: '100000');
  final _r = TextEditingController(text: '2.5');
  final _y = TextEditingController(text: '3');
  int _mode = 1; // 0 单利 1 复利

  @override
  void dispose() {
    _p.dispose();
    _r.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = double.tryParse(_p.text) ?? 0;
    final r = (double.tryParse(_r.text) ?? 0) / 100;
    final y = double.tryParse(_y.text) ?? 0;
    final total = _mode == 1 ? p * math.pow(1 + r, y) : p * (1 + r * y);
    final interest = total - p;
    return ToolScaffold(
      title: '存款利息',
      subtitle: '单利 / 复利 收益计算',
      scrollable: true,
      child: Column(
        children: [
          ToolChips<int>(
            items: const [(0, '单利'), (1, '复利')],
            current: _mode,
            onPick: (v) => setState(() => _mode = v),
          ),
          const SizedBox(height: 12),
          ToolField(controller: _p, label: '本金（元）', keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
          Row(
            children: [
              Expanded(child: ToolField(controller: _r, label: '年利率（%）', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ToolField(controller: _y, label: '年限（年）', keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
              ),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _row('利息收益', '¥${interest.toStringAsFixed(2)}', color: C.success),
                const Divider(height: 20),
                _row('本息合计', '¥${total.toStringAsFixed(2)}', big: true, color: C.brand),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {Color? color, bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 19 : 15.5, fontWeight: FontWeight.w900, color: color ?? context.t1)),
          ],
        ),
      );
}

// ─────────────── 年龄计算 ───────────────
class AgePage extends StatefulWidget {
  const AgePage({super.key});
  @override
  State<AgePage> createState() => _AgePageState();
}

class _AgePageState extends State<AgePage> {
  DateTime _birth = DateTime(1995, 6, 15);

  static const _zodiac = ['鼠', '牛', '虎', '兔', '龙', '蛇', '马', '羊', '猴', '鸡', '狗', '猪'];
  static const _signs = [
    (1, 20, '水瓶'), (2, 19, '双鱼'), (3, 21, '白羊'), (4, 20, '金牛'),
    (5, 21, '双子'), (6, 22, '巨蟹'), (7, 23, '狮子'), (8, 23, '处女'),
    (9, 23, '天秤'), (10, 24, '天蝎'), (11, 23, '射手'), (12, 22, '摩羯'),
  ];

  String get _sign {
    for (final (m, d, s) in _signs) {
      if (_birth.month == m) {
        return _birth.day < d ? s : _signs[(m) % 12].$3;
      }
    }
    return '摩羯';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    var age = now.year - _birth.year;
    if (now.month < _birth.month || (now.month == _birth.month && now.day < _birth.day)) age--;
    final days = now.difference(_birth).inDays;
    final nextBirth = DateTime(now.year, _birth.month, _birth.day);
    final target = nextBirth.isBefore(DateTime(now.year, now.month, now.day))
        ? DateTime(now.year + 1, _birth.month, _birth.day)
        : nextBirth;
    final toNext = target.difference(DateTime(now.year, now.month, now.day)).inDays;
    return ToolScaffold(
      title: '年龄计算',
      subtitle: '精确周岁 / 生肖 / 星座',
      scrollable: true,
      child: Column(
        children: [
          ToolCard(
            onTap: () async {
              final r = await showDatePicker(
                context: context,
                initialDate: _birth,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                helpText: '选择出生日期',
              );
              if (r != null) setState(() => _birth = r);
            },
            child: Row(
              children: [
                Icon(Icons.cake_rounded, size: 19, color: C.brand),
                const SizedBox(width: 10),
                Text('出生日期', style: Ty.small.copyWith(color: context.t3)),
                const Spacer(),
                Text('${_birth.year}-${_birth.month.toString().padLeft(2, '0')}-${_birth.day.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: Deco.brandGradient,
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              children: [
                const Text('周岁', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('$age', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                const SizedBox(height: 4),
                const Text('岁', style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              children: [
                _row('生肖', _zodiac[(_birth.year - 4) % 12]),
                _row('星座', _sign),
                _row('出生天数', '$days 天'),
                _row('距下次生日', toNext == 0 ? '就是今天 🎂' : '$toNext 天'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: context.t1)),
          ],
        ),
      );
}
