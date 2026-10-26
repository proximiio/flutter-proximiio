package io.proximi.flutter_proximiio

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import io.proximi.sdk.core.platform.PermissionRequestLauncher
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Shows runtime-permission prompts for the SDK through Flutter's activity binding.
 *
 * The SDK's own `ActivityResultPermissionLauncher` needs a `ComponentActivity`, and a plain
 * `FlutterActivity` is not one; this launcher works with any activity Flutter attaches. It is
 * process-wide like the SDK: every engine with an activity attaches it, and prompts go to the most
 * recently attached one.
 *
 * The SDK records a permission as asked before it calls the launcher, so callers check [canPrompt]
 * first: a request without an activity would read as a denial from then on.
 */
internal class FlutterPermissionLauncher : PermissionRequestLauncher, PluginRegistry.RequestPermissionsResultListener {
  private val bindings = mutableListOf<ActivityPluginBinding>()
  private var pending: Pending? = null
  private val mutex = Mutex()

  /** A prompt on screen. [activity] is `null` between a configuration change and the reattach. */
  private class Pending(val permissions: List<String>, var activity: Activity?) {
    val result = CompletableDeferred<Map<String, Boolean>>()
  }

  /** Whether an activity is attached to show a prompt on. */
  val canPrompt: Boolean get() = bindings.isNotEmpty()

  fun attach(binding: ActivityPluginBinding) {
    if (binding in bindings) return
    bindings += binding
    binding.addRequestPermissionsResultListener(this)
    pending?.let { if (it.activity == null) it.activity = binding.activity }
  }

  /**
   * Removes [binding]. After a configuration change the recreated activity receives the result of a
   * prompt still on screen, so it stays pending; otherwise the prompt is gone and it resolves with
   * what is granted now.
   */
  fun detach(binding: ActivityPluginBinding, forConfigChange: Boolean) {
    if (!bindings.remove(binding)) return
    binding.removeRequestPermissionsResultListener(this)
    val pending = pending?.takeIf { it.activity === binding.activity } ?: return
    if (forConfigChange) {
      pending.activity = null
    } else {
      pending.result.complete(grants(binding.activity, pending.permissions))
    }
  }

  override suspend fun request(permissions: List<String>): Map<String, Boolean> {
    if (permissions.isEmpty()) return emptyMap()
    return mutex.withLock {
      val shown = withContext(Dispatchers.Main) {
        val activity = bindings.lastOrNull()?.activity ?: return@withContext null
        Pending(permissions, activity).also {
          pending = it
          ActivityCompat.requestPermissions(activity, permissions.toTypedArray(), REQUEST_CODE)
        }
      } ?: return@withLock permissions.associateWith { false }
      try {
        shown.result.await()
      } finally {
        pending = null
      }
    }
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ): Boolean {
    if (requestCode != REQUEST_CODE) return false
    val pending = pending ?: return true
    // An interrupted prompt reports empty arrays; what is granted now is the answer then.
    val context = pending.activity ?: bindings.lastOrNull()?.activity
    val current = context?.let { grants(it, pending.permissions) } ?: pending.permissions.associateWith { false }
    val result = current + permissions.indices.associate { index ->
      permissions[index] to (grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED)
    }
    pending.result.complete(result)
    return true
  }

  private fun grants(context: Context, permissions: List<String>): Map<String, Boolean> =
    permissions.associateWith { ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }

  private companion object {
    /** Any 16-bit value distinct from other plugins' codes; the SDK's legacy 111…115 are left alone. */
    const val REQUEST_CODE = 0x5078
  }
}
