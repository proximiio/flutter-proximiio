import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';

const String token = 'YOUR_PROXIMIIO_TOKEN';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proximiio Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ProximiioExample(),
    );
  }
}

class ProximiioExample extends StatefulWidget {
  const ProximiioExample({super.key});

  @override
  State<ProximiioExample> createState() => _ProximiioExampleState();
}

class _ProximiioExampleState extends State<ProximiioExample> {
  String _visitorId = '';
  ProximiioFloor? _floor;
  ProximiioLocation _location = ProximiioLocation(lat: 0, lng: 0, sourceType: '');
  List<ProximiioGeofence> _geofences = [];

  @override
  void initState() {
    super.initState();
    _initProximiio();
  }

  Future<void> _initProximiio() async {
    try {
      final state = await FlutterProximiio.authorize(token);
      
      if (state.ready) {
        setState(() {
          _visitorId = state.visitorId;
        });

        FlutterProximiio.subscribe(
          ProximiioEvents.floorChanged,
          (ProximiioFloor floor) {
            setState(() {
              _floor = floor;
            });
          },
        );

        FlutterProximiio.subscribe(
          ProximiioEvents.positionUpdated,
          (ProximiioLocation location) {
            setState(() {
              _location = location;
            });
          },
        );

        final updateGeofences = (ProximiioGeofence geofence) async {
          final current = await FlutterProximiio.currentGeofences();
          setState(() {
            _geofences = current;
          });
        };

        FlutterProximiio.subscribe(
          ProximiioEvents.enteredGeofence,
          updateGeofences,
        );

        FlutterProximiio.subscribe(
          ProximiioEvents.exitedGeofence,
          updateGeofences,
        );

        await FlutterProximiio.requestPermissions();
        await FlutterProximiio.setNativeAccuracy(NativeAccuracy.gps);
      }
    } catch (e) {
      debugPrint('Error initializing Proximiio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximiio Flutter Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildInfoRow('Visitor ID:', _visitorId),
            const SizedBox(height: 12),
            _buildInfoRow('Latitude:', _location.lat.toStringAsFixed(8)),
            const SizedBox(height: 12),
            _buildInfoRow('Longitude:', _location.lng.toStringAsFixed(8)),
            const SizedBox(height: 12),
            _buildInfoRow('Source:', _location.sourceType ?? ''),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Geofences:',
              _geofences.map((g) => g.name).join(', '),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Floor:', _floor?.name ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    FlutterProximiio.unsubscribeAll(ProximiioEvents.floorChanged);
    FlutterProximiio.unsubscribeAll(ProximiioEvents.positionUpdated);
    FlutterProximiio.unsubscribeAll(ProximiioEvents.enteredGeofence);
    FlutterProximiio.unsubscribeAll(ProximiioEvents.exitedGeofence);
    super.dispose();
  }
}
