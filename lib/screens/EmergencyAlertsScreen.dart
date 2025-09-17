import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// Screen for reporting incidents with media (images or videos)
class ReportIncidentScreen extends StatefulWidget {
  final String? reportId;
  final Map<String, dynamic>? existingData;

  const ReportIncidentScreen({
    super.key,
    this.reportId,
    this.existingData,
  });

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  // Controllers for text input fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Variables for handling media files
  File? _mediaFile;
  bool _isVideo = false;
  bool _isSubmitting = false;
  String? _selectedMediaOption;
  String? _existingMediaUrl;

  // Controller for video playback
  VideoPlayerController? _videoController;

  // Media options for dropdown selection
  final List<Map<String, dynamic>> _mediaOptions = [
    {'value': 'camera_image', 'label': 'Take Photo', 'icon': Icons.camera_alt, 'source': ImageSource.camera, 'isVideo': false},
    {'value': 'gallery_image', 'label': 'Choose from Gallery', 'icon': Icons.photo_library, 'source': ImageSource.gallery, 'isVideo': false},
    {'value': 'camera_video', 'label': 'Record Video', 'icon': Icons.videocam, 'source': ImageSource.camera, 'isVideo': true},
    {'value': 'gallery_video', 'label': 'Choose Video from Gallery', 'icon': Icons.video_library, 'source': ImageSource.gallery, 'isVideo': true},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill form if editing existing report
    if (widget.existingData != null) {
      _titleController.text = widget.existingData!['title'] ?? '';
      _descriptionController.text = widget.existingData!['description'] ?? '';
      _existingMediaUrl = widget.existingData!['media_url'];
      _isVideo = widget.existingData!['is_video'] ?? false;
    }
  }

  @override
  void dispose() {
    // Clean up controllers when widget is disposed
    _titleController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // Picks media (image or video) from the specified source
  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    final pickedFile = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _mediaFile = File(pickedFile.path);
        _isVideo = isVideo;
        _existingMediaUrl = null; // Clear existing media URL when new media is selected
      });

      // Initialize video controller if video is selected
      if (isVideo) {
        _videoController = VideoPlayerController.file(_mediaFile!)
          ..initialize().then((_) {
            setState(() {});
            _videoController!.setLooping(true);
            _videoController!.play();
          });
      } else {
        // Dispose of any existing video controller if switching to image
        _videoController?.dispose();
        _videoController = null;
      }
    }
  }

  // Handles location permissions and fetching coordinates/address
  Future<Map<String, dynamic>?> _getLocationData() async {
    // If updating an existing report, use the existing location data
    if (widget.reportId != null) {
      return {
        'geopoint': widget.existingData!['geopoint'],
        'location': widget.existingData!['location'],
      };
    }

    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable them to proceed.')));
      }
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are required to submit a report.')));
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in your device settings.')));
      }
      return null;
    }

    try {
      // Get current position (latitude, longitude)
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      String address = "${place.name}, ${place.locality}, ${place.country}";

      // Return both GeoPoint for map data and String for display
      return {
        'geopoint': GeoPoint(position.latitude, position.longitude),
        'location': address,
      };
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error getting location: $e')),
        );
      }
      return null;
    }
  }

  // Share functionality to share report link
  Future<void> _shareReport() async {
    if (widget.reportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the report before sharing')),
      );
      return;
    }

    // In a real app, you would use your actual app domain and deep linking
    const appDomain = 'https://smartcivicwatch.com';
    final reportLink = '$appDomain/reports/${widget.reportId}';

    try {
      await Share.share(
        'Check out this incident report on Smart Civic Watch: $reportLink',
        subject: 'Incident Report on Smart Civic Watch',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing report: $e')),
      );
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Get location data
    final locationData = await _getLocationData();

    // If location is null (permission denied or error), stop the submission process.
    if (locationData == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      String? mediaUrl;

      // Upload media to Firebase Storage if a new file is selected
      if (_mediaFile != null) {
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${_isVideo ? 'video' : 'image'}";
        final ref =
        FirebaseStorage.instance.ref().child('reports').child(fileName);

        await ref.putFile(_mediaFile!);
        mediaUrl = await ref.getDownloadURL();
      } else if (_existingMediaUrl != null) {
        // Use existing media URL if no new media is selected
        mediaUrl = _existingMediaUrl;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final reportData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'media_url': mediaUrl,
        'is_video': _isVideo,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser?.uid,
        'userEmail': currentUser?.email,
        // Change from 'likes' to 'votes' for funding prioritization
        'votes': widget.existingData?['votes'] ?? widget.existingData?['likes'] ?? 0,
        'comments': widget.existingData?['comments'] ?? 0,
        'status': widget.existingData?['status'] ?? 'pending',
        'location': locationData['location'],
        'geopoint': locationData['geopoint'],
      };

      if (widget.reportId != null) {
        // Update existing report
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(widget.reportId)
            .update(reportData);
      } else {
        // Create new report
        await FirebaseFirestore.instance.collection('reports').add(reportData);
      }

      if (!mounted) return;
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            widget.reportId != null
                ? '✅ Report updated successfully'
                : '✅ Report submitted successfully'
        )),
      );

      // Return to previous screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reportId != null ? "Update Report" : "Report Incident"),
        backgroundColor: const Color(0xFF3E8EDE),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Share button for existing reports
          if (widget.reportId != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareReport,
              tooltip: 'Share this report',
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3E8EDE), Color(0xFF00BCD4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Title input field
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Title",
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (value) =>
                          value!.isEmpty ? 'Please enter a title' : null,
                        ),
                        const SizedBox(height: 16),

                        // Description input field
                        TextFormField(
                          controller: _descriptionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Description",
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          maxLines: 4,
                          validator: (value) =>
                          value!.isEmpty ? 'Please enter a description' : null,
                        ),
                        const SizedBox(height: 20),

                        // Show existing media if updating a report
                        if (widget.existingData != null && _existingMediaUrl != null && _mediaFile == null)
                          Column(
                            children: [
                              const Text(
                                "Current Media:",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              widget.existingData!['is_video']
                                  ? AspectRatio(
                                aspectRatio: 16/9,
                                child: Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(Icons.videocam, color: Colors.white, size: 50),
                                  ),
                                ),
                              )
                                  : Image.network(_existingMediaUrl!, height: 200, fit: BoxFit.cover),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Media preview section for new media
                        if (_mediaFile != null)
                          _isVideo && _videoController != null && _videoController!.value.isInitialized
                              ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: Stack(
                              children: [
                                VideoPlayer(_videoController!),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    child: IconButton(
                                      icon: Icon(
                                        _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (_videoController!.value.isPlaying) {
                                            _videoController!.pause();
                                          } else {
                                            _videoController!.play();
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                              : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_mediaFile!, height: 200, fit: BoxFit.cover),
                          ),
                        if (_mediaFile != null) const SizedBox(height: 16),

                        // Media selection dropdown
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedMediaOption,
                              hint: const Text(
                                'Select Media Source',
                                style: TextStyle(color: Colors.white70),
                              ),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              isExpanded: true,
                              style: const TextStyle(color: Colors.white),
                              dropdownColor: const Color(0xFF3E8EDE),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedMediaOption = newValue;
                                });

                                if (newValue != null) {
                                  final selectedOption = _mediaOptions.firstWhere(
                                        (option) => option['value'] == newValue,
                                  );

                                  _pickMedia(
                                    selectedOption['source'],
                                    isVideo: selectedOption['isVideo'],
                                  );
                                }
                              },
                              items: _mediaOptions.map<DropdownMenuItem<String>>((option) {
                                return DropdownMenuItem<String>(
                                  value: option['value'],
                                  child: Row(
                                    children: [
                                      Icon(option['icon'], color: Colors.white),
                                      const SizedBox(width: 12),
                                      Text(option['label'], style: const TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Clear media button
                        if (_mediaFile != null || _existingMediaUrl != null)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _mediaFile = null;
                                _selectedMediaOption = null;
                                _existingMediaUrl = null;
                                _videoController?.dispose();
                                _videoController = null;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text("Remove Media"),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Submit button at the bottom of the screen
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    elevation: 4,
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                      : Text(
                    widget.reportId != null ? "Update Report" : "Submit Report",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen for displaying emergency alerts and reports
class EmergencyAlertsScreen extends StatefulWidget {
  const EmergencyAlertsScreen({super.key});

  @override
  State<EmergencyAlertsScreen> createState() => _EmergencyAlertsScreenState();
}

class _EmergencyAlertsScreenState extends State<EmergencyAlertsScreen> {
  // Page controller for tab navigation
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  // Get current authenticated user
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Returns color based on report status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in-progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize page controller to the correct index after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.jumpToPage(_currentIndex);
    });
  }

  @override
  void dispose() {
    // Clean up page controller
    _pageController.dispose();
    super.dispose();
  }

  // Toggles vote status for a report
  Future<void> _toggleVote(String reportId, bool isCurrentlyVoted, int currentVotes) async {
    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'isVoted': !isCurrentlyVoted,
        'votes': isCurrentlyVoted ? currentVotes - 1 : currentVotes + 1,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating vote: $e')),
        );
      }
    }
  }

  // Shows comments bottom sheet for a report
  void _showComments(BuildContext context, String reportId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const Text('Comments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .doc(reportId)
                    .collection('comments')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No comments yet. Be the first to comment!'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final comment = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(comment['userName'] ?? 'Anonymous'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(comment['text'] ?? ''),
                            const SizedBox(height: 4),
                            Text(
                              comment['timestamp'] != null
                                  ? DateFormat('MMM dd, yyyy - hh:mm a').format(
                                  (comment['timestamp'] as Timestamp).toDate())
                                  : '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Comment input field
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _addComment(reportId, value.trim());
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Adds a new comment to a report
  Future<void> _addComment(String reportId, String text) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .collection('comments')
          .add({
        'text': text,
        'userName': _currentUser?.displayName ?? 'Anonymous',
        'userId': _currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'comments': FieldValue.increment(1),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

  // Deletes a report from Firestore
  Future<void> _deleteReport(String reportId) async {
    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting report: $e')),
        );
      }
    }
  }

  // Navigates to update report screen
  void _updateReport(DocumentSnapshot document) {
    final report = document.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportIncidentScreen(
          reportId: document.id,
          existingData: report,
        ),
      ),
    );
  }

  // Shares a report via URL
  Future<void> _shareReport(String reportId, String title) async {
    try {
      const appDomain = 'https://smartcivicwatch.com';
      final reportLink = '$appDomain/reports/$reportId';

      await Share.share(
        'Check out this incident report: "$title" on Smart Civic Watch: $reportLink',
        subject: 'Incident Report on Smart Civic Watch',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: ${e.toString()}')),
        );
      }
    }
  }

  // Builds a standardized action button
  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, Color? color) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
    );
  }

  // Shows detailed preview of a report
  void _showReportPreview(BuildContext context, DocumentSnapshot document) {
    final report = document.data() as Map<String, dynamic>;
    final timestamp = report['timestamp'] as Timestamp?;
    final date = timestamp != null ? timestamp.toDate() : DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            // Media preview section
            if (report['media_url'] != null && report['media_url'].isNotEmpty)
              Expanded(
                child: report['is_video'] == true
                    ? _VideoPreview(videoUrl: report['media_url'])
                    : CachedNetworkImage(
                  imageUrl: report['media_url'],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error, color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.warning_amber, size: 40, color: Colors.amber),
                ),
              ),
            const SizedBox(height: 16),
            // Report details section
            Text(
              report['title'] ?? report['description'] ?? 'No description',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              report['description'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            // Metadata section
            if (report['location'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report['location'],
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (report['userEmail'] != null)
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Reported by: ${report['userEmail']}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Builds a report card widget

  Widget _buildReportCard(DocumentSnapshot document, BuildContext context) {
    final report = document.data() as Map<String, dynamic>;
    final timestamp = report['timestamp'] as Timestamp?;
    final date = timestamp != null ? timestamp.toDate() : DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    final isMyReport = _currentUser != null && report['userId'] == _currentUser!.uid;
    final status = report['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showReportPreview(context, document),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media section (unchanged)
            if (report['media_url'] != null && report['media_url'].isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: report['is_video'] == true
                    ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      color: Colors.grey[200],
                      height: 200,
                      child: const Icon(Icons.play_circle_filled,
                          size: 50, color: Colors.white70),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'VIDEO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    : CachedNetworkImage(
                  imageUrl: report['media_url'],
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    height: 200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Image not available',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: const Center(child: Icon(Icons.warning_amber, size: 40, color: Colors.amber)),
              ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          report['title'] ?? report['description'] ?? 'No description',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(isMyReport ? 'My Report' : 'Community'),
                        backgroundColor: isMyReport ? Colors.blue[100] : Colors.green[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report['description'] ?? '',
                    style: const TextStyle(fontSize: 16),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      Chip(
                        label: Text(
                          status.toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                        backgroundColor: _getStatusColor(status),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Action buttons row - REMOVED VOTING BUTTON
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Comment button
                      _buildActionButton(
                        Icons.comment,
                        '${report['comments'] ?? 0}',
                            () => _showComments(context, document.id),
                        Colors.grey,
                      ),
                      // Share button
                      _buildActionButton(
                        Icons.share,
                        'Share',
                            () => _shareReport(document.id, report['title'] ?? 'Incident Report'),
                        Colors.grey,
                      ),
                      // Update button (only for my reports)
                      if (isMyReport)
                        _buildActionButton(
                          Icons.edit,
                          'Update',
                              () => _updateReport(document),
                          Colors.blue,
                        ),
                      // Delete button (only for my reports)
                      if (isMyReport)
                        _buildActionButton(
                          Icons.delete,
                          'Delete',
                              () => _showDeleteDialog(context, document.id),
                          Colors.red,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  // Shows confirmation dialog for report deletion
  void _showDeleteDialog(BuildContext context, String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReport(reportId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Builds empty state widget
  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alerts'),
        backgroundColor: const Color(0xFF283593),
        elevation: 4,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCategoryButton('My Reports', 0),
                  _buildCategoryButton('Community', 1),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading reports: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return _buildEmptyState(Icons.error, 'Failed to load reports');
          }

          final allReports = snapshot.data!.docs;

          // Filter reports based on current tab and user ID
          final myReports = _currentIndex == 0
              ? allReports.where((doc) => _currentUser != null && doc['userId'] == _currentUser!.uid).toList()
              : allReports.where((doc) => _currentUser != null && doc['userId'] != _currentUser!.uid).toList();

          return PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            children: [
              // My Reports Page
              _currentIndex == 0
                  ? (myReports.isEmpty
                  ? _buildEmptyState(Icons.report_problem, 'No reports from you yet')
                  : ListView.builder(
                itemCount: myReports.length,
                itemBuilder: (context, index) {
                  return _buildReportCard(myReports[index], context);
                },
              ))
                  : (myReports.isEmpty
                  ? _buildEmptyState(Icons.people, 'No community reports yet')
                  : ListView.builder(
                itemCount: myReports.length,
                itemBuilder: (context, index) {
                  return _buildReportCard(myReports[index], context);
                },
              )),
            ],
          );
        },
      ),
    );
  }

  // Builds category tab button
  Widget _buildCategoryButton(String title, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: isSelected ? Colors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () {
              setState(() {
                _currentIndex = index;
              });
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.center,
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget for video preview in report details
class _VideoPreview extends StatefulWidget {
  final String videoUrl;

  const _VideoPreview({required this.videoUrl});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl);
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      setState(() {});
    });

    _controller.addListener(() {
      if (_controller.value.isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              if (!_isPlaying)
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 50, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _controller.play();
                      _isPlaying = true;
                    });
                  },
                ),
              if (_isPlaying)
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.red,
                      bufferedColor: Colors.grey,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}