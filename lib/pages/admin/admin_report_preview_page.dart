import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:orthoq_app/theme/orthoq_colors.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'appointment_report_aggregator.dart';

const Map<String, String> _pdfWeekdayLabels = {
  'Mon': 'Monday',
  'Tue': 'Tuesday',
  'Wed': 'Wednesday',
  'Thu': 'Thursday',
  'Fri': 'Friday',
  'Sat': 'Saturday',
  'Sun': 'Sunday',
};

const Map<String, String> _pdfMonthLabels = {
  'Jan': 'January',
  'Feb': 'February',
  'Mar': 'March',
  'Apr': 'April',
  'May': 'May',
  'Jun': 'June',
  'Jul': 'July',
  'Aug': 'August',
  'Sep': 'September',
  'Oct': 'October',
  'Nov': 'November',
  'Dec': 'December',
};

Future<Uint8List> _generateReportPdf({
  required AppointmentReportPeriod period,
  required String subtitle,
  required List<AppointmentReportBucket> buckets,
  required String doctorScopeLabel,
  required int totalAppointments,
}) async {
  final pdf = pw.Document();
  final generatedAt = DateTime.now();
  final periodLabel =
      period == AppointmentReportPeriod.daily ? 'Daily' : 'Monthly';
  final breakdownTitle = period == AppointmentReportPeriod.daily
      ? 'Appointments by day'
      : 'Appointments by month';
  final labelMap = period == AppointmentReportPeriod.daily
      ? _pdfWeekdayLabels
      : _pdfMonthLabels;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'OrthoQ Appointment Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Generated: ${generatedAt.day}/${generatedAt.month}/${generatedAt.year}',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Report Summary',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.Text('Period: $periodLabel'),
              pw.Text('Scope: $doctorScopeLabel'),
              pw.Text('Range: $subtitle'),
              pw.Text('Total appointments: $totalAppointments'),
              pw.SizedBox(height: 20),
              pw.Text(
                breakdownTitle,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              ...buckets.map(
                (bucket) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(labelMap[bucket.label] ?? bucket.label),
                      pw.Text('${bucket.count}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return pdf.save();
}

/// Print-friendly preview of the admin appointment report.
class AdminReportPreviewPage extends StatelessWidget {
  const AdminReportPreviewPage({
    super.key,
    required this.period,
    required this.subtitle,
    required this.buckets,
    required this.doctorScopeLabel,
  });

  final AppointmentReportPeriod period;
  final String subtitle;
  final List<AppointmentReportBucket> buckets;
  final String doctorScopeLabel;

  int get _totalAppointments =>
      buckets.fold<int>(0, (sum, bucket) => sum + bucket.count);

  String get _pdfFileName {
    final now = DateTime.now();
    return 'OrthoQ_Report_${now.year}_${now.month}_${now.day}.pdf';
  }

  Future<void> _exportPdf(BuildContext context) async {
    try {
      final pdfData = await _generateReportPdf(
        period: period,
        subtitle: subtitle,
        buckets: buckets,
        doctorScopeLabel: doctorScopeLabel,
        totalAppointments: _totalAppointments,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: _pdfFileName,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodLabel =
        period == AppointmentReportPeriod.daily ? 'Daily' : 'Monthly';

    return Scaffold(
      backgroundColor: OrthoqColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Report Preview'),
        backgroundColor: OrthoqColors.navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  color: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OrthoQ Appointment Report',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: OrthoqColors.navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generated ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Divider(height: 32),
                        _SummaryRow(label: 'Period', value: periodLabel),
                        const SizedBox(height: 8),
                        _SummaryRow(label: 'Scope', value: doctorScopeLabel),
                        const SizedBox(height: 8),
                        _SummaryRow(label: 'Range', value: subtitle),
                        const SizedBox(height: 8),
                        _SummaryRow(
                          label: 'Total appointments',
                          value: '$_totalAppointments',
                        ),
                        const SizedBox(height: 24),
                        Text(
                          period == AppointmentReportPeriod.daily
                              ? 'Appointments by day'
                              : 'Appointments by month',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: OrthoqColors.navy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...buckets.map(
                          (bucket) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    bucket.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _totalAppointments == 0
                                          ? 0
                                          : bucket.count / _totalAppointments,
                                      minHeight: 10,
                                      backgroundColor: OrthoqColors.lightSlate,
                                      color: OrthoqColors.navy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '${bucket.count}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: OutlinedButton.icon(
                onPressed: () => _exportPdf(context),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OrthoqColors.navy,
                  side: const BorderSide(color: OrthoqColors.navy),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OrthoqColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}
