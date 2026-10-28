import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';

import '../../design/app_anim.dart';
import '../../config.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'app_download_logic.dart';

/// 软件下载列表（v40 重做）
///
/// 设计要点：
///   · 沿用全项目「沉浸式玻璃拟态」语言，与其它页面统一
///   · 分两组：进行中 / 已完成，一眼看清
///   · 每条卡片：图标 + 名称 + 状态胶囊 + 进度环/条 + 大小 + 操作按钮
///   · 空状态有插画级提示，不再是干巴巴的一行字
class AppDownloadPage extends StatefulWidget {
  const AppDownloadPage({super.key});

  @override
  State<AppDownloadPage> createState() => _AppDownloadPageState();
}

class _AppDownloadPageState extends State<AppDownloadPage> {
  // v52f #2：批量管理模式
  bool _manageMode = false;
  final Set<String> _selected = {};
  final AppDownloadLogic logic = Get.find<AppDownloadLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: GetBuilder<AppDownloadLogic>(
                    id: 'downInfos',
                    builder: (logic) {
                      final list = logic.downInfos;
                      if (list == null) {
                        return const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        );
                      }
                      if (list.isEmpty) return _empty();

                      final running = list
                          .where((d) => d.status != DownloadTaskStatus.complete)
                          .toList();
                      final done = list
                          .where((d) => d.status == DownloadTaskStatus.complete)
                          .toList();

                      return RefreshIndicator(
                        onRefresh: () async {
                          await logic.getAllDownInfos();
                          await Future.delayed(
                            const Duration(milliseconds: 300),
                          );
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            4,
                            context.pagePadding,
                            context.tabSpace + 30,
                          ),
                          children: [
                            if (running.isNotEmpty) ...[
                              _groupTitle('进行中', running.length, C.brand),
                              const SizedBox(height: 10),
                              ...running.map((d) => _card(d)),
                              const SizedBox(height: 18),
                            ],
                            if (done.isNotEmpty) ...[
                              _groupTitle('已完成', done.length, C.success),
                              const SizedBox(height: 10),
                              ...done.map((d) => _card(d)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 批量操作条（管理模式，v52f #2）
          if (_manageMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  10 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: context.isDark ? C.bg1 : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 18,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final logic = Get.find<AppDownloadLogic>();
                        final all = (logic.downInfos ?? [])
                            .map((d) => d.taskId ?? d.appId ?? '')
                            .where((k) => k.isNotEmpty)
                            .toSet();
                        setState(() {
                          if (all.length == _selected.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(all);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: context.t3.withAlpha(80)),
                        ),
                        child: Text(
                          '全选',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: context.t2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    GestureDetector(
                      onTap: () async {
                        if (_selected.isEmpty) {
                          ToastUtil.info('请先勾选任务');
                          return;
                        }
                        final logic = Get.find<AppDownloadLogic>();
                        final items = (logic.downInfos ?? [])
                            .where(
                              (d) => _selected.contains(d.taskId ?? d.appId),
                            )
                            .toList();
                        final ok = await Get.dialog<bool>(
                          AppDialog(
                            title: const Text('批量删除'),
                            content: Text(
                              '将删除所选 ${items.length} 项的记录和已下载文件，确定吗？',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Get.back(result: true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await logic.deleteMany(items);
                          _selected.clear();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: C.danger.withAlpha(24),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: C.danger.withAlpha(90)),
                        ),
                        child: Text(
                          '删除所选 (${_selected.length})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: C.danger,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final logic = Get.find<AppDownloadLogic>();
                        final ok = await Get.dialog<bool>(
                          AppDialog(
                            title: const Text('清空失败任务'),
                            content: const Text('将删除全部失败/取消任务的记录，确定吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Get.back(result: true),
                                child: const Text('清空'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await logic.clearFailed();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: C.brand.withAlpha(22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: C.brand.withAlpha(90)),
                        ),
                        child: Text(
                          '清空失败',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: C.brand,
                          ),
                        ),
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

  // ───── 顶栏 ─────
  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        10,
      ),
      child: Row(
        children: [
          AppPressable(
            onTap: () => Get.back(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(8),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: context.t1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (r) => Deco.aurora().createShader(r),
            child: Text(
              '下载管理',
              style: Ty.h2.copyWith(color: Colors.white, fontSize: 21),
            ),
          ),
          const Spacer(),
          GetBuilder<AppDownloadLogic>(
            id: 'downInfos',
            builder: (logic) {
              final n = logic.downInfos?.length ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Pill('$n 个任务', color: C.brand, small: true);
            },
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _manageMode = !_manageMode;
                _selected.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _manageMode
                    ? C.brand.withAlpha(30)
                    : (context.isDark
                          ? Colors.white.withAlpha(14)
                          : Colors.white),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _manageMode
                      ? C.brand.withAlpha(140)
                      : (context.isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(12)),
                ),
              ),
              child: Text(
                _manageMode ? '取消' : '管理',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _manageMode ? C.brand : context.t2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTitle(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 15,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: Ty.h3.copyWith(fontSize: 15, color: context.t1)),
        const SizedBox(width: 6),
        Text('$count', style: Ty.tiny.copyWith(color: context.t3)),
      ],
    );
  }

  // ───── 空状态 ─────
  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [C.brand.withAlpha(40), C.cyan.withAlpha(24)],
              ),
            ),
            child: Icon(
              Icons.download_done_rounded,
              size: 44,
              color: C.brand.withAlpha(200),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '暂无下载任务',
            style: Ty.h3.copyWith(fontSize: 15.5, color: context.t1),
          ),
          const SizedBox(height: 8),
          Text('去软件库里挑一个喜欢的吧', style: Ty.small.copyWith(color: context.t3)),
          const SizedBox(height: 20),
          SoftButton(
            label: '去逛逛',
            icon: Icons.explore_rounded,
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  // ───── 单条卡片 ─────
  Widget _card(DownInfo d) {
    final status = d.status;
    final color = _statusColor(status);
    final isDone = status == DownloadTaskStatus.complete;
    final progress = (d.progress ?? 0) / 100.0;
    final selKey = d.taskId ?? d.appId ?? '';
    final isSelected = _selected.contains(selKey);

    return GetBuilder<AppDownloadLogic>(
      id: '${d.appId}',
      builder: (logic) {
        return KitCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _manageMode
                    ? () => setState(() {
                        isSelected
                            ? _selected.remove(selKey)
                            : _selected.add(selKey);
                      })
                    : null,
                child: Row(
                  children: [
                    // 批量管理模式：勾选框（v52f #2）
                    if (_manageMode) ...[
                      GestureDetector(
                        onTap: () => setState(() {
                          isSelected
                              ? _selected.remove(selKey)
                              : _selected.add(selKey);
                        }),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 22,
                          color: isSelected ? C.brand : context.t3,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    // 图标（带状态角标）
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(R.md),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: (d.appIcon ?? '').isEmpty
                                ? _iconFallback()
                                : CachedNetworkImage(
                                    imageUrl: d.appIcon!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 120,
                                    placeholder: (_, __) => _iconFallback(),
                                    errorWidget: (_, __, ___) =>
                                        _iconFallback(),
                                  ),
                          ),
                        ),
                        if (isDone)
                          Positioned(
                            right: -3,
                            bottom: -3,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: C.success,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.h3.copyWith(
                              fontSize: 14.5,
                              color: context.t1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Pill(
                                _statusText(status),
                                color: color,
                                small: true,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  _sizeText(d),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ty.tiny.copyWith(color: context.t3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 管理模式下右侧动作按钮隐藏（点击选择即可）
                    if (!_manageMode) ...[
                      const SizedBox(width: 8),
                      _actionBtn(d, logic),
                    ],
                  ],
                ),
              ),
              // 失败/取消：显示「重试 / 删除」操作条（v52f #2）
              if (status == DownloadTaskStatus.failed ||
                  status == DownloadTaskStatus.canceled) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _miniBtn(
                        icon: Icons.refresh_rounded,
                        label: '重试',
                        color: C.brand,
                        onTap: () => logic.retryDownload(d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniBtn(
                        icon: Icons.delete_outline_rounded,
                        label: '删除',
                        color: C.danger,
                        onTap: () => logic.deleteDownload(d),
                      ),
                    ),
                  ],
                ),
              ],
              // 已完成：显示「分享 / 删除」操作条
              if (isDone) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _miniBtn(
                        icon: Icons.ios_share_rounded,
                        label: '分享',
                        color: C.cyan,
                        onTap: () => logic.shareDownload(d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniBtn(
                        icon: Icons.delete_outline_rounded,
                        label: '删除',
                        color: C.danger,
                        onTap: () async {
                          final ok = await Get.dialog<bool>(
                            AppDialog(
                              title: const Text('删除下载'),
                              content: Text(
                                '将删除「${_displayName(d)}」的记录和已下载的文件，确定吗？',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(result: false),
                                  child: const Text('取消'),
                                ),
                                FilledButton(
                                  onPressed: () => Get.back(result: true),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) logic.deleteDownload(d);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              // 进度（已完成不显示进度条）
              if (!isDone) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.full),
                  child: LinearProgressIndicator(
                    value: progress.isNaN ? 0 : progress.clamp(0.0, 1.0),
                    backgroundColor: context.isDark
                        ? Colors.white.withAlpha(16)
                        : Colors.black.withAlpha(10),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '${d.progress ?? 0}%',
                      style: Ty.tiny.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      (d.appSize ?? '').trim().isEmpty
                          ? ''
                          : '${calculateDownloadedSize(d.appSize!, d.progress ?? 0)} / ${d.appSize}',
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _iconFallback() => Container(
    color: C.brand.withAlpha(context.isDark ? 34 : 22),
    child: Icon(Icons.android, color: C.brand, size: 26),
  );

  /// 小操作按钮（分享 / 删除）
  Widget _miniBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withAlpha(context.isDark ? 34 : 22),
      borderRadius: BorderRadius.circular(R.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.full),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 右侧主操作按钮
  Widget _actionBtn(DownInfo d, AppDownloadLogic logic) {
    IconData icon;
    Color color;
    VoidCallback onTap;
    String tip;
    switch (d.status) {
      case DownloadTaskStatus.enqueued:
        icon = Icons.hourglass_top_rounded;
        color = C.warning;
        tip = '等待中';
        onTap = () {};
        break;
      case DownloadTaskStatus.running:
        icon = Icons.pause_rounded;
        color = C.brand;
        tip = '暂停';
        onTap = () => logic.pauseDownload(d);
        break;
      case DownloadTaskStatus.paused:
        icon = Icons.play_arrow_rounded;
        color = C.warning;
        tip = '继续';
        onTap = () => logic.resumeDownload(d);
        break;
      case DownloadTaskStatus.failed:
        icon = Icons.refresh_rounded;
        color = C.danger;
        tip = '重试';
        onTap = () => logic.retryDownload(d);
        break;
      case DownloadTaskStatus.complete:
        icon = Icons.install_mobile_rounded;
        color = C.brand; // v52f #4：安装动作用品牌色
        tip = '安装';
        onTap = () => logic.openDownloadFile(d);
        break;
      default:
        icon = Icons.more_horiz_rounded;
        color = context.t3;
        tip = '';
        onTap = () {};
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPressable(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withAlpha(context.isDark ? 40 : 26),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(90), width: 0.8),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
        if (tip.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(tip, style: Ty.tiny.copyWith(fontSize: 9.5, color: color)),
        ],
      ],
    );
  }

  /// 列表显示名：优先数据库里的应用名；
  /// 没有则退回任务真实文件名（去掉 .apk 后缀和自动追加的时间戳），
  /// 绝不显示「未知文件」这种无信息量的占位。
  String _displayName(DownInfo d) {
    final name = (d.appName ?? '').trim();
    if (name.isNotEmpty && name != '未知文件') return name;
    var fn = (d.fileName ?? '').trim();
    if (fn.isEmpty) return '下载文件';
    fn = fn.replaceAll('_', ' ');
    final apk = fn.toLowerCase().lastIndexOf('.apk');
    if (apk > 0) fn = fn.substring(0, apk);
    fn = fn.replaceFirst(RegExp(r'\s*\d{13}$'), '');
    return fn.trim().isEmpty ? '下载文件' : fn.trim();
  }

  String _sizeText(DownInfo d) {
    final s = (d.appSize ?? '').trim();
    return s.isEmpty ? '大小未知' : s;
  }

  String _statusText(DownloadTaskStatus? status) {
    switch (status) {
      case DownloadTaskStatus.enqueued:
        return '等待中';
      case DownloadTaskStatus.running:
        return '下载中';
      case DownloadTaskStatus.paused:
        return '已暂停';
      case DownloadTaskStatus.failed:
        return '下载失败';
      case DownloadTaskStatus.complete:
        return '已完成';
      default:
        return '未知';
    }
  }

  Color _statusColor(DownloadTaskStatus? status) {
    switch (status) {
      case DownloadTaskStatus.enqueued:
        return C.warning;
      case DownloadTaskStatus.running:
        return C.brand;
      case DownloadTaskStatus.paused:
        return C.warning;
      case DownloadTaskStatus.failed:
        return C.danger;
      case DownloadTaskStatus.complete:
        return C.success;
      default:
        return context.t3;
    }
  }
}
