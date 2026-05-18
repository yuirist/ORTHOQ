import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:intl/intl.dart';
import '../../models/doctor_model.dart';
import '../../services/doctor_delay_notification_service.dart';
import '../../services/doctor_service.dart';
import '../../services/email_service.dart';

class DelayNotificationsPage extends StatefulWidget {
  final String? initialDoctor;
  final String? initialDoctorId;
  final DateTime? initialDate;
  final String? initialMessage;

  /// When set, marks the delay alert completed after a successful broadcast.
  final String? delayRequestId;

  /// Pop this route after send only when opened via [Navigator.push], not as a staff tab.
  final bool popOnSuccess;

  const DelayNotificationsPage({
    super.key,
    this.initialDoctor,
    this.initialDoctorId,
    this.initialDate,
    this.initialMessage,
    this.delayRequestId,
    this.popOnSuccess = false,
  });

  @override
  State<DelayNotificationsPage> createState() => _DelayNotificationsPageState();
}

class _DelayNotificationsPageState extends State<DelayNotificationsPage> {
  final DoctorService _doctorService = DoctorService();
  final TextEditingController _delayMessageController = TextEditingController();
  final Set<String> _selectedAppointmentIds = {};

  String? _selectedDoctorId;
  String? _selectedDoctorName;
  DateTime _selectedDate = DateTime.now();
  bool _isSending = false;

  String get _emailDoctorName {
    final name = _selectedDoctorName?.trim() ?? '';
    if (name.isEmpty) return 'Doctor';
    return name.toLowerCase().startsWith('dr') ? name : 'Dr. $name';
  }

  String? _extractDelayMinutes(String text) {
    final match = RegExp(
      r'(\d+)\s*(min|mins|minute|minutes)',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  String _buildFormalDelayMessage(String doctorName, {String? minutes}) {
    final delayText =
        minutes != null && minutes.isNotEmpty ? '$minutes minutes' : '30 minutes';
    return 'We regret to inform you that Dr. $doctorName is currently experiencing a delay of approximately $delayText due to unforeseen circumstances. We sincerely apologize for the inconvenience and appreciate your patience.';
  }

  void _applyAutoMessageTemplate({String? sourceMessage}) {
    final doctorName = _selectedDoctorName;
    if (doctorName == null || doctorName.trim().isEmpty) return;
    final extractedMinutes =
        sourceMessage != null ? _extractDelayMinutes(sourceMessage) : null;
    final forTemplate = doctorName.toLowerCase().startsWith('dr')
        ? doctorName
        : 'Dr. $doctorName';
    _delayMessageController.text = _buildFormalDelayMessage(
      forTemplate,
      minutes: extractedMinutes,
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedAppointmentIds.clear();
    });
  }

  void _toggleSelectAll(List<QueryDocumentSnapshot> appointments) {
    setState(() {
      if (_selectedAppointmentIds.length == appointments.length) {
        _selectedAppointmentIds.clear();
      } else {
        _selectedAppointmentIds
          ..clear()
          ..addAll(appointments.map((doc) => doc.id));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedDoctorId = widget.initialDoctorId;
    final rawDoctor = widget.initialDoctor?.trim();
    if (rawDoctor != null && rawDoctor.isNotEmpty) {
      _selectedDoctorName = rawDoctor.toLowerCase().startsWith('dr.')
          ? rawDoctor.substring(3).trim()
          : rawDoctor;
    }
    _selectedDate = widget.initialDate ?? DateTime.now();
    _applyAutoMessageTemplate(sourceMessage: widget.initialMessage?.trim());
    _resolveInitialDoctor();
  }

  Future<void> _resolveInitialDoctor() async {
    final id = widget.initialDoctorId?.trim();
    if (id == null || id.isEmpty) return;
    final doctor = await _doctorService.getDoctorById(id);
    if (!mounted) return;
    if (doctor != null) {
      setState(() => _selectedDoctorName = doctor.name);
    }
  }

  @override
  void dispose() {
    _delayMessageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedAppointmentIds.clear();
      });
    }
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _endOfDay(DateTime date) =>
      _startOfDay(date).add(const Duration(days: 1));

  Stream<QuerySnapshot> _appointmentsStream() {
    if (_selectedDoctorId == null &&
        (_selectedDoctorName == null || _selectedDoctorName!.isEmpty)) {
      return const Stream.empty();
    }
    final start = _startOfDay(_selectedDate);
    final end = _endOfDay(_selectedDate);
    var query = FirebaseFirestore.instance
        .collection('appointments')
        .where('status', isEqualTo: 'confirmed');

    if (_selectedDoctorId != null && _selectedDoctorId!.isNotEmpty) {
      query = query.where('doctorId', isEqualTo: _selectedDoctorId);
    } else {
      query = query.where('doctorName', isEqualTo: _selectedDoctorName);
    }

    return query
        .where(
          'appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('appointmentDate', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  Future<QuerySnapshot> _appointmentsQuery() async {
    final start = _startOfDay(_selectedDate);
    final end = _endOfDay(_selectedDate);
    var query = FirebaseFirestore.instance
        .collection('appointments')
        .where('status', isEqualTo: 'confirmed');

    if (_selectedDoctorId != null && _selectedDoctorId!.isNotEmpty) {
      query = query.where('doctorId', isEqualTo: _selectedDoctorId);
    } else {
      query = query.where('doctorName', isEqualTo: _selectedDoctorName);
    }

    return query
        .where(
          'appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('appointmentDate', isLessThan: Timestamp.fromDate(end))
        .get();
  }

  Future<String?> _resolvePatientEmail(Map<String, dynamic> data) async {
    final fromAppointment = data['email']?.toString().trim();
    if (fromAppointment != null && fromAppointment.isNotEmpty) {
      return fromAppointment;
    }

    final patientId = data['patientId']?.toString().trim();
    if (patientId == null || patientId.isEmpty) return null;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(patientId).get();
      final fromUser = userDoc.data()?['email']?.toString().trim();
      if (fromUser != null && fromUser.isNotEmpty) return fromUser;
    } catch (_) {
      return null;
    }
    return null;
  }

  String _appointmentDateLabel(dynamic appointmentDateValue) {
    if (appointmentDateValue is Timestamp) {
      return DateFormat('EEEE, MMM d, y').format(appointmentDateValue.toDate());
    }
    if (appointmentDateValue is String) {
      final parsed = DateTime.tryParse(appointmentDateValue);
      if (parsed != null) {
        return DateFormat('EEEE, MMM d, y').format(parsed);
      }
    }
    return 'N/A';
  }

  Future<void> _sendDelayAlerts() async {
    if (_selectedDoctorId == null &&
        (_selectedDoctorName == null || _selectedDoctorName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_delayMessageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a delay message.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedAppointmentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one patient.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    var successCount = 0;
    try {
      final snapshot = await _appointmentsQuery();
      final docs = snapshot.docs
          .where((doc) => _selectedAppointmentIds.contains(doc.id))
          .toList();

      if (docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No matching appointments found for your selection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final delayMessage = _delayMessageController.text.trim();
      final doctorName = _emailDoctorName;

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final patientEmail = await _resolvePatientEmail(data);
        if (patientEmail == null || patientEmail.isEmpty) continue;

        final patientName = data['patientName']?.toString() ?? 'Patient';
        final appointmentTime =
            data['appointmentTime']?.toString().trim().isNotEmpty == true
                ? data['appointmentTime'].toString().trim()
                : 'N/A';
        final appointmentDateLabel =
            _appointmentDateLabel(data['appointmentDate']);

        final sent = await EmailService().sendDelayNotificationEmail(
          patientEmail,
          patientName,
          doctorName,
          appointmentDateLabel,
          appointmentTime,
          delayMessage,
        );
        if (sent) successCount++;
      }

      if (!mounted) return;

      if (successCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No delay emails could be sent. Check that selected patients have valid email addresses.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final requestId = widget.delayRequestId?.trim();
      if (requestId != null && requestId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(DoctorDelayNotificationService.collection)
            .doc(requestId)
            .set({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delay notifications sent to $successCount patient${successCount == 1 ? '' : 's'}.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _clearSelection();
      if (widget.popOnSuccess && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending delay notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delay Notifications'),
        backgroundColor: OrthoqColors.slateNavy,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Doctor Selection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<List<DoctorModel>>(
                          stream: _doctorService.getActiveDoctors(),
                          builder: (context, doctorsSnap) {
                            final doctors = doctorsSnap.data ?? [];
                            return DropdownButtonFormField<String>(
                              value: _selectedDoctorId,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Select doctor',
                              ),
                              items: doctors
                                  .map(
                                    (doctor) => DropdownMenuItem<String>(
                                      value: doctor.id,
                                      child: Text(
                                        doctor.name.trim().toLowerCase().startsWith('dr')
                                            ? doctor.name.trim()
                                            : 'Dr. ${doctor.name.trim()}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isSending
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedDoctorId = value;
                                        final match = doctors
                                            .where((d) => d.id == value);
                                        _selectedDoctorName = match.isEmpty
                                            ? null
                                            : match.first.name;
                                        _selectedAppointmentIds.clear();
                                      });
                                      _applyAutoMessageTemplate();
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Affected Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isSending ? null : _selectDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              DateFormat('EEEE, MMM d, y').format(_selectedDate),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Delay Message',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _delayMessageController,
                          maxLines: 5,
                          enabled: !_isSending,
                          decoration: const InputDecoration(
                            hintText:
                                'The doctor is experiencing a 30-minute delay due to an emergency surgery',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _appointmentsStream(),
                  builder: (context, snapshot) {
                    if (_selectedDoctorId == null &&
                        (_selectedDoctorName == null ||
                            _selectedDoctorName!.isEmpty)) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Select a doctor to view confirmed appointments.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('Error: ${snapshot.error}')),
                      );
                    }
                    final appointments = snapshot.data?.docs ?? [];
                    if (appointments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No confirmed appointments for selected doctor/date.',
                          ),
                        ),
                      );
                    }

                    final allSelected = appointments.isNotEmpty &&
                        _selectedAppointmentIds.length == appointments.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Patients (${appointments.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _isSending
                                    ? null
                                    : () => _toggleSelectAll(appointments),
                                child: Text(
                                  allSelected ? 'Deselect All' : 'Select All',
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: appointments.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final doc = appointments[index];
                            final data =
                                doc.data() as Map<String, dynamic>;
                            final patientName =
                                data['patientName']?.toString() ??
                                    'Unknown Patient';
                            final appointmentTime =
                                data['appointmentTime']?.toString() ?? 'N/A';
                            final email =
                                data['email']?.toString().trim() ?? '';
                            final isSelected =
                                _selectedAppointmentIds.contains(doc.id);

                            DateTime? appointmentDate;
                            final appointmentDateValue =
                                data['appointmentDate'];
                            if (appointmentDateValue is Timestamp) {
                              appointmentDate =
                                  appointmentDateValue.toDate();
                            } else if (appointmentDateValue is String) {
                              appointmentDate =
                                  DateTime.tryParse(appointmentDateValue);
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: _isSending
                                    ? null
                                    : (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedAppointmentIds
                                                .add(doc.id);
                                          } else {
                                            _selectedAppointmentIds
                                                .remove(doc.id);
                                          }
                                        });
                                      },
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  patientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (appointmentDate != null)
                                      Text(
                                        '${DateFormat('MMM dd, yyyy').format(appointmentDate)} at $appointmentTime',
                                      )
                                    else
                                      Text('Time: $appointmentTime'),
                                    Text(
                                      email.isNotEmpty
                                          ? email
                                          : 'Email from user profile (if available)',
                                      style: TextStyle(
                                        color: email.isNotEmpty
                                            ? Colors.blueGrey
                                            : Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendDelayAlerts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrthoqColors.slateNavy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _isSending
                            ? 'Sending...'
                            : 'Send Delay Alerts'
                                '${_selectedAppointmentIds.isEmpty ? '' : ' (${_selectedAppointmentIds.length})'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSending)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            OrthoqColors.slateNavy,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text('Sending delay notifications...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
