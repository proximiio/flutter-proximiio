# Flutter modernization plan: `flutter_proximiio` + `flutter_proximiio_map` onto SDK v6

Status: **DRAFT 2026-10-25**. Covers both repos:

| Coordination slug | Repo | Package |
|---|---|---|
| `proximiio-flutter-sdk` | `/Volumes/ExtremeSSD/proximiio/flutter-proximiio` | `flutter_proximiio` |
| `proximiio-flutter-map` | `/Volumes/ExtremeSSD/proximiio/flutter-proximiio-map` | `flutter_proximiio_map` |

Source of truth for names and behaviour: iOS SDK v6 (`proximiio-ios-sdk`) and iOS Map v6
(`proximiio-ios-map`); Android SDK/Map v6 mirror them. The Flutter layer adds no behaviour of its own.

## Summary

- Both packages are rewritten, not patched: the bridge targets v5 APIs that no longer exist (audit in §A).
- `flutter_proximiio` becomes a typed **Pigeon** bridge over the v6 facade (`Proximiio` actor on iOS,
  coroutine facade on Android). The Dart API follows v6 names: `authenticate` / `start` / `stop`, and the
  run-scoped streams become Dart `Stream`s (`positions`, `floorChanges`, `geofenceEvents`, …).
- `flutter_proximiio_map` drops the WebView. It becomes a **platform view** over the native v6 map
  (`ProximiioMapViewController` on iOS, `ProximiioMapView : FrameLayout` on Android), driven by a Dart
  `ProximiioMapController`. The native map draws the dot, floors, routes and guidance itself.
- Versions move in lockstep with the native libraries: `6.0.0-beta.N`, each release pinning exact native versions.
- Breaking for every current user. A migration guide ships with 6.0 (§C, P5).

## B. Target architecture

### B1. Native dependencies (as of 2026-10-25)

| | iOS | Android |
|---|---|---|
| SDK | `Proximiio` 6.0.0-beta.64: SwiftPM `proximiio/proximiio-sdk-ios-binary` (product `Proximiio`), **or** CocoaPods via `:podspec => https://raw.githubusercontent.com/proximiio/proximiio-sdk-ios-binary/<tag>/Proximiio.podspec` (not on trunk; made for React Native) | `io.proximi.sdk:proximiio:6.0.0-beta.31` from `https://maven.eu.proximi.fi/releases/` (public reads). Optional: `proximiio-positioning-uwb`, `proximiio-blueiot`, `proximiio-liveview` |
| Map | `ProximiioMap` 6.0.0-beta.51, **SwiftPM only** (`proximiio/proximiio-map-ios-binary`); pins SDK beta.64 and MapLibre **exact** 6.29.0 | `io.proximi.map:proximiio-map:6.0.0-beta.27` (check it is published; latest tag is beta.26); pins SDK beta.31, MapLibre `13.5.0` (floor, not pin) |
| Floor for host apps | iOS 15, Swift 6 / Xcode 16 | minSdk 26, Kotlin ≥ 2.2, JDK 17, compileSdk 37 likely required (to confirm with android-sdk) |
| Access | both iOS binary repos are **public** (GitHub API, 2026-10-25), although the SDK's `docs/RELEASING.md` still says "private until RC" | none |

Consequences for the plugins:
- iOS: ship **both** a `Package.swift` (Flutter SwiftPM support) and a podspec. The podspec depends on
  `Proximiio`; the app adds the one `pod 'Proximiio', :podspec => …` line (documented, same as React Native).
  The map has no podspec, so `flutter_proximiio_map` on iOS works only in SwiftPM mode until ios-map ships one
  (ask filed, §E).
- Android: the plugin's `build.gradle.kts` adds the maven repo for the app (`rootProject.allprojects`), and the
  README gives the `settings.gradle.kts` line for apps that use `dependencyResolutionManagement`.
- The plugin's own toolchain matches the SDK: AGP 8.13, Kotlin 2.2, JDK 17, Swift 6.

### B2. The bridge: Pigeon, one native instance

- **Pigeon** generates Dart/Kotlin/Swift from one `pigeons/proximiio_api.dart`: `@HostApi` for calls
  (`@async`), `@EventChannelApi` for streams, typed data classes and sealed event classes. No hand-written
  string maps (that drift is bug A1.5).
- **One native SDK instance per process**, stored in `Proximiio.shared` (exists on both platforms). The map
  plugin reads `Proximiio.shared`, so it needs no compile-time dependency on the SDK plugin's native code;
  both plugins only pin the same native SDK version.
- Several Flutter engines (add-to-app, background isolates) share that instance; each engine gets its own
  event sinks.
- iOS: the plugin class is `@MainActor`; each call is a `Task` that `await`s the actor, replies on main.
  Streams: one `Task` per `AsyncStream`, cancelled in `onCancel`.
- Android: a `CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)` per engine, cancelled in
  `onDetachedFromEngine`. Streams `collect` the `Flow`s and push to the Pigeon sink on main (fixes A1.4).
- **Run-scoped streams are hidden from Dart.** v6 streams end at `stop()` and must be re-subscribed after
  each `start()`. The native side re-subscribes on every transition to `running` (watching `State`), so a
  Dart `Stream` lives as long as the app listens to it, across restarts.
- Enum values cross the bridge as their raw strings (Swift `bleTrilateration` / Kotlin `BLE_TRILATERATION`
  → Dart `PositionSource.bleTrilateration`).

### B3. Dart API (sketch, names from v6)

```dart
final sdk = await Proximiio.create(ProximiioConfiguration(
  token: token,
  apiBaseUrl: Uri.parse('https://api.proximi.fi'), // per residency group or on-prem host; no eu/uae enum in v6
  visitorReportingEnabled: true,                   // v6 default is true
  android: AndroidServiceOptions(notificationTitle: 'Indoor positioning', mode: ServiceNotificationMode.enabled),
));

final status = await sdk.requestPermissions(always: false); // PermissionStatus{location, accuracy, bluetooth, motion}
final app = await sdk.authenticate();                       // ProximiioApplication?
await sdk.start();

sdk.state.listen(...);                 // idle | authenticated | starting | running | stopping
sdk.positions.listen((PositionUpdate p) => ...); // coordinate, horizontalAccuracy, floor?, source, timestamp
sdk.floorChanges.listen(...);
sdk.geofenceEvents.listen((e) => switch (e) {
  GeofenceEntered(:final geofence) => ...,
  GeofenceExited(:final geofence, :final dwellTime) => ..., // Duration, from the SDK's seconds
  PrivacyZoneEntered() || PrivacyZoneExited() => ...,
});
sdk.privacyZoneStateChanges / venueDataChanges / syncEvents / beaconEvents / permissionUpdates

final floors = await sdk.floors();     // also places(), geofences(), privacyZones(), amenities(), features()
final route = await sdk.computeRoute(from: a, fromLevel: 0, to: b, toLevel: 2,
    options: const RouteOptions(profile: RouteProfile.wheelchair));
await sdk.setVisitorReportingConsent(false);
await sdk.stop();
```

- Instance API, no statics. `Proximiio` is an abstract class with a Pigeon-backed implementation, so apps
  can fake it in tests.
- Errors: a sealed `ProximiioException` mapped from v6 `ProximiioError` (`InvalidToken`, `NotAuthenticated`,
  `LocationPermissionDenied`, `BluetoothPermissionDenied`, `MotionPermissionDenied`,
  `ReducedLocationAccuracy`, `Storage`, `Underlying`), with `isRetryable` (fixes A1.13).
- Models are immutable, with `==`/`hashCode` and `copyWith` (`freezed`, or hand-written if we want zero
  runtime deps). Floor `level` is a `double`, as in v6.
- Platform-only APIs live under `sdk.android` / `sdk.ios` (for example `updateServiceNotification`) instead of
  silently doing nothing on the other platform.

### B4. Permissions and background

- **iOS:** the SDK prompts itself (`requestPermissions(always:)`); the plugin forwards. The host app adds
  the Info.plist keys (`NSLocationAlwaysAndWhenInUseUsageDescription`, Bluetooth, Motion; Nearby Interaction /
  Camera only if those features are used) and `UIBackgroundModes=location` for background positioning.
- **Android:** the SDK takes a `PermissionRequestLauncher` (an interface). The plugin implements it on top of
  `ActivityPluginBinding.addRequestPermissionsResultListener` + `ActivityCompat.requestPermissions`, so it
  works with a plain `FlutterActivity` (`ActivityResultPermissionLauncher` would need a `ComponentActivity`).
  Background location is asked in a second step, as the SDK docs require (Android 11+).
- Android foreground service: `ProximiioServiceOptions` from `AndroidServiceOptions` in the configuration;
  `updateServiceNotification` / `resetServiceNotification` at runtime. The AAR already declares the FGS types
  and `POST_NOTIFICATIONS`.

### B5. Map widget

```dart
final map = ProximiioMapController();
ProximiioMap(
  controller: map,
  options: const MapOptions(floorSelector: true, chrome: MapChrome.bare),
  onFeatureTap: (ids, coordinate) => ...,
);
await map.camera.setCenter(coordinate, zoom: 19, animated: true);
await map.selectFloor(floorKey);           // followMyFloor(), showVenue(), recentre()
await map.setRoute(route);                 // a ComputedRoute from sdk.computeRoute
map.guidance.listen((RouteGuidance? g) => ...); // after map.setGuidanceRules(RouteFollowRules.venueWalk)
```

- **iOS:** a `FlutterPlatformViewFactory` creates `ProximiioMapViewController(sdk: Proximiio.shared!, options:)`,
  adds it as a child of the `FlutterViewController` (it relies on containment and safe-area callbacks),
  returns its `view`, and calls `dismantle()` on dispose.
- **Android:** `ProximiioMapView(context, session)`. Composition mode: **Hybrid Composition**
  (`PlatformViewLink` + `initExpensiveAndroidView`) by default, because the map renders to a `SurfaceView`.
  If android-map adds an option to render to a `TextureView` (asked, §E), we can offer the cheaper
  texture-layer mode as well. The plugin forwards the activity lifecycle (`FlutterLifecycleAdapter`) to the
  view's idempotent `onStart`…`onDestroy`, and calls `session.close()` on dispose (the host owns it).
- Each map instance gets its own Pigeon channel suffix (the platform view id).
- **v1 scope:** camera (center, zoom, fit, heading, insets), floors (list, select, follow), `MapOptions`
  (chrome, position style, trail, route line/markers, geofence style, language, insets, initial framing),
  feature tap, hidden features, route display, guidance stream, `lastError`.
- **Also v1 (decision F3):** `JourneyNavigator` (state + `events` stream + the ~20 commands) and `JourneyCodec`.
- **v2:** custom layers. Neither native map has search, highlight or generic markers, so the Flutter map does
  not either; they are asked of the map libraries first if needed.
- The map shows the SDK position by itself (the session subscribes to the SDK streams). The Flutter side does
  not push positions any more (removes A2.3, A2.9).

### B6. Repos, tests, CI, docs

- Two packages in two repos (decision F2; the map pulls MapLibre, SDK-only apps should not pay for it). The
  map pins an exact `flutter_proximiio` release; each repo has its own example app.
- Tests: Dart unit tests against a fake host API; Kotlin JVM tests and Swift XCTests for the model mappers
  (the place where platform payloads drifted); `integration_test` in the example app on one real iOS and one
  real Android device for permissions, start, positions and the map.
- CI (`conventions/ci-runners.md`): `dart format --set-exit-if-changed`, `flutter analyze` (strict lints),
  `flutter test`, Pigeon output up to date, `flutter build apk`, `flutter build ios --no-codesign` in both
  CocoaPods and SwiftPM modes.
- Docs and changelog per `conventions/docs-changelog.md`: Keep a Changelog 1.1 with `[Unreleased]`, docs as a
  Partner Zone docs bundle, a native-version table in the README.
- The example app reads the token from `--dart-define-from-file` (gitignored), never from source.

## C. Phases

| Phase | Content | Done when |
|---|---|---|
| **P0** Hygiene | Remove template code (A1.10), token out of source (A1.16), strict lints, CI skeleton, CHANGELOG format, monorepo decision applied | CI green on an empty-but-clean plugin |
| **P1** SDK core | Pigeon schema; config, `create`, `authenticate`, `start`/`stop`, `state`; `positions`, `floorChanges`, `geofenceEvents`, `privacyZoneStateChanges`; data getters (floors, places, geofences, privacy zones); permissions both platforms; Android service options; errors | example app positions on a device, both platforms, unit tests for every mapper |
| **P2** SDK extended | `computeRoute` + `RouteOptions`; `venueDataChanges`, `syncEvents`, `sync()`; `beaconEvents`; visitor reporting + `visitorId`; amenities, features, `mapStyle`; offline packages; simulation; diagnostics; log level | public Dart API covers the SDK's commonly used surface |
| **P3** Map v1 | platform views both platforms, controller, v1 scope from B5 **plus `JourneyNavigator`** (decision F3) | example app: map, dot, floors, tap, route shown, guidance text, a multi-stop journey |
| **P4** Map v2 | custom layers | (later) |
| **P5** Release | migration guide 1.x → 6.0, Partner Zone docs bundle, device test pass, tag `6.0.0-beta.1` | first beta consumable by a partner |

## D. Risks

- ~~Private iOS binaries until RC.~~ Checked 2026-10-25: both binary repos are already public.
- **MapLibre exact pin on iOS (6.29.0).** An app that also uses another MapLibre plugin (e.g. `maplibre_gl`)
  fails to resolve unless the versions match.
- **Raised floors for host apps:** iOS 15, minSdk 26, Kotlin 2.2, probably compileSdk 37. Older Flutter app
  templates need changes; the README lists them.
- **Android platform-view cost.** Hybrid Composition costs frame time on low-end devices; measure early in P3.
- **Swift 6 strict concurrency** against Flutter's non-`Sendable` plugin APIs: keep the plugin `@MainActor`.
- **Offline maps** work only with a bundled seed today (the SDK download endpoint answers 404).

## E. Coordination asks (filed 2026-10-25)

- `inbox/proximiio-ios-sdk/2026-10-25-proximiio-flutter-sdk-new-consumer.md`: FYI new consumer; CI access to
  the private binary repo; podspec-per-tag stays the CocoaPods path.
- `inbox/proximiio-android-sdk/2026-10-25-proximiio-flutter-sdk-new-consumer.md`: FYI new consumer; host
  compileSdk/Kotlin floor; `PermissionRequestLauncher` and `Proximiio.shared` as stable bridge API.
- `inbox/proximiio-ios-map/2026-10-25-proximiio-flutter-map-podspec.md`: a CocoaPods podspec for the map binary,
  or a decision that the map is SwiftPM-only.
- `inbox/proximiio-android-map/2026-10-25-proximiio-flutter-map-platform-view.md`: an option to render to a
  `TextureView`; behaviour without a `ViewTreeLifecycleOwner`.

## F. Decisions (operator, 2026-10-25)

1. **Breaking change to the v6 shape.** No compatibility layer for the 1.x static API; a migration guide
   1.x → 6.0 ships instead.
2. **Two repos stay.** `flutter_proximiio_map` depends on an exact `flutter_proximiio` version (a git
   dependency with a `ref` tag until the packages are published, never a bare git URL). Releases are cut in
   lockstep: map release N names the SDK plugin release it needs. B6's monorepo recommendation is dropped.
3. **Map v1 includes `JourneyNavigator`.** P3 and P4 below merge into one phase "Map v1"; custom layers
   remain the only v2 item.


## Status update (2026-10-25, later)

- **P1 verified on a device:** iOS 26.3 simulator integration test passes against the live API (authenticate,
  floors, amenities, map style, diagnostics; a bad token maps to `invalidToken`). On the Pixel (Android 17) the
  bridge works end to end but the test app got no network: the phone was locked and dozing, and Android blocks
  the network of apps that are not in the foreground (`blocked=APP_BACKGROUND`). Rerun with the phone unlocked.
- **P2 done:** wayfinding (`loadRouteNetwork`, `loadCachedRouteNetwork`, `computeRoute`, `routeDurations`), venue
  data (`features`, `amenities`, `departments`, `mapStyle`, `journeys`), streams (`venueDataChanges`, `syncEvents`,
  `beaconEvents`), offline packages, simulation, positioning inputs, diagnostics; error codes `noRoute`,
  `offlinePackage`, `journey` and the `underlying` detail. Dart tests 35/35, Kotlin tests 9/9, Android
  `assembleDebug` and iOS SwiftPM build green. Not bridged: `startBeaconDiscovery` sessions,
  `installBundledOfflineSeedIfNeeded` (bundle vs directory differs per platform; `installOfflineSeed` covers it).
- **Docs:** `docs/site` (28 pages) in the iOS/Android style, strict exporter preflight clean. Blocked on Partner
  Zone product ids `flutter` / `flutter-map` (asked).
- Found in the SDKs and asked: `authenticate()` fails offline on both platforms, so an offline cold start cannot
  reach `start()`; Android `MIGRATION.md` §3.5 claims `start()` checks permissions (it does not).
- Next: P3 (map v1 with `JourneyNavigator`) in `flutter-proximiio-map`.

## Status (2026-10-25, branch `v6-migration`)

- **P0 done:** template and v5 code removed, strict lints, Keep a Changelog, token out of the example
  (`--dart-define-from-file`, `env.json` gitignored).
- **P1 done, not yet run on a device:** Pigeon bridge + Dart API, iOS (Swift) and Android (Kotlin) bridges.
  - `flutter analyze`: no issues; Dart unit tests 21/21; Kotlin JVM tests (`MappersTest`) 9/9; example widget test 1/1.
  - Android: example `assembleDebug` builds against `io.proximi.sdk:proximiio:6.0.0-beta.31`.
  - iOS: a SwiftPM-mode app builds against `Proximiio` 6.0.0-beta.64. The CocoaPods path is **not verified**
    (CocoaPods is not installed on the build machine).
  - Not done: the integration test on a real device (needs a token in `example/env.json`), Swift unit tests.
- Found while building: an Android host needs **AGP 8.13** (AGP 8.9 cannot find `platforms;android-37`, which the
  SDK manager now installs as `android-37.0`) and Gradle 8.13+. Locally, `flutter build apk` runs Gradle on the
  JDK 25 bundled with Android Studio, which Gradle 8.x cannot run on; `flutter config --jdk-dir=<JDK 17 or 21>`
  fixes it (the builds above ran `./gradlew` with JBR 17).
- Next: P2 (SDK extended), then P3 (map v1 with `JourneyNavigator`) in `flutter-proximiio-map`.

## A. Audit of the current code (2026-10-25)

### A1. `flutter_proximiio` (plugin, ~1.1k lines Dart/Kotlin/Swift)

Native dependencies are the **legacy v5** SDKs: iOS pod `Proximiio` 5.3.0 (`ios/flutter_proximiio.podspec`),
Android `io.proximi.library:core:5.1.16` from the retired `maven.proximi.io` Nexus, plus the IndoorAtlas and
Mapbox repos (`android/build.gradle`). Nothing of it carries over to v6; the bridge is rewritten either way.

Bugs (behaviour today):

1. **Duplicate events after re-authorize.** `authorize()` calls `_startListeningToEvents()` every time and each
   call adds another `listen` on the broadcast stream, never cancelled (`lib/src/flutter_proximiio.dart:24,185`).
   The second `authorize` delivers every event twice.
2. **Android `authorize` can hang forever.** The result is completed only in `loggedIn(online = true)` or
   `loginFailed`; an offline login never completes the `Future` (`FlutterProximiioPlugin.kt:240`).
3. **Platforms do different things on `authorize`.** iOS syncs, starts updating and sets buffer size Mini;
   Android only sets the token. Same Dart call, different state afterwards.
4. **Android drops events in the background.** `sendEvent` posts through `activity?.runOnUiThread`; with no
   activity attached (backgrounded, engine without UI) events vanish (`FlutterProximiioPlugin.kt:355`).
5. **Payloads differ per platform.** Position: iOS adds `floor`, Android does not, and Android fills
   `sourceType` from a *geofence event type* (`positionExtended(..., type: ProximiioGeofence.EventType?)`).
   Beacons: iOS sends `distance` + `rssi`, Android `accuracy`. Dwell time: iOS converts seconds → ms,
   Android passes the SDK value unconverted. Dart `ProximiioGeofence.fromMap` reads none of `dwellTime`,
   `polygon`, `isPolygon`, so they are lost anyway.
6. **Android `entered` is always true** when the SDK returns any Boolean: `"entered" to (isEntered() != null)`.
7. **`requestPermissions` differs.** iOS returns `null` at once (prompt still pending); Android returns
   `true` after the Bluetooth prompt even when the user denies it. Android never asks for
   `POST_NOTIFICATIONS` (13+) or background location.
8. **`setNativeAccuracy` maps different numbers** to different accuracies on each platform.
9. **iOS logs every event** with `print` (`FlutterProximiioPlugin.swift:269`): log noise in release builds.

Structure and quality:

10. Leftover template code: a second Android plugin class `com/example/flutter_proximiio/FlutterProximiioPlugin.kt`,
    the unused `flutter_proximiio_platform_interface.dart` / `_method_channel.dart` (`getPlatformVersion`),
    template tests that test nothing of the real API.
11. All-static Dart API with global mutable state; not mockable, not testable.
12. Untyped events: `subscribe(ProximiioEvents, Function)` casts at runtime; a wrong callback type crashes on
    the first event instead of failing to compile.
13. Errors are wrapped as `Exception('Failed to …: $e')`; the `PlatformException.code` is lost, callers cannot
    tell "invalid token" from "offline".
14. Hand-written string-keyed maps on 3 sides (Dart/Kotlin/Swift) drift apart (see 5). No codegen, no tests.
15. Android toolchain: AGP 8.1, Kotlin 1.9, compileSdk 33, Java 8, `buildscript {}` in a library.
    iOS: iOS 13, Swift 5.0, CocoaPods only.
16. **The example app commits a live application token** (`example/lib/main.dart:4`). Move to
    `--dart-define`/`--dart-define-from-file` (gitignored) and rotate the token if this repo is or was public.

### A2. `flutter_proximiio_map` (one file, 339 lines)

The widget is a WebView loading an HTML page with an iframe onto **`https://maps.proximi.io/<customer>/`**,
one customer's web map, hard-coded. Talking to it is `postMessage` both ways.

1. **The widget's parameters do nothing.** `token` and `mapDefaults` are never used; every app gets the
   customer map.
2. **The public API cannot be called.** `setCenter`, `flyTo`, `setFloor`, `setRoute`, … are methods of the
   private `_ProximiioMapWidgetState`; there is no controller, so apps cannot reach them.
3. **`dispose()` removes the app's own listeners.** It calls `FlutterProximiio.unsubscribeAll(positionUpdated)`
   and `(floorChanged)`, which also deletes every subscription the host app made. The stored
   `StreamSubscription`s are never assigned.
4. Messages sent before "ready" are dropped although the log says "queued"; `_callMethod` turns timeouts and
   errors into `null`.
5. `setState` after a 500 ms delay without a `mounted` check: throws after a quick dispose.
6. Script injection by string interpolation (`window.postMessage('$jsonString', '*')`): a `'` in a value
   breaks the script. Messages are accepted from any origin and posted with target `'*'`.
7. Forces a `SafeArea` around the map; the host app should decide.
8. `flutter_proximiio` is a git dependency with no `ref`: every `pub get` can pick up a different commit.
9. The map reaches the SDK only for the dot (lat/lng/level); no routes, floors or features from the SDK.

Conclusion: nothing in either package is worth keeping as code. Keep the package names and the overall
idea (SDK plugin + separate map widget); rebuild both on v6.
