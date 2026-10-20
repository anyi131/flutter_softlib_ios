import 'package:flutter_softlib/app/pages/app_details/app_details_binding.dart';
import 'package:flutter_softlib/app/pages/app_details/app_details_page.dart';
import 'package:flutter_softlib/app/pages/app_download/app_download_binding.dart';
import 'package:flutter_softlib/app/pages/app_download/app_download_page.dart';
import 'package:flutter_softlib/app/pages/app_search/app_search_binding.dart';
import 'package:flutter_softlib/app/pages/app_search/app_search_page.dart';
import 'package:flutter_softlib/app/pages/article_reading/article_reading_binding.dart';
import 'package:flutter_softlib/app/pages/article_reading/article_reading_page.dart';
import 'package:flutter_softlib/app/pages/login/login_page.dart';
import 'package:flutter_softlib/app/pages/admin/admin_page.dart';
import 'package:flutter_softlib/app/pages/post_detail/post_detail_page.dart';
import 'package:flutter_softlib/app/pages/splash/splash_page.dart';
import 'package:flutter_softlib/app/pages/login/register_page.dart';
import 'package:flutter_softlib/app/pages/login/reset_page.dart';
import 'package:flutter_softlib/app/pages/vip_center/pay_web_page.dart';
import 'package:flutter_softlib/app/pages/app_details/url_webview_page.dart';
import 'package:flutter_softlib/app/pages/vip_center/vip_page.dart';
import 'package:flutter_softlib/app/pages/wallet/recharge_page.dart';
import 'package:flutter_softlib/app/pages/wallet/card_shop_page.dart';
import 'package:flutter_softlib/app/pages/appinfo/about_page.dart';
import 'package:flutter_softlib/app/pages/appinfo/agreement_page.dart';
import 'package:flutter_softlib/app/pages/navigate/mine/invite_page.dart';
import 'package:flutter_softlib/app/pages/message/message_page.dart';
import 'package:flutter_softlib/app/pages/taskcenter/task_page.dart';
import 'package:flutter_softlib/app/pages/wishlist/wish_page.dart';
import 'package:flutter_softlib/app/pages/guide/onboard_page.dart';
import 'package:flutter_softlib/app/pages/myfav/favorites_page.dart';
import 'package:flutter_softlib/app/pages/myfav/history_page.dart';
import 'package:get/get.dart';

import '../pages/navigate/navigate_binding.dart';
import '../pages/navigate/navigate_page.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const index = Routes.index;

  static final routes = [
    GetPage(name: _Paths.message, page: () => const MessagePage()),
    GetPage(name: _Paths.about, page: () => const AboutPage()),
    GetPage(name: _Paths.invite, page: () => const InvitePage()),
    GetPage(name: _Paths.agreement, page: () => const AgreementPage()),
    GetPage(name: _Paths.recharge, page: () => const RechargePage()),
    GetPage(name: _Paths.task, page: () => const TaskPage()),
    // ★ 1020：统一收藏夹（软件 + 工具）
    GetPage(name: _Paths.favorites, page: () => const FavoritesPage()),
    // ★ 1020：使用历史（可删除 / 批量清理）
    GetPage(name: _Paths.history, page: () => const HistoryPage()),
    // ★ 1020：首次启动引导（只显示一次）
    GetPage(
      name: _Paths.onboard,
      page: () => const OnboardPage(nextRoute: _Paths.index),
    ),
    // ★ 1020：求软件 / 需求投票
    GetPage(
      name: _Paths.wish,
      page: () {
        // 从搜索无结果跳进来时带上关键词
        final arg = Get.arguments;
        String kw = '';
        if (arg is Map) kw = '${arg['keyword'] ?? ''}';
        return WishPage(initialKeyword: kw);
      },
    ),
    GetPage(name: _Paths.splash, page: () => const SplashPage()),
    GetPage(
      name: _Paths.index,
      page: () => const NavigatePage(),
      binding: NavigateBinding(),
    ),
    GetPage(
      name: _Paths.appDownload,
      page: () => const AppDownloadPage(),
      binding: AppDownloadBinding(),
    ),
    GetPage(
      name: _Paths.appSearch,
      page: () => const AppSearchPage(),
      binding: AppSearchBinding(),
    ),
    GetPage(
      name: _Paths.appDetails,
      page: () => const AppDetailsPage(),
      binding: AppDetailsBinding(),
    ),
    GetPage(
      name: _Paths.articleReading,
      page: () => const ArticleReadingPage(),
      binding: ArticleReadingBinding(),
    ),
    GetPage(name: _Paths.vip, page: () => const VipPage()),
    GetPage(name: _Paths.payWeb, page: () => const PayWebPage()),
    GetPage(name: Routes.urlWebview, page: () => const UrlWebviewPage()),
    GetPage(name: Routes.cardShop, page: () => const CardShopPage()),
    GetPage(name: _Paths.postDetail, page: () => const PostDetailPage()),
    GetPage(name: _Paths.admin, page: () => const AdminPage()),
    GetPage(name: _Paths.login, page: () => const LoginPage()),
    GetPage(name: _Paths.register, page: () => const RegisterPage()),
    GetPage(name: _Paths.reset, page: () => const ResetPage()),
  ];
}
