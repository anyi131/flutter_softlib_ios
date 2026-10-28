import 'dart:async';
import 'dart:convert';

import 'api_host.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/device_info_util.dart';

/// 用户信息模型
class UserInfo {
  final int id;
  final String username;
  final String nickname;
  final String email;
  final String avatar;
  final String qq;
  final int gender;
  final String bio;
  final int score;
  final String money;
  final bool isVip;
  final String vipExpire;
  final String inviteCode;
  final String jointime;
  final bool isAdmin;

  /// 自定义称号
  final String title;

  /// 用户自定义开屏图
  final String splashImage;

  /// 今日是否已签到（服务端权威值；null = 服务端未返回，回退本地缓存）
  final bool? signedToday;

  UserInfo({
    required this.id,
    required this.username,
    required this.nickname,
    required this.email,
    required this.avatar,
    required this.qq,
    required this.gender,
    required this.bio,
    required this.score,
    required this.money,
    required this.isVip,
    required this.vipExpire,
    required this.inviteCode,
    required this.jointime,
    this.isAdmin = false,
    this.title = '',
    this.splashImage = '',
    this.signedToday,
  });

  factory UserInfo.fromJson(Map json) {
    String s(String k) => (json[k] ?? '').toString();
    return UserInfo(
      id: int.tryParse(s('id')) ?? 0,
      username: s('username'),
      nickname: s('nickname'),
      email: s('email'),
      avatar: s('avatar'),
      qq: s('qq'),
      gender: int.tryParse(s('gender')) ?? 0,
      bio: s('bio'),
      score: int.tryParse(s('score')) ?? 0,
      money: s('money'),
      // ★ 1014 修复：会员判断必须兼容数字 1 / 字符串 "1" / 布尔 true，
      //   否则服务端返回 1 时会被误判成「非会员」，
      //   导致「我的」页显示 VIP 但下载却要求付费（用户反馈的严重逻辑矛盾）。
      isVip:
          json['is_vip'] == true ||
          json['is_vip'] == 1 ||
          s('is_vip') == 'true' ||
          s('is_vip') == '1',
      vipExpire: s('vip_expire'),
      inviteCode: s('invite_code'),
      jointime: s('jointime'),
      isAdmin:
          json['is_admin'] == true ||
          json['is_admin'] == 1 ||
          s('is_admin') == 'true' ||
          s('is_admin') == '1',
      title: s('title'),
      splashImage: s('splash_image'),
      signedToday: json.containsKey('signed_today')
          ? (json['signed_today'] == true || s('signed_today') == 'true')
          : null,
    );
  }

  /// 账号（展示用）
  ///
  /// ★ 需求 #3：优先显示 QQ 号；没有 QQ 则显示邮箱；再没有才用 username/id
  String get account {
    if (qq.isNotEmpty) return qq;
    if (email.isNotEmpty) return email;
    if (username.isNotEmpty) return username;
    return id > 0 ? id.toString() : '';
  }

  /// ★ 1014：按到期时间判断是否有效会员（比 is_vip 字段更可靠，
  ///   即使服务端某天不返回 is_vip，也能凭 vip_expire 正确识别）。
  bool get isVipActive {
    if (isVip) return true;
    final t = int.tryParse(vipExpire.replaceAll(RegExp(r'[^0-9]'), ''));
    if (t == null || t <= 0) return false;
    // 兼容秒/毫秒两种时间戳
    final sec = t > 100000000000 ? (t ~/ 1000) : t;
    return sec > DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  /// ★ 1014：是否有「免费下载付费资源」的权限（会员 或 管理员）
  bool get canFreeDownload => isVipActive || isAdmin;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
    'email': email,
    'avatar': avatar,
    'qq': qq,
    'gender': gender,
    'bio': bio,
    'score': score,
    'money': money,
    'is_vip': isVip,
    'vip_expire': vipExpire,
    'invite_code': inviteCode,
    'jointime': jointime,
    'is_admin': isAdmin,
    'title': title,
    'splash_image': splashImage,
  };
}

/// 用户服务：注册 / 登录 / 找回 / 资料 / QQ头像
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  static const String baseUrl = ApiHost.base;
  static const String _kToken = 'user_token';
  static const String _kUser = 'user_info';

  final Dio _dio = Dio(
    BaseOptions(
      headers: DeviceInfo.headers,
      baseUrl: baseUrl,
      // ★ 1016：登录/资料这类交互请求收紧超时（原来连 12s/收 20s，
      //   弱网下会「转很久才失败」，体感极差）
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  String _token = '';
  UserInfo? _user;

  String get token => _token;
  UserInfo? get user => _user;
  bool get isLoggedIn => _token.isNotEmpty && _user != null;

  /// 拉取后台配置（登录页要判断 QQ 登录开关等）
  Future<Map<String, dynamic>> fetchConfig() async {
    try {
      final r = await _dio.get('/api/softlib/config/index');
      if (r.data is Map && r.data['code'] == 1 && r.data['data'] is Map) {
        return Map<String, dynamic>.from(r.data['data']);
      }
    } catch (_) {}
    return {};
  }

  /// 用已有 token 直接登录（QQ 快捷登录回调后调用）
  /// ★ 1015：QQ 原生 SDK 登录 —— 用 SDK 拿到的 openid + access_token 换本站 token
  /// 服务端会向 QQ 校验 access_token 的有效性，再查/建账号。
  Future<Map<String, dynamic>> qqAuthBySdk({
    required String openid,
    required String accessToken,
  }) async {
    try {
      final r = await _dio.post(
        '/api/softlib/user/qq_sdk_login',
        data: {'openid': openid, 'access_token': accessToken},
        options: Options(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      if (r.data is Map) {
        final d = Map<String, dynamic>.from(r.data as Map);
        return Map<String, dynamic>.from((d['data'] as Map?) ?? d);
      }
      return {};
    } catch (e) {
      return {'msg': e.toString()};
    }
  }

  Future<bool> loginByToken(
    String token, {
    String nickname = '',
    String avatar = '',
  }) async {
    _token = token;
    final sp = await SharedPreferences.getInstance();
    // ★★★ 1016 关键修复（「提示登录成功，我的页还是未登录」的真因 #1）：
    //   这里原来写的是 sp.setString('token', token)，
    //   而全项目读的都是 _kToken（'user_token'）—— 键名不一致，登录态根本没落盘。
    //   更糟的是「我的」页 load() 会先 restore()，用空的 user_token
    //   把内存里的 _token 冲成 ''，于是界面立刻变回未登录。
    await sp.setString(_kToken, token);
    // ★ 1016 提速：这里**不再等资料请求**（调用方 QQ/密码登录成功后会立刻刷新「我的」，
    //   那一次就够了）。少一个网络往返，授权回来到「登录成功」明显更快。
    //   失败也不清 token —— 刚下发的 token 一定是有效的，
    //   真正的失效由 _onTokenExpired() 统一处理。
    unawaited(refreshProfile());
    return true;
  }

  /// ★ 1016：把 QQ 绑定到**当前已登录账号**
  ///   场景：老用户先用自己的邮箱账号登录 → 绑定 QQ →
  ///        以后 QQ 一键登录直接进这个号（不会再自动开一个新号）。
  /// ★ 1020：查询 QQ 绑定状态（我的页显示「已绑定/未绑定」）
  Future<bool> qqBound() async {
    try {
      final r = await _dio.post(
        '/api/softlib/user/qq_status',
        data: {'token': _token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        return (r.data['data']?['bound'] ?? 0) == 1;
      }
    } catch (_) {}
    return false;
  }

  /// ★ 1020：解绑 QQ（之前只有绑定，绑错了没法自救）
  Future<void> unbindQQ() async {
    final r = await _dio.post(
      '/api/softlib/user/unbind_qq',
      data: {'token': _token},
    );
    if (r.data is! Map) throw Exception('解绑失败：返回格式异常');
    final d = Map<String, dynamic>.from(r.data as Map);
    if (d['code'] != 1) throw Exception('${d['msg'] ?? '解绑失败'}');
  }

  Future<Map<String, dynamic>> bindQQ({
    required String openid,
    required String accessToken,
  }) async {
    final r = await _dio.post(
      '/api/softlib/user/bind_qq',
      data: {'token': _token, 'openid': openid, 'access_token': accessToken},
    );
    if (r.data is! Map) throw Exception('绑定失败：返回格式异常');
    final d = Map<String, dynamic>.from(r.data as Map);
    if (d['code'] != 1) throw Exception('${d['msg'] ?? '绑定失败'}');
    return Map<String, dynamic>.from((d['data'] as Map?) ?? {});
  }

  /// 启动时恢复登录态
  Future<void> restore() async {
    final sp = await SharedPreferences.getInstance();
    final t = sp.getString(_kToken) ?? '';
    // ★ 1016：prefs 里没值的时候不要清掉内存里刚写入的 token
    //   （否则「刚登录 → load() → restore()」这一拍就会把登录态抹掉）
    if (t.isNotEmpty) _token = t;
    final raw = sp.getString(_kUser);
    if (raw != null && raw.isNotEmpty) {
      try {
        _user = UserInfo.fromJson(jsonDecode(raw) as Map);
      } catch (_) {}
    }
  }

  Future<void> _save(String token, UserInfo? info) async {
    _token = token;
    if (info != null) _user = info;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, _token);
    if (_user != null) {
      final u = _user;
      if (u != null) await sp.setString(_kUser, jsonEncode(u.toJson()));
    }
  }

  Future<void> logout() async {
    final t = _token;
    _token = '';
    _user = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kUser);
    if (t.isNotEmpty) {
      try {
        await _dio.post('/api/softlib/user/logout', data: {'token': t});
      } catch (_) {}
    }
  }

  /// v52f #6：全局登录失效处理
  /// 任何接口返回「登录已失效/请先登录」时：清空本地登录态并广播，
  /// 让「我的」等页面立即回到未登录 UI（不再出现“提示失效但还显示已登录”）
  void _onTokenExpired() {
    if (_token.isEmpty && _user == null) return;
    _token = '';
    _user = null;
    SharedPreferences.getInstance().then((sp) {
      sp.remove(_kToken);
      sp.remove(_kUser);
    });
    expiredTick.value++;
  }

  /// 失效信号（UI 可监听重建）
  final RxInt expiredTick = 0.obs;

  static bool _isAuthMsg(String? msg) {
    if (msg == null) return false;
    return msg.contains('登录已失效') ||
        msg.contains('请先登录') ||
        msg.contains('token') && msg.contains('失效');
  }

  /// v52q：邀请统计（我的邀请码/已邀人数/累计奖励）
  Future<Map<String, dynamic>> inviteStats() async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/invite_stats',
        data: {'token': _token},
      ),
    );
    if (r['code'] == 1 && r['data'] is Map) {
      return Map<String, dynamic>.from(r['data']);
    }
    throw Exception(r['msg'] ?? '获取失败');
  }

  /// v52f #3：下载成功上报操作日志（fire-and-forget，失败静默）
  /// ★ 1014 安全：优先带 appId —— 服务端按 id 精确校验付费权限；
  ///   仅靠名称反查会被同名免费资源绕过。
  Future<void> downloadLog(String appName, {int appId = 0}) async {
    if (_token.isEmpty) return;
    try {
      await _dio.post(
        '/api/softlib/user/download_log',
        data: {
          'token': _token,
          'name': appName,
          if (appId > 0) 'app_id': appId,
        },
      );
    } catch (_) {}
  }

  /// 统一解析后端 {code,msg,data}（★ 失效检测内建在这里）
  Map<String, dynamic> _unwrap(Response resp) {
    final d = resp.data;
    if (d is Map) {
      final m = Map<String, dynamic>.from(d);
      if (m['code'] == 0 && _isAuthMsg(m['msg']?.toString())) {
        _onTokenExpired();
      }
      return m;
    }
    throw Exception('返回格式异常');
  }

  /// 发送邮箱验证码
  Future<void> sendCode(String email, {String scene = 'register'}) async {
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/send_code',
        data: {'email': email, 'scene': scene},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '发送失败');
  }

  /// 注册
  Future<void> register({
    required String email,
    required String code,
    required String password,
    String nickname = '',
    String qq = '',
    String invite = '',
    String bindOpenid = '',
    String bindToken = '',
  }) async {
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/register',
        data: {
          'email': email,
          'code': code,
          if (invite.isNotEmpty) 'invite': invite,
          'password': password,
          'nickname': nickname,
          'qq': qq,
          if (bindOpenid.isNotEmpty && bindToken.isNotEmpty) ...{
            'bind_openid': bindOpenid,
            'bind_token': bindToken,
          },
        },
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '注册失败');
    final data = Map<String, dynamic>.from(r['data'] ?? {});
    await _save(
      (data['token'] ?? '').toString(),
      data['userinfo'] is Map ? UserInfo.fromJson(data['userinfo']) : null,
    );
  }

  /// 登录
  Future<void> login(String account, String password) async {
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/login',
        data: {'account': account, 'password': password},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '登录失败');
    final data = Map<String, dynamic>.from(r['data'] ?? {});
    await _save(
      (data['token'] ?? '').toString(),
      data['userinfo'] is Map ? UserInfo.fromJson(data['userinfo']) : null,
    );
  }

  /// 重置密码
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/reset',
        data: {'email': email, 'code': code, 'password': password},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '重置失败');
  }

  /// 刷新资料
  Future<UserInfo?> refreshProfile() async {
    if (_token.isEmpty) return null;
    try {
      final r = _unwrap(
        await _dio.post('/api/softlib/user/profile', data: {'token': _token}),
      );
      if (r['code'] == 1 && r['data'] is Map) {
        final info = UserInfo.fromJson(r['data']);
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_kUser, jsonEncode(info.toJson()));
        _user = info;
        return info;
      }
    } catch (_) {}
    return _user;
  }

  /// 更新资料（昵称/QQ/头像等）
  Future<UserInfo?> updateProfile(Map<String, dynamic> fields) async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/update',
        data: {...fields, 'token': _token},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '更新失败');
    if (r['data'] is Map) {
      final info = UserInfo.fromJson(r['data']);
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kUser, jsonEncode(info.toJson()));
      _user = info;
      return info;
    }
    return null;
  }

  /// 每日签到（+5 积分）
  Future<int> signIn() async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post('/api/softlib/user/sign', data: {'token': _token}),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '签到失败');
    final score = int.tryParse('${r['data']?['score']}') ?? 0;
    await refreshProfile();
    return score;
  }

  /// 赞助排行榜
  Future<List<Map<String, dynamic>>> donateRank() async {
    try {
      final r = await _dio.get('/api/softlib/user/donate_rank');
      if (r.data is Map && r.data['code'] == 1 && r.data['data'] is List) {
        return List<Map<String, dynamic>>.from(
          ((r.data['data'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (_) {}
    return [];
  }

  /// 使用卡密
  Future<String> redeem(String code) async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/redeem',
        data: {'token': _token, 'code': code},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '兑换失败');
    final msg = (r['msg'] ?? '兑换成功').toString();
    await refreshProfile();
    return msg;
  }

  // ============ ★ 1014：卡密商城 ============

  /// 卡密商城：商品列表 + 我的余额
  Future<Map<String, dynamic>> cardShop() async {
    final r = _unwrap(
      await _dio.post('/api/softlib/user/card_shop', data: {'token': _token}),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '获取卡密商城失败');
    final d = r['data'];
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// 卡密商城：用余额购买一张卡密
  Future<Map<String, dynamic>> buyCard(String key) async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/card_buy',
        data: {'token': _token, 'key': key},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '购买失败');
    final d = r['data'];
    await refreshProfile();
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// 卡密商城：我买过的卡密
  Future<List<Map<String, dynamic>>> myCards() async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post('/api/softlib/user/my_cards', data: {'token': _token}),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '获取我的卡密失败');
    final d = r['data'];
    if (d is List) {
      return d
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// 保存自定义开屏图
  Future<void> saveSplash(String url) async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/save_splash',
        data: {'token': _token, 'splash_image': url},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '保存失败');
    await refreshProfile();
  }

  /// 积分兑换商品列表（后台可配）
  Future<List<Map<String, dynamic>>> exchangeGoods() async {
    try {
      final r = await _dio.get('/api/softlib/user/exchange_goods');
      if (r.data is Map && r.data['code'] == 1 && r.data['data'] is List) {
        return List<Map<String, dynamic>>.from(
          ((r.data['data'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (_) {}
    return [];
  }

  /// 积分兑换
  Future<String> exchange(String goods) async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/exchange',
        data: {'token': _token, 'goods': goods},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '兑换失败');
    if (r['data'] is Map) {
      _user = UserInfo.fromJson(Map<String, dynamic>.from(r['data']));
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kUser, jsonEncode(_user!.toJson()));
    }
    return (r['msg'] ?? '兑换成功').toString();
  }

  /// 修改自定义称号
  Future<void> setTitle(String title) async {
    if (_token.isEmpty) throw Exception('请先登录');
    final r = _unwrap(
      await _dio.post(
        '/api/softlib/user/set_title',
        data: {'token': _token, 'title': title},
      ),
    );
    if (r['code'] != 1) throw Exception(r['msg'] ?? '修改失败');
    if (r['data'] is Map) {
      _user = UserInfo.fromJson(Map<String, dynamic>.from(r['data']));
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kUser, jsonEncode(_user!.toJson()));
    }
  }

  /// 查询 QQ 头像（注册前预览用）
  Future<String?> fetchQqAvatar(String qq) async {
    try {
      final resp = await _dio.get(
        '/api/softlib/user/qqavatar',
        queryParameters: {'qq': qq},
      );
      final r = _unwrap(resp);
      if (r['code'] == 1 && r['data'] is Map) {
        return (r['data']['avatar'] ?? '').toString();
      }
    } catch (_) {}
    return null;
  }
}
