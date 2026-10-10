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
