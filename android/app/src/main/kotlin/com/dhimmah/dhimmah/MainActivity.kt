package com.dhimmah.dhimmah

import android.os.Bundle
import android.net.Uri
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
    private var backupFileChannel: BackupFileChannel? = null

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
            updates.onActivityResult(result.resultCode)
        }

    /**
     * Android's own "where should this new document live" flow.
     *
     * `CreateDocument`, not `OpenDocument`: this is the contract that creates a
     * document and hands back a URI the app can write. Its type is fixed when the
     * contract is registered, which is why `BackupFileChannel.MIME_TYPE` is the
     * single definition of it — and why the Dart side asserts the same value, so
     * a fictional `application/vnd.dhimmah` cannot creep back in and make
     * providers refuse the document.
     *
     * Registered here, at field initialisation, for the same reason as the update
     * launcher: `registerForActivityResult` has to be called before the activity
     * reaches STARTED, so registering on first use would crash on first use.
     */
    private val createDocumentLauncher: ActivityResultLauncher<String> =
        registerForActivityResult(
            ActivityResultContracts.CreateDocument(BackupFileChannel.MIME_TYPE),
        ) { uri -> backupFiles.onDocumentCreated(uri) }

    /**
     * And the one that grants standing access to a directory:
     * `ACTION_OPEN_DOCUMENT_TREE`, the mechanism behind "choose a backup folder
     * once and let the app keep using it". The URI it returns is persistable;
     * taking that permission is what makes the folder still available next
     * launch, and the user can revoke it in the system settings at any time.
     */
    private val chooseFolderLauncher: ActivityResultLauncher<Uri?> =
        registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
            backupFiles.onFolderChosen(uri)
        }

    /**
     * The one update channel, created on demand and never replaced.
     *
     * `configureFlutterEngine` is reached from *inside* `super.onCreate` — that
     * is where the engine attaches — so it runs before this activity's own
     * `onCreate` body. A field created in both places therefore ends up holding
     * one object while the method channel answers through another. The
     * consequence is not a crash but a silence: the call that opened the picker
     * waits on an object the picker's result is never delivered to, so the Dart
     * future never completes and the screen sits on "جارٍ فحص المجلد" for ever,
     * with the grant it was given left unclaimed on the platform side. One
     * instance, reached through this accessor, is what makes the caller and the
     * callback the same object.
     */
    private val updates: AppUpdateChannel
        get() = updateChannel
            ?: AppUpdateChannel(this, updateLauncher).also { updateChannel = it }

    /** The one backup channel, for the same reason as [updates]. */
    private val backupFiles: BackupFileChannel
        get() = backupFileChannel
            ?: BackupFileChannel(this, createDocumentLauncher, chooseFolderLauncher)
                .also { backupFileChannel = it }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Touched, not assigned: whichever of the two entry points ran first has
        // already built them, and this must not build a second.
        updates
        backupFiles
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AppUpdateChannel.METHOD_CHANNEL)
            .setMethodCallHandler(updates)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AppUpdateChannel.EVENT_CHANNEL)
            .setStreamHandler(updates)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BackupFileChannel.METHOD_CHANNEL)
            .setMethodCallHandler(backupFiles)
    }

    override fun onDestroy() {
        updateChannel?.dispose()
        updateChannel = null
        backupFileChannel?.dispose()
        backupFileChannel = null
        super.onDestroy()
    }
}
