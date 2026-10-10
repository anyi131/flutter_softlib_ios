////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 管理后台「解析配置」Tab
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植配套。
// 编辑 ui_config.jicun 全量字段并走现有 ui_config 保存链路(config_save)。
// ⚠️ config_save 对 ui_config 是【整体覆盖】:本 Tab 保存时必须把加载到的完整
// ui_config 原样带回,只替换 jicun 节点,否则会把其他 Tab 的配置冲掉。
// 版权与许可遵循上游 MIT License,见仓库 LICENSE。
////////////////////////////////////////////////////////////////////////////////
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../api/soft_service.dart';
import '../../../design/adaptive.dart';
import '../../../jicun/jicun_config.dart';
import '../../../utils/toast_util.dart';

/// 平台名单(与客户端 jicun_platform.dart 对齐;未列出的走 unknown,不受开关控制)。
const List<String> kJicunPlatforms = [
  '抖音',
  '快手',
  '小红书',
  '哔哩哔哩',
  '微博',
  '微信视频号',
  '汽水音乐',
  '豆包',
];

class AdminJicunTab extends StatefulWidget {
  const AdminJicunTab({super.key});

  @override
  State<AdminJicunTab> createState() => _AdminJicunTabState();
}

class _AdminJicunTabState extends State<AdminJicunTab> {
  final _svc = AdminService.instance;

  bool _loading = true;
  bool _saving = false;
  String _loadErr = '';

  // ⚠️ 完整 ui_config 快照:保存时原样带回(除 jicun 外不动)。
  Map<String, dynamic> _rawUi = {};

  bool _enable = true;
  String _tabName = '即存';
  late TextEditingController _apiHost;
  late TextEditingController _apiBackup;
  late TextEditingController _apiHeaders;
  late TextEditingController _upstreamOverride;
  // 平台开关(写进 platform_enable JSON)
  final Map<String, bool> _platformOn = {
    for (final p in kJicunPlatforms) p: true,
  };
  late TextEditingController _maxConcurrent;
  late TextEditingController _timeout;
  late TextEditingController _retry;
  late TextEditingController _minSplitSize;
  late TextEditingController _saveDirName;
  late TextEditingController _historyLimit;
  bool _clearOnExit = false;
  String _qualityDefault = 'highest';
  bool _autoPaste = true;
  late TextEditingController _notice;

  @override
  void initState() {
    super.initState();
    _apiHost = TextEditingController();
    _apiBackup = TextEditingController();
    _apiHeaders = TextEditingController();
    _upstreamOverride = TextEditingController();
    _maxConcurrent = TextEditingController();
    _timeout = TextEditingController();
    _retry = TextEditingController();
    _minSplitSize = TextEditingController();
    _saveDirName = TextEditingController();
    _historyLimit = TextEditingController();
    _notice = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _apiHost.dispose();
    _apiBackup.dispose();
    _apiHeaders.dispose();
    _upstreamOverride.dispose();
    _maxConcurrent.dispose();
    _timeout.dispose();
    _retry.dispose();
    _minSplitSize.dispose();
    _saveDirName.dispose();
    _historyLimit.dispose();
    _notice.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadErr = '';
    });
    try {
      final cfg = await _svc.config();
      final raw = cfg['ui_config'];
      Map<String, dynamic> ui = {};
      if (raw is Map) {
        ui = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.trim().startsWith('{')) {
        try {
          ui = Map<String, dynamic>.from(jsonDecode(raw));
        } catch (_) {}
      }
      final jicun = (ui['jicun'] is Map)
          ? Map<String, dynamic>.from(ui['jicun'] as Map)
          : <String, dynamic>{};
      String s(String k, String d) {
        final v = '${jicun[k] ?? ''}';
        return v.isEmpty ? d : v;
      }

      int i(String k, int d) => int.tryParse('${jicun[k] ?? ''}'.trim()) ?? d;
      bool b(String k, bool d) {
        final v = jicun[k];
        if (v == null) return d;
        return v == true || v == 1 || v == '1' || v == 'true';
      }

      // 平台开关 JSON 合并进默认名单。
      var pe = <String, dynamic>{};
      final peRaw = '${jicun['platform_enable'] ?? ''}';
      if (peRaw.trim().startsWith('{')) {
        try {
          final d = jsonDecode(peRaw);
          if (d is Map) pe = Map<String, dynamic>.from(d);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _rawUi = ui;
        _enable = b('enable', true);
        _tabName = s('tab_name', '即存');
        _apiHost.text = s('api_host', '');
        _apiBackup.text = s('api_backup', '');
        _apiHeaders.text = s('api_headers', '');
        _upstreamOverride.text = s('upstream_override', '');
        for (final p in kJicunPlatforms) {
          if (pe.containsKey(p)) {
            final v = pe[p];
            _platformOn[p] = v == true || v == 1 || v == '1' || v == 'true';
          }
        }
        _maxConcurrent.text = '${i('max_concurrent', 4)}';
        _timeout.text = '${i('timeout', 20)}';
        _retry.text = '${i('retry', 3)}';
        _minSplitSize.text = '${i('min_split_size', 8)}';
        _saveDirName.text = s('save_dir_name', 'JicunDownload');
        _historyLimit.text = '${i('history_limit', 200)}';
        _clearOnExit = b('clear_on_exit', false);
        _qualityDefault = s('quality_default', 'highest');
        _autoPaste = b('auto_paste', true);
        _notice.text = s('notice', '');
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadErr = e.toString().replaceFirst('Exception: ', '');
        });
        ToastUtil.error(_loadErr);
      }
    }
  }

  /// ⚠️ 全量覆盖语义:带回完整 ui_config,只替换 jicun 节点。
  Map<String, dynamic> _payload() => {
    'ui_config': {
      ..._rawUi,
      'jicun': {
        'enable': _enable ? 1 : 0,
        'tab_name': _tabName.trim().isEmpty ? '即存' : _tabName.trim(),
        'api_host': _apiHost.text.trim(),
        'api_backup': _apiBackup.text.trim(),
        'api_headers': _apiHeaders.text.trim(),
        'upstream_override': _upstreamOverride.text.trim(),
        'platform_enable': jsonEncode({
          for (final p in kJicunPlatforms) p: _platformOn[p]! ? 1 : 0,
        }),
        'max_concurrent': int.tryParse(_maxConcurrent.text.trim()) ?? 4,
        'timeout': int.tryParse(_timeout.text.trim()) ?? 20,
        'retry': int.tryParse(_retry.text.trim()) ?? 3,
        'min_split_size': int.tryParse(_minSplitSize.text.trim()) ?? 8,
        'save_dir_name': _saveDirName.text.trim().isEmpty
            ? 'JicunDownload'
            : _saveDirName.text.trim(),
        'history_limit': int.tryParse(_historyLimit.text.trim()) ?? 200,
        'clear_on_exit': _clearOnExit ? 1 : 0,
        'quality_default': _qualityDefault,
        'auto_paste': _autoPaste ? 1 : 0,
        'notice': _notice.text.trim(),
      },
    },
  };

  bool _validJson(String s) {
    if (s.trim().isEmpty) return true;
    try {
      final d = jsonDecode(s);
      return d is Map;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_loadErr.isNotEmpty) {
      ToastUtil.error('配置未加载成功，禁止保存（避免覆盖线上配置），请先重试');
      return;
    }
    // JSON 字段校验,坏 JSON 不许保存(否则客户端会解析失败回落默认)。
    for (final (name, v) in [
      ('自定义请求头', _apiHeaders.text),
      ('平台级覆盖', _upstreamOverride.text),
    ]) {
      if (!_validJson(v)) {
        ToastUtil.error('「$name」不是合法的 JSON 对象,请检查后再保存');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await _svc.saveConfig(_payload());
      // 客户端热生效:立刻重新拉配置并刷新即存设置。
      try {
        await SoftService.instance.fetchConfig(force: true);
        JicunSettings.instance.refresh(force: true);
      } catch (_) {}
      if (mounted) ToastUtil.success('已保存并即时生效');
    } catch (e) {
      if (mounted) {
        ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadErr.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载失败:$_loadErr',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.t2),
            ),
            const SizedBox(height: 12),
            SoftButton(label: '重试', onPressed: _load),
          ],
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        12,
        context.pagePadding,
        32,
      ),
      children: [
        _section('功能与 Tab', [
          _switch(
            '启用即存功能',
            '关闭后 App 底部不显示「即存」Tab',
            _enable,
            (v) => setState(() => _enable = v),
          ),
          _text(
            'Tab 显示名',
            '底部第 5 个 Tab 的名字',
            _tabName,
            (v) => _tabName = v,
            hint: '即存',
          ),
          _switch(
            '自动读剪贴板',
            '回到前台自动填充剪贴板里的分享链接',
            _autoPaste,
            (v) => setState(() => _autoPaste = v),
          ),
          _text(
            '公告文案',
            '即存页顶部公告,留空不显示',
            _notice.text,
            (v) => _notice.text = v,
            maxLines: 2,
            hint: '例如:解析接口已升级,支持更多平台',
          ),
        ]),
        _section('解析接口', [
          _text(
            '主解析接口 api_host',
            '留空 = 上游默认;填自建/第三方解析服务地址(兼容 media-parser / 上游两种应答形状)',
            _apiHost.text,
            (v) => _apiHost.text = v,
            hint: 'https://your-parser.example.com',
          ),
          _text(
            '备用接口 api_backup',
            '主接口失败时按顺序兜底',
            _apiBackup.text,
            (v) => _apiBackup.text = v,
            hint: 'https://backup.example.com',
          ),
          _text(
            '自定义请求头 JSON',
            '发给解析接口的额外请求头,如 {"Authorization":"Bearer xx"}',
            _apiHeaders.text,
            (v) => _apiHeaders.text = v,
            maxLines: 2,
            hint: '{"Key":"Value"}',
          ),
          _text(
            '平台级覆盖 JSON',
            '某平台走不同上游/关闭,如 {"抖音":{"api":"https://dy.example.com","enable":true}}',
            _upstreamOverride.text,
            (v) => _upstreamOverride.text = v,
            maxLines: 3,
            hint: '{"平台":{"api":"...","enable":true}}',
          ),
        ]),
        _section('平台开关', [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '关掉的平台会在 App 本地直接拦截(一次请求都不发)',
              style: TextStyle(fontSize: 11, color: context.t3),
            ),
          ),
          for (final p in kJicunPlatforms)
            _switch(
              p,
              '',
              _platformOn[p]!,
              (v) => setState(() => _platformOn[p] = v),
            ),
        ]),
        _section('下载引擎', [
          _text(
            '并发文件数 max_concurrent',
            '同时下载的文件条数(1-8)',
            _maxConcurrent.text,
            (v) => _maxConcurrent.text = v,
            hint: '4',
          ),
          _text(
            '超时(秒) timeout',
            '解析请求与单段收流的超时',
            _timeout.text,
            (v) => _timeout.text = v,
            hint: '20',
          ),
          _text(
            '段重试次数 retry',
            '单个分段失败后的重试上限',
            _retry.text,
            (v) => _retry.text = v,
            hint: '3',
          ),
          _text(
            '分段阈值 min_split_size(MB)',
            '文件超过该大小才 Range 切段并行',
            _minSplitSize.text,
            (v) => _minSplitSize.text = v,
            hint: '8',
          ),
        ]),
        _section('存储与历史', [
          _text(
            '下载目录名 save_dir_name',
            'App 内「下载到应用目录」的子目录名',
            _saveDirName.text,
            (v) => _saveDirName.text = v,
            hint: 'JicunDownload',
          ),
          _text(
            '历史条数 history_limit',
            '本地解析历史上限(超出自动淘汰最旧)',
            _historyLimit.text,
            (v) => _historyLimit.text = v,
            hint: '200',
          ),
          _switch(
            '退出页面清历史',
            '离开即存页时自动清空解析历史',
            _clearOnExit,
            (v) => setState(() => _clearOnExit = v),
          ),
        ]),
        _section('清晰度', [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.isDark ? C.bg2 : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  '默认清晰度策略',
                  style: TextStyle(fontSize: 13, color: context.t1),
                ),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'highest', label: Text('最高')),
                    ButtonSegment(value: 'ask', label: Text('每次询问')),
                  ],
                  selected: {_qualityDefault},
                  onSelectionChanged: (s) =>
                      setState(() => _qualityDefault = s.first),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        PrimaryButton(
          label: '保存解析配置',
          icon: Icons.save_rounded,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          KitCard(child: Column(children: children)),
        ],
      ),
    );
  }

  Widget _switch(String title, String desc, bool value, ValueChanged<bool> on) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.t1,
                  ),
                ),
                if (desc.isNotEmpty)
                  Text(desc, style: TextStyle(fontSize: 11, color: context.t3)),
              ],
            ),
          ),
          Switch(value: value, onChanged: on),
        ],
      ),
    );
  }

  Widget _text(
    String title,
    String desc,
    String init,
    ValueChanged<String> on, {
    int maxLines = 1,
    String hint = '',
  }) {
    final ctrl = TextEditingController(text: init);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.t1,
            ),
          ),
          if (desc.isNotEmpty)
            Text(desc, style: TextStyle(fontSize: 11, color: context.t3)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            onChanged: on,
            style: TextStyle(fontSize: 13, color: context.t1),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: context.t3),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// JicunSettings 已在 jicun_config.dart 中以单例提供,这里不再需要桥接代理。
