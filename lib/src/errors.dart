import 'package:flutter/services.dart';

import 'wayfinding.dart';

/// What went wrong. The first group mirrors the SDK's `ProximiioError` cases on both platforms.
enum ProximiioErrorCode {
  /// The token was rejected.
  invalidToken,

  /// [Proximiio.authenticate] has not succeeded yet.
  notAuthenticated,

  /// Location permission is missing; see [ProximiioException.authorization].
  locationPermissionDenied,

  /// Bluetooth permission is missing.
  bluetoothPermissionDenied,

  /// Motion permission is missing.
  motionPermissionDenied,

  /// The user granted approximate location only.
  reducedLocationAccuracy,

  /// The SDK's local store failed.
  storage,

  /// A Proximi.io API request failed; see [ProximiioException.kind] and [ProximiioException.statusCode].
  api,

  /// No route between the points; see [ProximiioException.noRouteReason].
  noRoute,

  /// An offline package could not be synced or installed; see [ProximiioException.kind].
  offlinePackage,

  /// A journey id is invalid or the journey cannot be played; see [ProximiioException.kind].
  journey,

  /// Another failure inside the SDK or the platform; see [ProximiioException.underlying].
  underlying,

  /// [Proximiio.create] has not been called.
  notConfigured,

  /// A configuration value was rejected (a malformed URL or UUID).
  invalidArgument,

  /// The call does not exist on this platform.
  unsupported,

  /// A code added after this plugin release.
  unknown,
}

/// An error from the Proximi.io SDK or the bridge to it.
class ProximiioException implements Exception {
  /// Creates an exception.
  const ProximiioException(
    this.code, {
    this.message,
    this.isRetryable = false,
    this.authorization,
    this.kind,
    this.statusCode,
    this.noRouteReason,
    this.nearestDistanceMeters,
    this.blockedBy = const {},
    this.underlying,
    this.domain,
    this.failureCode,
  });

  /// Converts a platform error from the bridge.
  factory ProximiioException.fromPlatform(PlatformException error) {
    final details = <String, String>{};
    final raw = error.details;
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value != null) details[entry.key as String] = '${entry.value}';
      }
    }
    final blockedBy = details['blockedBy'];
    return ProximiioException(
      ProximiioErrorCode.values.firstWhere((code) => code.name == error.code, orElse: () => ProximiioErrorCode.unknown),
      message: error.message,
      isRetryable: details['retryable'] == 'true',
      authorization: details['authorization'],
      kind: details['kind'],
      statusCode: int.tryParse(details['statusCode'] ?? ''),
      noRouteReason: NoRouteReason.values.where((reason) => reason.name == details['reason']).firstOrNull,
      nearestDistanceMeters: double.tryParse(details['nearestDistanceMeters'] ?? ''),
      blockedBy:
          blockedBy == null || blockedBy.isEmpty
              ? const {}
              : {
                for (final name in blockedBy.split(','))
                  ...RouteAvoidance.values.where((avoidance) => avoidance.name == name),
              },
      underlying: details['underlying'],
      domain: details['domain'],
      failureCode: int.tryParse(details['failureCode'] ?? ''),
    );
  }

  /// What went wrong.
  final ProximiioErrorCode code;

  /// The SDK's description, for logs.
  final String? message;

  /// Whether retrying the same call can succeed (network and server failures).
  final bool isRetryable;

  /// For a permission error: the authorization state (`denied`, `restricted`, …).
  final String? authorization;

  /// The specific failure of an [ProximiioErrorCode.api] (`unauthorized`, `network`, `server`, …),
  /// [ProximiioErrorCode.offlinePackage] (`checksumMismatch`, `notInstalled`, …) or
  /// [ProximiioErrorCode.journey] (`invalidID`, `unplayable`) error.
  final String? kind;

  /// For an API server error: the HTTP status.
  final int? statusCode;

  /// For [ProximiioErrorCode.noRoute]: why no route was found.
  final NoRouteReason? noRouteReason;

  /// For [NoRouteReason.startOffNetwork] and [NoRouteReason.goalOffNetwork]: distance to the nearest path.
  final double? nearestDistanceMeters;

  /// For [NoRouteReason.noAccessibleRoute]: the avoidances every route would break.
  final Set<RouteAvoidance> blockedBy;

  /// The system error behind the failure (type and message), for logs and support.
  final String? underlying;

  /// The SDK's stable error domain, e.g. `io.proximi.sdk`.
  final String? domain;

  /// The SDK's stable numeric code within [domain].
  final int? failureCode;

  @override
  String toString() =>
      'ProximiioException(${code.name}${message == null ? '' : ': $message'}'
      '${underlying == null ? '' : ' [$underlying]'})';
}

/// Runs a bridge call and turns its [PlatformException]s into [ProximiioException]s.
Future<T> guarded<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PlatformException catch (error) {
    throw ProximiioException.fromPlatform(error);
  }
}
