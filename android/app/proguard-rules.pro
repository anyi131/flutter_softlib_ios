# ===== Flutter 官方推荐 keep 规则（防 R8 裁剪导致启动卡死/崩溃）=====
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# 插件注册与原生 MethodChannel（getSignature 等）
-keep class com.soft.anyi.MainActivity { *; }
-keep class **.GeneratedPluginRegistrant { *; }
# 常见插件反射需求
-keep class vn.hunghd.flutterdownloader.** { *; }
-keep class com.jakewharton.** { *; }
-keep class com.google.android.** { *; }
-dontwarn com.google.android.**
# 保留注解与泛型签名
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod

# ═══════════════════════════════════════════════════════════════
# ★ 1015：QQ SDK（open_sdk）R8/ProGuard 规则
#
# 为什么需要：
#   QQ SDK 内部引用 okhttp3（部分类没打包进来），
#   R8 的 "Missing classes" 检查会让构建直接失败：
#     ERROR: R8: Missing class okhttp3.Cache (referenced from ...)
#   这里用 -dontwarn 忽略这些缺失类（运行时不走那部分代码），
#   同时保留 SDK 的反射入口（否则授权回调会失效）。
# ═══════════════════════════════════════════════════════════════

# ① 忽略 QQ SDK 引用的可选依赖（未打包不影响运行）
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.tencent.**
-dontwarn org.apache.http.**

# ② 保留腾讯 SDK 全部类（授权/登录靠反射 + 回调类名）
-keep class com.tencent.** { *; }
-keep interface com.tencent.** { *; }
-keep class com.tencent.open.** { *; }
-keep class com.tencent.tauth.** { *; }
-keep class com.tencent.connect.** { *; }

# ③ 保留我们自己的桥接（MethodChannel 反射调用）
-keep class com.soft.anyi.QQLoginBridge { *; }
-keepclassmembers class com.soft.anyi.QQLoginBridge {
    public static <methods>;
    private static <fields>;
}

# ④ 保留 IUiListener 实现（QQ 回调靠类名）
-keep class * implements com.tencent.tauth.IUiListener { *; }
-keepclassmembers class * implements com.tencent.tauth.IUiListener { *; }

# ⑤ 保留 JSON 相关（QQ 返回 JSON 解析）
-keep class org.json.** { *; }
-dontwarn org.json.**
