import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mindmate_patient/main.dart';

class PatientMapScreen extends StatefulWidget {
  const PatientMapScreen({super.key});

  @override
  State<PatientMapScreen> createState() => _PatientMapScreenState();
}

class _PatientMapScreenState extends State<PatientMapScreen> {
  Position? _currentPosition;
  Map<String, dynamic>? _patientProfile;
  final MapController _mapController = MapController();
  List<Marker> _hospitalMarkers = [];
  bool _isLoadingHospitals = false;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    _currentPosition = await Geolocator.getCurrentPosition();
    if (mounted) setState(() {});

    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('tbl_patient')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) setState(() => _patientProfile = data);
    }

    if (_currentPosition != null) {
      _fetchNearbyHospitals();
    }
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_currentPosition == null) return;

    if (mounted) setState(() => _isLoadingHospitals = true);

    try {
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;
      const radius = 5000; // 5km

      final query = """
      [out:json];
      (
        node["amenity"="hospital"](around:$radius,$lat,$lng);
        way["amenity"="hospital"](around:$radius,$lat,$lng);
        relation["amenity"="hospital"](around:$radius,$lat,$lng);
      );
      out center;
      """;

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'];

        List<Marker> markers = [];
        for (var element in elements) {
          double? hLat = element['lat'] ?? element['center']?['lat'];
          double? hLng = element['lon'] ?? element['center']?['lon'];
          String name = element['tags']?['name'] ?? "Hospital";

          if (hLat != null && hLng != null) {
            markers.add(
              Marker(
                point: LatLng(hLat, hLng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_hospital, color: Colors.red, size: 50),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                              label: const Text("Close"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.local_hospital,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _hospitalMarkers = markers;
            _isLoadingHospitals = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching hospitals: $e");
      if (mounted) setState(() => _isLoadingHospitals = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng? userLoc = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;

    LatLng? safeZoneLoc =
        (_patientProfile != null && _patientProfile!['safe_zone_lat'] != null)
        ? LatLng(
            _patientProfile!['safe_zone_lat'],
            _patientProfile!['safe_zone_lng'],
          )
        : null;

    double radius = (_patientProfile?['safe_zone_radius'] ?? 100).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Hospitals"),
        backgroundColor: Colors.teal,
        actions: [
          if (_isLoadingHospitals)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          IconButton(
            onPressed: _fetchNearbyHospitals,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: userLoc == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: userLoc, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mindmate_patient',
                ),
                if (safeZoneLoc != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: safeZoneLoc,
                        color: Colors.teal.withOpacity(0.3),
                        borderStrokeWidth: 2,
                        borderColor: Colors.teal,
                        useRadiusInMeter: true,
                        radius: radius,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLoc,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                    if (safeZoneLoc != null)
                      Marker(
                        point: safeZoneLoc,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.home,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                    ..._hospitalMarkers,
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (userLoc != null) _mapController.move(userLoc, 15);
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
