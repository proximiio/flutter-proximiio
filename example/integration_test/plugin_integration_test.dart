// Runs on a device against the real SDK:
//   flutter test integration_test --dart-define-from-file=env.json
import 'package:flutter/foundation.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _token = String.fromEnvironment('PROXIMIIO_TOKEN');
const _apiBaseUrl = String.fromEnvironment('PROXIMIIO_API_BASE_URL');

Future<T> _logged<T>(String name, Future<T> Function() call) async {
  try {
    return await call();
  } on ProximiioException catch (e) {
    debugPrint('$name failed: $e kind=${e.kind} underlying=${e.underlying} domain=${e.domain}/${e.failureCode}');
    rethrow;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create, authenticate, read venue data', (tester) async {
    await Proximiio.setLogLevel(ProximiioLogLevel.debug);
    final sdk = await Proximiio.create(
      ProximiioConfiguration(token: _token, apiBaseUrl: _apiBaseUrl.isEmpty ? null : Uri.parse(_apiBaseUrl)),
    );
    expect(await sdk.state(), ProximiioState.idle);

    final application = await _logged('authenticate', sdk.authenticate);

    expect(application, isNotNull);
    expect(await sdk.state(), ProximiioState.authenticated);
    expect(await sdk.visitorId(), isNotEmpty);

    final floors = await sdk.floors();
    final paths = await _logged('loadRouteNetwork', sdk.loadRouteNetwork);
    final features = await sdk.features();
    final amenities = await _logged('amenities', sdk.amenities);
    final style = await _logged('mapStyle', sdk.mapStyle);
    final diagnostics = await sdk.diagnostics();
    debugPrint(
      'venue: ${floors.length} floors, $paths routable paths, ${features.length} features, ${amenities.length} amenities, '
      'style layers ${(style['layers'] as List?)?.length}; diagnostics: $diagnostics',
    );
    expect(diagnostics.isAuthenticated, isTrue);
    expect(style, contains('version'));
  }, skip: _token.isEmpty);

  testWidgets('a bad token is reported as invalidToken', (tester) async {
    final sdk = await Proximiio.create(const ProximiioConfiguration(token: 'not-a-token'));

    await expectLater(
      _logged('authenticate with a bad token', sdk.authenticate),
      throwsA(isA<ProximiioException>().having((e) => e.code, 'code', ProximiioErrorCode.invalidToken)),
    );
  });
}
