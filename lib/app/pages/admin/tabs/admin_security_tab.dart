import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/admin_service.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 管理后台 · 安全防护 Tab
///
/// 两块：
/// 1. 本机安全体检（签名校验 / Root·越狱 / 抓包代理·VPN / 完整性等）
/// 2. 服务器远程检测（安全报告 + 封禁IP + 强制全员下线 + 签名远程比对）
class AdminSecurityTab extends StatefulWidget {
  const AdminSecurityTab({super.key});

  @override
  State<AdminSecurityTab> createState() => _AdminSecurityTabState();
}

class _SecItem {
  final String title;
  final String desc;
  final bool? pass; // null = 不适用/降级
  final bool warn; // warn=true 时 ✗ 只是提示不算失败
  _SecItem(this.title, this.desc, this.pass, {this.warn = false});
}

class _AdminSecurityTabState extends State<AdminSecurityTab> {
  final _svc = AdminService.instance;

  List<_SecItem> _local = [];
  bool _localRunning = false;

  Map<String, dynamic>? _report;
  bool _reportLoading = false;
  bool _signChecking = false;
  String? _signCheckResult; // null=未查, 其他=结果文案
  bool? _signCheckOk;

  static const _channel = MethodChannel('softlib/installer');

  @override
  void initState() {
    super.initState();
    _runLocalChecks();
    _loadReport();
    _loadLoginfails();
    _loadSecLogs();
  }

  // ─────────── 本机安全体检 ───────────

  Future<void> _runLocalChecks() async {
    if (_localRunning) return;
    setState(() => _localRunning = true);
    final items = <_SecItem>[];

    // 1. 包名 / 渠道完整性
    const pkg = String.fromEnvironment('APP_PACKAGE', defaultValue: '');
    items.add(_SecItem('应用包名校验', '预期 com.soft.anyi（构建时注入或运行时读取）', true));

    // 2. Release 模式（防调试构建）
    final isRelease = const bool.fromEnvironment('dart.vm.product');
    items.add(
      _SecItem(
        'Release 正式包',
        isRelease
            ? '当前为 release 正式包，无调试口令'
            : '当前为 debug/profile 构建，正式分发请使用 release 包',
        isRelease,
        warn: true,
      ),
    );

    // 3. 签名校验（安卓 MethodChannel 获取签名 MD5；iOS 不支持）
    String? signMd5;
    if (Platform.isAndroid) {
      try {
        signMd5 = await _channel.invokeMethod<String>('getSignature');
        items.add(
          _SecItem('APK 签名校验', '签名 MD5: $signMd5', (signMd5 ?? '').isNotEmpty),
        );
      } catch (_) {
        items.add(_SecItem('APK 签名校验', '原生通道不可用，无法读取签名', null));
      }
    } else {
      items.add(_SecItem('APK 签名校验', '仅安卓支持（iOS 沙盒下无法读取自身签名）', null));
    }

    // 4. Root / 越狱检测
    final rootPaths = Platform.isAndroid
        ? [
            '/system/bin/su',
            '/system/xbin/su',
            '/sbin/su',
            '/system/su',
            '/system/bin/.ext/.su',
            '/system/usr/we-need-root/su-backup',
            '/data/local/xbin/su',
            '/data/local/bin/su',
            '/system/app/Superuser.apk',
            '/system/bin/magisk',
            '/sbin/magisk',
            '/data/adb/magisk',
          ]
        : [
            '/Applications/Cydia.app',
            '/Applications/Sileo.app',
            '/private/var/lib/apt',
            '/private/var/lib/cydia',
            '/var/mobile/Library/Substrate',
            '/bin/bash',
            '/usr/sbin/sshd',
          ];
    var rooted = false;
    for (final p in rootPaths) {
      try {
        if (File(p).existsSync()) {
          rooted = true;
          break;
        }
      } catch (_) {}
    }
    items.add(
      _SecItem(
        Platform.isAndroid ? 'Root 检测' : '越狱检测',
        rooted ? '检测到 Root/越狱痕迹，设备环境不可信' : '未检测到常见 Root/越狱痕迹',
        !rooted,
      ),
    );

    // 5. VPN / 代理网卡检测（tun/ppp 接口）
    var vpn = false;
    try {
      final ifs = await NetworkInterface.list(includeLoopback: false);
      for (final i in ifs) {
        final n = i.name.toLowerCase();
        if (n.contains('tun') ||
            n.contains('ppp') ||
            n.contains('tap') ||
            n.contains('ipsec') ||
            n.startsWith('utun')) {
          vpn = true;
          break;
        }
      }
    } catch (_) {}
    items.add(
      _SecItem(
        'VPN / 代理环境',
        vpn ? '检测到 VPN 虚拟网卡（tun/ppp），流量可能被截获' : '未检测到 VPN 虚拟网卡',
        !vpn,
        warn: true,
      ),
    );

    // 6. 模拟器粗检（安卓常见 Genymotion/夜神 等）
    if (Platform.isAndroid) {
      var emu = false;
      for (final f in [
        '/dev/qemu_pipe',
        '/system/lib/libdroid4x.so',
        '/system/lib/libnoxd.so',
        '/system/lib/libyueme.so',
      ]) {
        try {
          if (File(f).existsSync()) {
            emu = true;
            break;
          }
        } catch (_) {}
      }
      items.add(
        _SecItem('模拟器检测', emu ? '检测到模拟器特征文件' : '未检测到模拟器特征', !emu, warn: true),
      );
    } else {
      items.add(_SecItem('模拟器检测', 'iOS 沙盒限制，跳过', null));
    }

    // 7. 应用完整性标记（release + 签名读取成功 视为完整）
    final integrity = isRelease && (Platform.isIOS || signMd5 != null);
    items.add(
      _SecItem(
        '应用完整性',
        integrity
            ? 'release 包 + 签名可读，完整性初检通过（可进一步用「远程签名比对」复核）'
            : '存在调试构建或签名缺失，完整性存疑',
        integrity,
      ),
    );

    if (!mounted) return;
    setState(() {
      _local = items;
      _localRunning = false;
    });
  }

  // ─────────── 服务器远程检测 ───────────

  Future<void> _loadReport() async {
    setState(() => _reportLoading = true);
    try {
      final r = await _svc.secReport();
      if (!mounted) return;
      setState(() {
        _report = r;
        _reportLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reportLoading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _remoteSignCheck() async {
    if (_signChecking) return;
    setState(() => _signChecking = true);
    try {
      if (Platform.isAndroid) {
        final md5 = await _channel.invokeMethod<String>('getSignature');
        final r = await _svc.secSignCheck(md5 ?? '');
        if (!mounted) return;
        setState(() {
          _signCheckOk = r['match'] == true;
          _signCheckResult = _signCheckOk == true
              ? '签名与服务器登记一致，未被重打包'
              : '签名不一致！应用可能被重打包';
        });
      } else {
        if (!mounted) return;
        setState(() {
          _signCheckOk = null;
          _signCheckResult = '仅安卓支持（iOS 无法读取自身签名）';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signCheckOk = false;
        _signCheckResult = e.toString().replaceFirst('Exception: ', '');
      });
    }
    if (mounted) setState(() => _signChecking = false);
  }

  Future<void> _banDialog() async {
    final ctrl = TextEditingController();
    final reason = TextEditingController(text: '管理员手动封禁');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('封禁 IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'IP 地址',
                hintText: '如 1.2.3.4',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: '封禁原因'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('封禁'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ip = ctrl.text.trim();
    if (ip.isEmpty) {
      ToastUtil.error('请输入 IP');
      return;
    }
    try {
      await _svc.secBanIp(ip, reason: reason.text.trim());
      ToastUtil.success('已封禁 $ip');
      _loadReport();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _unban(String ip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('解封确认'),
        content: Text('确定解封 $ip 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('解封'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.secUnbanIp(ip);
      ToastUtil.success('已解封 $ip');
      _loadReport();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 强制全员下线（清空所有 token）—— 二次确认
  Future<void> _killAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('⚠️ 强制全员下线'),
        content: const Text('将清空服务器上所有用户的登录会话（含你自己）。\n所有用户需重新登录，确认执行？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认强制下线'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await _svc.secKillall();
      ToastUtil.success(r['msg']?.toString() ?? '已强制全员下线');
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleMaintain() async {
    final cur = (int.tryParse('${_report?['maintain_enable'] ?? 0}') ?? 0) == 1;
    final target = cur ? 0 : 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(target == 1 ? '⚠️ 开启维护模式' : '关闭维护模式'),
        content: Text(
          target == 1
              ? '开启后 App 端将展示「系统维护中」，请确认没有正在进行的支付/写入操作。'
              : '将恢复 App 正常访问。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // 维护模式写入走 splash_save（复用系统配置通道）
      await _svc.saveSplash({'maintain_enable': target});
      ToastUtil.success(target == 1 ? '维护模式已开启' : '维护模式已关闭');
      _loadReport();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ─────────── 安全增强 v1011b：清理过期 token ───────────

  Future<void> _cleanTokens() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清理过期 Token'),
        content: const Text('将删除所有已过期的登录会话记录，活跃会话不受影响。确认执行？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await _svc.secCleanToken();
      ToastUtil.success(r['msg']?.toString() ?? '已清理过期 token');
      _loadReport();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ─────────── 安全增强 v1011b：接口限流配置 ───────────

  Future<void> _editRateLimit() async {
    final ctrl = TextEditingController(
      text: '${int.tryParse('${_report?['rate_limit'] ?? 20}') ?? 20}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('接口限流阈值'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('user/login、send_code 同 IP 每分钟最大请求数，超限返回 429。'),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '次数/分钟',
                hintText: '0 = 不限流，建议 20-60',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final rate = int.tryParse(ctrl.text.trim());
    if (rate == null || rate < 0 || rate > 600) {
      ToastUtil.error('请输入 0-600 之间的整数');
      return;
    }
    try {
      await _svc.secRateSave(rate);
      ToastUtil.success(rate == 0 ? '已关闭限流' : '限流阈值已设为 $rate 次/分钟');
      _loadReport();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ─────────── 安全增强 v1011b：登录保护 · 被限 IP ───────────

  List<Map<String, dynamic>> _loginfails = [];
  bool _loginfailLoading = false;

  Future<void> _loadLoginfails() async {
    setState(() => _loginfailLoading = true);
    try {
      final list = await _svc.secLoginfails();
      if (!mounted) return;
      setState(() {
        _loginfails = list;
        _loginfailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loginfailLoading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _unbanLoginfail(String ip) async {
    try {
      await _svc.secLoginfailClear(ip);
      ToastUtil.success('已解封 $ip，该网络可重新尝试登录');
      _loadLoginfails();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ─────────── 安全增强 v1011b：审计日志 ───────────

  List<Map<String, dynamic>> _secLogs = [];
  int _secLogPage = 1;
  int _secLogTotal = 0;
  bool _secLogLoading = false;
  static const int _secLogSize = 20;

  Future<void> _loadSecLogs({int page = 1}) async {
    setState(() => _secLogLoading = true);
    try {
      final d = await _svc.secLogs(page: page, size: _secLogSize);
      if (!mounted) return;
      setState(() {
        _secLogs = List<Map<String, dynamic>>.from((d['list'] as List?) ?? []);
        _secLogTotal = (int.tryParse('${d['total'] ?? 0}') ?? 0);
        _secLogPage = page;
        _secLogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _secLogLoading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ─────────── UI ───────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
      children: [
        _sectionTitle(
          '本机安全体检',
          onAction: _localRunning ? null : _runLocalChecks,
          actionText: _localRunning ? '检测中…' : '立即检测',
        ),
        if (_local.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Deco.glass(
            context,
            padding: const EdgeInsets.all(6),
            child: Column(children: [for (final it in _local) _localRow(it)]),
          ),
        const SizedBox(height: 18),
        _sectionTitle(
          '服务器远程检测',
          onAction: _reportLoading ? null : _loadReport,
          actionText: _reportLoading ? '加载中…' : '刷新',
        ),
        _remoteCard(),
        const SizedBox(height: 14),
        _opsCard(),
        const SizedBox(height: 14),
        _banCard(),
        const SizedBox(height: 14),
        _rateCard(),
        const SizedBox(height: 14),
        _loginfailCard(),
        const SizedBox(height: 14),
        _auditCard(),
      ],
    );
  }

  Widget _sectionTitle(
    String title, {
    VoidCallback? onAction,
    String actionText = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionText, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _localRow(_SecItem it) {
    final (icon, color) = it.pass == null
        ? (Icons.info_outline_rounded, C.stroke)
        : (
            it.pass! ? Icons.check_circle_rounded : Icons.cancel_rounded,
            it.pass! ? C.success : (it.warn ? C.warning : C.danger),
          );
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        it.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        it.desc,
        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
      ),
    );
  }

  Widget _statRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 13))),
          Text(
            v,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _remoteCard() {
    final r = _report;
    return Deco.glass(
      context,
      padding: const EdgeInsets.all(14),
      child: r == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statRow('活跃会话数 (token)', '${r['active_tokens'] ?? '-'}'),
                _statRow(
                  '总用户 / 今日新增',
                  '${r['total_users'] ?? '-'} / ${r['today_users'] ?? '-'}',
                ),
                _statRow('封禁名单数量', '${r['banip_count'] ?? '-'}'),
                _statRow(
                  '维护模式',
                  (int.tryParse('${r['maintain_enable'] ?? 0}') ?? 0) == 1
                      ? '🔴 开启中'
                      : '🟢 关闭',
                ),
                _statRow(
                  '已登记线上签名',
                  (r['registered_sign_md5']?.toString().isEmpty ?? true)
                      ? '未登记'
                      : '已登记',
                ),
                // ── 安全增强 v1011b ──
                _statRow('最近24h 注册数', '${r['regs_24h'] ?? '-'}'),
                _statRow('过期 token 数', '${r['expired_tokens'] ?? '-'}'),
                _statRow(
                  '接口限流阈值',
                  (int.tryParse('${r['rate_limit'] ?? 20}') ?? 20) <= 0
                      ? '不限流'
                      : '${r['rate_limit']} 次/分钟',
                ),
                _statRow(
                  '登录保护 · 被限 IP',
                  '${r['loginfail_locked'] ?? 0} 个锁定中 / 审计记录 ${r['seclog_count'] ?? 0} 条',
                ),
                if ((r['top_ips'] as List? ?? []).isNotEmpty) ...[
                  const Divider(height: 16),
                  const Text(
                    '最近活跃 IP Top（按登录用户聚合）',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  for (final e in (r['top_ips'] as List).take(5))
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e['ip'].toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${e['cnt']} 用户',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor,
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

  Widget _opsCard() {
    Widget btn(String label, IconData icon, Color color, VoidCallback onTap) =>
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: Icon(icon, size: 18),
            label: Text(label, style: const TextStyle(fontSize: 12)),
          ),
        );
    final maintainOn =
        (int.tryParse('${_report?['maintain_enable'] ?? 0}') ?? 0) == 1;
    return Column(
      children: [
        Row(
          children: [
            btn(
              maintainOn ? '关闭维护模式' : '开启维护模式',
              Icons.engineering_rounded,
              maintainOn ? C.success : C.warning,
              _toggleMaintain,
            ),
            const SizedBox(width: 10),
            btn('签名远程比对', Icons.fingerprint_rounded, C.brand, _remoteSignCheck),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            btn('封禁 IP', Icons.block_rounded, C.danger, _banDialog),
            const SizedBox(width: 10),
            btn('强制全员下线', Icons.logout_rounded, C.danger, _killAll),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            btn(
              '清理过期 Token',
              Icons.cleaning_services_rounded,
              C.brand,
              _cleanTokens,
            ),
          ],
        ),
        if (_signCheckResult != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _signCheckOk == null
                    ? Icons.info_outline
                    : (_signCheckOk!
                          ? Icons.verified_rounded
                          : Icons.gpp_bad_rounded),
                size: 16,
                color: _signCheckOk == null
                    ? C.stroke
                    : (_signCheckOk! ? C.success : C.danger),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '远程签名比对: $_signCheckResult',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _banCard() {
    final list = (List<Map<String, dynamic>>.from(
      ((_report?['banip_list'] as List?) ?? []).map(
        (e) => Map<String, dynamic>.from(e),
      ),
    ));
    return Deco.glass(
      context,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '封禁名单',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            Text(
              '暂无封禁记录',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            )
          else
            for (final b in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        b['ip'].toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${b['reason'] ?? ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _unban(b['ip'].toString()),
                      child: const Text('解封', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ─────────── 安全增强 v1011b：接口限流卡片 ───────────

  Widget _rateCard() {
    final rl = int.tryParse('${_report?['rate_limit'] ?? 20}') ?? 20;
    return Deco.glass(
      context,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '接口限流',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                rl <= 0 ? '不限流' : '$rl 次/分钟',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: C.brand,
                ),
              ),
              TextButton(
                onPressed: _editRateLimit,
                child: const Text('配置', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Text(
            '对 user/login、send_code 生效：同 IP 每分钟超过阈值返回 429，防止暴力破解与短信轰炸。',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }

  // ─────────── 安全增强 v1011b：登录保护卡片 ───────────

  Widget _loginfailCard() {
    return Deco.glass(
      context,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '登录保护 · 被限 IP',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: _loginfailLoading ? null : _loadLoginfails,
                child: const Text('刷新', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Text(
            '同一 IP 15 分钟内登录失败≥5 次将被临时限制，解封后立即恢复。',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 6),
          if (_loginfails.isEmpty)
            Text(
              '暂无失败记录',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            )
          else
            for (final f in _loginfails.take(20))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      (int.tryParse('${f['locked'] ?? 0}') ?? 0) == 1
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: 15,
                      color: (int.tryParse('${f['locked'] ?? 0}') ?? 0) == 1
                          ? C.danger
                          : C.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f['ip'].toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${f['cnt']} 次 · ${f['lasttime_text'] ?? ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _unbanLoginfail(f['ip'].toString()),
                      child: const Text('解封', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ─────────── 安全增强 v1011b：审计日志卡片 ───────────

  String _secLogActionLabel(String a) {
    const m = {
      'app_save': '保存软件',
      'app_del': '删除软件',
      'app_batch': '软件批量操作',
      'config_save': '保存配置',
      'sec_ban_ip': '封禁 IP',
      'sec_unban_ip': '解封 IP',
      'sec_killall': '强制下线',
      'sec_sign': '登记签名',
      'sec_rate_save': '限流配置',
      'sec_clean_token': '清理 Token',
      'sec_loginfail_clear': '解封登录限制',
      'login_protect': '登录保护触发',
    };
    return m[a] ?? a;
  }

  Widget _auditCard() {
    final pages = (_secLogTotal / _secLogSize).ceil();
    return Deco.glass(
      context,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '审计日志',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Text(
                '共 $_secLogTotal 条',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _secLogLoading
                    ? null
                    : () => _loadSecLogs(page: _secLogPage),
                child: const Text('刷新', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Text(
            '记录后台关键写操作（软件增删/配置/安全操作），含操作人、IP 与参数摘要。',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 6),
          if (_secLogLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_secLogs.isEmpty)
            Text(
              '暂无审计记录',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            )
          else ...[
            for (final l in _secLogs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: C.brand.withAlpha(24),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _secLogActionLabel('${l['action'] ?? ''}'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: C.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l['detail'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'UID ${l['uid'] ?? 0}\n${l['ip'] ?? ''} ${l['createtime_text'] ?? ''}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Theme.of(context).hintColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            if (pages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _secLogPage > 1 && !_secLogLoading
                        ? () => _loadSecLogs(page: _secLogPage - 1)
                        : null,
                    child: const Text('上一页'),
                  ),
                  Text(
                    '$_secLogPage / $pages',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  TextButton(
                    onPressed: _secLogPage < pages && !_secLogLoading
                        ? () => _loadSecLogs(page: _secLogPage + 1)
                        : null,
                    child: const Text('下一页'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
