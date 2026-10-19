import 'package:flutter/material.dart';

import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：版权梦 · 自动采集配置
///   sub=auto / auto_save（**免验证码**）
/// ═══════════════════════════════════════════════════════════════
class CollectAutoView extends StatefulWidget {
  const CollectAutoView({super.key});

  @override
  State<CollectAutoView> createState() => _CollectAutoViewState();
}

class _CollectAutoViewState extends State<CollectAutoView> {
  final _svc = AdminService.instance;
  final _countCtrl = TextEditingController();
  final _blockCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _err = '';
  String _configId = '0';
  List<(String, String, bool)> _cats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _blockCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final d = await _svc.collectEx('auto');
      final fields = ((d['fields'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final f in fields) {
        // ★ 1016：优先显示中文标签（服务端下发 label），没有才退回字段名
        final name = '${f['label'] ?? f['name']}';
        if (name == 'auto_count') _countCtrl.text = '${f['value'] ?? ''}';
        if (name == 'block_keywords') _blockCtrl.text = '${f['value'] ?? ''}';
        if (name == 'config_id') _configId = '${f['value'] ?? '0'}';
        if (name.startsWith('auto_category_filter')) {
          final opts = (f['options'] as List?) ?? [];
          _cats = opts
              .whereType<Map>()
              .map(
                (o) => (
                  '${o['value']}',
                  '${o['label'] ?? o['value']}',
                  o['checked'] == true,
                ),
              )
              .toList();
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = ErrText.of(e);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.collectEx('auto_save', {
        'config_id': _configId,
        'auto_count': _countCtrl.text.trim().isEmpty
            ? '20'
            : _countCtrl.text.trim(),
        'block_keywords': _blockCtrl.text.trim(),
        'auto_category_filter': _cats
            .where((c) => c.$3)
            .map((c) => c.$1)
            .toList(),
      });
      if (!mounted) return;
      ToastUtil.success('自动采集配置已保存');
      await _load();
    } catch (e) {
      if (!mounted) return;
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(text: '加载自动采集配置…');
    if (_err.isNotEmpty) {
      return EmptyState(
        text: _err,
        hint: '下拉重试',
        icon: Icons.error_outline_rounded,
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        30,
      ),
      children: [
        AdCard(
          radius: R.xl,
          padding: const EdgeInsets.all(16),
          glow: C.mint,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: C.mint.withAlpha(context.isDark ? 40 : 24),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.autorenew_rounded, size: 19, color: C.mint),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('自动采集', style: Ty.h3.copyWith(color: context.t1)),
                    Text(
                      '检测到新软件会自动生成上传（无需验证码）',
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdSection(title: '采集参数', accent: C.brand),
        const SizedBox(height: 8),
        AdCard(
          radius: R.lg,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('单次采集数量'),
              const SizedBox(height: 6),
              TextField(
                controller: _countCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '例如 20',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label('屏蔽关键词（命中则不采集）'),
              const SizedBox(height: 6),
              TextField(
                controller: _blockCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '多个关键词用逗号或空格分隔',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_cats.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdSection(
            title: '分类过滤',
            subtitle: '勾选后只采集这些分类',
            accent: C.brandBright,
          ),
          const SizedBox(height: 8),
          AdCard(
            radius: R.lg,
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cats.map((c) {
                final on = c.$3;
                return GestureDetector(
                  onTap: () => setState(() {
                    final i = _cats.indexOf(c);
                    _cats[i] = (c.$1, c.$2, !on);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: on ? Deco.brandGradient : null,
                      color: on
                          ? null
                          : (context.isDark
                                ? Colors.white.withAlpha(12)
                                : Colors.white),
                      borderRadius: BorderRadius.circular(R.full),
                      border: Border.all(color: C.stroke),
                    ),
                    child: Text(
                      c.$2.isEmpty ? '分类 ${c.$1}' : c.$2,
                      style: Ty.tiny.copyWith(
                        fontSize: 12,
                        color: on ? Colors.white : context.t2,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SoftButton(
          label: _saving ? '保存中…' : '保存自动采集配置',
          height: 46,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Widget _label(String t) =>
      Text(t, style: Ty.small.copyWith(color: context.t2));
}

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：版权梦 · 版权配置 / 全局配置（通用渲染，需邮箱验证码）
///   sub = banquan / quanju，保存 sub = banquan_save / quanju_save
/// ═══════════════════════════════════════════════════════════════
class CollectConfigView extends StatefulWidget {
  const CollectConfigView({
    super.key,
    required this.sub,
    required this.title,
    required this.subtitle,
  });

  final String sub;
  final String title;
  final String subtitle;

  @override
  State<CollectConfigView> createState() => _CollectConfigViewState();
}

class _CollectConfigViewState extends State<CollectConfigView> {
  final _svc = AdminService.instance;
  final _codeCtrl = TextEditingController();

  List<Map<String, dynamic>> _fields = [];
  final Map<String, String> _values = {};
  final Map<String, TextEditingController> _edits = {};

  bool _loading = true;
  bool _saving = false;
  bool _sending = false;
  bool _needCode = true;
  int _countdown = 0;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _edits.values) {
      c.dispose();
    }
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final d = await _svc.collectEx(widget.sub);
      final list = ((d['fields'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _values.clear();
      for (final c in _edits.values) {
        c.dispose();
      }
      _edits.clear();
      for (final f in list) {
        // ★ 1016：优先显示中文标签（服务端下发 label），没有才退回字段名
        final name = '${f['label'] ?? f['name']}';
        final val = '${f['value'] ?? ''}';
        _values[name] = val;
        final type = '${f['type']}';
        if (type == 'text' ||
            type == 'textarea' ||
            type == 'number' ||
            type == 'email' ||
            type == 'url') {
          _edits[name] = TextEditingController(text: val);
        }
      }
      if (!mounted) return;
      setState(() {
        _fields = list.where((f) {
          final n = '${f['label'] ?? f['name']}';
          // 隐藏字段与验证码字段不渲染（验证码用专用输入框）
          return '${f['type']}' != 'hidden' &&
              n != 'email_code' &&
              n != 'csrf_token';
        }).toList();
        _needCode = d['needCode'] != false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = ErrText.of(e);
      });
    }
  }

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    try {
      final r = await _svc.collectEx('send_code');
      if (!mounted) return;
      ToastUtil.success('${r['msg'] ?? '验证码已发送'}（请查收邮箱，含垃圾箱）');
      setState(() => _countdown = 60);
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted || _countdown <= 1) return false;
        setState(() => _countdown--);
        return true;
      });
    } catch (e) {
      if (!mounted) return;
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _save() async {
    if (_needCode && _codeCtrl.text.trim().isEmpty) {
      ToastUtil.error('请先获取并填写邮箱验证码');
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{};
      for (final f in _fields) {
        // ★ 1016：优先显示中文标签（服务端下发 label），没有才退回字段名
        final name = '${f['label'] ?? f['name']}';
        final type = '${f['type']}';
        if (type == 'text' ||
            type == 'textarea' ||
            type == 'number' ||
            type == 'email' ||
            type == 'url') {
          payload[name] = _edits[name]?.text ?? '';
        } else {
          payload[name] = _values[name] ?? '';
        }
      }
      await _svc.collectEx('${widget.sub}_save', {
        'fields': payload,
        'email_code': _codeCtrl.text.trim(),
      });
      if (!mounted) return;
      ToastUtil.success('已保存到版权梦');
      _codeCtrl.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return LoadingState(text: '加载${widget.title}…');
    if (_err.isNotEmpty && _fields.isEmpty) {
      return EmptyState(
        text: _err,
        hint: '下拉重试',
        icon: Icons.error_outline_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          10,
          context.pagePadding,
          30,
        ),
        children: [
          AdCard(
            radius: R.xl,
            padding: const EdgeInsets.all(16),
            glow: C.brand,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: C.brandGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.shield_moon_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Ty.h3.copyWith(color: context.t1),
                      ),
                      Text(
                        widget.subtitle,
                        style: Ty.tiny.copyWith(color: context.t3),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: C.brand.withAlpha(context.isDark ? 40 : 22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_fields.length} 项',
                    style: Ty.tiny.copyWith(fontSize: 10.5, color: C.brand),
                  ),
                ),
              ],
            ),
          ),
          if (_needCode) ...[
            const SizedBox(height: 14),
            AdCard(
              radius: R.lg,
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mark_email_read_rounded,
                        size: 16,
                        color: C.warning,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '保存需要邮箱验证码（发给账号绑定邮箱）',
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '输入邮箱收到的验证码',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(R.md),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SoftButton(
                        label: _sending
                            ? '发送中'
                            : (_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                        height: 42,
                        onPressed: (_sending || _countdown > 0)
                            ? null
                            : _sendCode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AdSection(title: '配置项', accent: C.brandBright),
          const SizedBox(height: 8),
          ..._fields.map(_fieldCard),
          const SizedBox(height: 20),
          SoftButton(
            label: _saving ? '保存中…' : '保存到版权梦',
            height: 46,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 10),
          Text(
            '提示：保存会同步到版权梦平台，影响该账号下所有生成的软件。',
            textAlign: TextAlign.center,
            style: Ty.tiny.copyWith(color: context.t3),
          ),
        ],
      ),
    );
  }

  Widget _fieldCard(Map<String, dynamic> f) {
    // ★ 1016：优先显示中文标签（服务端下发 label），没有才退回字段名
    final name = '${f['label'] ?? f['name']}';
    final type = '${f['type']}';
    final opts = ((f['options'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final isText =
        type == 'text' ||
        type == 'textarea' ||
        type == 'number' ||
        type == 'email' ||
        type == 'url';
    return AdCard(
      radius: R.lg,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _labelOf(f),
                  style: Ty.small.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.t1,
                  ),
                ),
              ),
              if (isText)
                Text(
                  '${_edits[name]?.text.length ?? 0}',
                  style: Ty.tiny.copyWith(fontSize: 10, color: context.t3),
                ),
            ],
          ),
          const SizedBox(height: 9),
          if (isText)
            TextField(
              controller: _edits[name],
              maxLines: type == 'textarea' ? 3 : 1,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: '请输入 ${name}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.md),
                ),
              ),
            )
          else if (opts.isNotEmpty)
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: opts.map((o) {
                final v = '${o['value']}';
                final on = (_values[name] ?? '') == v;
                final lb = '${o['label'] ?? ''}';
                return GestureDetector(
                  onTap: () => setState(() => _values[name] = v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: on ? Deco.brandGradient : null,
                      color: on
                          ? null
                          : (context.isDark
                                ? Colors.white.withAlpha(12)
                                : Colors.white),
                      borderRadius: BorderRadius.circular(R.full),
                      border: Border.all(color: C.stroke),
                    ),
                    child: Text(
                      lb.isEmpty || lb == '?' ? '选项 $v' : lb,
                      style: Ty.tiny.copyWith(
                        fontSize: 12,
                        color: on ? Colors.white : context.t2,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Text(
              '${_values[name] ?? ''}',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
        ],
      ),
    );
  }

  /// 字段中文名（页面标签抓不到时回退到字段名）
  String _labelOf(Map<String, dynamic> f) {
    final lb = '${f['label'] ?? ''}';
    if (lb.isNotEmpty && lb != '?') return lb;
    const map = {
      'open': '总开关',
      'template': '模板类型',
      'page_show': '版权页面开关',
      'admod': '广告模式',
      'adymd': '广告显示时机',
      'adcs': '广告次数',
      'is_show_qq': '显示联系作者',
      'is_show_group': '显示群聊',
      'shareon': '分享开关',
      'sharetype': '分享类型',
      'sharemode': '分享渠道',
      'sharedelayedseconds': '分享延迟',
      'declare_t': '免责声明标题',
      'declare_d': '免责声明内容',
      'bjimg': '背景图链接',
      'csqq': '联系QQ',
      'groupqq': '群号',
      'end': '退出软件开关',
      'ends': '退出桌面开关',
      'uappopen': '打开指定软件',
      'uapp': '软件包名',
      'hwsopen': '打开网址链接',
      'hws': '网址',
      'sxbopen': '启动复制文本',
      'sxb': '复制文本内容',
      'tsopen': '提示开关',
      'ts': '提示内容',
    };
    return map['${f['name']}'] ?? '${f['name']}';
  }
}
