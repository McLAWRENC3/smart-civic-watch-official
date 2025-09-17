import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:share_plus/share_plus.dart'; // Added for sharing functionality

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