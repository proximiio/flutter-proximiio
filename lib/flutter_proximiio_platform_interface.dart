import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_proximiio_method_channel.dart';

abstract class FlutterProximiioPlatform extends PlatformInterface {
  /// Constructs a FlutterProximiioPlatform.
  FlutterProximiioPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterProximiioPlatform _instance = MethodChannelFlutterProximiio();

  /// The default instance of [FlutterProximiioPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterProximiio].
  static FlutterProximiioPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterProximiioPlatform] when
  /// they register themselves.
  static set instance(FlutterProximiioPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
