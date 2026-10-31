import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ui_config.dart';

/// 轻音效（下载完成 / 签到成功 / 来消息 / 有新版本）
///
/// ★★ 1031 重做（用户反馈「乱七八糟的音效」）：
///   原 4 个 wav 是单频纯音哔声（882/1050/658Hz），观感廉价。
///   现改为真人语音播报（微软 Edge 神经语音，可商用），三套音色随后台下发：
///     yunxi    男声·阳光（默认）
///     xiaoxiao 女声·温暖
///     yunyang  男声·沉稳
///   资产：assets/audio/voice/{style}-{scene}.mp3（12 个共 96KB）
class SoundUtil {
  SoundUtil._();

  /// 当前音色（后台 sfx.voice_style 下发）
  static String voiceStyle = 'yunxi';
  static const voiceStyles = <String, String>{
    'yunxi': '男声 · 阳光',
    'xiaoxiao': '女声 · 温暖',
    'yunyang': '男声 · 沉稳',
  };

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
    // ★ 1031：人声音色随配置下发；变化时重建播放器
    if (voiceStyles.containsKey(s.voiceStyle) && s.voiceStyle != voiceStyle) {
      voiceStyle = s.voiceStyle;
      onVoiceStyleChanged();
    }
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

  /// 当前音色变化后调用：丢弃旧实例，下次播放按新音色重建
  static void onVoiceStyleChanged() {
    for (final p in _players.values) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }

  /// 预热（避免第一次有延迟）
  ///
  /// ★ 1031：按当前音色加载 assets/audio/voice/{style}-{scene}.mp3；
  ///   资产缺失时回退默认音色 yunxi。
  static Future<void> _warmUp() async {
    for (final k in ['download', 'sign', 'message', 'update']) {
      if (_players.containsKey(k)) continue;
      try {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        try {
          await p.setPlayerMode(PlayerMode.lowLatency);
        } catch (_) {}
        await p.setSource(AssetSource('audio/voice/$voiceStyle-$k.mp3'));
        _players[k] = p;
      } catch (_) {
        // 当前音色资产缺失 → 回退默认音色
        try {
          final p = AudioPlayer();
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('audio/voice/yunxi-$k.mp3'));
          _players[k] = p;
        } catch (_) {}
      }
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
