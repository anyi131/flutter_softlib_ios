/// ★ 1105n 统一图标集（Lucide）
///
/// 选它的原因：24px 网格、1.75~2px 圆头描边，整套 1500+ 图标风格完全一致，
/// 而此前项目里 Material 圆角图标（*_rounded）和自定义图标混用，视觉不统一。
///
/// 用法：`import '../../design/lucide.dart';` 然后 `Lz.xxx`，
/// 需要调大小时给 Icon(size: ...) 覆盖即可（默认 24）。
import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

class Lz {
  Lz._();

  // 会员 / 权益
  static const IconData vip = LucideIcons.crown;
  static const IconData badge = LucideIcons.badgeCheck;
  static const IconData benefitDownload = LucideIcons.download;
  static const IconData benefitSpeed = LucideIcons.zap;
  static const IconData benefitSupport = LucideIcons.headphones;
  static const IconData check = LucideIcons.checkCircle;

  // 通用
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData gift = LucideIcons.gift;

  // 支付
  static const IconData payWallet = LucideIcons.wallet;
  static const IconData payWechat = LucideIcons.messageCircle;
  static const IconData payQq = LucideIcons.bird;

  static const IconData download = LucideIcons.download;
  static const IconData checkCircle = LucideIcons.checkCircle;
  static const IconData headphones = LucideIcons.headphones;
  static const IconData zap = LucideIcons.zap;
  static const IconData support = LucideIcons.headphones;

  // 导航 / 列表
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronUp = LucideIcons.chevronUp;
  static const IconData search = LucideIcons.search;
  static const IconData searchX = LucideIcons.searchX;
  static const IconData apps = LucideIcons.layoutGrid;
  static const IconData widgets = LucideIcons.layoutGrid;
  static const IconData store = LucideIcons.store;
  static const IconData cluster = LucideIcons.layoutGrid;
  static const IconData groupAdd = LucideIcons.userPlus;
  static const IconData inbox = LucideIcons.inbox;
  static const IconData alert = LucideIcons.alertCircle;
  static const IconData close = LucideIcons.x;
  static const IconData more = LucideIcons.moreHorizontal;

  // 内容 / 状态
  static const IconData trophy = LucideIcons.trophy;
  static const IconData sparkles = LucideIcons.sparkles;
  static const IconData megaphone = LucideIcons.megaphone;
  static const IconData downloadCloud = LucideIcons.downloadCloud;
  static const IconData hardDrive = LucideIcons.hardDrive;
  static const IconData imageOff = LucideIcons.imageOff;
  static const IconData clock = LucideIcons.clock;
  static const IconData languages = LucideIcons.languages;
  static const IconData eye = LucideIcons.eye;
  static const IconData pause = LucideIcons.pause;
  static const IconData play = LucideIcons.play;
  static const IconData circle = LucideIcons.circle;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData trash = LucideIcons.trash2;
  static const IconData share = LucideIcons.share;
  static const IconData hourglass = LucideIcons.hourglass;
  static const IconData compass = LucideIcons.compass;
  static const IconData cloud = LucideIcons.cloud;
  static const IconData lightbulb = LucideIcons.lightbulb;
  static const IconData tag = LucideIcons.tag;
  static const IconData star = LucideIcons.star;
  static const IconData starFill = LucideIcons.star; // 0.257 无 starFill
  static const IconData smile = LucideIcons.smile;

  // 账户 / 资产
  static const IconData money = LucideIcons.circleDollarSign;
  static const IconData price = LucideIcons.badgeDollarSign;
  static const IconData card = LucideIcons.creditCard;
  static const IconData moon = LucideIcons.moon;
  static const IconData hand = LucideIcons.hand;
  static const IconData shield = LucideIcons.shieldCheck;
  static const IconData user = LucideIcons.user;
  static const IconData userPlus = LucideIcons.userPlus;
  static const IconData logIn = LucideIcons.logIn;
  static const IconData link = LucideIcons.link;
  static const IconData smartphone = LucideIcons.smartphone;

  // ---- 全量铺开自动补齐 ----
  static const IconData alertCircle = LucideIcons.alertCircle;
  static const IconData alertTriangle = LucideIcons.alertTriangle;
  static const IconData alignLeft = LucideIcons.alignLeft;
  static const IconData arrowDown = LucideIcons.arrowDown;
  static const IconData arrowLeft = LucideIcons.arrowLeft;
  static const IconData arrowLeftRight = LucideIcons.arrowLeftRight;
  static const IconData arrowRight = LucideIcons.arrowRight;
  static const IconData arrowUp = LucideIcons.arrowUp;
  static const IconData arrowUpDown = LucideIcons.arrowUpDown;
  static const IconData arrowUpToLine = LucideIcons.arrowUpToLine;
  static const IconData atSign = LucideIcons.atSign;
  static const IconData badgeCheck = LucideIcons.badgeCheck;
  static const IconData badgeDollarSign = LucideIcons.badgeDollarSign;
  static const IconData ban = LucideIcons.ban;
  static const IconData bell = LucideIcons.bell;
  static const IconData bellRing = LucideIcons.bellRing;
  static const IconData bird = LucideIcons.bird;
  static const IconData bookOpen = LucideIcons.bookOpen;
  static const IconData briefcase = LucideIcons.briefcase;
  static const IconData cake = LucideIcons.cake;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData calendarRange = LucideIcons.calendarRange;
  static const IconData cat = LucideIcons.cat;
  static const IconData checkCheck = LucideIcons.checkCheck;
  static const IconData checkCircle2 = LucideIcons.checkCircle2;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData circleDollarSign = LucideIcons.circleDollarSign;
  static const IconData clapperboard = LucideIcons.clapperboard;
  static const IconData clipboardPaste = LucideIcons.clipboardPaste;
  static const IconData cloudOff = LucideIcons.cloudOff;
  static const IconData code = LucideIcons.code;
  static const IconData copy = LucideIcons.copy;
  static const IconData cpu = LucideIcons.cpu;
  static const IconData creditCard = LucideIcons.creditCard;
  static const IconData crop = LucideIcons.crop;
  static const IconData crown = LucideIcons.crown;
  static const IconData dice5 = LucideIcons.dice5;
  static const IconData dollarSign = LucideIcons.dollarSign;
  static const IconData externalLink = LucideIcons.externalLink;
  static const IconData eyeOff = LucideIcons.eyeOff;
  static const IconData fileText = LucideIcons.fileText;
  static const IconData fingerprint = LucideIcons.fingerprint;
  static const IconData flag = LucideIcons.flag;
  static const IconData flame = LucideIcons.flame;
  static const IconData flaskConical = LucideIcons.flaskConical;
  static const IconData folder = LucideIcons.folder;
  static const IconData gamepad2 = LucideIcons.gamepad2;
  static const IconData globe = LucideIcons.globe;
  static const IconData hammer = LucideIcons.hammer;
  static const IconData heart = LucideIcons.heart;
  static const IconData history = LucideIcons.history;
  static const IconData home = LucideIcons.home;
  static const IconData image = LucideIcons.image;
  static const IconData info = LucideIcons.info;
  static const IconData key = LucideIcons.key;
  static const IconData layoutDashboard = LucideIcons.layoutDashboard;
  static const IconData layoutGrid = LucideIcons.layoutGrid;
  static const IconData list = LucideIcons.list;
  static const IconData listChecks = LucideIcons.listChecks;
  static const IconData lock = LucideIcons.lock;
  static const IconData logOut = LucideIcons.logOut;
  static const IconData mail = LucideIcons.mail;
  static const IconData mapPin = LucideIcons.mapPin;
  static const IconData maximize = LucideIcons.maximize;
  static const IconData messageCircle = LucideIcons.messageCircle;
  static const IconData messageSquare = LucideIcons.messageSquare;
  static const IconData minimize = LucideIcons.minimize;
  static const IconData moreHorizontal = LucideIcons.moreHorizontal;
  static const IconData music = LucideIcons.music;
  static const IconData newspaper = LucideIcons.newspaper;
  static const IconData package = LucideIcons.package;
  static const IconData palette = LucideIcons.palette;
  static const IconData pencil = LucideIcons.pencil;
  static const IconData percent = LucideIcons.percent;
  static const IconData pin = LucideIcons.pin;
  static const IconData playCircle = LucideIcons.playCircle;
  static const IconData plus = LucideIcons.plus;
  static const IconData quote = LucideIcons.quote;
  static const IconData receipt = LucideIcons.receipt;
  static const IconData refreshCw = LucideIcons.refreshCw;
  static const IconData reply = LucideIcons.reply;
  static const IconData rocket = LucideIcons.rocket;
  static const IconData rotateCcw = LucideIcons.rotateCcw;
  static const IconData rotateCw = LucideIcons.rotateCw;
  static const IconData save = LucideIcons.save;
  static const IconData send = LucideIcons.send;
  static const IconData settings = LucideIcons.settings;
  static const IconData shapes = LucideIcons.shapes;
  static const IconData shieldCheck = LucideIcons.shieldCheck;
  static const IconData shoppingBag = LucideIcons.shoppingBag;
  static const IconData shuffle = LucideIcons.shuffle;
  static const IconData skipBack = LucideIcons.skipBack;
  static const IconData skipForward = LucideIcons.skipForward;
  static const IconData slidersHorizontal = LucideIcons.slidersHorizontal;
  static const IconData square = LucideIcons.square;
  static const IconData starHalf = LucideIcons.starHalf;
  static const IconData sun = LucideIcons.sun;
  static const IconData terminal = LucideIcons.terminal;
  static const IconData thermometer = LucideIcons.thermometer;
  static const IconData thumbsUp = LucideIcons.thumbsUp;
  static const IconData ticket = LucideIcons.ticket;
  static const IconData timer = LucideIcons.timer;
  static const IconData trash2 = LucideIcons.trash2;
  static const IconData trendingUp = LucideIcons.trendingUp;
  static const IconData type = LucideIcons.type;
  static const IconData undo2 = LucideIcons.undo2;
  static const IconData unlink = LucideIcons.unlink;
  static const IconData unlock = LucideIcons.unlock;
  static const IconData upload = LucideIcons.upload;
  static const IconData users = LucideIcons.users;
  static const IconData volume2 = LucideIcons.volume2;
  static const IconData volumeX = LucideIcons.volumeX;
  static const IconData wallet = LucideIcons.wallet;
  static const IconData wand2 = LucideIcons.wand2;
  static const IconData wifiOff = LucideIcons.wifiOff;
  static const IconData x = LucideIcons.x;
  static const IconData xCircle = LucideIcons.xCircle;
}
