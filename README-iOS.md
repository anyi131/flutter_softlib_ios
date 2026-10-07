# 软件库 App · iOS 适配版

> 本仓库是 **软件库 App 的 iOS 独立适配分支**，源码来自安卓主仓库
> [`anyi131/flutter_softlib`](https://github.com/anyi131/flutter_softlib)。
>
> **两个仓库完全独立**：本仓库里的 iOS 改动**不会、也没有修改任何安卓端逻辑**，
> 安卓主仓库保持原样。后续安卓有更新时按下面的「同步上游」方式合并即可。

---

## 一、为什么要单独开一个仓库

| 项目 | 安卓主仓库 | 本仓库（iOS） |
| --- | --- | --- |
| 平台 | Android | **Android + iOS 双端** |
| 产物 | `app-release.apk` | `Runner.app` / 未签名 `.ipa` |
| 工作流 | `build.yml`（ubuntu） | `build-ios.yml`（macOS）+ `build.yml` |
| 改动风险 | 不受影响 | 只在本仓库 |

安卓端是主力发布渠道，iOS 适配涉及 Podfile / Info.plist / AppDelegate 等
平台专属文件，混在同一仓库容易互相影响，所以拆成独立仓库。

---

## 二、iOS 适配都改了什么

> 原则：**能用平台判断解决的，绝不动安卓代码**。
> 所有平台分支都写成 `if (PlatUtil.isAndroid) { 原有代码原样 } else { iOS 分支 }`，
> 安卓走的就是适配前那几行，逻辑一字未改。

### 1. 新增文件（纯新增，不影响任何现有功能）

| 文件 | 作用 |
| --- | --- |
| `lib/app/utils/platform_util.dart` | 跨平台能力封装：下载目录、公共存储、通知栏打开等差异集中在此 |
| `lib/app/utils/install_helper.dart` | **iOS 专用**：安装包无法安装时，降级为「存储/分享」或「用其他应用打开」 |
| `tool/gen_ios_icons.py` | 生成 iOS 全套应用图标（可修改配色后重跑） |

### 2. 平台分流点（安卓逻辑保持原样）

| 位置 | Android | iOS |
| --- | --- | --- |
| 下载保存目录 | `/storage/emulated/0/Download` | 沙盒 `Documents/Download`（「文件」App 可见） |
| `saveInPublicStorage` | `true` | `false`（iOS 无此概念，传 true 会下载失败） |
| `openFileFromNotification` | `true` | `false` |
| 下载完成后动作 | 系统安装器装 APK | 弹「存储/分享」「用其他应用打开」 |
| 相册权限 | `photos` + `videos` + `storage` | 仅 `Permission.photos`（iOS 无存储权限，`videos` 不受支持） |
| 下载器后台回调 | 不需要 | `FlutterDownloader.registerCallback` |

### 3. iOS 工程配置

- **`ios/Runner/Info.plist`**
  - `UIBackgroundModes = fetch, processing` —— flutter_downloader 后台下载必需，否则切后台就断
  - `NSAppTransportSecurity.NSAllowsArbitraryLoads = true` —— 部分直链（蓝奏云等）是 http
  - 权限用途说明：相册读取/写入、相机、麦克风（iOS 缺了会直接闪退）
  - `LSApplicationQueriesSchemes`：`mqqapi` / `mqq` / `weixin` / `alipay` 等，QQ 群与客服跳转需要
  - `ITSAppUsesNonExemptEncryption = false`：免去每次上传的出口合规问答
  - 竖屏锁定（与 App 内 `setPreferredOrientations` 一致）
  - 应用名：**软件库**；最低版本 **iOS 13.0**
- **`ios/Runner/AppDelegate.swift`**
  - `FlutterDownloaderPlugin.setPluginRegistrantCallback(...)` —— App 被系统在后台唤醒时能恢复下载
- **`ios/Podfile`**
  - `platform :ios, '13.0'`；`post_install` 只把**低于** 13.0 的插件抬到 13.0（不降级，避免破坏需要更高版本的插件）
  - `permission_handler` 只编译实际用到的 `PERMISSION_PHOTOS` / `PERMISSION_NOTIFICATIONS`，减小包体并避免审核质疑
- **应用图标**：全新蓝紫渐变 + 下载符号，15 个尺寸 + 1024 营销图，已放进 `AppIcon.appiconset`

---

## 三、构建

### 方式 A：GitHub Actions（推荐，无需 Mac）

推送到 `master` 即自动触发 [Build iOS](.github/workflows/build-ios.yml)，
在 **macOS 15 + Xcode** 上真实编译，产物：

- `softlib-ios-Runner-app` —— `Runner.app`（未签名）
- `softlib-ios-unsigned-ipa` —— 未签名 `.ipa`

打 tag 时还会自动附到 Release 上。

### 方式 B：本地 Mac

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release --no-codesign   # 只验证编译
flutter build ipa --release                 # 需要签名证书，产出可安装 ipa
```

---

## 四、装到自己手机上

iOS 不像安卓可以随便装 APK，必须签名。三种方式：

1. **Xcode 免费签名（最简单，7 天有效期）**
   - Mac 上打开 `ios/Runner.xcworkspace`
   - Runner → Signing & Capabilities → 勾选 Automatically manage signing，登录 Apple ID
   - 把 Bundle Identifier 改成你自己的（如 `com.你的名字.softlib`）
   - 连上 iPhone → Run
2. **自签工具**：下载 CI 产出的未签名 IPA，用 AltStore / Sideloadly / TrollStore 等自签安装
3. **付费开发者账号**：`flutter build ipa` 后走 App Store Connect 分发 / TestFlight（有效期 1 年）

> Bundle Identifier 目前是 `com.softlib.app`，正式发布前建议改成你自己的域名反写。

---

## 五、iOS 上的功能差异（系统限制，非 Bug）

| 功能 | iOS 表现 |
| --- | --- |
| **安装下载的软件** | ❌ iOS 不允许安装 APK。点「安装」会弹面板，可**存储到「文件」App**、**分享到其它 App/AirDrop**，或发送到安卓设备安装 |
| 下载管理/进度 | ✅ 正常（沙盒 `Documents/Download`，支持后台下载） |
| 软件浏览、搜索、详情 | ✅ 正常 |
| 广场发帖/评论/点赞/图片上传 | ✅ 正常 |
| 线报、我的、后台管理 | ✅ 正常 |
| 更新弹窗 | ✅ 可下载；下载完同样走「存储/分享」（无法自动安装） |
| 保存海报到相册 | ✅ 正常（已声明相册写入用途） |

---

## 六、同步上游安卓仓库的更新

```bash
git remote add upstream https://github.com/anyi131/flutter_softlib.git   # 首次
git fetch upstream
git merge upstream/master     # 或 git rebase upstream/master
```

因为所有 iOS 改动都收在「新增文件 + 平台判断分支」里，
正常情况不会和上游的安卓改动冲突；若冲突，**保留上游的安卓逻辑**即可。

---

## 七、下一步可做的事

- [ ] 把此仓库也接入「软件库」服务端，做 iOS 专属的更新包下发（现在是共用安卓 APK 的更新地址）
- [ ] 用 `flutter_launcher_icons` 统一安卓/iOS 图标（安卓目前还是 Flutter 默认图标）
- [ ] 上架 App Store 前：移除 `NSAllowsArbitraryLoads`（改用按域名放行）、补充隐私清单 `PrivacyInfo.xcprivacy`
