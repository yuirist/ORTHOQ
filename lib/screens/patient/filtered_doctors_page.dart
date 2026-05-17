import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import 'doctor_detail_page.dart';

class FilteredDoctorsPage extends StatelessWidget {
  final String selectedCategory;

  const FilteredDoctorsPage({
    super.key,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    final doctorsStream = FirebaseFirestore.instance
        .collection('doctors')
        .where('specialization', isEqualTo: selectedCategory)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(selectedCategory),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: doctorsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: OrthoqColors.techBlue,
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Something went wrong while loading doctors.',
                style: TextStyle(color: Colors.black87),
              ),
            );
          }

          final rawDocs = snapshot.data?.docs ?? [];
          final doctors = rawDocs.where((doc) {
            final data = doc.data();
            final a = data['isActive'];
            if (a is bool) return a;
            if (a == null) return true;
            return a.toString().toLowerCase() == 'true';
          }).toList();

          if (doctors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.person_off_outlined,
                      size: 64,
                      color: OrthoqColors.techBlue,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No specialists available for this category at the moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final docSnap = doctors[index];
              final data = docSnap.data();
              final doctorName = (data['name'] as String?)?.trim().isNotEmpty == true
                  ? data['name'] as String
                  : 'Unknown Doctor';
              final doctorSpecialty =
                  (data['specialization'] as String?)?.trim().isNotEmpty == true
                      ? data['specialization'] as String
                      : selectedCategory;
              final imageUrl = data['imageUrl'] as String?;

              return Card(
                color: Colors.white,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DoctorCardAvatar(imageUrl: imageUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dr. $doctorName',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doctorSpecialty,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4A5568),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => DoctorDetailPage(
                                  doctorId: docSnap.id,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OrthoqColors.techBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'See Details',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DoctorCardAvatar extends StatelessWidget {
  final String? imageUrl;

  const _DoctorCardAvatar({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    const radius = 28.0;

    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE6F2FF),
        child: const Icon(
          Icons.person,
          size: 32,
          color: OrthoqColors.techBlue,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE6F2FF),
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OrthoqColors.techBlue,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person,
              size: 32,
              color: OrthoqColors.techBlue,
            );
          },
        ),
      ),
    );
  }
}
