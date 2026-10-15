import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_kit.dart';

/// ═══════════════════════════════════════════════════════════════
/// 工具箱 · 本地工具（v3.3.4）—— 纯 Dart，不联网，打开即用
///
/// 二维码 / 秒表 / 倒计时 / 单位换算 / BMI / 房贷 / Base64 /
/// 随机数 / 密码生成 / 亲戚称呼
/// ═══════════════════════════════════════════════════════════════

// ─────────────── 二维码生成 ───────────────
class QrcodePage extends StatefulWidget {
  const QrcodePage({super.key});
  @override
  State<QrcodePage> createState() => _QrcodePageState();
}

class _QrcodePageState extends State<QrcodePage> {
  final _ctrl = TextEditingController(text: 'https://www.52yfx.cn');
  String _data = 'https://www.52yfx.cn';
  double _size = 220;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '二维码生成',
      subtitle: '输入内容即时生成',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _ctrl,
            label: '内容',
            hint: '网址 / 文本 / 联系方式',
            icon: Icons.link_rounded,
            lines: 3,
            onChanged: (v) => setState(() => _data = v.trim()),
          ),
          const SizedBox(height: 16),
          Center(
            child: ToolCard(
              padding: const EdgeInsets.all(18),
              child: _data.isEmpty
                  ? SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Text(
                          '请输入内容',
                          style: Ty.small.copyWith(color: context.t3),
                        ),
                      ),
                    )
                  : QrImageView(
                      data: _data,
                      version: QrVersions.auto,
                      size: _size,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Slider(
            value: _size,
            min: 140,
            max: 300,
            activeColor: C.brand,
            label: '${_size.round()}px',
            onChanged: (v) => setState(() => _size = v),
          ),
        ],
      ),
    );
  }
}

// ─────────────── 秒表 ───────────────
class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});
  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  Timer? _timer;
  int _ms = 0;
  int _last = 0;
  final List<int> _laps = [];
  bool get _running => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _go() {
    _last = DateTime.now().millisecondsSinceEpoch;
    _timer = Timer.periodic(const Duration(milliseconds: 47), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() => _ms += now - _last);
      _last = now;
    });
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    setState(() {});
  }

  String _fmt(int ms) {
    final m = ms ~/ 60000;
    final s = (ms ~/ 1000) % 60;
    final c = (ms % 1000) ~/ 10;
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.'
        '${c.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '秒表',
      subtitle: '精度 0.01 秒 · 支持计次',
      child: Column(
        children: [
          const Spacer(),
          Text(
            _fmt(_ms),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: context.t1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: _ms == 0 ? '开始' : (_running ? '暂停' : '继续'),
                  icon: _running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: _running ? _pause : _go,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: _running ? '计次' : '重置',
                  icon: _running ? Icons.flag_rounded : Icons.refresh_rounded,
                  outline: true,
                  onPressed: () {
                    if (_running) {
                      setState(() => _laps.insert(0, _ms));
                    } else {
                      _pause();
                      setState(() {
                        _ms = 0;
                        _laps.clear();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _laps.isEmpty
                ? Center(
                    child: Text(
                      '点击「计次」记录分段',
                      style: Ty.small.copyWith(color: context.t3),
                    ),
                  )
                : ListView.separated(
                    itemCount: _laps.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: context.isDark
                          ? Colors.white.withAlpha(12)
                          : Colors.black.withAlpha(7),
                    ),
                    itemBuilder: (c, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          Text(
                            '第 ${_laps.length - i} 段',
                            style: Ty.small.copyWith(color: context.t2),
                          ),
                          const Spacer(),
                          Text(
                            _fmt(_laps[i]),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.t1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── 倒计时 ───────────────
class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});
  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  Timer? _timer;
  int _total = 300;
  int _left = 300;
  int _pick = 5;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      setState(() {});
      return;
    }
    if (_left <= 0) _left = _total;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        _timer = null;
        setState(() => _left = 0);
        HapticFeedback.heavyImpact();
        ToastUtil.success('时间到！');
        return;
      }
      setState(() => _left--);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pct = _total <= 0 ? 0.0 : _left / _total;
    return ToolScaffold(
      title: '倒计时',
      subtitle: '到点震动提醒',
      child: Column(
        children: [
          const SizedBox(height: 10),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 10,
                    backgroundColor: C.brand.withAlpha(24),
                    valueColor: AlwaysStoppedAnimation(C.brand),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_left ~/ 60).toString().padLeft(2, '0')}:'
                      '${(_left % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: context.t1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _timer == null ? '已暂停' : '计时中',
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: _timer == null ? '开始' : '暂停',
                  icon: _timer == null
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onPressed: _toggle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: '重置',
                  icon: Icons.refresh_rounded,
                  outline: true,
                  onPressed: () {
                    _timer?.cancel();
                    _timer = null;
                    setState(() => _left = _total);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('预设时长', style: Ty.h3.copyWith(color: context.t1)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1, 3, 5, 10, 15, 30, 60]
                .map(
                  (m) => AppPressable(
                    onTap: () {
                      _timer?.cancel();
                      _timer = null;
                      setState(() {
                        _pick = m;
                        _total = m * 60;
                        _left = _total;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _pick == m
                            ? C.brand.withAlpha(26)
                            : (context.isDark
                                  ? Colors.white.withAlpha(10)
                                  : Colors.white),
                        borderRadius: BorderRadius.circular(R.full),
                        border: Border.all(
                          color: _pick == m
                              ? C.brand.withAlpha(140)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '$m 分钟',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _pick == m ? C.brand : context.t2,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────── 单位换算 ───────────────
class UnitPage extends StatefulWidget {
  const UnitPage({super.key});
  @override
  State<UnitPage> createState() => _UnitPageState();
}

class _UnitPageState extends State<UnitPage> {
  static const _cats = <String, List<(String, double)>>{
    '长度': [
      ('毫米', 0.001),
      ('厘米', 0.01),
      ('米', 1),
      ('千米', 1000),
      ('英寸', 0.0254),
      ('英尺', 0.3048),
      ('英里', 1609.344),
    ],
    '重量': [
      ('毫克', 0.000001),
      ('克', 0.001),
      ('千克', 1),
      ('吨', 1000),
      ('磅', 0.4535924),
      ('盎司', 0.0283495),
    ],
    '面积': [('平方米', 1), ('平方千米', 1000000), ('公顷', 10000), ('亩', 666.6667)],
    '存储': [
      ('字节', 1),
      ('KB', 1024),
      ('MB', 1048576),
      ('GB', 1073741824),
      ('TB', 1099511627776),
    ],
    '时间': [('秒', 1), ('分钟', 60), ('小时', 3600), ('天', 86400), ('周', 604800)],
  };

  String _cat = '长度';
  int _from = 2;
  int _to = 3;
  final _ctrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _result {
    final u = _cats[_cat]!;
    final v = double.tryParse(_ctrl.text.trim()) ?? 0;
    return v * u[_from].$2 / u[_to].$2;
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    if (v.abs() >= 1e12 || (v.abs() < 1e-6 && v != 0)) {
      return v.toStringAsExponential(4);
    }
    return v
        .toStringAsFixed(6)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final units = _cats[_cat]!;
    return ToolScaffold(
      title: '单位换算',
      subtitle: '长度 / 重量 / 面积 / 存储 / 时间',
      
      child: Column(
        children: [
          ToolChips<String>(
            items: _cats.keys.map((k) => (k, k)).toList(),
            current: _cat,
            onPick: (k) => setState(() {
              _cat = k;
              _from = 0;
              _to = _cats[k]!.length > 1 ? 1 : 0;
            }),
          ),
          const SizedBox(height: 18),
          ToolCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.t1,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _picker(units.map((e) => e.$1).toList(), _from, (i) {
                      setState(() => _from = i);
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _line(context)),
                    AppPressable(
                      onTap: () => setState(() {
                        final t = _from;
                        _from = _to;
                        _to = t;
                      }),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: Deco.brandGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          size: 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(child: _line(context)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fmt(_result),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: C.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _picker(units.map((e) => e.$1).toList(), _to, (i) {
                      setState(() => _to = i);
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ToolButton(
            label: '复制结果',
            icon: Icons.copy_rounded,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _fmt(_result)));
              ToastUtil.success('已复制');
            },
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext c) => Container(
    height: 1,
    color: c.isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
  );

  Widget _picker(List<String> units, int cur, ValueChanged<int> onPick) =>
      PopupMenuButton<int>(
        initialValue: cur,
        onSelected: onPick,
        color: context.cardBg,
        itemBuilder: (c) => [
          for (int i = 0; i < units.length; i++)
            PopupMenuItem(
              value: i,
              child: Text(
                units[i],
                style: TextStyle(
                  fontSize: 14,
                  color: i == cur ? C.brand : context.t1,
                  fontWeight: i == cur ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(18),
            borderRadius: BorderRadius.circular(R.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                units[cur],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: C.brand,
                ),
              ),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: C.brand),
            ],
          ),
        ),
      );
}

// ─────────────── BMI 计算 ───────────────
class BmiPage extends StatefulWidget {
  const BmiPage({super.key});
  @override
  State<BmiPage> createState() => _BmiPageState();
}

class _BmiPageState extends State<BmiPage> {
  final _h = TextEditingController(text: '170');
  final _w = TextEditingController(text: '65');

  @override
  void dispose() {
    _h.dispose();
    _w.dispose();
    super.dispose();
  }

  double get _bmi {
    final h = (double.tryParse(_h.text.trim()) ?? 0) / 100;
    final w = double.tryParse(_w.text.trim()) ?? 0;
    return h <= 0 ? 0 : w / (h * h);
  }

  (String, Color) get _level {
    final b = _bmi;
    if (b <= 0) return ('请输入身高体重', C.brand);
    if (b < 18.5) return ('偏瘦', C.cyan);
    if (b < 24) return ('正常', C.success);
    if (b < 28) return ('超重', C.warning);
    return ('肥胖', C.danger);
  }

  @override
  Widget build(BuildContext context) {
    final lv = _level;
    return ToolScaffold(
      title: 'BMI 计算',
      subtitle: '中国成人标准',
      
      child: Column(
        children: [
          ToolField(
            controller: _h,
            label: '身高（厘米）',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.height_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolField(
            controller: _w,
            label: '体重（公斤）',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.monitor_weight_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          ToolCard(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                Text(
                  _bmi <= 0 ? '--' : _bmi.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: lv.$2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lv.$2.withAlpha(30),
                    borderRadius: BorderRadius.circular(R.full),
                  ),
                  child: Text(
                    lv.$1,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: lv.$2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('参考标准', style: Ty.h3.copyWith(color: context.t1)),
                const SizedBox(height: 10),
                for (final r in [
                  ('偏瘦', '< 18.5', C.cyan),
                  ('正常', '18.5 ~ 23.9', C.success),
                  ('超重', '24.0 ~ 27.9', C.warning),
                  ('肥胖', '≥ 28.0', C.danger),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: r.$3,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            r.$1,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: context.t2,
                            ),
                          ),
                        ),
                        Text(r.$2, style: Ty.small.copyWith(color: context.t3)),
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

// ─────────────── 房贷计算 ───────────────
class LoanPage extends StatefulWidget {
  const LoanPage({super.key});
  @override
  State<LoanPage> createState() => _LoanPageState();
}

class _LoanPageState extends State<LoanPage> {
  final _amt = TextEditingController(text: '100');
  final _years = TextEditingController(text: '30');
  final _rate = TextEditingController(text: '3.1');

  @override
  void dispose() {
    _amt.dispose();
    _years.dispose();
    _rate.dispose();
    super.dispose();
  }

  double get _p => (double.tryParse(_amt.text.trim()) ?? 0) * 10000;
  double get _n => (double.tryParse(_years.text.trim()) ?? 0) * 12;
  double get _r => (double.tryParse(_rate.text.trim()) ?? 0) / 100 / 12;

  double get _monthly {
    if (_p <= 0 || _n <= 0) return 0;
    if (_r <= 0) return _p / _n;
    return _p * _r * pow(1 + _r, _n) / (pow(1 + _r, _n) - 1);
  }

  double get _first {
    if (_p <= 0 || _n <= 0) return 0;
    return _p / _n + _p * _r;
  }

  double get _interest => _monthly * _n - _p;

  String _m(double v) => v <= 0 ? '--' : '${v.toStringAsFixed(2)} 元';

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '房贷计算',
      subtitle: '等额本息 / 等额本金',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _amt,
            label: '贷款金额（万元）',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.home_work_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolField(
            controller: _years,
            label: '贷款年限（年）',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.calendar_month_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolField(
            controller: _rate,
            label: '年利率（%）',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.percent_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('月供（等额本息）', style: Ty.h3.copyWith(color: context.t1)),
                const SizedBox(height: 8),
                Text(
                  _m(_monthly),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: C.brand,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: context.isDark
                      ? Colors.white.withAlpha(14)
                      : Colors.black.withAlpha(8),
                ),
                const SizedBox(height: 12),
                Text('首月（等额本金）', style: Ty.h3.copyWith(color: context.t1)),
                const SizedBox(height: 8),
                Text(
                  _m(_first),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.t2,
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
                Text(
                  '总利息（等额本息）',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
                const SizedBox(height: 4),
                Text(
                  _m(_interest),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: C.rose,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '结果仅供参考，实际以银行为准',
            style: Ty.tiny.copyWith(color: context.t3),
          ),
        ],
      ),
    );
  }
}

// ─────────────── Base64 编解码 ───────────────
class Base64Page extends StatefulWidget {
  const Base64Page({super.key});
  @override
  State<Base64Page> createState() => _Base64PageState();
}

class _Base64PageState extends State<Base64Page> {
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
      title: 'Base64',
      subtitle: '编码 / 解码（UTF-8）',
      
      child: Column(
        children: [
          ToolField(
            controller: _in,
            label: '原文',
            hint: '要编码的文本，或要解码的 Base64',
            icon: Icons.text_fields_rounded,
            lines: 5,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: '编码',
                  icon: Icons.arrow_downward_rounded,
                  onPressed: () {
                    try {
                      setState(
                        () => _out.text = base64Encode(utf8.encode(_in.text)),
                      );
                    } catch (_) {
                      ToastUtil.error('编码失败');
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: '解码',
                  icon: Icons.arrow_upward_rounded,
                  outline: true,
                  onPressed: () {
                    try {
                      setState(
                        () => _out.text = utf8.decode(
                          base64Decode(_in.text.trim()),
                        ),
                      );
                    } catch (_) {
                      ToastUtil.error('解码失败：不是合法的 Base64');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
}

// ─────────────── 随机数生成 ───────────────
class RandomPage extends StatefulWidget {
  const RandomPage({super.key});
  @override
  State<RandomPage> createState() => _RandomPageState();
}

class _RandomPageState extends State<RandomPage> {
  final _min = TextEditingController(text: '1');
  final _max = TextEditingController(text: '100');
  final _n = TextEditingController(text: '1');
  List<int> _out = const [];
  final _rnd = Random.secure();

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _n.dispose();
    super.dispose();
  }

  void _gen({bool unique = false}) {
    final lo = int.tryParse(_min.text.trim()) ?? 0;
    final hi = int.tryParse(_max.text.trim()) ?? 100;
    final n = (int.tryParse(_n.text.trim()) ?? 1).clamp(1, 100);
    if (lo >= hi) {
      ToastUtil.error('最小值必须小于最大值');
      return;
    }
    final range = hi - lo + 1;
    if (unique && range < n) {
      ToastUtil.error('区间内只有 $range 个整数，不够取 $n 个不重复');
      return;
    }
    setState(() {
      if (unique) {
        final pool = List.generate(range, (i) => lo + i)..shuffle(_rnd);
        _out = pool.take(n).toList()..sort();
      } else {
        _out = List.generate(n, (_) => lo + _rnd.nextInt(range));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '随机数生成',
      subtitle: '批量 / 不重复',
      
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ToolField(
                  controller: _min,
                  label: '最小值',
                  keyboard: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolField(
                  controller: _max,
                  label: '最大值',
                  keyboard: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                ),
              ),
            ],
          ),
          ToolField(
            controller: _n,
            label: '个数（1~100）',
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: '生成',
                  icon: Icons.casino_rounded,
                  onPressed: _gen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: '不重复',
                  icon: Icons.filter_alt_rounded,
                  outline: true,
                  onPressed: () => _gen(unique: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_out.isNotEmpty)
            ToolCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _out
                    .map<Widget>(
                      (v) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: Deco.brandGradient,
                          borderRadius: BorderRadius.circular(R.md),
                        ),
                        child: Text(
                          '$v',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────── 密码生成 ───────────────
class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  static const _lo = 'abcdefghijkmnopqrstuvwxyz';
  static const _up = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _dg = '23456789';
  static const _sy = r'!@#$%^&*()-_=+[]{}';

  double _len = 16;
  bool _useLo = true, _useUp = true, _useDg = true, _useSy = true;
  String _pwd = '';
  final _rnd = Random.secure();

  @override
  void initState() {
    super.initState();
    _gen();
  }

  void _gen() {
    final b = StringBuffer();
    if (_useLo) b.write(_lo);
    if (_useUp) b.write(_up);
    if (_useDg) b.write(_dg);
    if (_useSy) b.write(_sy);
    if (b.isEmpty) {
      setState(() => _pwd = '');
      return;
    }
    final chars = b.toString();
    setState(
      () => _pwd = List.generate(
        _len.round(),
        (_) => chars[_rnd.nextInt(chars.length)],
      ).join(),
    );
  }

  int get _strength {
    var s = 0;
    if (_len >= 8) s++;
    if (_len >= 12) s++;
    if (_useUp && _useLo) s++;
    if (_useDg) s++;
    if (_useSy) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final st = _strength.clamp(0, 5);
    const labels = ['极弱', '弱', '一般', '较强', '强', '很强'];
    final colors = [C.danger, C.danger, C.warning, C.amber, C.success, C.success];
    return ToolScaffold(
      title: '密码生成',
      subtitle: '本地随机 · 不联网',
      
      child: Column(
        children: [
          ToolCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SelectableText(
                  _pwd.isEmpty ? '请至少选择一种字符' : _pwd,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                    letterSpacing: 0.5,
                    color: context.t1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(R.full),
                        child: LinearProgressIndicator(
                          value: (st + 1) / 6,
                          minHeight: 6,
                          backgroundColor: C.brand.withAlpha(20),
                          valueColor: AlwaysStoppedAnimation(colors[st]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      labels[st],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: colors[st],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ToolCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Text('长度', style: Ty.h3.copyWith(color: context.t1)),
                    const Spacer(),
                    Text(
                      '${_len.round()} 位',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: C.brand,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _len,
                  min: 6,
                  max: 32,
                  divisions: 26,
                  activeColor: C.brand,
                  onChanged: (v) => setState(() => _len = v),
                ),
                _sw('小写字母 a-z', _useLo, (v) => _useLo = v),
                _sw('大写字母 A-Z', _useUp, (v) => _useUp = v),
                _sw('数字 0-9', _useDg, (v) => _useDg = v),
                _sw('特殊符号', _useSy, (v) => _useSy = v),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: '重新生成',
                  icon: Icons.refresh_rounded,
                  onPressed: _gen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: '复制',
                  icon: Icons.copy_rounded,
                  outline: true,
                  onPressed: () {
                    if (_pwd.isEmpty) return;
                    Clipboard.setData(ClipboardData(text: _pwd));
                    ToastUtil.success('已复制到剪贴板');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sw(String label, bool v, ValueChanged<bool> set) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13.5, color: context.t2),
          ),
        ),
        Switch(
          value: v,
          activeThumbColor: C.brand,
          onChanged: (x) {
            setState(() => set(x));
            _gen();
          },
        ),
      ],
    ),
  );
}

// ─────────────── 亲戚称呼计算 ───────────────
class RelativePage extends StatefulWidget {
  const RelativePage({super.key});
  @override
  State<RelativePage> createState() => _RelativePageState();
}

class _RelativePageState extends State<RelativePage> {
  static const _map = <String, String>{
    '父亲的父亲': '爷爷',
    '父亲的母亲': '奶奶',
    '母亲的父亲': '姥爷',
    '母亲的母亲': '姥姥',
    '父亲的哥哥': '伯父',
    '父亲的弟弟': '叔叔',
    '父亲的姐姐': '姑姑',
    '父亲的妹妹': '姑姑',
    '父亲的儿子': '兄弟',
    '父亲的女儿': '姐妹',
    '母亲的哥哥': '舅舅',
    '母亲的弟弟': '舅舅',
    '母亲的姐姐': '姨妈',
    '母亲的妹妹': '小姨',
    '母亲的儿子': '兄弟',
    '母亲的女儿': '姐妹',
    '父亲的兄弟的儿子': '堂兄弟',
    '父亲的兄弟的女儿': '堂姐妹',
    '父亲的姐妹的儿子': '表兄弟',
    '父亲的姐妹的女儿': '表姐妹',
    '母亲的兄弟姐妹的儿子': '表兄弟',
    '母亲的兄弟姐妹的女儿': '表姐妹',
    '哥哥的妻子': '嫂子',
    '弟弟的妻子': '弟妹',
    '姐姐的丈夫': '姐夫',
    '妹妹的丈夫': '妹夫',
    '妻子的父亲': '岳父',
    '妻子的母亲': '岳母',
    '丈夫的父亲': '公公',
    '丈夫的母亲': '婆婆',
    '儿子的妻子': '儿媳',
    '女儿的丈夫': '女婿',
    '儿子的儿子': '孙子',
    '儿子的女儿': '孙女',
    '女儿的儿子': '外孙',
    '女儿的女儿': '外孙女',
    '哥哥的儿子': '侄子',
    '哥哥的女儿': '侄女',
    '弟弟的儿子': '侄子',
    '姐姐的儿子': '外甥',
    '姐姐的女儿': '外甥女',
    '父亲的父亲的父亲': '曾祖父',
    '父亲的父亲的母亲': '曾祖母',
    '母亲的母亲的母亲': '外曾祖母',
    '爷爷的父亲': '曾祖父',
    '爷爷的母亲': '曾祖母',
  };

  final _ctrl = TextEditingController();
  String _res = '';
  String _err = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _calc() {
    var raw = _ctrl.text.trim();
    raw = raw
        .replaceAll('我的', '')
        .replaceAll('我', '')
        .replaceAll('自己', '')
        .replaceAll('本人', '');
    raw = raw
        .replaceAll('爸爸', '父亲')
        .replaceAll('爸', '父亲')
        .replaceAll('妈妈', '母亲')
        .replaceAll('妈', '母亲')
        .replaceAll('哥', '哥哥')
        .replaceAll('姐', '姐姐')
        .replaceAll('弟', '弟弟')
        .replaceAll('妹', '妹妹');
    raw = raw.replaceAll(RegExp(r'[的\s]+'), '的');
    raw = raw.replaceAll(RegExp(r'^的+|的+$'), '');
    if (raw.isEmpty) {
      setState(() {
        _res = '';
        _err = '请输入关系，例如「父亲的父亲的儿子」';
      });
      return;
    }
    final hit = _map[raw];
    setState(() {
      if (hit != null) {
        _res = hit;
        _err = '';
      } else {
        _res = '';
        _err = '暂未收录「$raw」，换个说法试试';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '亲戚称呼计算',
      subtitle: '输入关系链，算出该怎么称呼',
      
      child: Column(
        children: [
          ToolField(
            controller: _ctrl,
            label: '关系',
            hint: '例：父亲的父亲的儿子 / 妈妈的姐姐',
            icon: Icons.family_restroom_rounded,
            onSubmitted: (_) => _calc(),
          ),
          const SizedBox(height: 6),
          ToolButton(
            label: '计算称呼',
            icon: Icons.search_rounded,
            onPressed: _calc,
          ),
          const SizedBox(height: 18),
          if (_res.isNotEmpty)
            ToolCard(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  Text('应该叫', style: Ty.small.copyWith(color: context.t3)),
                  const SizedBox(height: 10),
                  Text(
                    _res,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: C.brand,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          if (_err.isNotEmpty)
            ToolCard(
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 17, color: C.warning),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _err,
                      style: TextStyle(fontSize: 13, color: context.t2),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('常用示例', style: Ty.h3.copyWith(color: context.t1)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  '父亲的父亲的儿子',
                  '父亲的哥哥',
                  '母亲的妹妹',
                  '父亲的姐妹的儿子',
                  '妻子的母亲',
                  '爷爷的母亲',
                ].map(
                  (t) => AppPressable(
                    onTap: () {
                      _ctrl.text = t;
                      _calc();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: C.brand.withAlpha(14),
                        borderRadius: BorderRadius.circular(R.full),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(fontSize: 12.5, color: C.brand),
                      ),
                    ),
                  ),
                ).toList(),
          ),
        ],
      ),
    );
  }
}
