import 'package:flutter/material.dart';

/// Admin clinic configuration (placeholder for future settings).
class AdminClinicSettingsPage extends StatelessWidget {
  const AdminClinicSettingsPage({super.key});

  static const Color _navy = Color(0xFF0D1B2A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Settings'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hospital Kajang — OrthoQ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Clinic hours, notification templates, and referral rules '
                    'can be configured here in a future release.',
                    style: TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF4A5568)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.access_time, color: _navy),
            title: const Text('Default session length'),
            subtitle: const Text('15 minutes'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.location_on_outlined, color: _navy),
            title: const Text('Location'),
            subtitle: const Text('Orthopaedic Outpatient Clinic, Hospital Kajang'),
          ),
        ],
      ),
    );
  }
}
