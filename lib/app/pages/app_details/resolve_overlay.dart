import 'dart:async';

import '../../utils/safe_ctx.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../design/app_anim.dart';
import '../../design/ui.dart';
import '../../design/lucide.dart';

/// ═══════════════════════════════════════════════════════════════
/// 下载链路加载动画（v52 #3）
///
///  · [ResolveOverlay]：点「解析并下载」后显示的加载浮层
///    （解析蓝奏云直链可能需要 1~6 秒，期间有呼吸动画 + 阶段文案）
///  · 下载任务真正创建成功 → 自动关闭浮层，让位给底部进度面板
///  · 解析失败 → 浮层自动关闭（由调用方弹错误窗）
/// ═══════════════════════════════════════════════════════════════
class ResolveOverlay {
  ResolveOverlay._();

  static OverlayEntry? _entry;
  static _ResolveOverlayState? _state;

  /// 显示（幂等：已在显示则更新阶段文案）
  static void show({String stage = '正在解析下载地址…'}) {
    // 1109：残留的「未插入」entry 先清理（上次 ctx 为 null 时会留下）
    if (_entry != null && !_inserted) {
      _entry = null;
      _state = null;
    }
    if (_entry != null) {
      _state?.setStage(stage);
      return;
    }
    _entry = OverlayEntry(builder: (_) => const _ResolveOverlayView());
    final ctx = Get.context;
    if (ctx == null) return;
    final _ctx = SafeCtx.of();
    if (_ctx == null) return;
    // ★ 1109：Overlay.of() 在路由过渡/弹窗遮盖期间会断言失败（表现为
    //   Null check operator，真机 /appDetails 高频出现）——
    //   浮层显示失败绝不阻断下载主流程，下一帧再试一次。
    try {
      Overlay.of(_ctx, rootOverlay: true).insert(_entry!);
      _inserted = true;
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final c2 = SafeCtx.of();
          if (c2 != null && _entry != null && !_inserted) {
            Overlay.of(c2, rootOverlay: true).insert(_entry!);
            _inserted = true;
          }
        } catch (_) {}
      });
    }
  }

  /// 更新阶段文案
  static void stage(String text) => _state?.setStage(text);

  /// 关闭（幂等）
  /// ★ 1109：remove() 对「从未 insert」或「已被移除」的 entry 会抛
  ///   Null check operator —— 真机日志 zone 通道反复出现（/index、/appDetails）。
  ///   这里：只在真正插入过时才 remove，并兜异常。
  static bool _inserted = false;

  static void dismiss() {
    final e = _entry;
    _entry = null;
    _state = null;
    if (e == null || !_inserted) return;
    _inserted = false;
    try {
      if (e.mounted) {
        e.remove();
      }
    } catch (_) {}
  }
}

class _ResolveOverlayView extends StatefulWidget {
  const _ResolveOverlayView();

  @override
  State<_ResolveOverlayView> createState() => _ResolveOverlayState();
}

class _ResolveOverlayState extends State<_ResolveOverlayView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  String _stage = '正在解析下载地址…';

  @override
  void initState() {
    super.initState();
    ResolveOverlay._state = this;
    _c.repeat();
  }

  @override
  void dispose() {
    if (ResolveOverlay._state == this) ResolveOverlay._state = null;
    _c.dispose();
    super.dispose();
  }

  void setStage(String s) {
    if (!mounted) return;
    setState(() => _stage = s);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Material(
      color: Colors.black.withAlpha(96),
      child: Center(
        child: AppScaleIn(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
            decoration: BoxDecoration(
              color: isDark ? C.bg2 : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 三层呼吸圆环
                SizedBox(
                  width: 64,
                  height: 64,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final t = (_c.value * 2) % 1.0; // 0-1 循环
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          for (int i = 0; i < 3; i++)
                            Transform.scale(
                              scale: 1 + ((t + i / 3) % 1.0) * 0.55,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: C.brand.withAlpha(
                                      (255 * (1 - ((t + i / 3) % 1.0))) ~/ 2,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          Icon(
                            Lz.downloadCloud,
                            color: C.brand,
                            size: 26,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _stage,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? C.t1 : C.lt1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '解析成功后将自动开始下载',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? C.t3 : C.lt3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 阶段文案常量
class ResolveStages {
  ResolveStages._();
  static const resolving = '正在解析下载地址…';
  static const retrying = '网络波动，正在重试…';
  static const starting = '解析成功，正在创建下载任务…';
}

/// 带加载动画的下载流程包装（addDownload 返回 void：浮层由 logic 内部管理）
Future<void> runDownloadWithOverlay(Future<void> Function() job) async {
  try {
    await job();
  } finally {
    ResolveOverlay.dismiss();
  }
}
