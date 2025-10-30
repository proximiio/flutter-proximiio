import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:flutter_proximiio/flutter_proximiio_platform_interface.dart';
import 'package:flutter_proximiio/flutter_proximiio_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterProximiioPlatform
    with MockPlatformInterfaceMixin
    implements FlutterProximiioPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterProximiioPlatform initialPlatform = FlutterProximiioPlatform.instance;

  test('$MethodChannelFlutterProximiio is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterProximiio>());
  });

  test('getPlatformVersion', () async {
    FlutterProximiio flutterProximiioPlugin = FlutterProximiio();
    MockFlutterProximiioPlatform fakePlatform = MockFlutterProximiioPlatform();
    FlutterProximiioPlatform.instance = fakePlatform;

    expect(await flutterProximiioPlugin.getPlatformVersion(), '42');
  });
}
