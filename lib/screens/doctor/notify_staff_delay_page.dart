import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class NotifyStaffDelayPage extends StatefulWidget {
  const NotifyStaffDelayPage({super.key});

  @override
  State<NotifyStaffDelayPage> createState() => _NotifyStaffDelayPageState();
}

class _NotifyStaffDelayPageState extends State<NotifyStaffDelayPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _send() async {
    final doctorName =
        Provider.of<AuthProvider>(context, listen: false).currentUserData?.fullName.trim() ?? '';
    final doctorId = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
    final message = _messageController.text.trim();

    if (doctorName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor profile unavailable.')),
      );
      return;
    }
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delay message.')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final normalizedDate =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      await FirebaseFirestore.instance.collection('reschedule_requests').add({
        'type': 'doctor_delay',
        'status': 'pending_staff_action',
        'sender': doctorName,
        'doctorName': doctorName,
        'doctorId': doctorId,
        'message': message,
        'date': Timestamp.fromDate(normalizedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delay alert sent to staff.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send delay alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notify Staff of Delay'),
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: const Text('Date'),
                subtitle: Text(DateFormat('EEEE, MMM d, y').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_month, color: Color(0xFF1A365D)),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Delay Message',
                hintText:
                    'Emergency surgery at Hospital Kajang, starting clinic 1 hour late',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A365D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _isSending ? 'Sending...' : 'Send',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
