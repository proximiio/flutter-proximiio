package io.proximi.flutter_proximiio

import android.Manifest
import android.app.Notification
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.proximi.sdk.Proximiio
import io.proximi.sdk.application
import io.proximi.sdk.currentFloor
import io.proximi.sdk.enteredGeofenceIds
import io.proximi.sdk.floor
import io.proximi.sdk.floors
import io.proximi.sdk.geofences
import io.proximi.sdk.isInPrivacyZone
import io.proximi.sdk.lastPosition
import io.proximi.sdk.place
import io.proximi.sdk.places
import io.proximi.sdk.privacyZones
import io.proximi.sdk.refreshPermissions
import io.proximi.sdk.requestMotionPermission
import io.proximi.sdk.requestPermissions
import io.proximi.sdk.resetServiceNotification
import io.proximi.sdk.service.ProximiioServiceOptions
import io.proximi.sdk.updateServiceNotification
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** Handles the Dart → native calls. Every call runs on the main thread and suspends on the SDK. */
internal class HostApi(private val context: Context) : ProximiioHostApi {

  private fun <T> run(callback: (Result<T>) -> Unit, body: suspend (Proximiio) -> T) {
    ProximiioHub.scope.launch {
      val sdk = ProximiioHub.sdk
      if (sdk == null) {
        callback(Result.failure(Mappers.notConfigured()))
        return@launch
      }
      val result = try {
        Result.success(body(sdk))
      } catch (error: CancellationException) {
        throw error
      } catch (error: Throwable) {
        Result.failure(Mappers.flutterError(error))
      }
      callback(result)
    }
  }

  override fun configure(configuration: MsgConfiguration, callback: (Result<Unit>) -> Unit) {
    ProximiioHub.scope.launch {
      val result = try {
        ProximiioHub.configure(context, Mappers.configuration(configuration, context))
        Result.success(Unit)
      } catch (error: CancellationException) {
        throw error
      } catch (error: Throwable) {
        Result.failure(Mappers.flutterError(error))
      }
      callback(result)
    }
  }

  override fun state(callback: (Result<MsgSdkState>) -> Unit) =
    run(callback) { Mappers.state(it.state()) }

  /**
   * Location (and background location with [always]) through the SDK, then what the SDK leaves to
   * the host on Android: Bluetooth scan/connect (API 31+) and, while the service notification is
   * on, POST_NOTIFICATIONS (API 33+). iOS asks for Bluetooth inside the SDK, so both platforms
   * end in the same state.
   */
  override fun requestPermissions(always: Boolean, callback: (Result<MsgPermissionStatus>) -> Unit) =
    run(callback) { sdk ->
      sdk.requestPermissions(always)
      val missing = buildList {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
          add(Manifest.permission.BLUETOOTH_SCAN)
          add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && ProximiioHub.wantsNotifications) {
          add(Manifest.permission.POST_NOTIFICATIONS)
        }
      }.filter { ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED }
      ProximiioHub.permissionLauncher.request(missing)
      Mappers.permissionStatus(sdk.refreshPermissions())
    }

  override fun requestMotionPermission(callback: (Result<Boolean>) -> Unit) =
    run(callback) { it.requestMotionPermission() }

  override fun authenticate(callback: (Result<MsgApplication?>) -> Unit) =
    run(callback) { sdk ->
      try {
        sdk.authenticate()?.let(Mappers::application)
      } finally {
        ProximiioHub.publishState()
      }
    }

  override fun start(callback: (Result<Unit>) -> Unit) =
    run(callback) { sdk ->
      try {
        sdk.start()
        ProximiioHub.subscribeRunStreams()
      } finally {
        ProximiioHub.publishState()
      }
    }

  override fun stop(callback: (Result<Unit>) -> Unit) =
    run(callback) { sdk ->
      sdk.stop()
      ProximiioHub.cancelRunStreams()
      ProximiioHub.publishState()
    }

  override fun signOut(callback: (Result<Unit>) -> Unit) =
    run(callback) { sdk ->
      try {
        sdk.signOut()
      } finally {
        ProximiioHub.publishState()
      }
    }

  override fun sync(callback: (Result<Long>) -> Unit) =
    run(callback) { it.sync().toLong() }

  override fun application(callback: (Result<MsgApplication?>) -> Unit) =
    run(callback) { sdk -> sdk.application()?.let(Mappers::application) }

  override fun places(callback: (Result<List<MsgPlace>>) -> Unit) =
    run(callback) { sdk -> sdk.places().map(Mappers::place) }

  override fun floors(callback: (Result<List<MsgFloor>>) -> Unit) =
    run(callback) { sdk -> sdk.floors().map(Mappers::floor) }

  override fun geofences(callback: (Result<List<MsgZone>>) -> Unit) =
    run(callback) { sdk -> sdk.geofences().map(Mappers::geofence) }

  override fun privacyZones(callback: (Result<List<MsgZone>>) -> Unit) =
    run(callback) { sdk -> sdk.privacyZones().map(Mappers::privacyZone) }

  override fun place(id: String, callback: (Result<MsgPlace?>) -> Unit) =
    run(callback) { sdk -> sdk.place(id)?.let(Mappers::place) }

  override fun floor(id: String, callback: (Result<MsgFloor?>) -> Unit) =
    run(callback) { sdk -> sdk.floor(id)?.let(Mappers::floor) }

  override fun currentFloor(callback: (Result<MsgFloor?>) -> Unit) =
    run(callback) { sdk -> sdk.currentFloor()?.let(Mappers::floor) }

  override fun lastPosition(callback: (Result<MsgPositionUpdate?>) -> Unit) =
    run(callback) { sdk -> sdk.lastPosition()?.let(Mappers::position) }

  override fun enteredGeofenceIds(callback: (Result<List<String>>) -> Unit) =
    run(callback) { sdk -> sdk.enteredGeofenceIds().sorted() }

  override fun isInPrivacyZone(callback: (Result<Boolean>) -> Unit) =
    run(callback) { it.isInPrivacyZone() }

  override fun visitorId(callback: (Result<String>) -> Unit) =
    run(callback) { it.visitorId() }

  override fun resetVisitorId(callback: (Result<String>) -> Unit) =
    run(callback) { it.resetVisitorId() }

  override fun visitorReportingConsent(callback: (Result<Boolean>) -> Unit) =
    run(callback) { it.visitorReportingConsent() }

  override fun setVisitorReportingConsent(granted: Boolean, callback: (Result<Unit>) -> Unit) =
    run(callback) { it.setVisitorReportingConsent(granted) }

  override fun setLogLevel(level: MsgLogLevel) {
    Proximiio.logLevel = Mappers.logLevel(level)
  }

  override fun updateServiceNotification(options: MsgAndroidServiceOptions, callback: (Result<Boolean>) -> Unit) =
    run(callback) { sdk -> sdk.updateServiceNotification(notification(options)) }

  override fun resetServiceNotification(callback: (Result<Unit>) -> Unit) =
    run(callback) { it.resetServiceNotification() }

  /** A notification on the SDK's service channel, with the configured defaults for unset fields. */
  private fun notification(options: MsgAndroidServiceOptions): Notification {
    val service = Mappers.serviceOptions(options, context)
    val icon = if (service.notificationIcon != 0) service.notificationIcon else context.applicationInfo.icon
    return Notification.Builder(context, ProximiioServiceOptions.CHANNEL_ID)
      .setContentTitle(service.notificationTitle)
      .setContentText(service.notificationText)
      .setSmallIcon(icon)
      .setOngoing(true)
      .build()
  }
}
