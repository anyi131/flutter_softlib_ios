import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/message_service.dart';
import 'fcm_service.dart';
import '../api/user_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// 通知栏推送（1016 新增）
///
/// 背景：服务端早就在「回复 / 评论 / 点赞 / 订单」时写消息了，
///   但 App 只在消息中心显示红点 —— 用户不进 App 就看不到。
///
/// 做法（不引入任何新插件，走已有原生通道，风险最低）：
///   · 原生侧自己建渠道 + 弹通知（MainActivity.kt 的 initNotify/showNotify）
///   · Dart 侧定时（45s）+ 回到前台时拉一次未读消息，
///     只对「比上次提示过的 id 更新」的消息弹通知，避免重复打扰
///   · 已提示到的 id 存本地，重启不会重复弹
///   · 首次运行只记录基线，不补弹历史消息
///   · 用户可关（消息页顶栏铃铛），默认开
///
/// 说明：iOS 侧暂未接（需要在 Swift 侧实现），调用会静默跳过。
/// ═══════════════════════════════════════════════════════════════
class NotifyService with WidgetsBindingObserver {
  NotifyService._();
  static final NotifyService instance = NotifyService._();

  static const _ch = MethodChannel('softlib/installer');
  static const _kLastId = 'notify_last_msg_id';
  static const _kEnabled = 'notify_enabled';

  Timer? _timer;
  /// 长轮询循环是否在跑（前台才跑）
  bool _loopRunning = false;
  int _lastId = 0;
  bool _firstRun = true;
  bool _enabled = true;
  bool _started = false;

  bool get enabled => _enabled;

  /// 初始化 + 启动轮询（启动时调用一次即可）
  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      final sp = await SharedPreferences.getInstance();
      _lastId = sp.getInt(_kLastId) ?? 0;
      _enabled = sp.getBool(_kEnabled) ?? true;
      _firstRun = _lastId <= 0;
    } catch (_) {}

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        // 通知权限（Android 13+）
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
        await _ch.invokeMethod('initNotify');
      } catch (_) {}
    }

    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}

    // 兜底轮询（长轮询不可用时也能收到，间隔放长不浪费）
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => tick());
    // ★ 前台用长轮询：几乎秒级收到（服务端挂住请求，一有新消息立刻返回）
    Timer(const Duration(seconds: 3), () {
      tick();
      _startLoop();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台：立即查一次 + 恢复长轮询
      tick();
      _startLoop();
    } else {
      // 退到后台：停掉长轮询（系统本来也会挂起 App，
      // 继续挂着只会白占服务器 worker 和电量）
      _stopLoop();
    }
  }

  void _startLoop() {
    if (_loopRunning) return;
    _loopRunning = true;
    _loop();
  }

  void _stopLoop() {
    _loopRunning = false;
  }

  /// 长轮询循环：有新消息立刻弹，然后马上再发起下一次
  Future<void> _loop() async {
    while (_loopRunning) {
      if (!_enabled || !UserService.instance.isLoggedIn) {
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }
      final d = await MessageService.instance.wait(lastId: _lastId);
      if (!_loopRunning) break;
      final raw = (d['list'] as List?) ?? const [];
      final list = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (list.isNotEmpty) {
        if (_firstRun) {
          // 首轮只记基线，不补弹历史
          _firstRun = false;
        } else {
          for (final m in list) {
            await _show(m);
          }
        }
        for (final m in list) {
          final id = (m['id'] as num?)?.toInt() ?? 0;
          if (id > _lastId) _lastId = id;
        }
        await _save();
      }
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  /// 开关（消息页顶栏铃铛）
  Future<void> setEnabled(bool v) async {
    _enabled = v;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kEnabled, v);
    } catch (_) {}
    if (v) tick();
  }

  bool _fcmReported = false;

  /// 拉一次未读消息，给「新消息」弹通知
  Future<void> tick() async {
    if (!UserService.instance.isLoggedIn) return;
    // ★ 1016：登录后补报一次 FCM token（启动时上报时可能还没登录，会被服务端拒绝）
    if (!_fcmReported) {
      _fcmReported = true;
      try {
        FcmService.reportNow();
      } catch (_) {}
    }
    if (!_enabled) return;
    try {
      final d = await MessageService.instance.list(page: 1);
      final raw = (d['list'] as List?) ?? const [];
      final list = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (list.isEmpty) return;

      int maxId = _lastId;
      for (final m in list) {
        final id = (m['id'] as num?)?.toInt() ?? 0;
        if (id > maxId) maxId = id;
      }

      // 首次运行：只记录基线，不补弹历史
      if (_firstRun) {
        _firstRun = false;
        _lastId = maxId;
        await _save();
        return;
      }

      final fresh = list
          .where((m) => ((m['id'] as num?)?.toInt() ?? 0) > _lastId)
          .toList()
        ..sort(
          (a, b) => ((a['id'] as num?)?.toInt() ?? 0).compareTo(
            (b['id'] as num?)?.toInt() ?? 0,
          ),
        );

      if (fresh.isNotEmpty) {
        // 一次最多弹 3 条，其余合并成一条「还有 N 条」
        final show = fresh.length > 3 ? fresh.sublist(fresh.length - 3) : fresh;
        for (final m in show) {
          await _show(m);
        }
        if (fresh.length > 3) {
          await _raw(
            id: 900001,
            title: '还有 ${fresh.length - 3} 条新消息',
            body: '打开「消息」查看全部动态',
          );
        }
        _lastId = maxId;
        await _save();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_kLastId, _lastId);
    } catch (_) {}
  }

  /// 消息 → 通知（标题按类型加个前缀，一眼能分清）
  Future<void> _show(Map<String, dynamic> m) async {
    final type = (m['type'] ?? 'system').toString();
    final prefix = switch (type) {
      'like' => '👍 ',
      'comment' => '💬 ',
      'reply' => '↩️ ',
      'order' => '🛒 ',
      'vip' => '💎 ',
      'system' => '📢 ',
      _ => '🔔 ',
    };
    final title = (m['title'] ?? '').toString();
    final body = (m['content'] ?? '').toString();
    await _raw(
      id: (((m['id'] as num?)?.toInt() ?? 0).abs() % 100000) + 1,
      title: prefix + (title.isEmpty ? '新消息' : title),
      body: body.isEmpty ? '打开 App 查看详情' : body,
    );
  }

  /// 立即弹一条通知（FCM 前台消息等场景用）
  Future<void> showNow(String title, String body) => _raw(
    id: (DateTime.now().millisecondsSinceEpoch % 100000) + 1,
    title: title.isEmpty ? '新消息' : title,
    body: body,
  );

  Future<void> _raw({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _ch.invokeMethod('showNotify', {
        'id': math.max(1, id),
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }
}
