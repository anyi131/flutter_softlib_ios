import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_kit.dart';

// ═══════════════════════════════════════════════════════════════
// 工具箱 · 第五批（1015）：生活健康 + 更多实用
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 体脂率 ───────────────
class BodyFatPage extends StatefulWidget {
  const BodyFatPage({super.key});
  @override
  State<BodyFatPage> createState() => _BodyFatPageState();
}

class _BodyFatPageState extends State<BodyFatPage> {
  final _h = TextEditingController(text: '170');
  final _w = TextEditingController(text: '65');
  final _neck = TextEditingController(text: '38');
  final _waist = TextEditingController(text: '80');
  bool _male = true;

  @override
  void dispose() {
    _h.dispose();
    _w.dispose();
    _neck.dispose();
    _waist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = double.tryParse(_h.text) ?? 0;
    final w = double.tryParse(_w.text) ?? 0;
    final neck = double.tryParse(_neck.text) ?? 0;
    final waist = double.tryParse(_waist.text) ?? 0;
    // 美国海军法（公制）
    double bf = 0;
    if (h > 0 && neck > 0 && waist > 0) {
      if (_male) {
        final d = waist - neck;
        if (d > 0) bf = 495 / (1.0324 - 0.19077 * (math.log(d) / math.ln10) + 0.15456 * (math.log(h) / math.ln10)) - 450;
      } else {
        final hip = waist * 1.25; // 近似
        final inner = waist + hip - neck;
        if (inner > 0) bf = 495 / (1.29579 - 0.35004 * (math.log(inner) / math.ln10) + 0.22100 * (math.log(h) / math.ln10)) - 450;
      }
    }
    // BMI
    final bmi = h > 0 ? w / math.pow(h / 100, 2) : 0;
    String level = '';
    if (bf > 0) {
      if (_male) {
        level = bf < 6 ? '偏低' : bf < 14 ? '运动员' : bf < 18 ? '健康' : bf < 25 ? '偏高' : '肥胖';
      } else {
        level = bf < 14 ? '偏低' : bf < 21 ? '运动员' : bf < 25 ? '健康' : bf < 32 ? '偏高' : '肥胖';
      }
    }
    return ToolScaffold(
      title: '体脂率',
      subtitle: '美国海军法估算（需量围度）',
      scrollable: true,
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
              Expanded(child: ToolField(controller: _h, label: '身高 cm', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _w, label: '体重 kg', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          Row(
            children: [
              Expanded(child: ToolField(controller: _neck, label: '颈围 cm', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _waist, label: '腰围 cm', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _r('体脂率', bf > 0 ? '${bf.toStringAsFixed(1)}%' : '—', big: true),
                _r('评估', level.isEmpty ? '—' : level),
                const Divider(height: 20),
                _r('BMI', bmi > 0 ? bmi.toStringAsFixed(1) : '—'),
                _r('BMI 评估', bmi <= 0 ? '—' : bmi < 18.5 ? '偏瘦' : bmi < 24 ? '正常' : bmi < 28 ? '偏胖' : '肥胖'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('注：围度测量误差会影响结果，仅供趋势参考', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 22 : 15.5, fontWeight: FontWeight.w900, color: big ? C.brand : context.t1)),
          ],
        ),
      );
}

// ─────────────── ② 饮水量 ───────────────
class WaterPage extends StatefulWidget {
  const WaterPage({super.key});
  @override
  State<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<WaterPage> {
  final _w = TextEditingController(text: '65');
  int _act = 1;

  @override
  void dispose() {
    _w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = double.tryParse(_w.text) ?? 0;
    final base = w * 33; // ml
    final extra = [0.0, 300, 600, 1000][_act];
    final total = base + extra;
    return ToolScaffold(
      title: '饮水量',
      subtitle: '按体重和运动量算每日建议',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _w,
            label: '体重 kg',
            keyboard: TextInputType.number,
            icon: Icons.water_drop_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolChips<int>(
            items: const [(0, '几乎不运动'), (1, '轻度'), (2, '中度'), (3, '高强度')],
            current: _act,
            onPick: (v) => setState(() => _act = v),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3AC0FF), Color(0xFF465CFF)]),
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              children: [
                const Text('每日建议饮水', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${(total / 1000).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                const SizedBox(height: 4),
                const Text('升', style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              children: [
                _r('毫升', '${total.toStringAsFixed(0)} ml'),
                _r('约等于', '${(total / 250).toStringAsFixed(1)} 杯（250ml）'),
                _r('约等于', '${(total / 500).toStringAsFixed(1)} 瓶（500ml）'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
          ],
        ),
      );
}

// ─────────────── ③ 孕期/预产期 ───────────────
class PregnancyPage extends StatefulWidget {
  const PregnancyPage({super.key});
  @override
  State<PregnancyPage> createState() => _PregnancyPageState();
}

class _PregnancyPageState extends State<PregnancyPage> {
  DateTime _last = DateTime.now().subtract(const Duration(days: 60));

  @override
  Widget build(BuildContext context) {
    final due = _last.add(const Duration(days: 280));
    final passed = DateTime.now().difference(_last).inDays;
    final weeks = passed ~/ 7;
    final days = passed % 7;
    final toDue = due.difference(DateTime.now()).inDays;
    final trimester = weeks < 13 ? '孕早期' : (weeks < 28 ? '孕中期' : '孕晚期');
    return ToolScaffold(
      title: '孕期计算',
      subtitle: '预产期 / 孕周推算',
      scrollable: true,
      child: Column(
        children: [
          ToolCard(
            onTap: () async {
              final r = await showDatePicker(
                context: context,
                initialDate: _last,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                helpText: '末次月经第一天',
              );
              if (r != null) setState(() => _last = r);
            },
            child: Row(
              children: [
                Icon(Icons.pregnant_woman_rounded, size: 19, color: C.brand),
                const SizedBox(width: 10),
                Text('末次月经', style: Ty.small.copyWith(color: context.t3)),
                const Spacer(),
                Text('${_last.year}-${_last.month.toString().padLeft(2, '0')}-${_last.day.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF8BA7), Color(0xFFFF5C8A)]),
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              children: [
                const Text('预产期', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                const SizedBox(height: 6),
                Text('还有 $toDue 天', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              children: [
                _r('当前孕周', passed < 0 ? '—' : '$weeks 周 $days 天'),
                _r('所处阶段', passed < 0 ? '—' : trimester),
                _r('已怀孕', '$passed 天'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('注：按 280 天标准孕程估算，实际以医生判断为准', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  Widget _r(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: context.t1)),
          ],
        ),
      );
}

// ─────────────── ④ 生理期预测 ───────────────
class PeriodPage extends StatefulWidget {
  const PeriodPage({super.key});
  @override
  State<PeriodPage> createState() => _PeriodPageState();
}

class _PeriodPageState extends State<PeriodPage> {
  DateTime _last = DateTime.now().subtract(const Duration(days: 14));
  int _cycle = 28;
  int _dur = 5;

  @override
  Widget build(BuildContext context) {
    final next = _last.add(Duration(days: _cycle));
    final ovu = _last.add(Duration(days: _cycle - 14));
    final toNext = next.difference(DateTime.now()).inDays;
    final safeStart = _last.add(Duration(days: _dur));
    final safeEnd = ovu.subtract(const Duration(days: 5));
    return ToolScaffold(
      title: '生理期预测',
      subtitle: '下次经期 / 排卵期推算',
      scrollable: true,
      child: Column(
        children: [
          ToolCard(
            onTap: () async {
              final r = await showDatePicker(
                context: context,
                initialDate: _last,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                helpText: '上次月经开始日',
              );
              if (r != null) setState(() => _last = r);
            },
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 19, color: C.brand),
                const SizedBox(width: 10),
                Text('上次开始日', style: Ty.small.copyWith(color: context.t3)),
                const Spacer(),
                Text('${_last.year}-${_last.month.toString().padLeft(2, '0')}-${_last.day.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('周期长度：$_cycle 天', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
          Slider(value: _cycle.toDouble(), min: 21, max: 40, activeColor: C.brand, onChanged: (v) => setState(() => _cycle = v.round())),
          Text('经期天数：$_dur 天', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
          Slider(value: _dur.toDouble(), min: 2, max: 10, activeColor: C.brand, onChanged: (v) => setState(() => _dur = v.round())),
          const SizedBox(height: 10),
          ToolCard(
            child: Column(
              children: [
                _r('下次经期', '${next.month}月${next.day}日（${toNext}天后）', color: const Color(0xFFFF5C8A)),
                _r('排卵日', '${ovu.month}月${ovu.day}日'),
                _r('易孕期', '${ovu.subtract(const Duration(days: 5)).month}月${ovu.subtract(const Duration(days: 5)).day}日 - ${ovu.add(const Duration(days: 1)).month}月${ovu.add(const Duration(days: 1)).day}日'),
                _r('安全期', '${safeStart.month}月${safeStart.day}日 - ${safeEnd.month}月${safeEnd.day}日'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('注：个体差异大，安全期避孕不可靠，仅供参考', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color ?? context.t1)),
          ],
        ),
      );
}

// ─────────────── ⑤ 记账本 ───────────────
class BookkeepPage extends StatefulWidget {
  const BookkeepPage({super.key});
  @override
  State<BookkeepPage> createState() => _BookkeepPageState();
}

class _BookkeepPageState extends State<BookkeepPage> {
  final _amt = TextEditingController();
  final _note = TextEditingController();
  final List<(String, double)> list = [];
  int _type = 0; // 0 支出 1 收入

  @override
  void dispose() {
    _amt.dispose();
    _note.dispose();
    super.dispose();
  }

  void _add() {
    final v = double.tryParse(_amt.text);
    if (v == null || v <= 0) return ToastUtil.error('请输入金额');
    setState(() {
      list.insert(0, ('${_type == 0 ? '支出' : '收入'} · ${_note.text.isEmpty ? '未备注' : _note.text}', _type == 0 ? -v : v));
      _amt.clear();
      _note.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final income = list.where((e) => e.$2 > 0).fold<double>(0, (a, b) => a + b.$2);
    final expense = -list.where((e) => e.$2 < 0).fold<double>(0, (a, b) => a + b.$2);
    return ToolScaffold(
      title: '简单记账',
      subtitle: '随手记录收支（本地，退出即清）',
      scrollable: true,
      child: Column(
        children: [
          ToolChips<int>(
            items: const [(0, '支出'), (1, '收入')],
            current: _type,
            onPick: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ToolField(controller: _amt, label: '金额', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: ToolField(controller: _note, label: '备注')),
            ],
          ),
          ToolButton(label: '记一笔', icon: Icons.add_rounded, onPressed: _add),
          const SizedBox(height: 14),
          ToolCard(
            child: Row(
              children: [
                Expanded(child: _sum('收入', income, C.success)),
                Container(width: 1, height: 34, color: C.stroke),
                Expanded(child: _sum('支出', expense, C.danger)),
                Container(width: 1, height: 34, color: C.stroke),
                Expanded(child: _sum('结余', income - expense, C.brand)),
              ],
            ),
          ),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 12),
            ToolCard(
              child: Column(
                children: list
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(e.value.$1, style: Ty.small.copyWith(color: context.t1))),
                              Text(
                                '${e.value.$2 > 0 ? '+' : ''}${e.value.$2.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: e.value.$2 > 0 ? C.success : C.danger,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppPressable(
                                onTap: () => setState(() => list.removeAt(e.key)),
                                child: Icon(Icons.close_rounded, size: 16, color: context.t3),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sum(String k, double v, Color c) => Column(
        children: [
          Text(k, style: Ty.tiny.copyWith(color: context.t3)),
          const SizedBox(height: 4),
          Text(v.toStringAsFixed(2), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c)),
        ],
      );
}

// ─────────────── ⑥ 银行卡校验 ───────────────
class BankCardPage extends StatefulWidget {
  const BankCardPage({super.key});
  @override
  State<BankCardPage> createState() => _BankCardPageState();
}

class _BankCardPageState extends State<BankCardPage> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Luhn 算法校验
  static bool luhn(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    if (d.length < 12) return false;
    var sum = 0;
    var alt = false;
    for (var i = d.length - 1; i >= 0; i--) {
      var n = int.parse(d[i]);
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  static const _banks = {
    '9558': '工商银行', '6222': '工商银行', '6212': '工商银行',
    '6225': '招商银行', '6214': '招商银行',
    '6228': '农业银行', '6227': '建设银行', '6217': '建设银行',
    '6216': '中国银行', '6221': '中国银行',
    '6226': '民生银行', '6222|6225': '',
  };

  String _bank(String d) {
    if (d.startsWith('62')) {
      final p2 = d.substring(0, 2);
      if (p2 == '62') return '银联卡（借记或信用）';
    }
    if (d.startsWith('4')) return 'Visa';
    if (d.startsWith('5')) return 'MasterCard';
    if (d.startsWith('9')) return '部分地区卡';
    return '未知发卡行';
  }

  @override
  Widget build(BuildContext context) {
    final d = _c.text.replaceAll(RegExp(r'\D'), '');
    final valid = luhn(d);
    return ToolScaffold(
      title: '银行卡校验',
      subtitle: 'Luhn 算法校验卡号（不上传）',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '银行卡号',
            hint: '输入后自动校验',
            icon: Icons.credit_card_rounded,
            keyboard: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          if (d.isNotEmpty)
            ToolCard(
              child: Column(
                children: [
                  _r('卡号长度', '${d.length} 位'),
                  _r('校验结果', valid ? '✓ 格式正确' : '✗ 校验不通过', ok: valid),
                  _r('卡组织', _bank(d)),
                  _r('Luhn 校验和', '${_checkSum(d)}'),
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
                  '· 用国际通行的 Luhn 算法校验卡号是否合法\n'
                  '· 仅做本地数学校验，不联网、不上传\n'
                  '· 校验通过不代表卡有效或可用',
                  style: Ty.tiny.copyWith(color: context.t3, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _checkSum(String s) {
    var sum = 0;
    var alt = false;
    for (var i = s.length - 1; i >= 0; i--) {
      var n = int.parse(s[i]);
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10;
  }

  Widget _r(String k, String v, {bool? ok}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ok == null ? context.t1 : (ok ? C.success : C.danger),
                )),
          ],
        ),
      );
}

// ─────────────── ⑦ 手机号归属地（本地号段） ───────────────
class PhoneAreaPage extends StatefulWidget {
  const PhoneAreaPage({super.key});
  @override
  State<PhoneAreaPage> createState() => _PhoneAreaPageState();
}

class _PhoneAreaPageState extends State<PhoneAreaPage> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _carriers = {
    '134': '移动', '135': '移动', '136': '移动', '137': '移动', '138': '移动',
    '139': '移动', '147': '移动', '150': '移动', '151': '移动', '152': '移动',
    '157': '移动', '158': '移动', '159': '移动', '178': '移动', '182': '移动',
    '183': '移动', '184': '移动', '187': '移动', '188': '移动', '198': '移动',
    '130': '联通', '131': '联通', '132': '联通', '155': '联通', '156': '联通',
    '185': '联通', '186': '联通', '166': '联通', '176': '联通',
    '133': '电信', '153': '电信', '173': '电信', '177': '电信', '180': '电信',
    '181': '电信', '189': '电信', '199': '电信',
  };

  @override
  Widget build(BuildContext context) {
    final s = _c.text.replaceAll(RegExp(r'\D'), '');
    final valid = RegExp(r'^1[3-9]\d{9}$').hasMatch(s);
    final carrier = s.length >= 3 ? (_carriers[s.substring(0, 3)] ?? '未知') : '';
    return ToolScaffold(
      title: '手机号解析',
      subtitle: '本地判断运营商与格式',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '手机号',
            hint: '输入 11 位手机号',
            icon: Icons.phone_android_rounded,
            keyboard: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          if (s.isNotEmpty)
            ToolCard(
              child: Column(
                children: [
                  _r('格式', valid ? '✓ 合法手机号' : '✗ 格式不正确', ok: valid),
                  _r('运营商', carrier),
                  _r('号段', s.length >= 7 ? '${s.substring(0, 3)} · ${s.substring(3, 7)}' : '—'),
                  _r('归属地', '需联网查询（本工具离线仅判运营商）'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool? ok}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Flexible(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: ok == null ? context.t1 : (ok ? C.success : C.danger),
                  )),
            ),
          ],
        ),
      );
}

// ─────────────── ⑧ 密码强度检测 ───────────────
class PwdCheckPage extends StatefulWidget {
  const PwdCheckPage({super.key});
  @override
  State<PwdCheckPage> createState() => _PwdCheckPageState();
}

class _PwdCheckPageState extends State<PwdCheckPage> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.text;
    var score = 0;
    final tips = <String>[];
    if (s.length >= 8) {
      score++;
    } else {
      tips.add('长度至少 8 位');
    }
    if (s.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(s)) {
      score++;
    } else {
      tips.add('加小写字母');
    }
    if (RegExp(r'[A-Z]').hasMatch(s)) {
      score++;
    } else {
      tips.add('加大写字母');
    }
    if (RegExp(r'\d').hasMatch(s)) {
      score++;
    } else {
      tips.add('加数字');
    }
    if (RegExp(r'[^\w\s]').hasMatch(s)) {
      score++;
    } else {
      tips.add('加符号（如 !@#）');
    }
    // 常见弱密码
    const weak = ['123456', 'password', 'qwerty', '111111', 'abc123', 'admin', '888888', '12345678'];
    if (weak.contains(s.toLowerCase())) {
      score = 1;
      tips.insert(0, '这是最常见的弱密码之一！');
    }
    final level = score <= 2 ? '弱' : score <= 4 ? '中' : '强';
    final color = score <= 2 ? C.danger : score <= 4 ? C.warning : C.success;
    return ToolScaffold(
      title: '密码强度',
      subtitle: '检测密码强度并给改进建议',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '输入密码',
            icon: Icons.lock_rounded,
            onChanged: (_) => setState(() {}),
          ),
          if (s.isNotEmpty) ...[
            const SizedBox(height: 6),
            ToolCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('强度', style: Ty.small.copyWith(color: context.t3)),
                      const Spacer(),
                      Text(level, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (score / 6).clamp(0.08, 1.0),
                      minHeight: 8,
                      backgroundColor: C.stroke,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('得分 $score / 6', style: Ty.tiny.copyWith(color: context.t3)),
                  ),
                ],
              ),
            ),
            if (tips.isNotEmpty) ...[
              const SizedBox(height: 12),
              ToolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('改进建议', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...tips.map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_right_rounded, size: 16, color: C.warning),
                              Text(t, style: Ty.small.copyWith(color: context.t2)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
