package com.soft.anyi;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

import com.tencent.connect.common.Constants;
import com.tencent.connect.auth.QQToken;
import com.tencent.tauth.IUiListener;
import com.tencent.tauth.Tencent;
import com.tencent.tauth.UiError;

import org.json.JSONObject;

import java.lang.ref.WeakReference;

/**
 * ★ 1015：QQ 登录原生桥接（自己实现，不用第三方插件）
 *
 * 为什么自己写：
 *   tencent_kit 等第三方插件把 AGP 版本写死在 Gradle 里（7.3.0 + compileSdk 31），
 *   与本项目 AGP 8.9 / compileSdk 34 不兼容，反复构建失败。
 *   自己写桥接可完全掌控 Gradle 配置，只依赖腾讯官方 SDK jar。
 *
 * 用法（Dart 侧）：
 *   MethodChannel('com.soft.anyi/qq').invokeMethod('login', {'appId': 'xxx'})
 *   返回 {openid, access_token} 或 {error: '...'}
 */
public class QQLoginBridge implements MethodChannel.MethodCallHandler,
        PluginRegistry.ActivityResultListener {

    public static final String CHANNEL = "com.soft.anyi/qq";

    private static WeakReference<Activity> activityRef;
    private static MethodChannel.Result pendingResult;
    private static Tencent tencent;

    public static void register(Activity activity, io.flutter.plugin.common.BinaryMessenger messenger) {
        activityRef = new WeakReference<>(activity);
        QQLoginBridge bridge = new QQLoginBridge();
        new MethodChannel(messenger, CHANNEL).setMethodCallHandler(bridge);
        // 注册 ActivityResult 回调
        if (activity instanceof PluginRegistry) {
            ((PluginRegistry) activity).addActivityResultListener(bridge);
        }
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "login": {
                String appId = call.argument("appId");
                if (appId == null || appId.isEmpty()) {
                    result.error("NO_APPID", "缺少 QQ AppID", null);
                    return;
                }
                Activity activity = activityRef != null ? activityRef.get() : null;
                if (activity == null) {
                    result.error("NO_ACTIVITY", "Activity 已销毁", null);
                    return;
                }
                pendingResult = result;
                tencent = Tencent.createInstance(appId, activity.getApplicationContext());
                // 用简单授权（只拿 openid + access_token）
                tencent.login(activity, "get_user_info", listener);
                break;
            }
            case "isQQInstalled": {
                Activity activity = activityRef != null ? activityRef.get() : null;
                boolean installed = false;
                if (activity != null && tencent != null) {
                    installed = tencent.isQQInstalled(activity);
                } else {
                    // 未登录过时用包管理器探测
                    try {
                        activity.getPackageManager().getPackageInfo("com.tencent.mobileqq", 0);
                        installed = true;
                    } catch (Throwable ignored) {}
                }
                result.success(installed);
                break;
            }
            case "logout": {
                if (tencent != null) tencent.logout(activityRef.get());
                result.success(true);
                break;
            }
            default:
                result.notImplemented();
        }
    }

    /** QQ 授权回调 */
    private final IUiListener listener = new IUiListener() {
        @Override
        public void onComplete(Object response) {
            if (pendingResult == null) return;
            try {
                JSONObject jo = (JSONObject) response;
                String openid = jo.optString("openid", "");
                String token = jo.optString("access_token", "");
                if (openid.isEmpty() || token.isEmpty()) {
                    pendingResult.error("EMPTY", "QQ 未返回 openid/token", null);
                } else {
                    java.util.Map<String, Object> map = new java.util.HashMap<>();
                    map.put("openid", openid);
                    map.put("access_token", token);
                    pendingResult.success(map);
                }
            } catch (Throwable e) {
                pendingResult.error("PARSE", String.valueOf(e.getMessage()), null);
            }
            pendingResult = null;
        }

        @Override
        public void onError(UiError e) {
            if (pendingResult != null) {
                pendingResult.error("QQ_ERROR",
                        (e != null ? e.errorMessage : "unknown"), null);
                pendingResult = null;
            }
        }

        @Override
        public void onCancel() {
            if (pendingResult != null) {
                pendingResult.success(null); // 用户取消
                pendingResult = null;
            }
        }

        @Override
        public void onWarning(int code) {}
    };

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == Constants.REQUEST_LOGIN) {
            Tencent.onActivityResultData(requestCode, resultCode, data, listener);
            return true;
        }
        return false;
    }
}
