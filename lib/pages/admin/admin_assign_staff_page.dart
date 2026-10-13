import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';

/// Assign exactly three doctor document IDs to a staff user's `assignedDoctorIds`.
class AdminAssignStaffPage extends StatefulWidget {
  const AdminAssignStaffPage({super.key});

  @override
  State<AdminAssignStaffPage> createState() => _AdminAssignStaffPageState();
}

class _AdminAssignStaffPageState extends State<AdminAssignStaffPage> {
  static const Color _navy = OrthoqColors.slateNavy;
  static const int _kRequiredDoctors = 3;

  String? _selectedStaffId;
  final Set<String> _selectedDoctorIds = {};
  bool _saving = false;

  Future<void> _save() async {
    if (_selectedStaffId == null || _selectedStaffId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a staff member first')),
      );
      return;
    }
    if (_selectedDoctorIds.length != _kRequiredDoctors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pick exactly $_kRequiredDoctors doctors (you have ${_selectedDoctorIds.length}).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ids = _selectedDoctorIds.toList();
      await FirebaseFirestore.instance.collection('users').doc(_selectedStaffId).update({
        'assignedDoctorIds': ids,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff assignment saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e\n(Staff must exist in users; Firebase admin rules apply.)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleDoctor(String doctorId, bool? checked) {
    if (checked == true) {
      if (_selectedDoctorIds.length >= _kRequiredDoctors &&
          !_selectedDoctorIds.contains(doctorId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only select 3 doctors. Uncheck one first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _selectedDoctorIds.add(doctorId));
    } else {
      setState(() => _selectedDoctorIds.remove(doctorId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorService = DoctorService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Staff'),
        backgroundColor: _navy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Step 1: Staff member',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'staff')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Text('Could not load staff: ${snap.error}', style: const TextStyle(color: Colors.red));
                      }
                      if (!snap.hasData) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No users with role "staff". Register a staff account first.',
                              style: TextStyle(color: Colors.grey.shade800),
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Staff',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedStaffId,
                            hint: const Text('Select staff'),
                            items: docs.map((d) {
                              final name = d.data()['fullName']?.toString().trim().isNotEmpty == true
                                  ? d.data()['fullName'].toString()
                                  : d.data()['email']?.toString() ?? d.id;
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(name, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedStaffId = v),
                          ),
                          Divider(height: 1, color: Colors.grey.shade400),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Step 2: Pick exactly 3 doctors',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selected: ${_selectedDoctorIds.length} / $_kRequiredDoctors',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<DoctorModel>>(
                    stream: doctorService.getActiveDoctors(),
                    builder: (context, docSnap) {
                      if (docSnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (docSnap.hasError) {
                        return Text('${docSnap.error}', style: const TextStyle(color: Colors.red));
                      }
                      final doctors = docSnap.data ?? [];
                      if (doctors.isEmpty) {
                        return const Text('No active doctors.');
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: doctors.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final d = doctors[i];
                          final checked = _selectedDoctorIds.contains(d.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) => _toggleDoctor(d.id, v),
                            title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              d.specialization,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Step 3: Save assignment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
