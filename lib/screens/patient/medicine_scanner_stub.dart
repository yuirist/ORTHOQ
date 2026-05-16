import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Web implementation: `tflite_flutter` is not available on web.
/// Kept API-compatible with [MedicineScannerPage] on mobile.
class MedicineScannerPage extends StatefulWidget {
  const MedicineScannerPage({
    super.key,
    this.launchSource,
    this.onLaunchHandled,
  });

  final ImageSource? launchSource;
  final VoidCallback? onLaunchHandled;

  @override
  State<MedicineScannerPage> createState() => _MedicineScannerPageState();
}

class _MedicineScannerPageState extends State<MedicineScannerPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Medicine Scanner is available on mobile only.'),
      ),
    );
  }
}
