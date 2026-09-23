package com.dhimmah.dhimmah

import android.os.Bundle
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * `FlutterFragmentActivity`, not `FlutterActivity`.
 *
 * This is not a preference. `androidx.biometric` shows its prompt through a
 * fragment, so `local_auth` refuses to run on a plain activity: it answers
 * NOT_FRAGMENT_ACTIVITY, which the Dart side reports as
 * `LocalAuthExceptionCode.uiUnavailable` with the message "The current Activity
 * must be a FragmentActivity". The prompt never appears and the fingerprint
 * button looks broken.
 *
 * `FragmentActivity` needs no appcompat theme of its own — the plugin's prompt
 * layout is built from plain platform views — so the launch and normal themes
 * stay as they are.
 *
 * Pinned by `test/platform/android_setup_test.dart`, because none of this is
 * visible from Dart.
 */
class MainActivity : FlutterFragmentActivity() {

    private var updateChannel: AppUpdateChannel? = null

    /**
     * The launcher Play's update flow reports back through.
     *
     * Registered here, at field initialisation, and not lazily: Flutter's
     * `registerForActivityResult` has to be called before the activity reaches
     * STARTED, so a registration that happened on the first update check would
     * be a crash on the first update check.
     */
    private val updateLauncher: ActivityResultLauncher<IntentSenderRequest> =
        registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
            updateChannel?.onActivityResult(result.resultCode)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        updateChannel = AppUpdateChannel(this, updateLauncher)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = updateChannel ?: AppUpdateChannel(this, updateLauncher).also {
            updateChannel = it
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AppUpdateChannel.METHOD_CHANNEL)
            .setMethodCallHandler(channel)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AppUpdateChannel.EVENT_CHANNEL)
            .setStreamHandler(channel)
    }

    override fun onDestroy() {
        updateChannel?.dispose()
        updateChannel = null
        super.onDestroy()
    }
}
