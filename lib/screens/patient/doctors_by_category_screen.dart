import 'package:flutter/material.dart';
import '../../services/doctor_service.dart';
import '../../models/doctor_model.dart';

class DoctorsByCategoryScreen extends StatelessWidget {
  final String category;

  const DoctorsByCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final doctorService = DoctorService();

    return Scaffold(
      appBar: AppBar(
        title: Text('$category Doctors'),
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: StreamBuilder<List<DoctorModel>>(
        stream: doctorService.getDoctorsBySpecialization(category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final doctors = snapshot.data ?? [];

          if (doctors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No doctors found in $category',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF1A365D),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 30,
                    ),
                  ),
                  title: Text(
                    'Dr. ${doctor.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    doctor.specialization,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Navigate to doctor details or booking
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Dr. ${doctor.name} - ${doctor.specialization}'),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

















