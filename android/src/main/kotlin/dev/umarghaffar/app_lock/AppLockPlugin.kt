package dev.umarghaffar.app_lock

import android.app.Activity
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Hides app content in the recents screen. Android 13+ can hide just the
 * thumbnail; older versions and the strict "secure" mode use FLAG_SECURE,
 * which also blocks screenshots and screen recording.
 */
class AppLockPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var mode = "none"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "app_lock/privacy")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setMode" -> {
                mode = call.argument<String>("mode") ?: "none"
                apply()
                result.success(null)
            }
            // the biometric prompt doesn't pause the activity, nothing to do
            "setSuspended" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    private fun apply() {
        val activity = activity ?: return
        val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        val secure = mode == "secure" || (mode == "hideInAppSwitcher" && !modern)
        if (secure) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        if (modern) activity.setRecentsScreenshotEnabled(mode == "none")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        apply()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        apply()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
