import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import 'filtered_doctors_page.dart';

/// Display labels shown in the UI; values must match Firestore `specialization`.
class _CategoryEntry {
  final String displayLabel;
  final String firestoreSpecialization;

  const _CategoryEntry({
    required this.displayLabel,
    required this.firestoreSpecialization,
  });
}

class AllCategoriesPage extends StatelessWidget {
  const AllCategoriesPage({super.key});

  static const List<_CategoryEntry> _categories = [
    _CategoryEntry(
      displayLabel: 'Hand Surgeon',
      firestoreSpecialization: 'Orthopaedic (Hand Surgeon)',
    ),
    _CategoryEntry(
      displayLabel: 'Spine Surgery',
      firestoreSpecialization: 'Orthopaedic (Spine Surgery)',
    ),
    _CategoryEntry(
      displayLabel: 'Foot and Ankle',
      firestoreSpecialization: 'Orthopaedic (Foot & Ankle)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('All categories'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = _categories[index];
          return Material(
            color: Colors.white,
            elevation: 1,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => FilteredDoctorsPage(
                      selectedCategory: entry.firestoreSpecialization,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      color: OrthoqColors.techBlue,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        entry.displayLabel,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF4A5568),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
