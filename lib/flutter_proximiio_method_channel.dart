import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_proximiio_platform_interface.dart';

/// An implementation of [FlutterProximiioPlatform] that uses method channels.
class MethodChannelFlutterProximiio extends FlutterProximiioPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_proximiio');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
