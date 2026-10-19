import 'package:flutter/material.dart';

import '../../design/app_anim.dart';
import '../../design/ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// 维护模式页 —— v3.3.4 共 5 款**骨架级**模板
///
/// 用户反馈「维护模式太简约」，旧版只有一个灰底图标 + 一行字。
/// 现在每款是不同的信息架构与视觉语言：
///
///   ① engineer  工程进度  深色 + 呼吸发光图标 + 阶段指示点
///   ② countdown 维护倒计时 金色徽标 + 进度条 + 左右时间轴
///   ③ glass     毛玻璃    双色光晕背景 + 模糊玻璃卡
///   ④ brand     品牌静默  LOGO + 品牌字 + 分割线（极简居中）
///   ⑤ checklist 服务清单  顶部提示条 + 维护事项编号列表
///
/// 由后台 sys_config.maintain_template 下发，取不到用 engineer。
/// ═══════════════════════════════════════════════════════════════
class MaintainPage extends StatefulWidget {
  /// 后台下发的维护文案（可能多行）
  final String text;

  /// 模板名：engineer / countdown / glass / brand / checklist
  final String template;

  /// 点击「重新加载」的回调
  final VoidCallback onReload;

  /// 品牌名（brand 模板展示用）
  final String appName;

  const MaintainPage({
    super.key,
    required this.text,
    required this.onReload,
    this.template = 'engineer',
    this.appName = '安逸软件汇',
  });

  @override
  State<MaintainPage> createState() => _MaintainPageState();
}

class _MaintainPageState extends State<MaintainPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  /// 维护文案：空则给默认；多行则拆行
  List<String> get _lines {
    final t = widget.text.trim().isEmpty ? '请稍后再试' : widget.text.trim();
    return t.split(RegExp(r'\r?\n')).where((e) => e.trim().isNotEmpty).toList();
  }

  String get _firstLine => _lines.isEmpty ? '请稍后再试' : _lines.first;

  List<String> get _restLines =>
      _lines.length <= 1 ? const [] : _lines.sublist(1);

  @override
  Widget build(BuildContext context) {
    return switch (widget.template) {
      'countdown' => _tplCountdown(),
      'glass' => _tplGlass(),
      'brand' => _tplBrand(),
      'checklist' => _tplChecklist(),
      _ => _tplEngineer(),
    };
  }

  // ─────────── 公共按钮 ───────────

  Widget _primary(String label, {bool wide = true}) {
    return AppPressable(
      onTap: widget.onReload,
      child: Container(
        width: wide ? double.infinity : null,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: Deco.brandGradient,
          borderRadius: BorderRadius.circular(R.full),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(90),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _ghost(String label) {
    return AppPressable(
      onTap: widget.onReload,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(R.full),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC7CBD8),
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ─────────── ① 工程进度 ───────────
  Widget _tplEngineer() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1116),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 呼吸发光图标
              AnimatedBuilder(
                animation: _breath,
                builder: (context, _) {
                  final v = _breath.value;
                  return Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      gradient: Deco.brandGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: C.brand.withAlpha((60 + v * 90).round()),
                          blurRadius: 30 + v * 30,
                          spreadRadius: 2 + v * 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              const Text(
                '系统维护中',
                style: TextStyle(
                  color: Color(0xFFF6F7FB),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              ..._restLines.isEmpty
                  ? [
                      Text(
                        _firstLine,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9AA1B2),
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                    ]
                  : [
                      Text(
                        _firstLine,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9AA1B2),
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._restLines.map(
                        (l) => Text(
                          l,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6B7288),
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
              const SizedBox(height: 24),
              // 阶段指示点（呼吸联动）
              AnimatedBuilder(
                animation: _breath,
                builder: (context, _) {
                  const total = 5;
                  final active = 2 + (_breath.value * 1.99).round();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(total, (i) {
                      final on = i < active;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 420),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: on ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: on ? C.brand : Colors.white.withAlpha(28),
                          borderRadius: BorderRadius.circular(R.full),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 30),
              _primary('重新加载'),
              const SizedBox(height: 16),
              Text(
                '维护完成后将自动恢复',
                style: TextStyle(
                  color: Colors.white.withAlpha(70),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────── ② 维护倒计时 ───────────
  Widget _tplCountdown() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1522),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF131A2B), Color(0xFF0E1420)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 金色徽标
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: C.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(R.full),
                    border: Border.all(color: C.amber.withAlpha(90)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 13, color: C.amber),
                      const SizedBox(width: 5),
                      Text(
                        '维护中',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: C.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '正在升级服务器',
                  style: TextStyle(
                    color: Color(0xFFF6F7FB),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _firstLine,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9AA1B2),
                    fontSize: 12.5,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.full),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(color: Colors.white.withAlpha(20)),
                        FractionallySizedBox(
                          widthFactor: 0.72,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [C.brand, C.brandBright],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Text(
                      '维护进行中',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withAlpha(90),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '预计 72%',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: C.brandBright.withAlpha(220),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: _ghost('刷新状态')),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: _primary('重新加载')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── ③ 毛玻璃 ───────────
  Widget _tplGlass() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D13),
      body: Stack(
        children: [
          // 双色光晕背景
          Positioned(
            left: -110,
            top: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [C.brand.withAlpha(130), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            right: -130,
            bottom: -110,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [C.accent.withAlpha(120), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withAlpha(46)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(28),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.construction_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '系统维护中',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        _firstLine,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                          height: 1.75,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _primary('重新加载'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── ④ 品牌静默 ───────────
  Widget _tplBrand() {
    return Scaffold(
      backgroundColor: const Color(0xFF08090D),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: Deco.brandGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.appName.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.appName.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withAlpha(80),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                '暂停服务',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 38,
                height: 3,
                decoration: BoxDecoration(
                  gradient: Deco.brandGradient,
                  borderRadius: BorderRadius.circular(R.full),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _lines.join('\n'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 13,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(width: 190, child: _primary('重新加载')),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────── ⑤ 服务清单 ───────────
  Widget _tplChecklist() {
    return Scaffold(
      backgroundColor: const Color(0xFF101319),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: C.amber.withAlpha(32),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 19,
                      color: C.amber,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      '系统维护中',
                      style: TextStyle(
                        color: Color(0xFFF6F7FB),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _firstLine,
                style: const TextStyle(
                  color: Color(0xFF9AA1B2),
                  fontSize: 12.5,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              // 编号列表
              ...List.generate(_restLines.isEmpty ? 3 : _restLines.length, (i) {
                final txt = _restLines.isEmpty
                    ? ['解析服务升级，支持更多平台', '下载通道扩容，下载更稳定', '维护完成后自动恢复'][i]
                    : _restLines[i];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withAlpha(18)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.brand.withAlpha(50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: C.brandBright,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          txt,
                          style: const TextStyle(
                            color: Color(0xFF9AA1B2),
                            fontSize: 12.5,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              _primary('重新加载'),
            ],
          ),
        ),
      ),
    );
  }
}
