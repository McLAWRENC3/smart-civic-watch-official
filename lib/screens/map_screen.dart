import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// Screen for displaying a map with user location and incident markers
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Variable to store the user's current location
  LatLng? _currentLocation;

  // Hardcoded list of incident locations (for demonstration)
  final List<LatLng> incidentLocations = [
    LatLng(-15.3875, 28.3228), // Lusaka
    LatLng(-15.4167, 28.2833), // Lusaka sample
  ];

  @override
  void initState() {
    super.initState();
    // Get user's location when the screen initializes
    _getUserLocation();
  }

  // Fetches the user's current location
  Future<void> _getUserLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Open location settings if services are disabled
      await Geolocator.openLocationSettings();
      return;
    }

    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    // Get current position and update state
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Map View"),
        backgroundColor: const Color(0xFF283593),
        foregroundColor: Colors.white,
      ),
      body: _currentLocation == null
      // Show loading indicator while getting location
          ? const Center(child: CircularProgressIndicator())
      // Display map once location is available
          : FlutterMap(
        options: MapOptions(
          center: _currentLocation!,
          zoom: 13,
        ),
        children: [
          // OpenStreetMap tile layer
          TileLayer(
            urlTemplate:
            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          // Marker layer for user location and incidents
          MarkerLayer(
            markers: [
              // User location marker
              Marker(
                point: _currentLocation!,
                width: 40,
                height: 40,
                builder: (ctx) => const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
              // Incident location markers
              ...incidentLocations.map((location) {
                return Marker(
                  point: location,
                  width: 40,
                  height: 40,
                  builder: (ctx) => const Icon(
                    Icons.warning,
                    color: Colors.red,
                    size: 28,
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }
}