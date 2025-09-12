import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Screen for managing emergency contacts with calling functionality
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for fade-in effect
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  // Controllers for text input fields
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();

  // Default emergency contacts list
  List<Map<String, String>> contacts = [
    {'name': 'Police', 'number': '991'},
    {'name': 'Fire Brigade', 'number': '993'},
    {'name': 'Ambulance', 'number': '999'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize animation controller and fade animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    // Clean up animation controller and text controllers
    _controller.dispose();
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  // Function to initiate a phone call
  Future<void> _makeCall(String number) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'Could not launch phone app';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Shows dialog to add a new emergency contact
  void _addNewContact() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Contact'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name input field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Contact Name'),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Name is required' : null,
              ),
              // Phone number input field
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                value?.isEmpty ?? true ? 'Number is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Save button
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                setState(() {
                  contacts.add({
                    'name': _nameController.text,
                    'number': _numberController.text
                  });
                });
                _nameController.clear();
                _numberController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Builds a contact card widget
  Widget _buildContactCard(Map<String, String> contact) {
    return InkWell(
      splashColor: Colors.indigo.withOpacity(0.2),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _makeCall(contact['number']!),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: Colors.indigo.withOpacity(0.3),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          leading: CircleAvatar(
            backgroundColor: Colors.indigo.shade700,
            child: const Icon(Icons.phone, color: Colors.white),
          ),
          title: Text(
            contact['name']!,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          subtitle: Text(
            contact['number']!,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.call, color: Colors.indigo),
            onPressed: () => _makeCall(contact['number']!),
            tooltip: 'Call ${contact['name']}',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: const Color(0xFF283593),
        elevation: 10,
        shadowColor: Colors.indigoAccent.withOpacity(0.6),
        actions: [
          // Add contact button in app bar
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add new contact',
            onPressed: _addNewContact,
          ),
        ],
      ),
      // Floating action button for adding new contacts
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewContact,
        child: const Icon(Icons.add),
        tooltip: 'Add new emergency contact',
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF283593), Color(0xFF1976D2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          // List of emergency contacts
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 20),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              return _buildContactCard(contacts[index]);
            },
          ),
        ),
      ),
    );
  }
}