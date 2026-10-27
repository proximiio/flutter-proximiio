import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:flutter_proximiio/src/convert.dart';
import 'package:flutter_proximiio/src/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('configuration', () {
    test('keeps unset overrides null so the native preset value stays', () {
      final msg = toMsgConfiguration(const ProximiioConfiguration(token: 't'));

      expect(msg.token, 't');
      expect(msg.preset, MsgConfigurationPreset.standard);
      expect(msg.apiBaseUrl, isNull);
      expect(msg.syncIntervalSeconds, isNull);
      expect(msg.desiredAccuracy, isNull);
      expect(msg.visitorReportingEnabled, isNull);
      expect(msg.geofenceExitDelaySeconds, isNull);
      expect(msg.fallbackApiBaseUrls, isEmpty);
      expect(msg.customIBeaconUuids, isEmpty);
      expect(msg.bleEvaluationIntervalSeconds, isNull);
      expect(msg.distanceFilter, isNull);
      expect(msg.allowsOfflineStart, isNull);
      expect(msg.android, isNull);
    });

    test('positions in privacy zones are withheld unless turned off, as in 1.x', () {
      expect(toMsgConfiguration(const ProximiioConfiguration(token: 't')).withholdsPositionsInPrivacyZones, isTrue);
      expect(
        toMsgConfiguration(
          const ProximiioConfiguration(token: 't', withholdsPositionsInPrivacyZones: false),
        ).withholdsPositionsInPrivacyZones,
        isFalse,
      );
    });

    test('converts every override, durations to seconds', () {
      final msg = toMsgConfiguration(
        ProximiioConfiguration(
          token: 't',
          preset: ConfigurationPreset.relayOnly,
          relayRunsInBackground: true,
          apiBaseUrl: Uri.parse('https://api.example.test'),
          fallbackApiBaseUrls: [Uri.parse('https://fallback.example.test')],
          syncInterval: const Duration(minutes: 2),
          desiredAccuracy: DesiredAccuracy.threeKilometers,
          allowsBackgroundLocationUpdates: true,
          visitorReportingEnabled: false,
          geofenceExitDelay: const Duration(milliseconds: 1500),
          withholdsPositionsInPrivacyZones: true,
          customIBeaconUuids: const ['F7826DA6-4FA2-4E98-8024-BC5B71E0893E'],
          pdrFusionEnabled: true,
          barometerEnabled: false,
          bleEvaluationInterval: const Duration(milliseconds: 500),
          distanceFilter: const DistanceFilter(minimumDisplacement: 0.4),
          allowsOfflineStart: false,
          android: const AndroidServiceOptions(
            notificationTitle: 'Title',
            notificationIcon: 'ic_stat',
            mode: ServiceNotificationMode.required,
          ),
        ),
      );

      expect(msg.preset, MsgConfigurationPreset.relayOnly);
      expect(msg.relayRunsInBackground, isTrue);
      expect(msg.apiBaseUrl, 'https://api.example.test');
      expect(msg.fallbackApiBaseUrls, ['https://fallback.example.test']);
      expect(msg.syncIntervalSeconds, 120);
      expect(msg.desiredAccuracy, MsgDesiredAccuracy.threeKilometers);
      expect(msg.allowsBackgroundLocationUpdates, isTrue);
      expect(msg.visitorReportingEnabled, isFalse);
      expect(msg.geofenceExitDelaySeconds, 1.5);
      expect(msg.withholdsPositionsInPrivacyZones, isTrue);
      expect(msg.customIBeaconUuids, ['F7826DA6-4FA2-4E98-8024-BC5B71E0893E']);
      expect(msg.pdrFusionEnabled, isTrue);
      expect(msg.barometerEnabled, isFalse);
      expect(msg.bleEvaluationIntervalSeconds, 0.5);
      expect(msg.distanceFilter?.minimumDisplacement, 0.4);
      expect(msg.distanceFilter?.accuracyDisplacementFactor, isNull);
      expect(msg.allowsOfflineStart, isFalse);
      expect(msg.android?.notificationTitle, 'Title');
      expect(msg.android?.notificationIcon, 'ic_stat');
      expect(msg.android?.mode, MsgServiceNotificationMode.required);
      expect(msg.android?.notificationText, isNull);
    });

    test('every public enum value has a transport counterpart', () {
      for (final preset in ConfigurationPreset.values) {
        expect(toMsgConfiguration(ProximiioConfiguration(token: 't', preset: preset)).preset.name, preset.name);
      }
      for (final accuracy in DesiredAccuracy.values) {
        expect(
          toMsgConfiguration(ProximiioConfiguration(token: 't', desiredAccuracy: accuracy)).desiredAccuracy?.name,
          accuracy.name,
        );
      }
      for (final level in ProximiioLogLevel.values) {
        expect(toMsgLogLevel(level).name, level.name);
      }
    });
  });

  group('models', () {
    final msgFloor = MsgFloor(
      id: 'f1',
      name: 'Ground',
      placeId: 'p1',
      level: 0.5,
      anchors: [MsgCoordinate(latitude: 48.1, longitude: 17.1)],
      floorPlanImageUrl: 'https://img.test/f1.png',
      metadataJson: '{"wing":"A","rooms":[1,2]}',
    );

    test('floor keeps a fractional level and decodes metadata', () {
      final floor = fromMsgFloor(msgFloor);

      expect(floor.level, 0.5);
      expect(floor.anchors, [const Coordinate(latitude: 48.1, longitude: 17.1)]);
      expect(floor.metadata, {
        'wing': 'A',
        'rooms': [1, 2],
      });
      expect(floor, fromMsgFloor(msgFloor), reason: 'value equality');
      expect(floor.hashCode, fromMsgFloor(msgFloor).hashCode);
    });

    test('broken metadata JSON becomes null instead of throwing', () {
      final place = fromMsgPlace(MsgPlace(id: 'p', metadataJson: '{not json'));
      expect(place.metadata, isNull);
    });

    test('geofence polygon, remote id and geometry issue', () {
      final geofence = fromMsgGeofence(
        MsgZone(
          id: 'g',
          radius: 0,
          polygon: [
            MsgCoordinate(latitude: 1, longitude: 2),
            MsgCoordinate(latitude: 3, longitude: 4),
            MsgCoordinate(latitude: 5, longitude: 6),
          ],
          remoteId: 'ext-1',
          geometryIssue: 'degenerateOutline',
        ),
      );

      expect(geofence.isPolygon, isTrue);
      expect(geofence.polygon!.first, const Coordinate(latitude: 1, longitude: 2));
      expect(geofence.remoteId, 'ext-1');
      expect(geofence.geometryIssue, GeometryIssue.degenerateOutline);
    });

    test('unknown geometry issue from a newer SDK is dropped, not thrown', () {
      final zone = fromMsgPrivacyZone(MsgZone(id: 'z', radius: 3, geometryIssue: 'somethingNew'));
      expect(zone.geometryIssue, isNull);
      expect(zone.isPolygon, isFalse);
    });

    test('permission status', () {
      final status = fromMsgPermissionStatus(
        MsgPermissionStatus(
          location: MsgLocationAuthorization.whenInUse,
          accuracy: MsgLocationAccuracy.reduced,
          bluetooth: MsgBluetoothAuthorization.denied,
          motion: MsgMotionAuthorization.unavailable,
        ),
      );

      expect(status.location, LocationAuthorization.whenInUse);
      expect(status.isLocationAuthorized, isTrue);
      expect(status.accuracy, LocationAccuracyAuthorization.reduced);
      expect(status.bluetooth, BluetoothAuthorization.denied);
      expect(status.motion, MotionAuthorization.unavailable);
    });
  });

  group('events', () {
    test('position timestamp is UTC milliseconds, floor carried along', () {
      final position = fromMsgPosition(
        MsgPositionUpdate(
          coordinate: MsgCoordinate(latitude: 48, longitude: 17),
          horizontalAccuracy: 2.5,
          floor: MsgFloor(id: 'f', level: 1, anchors: const []),
          source: MsgPositionSource.bleTrilateration,
          timestampMs: 1761400000123,
          background: true,
        ),
      );

      expect(position.timestamp, DateTime.utc(2025, 10, 25, 13, 46, 40, 123));
      expect(position.source, PositionSource.bleTrilateration);
      expect(position.floor?.level, 1);
      expect(position.background, isTrue);
    });

    test('geofence exit dwell time is the SDK seconds as a Duration', () {
      final event = fromMsgGeofenceEvent(
        MsgGeofenceExited(geofence: MsgZone(id: 'g', radius: 10), dwellTimeSeconds: 61.25),
      );

      expect(event, isA<GeofenceExited>());
      expect((event as GeofenceExited).dwellTime, const Duration(seconds: 61, milliseconds: 250));
    });

    test('every token status has a public counterpart', () {
      for (final status in MsgTokenStatus.values) {
        expect(fromMsgTokenStatus(status).name, status.name);
      }
      expect(TokenStatus.values.length, MsgTokenStatus.values.length);
    });

    test('every geofence event kind maps to its own class', () {
      final zone = MsgZone(id: 'z', radius: 1);
      expect(fromMsgGeofenceEvent(MsgGeofenceEntered(geofence: zone)), isA<GeofenceEntered>());
      expect(fromMsgGeofenceEvent(MsgPrivacyZoneEntered(zone: zone)), isA<PrivacyZoneEntered>());
      expect(fromMsgGeofenceEvent(MsgPrivacyZoneExited(zone: zone)), isA<PrivacyZoneExited>());
    });

    test('floor change and privacy zone state', () {
      final change = fromMsgFloorChange(
        MsgFloorChange(
          previousFloor: MsgFloor(id: 'a', level: 0, anchors: const []),
          floor: MsgFloor(id: 'b', level: 1, anchors: const []),
          direction: MsgFloorChangeDirection.up,
          confidence: 0.9,
          source: MsgFloorChangeSource.barometer,
          timestampMs: 0,
        ),
      );
      expect(change.direction, FloorChangeDirection.up);
      expect(change.floor?.id, 'b');

      final state = fromMsgPrivacyZoneState(
        MsgPrivacyZoneState(isInPrivacyZone: false, positioningSourcePrivateSinceMs: 1000, isPrivate: true),
      );
      expect(state.isPrivate, isTrue);
      expect(state.positioningSourcePrivateSince, DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
    });

    test('every transport state and source has a public counterpart', () {
      for (final state in MsgSdkState.values) {
        expect(fromMsgState(state).name, state.name);
      }
      for (final source in MsgPositionSource.values) {
        expect(PositionSource.values.byName(source.name).name, source.name);
      }
      for (final source in MsgFloorChangeSource.values) {
        expect(FloorChangeSource.values.byName(source.name).name, source.name);
      }
    });
  });
}
