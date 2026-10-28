import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;

import '../api/api_host.dart';
import '../routes/app_pages.dart';

/// ★ 1028 真机自检：把当前画面用 RepaintBoundary 截成 PNG 并回传服务器
/// 目的：让开发端能直接看到「真机像素」，不用每次都靠用户手动截图发过来。
/// 触发方式：我的 → 关于 → 长按版本号胶囊
class SelfCheck {
  SelfCheck._();

  /// 挂在 MaterialApp.builder 最外层，见 main.dart
  static final GlobalKey boundaryKey = GlobalKey();

  /// 与服务器 public/selfcheck.php 约定的静态口令（只防误用，不含敏感信息）
  static const String _key = 'anyi-sc-2026-0931';

  static const String endpoint = '${ApiHost.base}/selfcheck.php';

  static bool _running = false;

  /// 场景：目录名 → 路由
  static const Map<String, String> _scenes = <String, String>{
    '01_index': Routes.index,
    '02_search': Routes.appSearch,
    '03_task': Routes.task,
    '04_favorites': Routes.favorites,
    '05_history': Routes.history,
    '06_about': Routes.about,
  };

  /// 截当前一帧。返回 null 表示拿不到画布（未挂载 / 正在绘制）
  static Future<Uint8List?> shot({double pixelRatio = 2.0}) async {
    final BuildContext? ctx = boundaryKey.currentContext;
    if (ctx == null) return null;
    final RenderObject? ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    if (ro.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }
    ui.Image? img;
    try {
      img = await ro.toImage(pixelRatio: pixelRatio);
      final ByteData? bd =
          await img.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) return null;
      return bd.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      img?.dispose();
    }
  }

  static Future<bool> _upload(
    String label,
    Uint8List bytes,
    String version,
    String route,
  ) async {
    try {
      final FormData form = FormData.fromMap(<String, dynamic>{
        'version': version,
        'label': label,
        'route': route,
        'ts': '${DateTime.now().millisecondsSinceEpoch}',
        'shot': MultipartFile.fromBytes(bytes, filename: '$label.png'),
      });
      final Response<dynamic> r = await Dio().post<dynamic>(
        endpoint,
        data: form,
        options: Options(
          headers: <String, String>{'X-SC-Key': _key},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final dynamic d = r.data;
      return d is Map && d['code'] == 1;
    } catch (e) {
      debugPrint('SELFCHECK upload fail $label: $e');
      return false;
    }
  }

  /// 跑一遍：逐个路由截图上传。任何一步失败都继续，最后汇报成功张数。
  static Future<void> run({required String version}) async {
    if (_running) return;
    _running = true;

    final List<String> names = _scenes.keys.toList();
    int ok = 0;
    int shotOk = 0;
    final List<String> failed = <String>[];

    EasyLoading.show(
      status: '自检 0/${names.length}',
      maskType: EasyLoadingMaskType.clear,
    );

    try {
      for (int i = 0; i < names.length; i++) {
        final String name = names[i];
        final String route = _scenes[name]!;
        EasyLoading.show(
          status: '自检 ${i + 1}/${names.length}',
          maskType: EasyLoadingMaskType.clear,
        );

        try {
          Get.offAllNamed<dynamic>(route);
        } catch (e) {
          failed.add('$name(跳转失败)');
          continue;
        }

        // 等转场 + 首屏数据/图片回来
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        // ★ 截图前必须收掉 loading 蒙层，否则自检图里全是转圈
        EasyLoading.dismiss();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await WidgetsBinding.instance.endOfFrame;

        final Uint8List? bytes = await shot();
        if (bytes == null) {
          failed.add('$name(截图空)');
          continue;
        }
        shotOk++;
        final bool sent = await _upload(name, bytes, version, route);
        if (sent) {
          ok++;
        } else {
          failed.add('$name(上传失败)');
        }
        if (i + 1 < names.length) {
          EasyLoading.show(
            status: '自检 ${i + 2}/${names.length}',
            maskType: EasyLoadingMaskType.clear,
          );
        }
      }
    } finally {
      // 收尾：回到首页，别把用户丢在半路
      try {
        Get.offAllNamed<dynamic>(Routes.index);
      } catch (_) {}
      EasyLoading.dismiss();
      _running = false;
    }

    final String msg = failed.isEmpty
        ? '自检完成：$ok/${names.length} 张已上传'
        : '自检完成：$ok/${names.length} 张已上传（截到 $shotOk 张）\n${failed.join('、')}';
    EasyLoading.showToast(msg, duration: const Duration(seconds: 4));
  }
}
