import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_softlib/app/http/http_api.dart';
import 'package:flutter_softlib/app/utils/jump_util.dart';
import 'package:flutter_softlib/app/utils/toast_util.dart';
import 'package:get/get.dart';

import '../../../../generated/assets.dart';
import '../../../config.dart';
import '../../../api/soft_service.dart';
import '../../../models/app_item.dart';
import '../../../models/app_config.dart';
import '../../../models/http/results/carousel_model.dart';
import '../../../models/http/results/referral_model.dart';
import '../../../routes/app_pages.dart';

class HomeLogic extends GetxController {
  HttpApi httpApi = Get.find<HttpApi>();
  List<CarouselData>? carouses;
  List<ReferralData>? referrals;

  /// ★ 1020：推荐位为空时的兜底列表（软件列表）
  ///
  /// ★★ 必须和 referrals 分开！上一版把软件直接塞进 referrals，
  ///    结果首页头图 `_magazineHero` 拿 referrals.first.image 当全屏封面，
  ///    变成一个 App 图标被拉满整屏 —— 就是用户截图里的「顶栏错位」。
  List<ReferralData>? fallbackRefs;
  AppConfig? configData;
  String? word;

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
    getConfig();
    getWord();
    getCarouselSlider();
    getReferral();
  }

  ///获取配置
  Future<void> getConfig() async {
    try {
      // v52g：改走 SoftService（AppConfig 带 uiConfig，快捷入口热配置要用）
      // ★ 1015 优化：不再 force —— 启动时 main.dart 已强制拉过一次，
      //   这里强制再拉就是重复请求，白白让首屏多等一个往返。
      var config = await SoftService.instance.fetchConfig();
      if (config != null) {
        configData = config;
      }
      update(['placard']);
    } catch (e) {
      logger.e(e.toString());
    }
  }

  ///获取轮播图
  Future<void> getCarouselSlider() async {
    try {
      CarouselModel carouselModel = await httpApi.getCarousel();
      if (carouselModel.code == 1) {
        carouses = carouselModel.data ?? [];
      }
      update(['carousel']);
    } catch (e) {
      logger.e(e.toString());
    }
  }

  ///获取推荐
  ///
  /// ★ 1020 修复「首页最新推荐一片空白」：
  ///   原来只读运营推荐位（fa_softlib_referral），该表为空时首页整块空白 ——
  ///   但用户想看的是**软件列表**，不是运营推荐位。
  ///   现在：推荐位为空 → 自动回退到软件列表（按下载量排序）。
  Future<void> getReferral() async {
    try {
      var referral = await httpApi.getReferral();
      if (referral.code == 1) {
        referrals = referral.data;
      }
      // ★ 推荐位没数据 → 用软件列表兜底（写进 fallbackRefs，不动 referrals）
      if (referrals == null || referrals!.isEmpty) {
        final apps = await SoftService.instance.fetchApps();
        if (apps.isNotEmpty) {
          final sorted = List<AppItem>.from(apps)
            ..sort((a, b) => b.downCount.compareTo(a.downCount));
          fallbackRefs = sorted
              .take(20)
              .map(
                (a) => ReferralData(
                  type: 'app',
                  image: a.icon,
                  title: a.title,
                  content: [
                    if (a.size.isNotEmpty) a.size,
                    if (a.version.isNotEmpty) 'v${a.version}',
                    if (a.downCount > 0) '${a.downCount} 次下载',
                  ].join(' · '),
                  url: a.id.toString(),
                ),
              )
              .toList();
        }
      }
      update(['referral']);
    } catch (e) {
      logger.e(e.toString());
    }
  }

  ///获取每日一句
  Future<void> getWord() async {
    try {
      var referral = await httpApi.getWord();
      if (referral.code == 1) {
        word = referral.data;
      }
      update(['word']);
    } catch (e) {
      logger.e(e.toString());
    }
  }

  ///跳转加群（★ v331z2：解析 qun.qq.com 分享链接里的群号 → mqqapi scheme
  /// 直达 QQ 加群界面；解析失败退网页打开。原来只会把链接当图片展示）
  ///
  /// ★ 1020：后台填的常是 qm.qq.com/q/xxx 短链，本地解析不出群号，
  ///   于是直接丢给浏览器 → 用户看到网页而不是 QQ（反馈 #3）。
  ///   现在短链先问服务端要群号，拿到就直达 QQ。
  Future<void> joinGroup() async {
    // ★ v331z3：优先实时缓存配置（configData 可能因加载时序为 null → 误报「暂未配置」）
    final cached = SoftService.instance.cachedConfig;
    final groupUrl = configData?.feedbackGroup ?? (cached?.feedbackGroup ?? '');
    if (groupUrl.isEmpty) {
      ToastUtil.error('暂未配置');
      return;
    }
    // 1) 已经是 mqqapi/tencent 协议 → 直接跳
    if (groupUrl.startsWith('mqqapi://') || groupUrl.startsWith('tencent://')) {
      JumpUtil.openUrl(groupUrl);
      return;
    }
    // 2) 从 qun.qq.com/universal-share 分享链接里挖 groupCode
    var code = _extractGroupCode(groupUrl);
    // 3) 本地挖不到 → 问服务端（qm.qq.com 短链只有服务端抓页面才拿得到群号）
    code ??= await SoftService.instance.resolveQqGroup(groupUrl);
    if (code != null && code.isNotEmpty) {
      JumpUtil.openUrl(
        'mqqapi://card/show_pslcard?src_type=internal&version=1'
        '&uin=$code&card_type=group&source=qrcode',
      );
      return;
    }
    // 4) 其他链接 → 网页打开
    JumpUtil.openUrl(groupUrl);
  }

  /// 从 QQ 群分享链接（含 busi_data base64 JSON）提取群号
  String? _extractGroupCode(String url) {
    // 显式 gc=/groupCode= 参数
    final m = RegExp(r'[?&](?:gc|groupCode)=([0-9]{5,15})').firstMatch(url);
    if (m != null) return m.group(1);
    // busi_data base64 里的 groupCode
    final b = RegExp(r'busi_data=([A-Za-z0-9%+/=]+)').firstMatch(url);
    if (b != null) {
      try {
        final decoded = utf8.decode(
          base64Decode(Uri.decodeComponent(b.group(1)!).replaceAll(' ', '+')),
        );
        final j = jsonDecode(decoded);
        final g = '${j['groupCode'] ?? ''}';
        if (g.isNotEmpty) return g;
      } catch (_) {}
    }
    return null;
  }

  ///跳转加客服（★ v331z3：实时缓存兜底 + 直接打开链接，原来只会把链接当图片展示）
  void joinUser() {
    final cached = SoftService.instance.cachedConfig;
    final userUrl = configData?.feedbackUser ?? (cached?.feedbackUser ?? '');
    if (userUrl.isEmpty) {
      ToastUtil.error('暂未配置');
      return;
    }
    JumpUtil.openUrl(userUrl);
  }

  ///弹窗显示图片
  void showImage(String? imageUrl) {
    // ★ 1016：Get.context 可能为 null（页面已退出/启动期），直接 ! 会崩
    final ctx = Get.context;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(3),
          content: SizedBox(
            width: Get.width * 0.5,
            height: Get.height * 0.3,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: Get.width * 0.5,
                    height: Get.height * 0.3,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      fit: BoxFit.contain,
                      placeholder: (context, url) {
                        return Center(child: Image.asset(Assets.imagesSucceed));
                      },
                      errorWidget: (context, url, error) {
                        return Center(
                          child: Text(
                            '加载失败',
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ///轮播图点击
  void onCarouselTap(CarouselData data) {
    if (data.type != 'url') return;
    if (data.url != null && data.url!.isNotEmpty) {
      JumpUtil.openUrl(data.url!);
    } else {
      ToastUtil.error('无效的链接');
    }
  }

  ///推荐点击
  void onReferralTap(ReferralData data) {
    // ★ 1020：兜底列表里的「软件」类型 → 跳详情页
    if (data.type == 'app') {
      final id = int.tryParse(data.url ?? '') ?? 0;
      if (id > 0) {
        Get.toNamed(Routes.appDetails, arguments: {'appId': '$id'});
      }
      return;
    }
    if (data.type == 'url') {
      if (data.url != null && data.url!.isNotEmpty) {
        JumpUtil.openUrl(data.url!);
      } else {
        ToastUtil.error('无效的链接');
      }
    }
    if (data.type == 'page') {
      Get.toNamed(
        Routes.articleReading,
        arguments: {'title': data.title, 'content': data.content},
      );
    }
  }
}
