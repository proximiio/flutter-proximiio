import Flutter
import UIKit
import Proximiio

public class FlutterProximiioPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, ProximiioDelegate {
  private var eventSink: FlutterEventSink?
  private var proximiio: Proximiio?
  private var authResult: FlutterResult?

  // Track state locally
  private var currentFloor: ProximiioFloor?
  private var floors: [ProximiioFloor] = []
  private var geofences: [ProximiioGeofence] = []
  private var enteredGeofences: [ProximiioGeofence] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_proximiio", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "flutter_proximiio_events", binaryMessenger: registrar.messenger())
    let instance = FlutterProximiioPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorize":
      guard let args = call.arguments as? [String: Any],
            let token = args["token"] as? String else {
        result(FlutterError(code: "INVALID_TOKEN", message: "Token is required", details: nil))
        return
      }
      authorize(token: token, result: result)

    case "requestPermissions":
      let args = call.arguments as? [String: Any]
      let useAlways = args?["useAlways"] as? Bool ?? true
      proximiio?.requestPermissions(useAlways)
      result(nil)

    case "enable":
      proximiio?.startUpdating()
      result(nil)

    case "disable":
      proximiio?.stopUpdating()
      result(nil)

    case "currentFloor":
      if let floor = currentFloor {
        result(floor.toMap())
      } else {
        result(nil)
      }

    case "floors":
      result(floors.map { $0.toMap() })

    case "floorById":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(nil)
        return
      }
      if let floor = floors.first(where: { $0.uuid == id }) {
        result(floor.toMap())
      } else {
        result(nil)
      }

    case "geofences":
      result(geofences.map { $0.toMap() })

    case "geofenceById":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(nil)
        return
      }
      if let geofence = geofences.first(where: { $0.uuid == id }) {
        result(geofence.toMap())
      } else {
        result(nil)
      }

    case "currentGeofences":
      result(enteredGeofences.map { $0.toMap() })

    case "setBufferSize":
      guard let args = call.arguments as? [String: Any],
            let bufferSize = args["bufferSize"] as? Int else {
        result(nil)
        return
      }
      var size: ProximiioBufferSize
      switch bufferSize {
      case 0: size = kProximiioBufferMini
      case 1: size = kProximiioBufferSmall
      case 2: size = kProximiioBufferMedium
      case 3: size = kProximiioBufferLarge
      case 4: size = kProximiioBufferExtraLarge
      default: size = kProximiioBufferMini
      }
      proximiio?.setBufferSize(size)
      result(nil)

    case "setNativeAccuracy":
      guard let args = call.arguments as? [String: Any],
            let accuracy = args["accuracy"] as? Int else {
        result(nil)
        return
      }
      var acc: CLLocationAccuracy
      switch accuracy {
      case 0: acc = kCLLocationAccuracyThreeKilometers
      case 1: acc = kCLLocationAccuracyKilometer
      case 2: acc = kCLLocationAccuracyHundredMeters
      case 3: acc = kCLLocationAccuracyBest
      default: acc = kCLLocationAccuracyBest
      }
      proximiio?.setDesiredAccuracy(acc)
      result(nil)

    case "setNotificationMode":
      // Not applicable for iOS
      result(nil)

    case "setNotificationTitle":
      // Not applicable for iOS
      result(nil)

    case "setNotificationText":
      // Not applicable for iOS
      result(nil)

    case "setNotificationIcon":
      // Not applicable for iOS
      result(nil)

    case "updateOptions":
      // Not applicable for iOS
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authorize(token: String, result: @escaping FlutterResult) {
    authResult = result

    // Get shared instance
    proximiio = Proximiio.sharedInstance()
    proximiio?.delegate = self

    // Authenticate with token
    proximiio?.auth(withToken: token) { [weak self] (state) in
      if state == kProximiioReady {
        // Sync data
        self?.proximiio?.sync { (completed) in
          if completed {
            // Start positioning
            self?.proximiio?.startUpdating()
            self?.proximiio?.setBufferSize(kProximiioBufferMini)

            // Get visitor ID
            let visitorId = self?.proximiio?.visitorId ?? ""

            let stateMap: [String: Any] = [
              "ready": true,
              "visitorId": visitorId
            ]
            self?.authResult?(stateMap)
            self?.authResult = nil
          } else {
            self?.authResult?(FlutterError(code: "SYNC_ERROR", message: "Failed to sync data", details: nil))
            self?.authResult = nil
          }
        }
      } else {
        self?.authResult?(FlutterError(code: "AUTH_ERROR", message: "Authentication failed", details: nil))
        self?.authResult = nil
      }
    }
  }

  // MARK: - ProximiioDelegate Methods

  public func proximiioPositionUpdated(_ location: ProximiioLocation) {
    var locationData = location.toMap()
    // Add current floor if available
    if let floor = currentFloor {
      locationData["floor"] = floor.toMap()
    }
    sendEvent(event: "positionUpdated", data: locationData)
  }

  public func proximiioFloorChanged(_ floor: ProximiioFloor?) {
    currentFloor = floor
    if let floor = floor {
      sendEvent(event: "floorChanged", data: floor.toMap())

      // Update floors list if not already present
      if !floors.contains(where: { $0.uuid == floor.uuid }) {
        floors.append(floor)
      }
    }
  }

  public func proximiioEnteredGeofence(_ geofence: ProximiioGeofence) {
    if !enteredGeofences.contains(where: { $0.uuid == geofence.uuid }) {
      enteredGeofences.append(geofence)
    }
    if !geofences.contains(where: { $0.uuid == geofence.uuid }) {
      geofences.append(geofence)
    }
    sendEvent(event: "enteredGeofence", data: geofence.toMap())
  }

  public func proximiioExitedGeofence(_ geofence: ProximiioGeofence, dwellTime: Double?) {
    enteredGeofences.removeAll(where: { $0.uuid == geofence.uuid })
    var data = geofence.toMap()
    if let dwell = dwellTime {
      data["dwellTime"] = Int(dwell * 1000) // Convert to milliseconds
    }
    sendEvent(event: "exitedGeofence", data: data)
  }

  public func proximiioEnteredPrivacyZone(_ area: ProximiioPrivacyZone) {
    sendEvent(event: "enteredPrivacyZone", data: area.toMap())
  }

  public func proximiioExitedPrivacyZone(_ area: ProximiioPrivacyZone) {
    sendEvent(event: "exitedPrivacyZone", data: area.toMap())
  }

  public func proximiioFoundiBeacon(_ beacon: ProximiioIBeacon, registered: Bool) {
    sendEvent(event: "foundIBeacon", data: beacon.toMap())
  }

  public func proximiioUpdatediBeacon(_ beacon: ProximiioIBeacon) {
    // Optional: send update event
  }

  public func proximiioLostiBeacon(_ beacon: ProximiioIBeacon) {
    sendEvent(event: "lostIBeacon", data: beacon.toMap())
  }

  public func proximiioFoundEddystone(_ beacon: ProximiioEddystoneBeacon, registered: Bool) {
    sendEvent(event: "foundEddystoneBeacon", data: beacon.toMap())
  }

  public func proximiioUpdatedEddystone(_ beacon: ProximiioEddystoneBeacon) {
    // Optional: send update event
  }

  public func proximiioLostEddystone(_ beacon: ProximiioEddystoneBeacon) {
    sendEvent(event: "lostEddystoneBeacon", data: beacon.toMap())
  }

  // MARK: - Helper Methods

  private func sendEvent(event: String, data: Any?) {
    let eventData: [String: Any?] = [
      "event": event,
      "data": data
    ]

    // Debug: Print when sending events
    print("[iOS Plugin] Sending event: \(event), has eventSink: \(eventSink != nil)")

    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(eventData)
    }
  }

  // MARK: - FlutterStreamHandler Methods

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

// MARK: - Extension for converting objects to maps

extension ProximiioLocation {
  func toMap() -> [String: Any] {
    var map: [String: Any] = [
      "lat": coordinate.latitude,
      "lng": coordinate.longitude,
      "accuracy": horizontalAccuracy
    ]

    // Add source type if available
    if !sourceType.isEmpty {
      map["sourceType"] = sourceType
    }

    return map
  }
}

extension ProximiioFloor {
  func toMap() -> [String: Any] {
    var map: [String: Any] = [
      "id": uuid,
      "name": name ?? "",
      "level": floorNumber ?? 0
    ]

    // Add place ID if available
    if let placeUUID = place()?.uuid {
      map["placeId"] = placeUUID
    }

    // Add floor plan URL if available
    if let imageURL = floorPlanImageURL {
      map["floorplan"] = imageURL
    }

    // Convert anchors to nested arrays
    if let anchorsArray = anchors as? [[Double]] {
      map["anchors"] = anchorsArray
    }

    return map
  }
}

extension ProximiioGeofence {
  func toMap() -> [String: Any] {
    var map: [String: Any] = [
      "id": uuid,
      "name": name ?? "",
      "lat": area?.coordinate.latitude ?? 0.0,
      "lng": area?.coordinate.longitude ?? 0.0,
      "radius": radius
    ]

    // Add polygon if available
    if let poly = polygon, !poly.isEmpty {
      // Try to convert polygon points to array of coordinates
      let polygonArray = poly.compactMap { point -> [Double]? in
        if let dict = point as? [String: Any],
           let lat = dict["lat"] as? Double,
           let lng = dict["lng"] as? Double {
          return [lat, lng]
        }
        return nil
      }
      if !polygonArray.isEmpty {
        map["isPolygon"] = true
        map["polygon"] = polygonArray
      } else {
        map["isPolygon"] = false
      }
    } else {
      map["isPolygon"] = false
    }

    return map
  }
}

extension ProximiioPrivacyZone {
  func toMap() -> [String: Any] {
    var map: [String: Any] = [
      "id": uuid,
      "name": name ?? "",
      "lat": area?.coordinate.latitude ?? 0.0,
      "lng": area?.coordinate.longitude ?? 0.0,
      "radius": radius
    ]

    // Add polygon if available
    if let poly = polygon, !poly.isEmpty {
      // Try to convert polygon points to array of coordinates
      let polygonArray = poly.compactMap { point -> [Double]? in
        if let dict = point as? [String: Any],
           let lat = dict["lat"] as? Double,
           let lng = dict["lng"] as? Double {
          return [lat, lng]
        }
        return nil
      }
      if !polygonArray.isEmpty {
        map["isPolygon"] = true
        map["polygon"] = polygonArray
      } else {
        map["isPolygon"] = false
      }
    } else {
      map["isPolygon"] = false
    }

    return map
  }
}

extension ProximiioIBeacon {
  func toMap() -> [String: Any] {
    return [
      "type": "ibeacon",
      "uuid": uuid.uuidString,
      "major": major,
      "minor": minor,
      "distance": distance,
      "rssi": rssi,
      "identifier": "\(uuid.uuidString)/\(major)/\(minor)"
    ]
  }
}

extension ProximiioEddystoneBeacon {
  func toMap() -> [String: Any] {
    return [
      "type": "eddystone",
      "namespace": namespace ?? "",
      "instanceId": instanceID ?? "",
      "identifier": "\(namespace ?? "")/\(instanceID ?? "")"
    ]
  }
}
