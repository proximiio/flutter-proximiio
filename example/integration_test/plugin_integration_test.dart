// Runs on a device against the real SDK:
//   flutter test integration_test --dart-define-from-file=env.json
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _token = String.fromEnvironment('PROXIMIIO_TOKEN');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create and authenticate', (tester) async {
    final sdk = await Proximiio.create(const ProximiioConfiguration(token: _token));
    expect(await sdk.state(), ProximiioState.idle);

    final application = await sdk.authenticate();

    expect(application, isNotNull);
    expect(await sdk.state(), ProximiioState.authenticated);
    expect(await sdk.visitorId(), isNotEmpty);
  }, skip: _token.isEmpty);

  testWidgets('a bad token is reported as invalidToken', (tester) async {
    final sdk = await Proximiio.create(const ProximiioConfiguration(token: 'not-a-token'));

    await expectLater(
      sdk.authenticate(),
      throwsA(
        isA<ProximiioException>().having(
          (e) => e.code,
          'code',
          anyOf(ProximiioErrorCode.invalidToken, ProximiioErrorCode.api),
        ),
      ),
    );
  });
}
