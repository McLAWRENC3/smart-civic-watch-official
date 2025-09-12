import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Screen widget for handling donations and rewards
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  // Get current authenticated user
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  // Controller for custom donation amount input
  final _donationAmountController = TextEditingController();
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  // Default selected donation amount
  double _selectedAmount = 10.0;
  // Loading state for donation process
  bool _isDonating = false;

  // Available payment methods
  final List<String> _paymentMethods = ['Credit Card', 'PayPal', 'Mobile Money'];
  String _selectedPaymentMethod = 'Credit Card';

  @override
  void dispose() {
    // Clean up controller when widget is disposed
    _donationAmountController.dispose();
    super.dispose();
  }

  // Handles the donation process
  Future<void> _makeDonation(double amount, String paymentMethod) async {
    // Check if user is authenticated
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make a donation')),
      );
      return;
    }

    setState(() {
      _isDonating = true;
    });

    try {
      // Simulate payment processing (would integrate with payment gateway in real app)
      // Save donation record to Firestore
      await FirebaseFirestore.instance.collection('donations').add({
        'userId': _currentUser!.uid,
        'userEmail': _currentUser!.email,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thank you for your donation of \$$amount!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form fields
      _donationAmountController.clear();
      setState(() {
        _selectedAmount = 10.0;
      });
    } catch (e) {
      // Show error message if donation fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Donation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDonating = false;
      });
    }
  }

  // Shows donation dialog with amount and payment method options
  void _showDonationDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Make a Donation'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Select donation amount:'),
                    const SizedBox(height: 16),
                    // Quick-select amount chips
                    Wrap(
                      spacing: 8,
                      children: [5.0, 10.0, 25.0, 50.0, 100.0].map((amount) {
                        return ChoiceChip(
                          label: Text('\$$amount'),
                          selected: _selectedAmount == amount,
                          onSelected: (selected) {
                            setState(() {
                              _selectedAmount = amount;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Custom amount input field
                    TextFormField(
                      controller: _donationAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Or enter custom amount',
                        prefixText: '\$',
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _selectedAmount = double.tryParse(value) ?? 0.0;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Select payment method:'),
                    const SizedBox(height: 8),
                    // Payment method dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              // Donate button
              ElevatedButton(
                onPressed: _isDonating
                    ? null
                    : () async {
                  if (_selectedAmount > 0) {
                    Navigator.pop(context);
                    await _makeDonation(
                        _selectedAmount, _selectedPaymentMethod);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a valid amount')),
                    );
                  }
                },
                child: _isDonating
                    ? const CircularProgressIndicator()
                    : const Text('Donate'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Builds individual donation history card
  Widget _buildDonationCard(Map<String, dynamic> donation) {
    // Format donation timestamp
    final timestamp = donation['timestamp'] as Timestamp?;
    final date = timestamp != null ? timestamp.toDate() : DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: const Icon(Icons.attach_money, color: Colors.green),
        ),
        title: Text(
          '${donation['userEmail']?.toString().split('@')[0] ?? 'Anonymous'} donated \$${donation['amount']?.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Via ${donation['paymentMethod']} • $formattedDate'),
            if (donation['status'] != null)
            // Display donation status chip
              Chip(
                label: Text(
                  donation['status'].toString().toUpperCase(),
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: donation['status'] == 'completed'
                    ? Colors.green[100]
                    : Colors.orange[100],
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  // Builds reward card with icon and description
  Widget _buildRewardCard(String reward, int index) {
    // Determine icon and color based on index
    IconData icon;
    Color color;

    switch (index % 3) {
      case 0:
        icon = Icons.card_membership;
        color = Colors.blue;
        break;
      case 1:
        icon = Icons.local_offer;
        color = Colors.orange;
        break;
      case 2:
        icon = Icons.verified;
        color = Colors.purple;
        break;
      default:
        icon = Icons.star;
        color = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          reward,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Earn this reward by making regular donations',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Show reward details dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(reward),
              content: Text(
                'This reward is available to community members who regularly support civic improvements through donations.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donations & Rewards"),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header section with donation call-to-action
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.volunteer_activism, size: 50, color: Colors.green),
                const SizedBox(height: 10),
                const Text(
                  "Support Your Community",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your donations help improve civic infrastructure and emergency response in your area",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // Donation button
                ElevatedButton.icon(
                  onPressed: _showDonationDialog,
                  icon: const Icon(Icons.attach_money),
                  label: const Text('Make a Donation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          // Tabbed section for donations and rewards
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Recent Donations'),
                      Tab(text: 'Rewards'),
                    ],
                    indicatorColor: Colors.green,
                    labelColor: Colors.green,
                    unselectedLabelColor: Colors.grey,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Donations history tab
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('donations')
                              .orderBy('timestamp', descending: true)
                              .limit(20)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.attach_money, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No donations yet',
                                      style: TextStyle(fontSize: 18, color: Colors.grey),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Be the first to support your community!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView(
                              padding: const EdgeInsets.all(16),
                              children: snapshot.data!.docs.map((doc) {
                                return _buildDonationCard(doc.data() as Map<String, dynamic>);
                              }).toList(),
                            );
                          },
                        ),
                        // Rewards catalog tab
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildRewardCard('Certificate of Appreciation', 0),
                            _buildRewardCard('Discount Coupon at Local Businesses', 1),
                            _buildRewardCard('Community Recognition Badge', 2),
                            _buildRewardCard('Early Access to New Features', 3),
                            _buildRewardCard('Exclusive Community Events', 4),
                            _buildRewardCard('Personalized Thank You Message', 5),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}