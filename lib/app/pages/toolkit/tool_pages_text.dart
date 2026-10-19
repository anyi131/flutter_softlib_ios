import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_anim.dart';
import '../../design/ad.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_kit.dart';

// ═══════════════════════════════════════════════════════════════
// 工具箱 · 第四批（1015）：文本处理全集 + 生成器
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 字数统计 ───────────────
class TextStatPage extends StatefulWidget {
  const TextStatPage({super.key});
  @override
  State<TextStatPage> createState() => _TextStatPageState();
}

class _TextStatPageState extends State<TextStatPage> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _c.text;
    final chars = t.characters.length;
    final cn = RegExp(r'[\u4e00-\u9fa5]').allMatches(t).length;
    final en = RegExp(r'[a-zA-Z]').allMatches(t).length;
    final num = RegExp(r'[0-9]').allMatches(t).length;
    final words = t.trim().isEmpty ? 0 : t.trim().split(RegExp(r'\s+')).length;
    final lines = t.isEmpty ? 0 : t.split('\n').length;
    return ToolScaffold(
      title: '字数统计',
      subtitle: '字符/中英文/行数统计',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '输入文本',
            lines: 5,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                _r('总字符数', '$chars'),
                _r('中文字数', '$cn'),
                _r('英文字母', '$en'),
                _r('数字个数', '$num'),
                _r('单词数', '$words'),
                _r('行数', '$lines'),
                _r(
                  '段落数',
                  '${t.split(RegExp(r'\n\s*\n')).where((e) => e.trim().isNotEmpty).length}',
                ),
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
        Expanded(
          child: Text(k, style: Ty.small.copyWith(color: context.t3)),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: C.brand,
          ),
        ),
      ],
    ),
  );
}

// ─────────────── ② JSON 格式化 ───────────────
class JsonPage extends StatefulWidget {
  const JsonPage({super.key});
  @override
  State<JsonPage> createState() => _JsonPageState();
}

class _JsonPageState extends State<JsonPage> {
  final _in = TextEditingController();
  final _out = TextEditingController();
  String _msg = '';
  bool _ok = true;

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  void _fmt({required bool pretty}) {
    try {
      final obj = jsonDecode(_in.text);
      final s = pretty
          ? const JsonEncoder.withIndent('  ').convert(obj)
          : jsonEncode(obj);
      setState(() {
        _out.text = s;
        _msg = 'JSON 合法 · ${s.length} 字符';
        _ok = true;
      });
    } catch (e) {
      setState(() {
        _msg = '格式错误：${e.toString().split('\n').first}';
        _ok = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'JSON 工具',
      subtitle: '格式化 / 压缩 / 校验',

      child: Column(
        children: [
          ToolField(
            controller: _in,
            label: 'JSON 原文',
            lines: 6,
            icon: Icons.data_object_rounded,
          ),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: '格式化',
                  icon: Icons.format_align_left_rounded,
                  onPressed: () => _fmt(pretty: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: '压缩',
                  icon: Icons.compress_rounded,
                  outline: true,
                  onPressed: () => _fmt(pretty: false),
                ),
              ),
            ],
          ),
          if (_msg.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _msg,
              style: Ty.tiny.copyWith(color: _ok ? C.success : C.danger),
            ),
          ],
          const SizedBox(height: 10),
          ToolField(
            controller: _out,
            label: '结果',
            lines: 8,
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
}

// ─────────────── ③ URL 编码解码 ───────────────
class UrlPage extends StatefulWidget {
  const UrlPage({super.key});
  @override
  State<UrlPage> createState() => _UrlPageState();
}

class _UrlPageState extends State<UrlPage> {
  final _in = TextEditingController();
  final _out = TextEditingController();

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'URL 编码',
      subtitle: 'URLEncode / URLDecode',

      child: Column(
        children: [
          ToolField(
            controller: _in,
            label: '原文',
            lines: 4,
            icon: Icons.link_rounded,
          ),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: '编码',
                  icon: Icons.lock_rounded,
                  onPressed: () =>
                      setState(() => _out.text = Uri.encodeComponent(_in.text)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: '解码',
                  icon: Icons.lock_open_rounded,
                  outline: true,
                  onPressed: () {
                    try {
                      setState(
                        () => _out.text = Uri.decodeComponent(_in.text.trim()),
                      );
                    } catch (_) {
                      ToastUtil.error('不是合法的 URL 编码');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToolField(
            controller: _out,
            label: '结果',
            lines: 5,
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
}

// ─────────────── ④ 哈希计算 ───────────────
class HashPage extends StatefulWidget {
  const HashPage({super.key});
  @override
  State<HashPage> createState() => _HashPageState();
}

class _HashPageState extends State<HashPage> {
  final _in = TextEditingController();
  final Map<String, String> res = {};

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  // FNV-1a（32/64）简易校验和；无加密库依赖也能给出稳定摘要
  static String fnv1a(String s, {bool bits64 = false}) {
    if (bits64) {
      var h = BigInt.parse('14695981039346656037');
      final prime = BigInt.parse('1099511628211');
      final mask = (BigInt.one << 64) - BigInt.one;
      for (final b in utf8.encode(s)) {
        h = h ^ BigInt.from(b);
        h = (h * prime) & mask;
      }
      return h.toRadixString(16).padLeft(16, '0');
    } else {
      var h = 0x811c9dc5;
      for (final b in utf8.encode(s)) {
        h ^= b;
        h = (h * 0x01000193) & 0xFFFFFFFF;
      }
      return h.toRadixString(16).padLeft(8, '0');
    }
  }

  // 简单易读校验码（用于对账）
  static String simple(String s) {
    var sum = 0;
    for (final c in s.codeUnits) {
      sum = (sum * 31 + c) & 0x7FFFFFFF;
    }
    return sum.toRadixString(16).padLeft(8, '0');
  }

  void _calc() {
    final s = _in.text;
    setState(() {
      res['FNV-1a 32'] = fnv1a(s);
      res['FNV-1a 64'] = fnv1a(s, bits64: true);
      res['简单校验码'] = simple(s);
      res['Base64'] = base64Encode(utf8.encode(s));
      res['长度（字节）'] = '${utf8.encode(s).length}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '哈希校验',
      subtitle: '文本摘要 / 校验码',

      child: Column(
        children: [
          ToolField(
            controller: _in,
            label: '输入文本',
            lines: 4,
            icon: Icons.tag_rounded,
          ),
          ToolButton(
            label: '计算',
            icon: Icons.fingerprint_rounded,
            onPressed: _calc,
          ),
          if (res.isNotEmpty) ...[
            const SizedBox(height: 14),
            ToolCard(
              child: Column(
                children: res.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: Ad.w(context, 96),
                              child: Text(
                                e.key,
                                style: Ty.small.copyWith(color: context.t3),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                e.value,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: context.t1,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            AppPressable(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: e.value));
                                ToastUtil.success('已复制');
                              },
                              child: Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: context.t3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────── ⑤ 正则测试 ───────────────
class RegexPage extends StatefulWidget {
  const RegexPage({super.key});
  @override
  State<RegexPage> createState() => _RegexPageState();
}

class _RegexPageState extends State<RegexPage> {
  final _re = TextEditingController(text: r'\d+');
  final _txt = TextEditingController(text: 'abc123def456');
  List<String> matches = [];
  String err = '';

  @override
  void dispose() {
    _re.dispose();
    _txt.dispose();
    super.dispose();
  }

  void _run() {
    try {
      final r = RegExp(_re.text);
      final m = r.allMatches(_txt.text).map((e) => e.group(0) ?? '').toList();
      setState(() {
        matches = m;
        err = '';
      });
    } catch (e) {
      setState(() {
        matches = [];
        err = '正则表达式错误';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '正则测试',
      subtitle: '验证正则并查看匹配结果',
      scrollable: true,
      child: Column(
        children: [
          ToolField(controller: _re, label: '正则表达式', icon: Icons.code_rounded),
          ToolField(controller: _txt, label: '测试文本', lines: 4),
          ToolButton(
            label: '运行匹配',
            icon: Icons.play_arrow_rounded,
            onPressed: _run,
          ),
          if (err.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(err, style: Ty.small.copyWith(color: C.danger)),
          ],
          if (matches.isNotEmpty) ...[
            const SizedBox(height: 14),
            ToolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '匹配到 ${matches.length} 处',
                    style: Ty.small.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...matches
                      .take(50)
                      .map(
                        (m) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            m,
                            style: Ty.small.copyWith(
                              color: C.brand,
                              fontFamily: 'monospace',
                            ),
                          ),
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

// ─────────────── ⑥ 随机字符串 ───────────────
class RandStrPage extends StatefulWidget {
  const RandStrPage({super.key});
  @override
  State<RandStrPage> createState() => _RandStrPageState();
}

class _RandStrPageState extends State<RandStrPage> {
  int _len = 16;
  bool _upper = true, _lower = true, _digit = true, _symbol = false;
  String _out = '';

  void _gen() {
    const u = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const l = 'abcdefghijkmnpqrstuvwxyz';
    const d = '23456789';
    const s = '!@#\$%^&*-_=+';
    var pool = '';
    if (_upper) pool += u;
    if (_lower) pool += l;
    if (_digit) pool += d;
    if (_symbol) pool += s;
    if (pool.isEmpty) return ToastUtil.error('至少选一种字符');
    final r = math.Random.secure();
    setState(
      () => _out = List.generate(
        _len,
        (_) => pool[r.nextInt(pool.length)],
      ).join(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '随机字符串',
      subtitle: '自定义长度与字符集',
      scrollable: true,
      child: Column(
        children: [
          Text(
            '长度：$_len',
            style: Ty.small.copyWith(fontWeight: FontWeight.w800),
          ),
          Slider(
            value: _len.toDouble(),
            min: 4,
            max: 64,
            activeColor: C.brand,
            onChanged: (v) => setState(() => _len = v.round()),
          ),
          Wrap(
            spacing: 12,
            children: [
              _sw('大写', _upper, (v) => setState(() => _upper = v)),
              _sw('小写', _lower, (v) => setState(() => _lower = v)),
              _sw('数字', _digit, (v) => setState(() => _digit = v)),
              _sw('符号', _symbol, (v) => setState(() => _symbol = v)),
            ],
          ),
          const SizedBox(height: 12),
          ToolButton(label: '生成', icon: Icons.casino_rounded, onPressed: _gen),
          if (_out.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ToolCard(
                child: Column(
                  children: [
                    SelectableText(
                      _out,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: C.brand,
                        fontFamily: 'monospace',
                      ),
                    ),
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
                          Text(
                            '复制',
                            style: Ty.tiny.copyWith(color: context.t3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sw(String label, bool v, ValueChanged<bool> on) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Switch(value: v, activeThumbColor: C.brand, onChanged: on),
      Text(label, style: Ty.small.copyWith(color: context.t2)),
    ],
  );
}

// ─────────────── ⑦ 随机数与抽签 ───────────────
class RandNumPage extends StatefulWidget {
  const RandNumPage({super.key});
  @override
  State<RandNumPage> createState() => _RandNumPageState();
}

class _RandNumPageState extends State<RandNumPage> {
  final _min = TextEditingController(text: '1');
  final _max = TextEditingController(text: '100');
  final _n = TextEditingController(text: '1');
  bool _noRepeat = true;
  List<int> out = [];

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _n.dispose();
    super.dispose();
  }

  void _gen() {
    final a = int.tryParse(_min.text) ?? 1;
    final b = int.tryParse(_max.text) ?? 100;
    final c = int.tryParse(_n.text) ?? 1;
    if (a > b) return ToastUtil.error('最小值不能大于最大值');
    final count = (b - a + 1);
    if (_noRepeat && c > count) return ToastUtil.error('范围内数字不够');
    final r = math.Random.secure();
    final res = <int>[];
    if (_noRepeat) {
      final pool = List.generate(count, (i) => a + i)..shuffle(r);
      res.addAll(pool.take(c));
    } else {
      for (var i = 0; i < c; i++) {
        res.add(a + r.nextInt(count));
      }
    }
    setState(() => out = res);
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '随机数 / 抽签',
      subtitle: '范围随机数、不重复抽签',

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ToolField(
                  controller: _min,
                  label: '最小值',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolField(
                  controller: _max,
                  label: '最大值',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolField(
                  controller: _n,
                  label: '个数',
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Switch(
                value: _noRepeat,
                activeThumbColor: C.brand,
                onChanged: (v) => setState(() => _noRepeat = v),
              ),
              Text('不重复（抽签用）', style: Ty.small.copyWith(color: context.t2)),
            ],
          ),
          const SizedBox(height: 8),
          ToolButton(label: '生成', icon: Icons.casino_rounded, onPressed: _gen),
          if (out.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ToolCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: out
                      .map<Widget>(
                        (n) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: Deco.brandGradient,
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────── ⑧ 配色方案 ───────────────
class PalettePage extends StatefulWidget {
  const PalettePage({super.key});
  @override
  State<PalettePage> createState() => _PalettePageState();
}

class _PalettePageState extends State<PalettePage> {
  final _base = TextEditingController(text: '465CFF');
  List<String> colors = [];

  @override
  void dispose() {
    _base.dispose();
    super.dispose();
  }

  static String _hsl2hex(double h, double s, double l) {
    h = h % 360;
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;
    double r = 0, g = 0, b = 0;
    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }
    int to(double v) => ((v + m) * 255).round().clamp(0, 255);
    return '#${to(r).toRadixString(16).padLeft(2, '0')}${to(g).toRadixString(16).padLeft(2, '0')}${to(b).toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  void _gen(int mode) {
    var h = _base.text.trim().replaceAll('#', '');
    if (h.length != 6) return ToastUtil.error('请输入 6 位 HEX 颜色');
    final v = int.tryParse(h, radix: 16);
    if (v == null) return ToastUtil.error('颜色格式不对');
    final r = ((v >> 16) & 255) / 255,
        g = ((v >> 8) & 255) / 255,
        b = (v & 255) / 255;
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    final l = (mx + mn) / 2;
    final s = mx == mn
        ? 0.0
        : (l > 0.5 ? (mx - mn) / (2 - mx - mn) : (mx - mn) / (mx + mn));
    double hue;
    if (mx == mn) {
      hue = 0;
    } else if (mx == r) {
      hue = 60 * (((g - b) / (mx - mn)) % 6);
    } else if (mx == g) {
      hue = 60 * ((b - r) / (mx - mn) + 2);
    } else {
      hue = 60 * ((r - g) / (mx - mn) + 4);
    }
    final res = <String>[];
    if (mode == 0) {
      // 互补 + 邻近
      res.add(_hsl2hex(hue, s, l));
      res.add(_hsl2hex(hue + 30, s, l));
      res.add(_hsl2hex(hue + 180, s, l));
      res.add(_hsl2hex(hue + 210, s, l));
      res.add(_hsl2hex(hue, s * 0.6, math.min(1, l + 0.2)));
    } else if (mode == 1) {
      // 明暗阶梯
      for (var i = 0; i < 5; i++) {
        res.add(_hsl2hex(hue, s, (0.2 + i * 0.15).clamp(0, 1)));
      }
    } else {
      // 三角配色
      res.add(_hsl2hex(hue, s, l));
      res.add(_hsl2hex(hue + 120, s, l));
      res.add(_hsl2hex(hue + 240, s, l));
      res.add(_hsl2hex(hue + 180, s * 0.7, l));
      res.add(_hsl2hex(hue + 60, s * 0.5, math.min(1, l + 0.15)));
    }
    setState(() => colors = res);
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '配色方案',
      subtitle: '按基色生成和谐配色',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _base,
            label: '基准色 HEX',
            hint: '例：465CFF',
            icon: Icons.palette_rounded,
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _btn('互补邻近', () => _gen(0)),
              _btn('明暗阶梯', () => _gen(1)),
              _btn('三角配色', () => _gen(2)),
            ],
          ),
          if (colors.isNotEmpty) ...[
            const SizedBox(height: 16),
            ToolCard(
              child: Column(
                children: colors.map<Widget>((hex) {
                  final v = int.parse(hex.substring(1), radix: 16);
                  return GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: hex));
                      ToastUtil.success('已复制 $hex');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(0xff000000 | v),
                              borderRadius: BorderRadius.circular(R.sm),
                              border: Border.all(color: C.stroke),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            hex,
                            style: Ty.small.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => AppPressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: C.brand.withAlpha(context.isDark ? 30 : 14),
        borderRadius: BorderRadius.circular(R.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: C.brand,
        ),
      ),
    ),
  );
}

// ─────────────── ⑨ 占位文本生成 ───────────────
class LoremPage extends StatefulWidget {
  const LoremPage({super.key});
  @override
  State<LoremPage> createState() => _LoremPageState();
}

class _LoremPageState extends State<LoremPage> {
  int _paras = 3;
  String _out = '';

  static const _sents = [
    '在这个快速变化的时代，保持专注比获取信息更重要。',
    '好的产品不是功能堆砌，而是恰到好处的解决问题。',
    '把复杂留给自己，把简单留给用户。',
    '持续迭代胜过一次性完美。',
    '数据的价值在于被使用，而不是被存储。',
    '沟通的成本，往往高于实现本身。',
    '先让它跑起来，再让它跑得更好。',
    '别人的经验可以借鉴，但不能照搬。',
  ];

  void _gen() {
    final r = math.Random();
    final sb = StringBuffer();
    for (var i = 0; i < _paras; i++) {
      final n = 3 + r.nextInt(3);
      for (var j = 0; j < n; j++) {
        sb.write(_sents[r.nextInt(_sents.length)]);
      }
      sb.write('\n\n');
    }
    setState(() => _out = sb.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '占位文本',
      subtitle: '生成排版测试用的示例文字',
      scrollable: true,
      child: Column(
        children: [
          Text(
            '段落数：$_paras',
            style: Ty.small.copyWith(fontWeight: FontWeight.w800),
          ),
          Slider(
            value: _paras.toDouble(),
            min: 1,
            max: 20,
            activeColor: C.brand,
            onChanged: (v) => setState(() => _paras = v.round()),
          ),
          ToolButton(
            label: '生成文本',
            icon: Icons.text_snippet_rounded,
            onPressed: _gen,
          ),
          if (_out.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ToolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      _out,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.8,
                        color: context.t1,
                      ),
                    ),
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
                          Text(
                            '复制全文',
                            style: Ty.tiny.copyWith(color: context.t3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────── ⑩ ASCII 码表 / 字符查询 ───────────────
class AsciiPage extends StatefulWidget {
  const AsciiPage({super.key});
  @override
  State<AsciiPage> createState() => _AsciiPageState();
}

class _AsciiPageState extends State<AsciiPage> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.text;
    return ToolScaffold(
      title: '字符编码',
      subtitle: '字符 ↔ ASCII / Unicode 码点',

      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '输入字符',
            hint: '例：A 或 中文',
            icon: Icons.abc_rounded,
            onChanged: (_) => setState(() {}),
          ),
          if (s.isNotEmpty)
            ToolCard(
              child: Column(
                children: s.runes
                    .take(30)
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 46,
                              child: Text(
                                String.fromCharCode(r),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: C.brand,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Unicode U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}',
                                style: Ty.small.copyWith(color: context.t1),
                              ),
                            ),
                            Text(
                              '十进制 $r',
                              style: Ty.tiny.copyWith(color: context.t3),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '常用 ASCII',
                  style: Ty.small.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children:
                      [
                            'A:65',
                            'Z:90',
                            'a:97',
                            'z:122',
                            '0:48',
                            '9:57',
                            '空格:32',
                            '换行:10',
                            '制表:9',
                          ]
                          .map(
                            (e) => Text(
                              e,
                              style: Ty.tiny.copyWith(color: context.t3),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
