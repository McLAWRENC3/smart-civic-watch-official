import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

// Main home screen with dashboard and navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for fade-in effect
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  // User location and map controller
  LatLng? _userLocation;
  final MapController _mapController = MapController();
  bool _isLoadingLocation = false;

  // Sample incident locations (hardcoded for demonstration)
  final List<LatLng> _incidentLocations = [
    LatLng(-15.4180, 28.2820),
    LatLng(-15.4205, 28.2800),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize animation controller and fade animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Get user's current location on screen initialization
    _determinePosition();
  }

  // Determines and sets the user's current position
  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update user location and move map to that location
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_userLocation!, 15);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  // Handles user logout
  Future<void> _logout() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout error: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Builds a gradient-styled button with optional icon
  Widget _buildGradientButton(String label, VoidCallback onPressed, {IconData? icon}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.2 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          )
              : Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).currentUser;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3E8EDE), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: SizedBox.expand(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header section with title and navigation icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Dashboard',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Quick access icons
                                  IconButton(
                                    icon: const Icon(Icons.volunteer_activism,
                                        color: Colors.white, size: 28),
                                    tooltip: 'Donations',
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/donations');
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.notifications,
                                        color: Colors.white, size: 28),
                                    tooltip: 'Emergency Alerts',
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/alerts');
                                    },
                                  ),
                                ],
                              ),
                              // Display user email if available
                              if (currentUser != null && currentUser.email != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    currentUser.email!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Map container
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.26 * 255).round()),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            // FlutterMap widget for displaying map
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                center: _userLocation ?? LatLng(-15.4167, 28.2833),
                                zoom: 13,
                              ),
                              children: [
                                // OpenStreetMap tile layer
                                TileLayer(
                                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                  subdomains: const ['a', 'b', 'c'],
                                  userAgentPackageName: 'com.example.smart_civic_watch',
                                ),
                                // Marker layer for user location and incidents
                                MarkerLayer(
                                  markers: [
                                    if (_userLocation != null)
                                      Marker(
                                        width: 20,
                                        height: 20,
                                        point: _userLocation!,
                                        builder: (ctx) => Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.7),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ..._incidentLocations.map(
                                          (loc) => Marker(
                                        width: 40,
                                        height: 40,
                                        point: loc,
                                        builder: (ctx) => const Icon(
                                          Icons.location_pin,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Loading indicator while getting location
                            if (_isLoadingLocation)
                              const Center(child: CircularProgressIndicator()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Navigation buttons
                    _buildGradientButton('Report Incident', () {
                      Navigator.pushNamed(context, '/report');
                    }),
                    const SizedBox(height: 16),
                    _buildGradientButton('Emergency Contacts', () {
                      Navigator.pushNamed(context, '/contacts');
                    }),
                    const SizedBox(height: 16),
                    _buildGradientButton('Donations', () {
                      Navigator.pushNamed(context, '/donations');
                    }, icon: Icons.volunteer_activism),
                    const SizedBox(height: 16),
                    _buildGradientButton('Emergency Alerts', () {
                      Navigator.pushNamed(context, '/alerts');
                    }, icon: Icons.notifications),
                    const SizedBox(height: 16),
                    _buildGradientButton('Logout', _logout),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}