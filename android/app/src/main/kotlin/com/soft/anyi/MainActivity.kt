package com.soft.anyi

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/**
 * 主 Activity —— 提供原生「安装 APK」通道
 *
 * Flutter 侧调用 openFilex 走的是通用「查看文件」意图，系统会弹出
 * 「打开方式」选择器（MT管理器/阅读器等）。这里直接用 Android 的
 * PackageInstaller 意图，只有真正的安装器能响应，体验符合预期。
 */
class MainActivity : FlutterActivity() {

    private val channelName = "softlib/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("INVALID_PATH", "文件路径为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                    "canRequestPackageInstalls" -> {
                        val ok = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else true
                        result.success(ok)
                    }
                    "openInstallPermissionSettings" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val i = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                                i.data = Uri.parse("package:$packageName")
                                startActivity(i)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            // 兜底：打开应用详情页
                            try {
                                val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                i.data = Uri.parse("package:$packageName")
                                startActivity(i)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("NO_SETTINGS", e2.message, null)
                            }
                        }
                    }
                    "getSignature" -> {
                        // 安全防护：读取自身 APK 签名证书的 MD5（供远程比对防重打包）
                        try {
                            val bytes: ByteArray =
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                    val si = packageManager.getPackageInfo(
                                        packageName, android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES
                                    ).signingInfo
                                    si!!.apkContentsSigners[0].toByteArray()
                                } else {
                                    @Suppress("DEPRECATION")
                                    packageManager.getPackageInfo(
                                        packageName, android.content.pm.PackageManager.GET_SIGNATURES
                                    ).signatures[0].toByteArray()
                                }
                            val md = MessageDigest.getInstance("MD5").digest(bytes)
                            result.success(md.joinToString("") { "%02x".format(it) })
                        } catch (e: Exception) {
                            result.error("SIGN_FAIL", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 用系统安装器打开 APK */
    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) throw Exception("安装包不存在: $path")

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.flutter_downloader.provider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
