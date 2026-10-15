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
// 工具箱 · 扩展本地工具（1015 新增）
//   全部纯本地计算/转换，不依赖任何第三方接口 → 永不失效
//   公共骨架来自 tool_kit.dart（ToolScaffold / ToolCard / ToolButton / ToolField / ToolChips）
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 科学计算器 ───────────────
class CalcPage extends StatefulWidget {
  const CalcPage({super.key});
  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  final _ctrl = TextEditingController();
  final List<String> _hist = [];
  String _result = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run() {
    final src = _ctrl.text.trim();
    if (src.isEmpty) return;
    try {
      final v = _eval(src);
      final txt = _fmt(v);
      setState(() {
        _result = txt;
        _hist.insert(0, '$src = $txt');
        if (_hist.length > 30) _hist.removeLast();
      });
    } catch (_) {
      ToastUtil.error('表达式无法计算');
    }
  }

  static String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return '—';
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    return v.toStringAsPrecision(12).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// 极简表达式求值（支持 + - * / % ^ 括号、pi/e、常见函数）
  static double _eval(String s) {
    var t = s
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('π', 'pi')
        .replaceAll(' ', '')
        .toLowerCase();
    return _P(t).parse();
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '科学计算器',
      subtitle: '支持括号 / 幂 / 函数 / 常量',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _ctrl,
            label: '表达式',
            hint: '例：2*(3+4)^2 或 sqrt(16)+pi',
            icon: Icons.calculate_rounded,
            onSubmitted: (_) => _run(),
          ),
          ToolButton(label: '计算', icon: Icons.play_arrow_rounded, onPressed: _run),
          const SizedBox(height: 14),
          if (_result.isNotEmpty)
            ToolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('结果', style: Ty.tiny.copyWith(color: context.t3)),
                  const SizedBox(height: 6),
                  SelectableText(
                    _result,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: C.brand,
                    ),
                  ),
                ],
              ),
            ),
          if (_hist.isNotEmpty) ...[
            const SizedBox(height: 14),
            ToolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('历史', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      AppPressable(
                        onTap: () => setState(() => _hist.clear()),
                        child: Text('清空', style: Ty.tiny.copyWith(color: C.danger)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._hist.map((h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(h, style: Ty.tiny.copyWith(color: context.t2)),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 递归下降解析器（+ - * / % ^ 与括号、函数）
class _P {
  final String s;
  int i = 0;
  _P(this.s);

  double parse() {
    final v = _expr();
    if (i < s.length) throw Exception('bad');
    return v;
  }

  double _expr() {
    var v = _term();
    while (i < s.length) {
      final c = s[i];
      if (c == '+') {
        i++;
        v += _term();
      } else if (c == '-') {
        i++;
        v -= _term();
      } else {
        break;
      }
    }
    return v;
  }

  double _term() {
    var v = _pow();
    while (i < s.length) {
      final c = s[i];
      if (c == '*') {
        i++;
        v *= _pow();
      } else if (c == '/') {
        i++;
        v /= _pow();
      } else if (c == '%') {
        i++;
        v %= _pow();
      } else {
        break;
      }
    }
    return v;
  }

  double _pow() {
    final b = _unary();
    if (i < s.length && s[i] == '^') {
      i++;
      return math.pow(b, _pow()).toDouble();
    }
    return b;
  }

  double _unary() {
    if (i < s.length && s[i] == '-') {
      i++;
      return -_unary();
    }
    if (i < s.length && s[i] == '+') {
      i++;
    }
    return _atom();
  }

  double _atom() {
    if (i >= s.length) throw Exception('eof');
    if (s[i] == '(') {
      i++;
      final v = _expr();
      if (i >= s.length || s[i] != ')') throw Exception(')');
      i++;
      return v;
    }
    // 数字
    final st = i;
    while (i < s.length && (RegExp(r'[0-9.]').hasMatch(s[i]))) {
      i++;
    }
    if (i > st) return double.parse(s.substring(st, i));
    // 标识符
    final sb = StringBuffer();
    while (i < s.length && RegExp(r'[a-z0-9_]').hasMatch(s[i])) {
      sb.write(s[i]);
      i++;
    }
    final name = sb.toString();
    if (name == 'pi') return math.pi;
    if (name == 'e') return math.e;
    // 函数后必须跟括号
    if (i < s.length && s[i] == '(') {
      i++;
      final v = _expr();
      if (i >= s.length || s[i] != ')') throw Exception(')');
      i++;
      switch (name) {
        case 'sqrt':
          return math.sqrt(v);
        case 'abs':
          return v.abs();
        case 'sin':
          return math.sin(v);
        case 'cos':
          return math.cos(v);
        case 'tan':
          return math.tan(v);
        case 'ln':
          return math.log(v);
        case 'log':
          return math.log(v) / math.ln10;
        case 'round':
          return v.roundToDouble();
        case 'floor':
          return v.floorToDouble();
        case 'ceil':
          return v.ceilToDouble();
      }
    }
    throw Exception('unknown:$name');
  }
}

// ─────────────── ② 进制转换 ───────────────
class HexConvPage extends StatefulWidget {
  const HexConvPage({super.key});
  @override
  State<HexConvPage> createState() => _HexConvPageState();
}

class _HexConvPageState extends State<HexConvPage> {
  final _in = TextEditingController(text: '255');
  int _fromBase = 10;

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  int? get _val {
    final t = _in.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t, radix: _fromBase);
  }

  @override
  Widget build(BuildContext context) {
    final v = _val;
    return ToolScaffold(
      title: '进制转换',
      subtitle: '2 / 8 / 10 / 16 及自定义进制',
      scrollable: true,
      child: Column(
        children: [
          ToolChips<int>(
            items: const [(2, '二进制'), (8, '八进制'), (10, '十进制'), (16, '十六进制')],
            current: _fromBase,
            onPick: (v) => setState(() => _fromBase = v),
          ),
          const SizedBox(height: 12),
          ToolField(
            controller: _in,
            label: '输入（$_fromBase 进制）',
            icon: Icons.input_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          if (v == null)
            ToolCard(child: Text('请输入合法的 $_fromBase 进制数', style: Ty.small.copyWith(color: context.t3)))
          else
            ToolCard(
              child: Column(
                children: [
                  _row('二进制 (2)', v.toRadixString(2)),
                  _row('八进制 (8)', v.toRadixString(8)),
                  _row('十进制 (10)', v.toString()),
                  _row('十六进制 (16)', v.toRadixString(16).toUpperCase()),
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
            SizedBox(width: 96, child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Expanded(
              child: SelectableText(
                v,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1),
              ),
            ),
            AppPressable(
              onTap: () {
                Clipboard.setData(ClipboardData(text: v));
                ToastUtil.success('已复制');
              },
              child: Icon(Icons.copy_rounded, size: 17, color: context.t3),
            ),
          ],
        ),
      );
}

// ─────────────── ③ 时间戳转换 ───────────────
class TimestampPage extends StatefulWidget {
  const TimestampPage({super.key});
  @override
  State<TimestampPage> createState() => _TimestampPageState();
}

class _TimestampPageState extends State<TimestampPage> {
  final _in = TextEditingController();
  String _out = '';

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  void _ts2date() {
    final t = _in.text.trim();
    if (t.isEmpty) return;
    var n = int.tryParse(t);
    if (n == null) return ToastUtil.error('请输入数字时间戳');
    if (n > 99999999999) n = n ~/ 1000; // 毫秒自动转秒
    final d = DateTime.fromMillisecondsSinceEpoch(n * 1000);
    setState(() => _out = '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}:${_p(d.second)}');
  }

  void _date2ts() {
    final now = DateTime.now();
    setState(() => _out = '${now.millisecondsSinceEpoch ~/ 1000}');
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ToolScaffold(
      title: '时间戳转换',
      subtitle: 'Unix 时间戳 ↔ 日期时间',
      
      child: Column(
        children: [
          ToolCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前时间戳（秒）', style: Ty.tiny.copyWith(color: context.t3)),
                      const SizedBox(height: 4),
                      SelectableText(
                        '${now.millisecondsSinceEpoch ~/ 1000}',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: C.brand),
                      ),
                    ],
                  ),
                ),
                AppPressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '${now.millisecondsSinceEpoch ~/ 1000}'));
                    ToastUtil.success('已复制');
                  },
                  child: Icon(Icons.copy_rounded, size: 19, color: context.t3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolField(
            controller: _in,
            label: '时间戳或日期',
            hint: '输入时间戳 → 转日期；输入日期 → 转时间戳',
            icon: Icons.schedule_rounded,
            keyboard: TextInputType.text,
          ),
          Row(
            children: [
              Expanded(
                child: ToolButton(label: '时间戳→日期', icon: Icons.event_rounded, onPressed: _ts2date),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(label: '取当前时间戳', icon: Icons.access_time_rounded, outline: true, onPressed: _date2ts),
              ),
            ],
          ),
          if (_out.isNotEmpty) ...[
            const SizedBox(height: 14),
            ToolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('结果', style: Ty.tiny.copyWith(color: context.t3)),
                  const SizedBox(height: 6),
                  SelectableText(_out, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: C.brand)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────── ④ 大小写 / 文本转换 ───────────────
class CaseConvPage extends StatefulWidget {
  const CaseConvPage({super.key});
  @override
  State<CaseConvPage> createState() => _CaseConvPageState();
}

class _CaseConvPageState extends State<CaseConvPage> {
  final _in = TextEditingController();
  final _out = TextEditingController();

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  void _apply(String Function(String) f, String label) {
    setState(() => _out.text = f(_in.text));
    ToastUtil.success('已转换为$label');
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '文本转换',
      subtitle: '大小写 / 驼峰 / 下划线 / 反转',
      scrollable: true,
      child: Column(
        children: [
          ToolField(controller: _in, label: '原文', lines: 4, icon: Icons.text_fields_rounded),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('全部大写', () => _apply((s) => s.toUpperCase(), '大写')),
              _chip('全部小写', () => _apply((s) => s.toLowerCase(), '小写')),
              _chip('首字母大写', () => _apply(_title, '首字母大写')),
              _chip('驼峰命名', () => _apply(_camel, '驼峰')),
              _chip('下划线', () => _apply(_snake, '下划线')),
              _chip('中划线', () => _apply((s) => _snake(s).replaceAll('_', '-'), '中划线')),
              _chip('去空格', () => _apply((s) => s.replaceAll(RegExp(r'\s+'), ''), '去空格')),
              _chip('去多余空行', () => _apply((s) => s.replaceAll(RegExp(r'\n\s*\n+'), '\n'), '整理')),
              _chip('文字反转', () => _apply((s) => s.split('').reversed.join(), '反转')),
              _chip('去重行', () => _apply((s) => s.split('\n').toSet().join('\n'), '去重')),
              _chip('排序行', () {
                final l = _in.text.split('\n')..sort();
                setState(() => _out.text = l.join('\n'));
              }),
            ],
          ),
          const SizedBox(height: 12),
          ToolField(
            controller: _out,
            label: '结果',
            lines: 6,
            suffixIcon: Icons.copy_rounded,
            onSuffixTap: () {
              Clipboard.setData(ClipboardData(text: _out.text));
              ToastUtil.success('已复制');
            },
          ),
        ],
      ),
    );
  }

  static String _title(String s) =>
      s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');

  static String _camel(String s) {
    final parts = s.split(RegExp(r'[\s_\-]+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return s;
    return parts.first.toLowerCase() +
        parts.skip(1).map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join();
  }

  static String _snake(String s) => s
      .replaceAll(RegExp(r'([a-z0-9])([A-Z])'), r'$1_$2')
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .toLowerCase();

  Widget _chip(String label, VoidCallback onTap) => AppPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(context.isDark ? 30 : 14),
            borderRadius: BorderRadius.circular(R.full),
          ),
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.brand)),
        ),
      );
}

// ─────────────── ⑤ UUID 生成 ───────────────
class UuidPage extends StatefulWidget {
  const UuidPage({super.key});
  @override
  State<UuidPage> createState() => _UuidPageState();
}

class _UuidPageState extends State<UuidPage> {
  final _list = <String>[];
  int _count = 5;

  String _uuid4() {
    final r = math.Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  void _gen() {
    setState(() {
      _list.clear();
      for (var i = 0; i < _count; i++) {
        _list.add(_uuid4());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'UUID 生成',
      subtitle: '随机唯一标识（v4）',
      scrollable: true,
      child: Column(
        children: [
          ToolChips<int>(
            items: const [(1, '1 个'), (5, '5 个'), (10, '10 个'), (20, '20 个')],
            current: _count,
            onPick: (v) => setState(() => _count = v),
          ),
          const SizedBox(height: 12),
          ToolButton(label: '生成', icon: Icons.auto_awesome_rounded, onPressed: _gen),
          const SizedBox(height: 14),
          if (_list.isNotEmpty)
            ToolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('已生成 ${_list.length} 个', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      AppPressable(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _list.join('\n')));
                          ToastUtil.success('已全部复制');
                        },
                        child: Text('全部复制', style: Ty.tiny.copyWith(color: C.brand)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._list.map((u) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SelectableText(u, style: TextStyle(fontSize: 12.5, color: context.t1, fontFamily: 'monospace')),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────── ⑥ 颜色转换 ───────────────
class ColorConvPage extends StatefulWidget {
  const ColorConvPage({super.key});
  @override
  State<ColorConvPage> createState() => _ColorConvPageState();
}

class _ColorConvPageState extends State<ColorConvPage> {
  final _in = TextEditingController(text: '465CFF');

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  int? get _rgb {
    var t = _in.text.trim().replaceAll('#', '');
    if (t.length == 3) {
      t = t.split('').map((c) => '$c$c').join();
    }
    if (t.length != 6) return null;
    return int.tryParse(t, radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    final v = _rgb;
    return ToolScaffold(
      title: '颜色转换',
      subtitle: 'HEX ↔ RGB ↔ HSL',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _in,
            label: 'HEX 颜色（可不带 #）',
            hint: '例：465CFF 或 #fff',
            icon: Icons.palette_rounded,
            onChanged: (_) => setState(() {}),
          ),
          if (v != null) ...[
            ToolCard(
              child: Column(
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Color(0xff000000 | v),
                      borderRadius: BorderRadius.circular(R.md),
                      border: Border.all(color: C.stroke),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _row('HEX', '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}'),
                  _row('RGB', 'rgb(${(v >> 16) & 255}, ${(v >> 8) & 255}, ${v & 255})'),
                  _row('RGBA', 'rgba(${(v >> 16) & 255}, ${(v >> 8) & 255}, ${v & 255}, 1)'),
                  _row('数值', '0xFF${v.toRadixString(16).padLeft(6, '0').toUpperCase()}'),
                ],
              ),
            ),
          ] else
            ToolCard(child: Text('请输入 3 位或 6 位十六进制颜色', style: Ty.small.copyWith(color: context.t3))),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 66, child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Expanded(child: SelectableText(v, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.t1))),
            AppPressable(
              onTap: () {
                Clipboard.setData(ClipboardData(text: v));
                ToastUtil.success('已复制');
              },
              child: Icon(Icons.copy_rounded, size: 17, color: context.t3),
            ),
          ],
        ),
      );
}

// ─────────────── ⑦ 百分比 / 折扣计算 ───────────────
class PercentPage extends StatefulWidget {
  const PercentPage({super.key});
  @override
  State<PercentPage> createState() => _PercentPageState();
}

class _PercentPageState extends State<PercentPage> {
  final _a = TextEditingController(text: '100');
  final _b = TextEditingController(text: '80');

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = double.tryParse(_a.text) ?? 0;
    final b = double.tryParse(_b.text) ?? 0;
    final save = a - b;
    final off = a > 0 ? save / a * 100 : 0;
    return ToolScaffold(
      title: '折扣计算',
      subtitle: '原价 / 现价 → 折扣与省额',
      
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ToolField(controller: _a, label: '原价（元）', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: ToolField(controller: _b, label: '现价（元）', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _row('打折', '${(b / (a == 0 ? 1 : a) * 10).toStringAsFixed(2)} 折'),
                _row('省下', '¥${save.toStringAsFixed(2)}'),
                _row('降幅', '${off.toStringAsFixed(2)}%'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('常用折扣对照（原价 ¥$a）', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...[9, 8, 7, 6, 5].map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text('$d 折', style: Ty.tiny.copyWith(color: context.t3))),
                          Text('¥${(a * d / 10).toStringAsFixed(2)}', style: Ty.tiny.copyWith(fontWeight: FontWeight.w800)),
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

// ─────────────── ⑧ 日期间隔计算 ───────────────
class DateCalcPage extends StatefulWidget {
  const DateCalcPage({super.key});
  @override
  State<DateCalcPage> createState() => _DateCalcPageState();
}

class _DateCalcPageState extends State<DateCalcPage> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    final days = _to.difference(_from).inDays;
    return ToolScaffold(
      title: '日期间隔',
      subtitle: '两个日期相差多少天',
      scrollable: true,
      child: Column(
        children: [
          _picker('开始日期', _from, (d) => setState(() => _from = d)),
          const SizedBox(height: 10),
          _picker('结束日期', _to, (d) => setState(() => _to = d)),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _row('相差天数', '$days 天'),
                _row('相差周数', '${(days / 7).toStringAsFixed(1)} 周'),
                _row('相差月数', '${(days / 30.44).toStringAsFixed(1)} 月'),
                _row('相差年数', '${(days / 365.25).toStringAsFixed(2)} 年'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _picker(String label, DateTime d, ValueChanged<DateTime> onPick) => ToolCard(
        onTap: () async {
          final r = await showDatePicker(
            context: context,
            initialDate: d,
            firstDate: DateTime(1970),
            lastDate: DateTime(2100),
            helpText: label,
          );
          if (r != null) onPick(r);
        },
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 19, color: C.brand),
            const SizedBox(width: 10),
            Text(label, style: Ty.small.copyWith(color: context.t3)),
            const Spacer(),
            Text(
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1),
            ),
          ],
        ),
      );

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
