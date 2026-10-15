import 'package:get/get.dart';

import 'tool_pages_local.dart';
import 'tool_pages_local2.dart';
import 'tool_pages_local3.dart';
import 'tool_pages_image.dart';
import 'tool_pages_image2.dart';
import 'tool_pages_net.dart';

/// 工具打开函数签名（标题 + 后台配置的接口地址）
typedef ToolOpen = void Function({required String title, String apiUrl});

/// 后台 `jzs_tool.kind` → 具体页面（v3.3.4）
///
/// 未命中返回 null，由调用方决定降级（跳外链 / 提示暂未开放），绝不静默失败。
ToolOpen? toolRoute(String kind, {String route = ''}) {
  switch (kind.isNotEmpty ? kind : route) {
    // ── 热榜 / 资讯 ──
    case 'hotsearch':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => HotPage(title: title, apiUrl: apiUrl));
    case 'news':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => Daily60Page(title: title));
    case 'epic':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => EpicPage(title: title));
    case 'earthquake':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const EarthquakePage());
    case 'poem':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PoemPage());
    case 'hitokoto':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const HitokotoPage());

    // ── 影视 / 音乐 / 短剧 ──
    case 'movie':
    case 'moviesearch':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => MoviePage(title: title));
    case 'music':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const MusicPage());
    case 'shortvideo':
    case 'drama':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const DramaPage());

    // ── 图集 ──
    case 'comic':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ComicPage());
    case 'heroes':
    case 'herogallery':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const HeroGalleryPage());
    case 'wallpaper':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => WallpaperPage(apiUrl: apiUrl));

    // ── 查询 ──
    case 'translate':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TranslatePage());
    case 'exchange':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ExchangePage());
    case 'ipquery':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const IpPage());
    case 'weather':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const WeatherPage());

    // ── 效率（纯本地） ──
    case 'qrcode':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const QrcodePage());
    case 'stopwatch':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const StopwatchPage());
    case 'countdown':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const CountdownPage());
    case 'unit':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const UnitPage());
    case 'bmi':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const BmiPage());
    case 'loan':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const LoanPage());
    case 'base64':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const Base64Page());

    // ── 娱乐（纯本地） ──
    case 'random':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const RandomPage());
    case 'password':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PasswordPage());
    case 'relative':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const RelativePage());

    // ── ★ 1015 扩展：计算 / 转换 / 生成（纯本地） ──
    case 'calc':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const CalcPage());
    case 'hexconv':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const HexConvPage());
    case 'timestamp':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TimestampPage());
    case 'caseconv':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const CaseConvPage());
    case 'uuid':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const UuidPage());
    case 'colorconv':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ColorConvPage());
    case 'percent':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PercentPage());
    case 'datecalc':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const DateCalcPage());

    // ── ★ 1015 扩展：生活实用（纯本地） ──
    case 'bmr':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const BmrPage());
    case 'sleep':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const SleepPage());
    case 'idcard':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const IdCardPage());
    case 'split':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const SplitPage());
    case 'money':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const MoneyPage());
    case 'daycount':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const DayCountPage());
    case 'roman':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const RomanPage());
    case 'sizeconv':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const SizePage());
    case 'fuel':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const FuelPage());
    case 'passphrase':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PassphrasePage());

    // ── ★ 1015 扩展：图片工具（本地处理） ──
    case 'imgcompress':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgCompressPage());
    case 'imgcrop':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgCropPage());
    case 'imgconv':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgConvPage());
    case 'imgcolor':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgColorPage());
    case 'imgwater':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgWaterPage());
    case 'imgrotate':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgRotatePage());
    case 'imground':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgRoundPage());
    case 'imgmosaic':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgMosaicPage());
    case 'imgadjust':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgAdjustPage());
    case 'imggray':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgGrayPage());
    case 'imgresize':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgResizePage());
    case 'imginfo':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ImgInfoPage());
  }
  return null;
}
