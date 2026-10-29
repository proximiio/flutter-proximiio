import 'package:flutter/services.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:flutter_proximiio/src/convert.dart';
import 'package:flutter_proximiio/src/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

MsgCoordinate _c(double lat, double lng) => MsgCoordinate(latitude: lat, longitude: lng);

void main() {
  group('wayfinding', () {
    test('route options carry profile and avoidances', () {
      final msg = toMsgRouteOptions(
        const RouteOptions(profile: RouteProfile.wheelchair, avoid: {RouteAvoidance.revolvingDoors}),
      );

      expect(msg.profile, MsgRouteProfile.wheelchair);
      expect(msg.avoid, [MsgRouteAvoidance.revolvingDoors]);
    });

    test('every avoidance and profile has a transport counterpart', () {
      for (final avoidance in RouteAvoidance.values) {
        expect(MsgRouteAvoidance.values.byName(avoidance.name).name, avoidance.name);
      }
      for (final profile in RouteProfile.values) {
        expect(MsgRouteProfile.values.byName(profile.name).name, profile.name);
      }
      for (final kind in MsgInstructionKind.values) {
        expect(RouteInstructionKind.values.byName(kind.name).name, kind.name);
      }
    });

    test('a computed route converts with level changes and durations', () {
      final change = MsgLevelChange(featureType: 'elevator', fromLevel: 0, toLevel: 2, coordinate: _c(1, 2));
      final route = fromMsgRoute(
        MsgComputedRoute(
          coordinates: [_c(1, 2), _c(1.001, 2.001)],
          distanceMeters: 42.5,
          segments: [MsgRouteSegment(start: _c(1, 2), end: _c(1.001, 2.001), distanceMeters: 42.5)],
          level: 0,
          levelChanges: [change],
          instructions: [
            MsgRouteInstruction(
              kind: MsgInstructionKind.levelChange,
              coordinate: _c(1, 2),
              distanceMeters: 10,
              level: 0,
              durationSeconds: 30.5,
              levelChange: change,
            ),
          ],
          durationSeconds: 95.25,
        ),
      );

      expect(route.duration, const Duration(seconds: 95, milliseconds: 250));
      expect(route.levelChanges.single.toLevel, 2);
      expect(route.instructions.single.kind, RouteInstructionKind.levelChange);
      expect(route.instructions.single.levelChange?.featureType, 'elevator');
      expect(route.estimatedArrival(DateTime.utc(2026)), DateTime.utc(2026, 1, 1, 0, 1, 35, 250));
    });

    test('the duration matrix keeps the gaps where no route exists', () {
      final matrix = fromMsgDurations([
        MsgDurationRow(seconds: [0, 12.5]),
        MsgDurationRow(seconds: [null, 0]),
      ]);

      expect(matrix[0][1], const Duration(milliseconds: 12500));
      expect(matrix[1][0], isNull);
    });

    test('noRoute errors carry the reason, distance and blocked avoidances', () {
      final offNetwork = ProximiioException.fromPlatform(
        PlatformException(code: 'noRoute', details: {'reason': 'startOffNetwork', 'nearestDistanceMeters': '17.5'}),
      );
      expect(offNetwork.code, ProximiioErrorCode.noRoute);
      expect(offNetwork.noRouteReason, NoRouteReason.startOffNetwork);
      expect(offNetwork.nearestDistanceMeters, 17.5);

      final blocked = ProximiioException.fromPlatform(
        PlatformException(
          code: 'noRoute',
          details: {'reason': 'noAccessibleRoute', 'blockedBy': 'staircases,escalators,somethingNew'},
        ),
      );
      expect(blocked.blockedBy, {RouteAvoidance.staircases, RouteAvoidance.escalators});
    });
  });

  group('venue data', () {
    test('feature geometry and properties are decoded, title falls back', () {
      final feature = fromMsgFeature(
        MsgFeature(
          id: 'f',
          type: 'Feature',
          geometryJson: '{"type":"Point","coordinates":[17.1,48.1]}',
          propertiesJson: '{"title":"Cafe","level":1,"type":"poi"}',
          level: 1,
          propertyType: 'poi',
          isLevelChanger: false,
          titleTranslations: {'sk': 'Kaviareň'},
        ),
      );

      expect(feature.geometry?['type'], 'Point');
      expect(feature.properties?['title'], 'Cafe');
      expect(feature.title('sk'), 'Kaviareň');
      expect(feature.title('sk-SK'), 'Kaviareň');
      expect(feature.title('de'), 'Cafe');
      expect(feature.title(), 'Cafe');
    });

    test('amenity metadata and title translations', () {
      final amenity = fromMsgAmenity(
        MsgAmenity(
          id: 'a',
          title: 'Cafe',
          metadataJson: '{"searchable":true,"order":2}',
          titleTranslations: {'sk': 'Kaviareň', 'ar': ' '},
        ),
      );

      expect(amenity.metadata, {'searchable': true, 'order': 2});
      expect(amenity.titleTranslations, {'sk': 'Kaviareň', 'ar': ' '});
      expect(amenity.localizedTitle('sk'), 'Kaviareň');
      expect(amenity.localizedTitle('sk-SK'), 'Kaviareň');
      expect(amenity.localizedTitle('ar'), 'Cafe', reason: 'a blank translation is skipped');
      expect(amenity.localizedTitle(), 'Cafe');
      expect(fromMsgAmenity(MsgAmenity(id: 'b', titleTranslations: {})).metadata, isNull);
    });

    test('journey durations are seconds from the SDK', () {
      final journey = fromMsgJourney(
        MsgJourney(
          id: 'j',
          displayName: 'Highlights',
          waypoints: [MsgJourneyWaypoint(latitude: 1, longitude: 2, level: 0, dwellSeconds: 90, label: 'A')],
        ),
      );

      expect(journey.waypoints.single.dwell, const Duration(seconds: 90));
      expect(journey.waypoints.single.transition, isNull);
    });

    test('venue data kinds stay open-ended', () {
      final change = fromMsgVenueDataChange(MsgVenueDataChange(kinds: ['features', 'somethingNew']));

      expect(change.contains(VenueDataKind.features), isTrue);
      expect(change.contains(VenueDataKind.style), isFalse);
      expect(change.kinds, contains(const VenueDataKind('somethingNew')));
    });

    test('sync events', () {
      expect(fromMsgSyncEvent(MsgSyncCompleted(applied: 3)), const SyncCompleted(applied: 3));
      expect(fromMsgSyncEvent(MsgSyncUpdated(entity: 'Floor', id: 'f')), const SyncUpdated(entity: 'Floor', id: 'f'));
    });
  });

  group('beacons', () {
    test('identifiers by kind', () {
      expect(
        fromMsgBeaconIdentifier(MsgBeaconIdentifier(kind: MsgBeaconKind.iBeacon, uuid: 'U', major: 1, minor: 2)),
        const IBeaconIdentifier(uuid: 'U', major: 1, minor: 2),
      );
      expect(
        fromMsgBeaconIdentifier(MsgBeaconIdentifier(kind: MsgBeaconKind.eddystone, namespace: 'n', instance: 'i')),
        const EddystoneIdentifier(namespace: 'n', instance: 'i'),
      );
    });

    test('found and telemetry events', () {
      final identifier = MsgBeaconIdentifier(kind: MsgBeaconKind.uwbAccessory, name: 'anchor-1');
      final found = fromMsgBeaconEvent(
        MsgBeaconFound(observation: MsgBeaconObservation(identifier: identifier, rssi: -70, timestampMs: 1000)),
      );
      expect((found as BeaconFound).observation.rssi, -70);

      final telemetry = fromMsgBeaconEvent(
        MsgBeaconTelemetryReceived(
          identifier: identifier,
          telemetry: MsgBeaconTelemetry(
            batteryMillivolts: 3000,
            temperatureCelsius: 21.5,
            advertisementCount: 10,
            uptimeSeconds: 3600,
            receivedAtMs: 0,
          ),
        ),
      );
      expect((telemetry as BeaconTelemetryReceived).telemetry.uptime, const Duration(hours: 1));
    });
  });

  group('tools', () {
    test('package states', () {
      expect(fromMsgPackageState(MsgPackageState(kind: MsgPackageStateKind.ready, version: 7)), const PackageReady(7));
      expect(
        fromMsgPackageState(MsgPackageState(kind: MsgPackageStateKind.downloading, progress: 0.4)),
        const PackageDownloading(0.4),
      );
      expect(fromMsgPackageState(MsgPackageState(kind: MsgPackageStateKind.missing)), const PackageMissing());
    });

    test('simulated route update interval is seconds', () {
      final msg = toMsgSimulatedRoute(
        const SimulatedRoute(
          waypoints: [
            SimulatedWaypoint(Coordinate(latitude: 1, longitude: 2)),
            SimulatedWaypoint(Coordinate(latitude: 1.001, longitude: 2), level: 1),
          ],
          updateInterval: Duration(milliseconds: 500),
        ),
      );

      expect(msg.updateIntervalSeconds, 0.5);
      expect(msg.waypoints.last.level, 1);
      expect(msg.speed, 1.3);
    });

    test('diagnostics', () {
      final diagnostics = fromMsgDiagnostics(
        MsgDiagnostics(
          state: MsgSdkState.running,
          isStarted: true,
          isAuthenticated: true,
          visibleBeaconCount: 4,
          registeredBeaconCount: 30,
          lastPositionAgeSeconds: 1.5,
          lastPositionSource: MsgPositionSource.bleTrilateration,
          pdrEnabled: false,
          pdrRunning: false,
          visitorReportingEnabled: true,
          noPositionReason: null,
          summary: 'running, 4/30 beacons',
          generatedAtMs: 0,
        ),
      );

      expect(diagnostics.state, ProximiioState.running);
      expect(diagnostics.lastPositionAge, const Duration(milliseconds: 1500));
      expect(diagnostics.toString(), 'running, 4/30 beacons');
    });
  });
}
