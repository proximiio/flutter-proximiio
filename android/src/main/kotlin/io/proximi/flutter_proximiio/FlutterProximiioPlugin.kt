package io.proximi.flutter_proximiio

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.proximi.proximiiolibrary.*

class FlutterProximiioPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null
  private lateinit var context: Context
  private var activity: Activity? = null
  private var proximiioAPI: ProximiioAPI? = null
  private val options: ProximiioOptions = ProximiioOptions()
  private var activityBinding: ActivityPluginBinding? = null
  private var permissionResult: Result? = null

  // Track state locally
  private var lastFloor: ProximiioFloor? = null
  private val geofences: MutableList<ProximiioGeofence> = mutableListOf()
  private val enteredGeofences: MutableList<ProximiioGeofence> = mutableListOf()
  private val floors: MutableList<ProximiioFloor> = mutableListOf()
  private var authResult: Result? = null

  companion object {
    private const val TAG = "FlutterProximiioPlugin"
    private const val PERMISSION_REQUEST = 1
    private const val BLUETOOTH_REQUEST_S = 2
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_proximiio")
    channel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_proximiio_events")
    eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
      }

      override fun onCancel(arguments: Any?) {
        eventSink = null
      }
    })
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "authorize" -> {
        val token = call.argument<String>("token")
        if (token != null) {
          authorize(token, result)
        } else {
          result.error("INVALID_TOKEN", "Token is required", null)
        }
      }
      "requestPermissions" -> {
        requestPermissions(result)
      }
      "enable" -> {
        proximiioAPI?.setActivity(activity)
        proximiioAPI?.onStart()
        result.success(null)
      }
      "disable" -> {
        proximiioAPI?.onStop()
        result.success(null)
      }
      "currentFloor" -> {
        result.success(lastFloor?.toMap())
      }
      "floors" -> {
        result.success(floors.map { it.toMap() })
      }
      "floorById" -> {
        val id = call.argument<String>("id")
        val floor = floors.find { it.id == id }
        result.success(floor?.toMap())
      }
      "geofences" -> {
        result.success(geofences.map { it.toMap() })
      }
      "geofenceById" -> {
        val id = call.argument<String>("id")
        val geofence = geofences.find { it.id == id }
        result.success(geofence?.toMap())
      }
      "currentGeofences" -> {
        result.success(enteredGeofences.map { it.toMap() })
      }
      "setBufferSize" -> {
        // Buffer size may not be supported in newer SDK versions
        result.success(null)
      }
      "setNativeAccuracy" -> {
        val accuracy = call.argument<Int>("accuracy")
        if (accuracy != null) {
          proximiioAPI?.setNativeAccuracy(ProximiioApplication.NativeAccuracy.fromInt(accuracy))
        }
        result.success(null)
      }
      "setNotificationMode" -> {
        val mode = call.argument<Int>("mode")
        if (mode != null) {
          options.notificationMode = ProximiioOptions.NotificationMode.fromInt(mode)
        }
        result.success(null)
      }
      "setNotificationTitle" -> {
        val title = call.argument<String>("title")
        options.notificationTitle = title
        result.success(null)
      }
      "setNotificationText" -> {
        val text = call.argument<String>("text")
        options.notificationText = text
        result.success(null)
      }
      "setNotificationIcon" -> {
        val icon = call.argument<String>("icon")
        if (icon != null) {
          val identifier = context.resources.getIdentifier(icon, "drawable", context.packageName)
          if (identifier != 0) {
            options.notificationIcon = identifier
          }
        }
        result.success(null)
      }
      "updateOptions" -> {
        proximiioAPI?.updateNotificationOptions(options)
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun requestPermissions(result: Result) {
    val currentActivity = activity
    if (currentActivity == null) {
      result.error("NO_ACTIVITY", "Activity not available", null)
      return
    }

    permissionResult = result

    // Check if we already have location permission
    if (hasLocationPermission()) {
      // If we have location, request Bluetooth permissions (Android 12+)
      if (Build.VERSION.SDK_INT >= 31) {
        requestBluetoothPermissions(currentActivity)
      } else {
        result.success(true)
      }
    } else {
      // Request location permission first
      ActivityCompat.requestPermissions(
        currentActivity,
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
        PERMISSION_REQUEST
      )
    }
  }

  private fun requestBluetoothPermissions(activity: Activity) {
    if (Build.VERSION.SDK_INT >= 31) {
      ActivityCompat.requestPermissions(
        activity,
        arrayOf(
          Manifest.permission.BLUETOOTH_SCAN,
          Manifest.permission.BLUETOOTH_CONNECT
        ),
        BLUETOOTH_REQUEST_S
      )
    }
  }

  private fun hasLocationPermission(): Boolean {
    return ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    when (requestCode) {
      PERMISSION_REQUEST -> {
        val granted = grantResults.isNotEmpty() &&
                     grantResults[0] == PackageManager.PERMISSION_GRANTED

        if (granted && Build.VERSION.SDK_INT >= 31) {
          // Request Bluetooth permissions after location is granted
          activity?.let { requestBluetoothPermissions(it) }
        } else {
          permissionResult?.success(granted)
          permissionResult = null
        }
        return true
      }
      BLUETOOTH_REQUEST_S -> {
        permissionResult?.success(true)
        permissionResult = null
        return true
      }
    }
    return false
  }

  private fun authorize(token: String, result: Result) {
    authResult = result

    // Clean up existing instance
    proximiioAPI?.setActivity(null)
    proximiioAPI?.onStop()

    // Create new instance
    proximiioAPI = ProximiioAPI(TAG, context, options)

    // Set up the listener
    proximiioAPI?.setListener(object : ProximiioListener() {
      override fun loggedIn(online: Boolean, auth: String) {
        if (online && authResult != null) {
          val visitorId = proximiioAPI?.visitorID ?: ""
          val state = mapOf(
            "ready" to true,
            "visitorId" to visitorId
          )
          authResult?.success(state)
          authResult = null
        }
      }

      override fun loginFailed(error: LoginError) {
        if (authResult != null) {
          authResult?.error("INIT_ERROR", error.toString(), null)
          authResult = null
        }
      }

      override fun positionExtended(lat: Double, lon: Double, accuracy: Double, type: ProximiioGeofence.EventType?) {
        sendEvent("positionUpdated", mapOf(
          "lat" to lat,
          "lng" to lon,
          "accuracy" to accuracy,
          "sourceType" to (type?.name ?: "unknown")
        ))
      }

      override fun changedFloor(floor: ProximiioFloor?) {
        lastFloor = floor
        sendEvent("floorChanged", floor?.toMap())
      }

      override fun addedGeofence(geofence: ProximiioGeofence) {
        if (!geofences.contains(geofence)) {
          geofences.add(geofence)
        }
      }

      override fun removedGeofence(geofence: ProximiioGeofence) {
        geofences.remove(geofence)
        enteredGeofences.remove(geofence)
      }

      override fun geofenceEnter(geofence: ProximiioGeofence) {
        if (!enteredGeofences.contains(geofence)) {
          enteredGeofences.add(geofence)
        }
        sendEvent("enteredGeofence", geofence.toMap())
      }

      override fun geofenceExit(geofence: ProximiioGeofence, dwellTime: Long?) {
        enteredGeofences.remove(geofence)
        val data = geofence.toMap().toMutableMap()
        if (dwellTime != null) {
          data["dwellTime"] = dwellTime
        }
        sendEvent("exitedGeofence", data)
      }

      override fun privacyZoneEnter(area: ProximiioArea) {
        sendEvent("enteredPrivacyZone", area.toMap())
      }

      override fun privacyZoneExit(area: ProximiioArea) {
        sendEvent("exitedPrivacyZone", area.toMap())
      }

      override fun foundDevice(device: ProximiioBLEDevice, registered: Boolean) {
        when (device.getType()) {
          ProximiioInput.InputType.IBEACON -> {
            val beacon = device as ProximiioIBeacon
            sendEvent("foundIBeacon", beacon.toMap())
          }
          ProximiioInput.InputType.EDDYSTONE -> {
            val beacon = device as ProximiioEddystone
            sendEvent("foundEddystoneBeacon", beacon.toMap())
          }
          else -> {}
        }
      }

      override fun lostDevice(device: ProximiioBLEDevice, registered: Boolean) {
        when (device.getType()) {
          ProximiioInput.InputType.IBEACON -> {
            val beacon = device as ProximiioIBeacon
            sendEvent("lostIBeacon", beacon.toMap())
          }
          ProximiioInput.InputType.EDDYSTONE -> {
            val beacon = device as ProximiioEddystone
            sendEvent("lostEddystoneBeacon", beacon.toMap())
          }
          else -> {}
        }
      }

      override fun updatedFloor(floor: ProximiioFloor) {
        val index = floors.indexOfFirst { it.id == floor.id }
        if (index >= 0) {
          floors[index] = floor
        } else {
          floors.add(floor)
        }
      }
    })

    // Authenticate
    proximiioAPI?.setAuth(token, true)
  }

  private fun sendEvent(event: String, data: Any?) {
    val eventData = mapOf(
      "event" to event,
      "data" to data
    )
    activity?.runOnUiThread {
      eventSink?.success(eventData)
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    proximiioAPI?.onStop()
    proximiioAPI?.destroyService(false)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityBinding = binding
    binding.addRequestPermissionsResultListener(this)
    proximiioAPI?.setActivity(activity)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityBinding = binding
    binding.addRequestPermissionsResultListener(this)
    proximiioAPI?.setActivity(activity)
  }

  override fun onDetachedFromActivity() {
    activity = null
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
  }
}

// Extension functions for converting objects to maps
private fun ProximiioFloor.toMap(): Map<String, Any?> {
  // Convert anchors 2D array to list of lists for Flutter
  val anchorsList = anchors?.map { anchor ->
    anchor.toList()
  } ?: emptyList()

  return mapOf(
    "id" to id,
    "name" to name,
    "level" to (floorNumber ?: 0),
    "placeId" to (place?.id),
    "floorplan" to floorPlanURL,
    "anchors" to anchorsList
  )
}

private fun ProximiioArea.toMap(): Map<String, Any?> {
  // Convert polygon 2D array to list of lists for Flutter
  val polygonList = polygon?.map { point ->
    listOf(point[0], point[1])
  }

  return mapOf(
    "id" to id,
    "name" to name,
    "lat" to lat,
    "lng" to lon,
    "radius" to radius,
    "isPolygon" to (polygon != null),
    "polygon" to polygonList,
    "entered" to (isEntered() != null)
  )
}

private fun ProximiioGeofence.toMap(): Map<String, Any?> {
  return (this as ProximiioArea).toMap()
}

private fun ProximiioIBeacon.toMap(): Map<String, Any?> {
  return mapOf(
    "type" to "ibeacon",
    "uuid" to uuid,
    "major" to major,
    "minor" to minor,
    "accuracy" to (distance ?: 50.0),
    "identifier" to "$uuid/$major/$minor"
  )
}

private fun ProximiioEddystone.toMap(): Map<String, Any?> {
  return mapOf(
    "type" to "eddystone",
    "namespace" to namespace,
    "instanceId" to instanceID,
    "identifier" to "$namespace/$instanceID"
  )
}
