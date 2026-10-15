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
// 工具箱 · 第七批（1015）：生成器 + 实用查询
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 倒计时/计时器组 ───────────────
class TimerPage extends StatefulWidget {
  const TimerPage({super.key});
  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final _h = TextEditingController(text: '0');
  final _m = TextEditingController(text: '5');
  final _s = TextEditingController(text: '0');
  bool _running = false;
  int _left = 0;
  int _total = 0;

  @override
  void dispose() {
    _h.dispose();
    _m.dispose();
    _s.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final h = int.tryParse(_h.text) ?? 0;
    final m = int.tryParse(_m.text) ?? 0;
    final s = int.tryParse(_s.text) ?? 0;
    final t = h * 3600 + m * 60 + s;
    if (t <= 0) return ToastUtil.info('请设置时间');
    setState(() {
      _total = t;
      _left = t;
      _running = true;
    });
    while (_left > 0 && mounted && _running) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_running) return;
      setState(() => _left--);
    }
    if (mounted && _running) {
      setState(() => _running = false);
      ToastUtil.success('时间到！');
    }
  }

  String get _fmt {
    final h = _left ~/ 3600;
    final m = (_left % 3600) ~/ 60;
    final s = _left % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '定时器',
      subtitle: '倒计时提醒（时/分/秒）',
      
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ToolField(controller: _h, label: '时', keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _m, label: '分', keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _s, label: '秒', keyboard: TextInputType.number)),
            ],
          ),
          if (_running || _left > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: Deco.brandGradient,
                borderRadius: BorderRadius.circular(R.lg),
              ),
              child: Column(
                children: [
                  Text(_fmt,
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1, letterSpacing: 2)),
                  if (_total > 0) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _total == 0 ? 0 : 1 - _left / _total,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!_running)
            ToolButton(label: '开始倒计时', icon: Icons.play_arrow_rounded, onPressed: _start)
          else
            ToolButton(
              label: '停止',
              icon: Icons.stop_rounded,
              outline: true,
              onPressed: () => setState(() => _running = false),
            ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('常用快捷', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 3, 5, 10, 15, 30, 60]
                      .map<Widget>((m) => AppPressable(
                            onTap: () => setState(() {
                              _h.text = '0';
                              _m.text = '$m';
                              _s.text = '0';
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                              decoration: BoxDecoration(
                                color: C.brand.withAlpha(context.isDark ? 30 : 14),
                                borderRadius: BorderRadius.circular(R.full),
                              ),
                              child: Text('$m 分钟',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.brand)),
                            ),
                          ))
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

// ─────────────── ② 掷骰子 / 转盘 ───────────────
class DicePage extends StatefulWidget {
  const DicePage({super.key});
  @override
  State<DicePage> createState() => _DicePageState();
}

class _DicePageState extends State<DicePage> {
  int _count = 1;
  int _faces = 6;
  List<int> out = [];

  void _roll() {
    final r = math.Random.secure();
    setState(() => out = List.generate(_count, (_) => r.nextInt(_faces) + 1));
  }

  @override
  Widget build(BuildContext context) {
    const dice = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    return ToolScaffold(
      title: '掷骰子',
      subtitle: '随机点数 / 多骰同掷',
      scrollable: true,
      child: Column(
        children: [
          ToolChips<int>(
            items: const [(1, '1 个'), (2, '2 个'), (3, '3 个'), (5, '5 个')],
            current: _count,
            onPick: (v) => setState(() => _count = v),
          ),
          const SizedBox(height: 10),
          ToolChips<int>(
            items: const [(6, '6 面'), (10, '10 面'), (20, '20 面'), (100, '100 面')],
            current: _faces,
            onPick: (v) => setState(() => _faces = v),
          ),
          const SizedBox(height: 16),
          ToolButton(label: '掷骰子', icon: Icons.casino_rounded, onPressed: _roll),
          if (out.isNotEmpty) ...[
            const SizedBox(height: 18),
            if (_faces == 6)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: out
                    .map<Widget>((n) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(dice[n - 1], style: TextStyle(fontSize: 52, color: C.brand)),
                        ))
                    .toList(),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: out
                    .map<Widget>((n) => Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: Deco.brandGradient,
                            borderRadius: BorderRadius.circular(R.md),
                          ),
                          child: Text('$n',
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 14),
            Text('合计：${out.fold<int>(0, (a, b) => a + b)}',
                style: Ty.small.copyWith(fontWeight: FontWeight.w800, color: context.t2)),
          ],
        ],
      ),
    );
  }
}

// ─────────────── ③ 决策转盘（帮我决定） ───────────────
class DecidePage extends StatefulWidget {
  const DecidePage({super.key});
  @override
  State<DecidePage> createState() => _DecidePageState();
}

class _DecidePageState extends State<DecidePage> {
  final _c = TextEditingController(text: '吃饭\n睡觉\n打豆豆\n再想想');
  String _out = '';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pick() {
    final opts = _c.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (opts.isEmpty) return ToastUtil.info('请输入选项（每行一个）');
    setState(() => _out = opts[math.Random().nextInt(opts.length)]);
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '帮我决定',
      subtitle: '选择困难症救星',
      scrollable: true,
      child: Column(
        children: [
          ToolField(controller: _c, label: '选项（每行一个）', lines: 6, icon: Icons.list_rounded),
          ToolButton(label: '帮我选一个', icon: Icons.shuffle_rounded, onPressed: _pick),
          if (_out.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: Deco.brandGradient,
                borderRadius: BorderRadius.circular(R.lg),
                boxShadow: [BoxShadow(color: C.brand.withAlpha(80), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  const Text('就选它', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(_out,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.3)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────── ④ 时间校准（网络时间） ───────────────
class ClockPage extends StatefulWidget {
  const ClockPage({super.key});
  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    // ★ 1015：加「是否在顶层页面」判断，被其他页面盖住时不重建（省电、防卡）
    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent == false) continue;
      setState(() => _now = DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = ['一', '二', '三', '四', '五', '六', '日'][_now.weekday - 1];
    return ToolScaffold(
      title: '时钟',
      subtitle: '当前时间（每秒刷新）',
      scrollable: true,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34),
            decoration: BoxDecoration(
              gradient: Deco.brandGradient,
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              children: [
                Text(
                  '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1, letterSpacing: 2),
                ),
                const SizedBox(height: 10),
                Text('${_now.year}年${_now.month}月${_now.day}日 星期$w',
                    style: const TextStyle(fontSize: 13.5, color: Colors.white70, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _r('Unix 时间戳（秒）', '${_now.millisecondsSinceEpoch ~/ 1000}'),
                _r('Unix 时间戳（毫秒）', '${_now.millisecondsSinceEpoch}'),
                _r('今年第几天', _dayOfYear(_now)),
                _r('今年剩余', '${365 - int.parse(_dayOfYear(_now))} 天'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('基于设备本地时间，系统不准可在设置里开启自动校准', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  static String _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return '${d.difference(start).inDays + 1}';
  }

  Widget _r(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.t1, fontFamily: 'monospace')),
          ],
        ),
      );
}

// ─────────────── ⑤ 骰子/抽签之外的：转盘分组 ───────────────
class GroupPage extends StatefulWidget {
  const GroupPage({super.key});
  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final _c = TextEditingController(text: '张三\n李四\n王五\n赵六\n钱七\n孙八');
  final _n = TextEditingController(text: '2');
  List<List<String>> result = [];

  @override
  void dispose() {
    _c.dispose();
    _n.dispose();
    super.dispose();
  }

  void _split() {
    final names = _c.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final g = int.tryParse(_n.text) ?? 2;
    if (names.isEmpty) return ToastUtil.info('请输入名单');
    if (g < 2) return ToastUtil.info('至少分 2 组');
    names.shuffle(math.Random());
    final res = List.generate(g, (_) => <String>[]);
    for (var i = 0; i < names.length; i++) {
      res[i % g].add(names[i]);
    }
    setState(() => result = res);
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '随机分组',
      subtitle: '抽签分组 / 团队分配',
      
      child: Column(
        children: [
          ToolField(controller: _c, label: '名单（每行一个）', lines: 6, icon: Icons.groups_rounded),
          Row(
            children: [
              Expanded(child: ToolField(controller: _n, label: '分成几组', keyboard: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: ToolButton(label: '开始分组', icon: Icons.shuffle_rounded, onPressed: _split)),
            ],
          ),
          if (result.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...List.generate(result.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ToolCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: Deco.brandGradient,
                              borderRadius: BorderRadius.circular(R.full),
                            ),
                            child: Text('第 ${i + 1} 组',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          const Spacer(),
                          Text('${result[i].length} 人', style: Ty.tiny.copyWith(color: context.t3)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(result[i].join('、'), style: Ty.small.copyWith(color: context.t1, height: 1.7)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─────────────── ⑥ 简易秒表（多组计时） ───────────────
class LapTimerPage extends StatefulWidget {
  const LapTimerPage({super.key});
  @override
  State<LapTimerPage> createState() => _LapTimerPageState();
}

class _LapTimerPageState extends State<LapTimerPage> {
  final _sw = Stopwatch();
  final List<int> laps = [];
  bool _run = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    // ★ 1015：原来 100ms 刷新一次（每秒 10 次整页重建）→ 页面卡顿。
    //   改为 200ms，且只在「计时中」才重建，暂停时不重建。
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      if (_sw.isRunning && mounted) setState(() {});
    }
  }

  String _fmt(int ms) {
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final c = (ms % 1000) ~/ 10;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${c.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '秒表计次',
      subtitle: '带计次（Lap）的秒表',
      
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              gradient: Deco.brandGradient,
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Text(_fmt(_sw.elapsedMilliseconds),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: _run ? '暂停' : '开始',
                  icon: _run ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onPressed: () {
                    setState(() {
                      if (_sw.isRunning) {
                        _sw.stop();
                        _run = false;
                      } else {
                        _sw.start();
                        _run = true;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: '计次',
                  icon: Icons.flag_rounded,
                  outline: true,
                  onPressed: () => setState(() => laps.insert(0, _sw.elapsedMilliseconds)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ToolButton(
            label: '重置',
            icon: Icons.refresh_rounded,
            outline: true,
            onPressed: () => setState(() {
              _sw.reset();
              _sw.stop();
              _run = false;
              laps.clear();
            }),
          ),
          if (laps.isNotEmpty) ...[
            const SizedBox(height: 14),
            ToolCard(
              child: Column(
                children: laps.asMap().entries.map((e) {
                  final prev = e.key + 1 < laps.length ? laps[e.key + 1] : 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 50, child: Text('第 ${laps.length - e.key} 次', style: Ty.tiny.copyWith(color: context.t3))),
                        Expanded(child: Text(_fmt(e.value), style: Ty.small.copyWith(color: context.t1, fontFamily: 'monospace'))),
                        Text('+${_fmt(e.value - prev)}', style: Ty.tiny.copyWith(color: C.brand)),
                      ],
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
}

// ─────────────── ⑦ 屏幕尺子 ───────────────
class RulerPage extends StatelessWidget {
  const RulerPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '刻度尺',
      subtitle: '屏幕直尺（横/竖）',
      scrollable: true,
      child: Column(
        children: [
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('横向刻度（单位：cm 参考值）', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: LayoutBuilder(
                    builder: (ctx, c) => CustomPaint(
                      size: Size(c.maxWidth, 46),
                      painter: _RulerPainter(C.brand, context.isDark ? Colors.white70 : Colors.black87),
                    ),
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
                Text('说明', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  '· 不同设备屏幕像素密度不同，显示长度会有偏差\n'
                  '· 可用于粗略比较物体长度\n'
                  '· 需要精确测量请使用实体尺',
                  style: Ty.tiny.copyWith(color: context.t3, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final Color line;
  final Color text;
  _RulerPainter(this.line, this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = line
      ..strokeWidth = 1;
    // 假设 1cm ≈ 38 逻辑像素（约 160dpi 常见值）
    const cm = 38.0;
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final isCm = i % 10 == 0;
      final isHalf = i % 5 == 0;
      final h = isCm ? 26.0 : (isHalf ? 18.0 : 10.0);
      canvas.drawLine(Offset(x, 0), Offset(x, h), p);
      if (isCm) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${i ~/ 10}',
            style: TextStyle(fontSize: 10, color: text),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, 27));
      }
      x += cm / 10;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
