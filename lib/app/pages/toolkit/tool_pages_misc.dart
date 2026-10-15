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
// 工具箱 · 第九批（1015）：补齐 150 个真工具
// ═══════════════════════════════════════════════════════════════

// ─────────────── ① 鞋码对照表 ───────────────
class ShoeSizePage extends StatelessWidget {
  const ShoeSizePage({super.key});
  @override
  Widget build(BuildContext context) {
    final rows = List.generate(17, (i) {
      final cm = 22.0 + i * 0.5;
      final cn = cm * 2 - 10;
      return (cm, cn, cn + 0.5, cn - 18 + 0.5, cn - 18 - 0.5);
    });
    return ToolScaffold(
      title: '鞋码对照表',
      subtitle: '各国鞋码全表',
      scrollable: true,
      child: Column(
        children: [
          ToolCard(
            child: Column(
              children: [
                Row(
                  children: [
                    _th(context, '脚长cm', 1.2),
                    _th(context, '中国', 1),
                    _th(context, '欧洲', 1),
                    _th(context, '美国', 1),
                    _th(context, '英国', 1),
                  ],
                ),
                const Divider(height: 16),
                ...rows.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          _td(context, r.$1.toStringAsFixed(1), 1.2, bold: true),
                          _td(context, r.$2.toStringAsFixed(0), 1),
                          _td(context, r.$3.toStringAsFixed(1), 1),
                          _td(context, r.$4.toStringAsFixed(1), 1),
                          _td(context, r.$5.toStringAsFixed(1), 1),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('注：不同品牌有差异，建议以脚长为准', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  Widget _th(BuildContext context, String s, double f) => Expanded(
        flex: (f * 10).round(),
        child: Text(s, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.brand)),
      );

  Widget _td(BuildContext context, String s, double f, {bool bold = false}) => Expanded(
        flex: (f * 10).round(),
        child: Text(s,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              color: context.t1,
            )),
      );
}

// ─────────────── ② 衣服尺码 ───────────────
class ClothSizePage extends StatelessWidget {
  const ClothSizePage({super.key});
  @override
  Widget build(BuildContext context) {
    const data = [
      ('S', '160-165', '84-88', '66-70'),
      ('M', '165-170', '88-92', '70-74'),
      ('L', '170-175', '92-96', '74-78'),
      ('XL', '175-180', '96-100', '78-82'),
      ('2XL', '180-185', '100-104', '82-86'),
      ('3XL', '185-190', '104-108', '86-90'),
      ('4XL', '190-195', '108-112', '90-94'),
    ];
    return ToolScaffold(
      title: '衣服尺码',
      subtitle: '男装上装参考表',
      
      child: Column(
        children: [
          ToolCard(
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: Text('尺码', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.brand))),
                  Expanded(child: Text('身高cm', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.brand))),
                  Expanded(child: Text('胸围cm', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.brand))),
                  Expanded(child: Text('腰围cm', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.brand))),
                ]),
                const Divider(height: 16),
                ...data.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(r.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.t1))),
                          Expanded(child: Text(r.$2, style: Ty.small.copyWith(color: context.t2))),
                          Expanded(child: Text(r.$3, style: Ty.small.copyWith(color: context.t2))),
                          Expanded(child: Text(r.$4, style: Ty.small.copyWith(color: context.t2))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('女装尺码差异较大，建议按各品牌尺码表选购', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }
}

// ─────────────── ③ 血压/心率记录评估 ───────────────
class BpPage extends StatefulWidget {
  const BpPage({super.key});
  @override
  State<BpPage> createState() => _BpPageState();
}

class _BpPageState extends State<BpPage> {
  final _sys = TextEditingController(text: '120');
  final _dia = TextEditingController(text: '80');
  final _hr = TextEditingController(text: '72');

  @override
  void dispose() {
    _sys.dispose();
    _dia.dispose();
    _hr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = int.tryParse(_sys.text) ?? 0;
    final d = int.tryParse(_dia.text) ?? 0;
    final hr = int.tryParse(_hr.text) ?? 0;
    String level = '';
    Color color = C.success;
    if (s == 0 || d == 0) {
      level = '—';
    } else if (s < 90 || d < 60) {
      level = '偏低';
      color = C.warning;
    } else if (s < 120 && d < 80) {
      level = '理想';
    } else if (s < 130 && d < 85) {
      level = '正常';
    } else if (s < 140 || d < 90) {
      level = '正常偏高';
      color = C.warning;
    } else if (s < 160 || d < 100) {
      level = '1 级高血压';
      color = C.danger;
    } else {
      level = '2 级及以上';
      color = C.danger;
    }
    String hrLevel = hr == 0 ? '—' : (hr < 60 ? '偏慢' : (hr <= 100 ? '正常' : '偏快'));
    return ToolScaffold(
      title: '血压评估',
      subtitle: '按中国高血压指南分级',
      
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ToolField(controller: _sys, label: '收缩压', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _dia, label: '舒张压', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: ToolField(controller: _hr, label: '心率', keyboard: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          ToolCard(
            child: Column(
              children: [
                _r('血压值', '$s / $d mmHg'),
                _r('评估', level, color: color, big: true),
                const Divider(height: 20),
                _r('心率', '$hr 次/分 · $hrLevel'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('参考标准', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '理想：<120 / <80\n'
                  '正常：<130 / <85\n'
                  '正常偏高：130-139 / 85-89\n'
                  '1 级高血压：140-159 / 90-99\n'
                  '2 级高血压：≥160 / ≥100',
                  style: Ty.tiny.copyWith(color: context.t3, height: 1.8),
                ),
                const SizedBox(height: 8),
                Text('⚠ 仅供参考，异常请就医', style: Ty.tiny.copyWith(color: C.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {Color? color, bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 18 : 15, fontWeight: FontWeight.w900, color: color ?? context.t1)),
          ],
        ),
      );
}

// ─────────────── ④ 视力换算（近视度数） ───────────────
class VisionPage extends StatefulWidget {
  const VisionPage({super.key});
  @override
  State<VisionPage> createState() => _VisionPageState();
}

class _VisionPageState extends State<VisionPage> {
  final _c = TextEditingController(text: '4.8');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(_c.text) ?? 0;
    // 对数视力表 ↔ 小数记录 ↔ 约等度数
    const table = [
      (5.3, 2.0, 0), (5.2, 1.5, 0), (5.1, 1.2, 0), (5.0, 1.0, 0),
      (4.9, 0.8, 50), (4.8, 0.6, 100), (4.7, 0.5, 150), (4.6, 0.4, 200),
      (4.5, 0.3, 250), (4.4, 0.25, 300), (4.3, 0.2, 350), (4.2, 0.15, 400),
      (4.1, 0.12, 450), (4.0, 0.1, 500),
    ];
    final row = table.where((e) => (e.$1 - v).abs() < 0.05).toList();
    return ToolScaffold(
      title: '视力换算',
      subtitle: '对数视力 ↔ 小数 ↔ 约等度数',
      
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '对数视力（如 4.8 / 5.0）',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.remove_red_eye_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: row.isEmpty
                ? Text('请输入 4.0 - 5.3 之间的数值', style: Ty.small.copyWith(color: context.t3))
                : Column(
                    children: [
                      _r('对数视力', row.first.$1.toStringAsFixed(1)),
                      _r('小数记录', row.first.$2.toString()),
                      _r('约等度数', row.first.$3 == 0 ? '正常视力' : '约 ${row.first.$3} 度', big: true),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('对照表', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...table.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.$1.toStringAsFixed(1), style: Ty.tiny.copyWith(color: context.t3))),
                          Expanded(child: Text(e.$2.toString(), style: Ty.tiny.copyWith(color: context.t3))),
                          Expanded(
                            child: Text(e.$3 == 0 ? '正常' : '${e.$3} 度',
                                style: Ty.tiny.copyWith(color: context.t2, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('注：度数为粗略换算，实际需专业验光', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  Widget _r(String k, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: big ? 18 : 15, fontWeight: FontWeight.w900, color: big ? C.brand : context.t1)),
          ],
        ),
      );
}

// ─────────────── ⑤ 生肖/天干地支 ───────────────
class ZodiacPage extends StatefulWidget {
  const ZodiacPage({super.key});
  @override
  State<ZodiacPage> createState() => _ZodiacPageState();
}

class _ZodiacPageState extends State<ZodiacPage> {
  final _c = TextEditingController(text: '1995');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _z = ['鼠', '牛', '虎', '兔', '龙', '蛇', '马', '羊', '猴', '鸡', '狗', '猪'];
  static const _g = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
  static const _b = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];

  @override
  Widget build(BuildContext context) {
    final y = int.tryParse(_c.text) ?? 1990;
    final zi = (y - 4) % 12;
    final gi = (y - 4) % 10;
    return ToolScaffold(
      title: '生肖干支',
      subtitle: '按年份查生肖与天干地支',
      scrollable: true,
      child: Column(
        children: [
          ToolField(
            controller: _c,
            label: '年份（如 1995）',
            keyboard: TextInputType.number,
            icon: Icons.pets_rounded,
            onChanged: (_) => setState(() {}),
          ),
          ToolCard(
            child: Column(
              children: [
                Text('生肖', style: Ty.tiny.copyWith(color: context.t3)),
                const SizedBox(height: 4),
                Text(_z[zi < 0 ? zi + 12 : zi],
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: C.brand, height: 1.2)),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _r('天干地支', '${_g[gi < 0 ? gi + 10 : gi]}${_b[zi < 0 ? zi + 12 : zi]}年'),
                _r('干支序号', '第 ${((y - 4) % 60 + 60) % 60 + 1} 位'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('十二生肖顺序', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: List.generate(12, (i) {
                    final yy = 4 + i;
                    return Text('$yy ${_z[i]}', style: Ty.tiny.copyWith(color: context.t3));
                  }),
                ),
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
            Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
            Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
          ],
        ),
      );
}

// ─────────────── ⑥ 农历春节日期表 ───────────────
class SpringFestivalPage extends StatelessWidget {
  const SpringFestivalPage({super.key});
  @override
  Widget build(BuildContext context) {
    const data = [
      (2024, '2月10日', '龙'), (2025, '1月29日', '蛇'), (2026, '2月17日', '马'),
      (2027, '2月6日', '羊'), (2028, '1月26日', '猴'), (2029, '2月13日', '鸡'),
      (2030, '2月3日', '狗'), (2031, '1月23日', '猪'), (2032, '2月11日', '鼠'),
      (2033, '1月31日', '牛'), (2034, '2月19日', '虎'), (2035, '2月8日', '兔'),
    ];
    return ToolScaffold(
      title: '春节日期表',
      subtitle: '未来各年春节与生肖',
      
      child: ToolCard(
        child: Column(
          children: [
            Row(children: [
              Expanded(child: Text('年份', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.brand))),
              Expanded(child: Text('春节（正月初一）', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.brand))),
              Expanded(child: Text('生肖', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.brand))),
            ]),
            const Divider(height: 16),
            ...data.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('${e.$1}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: context.t1))),
                      Expanded(child: Text(e.$2, style: Ty.small.copyWith(color: context.t2))),
                      Expanded(child: Text('${e.$3}年', style: Ty.small.copyWith(color: C.brand, fontWeight: FontWeight.w800))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────── ⑦ 快递公司对照 ───────────────
class ExpressCoPage extends StatelessWidget {
  const ExpressCoPage({super.key});
  @override
  Widget build(BuildContext context) {
    const data = [
      ('顺丰速运', '95338', 'SF'), ('中通快递', '95311', 'ZTO'),
      ('圆通速递', '95554', 'YTO'), ('韵达快递', '95546', 'YD'),
      ('申通快递', '95543', 'STO'), ('邮政EMS', '11183', 'EMS'),
      ('京东物流', '950616', 'JD'), ('德邦快递', '95353', 'DBL'),
      ('极兔速递', '400-820-2222', 'JT'), ('百世快递', '95320', 'HTKY'),
      ('天天快递', '400-188-8888', 'HHTT'), ('菜鸟裹裹', '—', 'CAINIAO'),
    ];
    return ToolScaffold(
      title: '快递公司',
      subtitle: '常用快递客服电话',
      
      child: ToolCard(
        child: Column(
          children: data
              .map<Widget>((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(e.$1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.t1)),
                        ),
                        Expanded(
                          flex: 4,
                          child: GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: e.$2));
                              ToastUtil.success('已复制 ${e.$2}');
                            },
                            child: Text(e.$2, style: Ty.small.copyWith(color: C.brand, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Text(e.$3, style: Ty.tiny.copyWith(color: context.t3)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────── ⑧ 常见单位口语对照 ───────────────
class SlangUnitPage extends StatelessWidget {
  const SlangUnitPage({super.key});
  @override
  Widget build(BuildContext context) {
    const data = [
      ('一打', '12 个'), ('一罗', '144 个'), ('一令（纸）', '500 张'),
      ('一打兰', '1.772 克'), ('一英亩', '4046.86 ㎡'), ('一桶（油）', '158.98 升'),
      ('一加仑（美）', '3.785 升'), ('一盎司', '28.35 克'), ('一磅', '453.59 克'),
      ('一英里', '1.609 公里'), ('一海里', '1.852 公里'), ('一克拉', '0.2 克'),
      ('一码', '0.9144 米'), ('一英尺', '30.48 厘米'), ('一英寸', '2.54 厘米'),
      ('一亩', '666.67 ㎡'), ('一公顷', '15 亩'), ('一旬', '10 天'),
      ('一季', '3 个月'), ('一甲子', '60 年'),
    ];
    return ToolScaffold(
      title: '常用单位口语',
      subtitle: '一打/一罗/一桶到底是几个',
      
      child: ToolCard(
        child: Column(
          children: data
              .map<Widget>((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(e.$1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.t1)),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(e.$2, style: Ty.small.copyWith(color: C.brand, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────── ⑨ 麻将/扑克牌数字谐音 ───────────────
class NumSlangPage extends StatelessWidget {
  const NumSlangPage({super.key});
  @override
  Widget build(BuildContext context) {
    const data = [
      ('520', '我爱你'), ('521', '我愿意'), ('1314', '一生一世'),
      ('5201314', '我爱你一生一世'), ('7758', '亲亲我吧'), ('886', '拜拜了'),
      ('88', '拜拜'), ('666', '牛牛牛/厉害'), ('233', '哈哈哈'),
      ('9494', '就是就是'), ('7456', '气死我了'), ('918', '加油吧'),
      ('250', '傻瓜'), ('38', '三八'), ('748', '去死吧'),
      ('596', '我走了'), ('56', '无聊'), ('360', '想念你'),
      ('04551', '你是我唯一'), ('20184', '爱你一辈子'),
    ];
    return ToolScaffold(
      title: '数字谐音',
      subtitle: '常见数字暗语对照',
      
      child: ToolCard(
        child: Column(
          children: data
              .map<Widget>((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(e.$1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: C.brand,
                                fontFamily: 'monospace',
                              )),
                        ),
                        Expanded(child: Text(e.$2, style: Ty.small.copyWith(color: context.t1))),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────── ⑩ 时间管理：番茄钟 ───────────────
class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});
  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  int _work = 25;
  int _rest = 5;
  int _left = 25 * 60;
  bool _running = false;
  bool _isWork = true;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _left = _work * 60;
  }

  Future<void> _run() async {
    if (_running) {
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    while (_left > 0 && mounted && _running) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_running) return;
      setState(() => _left--);
    }
    if (!mounted || !_running) return;
    // 切换阶段
    if (_isWork) {
      setState(() {
        _done++;
        _isWork = false;
        _left = _rest * 60;
      });
      ToastUtil.success('专注完成！休息 $_rest 分钟');
    } else {
      setState(() {
        _isWork = true;
        _left = _work * 60;
      });
      ToastUtil.success('休息结束，继续专注');
    }
    if (mounted) _run();
  }

  String get _fmt {
    final m = _left ~/ 60;
    final s = _left % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = (_isWork ? _work : _rest) * 60;
    return ToolScaffold(
      title: '番茄钟',
      subtitle: '专注 / 休息循环',
      
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isWork ? [const Color(0xFFFF6B6B), const Color(0xFFFF3B30)] : [const Color(0xFF4ADE80), const Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              children: [
                Text(_isWork ? '专注中' : '休息中',
                    style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(_fmt,
                    style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white, height: 1, fontFamily: 'monospace')),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 46),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : 1 - _left / total,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ToolButton(
                  label: _running ? '暂停' : '开始',
                  icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onPressed: _run,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToolButton(
                  label: '重置',
                  icon: Icons.refresh_rounded,
                  outline: true,
                  onPressed: () => setState(() {
                    _running = false;
                    _isWork = true;
                    _left = _work * 60;
                    _done = 0;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _r('已完成番茄', '$_done 个'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _setter('专注时长', _work, (v) => setState(() { _work = v; if (_isWork && !_running) _left = v * 60; }))),
                    const SizedBox(width: 14),
                    Expanded(child: _setter('休息时长', _rest, (v) => setState(() { _rest = v; if (!_isWork && !_running) _left = v * 60; }))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setter(String label, int v, ValueChanged<int> on) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label：$v 分', style: Ty.small.copyWith(fontWeight: FontWeight.w800)),
          Slider(
            value: v.toDouble(),
            min: 1,
            max: 60,
            activeColor: C.brand,
            onChanged: (x) => on(x.round()),
          ),
        ],
      );

  Widget _r(String k, String v) => Row(
        children: [
          Expanded(child: Text(k, style: Ty.small.copyWith(color: context.t3))),
          Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.brand)),
        ],
      );
}
