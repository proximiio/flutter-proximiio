import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'configuration.dart';
import 'convert.dart';
import 'errors.dart';
import 'events.dart';
import 'messages.g.dart' as msg;
import 'models.dart';

/// The Proximi.io SDK: indoor positioning, floors, geofences, privacy zones and venue data.
///
/// There is one SDK instance per app process. [create] makes it; calling [create] again stops and
/// replaces it. The same instance drives `flutter_proximiio_map`.
///
/// ```dart
/// final sdk = await Proximiio.create(const ProximiioConfiguration(token: token));
/// await sdk.requestPermissions();
/// await sdk.authenticate();
/// await sdk.start();
/// sdk.positions.listen((position) => print(position));
/// ```
///
/// Streams can be listened to at any time. They deliver events while the SDK runs and stay open
/// across [stop] and [start].
///
/// Every method throws [ProximiioException] on failure.
abstract interface class Proximiio {
  /// Creates (or replaces) the process-wide SDK instance.
  static Future<Proximiio> create(ProximiioConfiguration configuration) => BridgedProximiio.create(configuration);

  /// Sets the minimum level of the native SDK's log output (process-wide).
  static Future<void> setLogLevel(ProximiioLogLevel level) =>
      guarded(() => msg.ProximiioHostApi().setLogLevel(toMsgLogLevel(level)));

  /// The state after each lifecycle call ([authenticate], [start], [stop], [signOut]).
  Stream<ProximiioState> get stateChanges;

  /// Permission changes, including those made in the system settings.
  Stream<PermissionStatus> get permissionUpdates;

  /// Device positions.
  Stream<PositionUpdate> get positions;

  /// Floor changes.
  Stream<FloorChangeEvent> get floorChanges;

  /// Geofence and privacy-zone entries and exits. [stop] reports an exit for every geofence the
  /// device is in.
  Stream<GeofenceEvent> get geofenceEvents;

  /// Whether positioning is private (inside a privacy zone, or private at the source).
  Stream<PrivacyZoneState> get privacyZoneStateChanges;

  /// The current lifecycle state.
  Future<ProximiioState> state();

  /// Asks for location (and, with [always], background location), Bluetooth and motion as needed,
  /// and returns the resulting status. Missing usage descriptions (iOS) or manifest entries
  /// (Android) resolve as denied.
  Future<PermissionStatus> requestPermissions({bool always = false});

  /// Asks for the motion / activity-recognition permission (needed for PDR).
  Future<bool> requestMotionPermission();

  /// Checks the token and loads the application. Works offline with a token accepted before.
  Future<ProximiioApplication?> authenticate();

  /// Starts positioning. Needs [authenticate] and the location permission.
  Future<void> start();

  /// Stops positioning.
  Future<void> stop();

  /// Stops, forgets the token and clears the stored venue data.
  Future<void> signOut();

  /// Synchronises venue data now; returns the number of changed records.
  Future<int> sync();

  /// The application of the token, when authenticated.
  Future<ProximiioApplication?> application();

  /// All places.
  Future<List<ProximiioPlace>> places();

  /// All floors.
  Future<List<ProximiioFloor>> floors();

  /// All geofences.
  Future<List<ProximiioGeofence>> geofences();

  /// All privacy zones.
  Future<List<ProximiioPrivacyZone>> privacyZones();

  /// The place with [id].
  Future<ProximiioPlace?> place(String id);

  /// The floor with [id].
  Future<ProximiioFloor?> floor(String id);

  /// The floor the device is on.
  Future<ProximiioFloor?> currentFloor();

  /// The most recent position.
  Future<PositionUpdate?> lastPosition();

  /// Ids of the geofences the device is in.
  Future<Set<String>> enteredGeofenceIds();

  /// Whether the device is in a privacy zone.
  Future<bool> isInPrivacyZone();

  /// The anonymous visitor id used for analytics.
  Future<String> visitorId();

  /// Replaces the visitor id with a new random one and returns it.
  Future<String> resetVisitorId();

  /// Whether the visitor agreed to analytics reporting.
  Future<bool> visitorReportingConsent();

  /// Records the visitor's analytics consent. `false` stops all reporting.
  Future<void> setVisitorReportingConsent(bool granted);

  /// Android-only calls. They throw [ProximiioErrorCode.unsupported] on iOS.
  ProximiioAndroid get android;
}

/// Android-only parts of the SDK.
abstract interface class ProximiioAndroid {
  /// Replaces the foreground-service notification. `false` when the service is not running.
  Future<bool> updateServiceNotification(AndroidServiceOptions options);

  /// Restores the notification from the configuration.
  Future<void> resetServiceNotification();
}

/// The streams of the bridge, separate so tests can replace them.
@visibleForTesting
class BridgeEvents {
  /// The bridge's event channels.
  const BridgeEvents();

  /// See [Proximiio.stateChanges].
  Stream<msg.MsgStateChange> stateChanges() => msg.stateChanges();

  /// See [Proximiio.permissionUpdates].
  Stream<msg.MsgPermissionStatus> permissionUpdates() => msg.permissionUpdates();

  /// See [Proximiio.positions].
  Stream<msg.MsgPositionUpdate> positions() => msg.positions();

  /// See [Proximiio.floorChanges].
  Stream<msg.MsgFloorChange> floorChanges() => msg.floorChanges();

  /// See [Proximiio.geofenceEvents].
  Stream<msg.MsgGeofenceEvent> geofenceEvents() => msg.geofenceEvents();

  /// See [Proximiio.privacyZoneStateChanges].
  Stream<msg.MsgPrivacyZoneState> privacyZoneStateChanges() => msg.privacyZoneStateChanges();
}

/// [Proximiio] over the Pigeon bridge.
@visibleForTesting
class BridgedProximiio implements Proximiio, ProximiioAndroid {
  /// Wraps an already configured native instance.
  BridgedProximiio(this._api, [this._events = const BridgeEvents()]);

  /// Configures the native instance and wraps it.
  static Future<BridgedProximiio> create(
    ProximiioConfiguration configuration, {
    msg.ProximiioHostApi? api,
    BridgeEvents events = const BridgeEvents(),
  }) async {
    final hostApi = api ?? msg.ProximiioHostApi();
    await guarded(() => hostApi.configure(toMsgConfiguration(configuration)));
    return BridgedProximiio(hostApi, events);
  }

  final msg.ProximiioHostApi _api;
  final BridgeEvents _events;

  // Each event channel has one native handler, so each is listened to through one shared
  // broadcast stream; a second `receiveBroadcastStream` would take over the channel.
  @override
  late final Stream<ProximiioState> stateChanges = _bridge(_events.stateChanges(), (m) => fromMsgState(m.state));

  @override
  late final Stream<PermissionStatus> permissionUpdates = _bridge(_events.permissionUpdates(), fromMsgPermissionStatus);

  @override
  late final Stream<PositionUpdate> positions = _bridge(_events.positions(), fromMsgPosition);

  @override
  late final Stream<FloorChangeEvent> floorChanges = _bridge(_events.floorChanges(), fromMsgFloorChange);

  @override
  late final Stream<GeofenceEvent> geofenceEvents = _bridge(_events.geofenceEvents(), fromMsgGeofenceEvent);

  @override
  late final Stream<PrivacyZoneState> privacyZoneStateChanges = _bridge(
    _events.privacyZoneStateChanges(),
    fromMsgPrivacyZoneState,
  );

  /// Both `map` and `fromHandlers` keep the channel's broadcast stream a broadcast stream.
  static Stream<T> _bridge<M, T>(Stream<M> source, T Function(M) convert) => source
      .map(convert)
      .transform(
        StreamTransformer<T, T>.fromHandlers(
          handleError:
              (error, stackTrace, sink) => sink.addError(
                error is PlatformException ? ProximiioException.fromPlatform(error) : error,
                stackTrace,
              ),
        ),
      );

  @override
  Future<ProximiioState> state() => guarded(() async => fromMsgState(await _api.state()));

  @override
  Future<PermissionStatus> requestPermissions({bool always = false}) =>
      guarded(() async => fromMsgPermissionStatus(await _api.requestPermissions(always)));

  @override
  Future<bool> requestMotionPermission() => guarded(_api.requestMotionPermission);

  @override
  Future<ProximiioApplication?> authenticate() => guarded(() async {
    final application = await _api.authenticate();
    return application == null ? null : fromMsgApplication(application);
  });

  @override
  Future<void> start() => guarded(_api.start);

  @override
  Future<void> stop() => guarded(_api.stop);

  @override
  Future<void> signOut() => guarded(_api.signOut);

  @override
  Future<int> sync() => guarded(_api.sync);

  @override
  Future<ProximiioApplication?> application() => guarded(() async {
    final application = await _api.application();
    return application == null ? null : fromMsgApplication(application);
  });

  @override
  Future<List<ProximiioPlace>> places() => guarded(() async => (await _api.places()).map(fromMsgPlace).toList());

  @override
  Future<List<ProximiioFloor>> floors() => guarded(() async => (await _api.floors()).map(fromMsgFloor).toList());

  @override
  Future<List<ProximiioGeofence>> geofences() =>
      guarded(() async => (await _api.geofences()).map(fromMsgGeofence).toList());

  @override
  Future<List<ProximiioPrivacyZone>> privacyZones() =>
      guarded(() async => (await _api.privacyZones()).map(fromMsgPrivacyZone).toList());

  @override
  Future<ProximiioPlace?> place(String id) => guarded(() async {
    final place = await _api.place(id);
    return place == null ? null : fromMsgPlace(place);
  });

  @override
  Future<ProximiioFloor?> floor(String id) => guarded(() async {
    final floor = await _api.floor(id);
    return floor == null ? null : fromMsgFloor(floor);
  });

  @override
  Future<ProximiioFloor?> currentFloor() => guarded(() async {
    final floor = await _api.currentFloor();
    return floor == null ? null : fromMsgFloor(floor);
  });

  @override
  Future<PositionUpdate?> lastPosition() => guarded(() async {
    final position = await _api.lastPosition();
    return position == null ? null : fromMsgPosition(position);
  });

  @override
  Future<Set<String>> enteredGeofenceIds() => guarded(() async => (await _api.enteredGeofenceIds()).toSet());

  @override
  Future<bool> isInPrivacyZone() => guarded(_api.isInPrivacyZone);

  @override
  Future<String> visitorId() => guarded(_api.visitorId);

  @override
  Future<String> resetVisitorId() => guarded(_api.resetVisitorId);

  @override
  Future<bool> visitorReportingConsent() => guarded(_api.visitorReportingConsent);

  @override
  Future<void> setVisitorReportingConsent(bool granted) => guarded(() => _api.setVisitorReportingConsent(granted));

  @override
  ProximiioAndroid get android => this;

  @override
  Future<bool> updateServiceNotification(AndroidServiceOptions options) =>
      guarded(() => _api.updateServiceNotification(toMsgServiceOptions(options)));

  @override
  Future<void> resetServiceNotification() => guarded(_api.resetServiceNotification);
}
