////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 本机偏好
// 服务端下发的 JicunSettings 只作为默认值：用户在本机改过之后，
// 一律以 SharedPreferences 里的值为准（key 统一前缀 jicun.）。
//
// 读盘只发生在第一次 load()；之后 getter 直接读内存，set 先改内存再异步写盘。
// 这样页面里可以同步取到值，不必每个控件都包一层 FutureBuilder。
////////////////////////////////////////////////////////////////////////////////
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jicun_config.dart';

/// 「即存」本机设置：内存缓存 + SharedPreferences 落盘。
class JicunPrefs {
  JicunPrefs._();

  static final JicunPrefs instance = JicunPrefs._();

  // —— 存储键（统一前缀，避免和宿主其它模块撞名） ——
  static const String kAutoPaste = 'jicun.autoPaste';
  static const String kSaveDirName = 'jicun.saveDirName';
  static const String kNotifyOnDone = 'jicun.notifyOnDone';
  static const String kNotifyOnFail = 'jicun.notifyOnFail';
  static const String kWifiOnly = 'jicun.wifiOnly';

  /// 目录名兜底值（与后台 save_dir_name 的默认值一致）。
  static const String defaultSaveDirName = '安逸软件汇';

  /// 目录名长度上限（去首尾空格后计算）。
  static const int maxSaveDirNameLength = 20;

  /// 文件系统保留字符，出现即判非法。
  static final RegExp _invalidNameChars = RegExp(r'[/\\:*?"<>|]');

  /// 任意偏好变化时 +1，设置主页用它刷新副标题。
  /// 单例没有 dispose 时机，所以不持有监听者之外的生命周期。
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SharedPreferences? _store;
  bool _loaded = false;
  Future<void>? _loading;

  // null = 还没读盘/没改过，getter 此时回落到服务端默认值。
  bool? _autoPaste;
  String? _saveDirName;
  bool? _notifyOnDone;
  bool? _notifyOnFail;
  bool? _wifiOnly;

  // ─────────────────────────── 公开读写 ───────────────────────────

  /// 服务端默认值：自动粘贴（字段缺失/类型异常按 true）。
  bool get autoPaste => _autoPaste ?? _serverAutoPaste();

  /// 服务端默认值：保存目录名（空/非法/异常回落到「安逸软件汇」）。
  String get saveDirName => _saveDirName ?? _serverSaveDirName();

  /// 无服务端字段，本机默认 true。
  bool get notifyOnDone => _notifyOnDone ?? true;

  /// 无服务端字段，本机默认 true。
  bool get notifyOnFail => _notifyOnFail ?? true;

  /// 无服务端字段，本机默认 false。
  bool get wifiOnly => _wifiOnly ?? false;

  /// 读一次盘；幂等，重复调用无副作用（并发调用共享同一次读盘）。
  Future<void> load() async {
    if (_loaded) return;
    final pending = _loading;
    if (pending != null) {
      await pending;
      return;
    }
    final task = _readFromDisk();
    _loading = task;
    try {
      await task;
      _loaded = true;
    } finally {
      _loading = null;
    }
  }

  /// 是否已经读过一次盘。
  bool get isLoaded => _loaded;

  Future<void> setAutoPaste(bool v) async {
    _autoPaste = v; // 先改内存，getter 立刻能读到
    _bump();
    await _write((sp) => sp.setBool(kAutoPaste, v));
  }

  /// 写入目录名。非法值（空、超长、含保留字符）直接忽略，不落盘。
  Future<void> setSaveDirName(String v) async {
    final name = v.trim();
    if (!isValidSaveDirName(name)) return;
    _saveDirName = name;
    _bump();
    await _write((sp) => sp.setString(kSaveDirName, name));
  }

  Future<void> setNotifyOnDone(bool v) async {
    _notifyOnDone = v;
    _bump();
    await _write((sp) => sp.setBool(kNotifyOnDone, v));
  }

  Future<void> setNotifyOnFail(bool v) async {
    _notifyOnFail = v;
    _bump();
    await _write((sp) => sp.setBool(kNotifyOnFail, v));
  }

  Future<void> setWifiOnly(bool v) async {
    _wifiOnly = v;
    _bump();
    await _write((sp) => sp.setBool(kWifiOnly, v));
  }

  // ─────────────────────────── 校验 ───────────────────────────

  /// 目录名是否可用：去空格后非空、≤20 字、不含 `/\:*?"<>|`。
  static bool isValidSaveDirName(String v) {
    final name = v.trim();
    if (name.isEmpty || name.length > maxSaveDirNameLength) return false;
    return !_invalidNameChars.hasMatch(name);
  }

  // ─────────────────────────── 内部实现 ───────────────────────────

  /// 服务端自动粘贴开关；用 dynamic 兜住字段缺失/为 null 的情况。
  bool _serverAutoPaste() {
    try {
      final dynamic v = JicunSettings.instance.cfg.autoPaste;
      if (v is bool) return v;
      if (v == null) return true;
      return v == 1 || v == '1' || v == 'true';
    } catch (_) {
      return true;
    }
  }

  /// 服务端保存目录名；空值或非法值回落到内置默认值。
  String _serverSaveDirName() {
    try {
      final dynamic v = JicunSettings.instance.cfg.saveDirName;
      final name = (v ?? '').toString().trim();
      if (isValidSaveDirName(name)) return name;
    } catch (_) {
      return defaultSaveDirName;
    }
    return defaultSaveDirName;
  }

  /// 统一写盘：失败只记日志，不回滚已经生效的内存值。
  Future<void> _write(Future<bool> Function(SharedPreferences sp) op) async {
    final sp = await _prefs();
    if (sp == null) return;
    try {
      await op(sp);
    } catch (e) {
      if (kDebugMode) debugPrint('[jicun] prefs 写盘失败: $e');
    }
  }

  Future<void> _readFromDisk() async {
    final sp = await _prefs();
    if (sp == null) return;

    var changed = false;
    bool? readBool(String key) {
      try {
        return sp.getBool(key);
      } catch (_) {
        return null;
      }
    }

    // 已经改过的字段（缓存非 null）不被盘上的旧值覆盖，避免 set 与 load 抢跑。
    if (_autoPaste == null) {
      final v = readBool(kAutoPaste);
      if (v != null) {
        _autoPaste = v;
        changed = true;
      }
    }
    if (_notifyOnDone == null) {
      final v = readBool(kNotifyOnDone);
      if (v != null) {
        _notifyOnDone = v;
        changed = true;
      }
    }
    if (_notifyOnFail == null) {
      final v = readBool(kNotifyOnFail);
      if (v != null) {
        _notifyOnFail = v;
        changed = true;
      }
    }
    if (_wifiOnly == null) {
      final v = readBool(kWifiOnly);
      if (v != null) {
        _wifiOnly = v;
        changed = true;
      }
    }
    if (_saveDirName == null) {
      String? v;
      try {
        v = sp.getString(kSaveDirName);
      } catch (_) {
        v = null;
      }
      if (v != null && isValidSaveDirName(v)) {
        _saveDirName = v.trim();
        changed = true;
      }
    }
    if (changed) _bump();
  }

  Future<SharedPreferences?> _prefs() async {
    final cached = _store;
    if (cached != null) return cached;
    try {
      return _store = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  void _bump() => revision.value++;

  /// 仅测试用：清掉内存缓存与「已加载」标记，让下一次 [load] 重新读盘。
  @visibleForTesting
  void resetForTest() {
    _autoPaste = null;
    _saveDirName = null;
    _notifyOnDone = null;
    _notifyOnFail = null;
    _wifiOnly = null;
    _loaded = false;
    _loading = null;
    _store = null;
  }
}
