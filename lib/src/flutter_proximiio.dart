import 'dart:async';
import 'package:flutter/services.dart';
import 'models/proximiio_location.dart';
import 'models/proximiio_floor.dart';
import 'models/proximiio_geofence.dart';
import 'models/proximiio_privacy_zone.dart';
import 'models/proximiio_input.dart';
import 'models/proximiio_init_state.dart';
import 'enums/native_accuracy.dart';
import 'enums/buffer_size.dart';
import 'enums/notification_mode.dart';
import 'enums/proximiio_events.dart';

class FlutterProximiio {
  static const MethodChannel _channel = MethodChannel('flutter_proximiio');
  static const EventChannel _eventChannel = EventChannel('flutter_proximiio_events');
  
  static Stream<dynamic>? _eventStream;
  static final Map<ProximiioEvents, List<Function>> _eventListeners = {};

  static Future<ProximiioInitState> authorize(String token) async {
    try {
      final result = await _channel.invokeMethod('authorize', {'token': token});
      _startListeningToEvents();
      return ProximiioInitState.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      throw Exception('Failed to authorize: $e');
    }
  }

  static Future<void> requestPermissions({bool useAlways = true}) async {
    try {
      await _channel.invokeMethod('requestPermissions', {'useAlways': useAlways});
    } catch (e) {
      throw Exception('Failed to request permissions: $e');
    }
  }

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (e) {
      throw Exception('Failed to enable: $e');
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (e) {
      throw Exception('Failed to disable: $e');
    }
  }

  static Future<ProximiioFloor?> currentFloor() async {
    try {
      final result = await _channel.invokeMethod('currentFloor');
      if (result == null) return null;
      return ProximiioFloor.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      throw Exception('Failed to get current floor: $e');
    }
  }

  static Future<List<ProximiioFloor>> floors() async {
    try {
      final result = await _channel.invokeMethod('floors');
      return (result as List).map((f) => ProximiioFloor.fromMap(Map<String, dynamic>.from(f))).toList();
    } catch (e) {
      throw Exception('Failed to get floors: $e');
    }
  }

  static Future<ProximiioFloor?> floorById(String id) async {
    try {
      final result = await _channel.invokeMethod('floorById', {'id': id});
      if (result == null) return null;
      return ProximiioFloor.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      throw Exception('Failed to get floor by id: $e');
    }
  }

  static Future<List<ProximiioGeofence>> geofences() async {
    try {
      final result = await _channel.invokeMethod('geofences');
      return (result as List).map((g) => ProximiioGeofence.fromMap(Map<String, dynamic>.from(g))).toList();
    } catch (e) {
      throw Exception('Failed to get geofences: $e');
    }
  }

  static Future<ProximiioGeofence?> geofenceById(String id) async {
    try {
      final result = await _channel.invokeMethod('geofenceById', {'id': id});
      if (result == null) return null;
      return ProximiioGeofence.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      throw Exception('Failed to get geofence by id: $e');
    }
  }

  static Future<List<ProximiioGeofence>> currentGeofences() async {
    try {
      final result = await _channel.invokeMethod('currentGeofences');
      return (result as List).map((g) => ProximiioGeofence.fromMap(Map<String, dynamic>.from(g))).toList();
    } catch (e) {
      throw Exception('Failed to get current geofences: $e');
    }
  }

  static Future<void> setBufferSize(BufferSize bufferSize) async {
    try {
      await _channel.invokeMethod('setBufferSize', {'bufferSize': bufferSize.index});
    } catch (e) {
      throw Exception('Failed to set buffer size: $e');
    }
  }

  static Future<void> setNativeAccuracy(NativeAccuracy accuracy) async {
    try {
      await _channel.invokeMethod('setNativeAccuracy', {'accuracy': accuracy.value});
    } catch (e) {
      throw Exception('Failed to set native accuracy: $e');
    }
  }

  static Future<void> setNotificationMode(NotificationMode mode) async {
    try {
      await _channel.invokeMethod('setNotificationMode', {'mode': mode.value});
    } catch (e) {
      throw Exception('Failed to set notification mode: $e');
    }
  }

  static Future<void> setNotificationTitle(String title) async {
    try {
      await _channel.invokeMethod('setNotificationTitle', {'title': title});
    } catch (e) {
      throw Exception('Failed to set notification title: $e');
    }
  }

  static Future<void> setNotificationText(String text) async {
    try {
      await _channel.invokeMethod('setNotificationText', {'text': text});
    } catch (e) {
      throw Exception('Failed to set notification text: $e');
    }
  }

  static Future<void> setNotificationIcon(String icon) async {
    try {
      await _channel.invokeMethod('setNotificationIcon', {'icon': icon});
    } catch (e) {
      throw Exception('Failed to set notification icon: $e');
    }
  }

  static Future<void> updateOptions() async {
    try {
      await _channel.invokeMethod('updateOptions');
    } catch (e) {
      throw Exception('Failed to update options: $e');
    }
  }

  static void subscribe(ProximiioEvents event, Function callback) {
    if (!_eventListeners.containsKey(event)) {
      _eventListeners[event] = [];
    }
    _eventListeners[event]!.add(callback);
  }

  static void unsubscribe(ProximiioEvents event, Function callback) {
    if (_eventListeners.containsKey(event)) {
      _eventListeners[event]!.remove(callback);
    }
  }

  static void unsubscribeAll(ProximiioEvents event) {
    _eventListeners.remove(event);
  }

  static void _startListeningToEvents() {
    _eventStream ??= _eventChannel.receiveBroadcastStream();
    _eventStream!.listen((dynamic event) {
      if (event is Map) {
        final eventType = ProximiioEvents.values.firstWhere(
          (e) => e.name == event['event'],
          orElse: () => ProximiioEvents.unknown,
        );

        if (_eventListeners.containsKey(eventType)) {
          final data = event['data'];
          
          for (var listener in _eventListeners[eventType]!) {
            switch (eventType) {
              case ProximiioEvents.positionUpdated:
                listener(ProximiioLocation.fromMap(Map<String, dynamic>.from(data)));
                break;
              case ProximiioEvents.floorChanged:
                listener(ProximiioFloor.fromMap(Map<String, dynamic>.from(data)));
                break;
              case ProximiioEvents.enteredGeofence:
              case ProximiioEvents.exitedGeofence:
                listener(ProximiioGeofence.fromMap(Map<String, dynamic>.from(data)));
                break;
              case ProximiioEvents.enteredPrivacyZone:
              case ProximiioEvents.exitedPrivacyZone:
                listener(ProximiioPrivacyZone.fromMap(Map<String, dynamic>.from(data)));
                break;
              case ProximiioEvents.foundIBeacon:
              case ProximiioEvents.updatedIBeacon:
              case ProximiioEvents.lostIBeacon:
              case ProximiioEvents.foundEddystoneBeacon:
              case ProximiioEvents.updatedEddystoneBeacon:
              case ProximiioEvents.lostEddystoneBeacon:
                listener(ProximiioInput.fromMap(Map<String, dynamic>.from(data)));
                break;
              default:
                listener(data);
            }
          }
        }
      }
    });
  }
}
