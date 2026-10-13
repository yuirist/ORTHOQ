import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Sends transactional email via Gmail SMTP using the [mailer] package.
///
/// **Security:** Prefer `SMTP_USER` / `SMTP_APP_PASSWORD` in `.env` so credentials
/// are not committed. The fallbacks below are for local debugging only.
class EmailService {
  EmailService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Gmail address used as the SMTP login (not your personal password).
  static const String _smtpUserFallback = 'danishjamari3@gmail.com';

  /// Paste your 16-character Google App Password here (no spaces).
  /// Generate at: Google Account → Security → 2-Step Verification → App passwords.
  /// Do NOT use your normal Gmail login password — SMTP requires an app password.
  static const String _smtpAppPasswordFallback = 'qauhdvqvectgavyr';

  static String get _smtpUser =>
      dotenv.env['SMTP_USER']?.trim().isNotEmpty == true
          ? dotenv.env['SMTP_USER']!.trim()
          : _smtpUserFallback;

  static String get _smtpPassword =>
      dotenv.env['SMTP_APP_PASSWORD']?.trim().isNotEmpty == true
          ? dotenv.env['SMTP_APP_PASSWORD']!.trim()
          : _smtpAppPasswordFallback;

  SmtpServer get _smtpServer => gmail(_smtpUser, _smtpPassword);

  bool get _canSend => _smtpPassword.isNotEmpty;

  static String _escapeHtml(String? value) {
    if (value == null || value.isEmpty) {
      return '—';
    }
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  /// Wraps inner body HTML in a shared OrthoQ shell (Arial, header, clinical tone).
  static String _htmlDocument(String innerBodyHtml) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background-color:#F7FAFC;">
<div style="font-family: Arial, sans-serif; max-width: 640px; margin: 0 auto; color: #2d3748;">
  <div style="background-color: #1B3C68; color: #ffffff; padding: 18px 22px;">
    <h1 style="margin:0;font-size:20px;font-weight:bold;">OrthoQ - Hospital Kajang</h1>
  </div>
  <div style="padding: 24px 22px 32px 22px; background-color: #F7FAFC;">
$innerBodyHtml
  </div>
</div>
</body>
</html>''';
  }

  Future<bool> sendBookingPendingEmail(
    String patientEmail,
    String patientName, {
    String? patientId,
  }) async {
    const subject = 'Booking Received - Pending Review';
    final safeName = _escapeHtml(patientName);
    final inner =
        '''
    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.55;">
      Your booking has been received and is <strong>pending review</strong>.
      Our clinic team will confirm your appointment once your referral has been checked.
    </p>
    <h2 style="margin:0 0 12px 0;font-size:17px;color:#1B3C68;">Next steps</h2>
    <ul style="margin:0;padding-left:20px;font-size:15px;line-height:1.65;color:#4A5568;">
      <li style="margin-bottom:8px;">Reviewing your referral letter</li>
      <li style="margin-bottom:8px;">Verifying your details against clinic records</li>
      <li style="margin-bottom:0;">Assigning an appointment slot and notifying you by email</li>
    </ul>
    <p style="margin:24px 0 0 0;font-size:14px;line-height:1.5;color:#4A5568;">
      You do not need to take further action right now. If you have questions, please contact the clinic.
    </p>''';

    final html = _htmlDocument(inner);
    final plain =
        'Hi $patientName,\n\nYour booking is received and pending review.\n\nNext steps:\n'
        '- Reviewing your referral letter\n'
        '- Verifying your details\n'
        '- Assigning a slot and notifying you\n';

    return _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendBookingPendingEmail',
      patientId: patientId,
      historyTitle: 'Booking Received - Pending Review',
      historyDescription: 'sendBookingPendingEmail',
    );
  }

  /// Immediate booking confirmation for follow-up patients (after Firestore save).
  Future<bool> sendFollowUpConfirmationEmail({
    required String patientEmail,
    required String patientName,
    required String doctorName,
    required String appointmentDate,
    required String appointmentTime,
  }) async {
    const subject = 'Appointment Confirmed - OrthoQ (Hospital Kajang)';
    final safeName = _escapeHtml(patientName);
    final safeDate = _escapeHtml(appointmentDate);
    final safeTime = _escapeHtml(appointmentTime);
    final doctorLabel = doctorName.trim().toLowerCase().startsWith('dr')
        ? doctorName.trim()
        : 'Dr. $doctorName';
    final safeDoctor = _escapeHtml(doctorLabel);

    final inner =
        '''
    <p style="margin:0 0 18px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.55;">
      Your follow-up appointment at <strong>OrthoQ (Hospital Kajang)</strong> is <strong>confirmed</strong>.
      Please find the details below.
    </p>
    <table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;font-size:15px;background:#ffffff;">
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Patient Name</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeName</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Doctor</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Appointment Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Appointment Time</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeTime</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Clinic</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">OrthoQ (Hospital Kajang)</td>
      </tr>
    </table>
    <p style="margin:20px 0 0 0;font-size:14px;line-height:1.5;color:#4A5568;">
      Please arrive at least 30 min before your appointment time and bring any relevant documents
    </p>''';

    final html = _htmlDocument(inner);
    final plain =
        'Hi $patientName,\n\n'
        'Your follow-up appointment at OrthoQ (Hospital Kajang) is confirmed.\n\n'
        'Patient Name: $patientName\n'
        'Doctor: $doctorLabel\n'
        'Appointment Date: $appointmentDate\n'
        'Appointment Time: $appointmentTime\n'
        'Clinic: OrthoQ (Hospital Kajang)\n';

    return _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendFollowUpConfirmationEmail',
    );
  }

  Future<bool> sendApprovalEmail(
    String patientEmail,
    String date,
    String time,
    String doctorName,
    String specialization, {
    String? patientId,
  }) async {
    const subject = 'Appointment Confirmed - OrthoQ';
    final safeDoctor = _escapeHtml(doctorName);
    final safeSpec = _escapeHtml(specialization);
    final safeDate = _escapeHtml(date);
    final safeTime = _escapeHtml(time);

    final inner =
        '''
    <p style="margin:0 0 18px 0;font-size:16px;line-height:1.5;">
      Great news! Your appointment is <strong>confirmed</strong>. Please find the details below.
    </p>
    <table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;font-size:15px;background:#ffffff;">
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Doctor Name</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Specialization</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeSpec</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Time</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeTime</td>
      </tr>
    </table>
    <p style="margin:20px 0 0 0;font-size:14px;line-height:1.5;color:#4A5568;">
      Please arrive at least 30 min before your appointment time and bring any relevant documents
    </p>''';

    final html = _htmlDocument(inner);
    final plain =
        'Your appointment is confirmed.\nDoctor: $doctorName\nSpecialization: $specialization\nDate: $date\nTime: $time\n';

    return _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendApprovalEmail',
      patientId: patientId,
      historyTitle: 'Appointment Confirmed - OrthoQ',
      historyDescription: 'sendApprovalEmail',
    );
  }

  static String _rescheduleComparisonTableHtml({
    required String statusLabel,
    required String statusColor,
    required String doctorName,
    required String oldDate,
    required String oldTime,
    required String newDate,
    required String newTime,
  }) {
    final safeDoctor = _escapeHtml(doctorName);
    final safeOldDate = _escapeHtml(oldDate);
    final safeOldTime = _escapeHtml(oldTime);
    final safeNewDate = _escapeHtml(newDate);
    final safeNewTime = _escapeHtml(newTime);
    final safeStatus = _escapeHtml(statusLabel);

    return '''
    <table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;font-size:15px;background:#ffffff;">
      <tr style="border-bottom:1px solid #eee;">
        <td style="padding:10px;font-weight:bold;color:#1B3C68;">Status</td>
        <td style="padding:10px;color:$statusColor;font-weight:bold;">$safeStatus</td>
      </tr>
      <tr style="border-bottom:1px solid #eee;">
        <td style="padding:10px;font-weight:bold;color:#1B3C68;">Doctor</td>
        <td style="padding:10px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr style="border-bottom:1px solid #eee;background-color:#f9f9f9;">
        <td style="padding:10px;color:#777;font-weight:bold;">Original Date</td>
        <td style="padding:10px;color:#777;text-decoration:line-through;">$safeOldDate</td>
      </tr>
      <tr style="border-bottom:1px solid #eee;background-color:#f9f9f9;">
        <td style="padding:10px;color:#777;font-weight:bold;">Original Time</td>
        <td style="padding:10px;color:#777;text-decoration:line-through;">$safeOldTime</td>
      </tr>
      <tr style="border-bottom:1px solid #eee;">
        <td style="padding:10px;font-weight:bold;color:#1B3C68;">New Appointment Date</td>
        <td style="padding:10px;color:#2d3748;"><strong>$safeNewDate</strong></td>
      </tr>
      <tr style="border-bottom:1px solid #eee;">
        <td style="padding:10px;font-weight:bold;color:#1B3C68;">Time</td>
        <td style="padding:10px;color:#2d3748;"><strong>$safeNewTime</strong></td>
      </tr>
    </table>''';
  }

  Future<bool> sendRescheduleEmail(
    String patientEmail,
    String patientName,
    String oldDate,
    String oldTime,
    String newDate,
    String newTime,
    String doctorName,
    String reason, {
    String? patientId,
  }) async {
    const subject = 'IMPORTANT: Your Appointment Has Been Rescheduled - OrthoQ';
    final safeName = _escapeHtml(patientName);
    final safeReason = _escapeHtml(reason.trim().isEmpty
        ? 'Please attend your updated appointment slot.'
        : reason.trim());
    final doctorLabel = doctorName.trim().toLowerCase().startsWith('dr')
        ? doctorName.trim()
        : 'Dr. $doctorName';
    final safeDoctor = _escapeHtml(doctorLabel);

    final table = _rescheduleComparisonTableHtml(
      statusLabel: 'RESCHEDULED',
      statusColor: '#C53030',
      doctorName: doctorLabel,
      oldDate: oldDate,
      oldTime: oldTime,
      newDate: newDate,
      newTime: newTime,
    );

    final inner =
        '''
    <p style="margin:0 0 14px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <h2 style="margin:0 0 18px 0;font-size:18px;color:#1B3C68;font-weight:bold;">
      Appointment Reschedule Notice
    </h2>
    <p style="font-size:14px;color:#333333;line-height:1.55;margin:0 0 18px 0;">
      Due to unforeseen circumstances, <b>$safeDoctor</b> has to reschedule your appointment.<br><br>
      <strong>Message from the doctor:</strong><br>
      <span style="font-style:italic;color:#555555;">"$safeReason"</span>
    </p>
    $table
    <p style="font-size:14px;color:#333333;line-height:1.55;margin:20px 0 0 0;">
      If you want to choose a different date and time, book in orthoq app.<br>
      Thank you.
    </p>''';

    final html = _htmlDocument(inner);
    final plainReason = reason.trim().isEmpty
        ? 'Please attend your updated appointment slot.'
        : reason.trim();
    final plain =
        '''
IMPORTANT: Your appointment has been rescheduled.

Hi $patientName,

Appointment Reschedule Notice

Due to unforeseen circumstances, $doctorLabel has to reschedule your appointment.

Message from the doctor: "$plainReason"

Status: RESCHEDULED
Doctor: $doctorLabel
Original Date: $oldDate
Original Time: $oldTime
New Appointment Date: $newDate
Time: $newTime

If you want to choose a different date and time, book in orthoq app.
Thank you.
''';

    return _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendRescheduleEmail',
      patientId: patientId,
      historyTitle: 'Appointment Rescheduled - OrthoQ',
      historyDescription:
          'Reschedule notice email sent to patient due to doctor schedule changes.',
    );
  }

  Future<bool> sendRescheduleResponseEmail(
    String email,
    String name,
    bool isAccepted,
    String newDate,
    String newTime,
  ) async {
    final safeName = _escapeHtml(name);
    final safeNewDate = _escapeHtml(newDate);
    final safeNewTime = _escapeHtml(newTime);

    final subject = isAccepted
        ? 'Reschedule Request Approved - OrthoQ'
        : 'Reschedule Request Declined - OrthoQ';

    final inner = isAccepted
        ? '''
    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.55;">
      Your reschedule request for <strong>Hospital Kajang</strong> has been <strong style="color:#2F855A;">APPROVED</strong>.
      Your updated appointment details are shown below.
    </p>
    <table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;font-size:15px;background:#ffffff;">
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Status</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;"><strong style="color:#2F855A;">APPROVED</strong></td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">New Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeNewDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">New Time</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeNewTime</td>
      </tr>
    </table>
    <p style="margin:20px 0 0 0;font-size:14px;line-height:1.5;color:#4A5568;">
      Please attend according to this updated slot.
    </p>'''
        : '''
    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.55;">
      Your reschedule request has been <strong style="color:#C53030;">DECLINED</strong>.
      Please attend your original appointment.
    </p>
    <p style="margin:0;font-size:14px;line-height:1.5;color:#4A5568;">
      If you need further assistance, please contact Hospital Kajang.
    </p>''';

    final html = _htmlDocument(inner);
    final plain = isAccepted
        ? 'Hi $name,\n\nYour reschedule request for Hospital Kajang has been APPROVED.\nNew Date: $newDate\nNew Time: $newTime\n'
        : 'Hi $name,\n\nYour reschedule request has been DECLINED. Please attend your original appointment.\n';

    return _sendOrLog(
      to: email,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendRescheduleResponseEmail',
    );
  }

  Future<bool> sendRescheduleConfirmationEmail(
    String email,
    String name,
    bool isAccepted,
    String oldDate,
    String oldTime,
    String newDate,
    String newTime,
    String doctorName, {
    String? patientId,
  }) async {
    final safeName = _escapeHtml(name);
    final safeOldDate = _escapeHtml(oldDate);
    final safeOldTime = _escapeHtml(oldTime);
    final doctorLabel = doctorName.trim().toLowerCase().startsWith('dr')
        ? doctorName.trim()
        : 'Dr. $doctorName';

    final subject = isAccepted
        ? 'Reschedule Request Approved - OrthoQ'
        : 'Reschedule Request Declined - OrthoQ';

    final inner = isAccepted
        ? '''
    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.55;">
      Your reschedule request for <strong>Hospital Kajang</strong> has been <strong style="color:#2F855A;">APPROVED</strong>.
      Your updated appointment details are shown below.
    </p>
    ${_rescheduleComparisonTableHtml(
      statusLabel: 'APPROVED (RESCHEDULED)',
      statusColor: '#2F855A',
      doctorName: doctorLabel,
      oldDate: oldDate,
      oldTime: oldTime,
      newDate: newDate,
      newTime: newTime,
    )}
    <p style="margin:20px 0 0 0;font-size:14px;line-height:1.5;color:#4A5568;">
      Please attend according to this updated slot.
    </p>'''
        : '''
    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.55;">
      Your reschedule request has been <strong style="color:#C53030;">DECLINED</strong>.
      Please attend your original appointment on <strong>$safeOldDate</strong> at <strong>$safeOldTime</strong>.
    </p>''';

    final html = _htmlDocument(inner);
    final plain = isAccepted
        ? 'Hi $name,\n\nYour reschedule request for Hospital Kajang has been APPROVED.\n'
            'Doctor: $doctorLabel\n'
            'Original Date: $oldDate\n'
            'Original Time: $oldTime\n'
            'New Appointment Date: $newDate\n'
            'Time: $newTime\n'
        : 'Hi $name,\n\nYour reschedule request has been DECLINED. '
            'Please attend your original appointment on $oldDate at $oldTime.\n';

    return _sendOrLog(
      to: email,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendRescheduleConfirmationEmail',
      patientId: patientId,
      historyTitle: 'Appointment Rescheduled - OrthoQ',
      historyDescription:
          'Reschedule notice email sent to patient due to doctor schedule changes.',
    );
  }

  /// Notifies clinic staff that a doctor has reported a schedule delay.
  Future<bool> sendStaffDoctorDelayEmail({
    required String toEmail,
    required String doctorName,
    required String delayDate,
    required String delayMessage,
  }) async {
    const subject = 'Urgent: Doctor Appointment Delay Notice - OrthoQ';
    final doctorLabel = doctorName.trim().toLowerCase().startsWith('dr')
        ? doctorName.trim()
        : 'Dr. $doctorName';
    final safeDoctor = _escapeHtml(doctorLabel);
    final safeDate = _escapeHtml(delayDate);
    final safeMessage = _escapeHtml(delayMessage);

    final inner =
        '''
    <p style="margin:0 0 18px 0;font-size:16px;line-height:1.5;">
      Dear Clinic Staff,
    </p>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.55;color:#4A5568;">
      A doctor has submitted an urgent delay notice through OrthoQ. Please review the details below and notify affected patients as needed.
    </p>
    <table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;font-size:15px;background:#ffffff;">
      <tr style="border-bottom:1px solid #eee;">
        <td style="padding:10px;font-weight:bold;color:#1B3C68;">Status</td>
        <td style="padding:10px;color:#C05621;font-weight:bold;">DOCTOR DELAY NOTICE</td>
      </tr>
      <tr style="border-bottom:1px solid #eee;">
        <td style="padding:10px;font-weight:bold;color:#1B3C68;">Doctor Name</td>
        <td style="padding:10px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr style="border-bottom:1px solid #eee;">
        <td style="padding:10px;font-weight:bold;color:#1B3C68;">Effective Date</td>
        <td style="padding:10px;color:#2d3748;"><strong>$safeDate</strong></td>
      </tr>
    </table>
    <h2 style="margin:22px 0 12px 0;font-size:16px;color:#1B3C68;font-weight:bold;">
      Delay Message Context
    </h2>
    <p style="margin:0;font-size:15px;line-height:1.6;color:#2d3748;padding:14px;background:#FFFAF0;border:1px solid #FBD38D;border-radius:8px;">
      $safeMessage
    </p>
    <p style="margin:20px 0 0 0;font-size:14px;line-height:1.55;color:#4A5568;">
      Log in to OrthoQ to broadcast patient notifications for this delay.
    </p>''';

    final html = _htmlDocument(inner);
    final plain =
        'Urgent: Doctor Appointment Delay Notice - OrthoQ\n\n'
        'Dear Clinic Staff,\n\n'
        'A doctor has submitted an urgent delay notice.\n\n'
        'Status: DOCTOR DELAY NOTICE\n'
        'Doctor Name: $doctorLabel\n'
        'Effective Date: $delayDate\n\n'
        'Delay Message Context:\n$delayMessage\n\n'
        'Log in to OrthoQ to broadcast patient notifications for this delay.\n';

    return _sendOrLog(
      to: toEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendStaffDoctorDelayEmail',
    );
  }

  Future<bool> sendDelayNotificationEmail(
    String patientEmail,
    String patientName,
    String doctorName,
    String appointmentDate,
    String originalTime,
    String delayMessage,
  ) async {
    const subject = 'Urgent: Appointment Delay at OrthoQ - Hospital Kajang';
    final safeName = _escapeHtml(patientName);
    final doctorLabel = doctorName.trim().toLowerCase().startsWith('dr')
        ? doctorName.trim()
        : 'Dr. $doctorName';
    final safeDoctor = _escapeHtml(doctorLabel);
    final safeAppointmentDate = _escapeHtml(appointmentDate);
    final safeOriginalTime = _escapeHtml(originalTime);
    final safeMessage = _escapeHtml(delayMessage);

    final inner =
        '''
    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.6;color:#2d3748;">$safeMessage</p>
    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.55;">
      This urgent update applies to your appointment at <strong>OrthoQ (Hospital Kajang)</strong>:
    </p>
    <table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;font-size:15px;background:#ffffff;">
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Doctor</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeAppointmentDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Your scheduled time</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;"><strong>$safeOriginalTime</strong></td>
      </tr>
    </table>
    <p style="margin:20px 0 0 0;font-size:14px;line-height:1.55;color:#4A5568;">
      We apologize for the inconvenience and appreciate your patience.
    </p>''';

    final html = _htmlDocument(inner);
    final plain =
        'Hi $patientName,\n\n'
        '$delayMessage\n\n'
        'OrthoQ (Hospital Kajang)\n'
        'Doctor: $doctorLabel\n'
        'Appointment Date: $appointmentDate\n'
        'Your scheduled time: $originalTime\n\n'
        'We apologize for the inconvenience and appreciate your patience.\n';

    return _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendDelayNotificationEmail',
    );
  }

  /// Notifies a patient that their pending appointment was rejected by clinic staff.
  Future<bool> sendAppointmentRejectionEmail({
    required String patientEmail,
    required String patientName,
    required String rejectionReason,
    required String appointmentDate,
    required String appointmentTime,
    required String doctorName,
  }) async {
    const subject = 'Appointment Status: Rejected';
    final safeName = _escapeHtml(patientName);
    final safeReason = _escapeHtml(rejectionReason);
    final safeDate = _escapeHtml(appointmentDate);
    final safeTime = _escapeHtml(appointmentTime);
    final doctorLabel = doctorName.trim().toLowerCase().startsWith('dr')
        ? doctorName.trim()
        : 'Dr. ${doctorName.trim()}';
    final safeDoctor = _escapeHtml(doctorLabel);

    final inner =
        '''
    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.55;">
      We regret to inform you that your appointment request at
      <strong>OrthoQ (Hospital Kajang)</strong> has been <strong style="color:#C53030;">rejected</strong>.
      The details below refer to the request that was declined.
    </p>
    <h2 style="margin:0 0 12px 0;font-size:17px;color:#1B3C68;">Appointment details</h2>
    <table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;font-size:15px;background:#ffffff;margin-bottom:20px;">
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Time</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeTime</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1B3C68;">Doctor</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDoctor</td>
      </tr>
    </table>
    <h2 style="margin:0 0 12px 0;font-size:17px;color:#1B3C68;">Reason for rejection</h2>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.6;color:#2d3748;padding:14px;background:#ffffff;border:1px solid #CBD5E0;border-radius:8px;">
      $safeReason
    </p>
    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.55;color:#2d3748;">
      <strong>Please log back into the OrthoQ app to schedule a new appointment.</strong>
    </p>
    <p style="margin:0;font-size:14px;line-height:1.55;color:#4A5568;">
      If you have questions, please contact the clinic.
    </p>''';

    final html = _htmlDocument(inner);
    final plain =
        'Hi $patientName,\n\n'
        'Your appointment request at OrthoQ (Hospital Kajang) has been rejected.\n\n'
        'Appointment details:\n'
        'Date: $appointmentDate\n'
        'Time: $appointmentTime\n'
        'Doctor: $doctorLabel\n\n'
        'Reason for rejection:\n$rejectionReason\n\n'
        'Please log back into the OrthoQ app to schedule a new appointment.\n\n'
        'If you have questions, please contact the clinic.\n';

    return _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendAppointmentRejectionEmail',
    );
  }

  Future<void> _logEmailToPatientHistory({
    required String patientId,
    required String title,
    required String description,
    required String status,
  }) async {
    final trimmedId = patientId.trim();
    if (trimmedId.isEmpty) return;

    try {
      await _firestore
          .collection('patients')
          .doc(trimmedId)
          .collection('history')
          .add({
        'title': title,
        'description': description,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('EmailService: failed to log patient history — $e');
    }
  }

  Future<bool> _sendOrLog({
    required String to,
    required String subject,
    required String html,
    required String plainText,
    required String contextLabel,
    String? patientId,
    String? historyTitle,
    String? historyDescription,
  }) async {
    final trimmedTo = to.trim();
    if (trimmedTo.isEmpty) {
      debugPrint(
        'EmailService($contextLabel): skipped — recipient email is empty.',
      );
      return false;
    }

    // Mobile/desktop: send immediately via SMTP when credentials are configured.
    if (!kIsWeb && _canSend) {
      final sent = await _sendDirect(
        to: trimmedTo,
        subject: subject,
        html: html,
        plainText: plainText,
        contextLabel: contextLabel,
      );
      if (sent) {
        await _maybeLogPatientHistory(
          patientId: patientId,
          historyTitle: historyTitle,
          historyDescription: historyDescription,
          contextLabel: contextLabel,
          status: 'sent',
        );
        return true;
      }
    }

    // Web (and mobile fallback): queue for the sendOutboundMail Cloud Function.
    try {
      await _firestore.collection('outbound_mail').add({
        'to': trimmedTo,
        'subject': subject,
        'html': html,
        'text': plainText,
        'contextLabel': contextLabel,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'EmailService($contextLabel): queued for delivery → $trimmedTo',
      );
      await _maybeLogPatientHistory(
        patientId: patientId,
        historyTitle: historyTitle,
        historyDescription: historyDescription,
        contextLabel: contextLabel,
        status: 'pending',
      );
      return true;
    } catch (e, stack) {
      debugPrint('EmailService($contextLabel): queue failed — $e');
      debugPrint('$stack');
      if (kIsWeb) {
        debugPrint(
          'EmailService($contextLabel): deploy Cloud Functions '
          '(sendOutboundMail) and add Firestore rules for outbound_mail.',
        );
      }
      return false;
    }
  }

  Future<void> _maybeLogPatientHistory({
    required String? patientId,
    required String? historyTitle,
    required String? historyDescription,
    required String contextLabel,
    required String status,
  }) async {
    final id = patientId?.trim() ?? '';
    final title = historyTitle?.trim() ?? '';
    if (id.isEmpty || title.isEmpty) return;

    await _logEmailToPatientHistory(
      patientId: id,
      title: title,
      description: historyDescription?.trim().isNotEmpty == true
          ? historyDescription!.trim()
          : contextLabel,
      status: status,
    );
  }

  Future<bool> _sendDirect({
    required String to,
    required String subject,
    required String html,
    required String plainText,
    required String contextLabel,
  }) async {
    final message = Message()
      ..from = Address(_smtpUser, 'OrthoQ')
      ..recipients.add(to)
      ..subject = subject
      ..html = html
      ..text = plainText;

    try {
      final report = await send(message, _smtpServer);
      debugPrint('EmailService($contextLabel): direct SMTP success → $to — $report');
      return true;
    } on MailerException catch (e, stack) {
      debugPrint('EmailService($contextLabel): MailerException — $e');
      for (final problem in e.problems) {
        debugPrint(
          '  Gmail/mailer problem — code: ${problem.code}, message: ${problem.msg}',
        );
      }
      debugPrint('$stack');
      return false;
    } catch (e, stack) {
      debugPrint('EmailService($contextLabel): direct SMTP failed — $e');
      debugPrint('$stack');
      return false;
    }
  }
}
