package com.dhimmah.dhimmah

import android.app.Activity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play's in-app updates, behind one channel.
 *
 * The app never downloads an APK and never installs anything: it asks the Play
 * Store app what it would install, and hands the download and the install back
 * to Play. That is the only route allowed to update an app on a modern Android
 * device, and the only one that respects the user's own Play settings — over
 * mobile data, over metered connections, and on a device Play has not yet rolled
 * the release out to.
 *
 * `com.google.android.play:app-update`, not the old monolithic `play-core`: the
 * Play Core libraries were split per feature and the old artifact is superseded.
 * The task type moved with the split, so this uses
 * `com.google.android.gms.tasks.Task` through the library's own API rather than
 * the retired `com.google.android.play.core.tasks`.
 */
class AppUpdateChannel(
    private val activity: Activity,
    private val launcher: ActivityResultLauncher<IntentSenderRequest>,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "dhimmah/app_update"
        const val EVENT_CHANNEL = "dhimmah/app_update/events"

        private const val TYPE_FLEXIBLE = AppUpdateType.FLEXIBLE
        private const val TYPE_IMMEDIATE = AppUpdateType.IMMEDIATE
    }

    private val manager: AppUpdateManager = AppUpdateManagerFactory.create(activity)

    private var events: EventChannel.EventSink? = null
    private var lastInfo: AppUpdateInfo? = null

    /**
     * Play's own install listener.
     *
     * Registered while a download is running and unregistered as soon as it
     * settles, because leaving it attached is a wakeup on every install-state
     * change for the life of the process.
     *
     * The body is a separate function rather than a lambda that names this
     * field: a lambda that unregisters *itself* makes the compiler try to work
     * out the type of `installListener` from its own initialiser, which it
     * cannot, and reports it as a recursive type problem.
     */
    private val installListener: InstallStateUpdatedListener =
        InstallStateUpdatedListener { state -> onInstallState(state) }

    private fun onInstallState(state: InstallState) {
        val status = state.installStatus()
        val phase = when (status) {
            InstallStatus.DOWNLOADING -> "downloading"
            InstallStatus.DOWNLOADED -> "downloaded"
            InstallStatus.INSTALLING -> "installing"
            InstallStatus.INSTALLED -> "installed"
            InstallStatus.FAILED -> "failed"
            InstallStatus.CANCELED -> "cancelled"
            else -> null
        }

        if (phase != null) {
            events?.success(
                mapOf(
                    "phase" to phase,
                    "available" to (status != InstallStatus.INSTALLED),
                    "availableVersionCode" to (lastInfo?.availableVersionCode() ?: 0),
                    "updatePriority" to (lastInfo?.updatePriority() ?: 0),
                    "bytesDownloaded" to state.bytesDownloaded(),
                    "totalBytesToDownload" to state.totalBytesToDownload(),
                )
            )
        }

        when (status) {
            InstallStatus.DOWNLOADED,
            InstallStatus.FAILED,
            InstallStatus.CANCELED,
            InstallStatus.INSTALLED,
            -> manager.unregisterListener(installListener)
        }
    }

    // --- Method channel ------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "check" -> check(result)
            "startFlexible" -> start(result, TYPE_FLEXIBLE)
            "startImmediate" -> start(result, TYPE_IMMEDIATE)
            "complete" -> complete(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Asks Play what it would install.
     *
     * The answer is Play's alone. This does not compare version names and does
     * not read the installed version code: Play decides whether an update is
     * available to *this* install, on *this* device, for *this* user, and a
     * client that second-guesses it either nags about an update it cannot
     * deliver or hides one it can.
     */
    private fun check(result: MethodChannel.Result) {
        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                lastInfo = info
                val availability = info.updateAvailability()

                // A stalled immediate update is resumed rather than offered: the
                // user already agreed to it, and Play expects the app to pick it
                // back up when it returns to the foreground.
                val stalled =
                    availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS

                if (availability != UpdateAvailability.UPDATE_AVAILABLE && !stalled) {
                    result.success(mapOf("available" to false))
                    return@addOnSuccessListener
                }

                result.success(describe(info, stalled = stalled))
            }
            .addOnFailureListener {
                // A device without Play, a store updating itself, a check that
                // timed out — all of them mean "nothing to offer right now".
                result.success(mapOf("available" to false))
            }
    }

    /**
     * Starts the flow the user asked for.
     *
     * Returns whether Play accepted it, so the app can tell "the flow is running"
     * from "this install cannot be updated by Play at all" — which is every
     * sideloaded copy, and is not something to explain to a user.
     */
    private fun start(result: MethodChannel.Result, type: Int) {
        val info = lastInfo
        if (info == null) {
            result.success(false)
            return
        }
        val options = AppUpdateOptions.newBuilder(type).build()
        val started = try {
            manager.startUpdateFlowForResult(info, launcher, options)
        } catch (_: Exception) {
            // An IntentSender Play handed over that the system refused. Nothing
            // the user can act on.
            false
        }
        if (started && type == TYPE_FLEXIBLE) {
            manager.registerListener(installListener)
        }
        result.success(started)
    }

    /**
     * Installs a flexible update that has finished downloading.
     *
     * In the foreground Play shows its own full-screen progress and restarts the
     * app; nothing after this call is the app's to draw.
     */
    private fun complete(result: MethodChannel.Result) {
        manager.completeUpdate()
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { result.success(false) }
    }

    /** The map the Dart side reads, with no personal data in it. */
    private fun describe(info: AppUpdateInfo, stalled: Boolean): Map<String, Any?> = mapOf(
        "available" to true,
        "availableVersionCode" to info.availableVersionCode(),
        "updatePriority" to info.updatePriority(),
        "stalenessDays" to info.clientVersionStalenessDays(),
        "flexibleAllowed" to info.isUpdateTypeAllowed(TYPE_FLEXIBLE),
        "immediateAllowed" to (stalled || info.isUpdateTypeAllowed(TYPE_IMMEDIATE)),
        "resumeImmediate" to stalled,
        "bytesDownloaded" to info.bytesDownloaded(),
        "totalBytesToDownload" to info.totalBytesToDownload(),
    )

    /** The result of the flow Play ran on the app's behalf. */
    fun onActivityResult(resultCode: Int) {
        if (resultCode == Activity.RESULT_OK) return
        // The user closed Play's screen, or the update could not proceed. Both
        // mean the app goes back to what it was doing; the next check finds the
        // update again if it is still there.
        events?.success(mapOf("phase" to "cancelled", "available" to false))
    }

    // --- Event channel -------------------------------------------------------

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
        // Only the listener that exists for a download is unregistered, and only
        // once there is no longer anyone to tell.
        manager.unregisterListener(installListener)
    }

    /** Called from the activity's `onDestroy`, so no listener outlives the UI. */
    fun dispose() {
        manager.unregisterListener(installListener)
        events = null
    }
}
