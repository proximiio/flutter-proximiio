import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:flutter_proximiio/src/messages.g.dart';
import 'package:flutter_proximiio/src/proximiio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls; answers from fields set by the test.
class FakeHostApi extends ProximiioHostApi {
  final calls = <String>[];
  MsgConfiguration? configuration;
  PlatformException? failWith;
  List<MsgFloor> floorList = [];
  bool configured = false;
  String style = '{}';

  Future<T> _answer<T>(String name, T value) async {
    calls.add(name);
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<void> configure(MsgConfiguration configuration) {
    this.configuration = configuration;
    return _answer('configure', null);
  }

  @override
  Future<bool> isConfigured() => _answer('isConfigured', configured);

  @override
  Future<String> mapStyle() => _answer('mapStyle', style);

  @override
  Future<MsgApplication?> authenticate() => _answer('authenticate', MsgApplication(id: 'app', name: 'Demo'));

  @override
  Future<void> start() => _answer('start', null);

  @override
  Future<void> stop() => _answer('stop', null);

  @override
  Future<List<MsgFloor>> floors() => _answer('floors', floorList);

  @override
  Future<List<String>> enteredGeofenceIds() => _answer('enteredGeofenceIds', ['b', 'a', 'a']);

  @override
  Future<MsgPermissionStatus> requestPermissions(bool always) => _answer(
    'requestPermissions($always)',
    MsgPermissionStatus(
      location: always ? MsgLocationAuthorization.always : MsgLocationAuthorization.whenInUse,
      accuracy: MsgLocationAccuracy.full,
      bluetooth: MsgBluetoothAuthorization.allowed,
      motion: MsgMotionAuthorization.notDetermined,
    ),
  );

  @override
  Future<bool> updateServiceNotification(MsgAndroidServiceOptions options) =>
      _answer('updateServiceNotification(${options.notificationTitle})', true);
}

/// Event channels backed by controllers the test drives.
class FakeEvents extends BridgeEvents {
  final positionsController = StreamController<MsgPositionUpdate>.broadcast();
  final geofenceController = StreamController<MsgGeofenceEvent>.broadcast();
  int positionsCalls = 0;

  @override
  Stream<MsgPositionUpdate> positions() {
    positionsCalls++;
    return positionsController.stream;
  }

  @override
  Stream<MsgGeofenceEvent> geofenceEvents() => geofenceController.stream;

  Future<void> close() async {
    await positionsController.close();
    await geofenceController.close();
  }
}

MsgPositionUpdate _position(double latitude) => MsgPositionUpdate(
  coordinate: MsgCoordinate(latitude: latitude, longitude: 17),
  horizontalAccuracy: 1,
  source: MsgPositionSource.native,
  timestampMs: 0,
  background: false,
);

void main() {
  late FakeHostApi api;
  late FakeEvents events;

  setUp(() {
    api = FakeHostApi();
    events = FakeEvents();
  });

  tearDown(() => events.close());

  test('create configures the native instance once', () async {
    await BridgedProximiio.create(
      const ProximiioConfiguration(token: 'tok'),
      api: api,
      events: events,
    );

    expect(api.calls, ['configure']);
    expect(api.configuration?.token, 'tok');
  });

  test('lifecycle calls go through in order and convert results', () async {
    final sdk = await BridgedProximiio.create(
      const ProximiioConfiguration(token: 't'),
      api: api,
      events: events,
    );

    final status = await sdk.requestPermissions(always: true);
    final app = await sdk.authenticate();
    await sdk.start();
    await sdk.stop();

    expect(status.location, LocationAuthorization.always);
    expect(app, const ProximiioApplication(id: 'app', name: 'Demo'));
    expect(api.calls, ['configure', 'requestPermissions(true)', 'authenticate', 'start', 'stop']);
  });

  test('platform errors become ProximiioException with the SDK code and details', () async {
    final sdk = BridgedProximiio(api, events);
    api.failWith = PlatformException(
      code: 'locationPermissionDenied',
      message: 'Location access is denied.',
      details: {'authorization': 'denied', 'retryable': 'false', 'domain': 'io.proximi.sdk', 'failureCode': '3'},
    );

    await expectLater(
      sdk.start(),
      throwsA(
        isA<ProximiioException>()
            .having((e) => e.code, 'code', ProximiioErrorCode.locationPermissionDenied)
            .having((e) => e.authorization, 'authorization', 'denied')
            .having((e) => e.failureCode, 'failureCode', 3)
            .having((e) => e.isRetryable, 'isRetryable', isFalse),
      ),
    );
  });

  test('api errors carry kind and status; unknown codes do not crash', () async {
    final sdk = BridgedProximiio(api, events);
    api.failWith = PlatformException(
      code: 'api',
      details: {'kind': 'server', 'statusCode': '503', 'retryable': 'true'},
    );
    await expectLater(
      sdk.authenticate(),
      throwsA(
        isA<ProximiioException>()
            .having((e) => e.kind, 'kind', 'server')
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.isRetryable, 'isRetryable', isTrue),
      ),
    );

    api.failWith = PlatformException(code: 'somethingFromTheFuture');
    await expectLater(
      sdk.stop(),
      throwsA(isA<ProximiioException>().having((e) => e.code, 'code', ProximiioErrorCode.unknown)),
    );
  });

  test('data getters convert lists and sets', () async {
    final sdk = BridgedProximiio(api, events);
    api.floorList = [MsgFloor(id: 'f', level: 2, anchors: const [])];

    expect((await sdk.floors()).single.level, 2);
    expect(await sdk.enteredGeofenceIds(), {'a', 'b'});
  });

  test('every listener shares one event channel subscription', () async {
    final sdk = BridgedProximiio(api, events);
    final first = <double>[];
    final second = <double>[];

    final a = sdk.positions.listen((p) => first.add(p.coordinate.latitude));
    final b = sdk.positions.listen((p) => second.add(p.coordinate.latitude));
    events.positionsController.add(_position(48));
    await pumpEventQueue();

    expect(events.positionsCalls, 1);
    expect(first, [48]);
    expect(second, [48]);
    await a.cancel();
    await b.cancel();
  });

  test('a second create shares the streams of the first handle', () async {
    final first = await BridgedProximiio.create(
      const ProximiioConfiguration(token: 'a'),
      api: api,
      events: events,
    );
    final old = <double>[];
    final oldSubscription = first.positions.listen((p) => old.add(p.coordinate.latitude));

    final second = await BridgedProximiio.create(
      const ProximiioConfiguration(token: 'b'),
      api: api,
      events: events,
    );
    final current = <double>[];
    final subscription = second.positions.listen((p) => current.add(p.coordinate.latitude));
    events.positionsController.add(_position(48));
    await pumpEventQueue();
    // The old page goes away; the new one keeps its events.
    await oldSubscription.cancel();
    events.positionsController.add(_position(49));
    await pumpEventQueue();

    expect(events.positionsCalls, 1);
    expect(old, [48]);
    expect(current, [48, 49]);
    await subscription.cancel();
  });

  test('shared returns the running instance without configuring it', () async {
    expect(await BridgedProximiio.shared(api: api, events: events), isNull);

    api.configured = true;
    final sdk = await BridgedProximiio.shared(api: api, events: events);
    await sdk!.start();

    expect(api.calls, ['isConfigured', 'isConfigured', 'start']);
  });

  test('a map style that is not a JSON object is an api decoding error', () async {
    final sdk = BridgedProximiio(api, events);

    for (final body in ['<html>', '[]']) {
      api.style = body;
      await expectLater(
        sdk.mapStyle(),
        throwsA(
          isA<ProximiioException>()
              .having((e) => e.code, 'code', ProximiioErrorCode.api)
              .having((e) => e.kind, 'kind', 'decoding'),
        ),
      );
    }
    api.style = '{"version": 8}';
    expect(await sdk.mapStyle(), {'version': 8});
  });

  test('stream errors are converted too', () async {
    final sdk = BridgedProximiio(api, events);
    final errors = <Object>[];
    final subscription = sdk.geofenceEvents.listen((_) {}, onError: errors.add);

    events.geofenceController.addError(PlatformException(code: 'notAuthenticated'));
    await pumpEventQueue();

    expect(errors.single, isA<ProximiioException>().having((e) => e.code, 'code', ProximiioErrorCode.notAuthenticated));
    await subscription.cancel();
  });

  test('android options are converted', () async {
    final sdk = BridgedProximiio(api, events);

    final updated = await sdk.android.updateServiceNotification(const AndroidServiceOptions(notificationTitle: 'Hi'));

    expect(updated, isTrue);
    expect(api.calls.last, 'updateServiceNotification(Hi)');
  });
}
