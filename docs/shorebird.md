# Shorebird 接入指南（Flutter 代码热更新）

> 目标：改 Dart 代码后**不用重新发版**，用户重启 App 即生效。
> 现状：只做「接入准备」，未执行 `shorebird init`（需要你的账号生成 app_id），
> 也**没有推送、没有构建**。

## 一、它是怎么工作的

- 打包用 Shorebird 自己的 Flutter 分支（编译成「加了 OTA 壳」的 APK/IPA）
- 之后每次只上传**变更的 Dart 代码补丁**（几百 KB），不进应用商店
- 原生代码 / 插件 / 资源变更仍然需要正常发版

## 二、开通步骤（在你的 Mac 上做，不在服务器）

```bash
# 1) 装 CLI（macOS）
curl --proto '=https' --tlsv1.2 -sSfL https://shorebird.dev/install.sh | bash

# 2) 登录（浏览器 GitHub 授权）
shorebird login

# 3) 在项目根目录初始化：会生成 shorebird.yaml（含 app_id）
cd ~/flutter_softlib
shorebird init

# 4) 首次发版（产出一个真正带 OTA 能力的 APK）
shorebird release android -- --build-number=152 --build-name=3.11.6

# 5) 之后改 Dart 代码 → 只发补丁
shorebird patch android -- --build-number=152
```

`shorebird.yaml` 长这样（由 init 生成，**需要提交到仓库**）：

```yaml
app_id: 6a3f…（你的项目 id）
```

## 三、iOS 注意

- 支持 iOS，但补丁必须与已上架版本的签名/内置版本严格对应
- 你的 IPA 目前是未签名自签安装 → 先用同一套证书走 `shorebird release ios`，
  否则补丁校验会失败
- iOS 的补丁能力受 Apple 政策约束，**商业分发前先小范围验证**

## 四、和现有流程的关系

| 场景 | 现在 | 接 Shorebird 后 |
|---|---|---|
| 改 UI 文案/颜色/逻辑（Dart） | 改版本号 → CI 出包 → 传蓝奏 → 切版本表 | `shorebird patch` 一条命令，用户重启生效 |
| 换插件 / 加权限 / 改原生 | 同上（必须发版） | 不变 |
| 紧急回滚 | 重新发旧包 + 强更 | 控制台一键回滚到上上个补丁 |

现有 GitHub Actions（`build.yml`）保留：**原生变更或大版本**仍走它出正式包；
日常小改走 patch。

## 五、费用与限制（先了解再决定）

- 开发/测试阶段免费额度就够用
- 生产按补丁数量计费，具体以 <https://shorebird.dev/pricing> 为准
- 补丁大小与改动的 Dart 文件数相关，一般几十到几百 KB
- 强更/强制补丁：`shorebird patch android --allow-native-diffs`（慎用）

## 六、落地检查清单

- [ ] Mac 上 `shorebird login` 成功
- [ ] 仓库根目录出现 `shorebird.yaml`（提交）
- [ ] `shorebird release android` 出的 APK 能正常安装启动
- [ ] 改一行文案 → `shorebird patch android` → 冷启动看到变化
- [ ] 验证回滚：控制台选择上一个补丁回滚，冷启动恢复
