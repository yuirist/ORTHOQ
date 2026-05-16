import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';

class DoctorManagementPage extends StatefulWidget {
  const DoctorManagementPage({super.key, this.userProfile});

  final UserModel? userProfile;

  @override
  State<DoctorManagementPage> createState() => _DoctorManagementPageState();
}

class _DoctorManagementPageState extends State<DoctorManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _staffUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final staffUserId = _staffUserId;

    if (staffUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Staff user not authenticated.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Staff Profile'),
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('staff').doc(staffUserId).snapshots(),
        builder: (context, staffSnapshot) {
          if (staffSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final staffData = staffSnapshot.data?.data() ?? <String, dynamic>{};
          final staffEmail = widget.userProfile?.email.trim().isNotEmpty == true
              ? widget.userProfile!.email.trim()
              : FirebaseAuth.instance.currentUser?.email ?? '';
          final staffRole = widget.userProfile?.role.trim().isNotEmpty == true
              ? widget.userProfile!.role.trim()
              : (staffData['role']?.toString().trim().isNotEmpty ?? false)
                  ? staffData['role'].toString().trim()
                  : 'Clinic Assistant';
          final displayName =
              widget.userProfile?.fullName.trim().isNotEmpty == true
                  ? widget.userProfile!.fullName.trim()
                  : staffEmail;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Color(0xFF1A365D),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (displayName != staffEmail && staffEmail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          staffEmail,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        staffRole,
                        style: const TextStyle(
                          color: Color(0xFF1A365D),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Assigned Doctors',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A365D),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore.collection('doctors').snapshots(),
                    builder: (context, doctorSnapshot) {
                      if (doctorSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (doctorSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading doctors: ${doctorSnapshot.error}',
                            style: const TextStyle(color: Color(0xFFC53030)),
                          ),
                        );
                      }

                      final doctors = doctorSnapshot.data?.docs ?? [];

                      if (doctors.isEmpty) {
                        return const Card(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No doctors found in Firebase collection.'),
                            ),
                          ),
                        );
                      }

                      return Card(
                        child: ListView.separated(
                          itemCount: doctors.length < 3 ? doctors.length : 3,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final doctorData = doctors[index].data();
                            final doctorName =
                                doctorData['name']?.toString().trim() ?? 'Unknown Doctor';
                            final specialization =
                                doctorData['specialization']?.toString().trim().isNotEmpty ==
                                        true
                                    ? doctorData['specialization'].toString().trim()
                                    : 'Orthopaedic';
                            final imageUrl = doctorData['imageUrl']?.toString().trim();

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFE6F2FF),
                                child: (imageUrl != null && imageUrl.isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          imageUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.medical_services_outlined,
                                              color: Color(0xFF1A365D),
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.medical_services_outlined,
                                        color: Color(0xFF1A365D),
                                      ),
                              ),
                              title: Text(
                                'Dr. $doctorName',
                                style: const TextStyle(
                                  color: Color(0xFF1A365D),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                specialization,
                                style: const TextStyle(
                                  color: Color(0xFF1A365D),
                                  fontSize: 13,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
