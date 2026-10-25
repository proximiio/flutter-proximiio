// Conversions between the public Dart types and the Pigeon transport types. Not exported.
import 'dart:convert';

import 'configuration.dart';
import 'events.dart';
import 'messages.g.dart';
import 'models.dart';

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
  positioningSourcePrivateSince:
      s.positioningSourcePrivateSinceMs == null ? null : _time(s.positioningSourcePrivateSinceMs!),
  isPrivate: s.isPrivate,
);
