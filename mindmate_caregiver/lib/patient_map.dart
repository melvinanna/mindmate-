import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mindmate_caregiver/main.dart'; // contains supabase client

class PatientMapScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientMapScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientMapScreen> createState() => _PatientMapScreenState();
}

class _PatientMapScreenState extends State<PatientMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<List<Map<String, dynamic>>>? _locationSubscription;

  late String _selectedPatientId;
  late String _selectedPatientName;
  List<Map<String, dynamic>> _allPatients = [];
  
  LatLng? _currentPatientLocation;
  double _safeZoneRadius = 100.0;
  List<LatLng> _historyPoints = [];

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;
    _selectedPatientName = widget.patientName;
    _fetchAllPatients();
    _subscribeToPatientLocation();
  }

  Future<void> _fetchAllPatients() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final patients = await supabase
          .from('tbl_patient')
          .select('id, patient_name')
          .eq('caregiver_id', user.id);
      setState(() {
        _allPatients = List<Map<String, dynamic>>.from(patients);
      });
    }
  }

  void _switchPatient(String patientId, String patientName) {
    setState(() {
      _selectedPatientId = patientId;
      _selectedPatientName = patientName;
      _currentPatientLocation = null;
      _historyPoints = [];
    });
    _locationSubscription?.cancel();
    _subscribeToPatientLocation();
  }

  void _subscribeToPatientLocation() {
    // 1. Initial Fetch
    _fetchInitialLocation();

    // 2. Subscribe to realtime changes on tbl_patient
    _locationSubscription = supabase
        .from('tbl_patient')
        .stream(primaryKey: ['id'])
        .eq('id', _selectedPatientId)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final patientData = data.first;
            if (patientData['last_known_location_lat'] != null &&
                patientData['last_known_location_lng'] != null) {
              final latLng = LatLng(
                patientData['last_known_location_lat'],
                patientData['last_known_location_lng'],
              );

              final int safeZoneRadius = patientData['safe_zone_radius'] ?? 100;

              setState(() {
                _currentPatientLocation = latLng;
                _safeZoneRadius = safeZoneRadius.toDouble();
                // Append real-time movement to history points
                _historyPoints.add(latLng);
              });
              _animateToLocation(latLng);
            }
          }
        });
  }

  Future<void> _fetchInitialLocation() async {
    // A. Fetch current location & safe zone
    final response = await supabase
        .from('tbl_patient')
        .select()
        .eq('id', _selectedPatientId)
        .maybeSingle();

    // B. Fetch location history trail
    final historyResponse = await supabase
        .from('tbl_location_history')
        .select()
        .eq('patient_id', _selectedPatientId)
        .order('recorded_at', ascending: true)
        .limit(100);

    List<LatLng> loadedHistory = [];
    for (var point in historyResponse) {
      loadedHistory.add(LatLng(point['latitude'], point['longitude']));
    }

    if (response != null &&
        response['last_known_location_lat'] != null &&
        response['last_known_location_lng'] != null) {
      final latLng = LatLng(
        response['last_known_location_lat'],
        response['last_known_location_lng'],
      );
      final int safeZoneRadius = response['safe_zone_radius'] ?? 100;

      setState(() {
        _currentPatientLocation = latLng;
        _safeZoneRadius = safeZoneRadius.toDouble();
        _historyPoints = loadedHistory.isNotEmpty ? loadedHistory : [latLng];
      });
      _animateToLocation(latLng);
    }
  }

  void _animateToLocation(LatLng pos) {
    // move the map to the new location only if the controller is ready
    try {
      _mapController.move(pos, 16.5);
    } catch (e) {
      debugPrint("Map controller not ready yet.");
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _allPatients.length > 1
            ? DropdownButton<String>(
                value: _selectedPatientId,
                dropdownColor: Colors.teal,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: _allPatients.map((patient) {
                  return DropdownMenuItem<String>(
                    value: patient['id'],
                    child: Text(patient['patient_name']),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    final patient = _allPatients
                        .firstWhere((p) => p['id'] == value);
                    _switchPatient(value, patient['patient_name']);
                  }
                },
              )
            : Text("${_selectedPatientName}'s Live Tracking"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _currentPatientLocation == null
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPatientLocation!,
                initialZoom: 16.5,
                onLongPress: (tapPosition, point) {
                  setState(() {
                    _currentPatientLocation = point;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mindmate_caregiver',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _currentPatientLocation!,
                      radius: _safeZoneRadius,
                      useRadiusInMeter: true,
                      color: Colors.teal.withOpacity(0.2),
                      borderColor: Colors.teal,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _historyPoints,
                      color: Colors.blueAccent.withOpacity(0.5),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPatientLocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSafeZone,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.security, color: Colors.white),
        label: const Text(
          "UPDATE SAFE ZONE",
          style: TextStyle(color: Colors.white),
        ),
      ),
      bottomSheet: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          children: [
            const Text(
              "Adjust Safe Zone Radius (Meters)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _safeZoneRadius,
              min: 50,
              max: 2000,
              divisions: 39,
              label: "${_safeZoneRadius.toInt()}m",
              onChanged: (val) => setState(() => _safeZoneRadius = val),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSafeZone() async {
    if (_currentPatientLocation == null) return;
    try {
      await supabase
          .from('tbl_patient')
          .update({
            'safe_zone_lat': _currentPatientLocation!.latitude,
            'safe_zone_lng': _currentPatientLocation!.longitude,
            'safe_zone_radius': _safeZoneRadius.toInt(),
          })
          .eq('id', widget.patientId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Safe Zone Updated!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    }
  }
}
