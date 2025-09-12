import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

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

  // Toggles like status for a report
  Future<void> _toggleLike(String reportId, bool isCurrentlyLiked, int currentLikes) async {
    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'isLiked': !isCurrentlyLiked,
        'likes': isCurrentlyLiked ? currentLikes - 1 : currentLikes + 1,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: $e')),
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

  // Shares a report via URL
  Future<void> _shareReport(Map<String, dynamic> report) async {
    try {
      final Uri shareUri = Uri(
        scheme: 'https',
        host: 'smartcivicwatch.com',
        path: '/alerts/${report['id']}',
        queryParameters: {'utm_source': 'app_share'},
      );

      if (await canLaunchUrl(shareUri)) {
        await launchUrl(shareUri);
      } else {
        throw 'Could not launch share URL';
      }
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
            if (report['reportedBy'] != null)
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Reported by: ${report['reportedBy']}',
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
    final status = report['status'] ?? 'pending'; // Default to 'pending' if status is not set

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showReportPreview(context, document),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media section
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
                  // Action buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        report['isLiked'] == true ? Icons.favorite : Icons.favorite_border,
                        '${report['likes'] ?? 0}',
                            () => _toggleLike(document.id, report['isLiked'] ?? false, report['likes'] ?? 0),
                        report['isLiked'] == true ? Colors.red : Colors.grey,
                      ),
                      _buildActionButton(
                        Icons.comment,
                        '${report['comments'] ?? 0}',
                            () => _showComments(context, document.id),
                        Colors.grey,
                      ),
                      _buildActionButton(
                        Icons.share,
                        'Share',
                            () => _shareReport(report),
                        Colors.grey,
                      ),
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