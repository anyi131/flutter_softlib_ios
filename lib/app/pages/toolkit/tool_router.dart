import 'package:get/get.dart';

import 'tool_pages_local.dart';
import 'tool_pages_local2.dart';
import 'tool_pages_local3.dart';
import 'tool_pages_image.dart';
import 'tool_pages_image2.dart';
import 'tool_pages_local4.dart';
import 'tool_pages_text.dart';
import 'tool_pages_life.dart';
import 'tool_pages_eng.dart';
import 'tool_pages_gen.dart';
import 'tool_pages_fin.dart';
import 'tool_pages_misc.dart';
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

    // ── ★ 1015 扩展：单位换算全集 ──
    case 'length':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const LengthPage());
    case 'weight':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const WeightPage());
    case 'area':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const AreaPage());
    case 'volume':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const VolumePage());
    case 'speed':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const SpeedPage());
    case 'datasize':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const DataPage());
    case 'timeunit':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TimeUnitPage());
    case 'temperature':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TempPage());

    // ── ★ 1015 扩展：常用计算 ──
    case 'tax':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TaxPage());
    case 'mortgage':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const MortgagePage());
    case 'interest':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const InterestPage());
    case 'age':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const AgePage());

    // ── ★ 1015 扩展：文本处理 ──
    case 'textstat':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TextStatPage());
    case 'json':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const JsonPage());
    case 'urlcode':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const UrlPage());
    case 'hash':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const HashPage());
    case 'regex':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const RegexPage());
    case 'randstr':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const RandStrPage());
    case 'randnum':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const RandNumPage());
    case 'palette':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PalettePage());
    case 'lorem':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const LoremPage());
    case 'ascii':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const AsciiPage());

    // ── ★ 1015 扩展：生活健康 ──
    case 'bodyfat':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const BodyFatPage());
    case 'water':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const WaterPage());
    case 'pregnancy':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PregnancyPage());
    case 'period':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PeriodPage());
    case 'bookkeep':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const BookkeepPage());
    case 'bankcard':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const BankCardPage());
    case 'phonearea':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PhoneAreaPage());
    case 'pwdcheck':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PwdCheckPage());

    // ── ★ 1015 扩展：工程估算与更多换算 ──
    case 'decor':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const DecorPage());
    case 'elecbill':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ElecPage());
    case 'pressure':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PressurePage());
    case 'power':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PowerPage());
    case 'energy':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const EnergyPage());
    case 'angle':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const AnglePage());
    case 'frequency':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const FreqPage());
    case 'light':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const LightPage());
    case 'workday':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const WorkdayPage());
    case 'numcn':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const NumCnPage());

    // ── ★ 1015 扩展：生成器与娱乐 ──
    case 'timer':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TimerPage());
    case 'dice':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const DicePage());
    case 'decide':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const DecidePage());
    case 'clock':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ClockPage());
    case 'group':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const GroupPage());
    case 'laptimer':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const LapTimerPage());
    case 'ruler':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const RulerPage());

    // ── ★ 1015 扩展：金融与工程估算 ──
    case 'carloan':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const CarLoanPage());
    case 'bonustax':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const BonusTaxPage());
    case 'social':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const SocialPage());
    case 'salary':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const SalaryPage());
    case 'tile':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TilePage());
    case 'paint':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PaintPage());
    case 'fuelconv':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const FuelConvPage());
    case 'mstime':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const MsTimePage());
    case 'bignum':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const BigNumPage());
    case 'tip':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const TipPage());

    // ── ★ 1015 扩展：健康与生活参考 ──
    case 'shoesize':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ShoeSizePage());
    case 'clothsize':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ClothSizePage());
    case 'bloodpressure':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const BpPage());
    case 'vision':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const VisionPage());
    case 'zodiac':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ZodiacPage());
    case 'springfest':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const SpringFestivalPage());
    case 'expressco':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const ExpressCoPage());
    case 'slangunit':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const SlangUnitPage());
    case 'numslang':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const NumSlangPage());
    case 'pomodoro':
      return ({required String title, String apiUrl = ''}) =>
          Get.to(() => const PomodoroPage());
  }
  return null;
}
