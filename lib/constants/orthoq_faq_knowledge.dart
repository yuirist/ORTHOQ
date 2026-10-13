class OrthoqFaqEntry {
  const OrthoqFaqEntry({
    required this.keywords,
    required this.answer,
  });

  final List<String> keywords;
  final String answer;
}

/// Local knowledge base for instant OrthoQ / clinic answers.
abstract final class OrthoqFaqKnowledge {
  static const String welcomeHint =
      'Hi! I\'m the OrthoQ AI Assistant for Hospital Kajang Orthopaedic Clinic. '
      'Ask me about booking, rescheduling, referrals, or your appointments.';

  static const List<OrthoqFaqEntry> entries = [
    OrthoqFaqEntry(
      keywords: [
        'book',
        'booking',
        'make appointment',
        'schedule appointment',
        'how do i book',
      ],
      answer:
          'To book an appointment in OrthoQ:\n\n'
          '1. Tap **Book** in the bottom navigation bar.\n'
          '2. Choose **New Patient** or **Follow-up Patient**.\n'
          '3. Select a doctor and specialty.\n'
          '4. Pick an available date and time slot.\n'
          '5. Upload your referral letter (new patients).\n'
          '6. Confirm your details and submit.\n\n'
          'Clinic staff will verify your booking and notify you once confirmed.',
    ),
    OrthoqFaqEntry(
      keywords: [
        'reschedule',
        'change appointment',
        'change date',
        'move appointment',
      ],
      answer:
          'To reschedule your appointment:\n\n'
          '1. Open **Visits** (My Appointments).\n'
          '2. Select the appointment you want to change.\n'
          '3. Tap **Reschedule**.\n'
          '4. Choose a new available date and time.\n'
          '5. Confirm the request.\n\n'
          'Your request will be reviewed by clinic staff.',
    ),
    OrthoqFaqEntry(
      keywords: ['cancel', 'cancellation', 'cancel appointment'],
      answer:
          'To cancel an appointment:\n\n'
          '1. Go to **Visits** (My Appointments).\n'
          '2. Open the appointment details.\n'
          '3. Tap **Cancel Appointment** and confirm.\n\n'
          'Please cancel as early as possible so the slot can be offered to other patients.',
    ),
    OrthoqFaqEntry(
      keywords: [
        'referral',
        'upload referral',
        'referral letter',
        'upload letter',
      ],
      answer:
          'To upload a referral letter:\n\n'
          '1. During booking, select **New Patient**.\n'
          '2. On the referral step, tap **Upload Referral Letter**.\n'
          '3. Choose a clear photo or PDF from your device.\n'
          '4. Submit and wait for staff verification.\n\n'
          'New patients typically need a referral from a clinic or hospital.',
    ),
    OrthoqFaqEntry(
      keywords: ['choose doctor', 'select doctor', 'find doctor', 'pick doctor'],
      answer:
          'To choose a doctor:\n\n'
          '1. From the **Home** tab, browse **Specialties** (Hand, Spine, Foot & Ankle).\n'
          '2. Or tap **Book** and filter by category.\n'
          '3. View each doctor\'s profile and specialization.\n'
          '4. Select your preferred doctor before choosing a date.',
    ),
    OrthoqFaqEntry(
      keywords: [
        'appointment history',
        'my appointments',
        'view appointment',
        'past appointment',
      ],
      answer:
          'To view your appointment history:\n\n'
          '1. Tap **Visits** in the bottom navigation bar.\n'
          '2. See upcoming and past appointments.\n'
          '3. Tap any appointment for full details, reschedule, or cancel options.',
    ),
    OrthoqFaqEntry(
      keywords: [
        'new patient',
        'follow-up',
        'follow up',
        'difference',
        'first visit',
      ],
      answer:
          '**New Patient** — First visit to the orthopaedic clinic. You must upload a '
          'referral letter and complete patient verification by staff.\n\n'
          '**Follow-up Patient** — Returning for continuing care with an existing '
          'orthopaedic record. Referral may not be required; staff will confirm based on your case.',
    ),
    OrthoqFaqEntry(
      keywords: ['document', 'documents', 'what do i need', 'what to bring'],
      answer:
          'For new patients, please prepare:\n\n'
          '• Referral letter from a clinic or hospital\n'
          '• Identity card (IC)\n'
          '• Previous medical records or X-rays (if available)\n'
          '• Insurance details (if applicable)\n\n'
          'For follow-up visits, bring your IC and any new investigation results.',
    ),
    OrthoqFaqEntry(
      keywords: [
        'orthopaedic',
        'orthopedic',
        'clinic information',
        'hospital kajang',
        'services',
      ],
      answer:
          '**Hospital Kajang — Orthopaedic Outpatient Clinic**\n\n'
          'OrthoQ helps you manage orthopaedic appointments digitally. Services include:\n'
          '• Hand & upper limb\n'
          '• Spine surgery\n'
          '• Foot & ankle\n\n'
          'Use the app to book, reschedule, upload referrals, and receive notifications.',
    ),
    OrthoqFaqEntry(
      keywords: ['contact', 'phone', 'call clinic', 'reach clinic'],
      answer:
          '**Contact Hospital Kajang Orthopaedic Clinic**\n\n'
          'For urgent clinical matters, please call the hospital main line or visit the '
          'outpatient counter during operating hours.\n\n'
          'For appointment status in OrthoQ, check **Visits** or wait for staff notifications.',
    ),
  ];

  /// Returns a matching FAQ answer or null.
  static String? matchFaq(String userMessage) {
    final normalized = userMessage.toLowerCase().trim();
    if (normalized.isEmpty) return null;

    OrthoqFaqEntry? best;
    var bestScore = 0;

    for (final entry in entries) {
      var score = 0;
      for (final keyword in entry.keywords) {
        if (normalized.contains(keyword.toLowerCase())) {
          score += keyword.length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }

    return bestScore > 0 ? best!.answer : null;
  }
}
