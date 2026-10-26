package io.proximi.flutter_proximiio

import android.content.ContextWrapper
import io.proximi.flutter_proximiio.Mappers.camelName
import io.proximi.sdk.ProximiioError
import io.proximi.sdk.core.model.JsonValue
import io.proximi.sdk.core.model.ProximiioGeofence
import io.proximi.sdk.core.model.ProximiioGeometryIssue
import io.proximi.sdk.core.platform.PermissionStatus
import io.proximi.sdk.geofencing.GeofenceEvent
import io.proximi.sdk.positioning.native.CoreLocationAccuracy
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertNull

class MappersTest {
  private val context = ContextWrapper(null)

  private fun config(
    preset: MsgConfigurationPreset = MsgConfigurationPreset.STANDARD,
    apiBaseUrl: String? = null,
    desiredAccuracy: MsgDesiredAccuracy? = null,
    visitorReportingEnabled: Boolean? = null,
    geofenceExitDelaySeconds: Double? = null,
    customIBeaconUuids: List<String> = emptyList(),
  ) = MsgConfiguration(
    token = "token",
    preset = preset,
    apiBaseUrl = apiBaseUrl,
    fallbackApiBaseUrls = emptyList(),
    desiredAccuracy = desiredAccuracy,
    visitorReportingEnabled = visitorReportingEnabled,
    geofenceExitDelaySeconds = geofenceExitDelaySeconds,
    customIBeaconUuids = customIBeaconUuids,
  )

  @Test
  fun `unset overrides keep the preset values`() {
    val result = Mappers.configuration(config(), context)

    assertEquals("token", result.token)
    assertEquals(io.proximi.sdk.ProximiioConfiguration.default("token"), result)
  }

  @Test
  fun `overrides replace preset values`() {
    val result = Mappers.configuration(
      config(
        apiBaseUrl = "https://api.example.test",
        desiredAccuracy = MsgDesiredAccuracy.THREE_KILOMETERS,
        visitorReportingEnabled = false,
        geofenceExitDelaySeconds = 1.5,
        customIBeaconUuids = listOf("f7826da6-4fa2-4e98-8024-bc5b71e0893e"),
      ),
      context,
    )

    assertEquals(URI("https://api.example.test"), result.apiBaseURL)
    assertEquals(CoreLocationAccuracy.KILOMETER, result.desiredAccuracy, "Android has no three-kilometre level")
    assertEquals(false, result.visitorReportingEnabled)
    assertEquals(1.5, result.geofenceExitDelay)
    assertEquals("f7826da6-4fa2-4e98-8024-bc5b71e0893e", result.customIBeaconUUIDs.single().toString())
  }

  @Test
  fun `malformed values are rejected as invalidArgument`() {
    val badUrl = assertFailsWith<ProximiioFlutterError> { Mappers.configuration(config(apiBaseUrl = "not a url"), context) }
    assertEquals("invalidArgument", badUrl.code)

    val badUuid = assertFailsWith<ProximiioFlutterError> {
      Mappers.configuration(config(customIBeaconUuids = listOf("nope")), context)
    }
    assertEquals("invalidArgument", badUuid.code)
  }

  @Test
  fun `outline turns GeoJSON longitude-latitude pairs into latitude-longitude`() {
    val zone = Mappers.geofence(
      ProximiioGeofence(
        id = "g",
        polygon = listOf(listOf(17.1, 48.1), listOf(17.2, 48.2), listOf(17.3, 48.3), listOf(1.0)),
        geometryIssue = ProximiioGeometryIssue.DEGENERATE_OUTLINE,
        remoteId = "ext",
      ),
    )

    assertEquals(MsgCoordinate(latitude = 48.1, longitude = 17.1), zone.polygon!!.first())
    assertEquals(3, zone.polygon!!.size, "a point without two values is dropped")
    assertEquals("degenerateOutline", zone.geometryIssue)
    assertEquals("ext", zone.remoteId)
  }

  @Test
  fun `metadata becomes JSON, null stays null`() {
    val json = Mappers.json(
      JsonValue.Object(
        mapOf(
          "wing" to JsonValue.String("A"),
          "rooms" to JsonValue.Array(listOf(JsonValue.Number(1.0), JsonValue.Bool(true), JsonValue.Null)),
        ),
      ),
    )

    assertEquals("""{"wing":"A","rooms":[1,true,null]}""", json)
    assertNull(Mappers.json(null))
    assertNull(Mappers.json(JsonValue.Null))
  }

  @Test
  fun `whole numbers are written as iOS writes them, fractions stay`() {
    val json = Mappers.json(
      JsonValue.Array(listOf(JsonValue.Number(17.0), JsonValue.Number(48.25), JsonValue.Number(-3.0), JsonValue.Number(1e20))),
    )

    assertEquals("""[17,48.25,-3,1.0E20]""", json)
  }

  @Test
  fun `geofence exit keeps the dwell time in seconds`() {
    val event = Mappers.geofenceEvent(GeofenceEvent.Exited(ProximiioGeofence(id = "g"), dwellTime = 61.25))

    assertIs<MsgGeofenceExited>(event)
    assertEquals(61.25, event.dwellTimeSeconds)
  }

  @Test
  fun `SDK errors keep their iOS case names and authorization raw values`() {
    val error = Mappers.flutterError(
      ProximiioError.LocationPermissionDenied(PermissionStatus.LocationAuthorization.NOT_DETERMINED),
    )

    assertEquals("locationPermissionDenied", error.code)
    @Suppress("UNCHECKED_CAST")
    val details = error.details as Map<String, String>
    assertEquals("notDetermined", details["authorization"])
    assertEquals("io.proximi.sdk", details["domain"])
    assertEquals("false", details["retryable"])
  }

  @Test
  fun `other errors are underlying, bridge errors pass through`() {
    assertEquals("underlying", Mappers.flutterError(IllegalStateException("boom")).code)
    assertEquals("notConfigured", Mappers.flutterError(Mappers.notConfigured()).code)
  }

  @Test
  fun `camelName matches the iOS raw values`() {
    assertEquals("whenInUse", PermissionStatus.LocationAuthorization.WHEN_IN_USE.camelName())
    assertEquals("denied", PermissionStatus.LocationAuthorization.DENIED.camelName())
  }
}
