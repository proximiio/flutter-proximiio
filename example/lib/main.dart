import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';

/// The application token comes from the build, never from source:
///   cp env.example.json env.json   # put your token in env.json (gitignored)
///   flutter run --dart-define-from-file=env.json
const _token = String.fromEnvironment('PROXIMIIO_TOKEN');
const _apiBaseUrl = String.fromEnvironment('PROXIMIIO_API_BASE_URL');

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Proximi.io',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF3F69FF)),
    home: const PositioningPage(),
  );
}

class PositioningPage extends StatefulWidget {
  const PositioningPage({super.key});

  @override
  State<PositioningPage> createState() => _PositioningPageState();
}

class _PositioningPageState extends State<PositioningPage> {
  Proximiio? _sdk;
  ProximiioState _state = ProximiioState.idle;
  PermissionStatus? _permissions;
  PositionUpdate? _position;
  final List<String> _log = [];
  final List<StreamSubscription<Object?>> _subscriptions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_token.isNotEmpty) unawaited(_setUp());
  }

  Future<void> _setUp() async {
    await _run(() async {
      final sdk = await Proximiio.create(
        ProximiioConfiguration(
          token: _token,
          apiBaseUrl: _apiBaseUrl.isEmpty ? null : Uri.parse(_apiBaseUrl),
          android: const AndroidServiceOptions(notificationTitle: 'Proximi.io example'),
        ),
      );
      _subscriptions.addAll([
        sdk.stateChanges.listen((state) => setState(() => _state = state)),
        sdk.permissionUpdates.listen((status) => setState(() => _permissions = status)),
        sdk.positions.listen((position) => setState(() => _position = position)),
        sdk.floorChanges.listen((change) => _add('floor ${change.previousFloor?.level} → ${change.floor?.level}')),
        sdk.geofenceEvents.listen(
          (event) => _add(switch (event) {
            GeofenceEntered(:final geofence) => 'entered ${geofence.name ?? geofence.id}',
            GeofenceExited(:final geofence, :final dwellTime) =>
              'left ${geofence.name ?? geofence.id} after ${dwellTime.inSeconds} s',
            PrivacyZoneEntered(:final zone) => 'entered privacy zone ${zone.name ?? zone.id}',
            PrivacyZoneExited(:final zone) => 'left privacy zone ${zone.name ?? zone.id}',
          }),
        ),
      ]);
      setState(() => _sdk = sdk);
      final application = await sdk.authenticate();
      _add('authenticated: ${application?.name ?? application?.id}');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      setState(() => _error = null);
      await action();
    } on ProximiioException catch (error) {
      setState(() => _error = '${error.code.name}: ${error.message ?? ''}');
    }
  }

  void _add(String line) => setState(() => _log.insert(0, line));

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sdk = _sdk;
    final position = _position;
    return Scaffold(
      appBar: AppBar(title: const Text('Proximi.io SDK')),
      body: _token.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No token. Run with --dart-define-from-file=env.json (see env.example.json).'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('State: ${_state.name}', style: Theme.of(context).textTheme.titleMedium),
                if (_permissions != null) Text('$_permissions'),
                if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: sdk == null
                          ? null
                          : () => _run(() async {
                              final status = await sdk.requestPermissions();
                              setState(() => _permissions = status);
                            }),
                      child: const Text('Permissions'),
                    ),
                    FilledButton(
                      onPressed: sdk == null || _state == ProximiioState.running ? null : () => _run(sdk.start),
                      child: const Text('Start'),
                    ),
                    OutlinedButton(
                      onPressed: sdk == null || _state != ProximiioState.running ? null : () => _run(sdk.stop),
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text(
                  position == null
                      ? 'No position yet'
                      : '${position.coordinate.latitude.toStringAsFixed(6)}, '
                            '${position.coordinate.longitude.toStringAsFixed(6)} '
                            '±${position.horizontalAccuracy.toStringAsFixed(1)} m\n'
                            'floor ${position.floor?.name ?? position.floor?.level ?? '-'} · ${position.source.name}',
                ),
                const Divider(height: 32),
                for (final line in _log) Text(line),
              ],
            ),
    );
  }
}
