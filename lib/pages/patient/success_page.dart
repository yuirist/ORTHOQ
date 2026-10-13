import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:orthoq_app/theme/orthoq_theme.dart';
import 'package:orthoq_app/theme/orthoq_typography.dart';
import 'package:orthoq_app/theme/orthoq_widgets.dart';
import 'patient_home_screen.dart';

class SuccessPage extends StatelessWidget {
  final String appointmentId;
  final String doctorName;
  final DateTime appointmentDate;
  final String appointmentTime;

  const SuccessPage({
    super.key,
    required this.appointmentId,
    required this.doctorName,
    required this.appointmentDate,
    required this.appointmentTime,
  });

  String _displayTime(String rawTime) {
    if (rawTime.trim().isEmpty || rawTime.trim().toUpperCase() == 'TBD') {
      return 'Awaiting Staff Confirmation';
    }
    return rawTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Successful'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: OrthoqSpacing.form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const OrthoqSuccessAnimation(size: 110),
              const SizedBox(height: OrthoqSpacing.lg),
              Text(
                'Booking confirmed',
                style: OrthoqTypography.headingMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OrthoqSpacing.xs),
              Text(
                'Your appointment request has been submitted',
                style: OrthoqTypography.bodyMedium(color: OrthoqColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OrthoqSpacing.lg),
              OrthoqInteractiveCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appointment details',
                      style: OrthoqTypography.sectionTitle(),
                    ),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        'Doctor',
                        'Dr. $doctorName',
                      ),
                      const Divider(),
                      _buildDetailRow(
                        'Date',
                        'Awaiting Staff Confirmation',
                      ),
                      const Divider(),
                      _buildDetailRow(
                        'Time',
                        _displayTime(appointmentTime),
                      ),
                      const Divider(),
                      _buildDetailRow(
                        'Status',
                        'Pending Staff Approval',
                        valueColor: OrthoqColors.slateNavy,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: OrthoqSpacing.lg),

              // Info Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OrthoqColors.inputFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: OrthoqColors.slateNavy,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your appointment is pending approval. You will receive a notification once it\'s confirmed.',
                        style: OrthoqTypography.bodyMedium(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Back to Home Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PatientHomeScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: OrthoqTheme.primaryButton,
                  child: const Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: OrthoqTypography.label()),
          ),
          Expanded(
            child: Text(
              value,
              style: OrthoqTypography.bodyLarge(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}














