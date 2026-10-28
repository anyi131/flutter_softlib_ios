import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ui_config.dart';

/// 轻音效（下载完成 / 签到成功 / 来消息 / 有新版本）
///
/// ★★ 1020 重做（用户反馈「音效开启了也没用」）：
///   原来根本没播音频 —— 只是 SystemSound.play(click) + 震动，
///   而多数手机默认关闭「触摸提示音」，所以用户开了开关也听不到。
///
///   现在：
///     · 真实音频文件（assets/audio/*.wav，4 个共 47KB）
///     · audioplayers 低延迟播放，每类独立实例（不抢彼此）
///     · 系统静音/勿扰时自动不响（由系统音频会话决定）
///     · 4 个场景独立开关 + 总开关，与后台配置一致
class SoundUtil {
  SoundUtil._();

  static const _kMaster = 'sfx_master';
  static const _kDownload = 'sfx_download';
  static const _kSign = 'sfx_sign';
  static const _kMessage = 'sfx_message';
  static const _kUpdate = 'sfx_update';

  static bool master = true;
  static bool download = true;
  static bool sign = true;
  static bool message = true;
  static bool update = true;

  static bool _loaded = false;

  /// 启动时读一次（本地偏好）
  static Future<void> init() async {
    if (_loaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      master = sp.getBool(_kMaster) ?? true;
      download = sp.getBool(_kDownload) ?? true;
      sign = sp.getBool(_kSign) ?? true;
      message = sp.getBool(_kMessage) ?? true;
      update = sp.getBool(_kUpdate) ?? true;
      _loaded = true;
    } catch (_) {}
  }

  /// ★ 1028：服务端下发的音效开关（ui_config.sfx）—— 全站统管
  ///
  /// 原来 4 个开关只写本机 SharedPreferences，后台一改只影响管理员自己那台，
  /// 用户端照旧默认 true，表现为「音效开关没用」。现在配置一拉到就覆盖本地。
  static void applyRemote(SfxConfig s) {
    master = s.master;
    download = s.download;
    sign = s.sign;
    message = s.message;
    update = s.update;
    _loaded = true;
  }

  /// 后台/设置页修改后保存
  static Future<void> save({
    bool? masterOn,
    bool? downloadOn,
    bool? signOn,
    bool? messageOn,
    bool? updateOn,
  }) async {
    if (masterOn != null) master = masterOn;
    if (downloadOn != null) download = downloadOn;
    if (signOn != null) sign = signOn;
    if (messageOn != null) message = messageOn;
    if (updateOn != null) update = updateOn;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kMaster, master);
      await sp.setBool(_kDownload, download);
      await sp.setBool(_kSign, sign);
      await sp.setBool(_kMessage, message);
      await sp.setBool(_kUpdate, update);
    } catch (_) {}
  }

  /// 下载完成：双击轻振动（系统会跟随静音设置）
  static Future<void> playDownload() async {
    if (!master || !download) return;
    _play('download');
  }

  /// 签到成功
  static Future<void> playSign() async {
    if (!master || !sign) return;
    _play('sign');
  }

  /// 来消息
  static Future<void> playMessage() async {
    if (!master || !message) return;
    _play('message');
  }

  /// 有新版本
  static Future<void> playUpdate() async {
    if (!master || !update) return;
    _play('update');
  }

  // ═══════════ 播放实现 ═══════════

  static final Map<String, AudioPlayer> _players = {};

  /// 预热（避免第一次有延迟）
  ///
  /// ★ 1028：改成「谁缺补谁」。原来一把 `_audioReady=true` 提前置位，
  ///   第一次创建失败（音频会话没就绪/静音）就再也不重试 → 全程无声。
  static Future<void> _warmUp() async {
    for (final k in ['download', 'sign', 'message', 'update']) {
      if (_players.containsKey(k)) continue;
      try {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        // ★ 1028：低延迟模式 —— 短音效走 MediaPlayer 时首帧有明显延迟，
        //   用户会觉得「开关点了没反应」。
        try {
          await p.setPlayerMode(PlayerMode.lowLatency);
        } catch (_) {}
        await p.setSource(AssetSource('audio/$k.wav'));
        _players[k] = p;
      } catch (_) {}
    }
  }

  static void _play(String name) {
    // 不 await：音效不应该阻塞任何业务逻辑
    () async {
      try {
        await _warmUp();
        final p = _players[name];
        if (p == null) return;
        // ★ 1028：stop() 之后必须把进度归零，否则 resume() 会「从头到尾都没有声音」
        await p.stop();
        try {
          await p.seek(Duration.zero);
        } catch (_) {}
        await p.resume();
      } catch (_) {
        // 静音 / 无音频设备 / 播放失败 —— 静默忽略，绝不影响主流程
      }
    }();
  }

  /// 释放（App 退出时）
  static Future<void> dispose() async {
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
