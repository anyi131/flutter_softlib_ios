# Flutter 接口保留（混淆其余应用代码）
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.Log { *; }
-dontwarn io.flutter.embedding.**
# MethodChannel 调用的原生方法防裁剪（getSignature 等）
-keepclassmembers class com.soft.anyi.MainActivity { public *; }
# Gson/JSON 模型（如有反射）
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
