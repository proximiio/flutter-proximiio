// Conversions between the public Dart types and the Pigeon transport types. Not exported.
import 'dart:convert';

import 'beacons.dart';
import 'configuration.dart';
import 'events.dart';
import 'messages.g.dart';
import 'models.dart';
import 'tools.dart';
import 'venue.dart';
import 'wayfinding.dart';

/// Configuration → transport.
MsgConfiguration toMsgConfiguration(ProximiioConfiguration c) => MsgConfiguration(
  token: c.token,
  preset: MsgConfigurationPreset.values.byName(c.preset.name),
  relayRunsInBackground: c.relayRunsInBackground,
  apiBaseUrl: c.apiBaseUrl?.toString(),
  fallbackApiBaseUrls: [for (final url in c.fallbackApiBaseUrls) url.toString()],
  syncIntervalSeconds: _seconds(c.syncInterval),
  desiredAccuracy: c.desiredAccuracy == null ? null : MsgDesiredAccuracy.values.byName(c.desiredAccuracy!.name),
  allowsBackgroundLocationUpdates: c.allowsBackgroundLocationUpdates,
  visitorReportingEnabled: c.visitorReportingEnabled,
  geofenceExitDelaySeconds: _seconds(c.geofenceExitDelay),
  withholdsPositionsInPrivacyZones: c.withholdsPositionsInPrivacyZones,
  customIBeaconUuids: c.customIBeaconUuids,
  pdrFusionEnabled: c.pdrFusionEnabled,
  barometerEnabled: c.barometerEnabled,
  bleEvaluationIntervalSeconds: _seconds(c.bleEvaluationInterval),
  distanceFilter: c.distanceFilter == null
      ? null
      : MsgDistanceFilter(
          minimumDisplacement: c.distanceFilter!.minimumDisplacement,
          accuracyDisplacementFactor: c.distanceFilter!.accuracyDisplacementFactor,
        ),
  allowsOfflineStart: c.allowsOfflineStart,
  android: c.android == null ? null : toMsgServiceOptions(c.android!),
);

/// Android service options → transport.
MsgAndroidServiceOptions toMsgServiceOptions(AndroidServiceOptions o) => MsgAndroidServiceOptions(
  notificationTitle: o.notificationTitle,
  notificationText: o.notificationText,
  notificationIcon: o.notificationIcon,
  channelName: o.channelName,
  channelDescription: o.channelDescription,
  mode: o.mode == null ? null : MsgServiceNotificationMode.values.byName(o.mode!.name),
  holdsWakeLock: o.holdsWakeLock,
);

/// Log level → transport.
MsgLogLevel toMsgLogLevel(ProximiioLogLevel level) => MsgLogLevel.values.byName(level.name);

double? _seconds(Duration? d) => d == null ? null : d.inMicroseconds / Duration.microsecondsPerSecond;

Duration _duration(double seconds) => Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

DateTime _time(int millis) => DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

Object? _metadata(String? json) {
  if (json == null) return null;
  try {
    return jsonDecode(json);
  } on FormatException {
    return null;
  }
}

/// Transport → [Coordinate].
Coordinate fromMsgCoordinate(MsgCoordinate c) => Coordinate(latitude: c.latitude, longitude: c.longitude);

/// Transport → [ProximiioApplication].
ProximiioApplication fromMsgApplication(MsgApplication a) => ProximiioApplication(id: a.id, name: a.name);

/// Transport → [ProximiioPlace].
ProximiioPlace fromMsgPlace(MsgPlace p) => ProximiioPlace(
  id: p.id,
  name: p.name,
  address: p.address,
  tags: p.tags,
  location: p.location == null ? null : fromMsgCoordinate(p.location!),
  metadata: _metadata(p.metadataJson),
);

/// Transport → [ProximiioFloor].
ProximiioFloor fromMsgFloor(MsgFloor f) => ProximiioFloor(
  id: f.id,
  name: f.name,
  placeId: f.placeId,
  floorId: f.floorId,
  level: f.level,
  anchors: [for (final a in f.anchors) fromMsgCoordinate(a)],
  floorPlanImageUrl: f.floorPlanImageUrl,
  metadata: _metadata(f.metadataJson),
);

GeometryIssue? _geometryIssue(String? value) =>
    value == null ? null : GeometryIssue.values.where((issue) => issue.name == value).firstOrNull;

List<Coordinate>? _outline(List<MsgCoordinate>? polygon) =>
    polygon == null ? null : [for (final p in polygon) fromMsgCoordinate(p)];

/// Transport → [ProximiioGeofence].
ProximiioGeofence fromMsgGeofence(MsgZone z) => ProximiioGeofence(
  id: z.id,
  name: z.name,
  type: z.type,
  area: z.area == null ? null : fromMsgCoordinate(z.area!),
  radius: z.radius,
  polygon: _outline(z.polygon),
  address: z.address,
  placeId: z.placeId,
  departmentId: z.departmentId,
  floorId: z.floorId,
  remoteId: z.remoteId,
  metadata: _metadata(z.metadataJson),
  geometryIssue: _geometryIssue(z.geometryIssue),
);

/// Transport → [ProximiioPrivacyZone].
ProximiioPrivacyZone fromMsgPrivacyZone(MsgZone z) => ProximiioPrivacyZone(
  id: z.id,
  name: z.name,
  type: z.type,
  area: z.area == null ? null : fromMsgCoordinate(z.area!),
  radius: z.radius,
  polygon: _outline(z.polygon),
  address: z.address,
  placeId: z.placeId,
  departmentId: z.departmentId,
  floorId: z.floorId,
  metadata: _metadata(z.metadataJson),
  geometryIssue: _geometryIssue(z.geometryIssue),
);

/// Transport → [PermissionStatus].
PermissionStatus fromMsgPermissionStatus(MsgPermissionStatus s) => PermissionStatus(
  location: LocationAuthorization.values.byName(s.location.name),
  accuracy: LocationAccuracyAuthorization.values.byName(s.accuracy.name),
  bluetooth: BluetoothAuthorization.values.byName(s.bluetooth.name),
  motion: MotionAuthorization.values.byName(s.motion.name),
);

/// Transport → [ProximiioState].
ProximiioState fromMsgState(MsgSdkState s) => ProximiioState.values.byName(s.name);

/// Transport → [TokenStatus].
TokenStatus fromMsgTokenStatus(MsgTokenStatus s) => TokenStatus.values.byName(s.name);

/// Transport → [PositionUpdate].
PositionUpdate fromMsgPosition(MsgPositionUpdate p) => PositionUpdate(
  coordinate: fromMsgCoordinate(p.coordinate),
  horizontalAccuracy: p.horizontalAccuracy,
  floor: p.floor == null ? null : fromMsgFloor(p.floor!),
  source: PositionSource.values.byName(p.source.name),
  timestamp: _time(p.timestampMs),
  background: p.background,
);

/// Transport → [FloorChangeEvent].
FloorChangeEvent fromMsgFloorChange(MsgFloorChange e) => FloorChangeEvent(
  previousFloor: e.previousFloor == null ? null : fromMsgFloor(e.previousFloor!),
  floor: e.floor == null ? null : fromMsgFloor(e.floor!),
  direction: FloorChangeDirection.values.byName(e.direction.name),
  confidence: e.confidence,
  source: FloorChangeSource.values.byName(e.source.name),
  timestamp: _time(e.timestampMs),
);

/// Transport → [PdrUpdate].
PdrUpdate fromMsgPdrUpdate(MsgPdrUpdate u) => PdrUpdate(
  northMeters: u.northMeters,
  eastMeters: u.eastMeters,
  distanceMeters: u.distanceMeters,
  headingDegrees: u.headingDegrees,
  isMoving: u.isMoving,
  placement: DevicePlacement.values.byName(u.placement.name),
  timestamp: _duration(u.timestampSeconds),
);

/// Transport → [GeofenceEvent].
GeofenceEvent fromMsgGeofenceEvent(MsgGeofenceEvent e) => switch (e) {
  MsgGeofenceEntered(:final geofence) => GeofenceEntered(fromMsgGeofence(geofence)),
  MsgGeofenceExited(:final geofence, :final dwellTimeSeconds) => GeofenceExited(
    fromMsgGeofence(geofence),
    dwellTime: _duration(dwellTimeSeconds),
  ),
  MsgPrivacyZoneEntered(:final zone) => PrivacyZoneEntered(fromMsgPrivacyZone(zone)),
  MsgPrivacyZoneExited(:final zone) => PrivacyZoneExited(fromMsgPrivacyZone(zone)),
};

/// Transport → [PrivacyZoneState].
PrivacyZoneState fromMsgPrivacyZoneState(MsgPrivacyZoneState s) => PrivacyZoneState(
  isInPrivacyZone: s.isInPrivacyZone,
  positioningSourcePrivateSince: s.positioningSourcePrivateSinceMs == null
      ? null
      : _time(s.positioningSourcePrivateSinceMs!),
  isPrivate: s.isPrivate,
);

// ── Wayfinding ──

/// Coordinate → transport.
MsgCoordinate toMsgCoordinate(Coordinate c) => MsgCoordinate(latitude: c.latitude, longitude: c.longitude);

/// Route options → transport.
MsgRouteOptions toMsgRouteOptions(RouteOptions o) => MsgRouteOptions(
  profile: MsgRouteProfile.values.byName(o.profile.name),
  avoid: [for (final a in o.avoid) MsgRouteAvoidance.values.byName(a.name)],
);

/// Route point → transport.
MsgRoutePoint toMsgRoutePoint(RoutePoint p) => MsgRoutePoint(coordinate: toMsgCoordinate(p.coordinate), level: p.level);

LevelChange _levelChange(MsgLevelChange c) => LevelChange(
  featureType: c.featureType,
  fromLevel: c.fromLevel,
  toLevel: c.toLevel,
  coordinate: fromMsgCoordinate(c.coordinate),
);

/// Transport → [ComputedRoute].
ComputedRoute fromMsgRoute(MsgComputedRoute r) => ComputedRoute(
  coordinates: [for (final c in r.coordinates) fromMsgCoordinate(c)],
  distanceMeters: r.distanceMeters,
  segments: [
    for (final s in r.segments)
      RouteSegment(start: fromMsgCoordinate(s.start), end: fromMsgCoordinate(s.end), distanceMeters: s.distanceMeters),
  ],
  level: r.level,
  levelChanges: [for (final c in r.levelChanges) _levelChange(c)],
  instructions: [
    for (final i in r.instructions)
      RouteInstruction(
        kind: RouteInstructionKind.values.byName(i.kind.name),
        coordinate: fromMsgCoordinate(i.coordinate),
        distanceMeters: i.distanceMeters,
        level: i.level,
        duration: _duration(i.durationSeconds),
        levelChange: i.levelChange == null ? null : _levelChange(i.levelChange!),
      ),
  ],
  duration: _duration(r.durationSeconds),
);

/// Transport → duration matrix.
List<List<Duration?>> fromMsgDurations(List<MsgDurationRow> rows) => [
  for (final row in rows) [for (final s in row.seconds) s == null ? null : _duration(s)],
];

// ── Venue data ──

Map<String, Object?>? _object(String? json) {
  final value = _metadata(json);
  return value is Map ? value.cast<String, Object?>() : null;
}

/// Transport → [ProximiioAmenity].
ProximiioAmenity fromMsgAmenity(MsgAmenity a) => ProximiioAmenity(
  id: a.id,
  title: a.title,
  category: a.category,
  icon: a.icon,
  details: a.details,
  metadata: _metadata(a.metadataJson),
  titleTranslations: a.titleTranslations,
);

/// Transport → [ProximiioFeature].
ProximiioFeature fromMsgFeature(MsgFeature f) => ProximiioFeature(
  id: f.id,
  type: f.type,
  geometry: _object(f.geometryJson),
  properties: _object(f.propertiesJson),
  level: f.level,
  featureClass: f.featureClass,
  propertyType: f.propertyType,
  isLevelChanger: f.isLevelChanger,
  titleTranslations: f.titleTranslations,
);

/// Transport → [ProximiioDepartment].
ProximiioDepartment fromMsgDepartment(MsgDepartment d) => ProximiioDepartment(
  id: d.id,
  name: d.name,
  placeId: d.placeId,
  floorId: d.floorId,
  tags: d.tags,
  metadata: _metadata(d.metadataJson),
);

Duration? _optionalDuration(double? seconds) => seconds == null ? null : _duration(seconds);

/// Transport → [ProximiioJourney].
ProximiioJourney fromMsgJourney(MsgJourney j) => ProximiioJourney(
  id: j.id,
  organizationId: j.organizationId,
  name: j.name,
  placeId: j.placeId,
  speed: j.speed,
  displayName: j.displayName,
  waypoints: [
    for (final w in j.waypoints)
      JourneyWaypoint(
        latitude: w.latitude,
        longitude: w.longitude,
        level: w.level,
        floorId: w.floorId,
        label: w.label,
        dwell: _optionalDuration(w.dwellSeconds),
        speed: w.speed,
        transition: _optionalDuration(w.transitionSeconds),
      ),
  ],
);

/// Transport → [VenueDataChange].
VenueDataChange fromMsgVenueDataChange(MsgVenueDataChange c) =>
    VenueDataChange({for (final k in c.kinds) VenueDataKind(k)});

/// Transport → [SyncEvent].
SyncEvent fromMsgSyncEvent(MsgSyncEvent e) => switch (e) {
  MsgSyncUpdated(:final entity, :final id) => SyncUpdated(entity: entity, id: id),
  MsgSyncDeleted(:final entity, :final id) => SyncDeleted(entity: entity, id: id),
  MsgSyncCompleted(:final applied) => SyncCompleted(applied: applied),
  MsgSyncFailed(:final reason) => SyncFailed(reason: reason),
  MsgStoreRecreated(:final reason) => StoreRecreated(reason: reason),
};

// ── Beacons ──

/// Transport → [BeaconIdentifier].
BeaconIdentifier fromMsgBeaconIdentifier(MsgBeaconIdentifier i) => switch (i.kind) {
  MsgBeaconKind.iBeacon => IBeaconIdentifier(uuid: i.uuid ?? '', major: i.major ?? 0, minor: i.minor ?? 0),
  MsgBeaconKind.eddystone => EddystoneIdentifier(namespace: i.namespace ?? '', instance: i.instance ?? ''),
  MsgBeaconKind.uwbAccessory => UwbAccessoryIdentifier(name: i.name ?? ''),
};

BeaconObservation _observation(MsgBeaconObservation o) => BeaconObservation(
  identifier: fromMsgBeaconIdentifier(o.identifier),
  rssi: o.rssi,
  txPower: o.txPower,
  timestamp: _time(o.timestampMs),
  calibratedDistance: o.calibratedDistance,
);

/// Transport → [BeaconEvent].
BeaconEvent fromMsgBeaconEvent(MsgBeaconEvent e) => switch (e) {
  MsgBeaconFound(:final observation) => BeaconFound(_observation(observation)),
  MsgBeaconUpdated(:final observation) => BeaconUpdated(_observation(observation)),
  MsgBeaconLost(:final identifier) => BeaconLost(fromMsgBeaconIdentifier(identifier)),
  MsgBeaconTelemetryReceived(:final identifier, :final telemetry) => BeaconTelemetryReceived(
    fromMsgBeaconIdentifier(identifier),
    BeaconTelemetry(
      batteryMillivolts: telemetry.batteryMillivolts,
      temperatureCelsius: telemetry.temperatureCelsius,
      advertisementCount: telemetry.advertisementCount,
      uptime: _duration(telemetry.uptimeSeconds),
      receivedAt: _time(telemetry.receivedAtMs),
    ),
  ),
};

// ── Offline, simulation, diagnostics ──

/// Transport → [PackageState].
PackageState fromMsgPackageState(MsgPackageState s) => switch (s.kind) {
  MsgPackageStateKind.missing => const PackageMissing(),
  MsgPackageStateKind.downloading => PackageDownloading(s.progress ?? 0),
  MsgPackageStateKind.ready => PackageReady(s.version ?? 0),
  MsgPackageStateKind.stale => const PackageStale(),
  MsgPackageStateKind.verifying => const PackageVerifying(),
  MsgPackageStateKind.failed => const PackageFailed(),
};

/// Simulated route → transport.
MsgSimulatedRoute toMsgSimulatedRoute(SimulatedRoute r) => MsgSimulatedRoute(
  waypoints: [
    for (final w in r.waypoints) MsgSimulatedWaypoint(coordinate: toMsgCoordinate(w.coordinate), level: w.level),
  ],
  speed: r.speed,
  updateIntervalSeconds: _seconds(r.updateInterval)!,
  loops: r.loops,
  accuracy: r.accuracy,
);

/// Transport → [ProximiioDiagnostics].
ProximiioDiagnostics fromMsgDiagnostics(MsgDiagnostics d) => ProximiioDiagnostics(
  state: fromMsgState(d.state),
  isStarted: d.isStarted,
  isAuthenticated: d.isAuthenticated,
  permissions: d.permissions == null ? null : fromMsgPermissionStatus(d.permissions!),
  visibleBeaconCount: d.visibleBeaconCount,
  registeredBeaconCount: d.registeredBeaconCount,
  lastPositionAge: _optionalDuration(d.lastPositionAgeSeconds),
  lastPositionSource: d.lastPositionSource == null ? null : PositionSource.values.byName(d.lastPositionSource!.name),
  pdrEnabled: d.pdrEnabled,
  pdrRunning: d.pdrRunning,
  visitorReportingEnabled: d.visitorReportingEnabled,
  noPositionReason: d.noPositionReason,
  summary: d.summary,
  generatedAt: _time(d.generatedAtMs),
);
