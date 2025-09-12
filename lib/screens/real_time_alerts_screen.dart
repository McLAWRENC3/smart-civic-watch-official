import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

// Screen for displaying real-time emergency alerts
class RealTimeAlertsScreen extends StatefulWidget {
  const RealTimeAlertsScreen({super.key});

  @override
  State<RealTimeAlertsScreen> createState() => _RealTimeAlertsScreenState();
}

class _RealTimeAlertsScreenState extends State<RealTimeAlertsScreen> {
  // Get current authenticated user
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  // Store user's current position
  Position? _currentPosition;
  // Loading state for location retrieval
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    // Get user's current location on screen initialization
    _getCurrentLocation();
    // Setup push notifications (placeholder for FCM integration)
    _setupPushNotifications();
  }

  // Gets the user's current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  // Placeholder for push notification setup (would integrate with FCM)
  void _setupPushNotifications() {
    // This would integrate with Firebase Cloud Messaging
    // For now, we'll use Firestore real-time updates
  }

  // Calculates distance between user and alert location
  double _calculateDistance(double alertLat, double alertLng) {
    if (_currentPosition == null) return -1;

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      alertLat,
      alertLng,
    );
  }

  // Opens Google Maps to navigate to alert location
  Future<void> _navigateToAlertLocation(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  // Builds a card widget for each alert
  Widget _buildAlertCard(DocumentSnapshot document) {
    final alert = document.data() as Map<String, dynamic>;
    final timestamp = alert['timestamp'] as Timestamp?;
    final date = timestamp != null ? timestamp.toDate() : DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);

    // Extract alert location coordinates
    final double? alertLat = alert['latitude'];
    final double? alertLng = alert['longitude'];
    // Calculate distance to alert if coordinates are available
    final double distance = (alertLat != null && alertLng != null)
        ? _calculateDistance(alertLat, alertLng)
        : -1;

    // Determine color based on alert severity
    final String severity = alert['severity'] ?? 'medium';
    Color severityColor;

    switch (severity) {
      case 'high':
        severityColor = Colors.red;
        break;
      case 'medium':
        severityColor = Colors.orange;
        break;
      case 'low':
        severityColor = Colors.yellow;
        break;
      default:
        severityColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: severityColor.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert title and severity chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    alert['title'] ?? 'Emergency Alert',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(
                    severity.toUpperCase(),
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: severityColor.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Alert description
            Text(
              alert['description'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            // Alert timestamp
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            // Display distance if available
            if (distance > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${(distance / 1000).toStringAsFixed(1)} km away',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Navigation button (only shown if location coordinates exist)
                if (alertLat != null && alertLng != null)
                  TextButton.icon(
                    icon: const Icon(Icons.directions, size: 16),
                    label: const Text('Navigate'),
                    onPressed: () => _navigateToAlertLocation(alertLat, alertLng),
                  ),
                // Details button
                TextButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Details'),
                  onPressed: () {
                    _showAlertDetails(alert);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Shows detailed alert information in a dialog
  void _showAlertDetails(Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert['title'] ?? 'Alert Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert['description'] ?? ''),
              const SizedBox(height: 16),
              // Display location coordinates if available
              if (alert['latitude'] != null && alert['longitude'] != null)
                Text('Location: ${alert['latitude']}, ${alert['longitude']}'),
              const SizedBox(height: 8),
              Text('Severity: ${alert['severity'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              Text('Type: ${alert['type'] ?? 'General'}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Alerts'),
        backgroundColor: const Color(0xFF283593),
        actions: [
          // Refresh location button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading indicator when getting location
          if (_isLoadingLocation)
            const LinearProgressIndicator(),
          Expanded(
            // Stream builder for real-time alerts from Firestore
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('alerts')
                  .where('active', isEqualTo: true)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // Show loading indicator while data is loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Show empty state if no alerts are available
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No active alerts',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'You will be notified when new alerts are issued',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Build list of alert cards
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    return _buildAlertCard(snapshot.data!.docs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Floating action button for reporting new emergencies
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Quick report functionality
          Navigator.pushNamed(context, '/report');
        },
        child: const Icon(Icons.add_alert),
        tooltip: 'Report Emergency',
      ),
    );
  }
}