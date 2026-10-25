package io.proximi.flutter_proximiio

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

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

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    ProximiioHostApi.setUp(binding.binaryMessenger, null)
    streams?.let(ProximiioHub::detach)
    streams = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    ProximiioHub.permissionLauncher.attach(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

  override fun onDetachedFromActivity() {
    activityBinding?.let(ProximiioHub.permissionLauncher::detach)
    activityBinding = null
  }
}
