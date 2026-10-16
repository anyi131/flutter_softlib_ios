package com.soft.anyi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
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

        // ★ 1015：注册 QQ 登录原生桥接（自己实现，不依赖第三方插件）
        try {
            QQLoginBridge.register(this, flutterEngine.dartExecutor.binaryMessenger)
        } catch (e: Throwable) {
            android.util.Log.w("QQLoginBridge", "注册失败: ${e.message}")
        }

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
                            val pi = packageManager.getPackageInfo(
                                packageName, android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES
                            )
                            val sig = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                pi.signingInfo!!.apkContentsSigners!![0]
                            } else {
                                @Suppress("DEPRECATION")
                                pi.signatures!![0]
                            }
                            val bytes: ByteArray = sig.toByteArray()
                            val md = MessageDigest.getInstance("MD5").digest(bytes)
                            result.success(md.joinToString("") { "%02x".format(it) })
                        } catch (e: Exception) {
                            result.error("SIGN_FAIL", e.message, null)
                        }
                    }
                    // ★ 1016：通知栏（动态/回复/点赞提醒）
                    "initNotify" -> {
                        ensureNotifyChannel()
                        result.success(true)
                    }
                    "showNotify" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title").orEmpty()
                        val body = call.argument<String>("body").orEmpty()
                        try {
                            showNotify(id, title, body)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("NOTIFY_FAIL", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ═══════════════ 通知栏（1016 新增）═══════════════
    private val chId = "softlib_dynamic"

    /** 创建通知渠道（Android 8+ 必须） */
    private fun ensureNotifyChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(chId) == null) {
                val ch = NotificationChannel(
                    chId, "动态与消息", NotificationManager.IMPORTANCE_DEFAULT
                )
                ch.description = "收到回复、点赞、评论、订单等提醒时通知"
                ch.enableLights(true)
                nm.createNotificationChannel(ch)
            }
        }
    }

    /** 弹一条通知；点它回到 App */
    private fun showNotify(id: Int, title: String, body: String) {
        ensureNotifyChannel()
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open", "message")
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pi = PendingIntent.getActivity(this, id, intent, flags)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, chId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val icon = applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_dialog_info
        val n = builder
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(icon)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .build()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(id, n)
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

    // ★ 1015：把 QQ 授权结果转发给桥接（新版 Flutter 已无 PluginRegistry API）
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        try {
            QQLoginBridge.handleActivityResult(requestCode, resultCode, data)
        } catch (e: Throwable) {
            android.util.Log.w("QQLoginBridge", "onActivityResult: ${e.message}")
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
