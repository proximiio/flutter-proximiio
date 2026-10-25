package io.proximi.flutter_proximiio

import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
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
 * `FlutterActivity` is not one; this launcher works with any activity Flutter attaches.
 * Without an attached activity, a request resolves at once with nothing granted, and the SDK
 * re-reads the real state afterwards.
 */
internal class FlutterPermissionLauncher : PermissionRequestLauncher, PluginRegistry.RequestPermissionsResultListener {
  private var binding: ActivityPluginBinding? = null
  private var pending: CompletableDeferred<Map<String, Boolean>>? = null
  private val mutex = Mutex()

  fun attach(binding: ActivityPluginBinding) {
    this.binding?.removeRequestPermissionsResultListener(this)
    this.binding = binding
    binding.addRequestPermissionsResultListener(this)
  }

  fun detach(binding: ActivityPluginBinding) {
    if (this.binding !== binding) return
    binding.removeRequestPermissionsResultListener(this)
    this.binding = null
  }

  override suspend fun request(permissions: List<String>): Map<String, Boolean> {
    if (permissions.isEmpty()) return emptyMap()
    return mutex.withLock {
      val deferred = CompletableDeferred<Map<String, Boolean>>()
      val shown = withContext(Dispatchers.Main) {
        val activity = binding?.activity ?: return@withContext false
        pending = deferred
        ActivityCompat.requestPermissions(activity, permissions.toTypedArray(), REQUEST_CODE)
        true
      }
      if (!shown) return@withLock permissions.associateWith { false }
      try {
        deferred.await()
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
    val result = permissions.indices.associate { index ->
      permissions[index] to (grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED)
    }
    pending?.complete(result)
    return true
  }

  private companion object {
    /** Any 16-bit value distinct from other plugins' codes; the SDK's legacy 111…115 are left alone. */
    const val REQUEST_CODE = 0x5078
  }
}
