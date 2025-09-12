import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

// Screen for reporting incidents with media (images or videos)
class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

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

  // Submits the incident report to Firebase
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      String? mediaUrl;

      // Upload media to Firebase Storage if a file is selected
      if (_mediaFile != null) {
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${_isVideo ? 'video' : 'image'}";
        final ref =
        FirebaseStorage.instance.ref().child('reports').child(fileName);

        await ref.putFile(_mediaFile!);
        mediaUrl = await ref.getDownloadURL();
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      // Save report data to Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'media_url': mediaUrl,
        'is_video': _isVideo,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser?.uid,
        'userEmail': currentUser?.email, // Add user email to the report
        'likes': 0,
        'comments': 0,
        'isLiked': false,
        'status': 'pending', // Add default status
      });

      if (!mounted) return;
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Report submitted successfully')),
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
        title: const Text("Report Incident"),
        backgroundColor: const Color(0xFF3E8EDE),
        foregroundColor: Colors.white,
        elevation: 0,
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

                        // Media preview section
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
                        if (_mediaFile != null)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _mediaFile = null;
                                _selectedMediaOption = null;
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
                      : const Text(
                    "Submit Report",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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