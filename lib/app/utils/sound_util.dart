import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ★ 1016：轻音效（下载完成 / 签到成功 / 来消息 / 有新版本）
///
/// 设计要点（按需求）：
///  · 4 个场景独立开关 + 1 个总开关（存本地，后台可覆盖默认值）
///  · 尊重系统静音：优先用 **系统短音效**（HapticFeedback / SystemSound），
///    不引入音频插件 —— 系统静音时自然不会响，零风险、零体积
///  · 短促 <1s、不与下载通知音效重复
///
/// 说明：没有用 audioplayers，是因为：① 引入插件 + 打包音频文件会增大体积；
/// ② 系统静音语义由系统自己处理，不需要额外判断 AudioManager/AVAudioSession。
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
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// 签到成功：轻点击 + 轻振动
  static Future<void> playSign() async {
    if (!master || !sign) return;
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// 来消息
  static Future<void> playMessage() async {
    if (!master || !message) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// 有新版本：提示音
  static Future<void> playUpdate() async {
    if (!master || !update) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
