import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../../widgets/doctor_avatar.dart';

class DoctorDetailsPage extends StatelessWidget {
  final String doctorId;

  const DoctorDetailsPage({
    super.key,
    required this.doctorId,
  });

  static String? _bioFromData(Map<String, dynamic> data) {
    for (final key in ['bio', 'description', 'about', 'profile']) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('doctors').doc(doctorId);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Doctor profile'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: OrthoqColors.techBlue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load this doctor: ${snapshot.error}',
                style: const TextStyle(color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            );
          }

          final doc = snapshot.data;
          if (doc == null || !doc.exists || doc.data() == null) {
            return const Center(
              child: Text(
                'Doctor not found.',
                style: TextStyle(color: Colors.black87),
              ),
            );
          }

          final data = doc.data()!;
          final name = (data['name'] as String?)?.trim().isNotEmpty == true
              ? data['name'] as String
              : 'Unknown Doctor';
          final specialization =
              (data['specialization'] as String?)?.trim().isNotEmpty == true
                  ? data['specialization'] as String
                  : '—';
          final imageUrl = data['imageUrl'] as String?;
          final bio = _bioFromData(data);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: DoctorHeaderImage(imageUrl: imageUrl),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. $name',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: OrthoqColors.slateNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        specialization,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4A5568),
                          height: 1.35,
                        ),
                      ),
                      if (bio != null) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'About',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF4A5568),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
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
