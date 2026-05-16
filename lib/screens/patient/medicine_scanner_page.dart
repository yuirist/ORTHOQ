import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/medicine_ai_service.dart';

const String _medicineDisclaimer =
    'For assistance only. Consult a doctor before use.';

/// On-device scan flow + Firestore [medicines] lookup and fact sheet UI.
class MedicineScannerPage extends StatefulWidget {
  const MedicineScannerPage({
    super.key,
    this.launchSource,
    this.onLaunchHandled,
  });

  /// When set (e.g. from bottom navigation), classification starts after first frame.
  final ImageSource? launchSource;

  /// Called after a [launchSource] run is started so the parent can clear it.
  final VoidCallback? onLaunchHandled;

  @override
  State<MedicineScannerPage> createState() => _MedicineScannerPageState();
}

class _MedicineScannerPageState extends State<MedicineScannerPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.launchSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final src = widget.launchSource;
        if (src != null) {
          await _runInference(src);
        }
        widget.onLaunchHandled?.call();
      });
    }
  }

  @override
  void didUpdateWidget(MedicineScannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.launchSource != null && widget.launchSource != oldWidget.launchSource) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final src = widget.launchSource;
        if (src != null) {
          await _runInference(src);
        }
        widget.onLaunchHandled?.call();
      });
    }
  }

  Future<void> _runInference(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await MedicineAIService.instance.pickAndClassify(source);
      if (!mounted) return;

      if (!result.isConfident) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Identification unclear'),
            content: const Text(
              'Confidence is below 75%. Please try again with a clearer, well-lit image.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final docId = _firestoreDocIdForLabel(result.label);
      final snap = await FirebaseFirestore.instance
          .collection('medicines')
          .doc(docId)
          .get();

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _MedicineFactSheet(
          inference: result,
          docId: docId,
          snapshot: snap,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ImageSource?> _askSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFF1A365D)),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF1A365D)),
                  title: const Text('Upload from Gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onChooseSourcePressed() async {
    final source = await _askSource();
    if (!mounted || source == null) return;
    await _runInference(source);
  }

  static String _firestoreDocIdForLabel(String label) {
    return label.trim().replaceAll('/', '_');
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1A365D);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Scanner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: navy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.medication_outlined,
                            color: navy,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Choose a photo of the medicine packaging or label. '
                            'Images are resized to at most 600×600 before on-device analysis.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _onChooseSourcePressed,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(_busy ? 'Working…' : 'Take Photo or Upload from Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  side: const BorderSide(color: navy),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              _medicineDisclaimer,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineFactSheet extends StatelessWidget {
  const _MedicineFactSheet({
    required this.inference,
    required this.docId,
    required this.snapshot,
  });

  final MedicineInferenceResult inference;
  final String docId;
  final DocumentSnapshot<Map<String, dynamic>> snapshot;

  String _pickString(Map<String, dynamic>? data, List<String> keys, String fallback) {
    if (data == null) return fallback;
    for (final k in keys) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1A365D);
    final data = snapshot.data();
    final exists = snapshot.exists && data != null;

    final displayName = exists
        ? _pickString(data, const ['displayName', 'name'], docId)
        : docId;
    final purpose = exists
        ? _pickString(data, const ['purpose', 'usage', 'indication'], '—')
        : 'No matching record in the clinic database.';
    final dosage = exists
        ? _pickString(
            data,
            const ['dosage', 'recommendedDosage', 'recommended_dosage'],
            '—',
          )
        : '—';

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(0, -4),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.fact_check_outlined, color: navy, size: 26),
                  const SizedBox(width: 10),
                  const Text(
                    'Medicine details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Model match: ${inference.label} '
                '(${(inference.confidence * 100).toStringAsFixed(1)}% confidence)',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              _FactRow(title: 'Medicine Name', value: displayName),
              const SizedBox(height: 14),
              _FactRow(title: 'Purpose', value: purpose),
              const SizedBox(height: 14),
              _FactRow(title: 'Dosage', value: dosage),
              if (!exists) ...[
                const SizedBox(height: 16),
                Material(
                  color: const Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade900),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Firestore has no document `medicines/$docId`. '
                            'Add a document with that ID or align your model labels.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade900,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                _medicineDisclaimer,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            height: 1.35,
            color: Color(0xFF1A202C),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
