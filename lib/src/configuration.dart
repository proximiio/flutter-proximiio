/// Starting point of a [ProximiioConfiguration]; the SDK's presets.
enum ConfigurationPreset {
  /// Balanced defaults (the SDK's `default`).
  standard,

  /// More frequent scanning and positioning, more battery.
  highAccuracy,

  /// Less frequent scanning and positioning, less battery.
  lowPower,

  /// Positions come only from a relay (RTLS); no BLE or native location.
  relayOnly,
}

/// Accuracy asked of the platform location service (GPS / fused location).
enum DesiredAccuracy {
  /// Highest accuracy plus sensor fusion (the default of every preset except
  /// [ConfigurationPreset.lowPower], which uses [hundredMeters]).
  bestForNavigation,

  /// Highest accuracy.
  best,

  /// About ten metres.
  nearestTenMeters,

  /// About a hundred metres.
  hundredMeters,

  /// About a kilometre.
  kilometer,

  /// About three kilometres. Android has no such level and uses [kilometer].
  threeKilometers,
}

/// Whether the Android foreground service shows its notification.
enum ServiceNotificationMode {
  /// The service runs with its notification (the default).
  enabled,

  /// No foreground service; positioning stops with the app in the background.
  disabled,

  /// The same as [enabled] (Android 8 and newer always need the service); kept for 1.x
  /// configurations.
  required,
}

/// Minimum level of the SDK log entries the plugin writes to the platform log; see
/// [Proximiio.setLogLevel].
enum ProximiioLogLevel {
  /// Everything.
  debug,

  /// Informational and above.
  info,

  /// Notable events and above.
  notice,

  /// Warnings and errors.
  warning,

  /// Errors only.
  error,
}

/// The Android foreground-service notification. Ignored on iOS.
///
/// Unset fields keep the SDK's defaults.
class AndroidServiceOptions {
  /// Creates service options; every field is optional.
  const AndroidServiceOptions({
    this.notificationTitle,
    this.notificationText,
    this.notificationIcon,
    this.channelName,
    this.channelDescription,
    this.mode,
    this.holdsWakeLock,
  });

  /// Notification title.
  final String? notificationTitle;

  /// Notification text.
  final String? notificationText;

  /// Name of a drawable resource in the app, e.g. `ic_stat_positioning`. The app icon when unset
  /// or not found. The resource is looked up by name, so keep it in release builds with
  /// `tools:keep="@drawable/ic_stat_positioning"` in `res/raw/keep.xml`; the resource shrinker removes it
  /// otherwise.
  final String? notificationIcon;

  /// Name of the notification channel shown in the system settings.
  final String? channelName;

  /// Description of the notification channel.
  final String? channelDescription;

  /// Whether the service and its notification are used.
  final ServiceNotificationMode? mode;

  /// Whether the service holds a partial wake lock while positioning.
  final bool? holdsWakeLock;
}

/// When the SDK publishes a new position: only after it moved at least
/// `max(minimumDisplacement, accuracyDisplacementFactor × accuracy)` from the last published one,
/// where `accuracy` is the smaller `horizontalAccuracy` of the two. A stationary visitor gets no new
/// positions. With PDR fusion, a detected step publishes a position without this check.
///
/// Unset fields keep the SDK's defaults.
class DistanceFilter {
  /// Creates a distance filter; every field is optional.
  const DistanceFilter({this.minimumDisplacement, this.accuracyDisplacementFactor});

  /// Smallest movement that publishes a position, in metres (SDK default: 1.33). At least 0.
  final double? minimumDisplacement;

  /// Share of the accuracy the movement must also reach (SDK default: 0.5). At least 0.
  final double? accuracyDisplacementFactor;
}

/// How the SDK is set up. Starts from [preset]; every non-null field overrides it.
class ProximiioConfiguration {
  /// Creates a configuration for the application [token].
  const ProximiioConfiguration({
    required this.token,
    this.preset = ConfigurationPreset.standard,
    this.relayRunsInBackground,
    this.apiBaseUrl,
    this.fallbackApiBaseUrls = const [],
    this.syncInterval,
    this.desiredAccuracy,
    this.allowsBackgroundLocationUpdates,
    this.visitorReportingEnabled,
    this.geofenceExitDelay,
    this.withholdsPositionsInPrivacyZones = true,
    this.customIBeaconUuids = const [],
    this.pdrFusionEnabled,
    this.barometerEnabled,
    this.bleEvaluationInterval,
    this.distanceFilter,
    this.android,
  });

  /// Proximi.io application token.
  final String token;

  /// The SDK preset the other fields override.
  final ConfigurationPreset preset;

  /// With [ConfigurationPreset.relayOnly] on iOS: keep receiving relay positions in the
  /// background. On Android the foreground service ([android]) does this.
  final bool? relayRunsInBackground;

  /// Proximi.io API host, e.g. `https://api.proximi.fi`. Use the host of your residency group or
  /// of your own installation; the SDK has no region switch.
  final Uri? apiBaseUrl;

  /// Hosts tried in order when [apiBaseUrl] cannot be reached.
  final List<Uri> fallbackApiBaseUrls;

  /// How often venue data is synchronised while running (preset default: 5 minutes, 10 with
  /// [ConfigurationPreset.lowPower]).
  final Duration? syncInterval;

  /// Accuracy asked of the platform location service.
  final DesiredAccuracy? desiredAccuracy;

  /// Keep positioning with the app in the background. iOS also needs `UIBackgroundModes`
  /// `location`; Android uses the foreground service.
  final bool? allowsBackgroundLocationUpdates;

  /// Report visitor analytics (positions, geofence events). The SDK default is `true`; see also
  /// [Proximiio.setVisitorReportingConsent].
  final bool? visitorReportingEnabled;

  /// How long a geofence exit waits for a re-entry before it is reported (SDK default: 3 s).
  final Duration? geofenceExitDelay;

  /// Hold back positions while the visitor is inside a privacy zone: [Proximiio.positions] and
  /// [Proximiio.lastPosition] get none there. `true` by default, as in 1.x; the native SDK v6 default
  /// is `false`.
  final bool withholdsPositionsInPrivacyZones;

  /// iBeacon UUIDs to scan for in addition to those of the venue data.
  final List<String> customIBeaconUuids;

  /// Fuse pedestrian dead reckoning into positions.
  final bool? pdrFusionEnabled;

  /// Use the barometer for floor changes. iOS only; Android always uses it when present.
  final bool? barometerEnabled;

  /// How often the SDK computes a position from the beacons (preset default: 2.5 s; 1 s with
  /// [ConfigurationPreset.highAccuracy], 5 s with [ConfigurationPreset.lowPower]). Must be positive.
  /// Positions arrive at most this often, and only when they pass [distanceFilter].
  final Duration? bleEvaluationInterval;

  /// When a new position is published; see [DistanceFilter].
  final DistanceFilter? distanceFilter;

  /// Android foreground service and its notification. Without it the Android SDK runs no foreground
  /// service, and positioning stops once Android freezes the backgrounded app. Ignored on iOS.
  final AndroidServiceOptions? android;
}
