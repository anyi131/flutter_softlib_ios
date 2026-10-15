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
// 工具箱 · 生活实用类（1015 新增第二批）
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 热量计算（BMR / TDEE） ───────────────
class BmrPage extends StatefulWidget {
  const BmrPage({super.key});
  @override
  State<BmrPage> createState() => _BmrPageState();
}

class _BmrPageState extends State<BmrPage> {
  final _h = TextEditingController(text: '170');
  final _w = TextEditingController(text: '65');
  final _a = TextEditingController(text: '30');
  bool _male = true;
  int _act = 1;

  static const _acts = ['久坐', '轻度活动', '中度活动', '高强度', '极高强度'];
  static const _mult = [1.2, 1.375, 1.55, 1.725, 1.9];

  @override
  void dispose() {
    _h.dispose();
    _w.dispose();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = double.tryParse(_h.text) ?? 170;
    final w = double.tryParse(_w.text) ?? 65;
    final a = double.tryParse(_a.text) ?? 30;
    // Mifflin-St Jeor
    final bmr = _male ? 10 * w + 6.25 * h - 5 * a + 5 : 10 * w + 6.25 * h - 5 * a - 161;
    final tdee = bmr * _mult[_act];
    return ToolScaffold(
      title: '热量计算',
      subtitle: '基础代谢 BMR / 每日消耗 TDEE',
      
      child: Column(
        children: [
          ToolChips<bool>(
            items: const [(true, '男'), (false, '女')],
            current: _male,
            onPick: (v) => setState(() => _male = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ToolField(controller: _h, label: '身高(cm)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _w, label: '体重(kg)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _a, label: '年龄', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolChips<int>(
            items: List.generate(5, (i) => (i, _acts[i])),
            current: _act,
            onPick: (v) => setState(() => _act = v),
          ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _row('基础代谢 BMR', '${bmr.toStringAsFixed(0)} kcal'),
                _row('每日消耗 TDEE', '${tdee.toStringAsFixed(0)} kcal', big: true),
                const Divider(height: 20),
                _row('减脂建议', '${(tdee - 500).toStringAsFixed(0)} kcal'),
                _row('增肌建议', '${(tdee + 300).toStringAsFixed(0)} kcal'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 19 : 15.5, fontWeight: FontWeight.w900, color: big ? C.brand : context.t1)),
          ],
        ),
      );
}

// ─────────────── ② 睡眠计算 ───────────────
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});
  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  TimeOfDay _t = const TimeOfDay(hour: 23, minute: 0);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, _t.hour, _t.minute);
    return ToolScaffold(
      title: '睡眠计算',
      subtitle: '按 90 分钟睡眠周期推算起床时间',
      
      child: Column(
        children: [
          ToolCard(
            onTap: () async {
              final r = await showTimePicker(context: context, initialTime: _t);
              if (r != null) setState(() => _t = r);
            },
            child: Row(
              children: [
                Icon(Icons.bedtime_rounded, size: 19, color: C.brand),
                const SizedBox(width: 10),
                Text('入睡时间', style: Ty.small.copyWith(color: context.t3)),
                const Spacer(),
                Text('${_t.hour.toString().padLeft(2, '0')}:${_t.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.brand)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('建议起床时间（含 15 分钟入睡）', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...[3, 4, 5, 6].map((n) {
                  final t = base.add(Duration(minutes: n * 90 + 15));
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text('$n 个周期（${(n * 1.5).toStringAsFixed(1)} 小时）', style: Ty.small.copyWith(color: context.t3))),
                        Text('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.t1)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── ③ 身份证解析 ───────────────
class IdCardPage extends StatefulWidget {
  const IdCardPage({super.key});
  @override
  State<IdCardPage> createState() => _IdCardPageState();
}

class _IdCardPageState extends State<IdCardPage> {
  final _in = TextEditingController();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  static const _provinces = {
    '11': '北京', '12': '天津', '13': '河北', '14': '山西', '15': '内蒙古',
    '21': '辽宁', '22': '吉林', '23': '黑龙江', '31': '上海', '32': '江苏',
    '33': '浙江', '34': '安徽', '35': '福建', '36': '江西', '37': '山东',
    '41': '河南', '42': '湖北', '43': '湖南', '44': '广东', '45': '广西',
    '46': '海南', '50': '重庆', '51': '四川', '52': '贵州', '53': '云南',
    '54': '西藏', '61': '陕西', '62': '甘肃', '63': '青海', '64': '宁夏',
    '65': '新疆', '71': '台湾', '81': '香港', '82': '澳门',
  };

  @override
  Widget build(BuildContext context) {
    final s = _in.text.trim().toUpperCase();
    final valid = RegExp(r'^\d{17}[\dX]$').hasMatch(s);
    String area = '', birth = '', sex = '', age = '';
    if (valid) {
      area = _provinces[s.substring(0, 2)] ?? '未知地区';
      birth = '${s.substring(6, 10)}-${s.substring(10, 12)}-${s.substring(12, 14)}';
      sex = (int.parse(s[16]) % 2 == 1) ? '男' : '女';
      try {
        final b = DateTime(int.parse(s.substring(6, 10)), int.parse(s.substring(10, 12)), int.parse(s.substring(12, 14)));
        final n = DateTime.now();
        var a = n.year - b.year;
        if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
        age = '$a 岁';
      } catch (_) {}
    }
    return ToolScaffold(
      title: '身份证解析',
      subtitle: '本地解析籍贯 / 生日 / 性别（不上传）',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _in,
            label: '身份证号（18 位）',
            hint: '输入后自动解析',
            icon: Icons.badge_rounded,
            onChanged: (_) => setState(() {}),
          ),
          if (s.isNotEmpty)
            ToolCard(
              child: valid
                  ? Column(
                      children: [
                        _row('归属地', area),
                        _row('出生日期', birth),
                        _row('性别', sex),
                        _row('年龄', age),
                        _row('校验位', s.substring(17), ok: true),
                      ],
                    )
                  : Text('格式不正确（应为 18 位，最后一位可为 X）', style: Ty.small.copyWith(color: C.danger)),
            ),
          const SizedBox(height: 12),
          Text('说明：仅在本机按国标规则解析，不会上传任何信息。', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool ok = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ok ? C.success : context.t1)),
          ],
        ),
      );
}

// ─────────────── ④ AA 分摊 / 小费 ───────────────
class SplitPage extends StatefulWidget {
  const SplitPage({super.key});
  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  final _total = TextEditingController(text: '300');
  final _n = TextEditingController(text: '4');
  final _tip = TextEditingController(text: '0');

  @override
  void dispose() {
    _total.dispose();
    _n.dispose();
    _tip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = double.tryParse(_total.text) ?? 0;
    final n = int.tryParse(_n.text) ?? 1;
    final tip = double.tryParse(_tip.text) ?? 0;
    final grand = t * (1 + tip / 100);
    final per = n > 0 ? grand / n : 0;
    return ToolScaffold(
      title: 'AA 分摊',
      subtitle: '总价 / 人数 / 小费 → 每人多少',
      
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ToolField(controller: _total, label: '总金额(元)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _n, label: '人数', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _tip, label: '小费(%)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _row('含小费总额', '¥${grand.toStringAsFixed(2)}'),
                _row('每人应付', '¥${per.toStringAsFixed(2)}', big: true),
                const Divider(height: 20),
                _row('一分不给小费', '¥${(t / (n == 0 ? 1 : n)).toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 20 : 15.5, fontWeight: FontWeight.w900, color: big ? C.brand : context.t1)),
          ],
        ),
      );
}

// ─────────────── ⑤ 金额大写转换 ───────────────
class MoneyPage extends StatefulWidget {
  const MoneyPage({super.key});
  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  final _in = TextEditingController(text: '12345.67');

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  static const _d = ['零', '壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖'];
  static const _u = ['', '拾', '佰', '仟'];
  static const _s = ['', '万', '亿', '万亿'];

  static String convert(double n) {
    if (n == 0) return '零元整';
    final neg = n < 0;
    n = n.abs();
    final intPart = n.floor();
    final cents = ((n - intPart) * 100).round();
    final sb = StringBuffer();
    if (intPart == 0) {
      sb.write('零');
    } else {
      final str = intPart.toString();
      final groups = <String>[];
      for (var i = str.length; i > 0; i -= 4) {
        groups.insert(0, str.substring(i - 4 < 0 ? 0 : i - 4, i));
      }
      for (var g = 0; g < groups.length; g++) {
        final seg = groups[g];
        final secIdx = groups.length - 1 - g;
        var zero = false;
        final tmp = StringBuffer();
        for (var i = 0; i < seg.length; i++) {
          final digit = int.parse(seg[i]);
          final unit = _u[seg.length - 1 - i];
          if (digit == 0) {
            zero = true;
          } else {
            if (zero && tmp.isNotEmpty) tmp.write('零');
            zero = false;
            tmp.write(_d[digit] + unit);
          }
        }
        if (tmp.isNotEmpty) sb.write(tmp.toString() + _s[secIdx]);
      }
    }
    var out = (neg ? '负' : '') + sb.toString() + '元';
    if (cents == 0) {
      out += '整';
    } else {
      final j = cents ~/ 10, f = cents % 10;
      if (j > 0) out += '${_d[j]}角';
      if (f > 0) out += '${_d[f]}分';
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(_in.text.trim()) ?? 0;
    return ToolScaffold(
      title: '金额大写',
      subtitle: '数字金额 → 中文大写（报销/合同）',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _in,
            label: '金额（元）',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.attach_money_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('大写金额', style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 8),
                SelectableText(convert(v),
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: C.brand, height: 1.5)),
                const SizedBox(height: 10),
                AppPressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: convert(v)));
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
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('千分位格式', style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 6),
                SelectableText(_withComma(v),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.t1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _withComma(double v) {
    final s = v.toStringAsFixed(2).split('.');
    final intPart = s[0];
    final sb = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) sb.write(',');
      sb.write(intPart[i]);
    }
    return sb.toString() + '.' + s[1];
  }
}

// ─────────────── ⑥ 倒数日 / 纪念日 ───────────────
class DayCountPage extends StatefulWidget {
  const DayCountPage({super.key});
  @override
  State<DayCountPage> createState() => _DayCountPageState();
}

class _DayCountPageState extends State<DayCountPage> {
  DateTime _target = DateTime.now().add(const Duration(days: 100));
  final _name = TextEditingController(text: '目标日');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(_target.year, _target.month, _target.day);
    final diff = t.difference(today).inDays;
    return ToolScaffold(
      title: '倒数日',
      subtitle: '距离目标日还有多少天',
      scrollable: true,
      child: Column(
        children: [
          ToolField(controller: _name, label: '事件名称', icon: Icons.event_note_rounded),
          ToolCard(
            onTap: () async {
              final r = await showDatePicker(
                context: context,
                initialDate: _target,
                firstDate: DateTime(1970),
                lastDate: DateTime(2100),
              );
              if (r != null) setState(() => _target = r);
            },
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 19, color: C.brand),
                const SizedBox(width: 10),
                Text('目标日期', style: Ty.small.copyWith(color: context.t3)),
                const Spacer(),
                Text('${_target.year}-${_target.month.toString().padLeft(2, '0')}-${_target.day.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26),
            decoration: BoxDecoration(
              gradient: Deco.brandGradient,
              borderRadius: BorderRadius.circular(R.lg),
              boxShadow: [BoxShadow(color: C.brand.withAlpha(80), blurRadius: 22, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                Text(_name.text.isEmpty ? '目标日' : _name.text,
                    style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  diff == 0 ? '就是今天' : (diff > 0 ? '$diff' : '${-diff}'),
                  style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
                ),
                const SizedBox(height: 4),
                Text(diff == 0 ? '' : (diff > 0 ? '天后' : '天前'),
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── ⑦ 罗马数字转换 ───────────────
class RomanPage extends StatefulWidget {
  const RomanPage({super.key});
  @override
  State<RomanPage> createState() => _RomanPageState();
}

class _RomanPageState extends State<RomanPage> {
  final _in = TextEditingController(text: '2026');

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  static const _m = [
    (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'),
    (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I'),
  ];

  static String toRoman(int n) {
    if (n <= 0 || n > 3999) return '—';
    final sb = StringBuffer();
    for (final (v, s) in _m) {
      while (n >= v) {
        sb.write(s);
        n -= v;
      }
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(_in.text.trim()) ?? 0;
    return ToolScaffold(
      title: '罗马数字',
      subtitle: '阿拉伯数字 ↔ 罗马数字（1-3999）',
      
      child: Column(
        children: [
          ToolField(
            controller: _in,
            label: '数字（1-3999）',
            keyboard: TextInputType.number,
            icon: Icons.pin_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                Text('罗马数字', style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 8),
                SelectableText(toRoman(n),
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: C.brand, letterSpacing: 2)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('常用对照', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...[1, 5, 10, 50, 100, 500, 1000].map((v) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text('$v', style: Ty.tiny.copyWith(color: context.t3))),
                          Text(toRoman(v), style: Ty.tiny.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── ⑧ 尺码换算 ───────────────
class SizePage extends StatefulWidget {
  const SizePage({super.key});
  @override
  State<SizePage> createState() => _SizePageState();
}

class _SizePageState extends State<SizePage> {
  final _cm = TextEditingController(text: '25');
  bool _shoe = true;

  @override
  void dispose() {
    _cm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cm = double.tryParse(_cm.text) ?? 0;
    // 通用近似公式：中国码 ≈ 脚长(cm)*2 - 10
    final cn = cm * 2 - 10;
    final eu = cn + 0.5;
    final us = cn - 18 + 0.5;
    final uk = cn - 18 - 0.5;
    return ToolScaffold(
      title: '尺码换算',
      subtitle: '脚长 → 各国鞋码',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _cm,
            label: '脚长（厘米）',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.straighten_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                _row('中国码', cn.toStringAsFixed(1)),
                _row('欧码 EU', eu.toStringAsFixed(1)),
                _row('美码 US', us.toStringAsFixed(1)),
                _row('英码 UK', uk.toStringAsFixed(1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('脚长测量建议', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '· 下午或晚上测量（脚会比早上略大）\n'
                  '· 站立状态下测量，脚后跟贴墙\n'
                  '· 量最长脚趾到脚跟的距离\n'
                  '· 运动鞋建议选大半码到一码',
                  style: Ty.tiny.copyWith(color: context.t3, height: 1.8),
                ),
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
            Text(v, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.brand)),
          ],
        ),
      );
}

// ─────────────── ⑨ 百公里油耗 ───────────────
class FuelPage extends StatefulWidget {
  const FuelPage({super.key});
  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  final _km = TextEditingController(text: '500');
  final _l = TextEditingController(text: '40');
  final _price = TextEditingController(text: '8');

  @override
  void dispose() {
    _km.dispose();
    _l.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final km = double.tryParse(_km.text) ?? 0;
    final l = double.tryParse(_l.text) ?? 0;
    final p = double.tryParse(_price.text) ?? 0;
    final per100 = km > 0 ? l / km * 100 : 0;
    final perKm = km > 0 ? l * p / km : 0;
    return ToolScaffold(
      title: '油耗计算',
      subtitle: '百公里油耗 / 每公里花费',
      
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ToolField(controller: _km, label: '里程(km)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _l, label: '油量(L)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _price, label: '油价(元/L)', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _row('百公里油耗', '${per100.toStringAsFixed(2)} L', big: true),
                _row('每公里花费', '¥${perKm.toStringAsFixed(3)}'),
                _row('每公里油耗', '${(per100 / 100).toStringAsFixed(3)} L'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 20 : 15.5, fontWeight: FontWeight.w900, color: big ? C.brand : context.t1)),
          ],
        ),
      );
}

// ─────────────── ⑩ 随机密码加强版（口令短语） ───────────────
class PassphrasePage extends StatefulWidget {
  const PassphrasePage({super.key});
  @override
  State<PassphrasePage> createState() => _PassphrasePageState();
}

class _PassphrasePageState extends State<PassphrasePage> {
  static const _words = [
    'apple', 'river', 'cloud', 'tiger', 'music', 'stone', 'light', 'bread', 'green', 'happy',
    'ocean', 'panda', 'silver', 'garden', 'rocket', 'winter', 'bamboo', 'planet', 'forest', 'candle',
    'coffee', 'dragon', 'thunder', 'moon', 'sunset', 'island', 'falcon', 'honey', 'violet', 'pepper',
    'orange', 'lemon', 'cactus', 'desert', 'marble', 'puzzle', 'shadow', 'breeze', 'ember', 'galaxy',
  ];
  String _out = '';
  int _n = 4;
  bool _cap = true;
  bool _num = true;

  void _gen() {
    final r = math.Random.secure();
    final picked = <String>[];
    for (var i = 0; i < _n; i++) {
      var w = _words[r.nextInt(_words.length)];
      if (_cap) w = w[0].toUpperCase() + w.substring(1);
      picked.add(w);
    }
    var s = picked.join('-');
    if (_num) s += '-${r.nextInt(100)}';
    setState(() => _out = s);
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '口令短语',
      subtitle: '好记又安全的密码（比乱码更好记）',
      
      child: Column(
        children: [
          ToolChips<int>(
            items: const [(3, '3 词'), (4, '4 词'), (5, '5 词'), (6, '6 词')],
            current: _n,
            onPick: (v) => setState(() => _n = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppPressable(
                  onTap: () => setState(() => _cap = !_cap),
                  child: Row(
                    children: [
                      Switch(value: _cap, activeThumbColor: C.brand, onChanged: (v) => setState(() => _cap = v)),
                      Text('首字母大写', style: Ty.small.copyWith(color: context.t2)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AppPressable(
                  onTap: () => setState(() => _num = !_num),
                  child: Row(
                    children: [
                      Switch(value: _num, activeThumbColor: C.brand, onChanged: (v) => setState(() => _num = v)),
                      Text('加数字', style: Ty.small.copyWith(color: context.t2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ToolButton(label: '生成口令', icon: Icons.vpn_key_rounded, onPressed: _gen),
          if (_out.isNotEmpty) ...[
            const SizedBox(height: 14),
            ToolCard(
              child: Column(
                children: [
                  SelectableText(_out,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: C.brand, height: 1.5)),
                  const SizedBox(height: 10),
                  AppPressable(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _out));
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
        ],
      ),
    );
  }
}
