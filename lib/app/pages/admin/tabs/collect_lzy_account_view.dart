import 'package:flutter/material.dart';
import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 采集 · 蓝奏云账号（对应采集平台站点的「蓝奏云Cookie获取」页）
///
/// 采集的软件最终会上传到这个蓝奏云账号，所以必须先在站点配好 Cookie。
/// 这里直接调站点接口提交账号密码，站点自己去拿并加密保存 Cookie。
class CollectLzyAccountView extends StatefulWidget {
  const CollectLzyAccountView({super.key});

  @override
  State<CollectLzyAccountView> createState() => _CollectLzyAccountViewState();
}

class _CollectLzyAccountViewState extends State<CollectLzyAccountView>
    with AutomaticKeepAliveClientMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _configured = false;
  bool _showPass = false;
  String _updated = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await AdminService.instance.collectLzyCookie();
      if (!mounted) return;
      setState(() {
        _configured = r['configured'] == true || r['configured'] == 1;
        _updated = (r['updated'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _save() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text.trim();
    if (u.isEmpty || p.isEmpty) {
      ToastUtil.info('请填写蓝奏云账号和密码');
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminService.instance.collectLzyCookieSave(user: u, pass: p);
      if (!mounted) return;
      _passCtrl.clear();
      ToastUtil.success('已提交，采集平台正在获取 Cookie');
      await _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('清空蓝奏云 Cookie'),
        content: const Text('清空后需要重新填写账号密码才能采集。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Get.back(result: true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AdminService.instance.collectLzyCookieClear();
      ToastUtil.success('已请求清空');
      await _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const LoadingState(text: '读取蓝奏云配置…');
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdCard(
            radius: R.md,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  _configured
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  size: 22,
                  color: _configured ? C.success : C.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _configured ? '蓝奏云 Cookie 已配置' : '尚未配置蓝奏云 Cookie',
                        style: Ty.h3.copyWith(fontSize: 14, color: context.t1),
                      ),
                      if (_updated.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '更新时间：$_updated',
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_configured)
                  MiniAction(
                    label: '清空',
                    icon: Icons.delete_outline_rounded,
                    color: C.danger,
                    onTap: _busy ? () {} : _clear,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AdCard(
            radius: R.md,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdSection(title: '填写蓝奏云账号', accent: C.brand),
                const SizedBox(height: 4),
                Text(
                  '采集选中的软件时，会由采集平台上传到你的蓝奏云。'
                  '填一次即可，之后无需再管。',
                  style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userCtrl,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: '蓝奏云账号',
                    isDense: true,
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.md),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passCtrl,
                  obscureText: !_showPass,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: '蓝奏云密码',
                    isDense: true,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: context.t3,
                      ),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.md),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: '获取并保存 Cookie',
                  icon: Icons.cloud_upload_rounded,
                  height: 46,
                  loading: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AdCard(
            radius: R.md,
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 17, color: C.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cookie 由采集平台加密保存。为账号安全，建议用完后'
                    '在上方点「清空」，下次采集时再重新填写。',
                    style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
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
