import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';

class ManageDelaysPage extends StatefulWidget {
  const ManageDelaysPage({super.key});

  @override
  State<ManageDelaysPage> createState() => _ManageDelaysPageState();
}

class _ManageDelaysPageState extends State<ManageDelaysPage> {
  final DoctorService _doctorService = DoctorService();
  String? _selectedDoctorId;
  final TextEditingController _delayMinutesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _delayMinutesController.dispose();
    super.dispose();
  }

  Future<void> _submitDelay() async {
    if (_selectedDoctorId == null || _selectedDoctorId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final delayMinutes = int.tryParse(_delayMinutesController.text.trim());
    if (delayMinutes == null || delayMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid delay in minutes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Update doctor's delay field
      final doctorRef = firestore.collection('doctors').doc(_selectedDoctorId);
      batch.update(doctorRef, {
        'delayMinutes': delayMinutes,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Get today's date range
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Query all appointments for this doctor today
      final appointmentsQuery = await firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: _selectedDoctorId)
          .where('appointmentDate', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentDate', isLessThan: endOfDay)
          .get();

      // Update all appointments to 'delayed' status
      for (var doc in appointmentsQuery.docs) {
        final appointmentRef = firestore.collection('appointments').doc(doc.id);
        batch.update(appointmentRef, {
          'status': 'delayed',
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // Commit the batch
      await batch.commit();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delay updated successfully. ${appointmentsQuery.docs.length} appointment(s) marked as delayed.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear form
        setState(() {
          _selectedDoctorId = null;
          _delayMinutesController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating delay: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Delays'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'When you submit a delay, all appointments for the selected doctor today will be marked as "delayed".',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Doctor Selection
            const Text(
              'Select Doctor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<DoctorModel>>(
              stream: _doctorService.getActiveDoctors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );
                }

                final doctors = snapshot.data ?? [];
                if (doctors.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No active doctors found'),
                    ),
                  );
                }

                return Card(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDoctorId,
                    decoration: const InputDecoration(
                      labelText: 'Doctor',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: doctors.map((doctor) {
                      return DropdownMenuItem<String>(
                        value: doctor.id,
                        child: Text('Dr. ${doctor.name} - ${doctor.specialization}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDoctorId = value;
                      });
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Delay Minutes Input
            const Text(
              'Delay Minutes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: TextField(
                controller: _delayMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enter delay in minutes (e.g., 30)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDelay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrthoqColors.slateNavy,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Text(
                        'Submit Delay',
                        style: TextStyle(
                          fontSize: 16,
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


