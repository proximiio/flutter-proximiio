package io.proximi.flutter_proximiio

import android.app.Activity
import android.app.Application
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.withLock

/**
 * One instance per Flutter engine. The SDK instance itself is process-wide ([ProximiioHub]),
 * so several engines (add-to-app, background engines) share it and each gets the events.
 */
class FlutterProximiioPlugin : FlutterPlugin, ActivityAware {
  private var streams: EngineStreams? = null
  private var activityBinding: ActivityPluginBinding? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    val streams = EngineStreams(binding.binaryMessenger)
    this.streams = streams
    ProximiioHub.attach(streams)
    ProximiioHostApi.setUp(binding.binaryMessenger, HostApi(binding.applicationContext))
  }

  /**
   * When the last engine goes, nothing can stop the SDK any more. Without a foreground service it is
   * stopped here; with one it keeps positioning (geofences, analytics) for as long as Android keeps
   * the service, and the next engine reaches it with `Proximiio.shared()`.
   */
  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    ProximiioHostApi.setUp(binding.binaryMessenger, null)
    val streams = streams ?: return
    this.streams = null
    if (ProximiioHub.detach(streams) && ProximiioHub.serviceOptions == null) {
      ProximiioHub.scope.launch {
        ProximiioHub.lifecycle.withLock { ProximiioHub.sdk?.let { ProximiioHub.stopAndDrain(it) } }
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    ProximiioHub.permissionLauncher.attach(binding)
    binding.activity.application.registerActivityLifecycleCallbacks(resumeWatcher)
  }

  override fun onDetachedFromActivityForConfigChanges() = detachActivity(forConfigChange = true)

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

  override fun onDetachedFromActivity() = detachActivity(forConfigChange = false)

  private fun detachActivity(forConfigChange: Boolean) {
    val binding = activityBinding ?: return
    activityBinding = null
    binding.activity.application.unregisterActivityLifecycleCallbacks(resumeWatcher)
    ProximiioHub.permissionLauncher.detach(binding, forConfigChange)
  }

  /** A permission changed in the system settings is seen when the app comes back. */
  private val resumeWatcher = object : Application.ActivityLifecycleCallbacks {
    override fun onActivityResumed(activity: Activity) {
      if (activity === activityBinding?.activity) ProximiioHub.refreshPermissions()
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
    override fun onActivityStarted(activity: Activity) = Unit
    override fun onActivityPaused(activity: Activity) = Unit
    override fun onActivityStopped(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
    override fun onActivityDestroyed(activity: Activity) = Unit
  }
}
