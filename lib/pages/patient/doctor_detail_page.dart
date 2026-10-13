import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../../widgets/doctor_avatar.dart';

class DoctorDetailPage extends StatelessWidget {
  final String doctorId;

  const DoctorDetailPage({
    super.key,
    required this.doctorId,
  });

  static const Map<String, String> _credentialFallbackByName = {
    'DR JAMAL BIN KASSIM': 'MBBCh (Ain Shams Uni), M.Med (Ortho) (USM)',
    'DR SITI MAIMUNAH BINTI AHMAD':
        'MD (UKM), MS ORTH (UKM), Fellow in Hand Surgery (Singapore)',
    'DR HALIM BIN TONGKOL': 'MBBS (Monash), MS Ortho (UM), CMIA(NIOSH)',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('doctors')
              .doc(doctorId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Unable to load doctor: ${snapshot.error}'));
            }

            final data = snapshot.data?.data();
            if (data == null) {
              return const Center(child: Text('Doctor profile not found.'));
            }

            final rawName = (data['name'] as String?)?.trim() ?? 'Unknown Doctor';
            final nameUpper = rawName.toUpperCase();
            final specialty =
                (data['specialization'] as String?)?.trim().isNotEmpty == true
                    ? (data['specialization'] as String).trim()
                    : 'Orthopaedic';
            final credentialsFromDb = (data['credentials'] as String?) ??
                (data['Credentials'] as String?);
            final credentials = (credentialsFromDb?.trim().isNotEmpty == true)
                ? credentialsFromDb!.trim()
                : (_credentialFallbackByName[nameUpper] ??
                    'Credentials will be updated soon.');
            final imageUrl = (data['imageUrl'] as String?)?.trim();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DoctorAvatar(
                          imageUrl: imageUrl,
                          radius: 44,
                          iconSize: 42,
                          fallbackIcon: Icons.medical_services_outlined,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          rawName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: OrthoqColors.slateNavy,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Specialty',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A5568),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                specialty,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Credentials',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A5568),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                credentials,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Clinic Schedule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: OrthoqColors.slateNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.2),
                            1: FlexColumnWidth(1.8),
                          },
                          border: TableBorder.all(color: Color(0xFFE2E8F0)),
                          children: const [
                            TableRow(
                              decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    'Days',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: OrthoqColors.slateNavy,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    'Time',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: OrthoqColors.slateNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    'MON - SAT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A5568),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    '8.00 AM - 12.00 PM',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
