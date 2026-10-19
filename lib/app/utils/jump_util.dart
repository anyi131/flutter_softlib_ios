import 'package:flutter_softlib/app/utils/toast_util.dart';
import 'package:url_launcher/url_launcher_string.dart';

class JumpUtil {
  /// ★ 1014 安全：判断 URL 是否为「软件安装包直链 / 网盘直链」。
  /// 这类链接若交给外部浏览器打开，就等于绕过了 App 与服务端的所有鉴权
  ///（后台把轮播/公告/更新地址误配成直链时，用户一点就下载）。
  static bool isDownloadLink(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return false;
    // ★ 1014：只拦「真正的安装包直链」，避免误伤正常页面。
    //   教训：最初白名单含 'lanzou'/'down.' 等宽泛词，
    //   把「App 更新包地址」「蓝奏云分享页」也拦了 →
    //   用户点「立即更新」被弹「该链接为下载地址」。

    // 1) 以安装包/压缩包结尾（含 query/fragment 的情况）
    if (RegExp(r'\.(apk|ipa|xapk|apks|zip|rar|7z)(\?|#|$)').hasMatch(u)) {
      return true;
    }
    // 2) 蓝奏云解析后的直链 CDN（形如 h1060.lanosso.com/<hash>/...）
    //    注意：分享页是 lanzou*.com（不带 so），不应拦截。
    if (u.contains('lanosso.com') ||
        u.contains('lanzn.com') ||
        u.contains('lanzn.net')) {
      return true;
    }
    return false;
  }

  /// 浏览器打开网址
  ///
  /// ★ 1014 安全：默认拒绝「安装包/网盘直链」，避免绕过 App 内鉴权。
  /// 需要打开直链的场景（如解析失败兜底）必须显式传 allowDownload: true，
  /// 且调用方须已完成服务端校验。
  static void openUrl(String url, {bool allowDownload = false}) {
    if (url.isEmpty) {
      ToastUtil.error('网址不能为空');
      return;
    }
    if (Uri.tryParse(url)?.hasScheme != true) {
      ToastUtil.error('无效的网址: $url');
      return;
    }
    if (!allowDownload && isDownloadLink(url)) {
      ToastUtil.error('该链接为下载地址，请从软件详情页下载（需登录校验）');
      return;
    }
    launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  /// 添加QQ群
  ///
  /// ★ 1020：canLaunchUrlString 对 mqqapi:// 常返回 false（Android 11+ 的
  ///   package visibility 限制），之前会直接弹「无法打开QQ群」而不是跳转。
  ///   现在「直接尝试唤起」为准，失败再退回浏览器加群页（用户反馈 #3）。
  static Future<bool> joinQQGroup(String groupCode) async {
    if (groupCode.isEmpty) return false;
    final qunUrl =
        "mqqapi://card/show_pslcard?src_type=internal&version=1"
        "&uin=$groupCode&card_type=group&source=qrcode";
    try {
      final ok = await launchUrlString(
        qunUrl,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return true;
    } catch (_) {}
    // 兜底：QQ 群网页版（浏览器里能继续唤起 QQ 或提示安装）
    try {
      await launchUrlString(
        'https://qm.qq.com/cgi-bin/qm/qr?k=&group_code=$groupCode',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    return false;
  }

  /// 添加QQ好友
  static Future<void> addQQFriend(String qqNumber) async {
    String qqUrl =
        "mqqapi://card/show_pslcard?src_type=internal&source=sharecard&version=1&uin=$qqNumber";
    if (await canLaunchUrlString(qqUrl)) {
      await launchUrlString(
        qqUrl,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } else {
      ToastUtil.error('无法打开QQ: $qqNumber');
    }
  }
}
