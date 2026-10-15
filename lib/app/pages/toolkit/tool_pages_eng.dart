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
// 工具箱 · 第六批（1015）：工程估算 + 更多换算
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 装修面积/用量估算 ───────────────
class DecorPage extends StatefulWidget {
  const DecorPage({super.key});
  @override
  State<DecorPage> createState() => _DecorPageState();
}

class _DecorPageState extends State<DecorPage> {
  final _len = TextEditingController(text: '5');
  final _wid = TextEditingController(text: '4');
  final _hei = TextEditingController(text: '2.8');

  @override
  void dispose() {
    _len.dispose();
    _wid.dispose();
    _hei.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = double.tryParse(_len.text) ?? 0;
    final w = double.tryParse(_wid.text) ?? 0;
    final h = double.tryParse(_hei.text) ?? 0;
    final floor = l * w;
    final wall = 2 * (l + w) * h;
    final total = floor + wall;
    // 地砖（800x800mm，损耗 5%）
    final tiles = floor / 0.64 * 1.05;
    // 墙漆（1L 约 10㎡，两遍）
    final paint = wall * 2 / 10;
    return ToolScaffold(
      title: '装修估算',
      subtitle: '面积 / 瓷砖 / 涂料用量',
      
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ToolField(controller: _len, label: '长(m)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _wid, label: '宽(m)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _hei, label: '层高(m)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _r('地面面积', '${floor.toStringAsFixed(2)} ㎡'),
                _r('墙面面积', '${wall.toStringAsFixed(2)} ㎡'),
                _r('涂刷总面积', '${total.toStringAsFixed(2)} ㎡', big: true),
                const Divider(height: 20),
                _r('800×800 地砖', '${tiles.toStringAsFixed(0)} 块（含 5% 损耗）'),
                _r('墙面漆（2遍）', '${paint.toStringAsFixed(1)} L'),
                _r('踢脚线', '${(2 * (l + w)).toStringAsFixed(1)} m'),
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
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 17 : 14.5, fontWeight: FontWeight.w900, color: big ? C.brand : context.t1)),
          ],
        ),
      );
}

// ─────────────── ② 电费计算 ───────────────
class ElecPage extends StatefulWidget {
  const ElecPage({super.key});
  @override
  State<ElecPage> createState() => _ElecPageState();
}

class _ElecPageState extends State<ElecPage> {
  final _power = TextEditingController(text: '1500');
  final _hours = TextEditingController(text: '8');
  final _days = TextEditingController(text: '30');
  final _price = TextEditingController(text: '0.55');

  @override
  void dispose() {
    _power.dispose();
    _hours.dispose();
    _days.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = double.tryParse(_power.text) ?? 0;
    final h = double.tryParse(_hours.text) ?? 0;
    final d = double.tryParse(_days.text) ?? 0;
    final price = double.tryParse(_price.text) ?? 0;
    final kwhDay = p * h / 1000;
    final kwhTotal = kwhDay * d;
    final money = kwhTotal * price;
    return ToolScaffold(
      title: '电费计算',
      subtitle: '按功率和时长估算电费',
      
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ToolField(controller: _power, label: '功率(W)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _hours, label: '每天(h)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          Row(
            children: [
              Expanded(child: ToolField(controller: _days, label: '天数', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _price, label: '电价(元/度)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _r('每天耗电', '${kwhDay.toStringAsFixed(3)} 度'),
                _r('$d 天总耗电', '${kwhTotal.toStringAsFixed(2)} 度'),
                const Divider(height: 20),
                _r('预计电费', '¥${money.toStringAsFixed(2)}', big: true),
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
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 19 : 15, fontWeight: FontWeight.w900, color: big ? C.brand : context.t1)),
          ],
        ),
      );
}

// ─────────────── ③ 压力换算 ───────────────
class PressurePage extends StatelessWidget {
  const PressurePage({super.key});
  @override
  Widget build(BuildContext context) => const UnitPageGeneric(
        title: '压力换算',
        subtitle: '帕/巴/标准大气压/psi 等',
        units: [
          ('帕 Pa', 1.0),
          ('千帕 kPa', 1000.0),
          ('兆帕 MPa', 1000000.0),
          ('巴 bar', 100000.0),
          ('毫巴 mbar', 100.0),
          ('标准大气压 atm', 101325.0),
          ('psi', 6894.757293),
          ('毫米汞柱 mmHg', 133.322387),
          ('毫米水柱 mmH2O', 9.80665),
        ],
      );
}

// ─────────────── ④ 功率换算 ───────────────
class PowerPage extends StatelessWidget {
  const PowerPage({super.key});
  @override
  Widget build(BuildContext context) => const UnitPageGeneric(
        title: '功率换算',
        subtitle: '瓦/千瓦/马力 等',
        units: [
          ('瓦 W', 1.0),
          ('千瓦 kW', 1000.0),
          ('兆瓦 MW', 1000000.0),
          ('毫瓦 mW', 0.001),
          ('公制马力 PS', 735.49875),
          ('英制马力 hp', 745.699872),
          ('卡/秒 cal/s', 4.184),
          ('英热单位/时 BTU/h', 0.29307107),
        ],
      );
}

// ─────────────── ⑤ 能量换算 ───────────────
class EnergyPage extends StatelessWidget {
  const EnergyPage({super.key});
  @override
  Widget build(BuildContext context) => const UnitPageGeneric(
        title: '能量换算',
        subtitle: '焦耳/卡/千卡/千瓦时',
        units: [
          ('焦耳 J', 1.0),
          ('千焦 kJ', 1000.0),
          ('卡 cal', 4.184),
          ('千卡 kcal', 4184.0),
          ('瓦时 Wh', 3600.0),
          ('千瓦时 kWh', 3600000.0),
          ('电子伏 eV', 1.602176634e-19),
          ('英热单位 BTU', 1055.05585262),
        ],
      );
}

// ─────────────── ⑥ 角度换算 ───────────────
class AnglePage extends StatelessWidget {
  const AnglePage({super.key});
  @override
  Widget build(BuildContext context) => const UnitPageGeneric(
        title: '角度换算',
        subtitle: '度/弧度/梯度/角分',
        units: [
          ('度 °', 1.0),
          ('弧度 rad', 57.29577951308232),
          ('梯度 grad', 0.9),
          ('角分 ′', 0.016666666667),
          ('角秒 ″', 0.000277777778),
          ('转 turn', 360.0),
        ],
      );
}

// ─────────────── ⑦ 频率换算 ───────────────
class FreqPage extends StatelessWidget {
  const FreqPage({super.key});
  @override
  Widget build(BuildContext context) => const UnitPageGeneric(
        title: '频率换算',
        subtitle: '赫兹/千赫/兆赫/吉赫',
        units: [
          ('赫兹 Hz', 1.0),
          ('千赫 kHz', 1000.0),
          ('兆赫 MHz', 1000000.0),
          ('吉赫 GHz', 1000000000.0),
          ('每分钟次 rpm', 0.016666666667),
        ],
      );
}

// ─────────────── ⑧ 光照换算 ───────────────
class LightPage extends StatelessWidget {
  const LightPage({super.key});
  @override
  Widget build(BuildContext context) => const UnitPageGeneric(
        title: '光照换算',
        subtitle: '勒克斯/流明/英尺烛光',
        units: [
          ('勒克斯 lx', 1.0),
          ('英尺烛光 fc', 10.7639104),
          ('辐透 ph', 10000.0),
          ('诺克斯 nx', 0.001),
        ],
      );
}

/// 通用单位换算页（给定 (名称, 相对基准倍数) 列表）
class UnitPageGeneric extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<(String, double)> units;
  const UnitPageGeneric({
    super.key,
    required this.title,
    required this.subtitle,
    required this.units,
  });
  @override
  State<UnitPageGeneric> createState() => _UnitPageGenericState();
}

class _UnitPageGenericState extends State<UnitPageGeneric> {
  int _from = 0;
  int _to = 1;
  final _c = TextEditingController(text: '1');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _result {
    final v = double.tryParse(_c.text.trim()) ?? 0;
    return v * widget.units[_from].$2 / widget.units[_to].$2;
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    final a = v.abs();
    if (a >= 1e15 || a < 1e-6) return v.toStringAsExponential(6);
    var s = v.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      
      child: Column(
        children: [
          ToolCard(
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: _from,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(
                        widget.units.length,
                        (i) => DropdownMenuItem(
                              value: i,
                              child: Text(widget.units[i].$1, style: const TextStyle(fontSize: 13)),
                            )),
                    onChanged: (v) => setState(() => _from = v ?? 0),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 17, color: C.brand),
                Expanded(
                  child: DropdownButton<int>(
                    value: _to,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(
                        widget.units.length,
                        (i) => DropdownMenuItem(
                              value: i,
                              child: Text(widget.units[i].$1, style: const TextStyle(fontSize: 13)),
                            )),
                    onChanged: (v) => setState(() => _to = v ?? 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolField(
            controller: _c,
            label: '数值',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                Text('换算结果', style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 8),
                SelectableText(_fmt(_result),
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: C.brand)),
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
                      Text('复制', style: Ty.tiny.copyWith(color: context.t3)),
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

// ─────────────── ⑨ 日期间隔（工作日） ───────────────
class WorkdayPage extends StatefulWidget {
  const WorkdayPage({super.key});
  @override
  State<WorkdayPage> createState() => _WorkdayPageState();
}

class _WorkdayPageState extends State<WorkdayPage> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    var work = 0, weekend = 0;
    var d = DateTime(_from.year, _from.month, _from.day);
    final end = DateTime(_to.year, _to.month, _to.day);
    while (!d.isAfter(end)) {
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        weekend++;
      } else {
        work++;
      }
      d = d.add(const Duration(days: 1));
    }
    return ToolScaffold(
      title: '工作日计算',
      subtitle: '两个日期之间的工作日/周末天数',
      scrollable: true,
      child: Column(
        children: [
          _pick('开始', _from, (v) => setState(() => _from = v)),
          const SizedBox(height: 10),
          _pick('结束', _to, (v) => setState(() => _to = v)),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _r('工作日', '$work 天', C.brand),
                _r('周末', '$weekend 天', C.warning),
                _r('总天数', '${work + weekend} 天'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('注：仅按周六日区分，不含法定节假日调休', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  Widget _pick(String label, DateTime d, ValueChanged<DateTime> on) => ToolCard(
        onTap: () async {
          final r = await showDatePicker(
            context: context,
            initialDate: d,
            firstDate: DateTime(1970),
            lastDate: DateTime(2100),
            helpText: label,
          );
          if (r != null) on(r);
        },
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 19, color: C.brand),
            const SizedBox(width: 10),
            Text(label, style: Ty.small.copyWith(color: context.t3)),
            const Spacer(),
            Text('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
          ],
        ),
      );

  Widget _r(String k, String v, [Color? c]) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c ?? context.t1)),
          ],
        ),
      );
}

// ─────────────── ⑩ 数字大写（人民币） ───────────────
class NumCnPage extends StatefulWidget {
  const NumCnPage({super.key});
  @override
  State<NumCnPage> createState() => _NumCnPageState();
}

class _NumCnPageState extends State<NumCnPage> {
  final _c = TextEditingController(text: '1234');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _d = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  static const _u = ['', '十', '百', '千'];

  static String conv(int n) {
    if (n == 0) return '零';
    final s = n.toString();
    final sb = StringBuffer();
    final len = s.length;
    var zero = false;
    for (var i = 0; i < len; i++) {
      final digit = int.parse(s[i]);
      final unit = _u[(len - 1 - i) % 4];
      if (digit == 0) {
        zero = true;
      } else {
        if (zero && sb.isNotEmpty) sb.write('零');
        zero = false;
        sb.write(_d[digit] + unit);
      }
      // 万/亿单位
      final pos = len - i - 1;
      if (pos == 4) sb.write('万');
      if (pos == 8) sb.write('亿');
    }
    var out = sb.toString();
    if (out.startsWith('一十')) out = out.substring(1);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(_c.text.trim()) ?? 0;
    return ToolScaffold(
      title: '数字转中文',
      subtitle: '阿拉伯数字 → 中文读法',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '数字',
            keyboard: TextInputType.number,
            icon: Icons.translate_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                Text('中文读法', style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 8),
                SelectableText(conv(n),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.brand)),
                const SizedBox(height: 10),
                AppPressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: conv(n)));
                    ToastUtil.success('已复制');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 15, color: context.t3),
                      const SizedBox(width: 4),
                      Text('复制', style: Ty.tiny.copyWith(color: context.t3)),
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
