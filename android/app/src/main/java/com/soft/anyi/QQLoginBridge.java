package com.soft.anyi;

import android.app.Activity;
import android.content.Intent;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import com.tencent.connect.common.Constants;
import com.tencent.tauth.IUiListener;
import com.tencent.tauth.Tencent;
import com.tencent.tauth.UiError;

import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.util.HashMap;
import java.util.Map;

/**
 * ★ 1015：QQ 登录原生桥接（自己实现，不用第三方插件）
 *
 * 为什么自己写：
 *   tencent_kit 等第三方插件把 AGP 版本写死在 Gradle 里（7.3.0 + compileSdk 31），
 *   与本项目 AGP 8.x / compileSdk 36 不兼容，反复构建失败。
 *   自己写桥接可完全掌控 Gradle 配置，只依赖腾讯官方 SDK jar。
 *
 * 用法（Dart 侧）：
 *   MethodChannel('com.soft.anyi/qq').invokeMethod('login', {'appId': 'xxx'})
 *
 * 注意：不依赖 PluginRegistry（新版 Flutter 已移除该 API），
 *       改由 MainActivity 在 onActivityResult 里转发回调。
 */
public class QQLoginBridge implements MethodChannel.MethodCallHandler {

    public static final String CHANNEL = "com.soft.anyi/qq";

    private static WeakReference<Activity> activityRef;
    private static MethodChannel.Result pendingResult;
    private static Tencent tencent;

    /** 在 MainActivity.configureFlutterEngine 里调用 */
    public static void register(Activity activity, BinaryMessenger messenger) {
        activityRef = new WeakReference<>(activity);
        new MethodChannel(messenger, CHANNEL).setMethodCallHandler(new QQLoginBridge());
    }

    /** 由 MainActivity.onActivityResult 转发进来 */
    public static boolean handleActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == Constants.REQUEST_LOGIN) {
            Tencent.onActivityResultData(requestCode, resultCode, data, listener);
            return true;
        }
        return false;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "login":
                doLogin(call, result);
                break;
            case "isQQInstalled":
                result.success(isQQInstalled());
                break;
            case "logout":
                try {
                    if (tencent != null) {
                        Activity a = activityRef != null ? activityRef.get() : null;
                        if (a != null) tencent.logout(a);
                    }
                    result.success(true);
                } catch (Throwable e) {
                    result.success(false);
                }
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void doLogin(MethodCall call, MethodChannel.Result result) {
        String appId = call.argument("appId");
        if (appId == null || appId.isEmpty()) {
            result.error("NO_APPID", "缺少 QQ AppID", null);
            return;
        }
        Activity activity = activityRef != null ? activityRef.get() : null;
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity 不可用", null);
            return;
        }
        if (pendingResult != null) {
            result.error("BUSY", "上一次登录尚未完成", null);
            return;
        }
        pendingResult = result;
        try {
            tencent = Tencent.createInstance(appId, activity.getApplicationContext());
            tencent.login(activity, "get_user_info", listener);
        } catch (Throwable e) {
            pendingResult = null;
            result.error("LOGIN_FAIL", String.valueOf(e.getMessage()), null);
        }
    }

    /** 探测 QQ 是否安装（不依赖 Tencent 实例） */
    private boolean isQQInstalled() {
        Activity activity = activityRef != null ? activityRef.get() : null;
        if (activity == null) return false;
        try {
            activity.getPackageManager().getPackageInfo("com.tencent.mobileqq", 0);
            return true;
        } catch (Throwable ignored) {
            // 部分 ROM 包名不同
            try {
                activity.getPackageManager().getPackageInfo("com.tencent.mobileqqi", 0);
                return true;
            } catch (Throwable ignored2) {
                return false;
            }
        }
    }

    /** QQ 授权回调 */
    private static final IUiListener listener = new IUiListener() {
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
                    Map<String, Object> map = new HashMap<>();
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
                // ★ 1015：带上完整错误码（便于定位）
                String msg = (e != null && e.errorMessage != null) ? e.errorMessage : "unknown";
                String detail = e != null ? (e.errorDetail != null ? e.errorDetail : "") : "";
                int code = e != null ? e.errorCode : -1;
                android.util.Log.e("QQLoginBridge", "授权失败 code=" + code + " msg=" + msg + " detail=" + detail);
                pendingResult.error("QQ_ERROR", "code=" + code + " " + msg + " | " + detail, null);
                pendingResult = null;
            }
        }

        @Override
        public void onCancel() {
            if (pendingResult != null) {
                pendingResult.success(null); // 用户取消 → Dart 侧收到 null
                pendingResult = null;
            }
        }

        @Override
        public void onWarning(int code) {
            // 忽略
        }
    };
}
