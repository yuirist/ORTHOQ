import 'package:intl/intl.dart';

import '../data/orthoq_faq_knowledge.dart';
import '../models/appointment_model.dart';
import '../models/recommendation_model.dart';
import 'appointment_service.dart';
import 'doctor_recommendation_service.dart';
import 'gemini_service.dart';

class AiAssistantService {
  AiAssistantService({
    AppointmentService? appointmentService,
    GeminiService? geminiService,
    DoctorRecommendationService? recommendationService,
  })  : _appointmentService = appointmentService ?? AppointmentService(),
        _geminiService = geminiService ?? GeminiService(),
        _recommendationService =
            recommendationService ?? DoctorRecommendationService();

  final AppointmentService _appointmentService;
  final GeminiService _geminiService;
  final DoctorRecommendationService _recommendationService;

  Future<String> getResponse({
    required String userId,
    required String userMessage,
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      throw GeminiException('Please enter a message before sending.');
    }

    final faqAnswer = OrthoqFaqKnowledge.matchFaq(trimmed);
    if (faqAnswer != null) {
      return _stripMarkdownBold(faqAnswer);
    }

    final appointmentAnswer = await _tryAppointmentContext(userId, trimmed);
    if (appointmentAnswer != null) {
      return appointmentAnswer;
    }

    final specialistAnswer = await _trySpecialistRecommendation(trimmed);
    if (specialistAnswer != null) {
      return specialistAnswer;
    }

    final appointment = await _appointmentService.getNextUpcomingAppointment(userId);
    final context = appointment == null
        ? 'The patient has no confirmed upcoming appointments.'
        : _formatAppointmentContext(appointment);

    return _geminiService.generateResponse(
      userId: userId,
      userMessage: trimmed,
      appointmentContext: context,
    );
  }

  Future<String?> _tryAppointmentContext(String userId, String message) async {
    final normalized = message.toLowerCase();

    final asksWhen = _matchesAny(normalized, [
      'when is my appointment',
      'next appointment',
      'my appointment date',
      'what time is my appointment',
      'upcoming appointment',
    ]);

    final asksReschedule = _matchesAny(normalized, [
      'can i reschedule',
      'can i change my appointment',
      'am i allowed to reschedule',
      'reschedule my appointment',
    ]);

    if (!asksWhen && !asksReschedule) return null;

    final appointment =
        await _appointmentService.getNextUpcomingAppointment(userId);

    if (appointment == null) {
      return 'You do not have a confirmed upcoming appointment. '
          'Tap **Book** in the bottom menu to schedule a visit.';
    }

    if (asksWhen) {
      return _formatNextAppointmentReply(appointment);
    }

    return _formatRescheduleEligibility(appointment);
  }

  /// Rule-based specialist recommendation for symptom descriptions in chat.
  Future<String?> _trySpecialistRecommendation(String message) async {
    if (!_recommendationService.shouldRecommendInChat(message)) {
      return null;
    }

    try {
      final recommendation =
          await _recommendationService.recommendFromSymptoms(message);

      if (recommendation.isMatchFound) {
        return recommendation.formatForChat();
      }

      if (_recommendationService.looksLikeSymptomDescription(message)) {
        return SpecialistRecommendation.noMatchMessage;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  bool _matchesAny(String text, List<String> phrases) {
    return phrases.any(text.contains);
  }

  String _formatNextAppointmentReply(AppointmentModel appointment) {
    final dateLabel =
        DateFormat('d MMMM y').format(appointment.appointmentDate);
    final timeLabel = appointment.appointmentTime;
    final doctor = appointment.doctorName.startsWith('Dr.')
        ? appointment.doctorName
        : 'Dr. ${appointment.doctorName}';

    return 'Your next appointment is on $dateLabel at $timeLabel with $doctor.';
  }

  String _formatRescheduleEligibility(AppointmentModel appointment) {
    final status = appointment.status.toLowerCase();

    if (status == 'cancelled' || status == 'completed') {
      return 'This appointment is ${appointment.status.toLowerCase()} and cannot be rescheduled. '
          'Book a new visit from the **Book** tab if you need another appointment.';
    }

    if (appointment.hasRescheduleRequest) {
      return 'You already have a pending reschedule request for your appointment on '
          '${DateFormat('d MMM y').format(appointment.appointmentDate)}. '
          'Clinic staff will review it shortly.';
    }

    return 'Yes, you can request to reschedule your appointment on '
        '${DateFormat('d MMM y').format(appointment.appointmentDate)}.\n\n'
        '1. Open **Visits**.\n'
        '2. Select the appointment.\n'
        '3. Tap **Reschedule** and choose a new slot.\n'
        '4. Confirm your request.\n\n'
        'Staff will approve the new date and time.';
  }

  String _formatAppointmentContext(AppointmentModel appointment) {
    return 'Next appointment: ${DateFormat('d MMM y').format(appointment.appointmentDate)} '
        'at ${appointment.appointmentTime} with Dr. ${appointment.doctorName}. '
        'Status: ${appointment.status}. '
        'Type: ${appointment.patientType}.';
  }

  String _stripMarkdownBold(String text) {
    return text.replaceAll('**', '');
  }
}
