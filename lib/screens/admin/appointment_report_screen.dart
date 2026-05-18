import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';

import '../../models/doctor_model.dart';
import 'appointment_report_aggregator.dart';

/// Admin reports — appointment volume charts with optional doctor filter.
class AppointmentReportScreen extends StatefulWidget {
  const AppointmentReportScreen({super.key});

  @override
  State<AppointmentReportScreen> createState() =>
      _AppointmentReportScreenState();
}

class _AppointmentReportScreenState extends State<AppointmentReportScreen> {
  AppointmentReportPeriod _period = AppointmentReportPeriod.daily;
  String? _selectedDoctorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReportsHeader(
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Object?>>(
                stream: FirebaseFirestore.instance
                    .collection('doctors')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, doctorsSnap) {
                  final doctors = _parseDoctors(doctorsSnap.data?.docs);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _DoctorFilterDropdown(
                          doctors: doctors,
                          selectedDoctorId: _selectedDoctorId,
                          loading: doctorsSnap.connectionState ==
                              ConnectionState.waiting,
                          onChanged: (id) {
                            setState(() => _selectedDoctorId = id);
                          },
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Object?>>(
                          stream: FirebaseFirestore.instance
                              .collection('appointments')
                              .snapshots(),
                          builder: (context, appointmentsSnap) {
                            if (appointmentsSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !appointmentsSnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: OrthoqColors.navy,
                                ),
                              );
                            }

                            if (appointmentsSnap.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Could not load appointments.\n${appointmentsSnap.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              );
                            }

                            final allDocs =
                                appointmentsSnap.data?.docs ?? const [];
                            final filtered = filterAppointmentsByDoctor(
                              allDocs,
                              _selectedDoctorId,
                            );
                            final report =
                                buildAppointmentReportData(filtered);
                            final buckets = report.bucketsFor(_period);
                            final hasData =
                                buckets.any((b) => b.count > 0);
                            final chartMax =
                                AppointmentReportData.maxCountFor(buckets)
                                    .toDouble();
                            final now = DateTime.now();
                            final doctorScopeLabel = _doctorScopeLabel(
                              doctors,
                              _selectedDoctorId,
                            );
                            final chartKey =
                                '${_selectedDoctorId ?? kAllDoctorsFilterKey}_$_period';

                            return SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PeriodToggle(
                                    period: _period,
                                    onChanged: (p) =>
                                        setState(() => _period = p),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    periodSubtitle(
                                      _period,
                                      now,
                                      doctorScopeLabel: doctorScopeLabel,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (!hasData)
                                    _EmptyChartMessage(
                                      period: _period,
                                      doctorScopeLabel: doctorScopeLabel,
                                    )
                                  else
                                    _AppointmentBarChart(
                                      key: ValueKey(chartKey),
                                      buckets: buckets,
                                      maxY: chartMax,
                                      isMonthly: _period ==
                                          AppointmentReportPeriod.monthly,
                                    ),
                                  const SizedBox(height: 28),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Print / Export PDF — coming soon.',
                                          ),
                                          backgroundColor: OrthoqColors.navy,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.print_outlined),
                                    label: const Text('Print / Export'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: OrthoqColors.navy,
                                      side: const BorderSide(
                                        color: OrthoqColors.navy,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DoctorModel> _parseDoctors(
    List<QueryDocumentSnapshot<Object?>>? docs,
  ) {
    if (docs == null) return const [];
    return docs
        .map((doc) {
          final data = doc.data();
          if (data is! Map<String, dynamic>) return null;
          return DoctorModel.fromMap(data, doc.id);
        })
        .whereType<DoctorModel>()
        .toList();
  }

  String _doctorScopeLabel(List<DoctorModel> doctors, String? selectedId) {
    if (selectedId == null) return 'All doctors';
    final match = doctors.where((d) => d.id == selectedId).toList();
    if (match.isEmpty) return 'Selected doctor';
    final name = match.first.name.trim();
    return name.toLowerCase().startsWith('dr') ? name : 'Dr. $name';
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OrthoqColors.navy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Back',
            ),
            const Expanded(
              child: Text(
                'Reports',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorFilterDropdown extends StatelessWidget {
  const _DoctorFilterDropdown({
    required this.doctors,
    required this.selectedDoctorId,
    required this.loading,
    required this.onChanged,
  });

  final List<DoctorModel> doctors;
  final String? selectedDoctorId;
  final bool loading;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OrthoqColors.navy, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedDoctorId ?? kAllDoctorsFilterKey,
          icon: const Icon(Icons.arrow_drop_down, color: OrthoqColors.navy),
          style: const TextStyle(
            color: OrthoqColors.navy,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: kAllDoctorsFilterKey,
              child: Text('All Doctors'),
            ),
            ...doctors.map(
              (doctor) => DropdownMenuItem<String>(
                value: doctor.id,
                child: Text(
                  doctor.name.trim().toLowerCase().startsWith('dr')
                      ? doctor.name.trim()
                      : 'Dr. ${doctor.name.trim()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: loading
              ? null
              : (value) {
                  onChanged(
                    value == null || value == kAllDoctorsFilterKey
                        ? null
                        : value,
                  );
                },
        ),
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.period,
    required this.onChanged,
  });

  final AppointmentReportPeriod period;
  final ValueChanged<AppointmentReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppointmentReportPeriod>(
      segments: const [
        ButtonSegment(
          value: AppointmentReportPeriod.daily,
          label: Text('Daily'),
          icon: Icon(Icons.today_outlined, size: 18),
        ),
        ButtonSegment(
          value: AppointmentReportPeriod.monthly,
          label: Text('Monthly'),
          icon: Icon(Icons.calendar_month_outlined, size: 18),
        ),
      ],
      selected: {period},
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) onChanged(selected.first);
      },
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return OrthoqColors.navy;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return OrthoqColors.navy;
          return Colors.white;
        }),
      ),
    );
  }
}

class _EmptyChartMessage extends StatelessWidget {
  const _EmptyChartMessage({
    required this.period,
    required this.doctorScopeLabel,
  });

  final AppointmentReportPeriod period;
  final String doctorScopeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrthoqColors.lightSlate),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No appointments found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: OrthoqColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _emptyHint(period, doctorScopeLabel),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _emptyHint(AppointmentReportPeriod period, String doctorScope) {
    switch (period) {
      case AppointmentReportPeriod.daily:
        return 'No appointments this week (Mon–Sun) for $doctorScope.';
      case AppointmentReportPeriod.monthly:
        return 'No appointments this year (Jan–Dec) for $doctorScope.';
    }
  }
}

class _AppointmentBarChart extends StatelessWidget {
  const _AppointmentBarChart({
    super.key,
    required this.buckets,
    required this.maxY,
    required this.isMonthly,
  });

  final List<AppointmentReportBucket> buckets;
  final double maxY;
  final bool isMonthly;

  static const _leftAxisStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: OrthoqColors.navy,
  );

  @override
  Widget build(BuildContext context) {
    assert(buckets.length == 7 || buckets.length == 12);
    final chartMaxY = (maxY < 1 ? 4.0 : maxY * 1.2).ceilToDouble();
    final barWidth = isMonthly ? 12.0 : 24.0;

    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 20, isMonthly ? 4 : 12, 12),
        child: SizedBox(
          height: isMonthly ? 320 : 300,
          child: BarChart(
            BarChartData(
              alignment: isMonthly
                  ? BarChartAlignment.spaceBetween
                  : BarChartAlignment.spaceAround,
              maxY: chartMaxY,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: chartMaxY > 5 ? (chartMaxY / 5) : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: OrthoqColors.lightSlate,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      if (value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: _leftAxisStyle,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: isMonthly ? 44 : 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= buckets.length) {
                        return const SizedBox.shrink();
                      }
                      final label = Text(
                        buckets[i].label,
                        style: TextStyle(
                          fontSize: isMonthly ? 9 : 11,
                          fontWeight: FontWeight.w600,
                          color: OrthoqColors.navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      );
                      if (!isMonthly) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: label,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Transform.rotate(
                          angle: -0.45,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 34,
                            child: label,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(buckets.length, (i) {
                final count = buckets[i].count.toDouble();
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: count,
                      color: OrthoqColors.navy,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => OrthoqColors.navy,
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final bucket = buckets[group.x.toInt()];
                    return BarTooltipItem(
                      '${bucket.label}\n${bucket.count} appointment${bucket.count == 1 ? '' : 's'}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
  }
}
