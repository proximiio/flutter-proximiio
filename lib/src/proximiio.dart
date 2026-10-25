import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'beacons.dart';
import 'configuration.dart';
import 'convert.dart';
import 'errors.dart';
import 'events.dart';
import 'messages.g.dart' as msg;
import 'models.dart';
import 'tools.dart';
import 'venue.dart';
import 'wayfinding.dart';

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

  /// Venue data changed (features, amenities, style, floors, places, geofences): re-read what you show.
  Stream<VenueDataChange> get venueDataChanges;

  /// Steps of the venue data synchronisation.
  Stream<SyncEvent> get syncEvents;

  /// Beacons of the venue coming into and out of range.
  Stream<BeaconEvent> get beaconEvents;

  /// The current lifecycle state.
  Future<ProximiioState> state();

  /// Asks for location (and, with [always], background location), Bluetooth and motion as needed,
  /// and returns the resulting status. Missing usage descriptions (iOS) or manifest entries
  /// (Android) resolve as denied.
  Future<PermissionStatus> requestPermissions({bool always = false});

  /// Asks for the motion / activity-recognition permission (needed for PDR).
  Future<bool> requestMotionPermission();

  /// Validates the token with the Proximi.io API (needs a connection), loads the application and
  /// applies the stored venue data. Throws [ProximiioErrorCode.invalidToken] for a rejected token and
  /// [ProximiioErrorCode.api] when the API cannot be reached.
  Future<ProximiioApplication?> authenticate();

  /// Starts positioning. Throws [ProximiioErrorCode.notAuthenticated] before a successful
  /// [authenticate]. It does not check permissions: without location it starts but produces no positions.
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

  // ── Wayfinding ──

  /// Computes a route on the device. [toLevel] defaults to [fromLevel]. Throws
  /// [ProximiioErrorCode.noRoute] with a [NoRouteReason] when none exists.
  Future<ComputedRoute> computeRoute({
    required Coordinate from,
    required double fromLevel,
    required Coordinate to,
    double? toLevel,
    RouteOptions options = const RouteOptions(),
  });

  /// Walking time between every pair of [points] (row = from, column = to); `null` where no route exists.
  Future<List<List<Duration?>>> routeDurations(List<RoutePoint> points, {RouteOptions options = const RouteOptions()});

  /// Downloads the venue features (only when they changed), stores them and installs the route
  /// network; returns the number of routable paths. Needs a connection. Call it after [authenticate]
  /// and before [computeRoute], [routeDurations] or [enableRouteSnapping]; [start] does not load it.
  /// [features] reads the features this stores.
  Future<int> loadRouteNetwork();

  /// Installs the route network from the features stored by an earlier [loadRouteNetwork], without a
  /// request; `0` when none are stored. For offline cold starts.
  Future<int> loadCachedRouteNetwork();

  // ── Venue data ──

  /// All amenities (downloaded once, then cached).
  Future<List<ProximiioAmenity>> amenities();

  /// The GeoJSON features stored by [loadRouteNetwork] (and kept current by sync).
  Future<List<ProximiioFeature>> features();

  /// All departments.
  Future<List<ProximiioDepartment>> departments();

  /// The organisation's MapLibre style document.
  Future<Map<String, Object?>> mapStyle();

  /// All journeys of the organisation.
  Future<List<ProximiioJourney>> journeys();

  /// The journey with [id].
  Future<ProximiioJourney> journey(String id);

  // ── Offline packages ──

  /// Downloads or updates the offline package [packageId]; returns its state afterwards.
  Future<PackageState> syncOfflinePackage(String packageId, {String? place, bool allowsCellular = true});

  /// State of the offline package [packageId].
  Future<PackageState> offlinePackageState(String packageId);

  /// Installs the package [packageId] from unpacked package files in [directory] (for example
  /// extracted from the app's assets on first launch).
  Future<void> installOfflineSeed(String packageId, String directory);

  /// Deletes the package [packageId] from the device.
  Future<void> removeOfflinePackage(String packageId);

  /// Bytes the package [packageId] uses on disk.
  Future<int> offlinePackageDiskUsage(String packageId);

  // ── Simulation ──

  /// Emits one simulated position.
  Future<PositionUpdate?> simulatePosition(Coordinate coordinate, {int level = 0, double accuracy = 5});

  /// Walks [route], emitting positions as if the device moved. Needs a running SDK.
  Future<void> startSimulation(SimulatedRoute route);

  /// Pauses the simulation.
  Future<void> pauseSimulation();

  /// Resumes the simulation.
  Future<void> resumeSimulation();

  /// Stops the simulation.
  Future<void> stopSimulation();

  /// Continues the simulation from the waypoint at [index].
  Future<void> jumpToWaypoint(int index);

  /// State of the simulation.
  Future<SimulationState> simulationState();

  // ── Positioning inputs ──

  /// Sets a position from an outside source (a QR code, a relay, the app). [floorId] must be a floor
  /// from [floors]; an unknown id means no floor.
  Future<PositionUpdate?> setCustomPosition(Coordinate coordinate, {double accuracy = 5, String? floorId});

  /// Sets the floor; `null` clears it.
  Future<FloorChangeEvent?> setFloor(String? floorId);

  /// Snaps positions to the route network within [thresholdMeters] (SDK default 5 m).
  Future<void> enableRouteSnapping({double? thresholdMeters});

  /// Stops snapping positions to the route network.
  Future<void> disableRouteSnapping();

  /// Turns on pedestrian dead reckoning. Needs the motion permission ([requestMotionPermission]).
  Future<void> enablePdr();

  /// Turns off pedestrian dead reckoning.
  Future<void> disablePdr();

  /// Marks positions from the positioning source (a relay) as private since [since]; `null` clears it.
  Future<void> setPositioningSourcePrivate(DateTime? since);

  // ── Diagnostics ──

  /// A snapshot of what the SDK is doing.
  Future<ProximiioDiagnostics> diagnostics();

  /// Starts recording diagnostics to disk, for a support report.
  Future<void> startDiagnosticsRecording();

  /// Stops recording diagnostics.
  Future<void> stopDiagnosticsRecording();

  /// Packs the recording into a zip (secrets removed) and returns its path, to share with support.
  Future<String> prepareDiagnosticsReport();

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

  /// See [Proximiio.venueDataChanges].
  Stream<msg.MsgVenueDataChange> venueDataChanges() => msg.venueDataChanges();

  /// See [Proximiio.syncEvents].
  Stream<msg.MsgSyncEvent> syncEvents() => msg.syncEvents();

  /// See [Proximiio.beaconEvents].
  Stream<msg.MsgBeaconEvent> beaconEvents() => msg.beaconEvents();
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

  @override
  late final Stream<VenueDataChange> venueDataChanges = _bridge(_events.venueDataChanges(), fromMsgVenueDataChange);

  @override
  late final Stream<SyncEvent> syncEvents = _bridge(_events.syncEvents(), fromMsgSyncEvent);

  @override
  late final Stream<BeaconEvent> beaconEvents = _bridge(_events.beaconEvents(), fromMsgBeaconEvent);

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
  Future<ComputedRoute> computeRoute({
    required Coordinate from,
    required double fromLevel,
    required Coordinate to,
    double? toLevel,
    RouteOptions options = const RouteOptions(),
  }) => guarded(
    () async => fromMsgRoute(
      await _api.computeRoute(
        toMsgCoordinate(from),
        fromLevel,
        toMsgCoordinate(to),
        toLevel ?? fromLevel,
        toMsgRouteOptions(options),
      ),
    ),
  );

  @override
  Future<List<List<Duration?>>> routeDurations(
    List<RoutePoint> points, {
    RouteOptions options = const RouteOptions(),
  }) => guarded(
    () async =>
        fromMsgDurations(await _api.routeDurations(points.map(toMsgRoutePoint).toList(), toMsgRouteOptions(options))),
  );

  @override
  Future<int> loadRouteNetwork() => guarded(_api.loadRouteNetwork);

  @override
  Future<int> loadCachedRouteNetwork() => guarded(_api.loadCachedRouteNetwork);

  @override
  Future<List<ProximiioAmenity>> amenities() =>
      guarded(() async => (await _api.amenities()).map(fromMsgAmenity).toList());

  @override
  Future<List<ProximiioFeature>> features() =>
      guarded(() async => (await _api.features()).map(fromMsgFeature).toList());

  @override
  Future<List<ProximiioDepartment>> departments() =>
      guarded(() async => (await _api.departments()).map(fromMsgDepartment).toList());

  @override
  Future<Map<String, Object?>> mapStyle() => guarded(() async {
    final decoded = jsonDecode(await _api.mapStyle());
    return decoded is Map ? decoded.cast<String, Object?>() : <String, Object?>{};
  });

  @override
  Future<List<ProximiioJourney>> journeys() =>
      guarded(() async => (await _api.journeys()).map(fromMsgJourney).toList());

  @override
  Future<ProximiioJourney> journey(String id) => guarded(() async => fromMsgJourney(await _api.journey(id)));

  @override
  Future<PackageState> syncOfflinePackage(String packageId, {String? place, bool allowsCellular = true}) =>
      guarded(() async => fromMsgPackageState(await _api.syncOfflinePackage(packageId, place, allowsCellular)));

  @override
  Future<PackageState> offlinePackageState(String packageId) =>
      guarded(() async => fromMsgPackageState(await _api.offlinePackageState(packageId)));

  @override
  Future<void> installOfflineSeed(String packageId, String directory) =>
      guarded(() => _api.installOfflineSeed(packageId, directory));

  @override
  Future<void> removeOfflinePackage(String packageId) => guarded(() => _api.removeOfflinePackage(packageId));

  @override
  Future<int> offlinePackageDiskUsage(String packageId) => guarded(() => _api.offlinePackageDiskUsage(packageId));

  @override
  Future<PositionUpdate?> simulatePosition(Coordinate coordinate, {int level = 0, double accuracy = 5}) =>
      guarded(() async {
        final position = await _api.simulatePosition(toMsgCoordinate(coordinate), level, accuracy);
        return position == null ? null : fromMsgPosition(position);
      });

  @override
  Future<void> startSimulation(SimulatedRoute route) => guarded(() => _api.startSimulation(toMsgSimulatedRoute(route)));

  @override
  Future<void> pauseSimulation() => guarded(_api.pauseSimulation);

  @override
  Future<void> resumeSimulation() => guarded(_api.resumeSimulation);

  @override
  Future<void> stopSimulation() => guarded(_api.stopSimulation);

  @override
  Future<void> jumpToWaypoint(int index) => guarded(() => _api.jumpToWaypoint(index));

  @override
  Future<SimulationState> simulationState() =>
      guarded(() async => SimulationState.values.byName((await _api.simulationState()).name));

  @override
  Future<PositionUpdate?> setCustomPosition(Coordinate coordinate, {double accuracy = 5, String? floorId}) =>
      guarded(() async {
        final position = await _api.setCustomPosition(toMsgCoordinate(coordinate), accuracy, floorId);
        return position == null ? null : fromMsgPosition(position);
      });

  @override
  Future<FloorChangeEvent?> setFloor(String? floorId) => guarded(() async {
    final change = await _api.setFloor(floorId);
    return change == null ? null : fromMsgFloorChange(change);
  });

  @override
  Future<void> enableRouteSnapping({double? thresholdMeters}) =>
      guarded(() => _api.enableRouteSnapping(thresholdMeters));

  @override
  Future<void> disableRouteSnapping() => guarded(_api.disableRouteSnapping);

  @override
  Future<void> enablePdr() => guarded(_api.enablePdr);

  @override
  Future<void> disablePdr() => guarded(_api.disablePdr);

  @override
  Future<void> setPositioningSourcePrivate(DateTime? since) =>
      guarded(() => _api.setPositioningSourcePrivate(since?.millisecondsSinceEpoch));

  @override
  Future<ProximiioDiagnostics> diagnostics() => guarded(() async => fromMsgDiagnostics(await _api.diagnostics()));

  @override
  Future<void> startDiagnosticsRecording() => guarded(_api.startDiagnosticsRecording);

  @override
  Future<void> stopDiagnosticsRecording() => guarded(_api.stopDiagnosticsRecording);

  @override
  Future<String> prepareDiagnosticsReport() => guarded(_api.prepareDiagnosticsReport);

  @override
  ProximiioAndroid get android => this;

  @override
  Future<bool> updateServiceNotification(AndroidServiceOptions options) =>
      guarded(() => _api.updateServiceNotification(toMsgServiceOptions(options)));

  @override
  Future<void> resetServiceNotification() => guarded(_api.resetServiceNotification);
}
