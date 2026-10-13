import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/cloudinary_service.dart';

/// Opens a referral letter URL (PDF or image) in an external viewer/browser.
Future<void> openReferralLetterUrl(
  BuildContext context,
  String? referralUrl,
) async {
  final url = referralUrl?.trim() ?? '';
  if (url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No referral letter available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  try {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CloudinaryService.isPdfUrl(url)
                ? 'Could not open PDF. Try copying the link.'
                : 'Could not open referral link',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening referral: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
