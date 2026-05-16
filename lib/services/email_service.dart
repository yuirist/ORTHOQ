import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Sends transactional email via Gmail SMTP using the [mailer] package.
///
/// **Security:** `_smtpPassword` is hardcoded below for local debugging only.
/// Anyone with repo access can read it. Prefer removing the password before
/// pushing to a remote, or use a dedicated low-privilege account and rotate
/// the app password if it is ever exposed.
class EmailService {
  EmailService();

  static const String _smtpUser = 'danishjamari3@gmail.com';

  /// Gmail App Password (16 characters, no spaces).
  static const String _smtpPassword = 'jixrguqljhedvnza';

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
  <div style="background-color: #1A365D; color: #ffffff; padding: 18px 22px;">
    <h1 style="margin:0;font-size:20px;font-weight:bold;">OrthoQ - Hospital Kajang</h1>
  </div>
  <div style="padding: 24px 22px 32px 22px; background-color: #F7FAFC;">
$innerBodyHtml
  </div>
</div>
</body>
</html>''';
  }

  Future<void> sendBookingPendingEmail(
    String patientEmail,
    String patientName,
  ) async {
    const subject = 'Booking Received - Pending Review';
    final safeName = _escapeHtml(patientName);
    final inner =
        '''
    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <p style="margin:0 0 20px 0;font-size:15px;line-height:1.55;">
      Your booking has been received and is <strong>pending review</strong>.
      Our clinic team will confirm your appointment once your referral has been checked.
    </p>
    <h2 style="margin:0 0 12px 0;font-size:17px;color:#1A365D;">Next steps</h2>
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

    await _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendBookingPendingEmail',
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
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Patient Name</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeName</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Doctor</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Appointment Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Appointment Time</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeTime</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Clinic</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">OrthoQ (Hospital Kajang)</td>
      </tr>
    </table>
    <p style="margin:20px 0 0 0;font-size:14px;line-height:1.5;color:#4A5568;">
      Please arrive a few minutes early and bring any relevant documents or imaging reports.
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

  Future<void> sendApprovalEmail(
    String patientEmail,
    String date,
    String time,
    String doctorName,
    String specialization,
  ) async {
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
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Doctor Name</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Specialization</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeSpec</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Time</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeTime</td>
      </tr>
    </table>
    <p style="margin:20px 0 0 0;font-size:14px;line-height:1.5;color:#4A5568;">
      Please arrive a few minutes early and bring any relevant documents or imaging reports.
    </p>''';

    final html = _htmlDocument(inner);
    final plain =
        'Your appointment is confirmed.\nDoctor: $doctorName\nSpecialization: $specialization\nDate: $date\nTime: $time\n';

    await _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendApprovalEmail',
    );
  }

  Future<void> sendRescheduleEmail(
    String patientEmail,
    String patientName,
    String oldDate,
    String newDate,
    String newTime,
    String doctorName,
  ) async {
    const subject = 'IMPORTANT: Your Appointment Has Been Rescheduled - OrthoQ';
    final safeName = _escapeHtml(patientName);
    final safeDoctor = _escapeHtml(doctorName);
    final safeOldDate = _escapeHtml(oldDate);
    final safeNewDate = _escapeHtml(newDate);
    final safeNewTime = _escapeHtml(newTime);

    final inner =
        '''
    <p style="margin:0 0 14px 0;font-size:16px;line-height:1.5;">Hi $safeName,</p>
    <h2 style="margin:0 0 18px 0;font-size:18px;color:#1A365D;font-weight:bold;">
      Appointment Reschedule Notice
    </h2>
    <p style="margin:0 0 18px 0;font-size:15px;line-height:1.55;color:#4A5568;">
      Your orthopaedic appointment details have been updated. Please review the summary below.
    </p>
    <table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;font-size:15px;background:#ffffff;">
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Status</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;">
          <span style="font-weight:bold;color:#C53030;">RESCHEDULED</span>
        </td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Doctor</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Previous Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#718096;text-decoration:line-through;">$safeOldDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">New Confirmed Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;"><strong>$safeNewDate</strong></td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">New Confirmed Time</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;"><strong>$safeNewTime</strong></td>
      </tr>
    </table>
    <p style="margin:22px 0 0 0;font-size:14px;line-height:1.55;color:#4A5568;">
      If this new time does not work for you, please contact the clinic assistant at Hospital Kajang immediately.
    </p>''';

    final html = _htmlDocument(inner);
    final plain =
        '''
IMPORTANT: Your appointment has been rescheduled.

Hi $patientName,

Appointment Reschedule Notice
Status: RESCHEDULED
Doctor: $doctorName
Previous Date: $oldDate
New Confirmed Date: $newDate
New Confirmed Time: $newTime

If this new time does not work for you, please contact the clinic assistant at Hospital Kajang immediately.
''';

    await _sendOrLog(
      to: patientEmail,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendRescheduleEmail',
    );
  }

  Future<void> sendRescheduleResponseEmail(
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
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Status</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;"><strong style="color:#2F855A;">APPROVED</strong></td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">New Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeNewDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">New Time</td>
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

    await _sendOrLog(
      to: email,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendRescheduleResponseEmail',
    );
  }

  Future<void> sendRescheduleConfirmationEmail(
    String email,
    String name,
    bool isAccepted,
    String newDate,
    String newTime,
    String doctorName,
  ) async {
    final safeName = _escapeHtml(name);
    final safeNewDate = _escapeHtml(newDate);
    final safeNewTime = _escapeHtml(newTime);
    final safeDoctor = _escapeHtml(doctorName);

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
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Status</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;"><strong style="color:#2F855A;">APPROVED</strong></td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Doctor</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;"><strong>Dr. $safeDoctor</strong></td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">New Appointment Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeNewDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Time</td>
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
    </p>''';

    final html = _htmlDocument(inner);
    final plain = isAccepted
        ? 'Hi $name,\n\nYour reschedule request for Hospital Kajang has been APPROVED.\nDoctor: Dr. $doctorName\nNew Date: $newDate\nNew Time: $newTime\n'
        : 'Hi $name,\n\nYour reschedule request has been DECLINED. Please attend your original appointment.\n';

    await _sendOrLog(
      to: email,
      subject: subject,
      html: html,
      plainText: plain,
      contextLabel: 'sendRescheduleConfirmationEmail',
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
        <td style="border:1px solid #CBD5E0;padding:12px 14px;width:38%;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Doctor</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeDoctor</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Date</td>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;color:#2d3748;">$safeAppointmentDate</td>
      </tr>
      <tr>
        <td style="border:1px solid #CBD5E0;padding:12px 14px;background-color:#EDF2F7;font-weight:bold;color:#1A365D;">Your scheduled time</td>
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

  Future<bool> _sendOrLog({
    required String to,
    required String subject,
    required String html,
    required String plainText,
    required String contextLabel,
  }) async {
    final trimmedTo = to.trim();
    if (trimmedTo.isEmpty) {
      debugPrint(
        'EmailService($contextLabel): skipped — recipient email is empty.',
      );
      return false;
    }

    if (!_canSend) {
      debugPrint(
        'EmailService($contextLabel): skipped — _smtpPassword is empty. '
        'Paste your 16-character Gmail App Password (no spaces) into '
        'email_service.dart.',
      );
      return false;
    }

    final message = Message()
      ..from = Address(_smtpUser, 'OrthoQ')
      ..recipients.add(trimmedTo)
      ..subject = subject
      ..html = html
      ..text = plainText;

    try {
      final report = await send(message, _smtpServer);
      debugPrint('EmailService($contextLabel): success → $trimmedTo — $report');
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
      debugPrint('EmailService($contextLabel): failed — $e');
      debugPrint('$stack');
      return false;
    }
  }
}
