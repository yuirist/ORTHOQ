import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of running the on-device medicine / image classifier.
class MedicineInferenceResult {
  MedicineInferenceResult({
    required this.label,
    required this.confidence,
    required this.isConfident,
  });

  /// Best-matching class label from [labels.txt] (aligned to model output index).
  final String label;

  /// Top confidence in the range [0, 1] after any softmax normalization.
  final double confidence;

  /// `true` when [confidence] is at least 75%.
  final bool isConfident;
}

/// Loads the Teachable Machine (or compatible) TFLite model from assets and runs inference.
class MedicineAIService {
  MedicineAIService._();

  static final MedicineAIService instance = MedicineAIService._();

  Interpreter? _interpreter;
  List<String> _labels = [];

  static const double _confidenceThreshold = 0.75;
  static const int _defaultInputSide = 224;

  /// Clears any cached interpreter (e.g. after replacing [assets/model.tflite]).
  void reset() {
    _interpreter?.close();
    _interpreter = null;
    _labels = [];
  }

  Future<void> _ensureModel() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      final raw = await rootBundle.loadString('assets/labels.txt');
      _labels = _parseLabels(raw);
      if (_labels.isEmpty) {
        _interpreter?.close();
        _interpreter = null;
        throw StateError('No labels found in assets/labels.txt');
      }
    } catch (e, st) {
      _interpreter?.close();
      _interpreter = null;
      _labels = [];
      debugPrint('MedicineAIService: failed to load model: $e\n$st');
      rethrow;
    }
  }

  static List<String> _parseLabels(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final out = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Teachable Machine / some exports: "0 panadol"
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2 && int.tryParse(parts.first) != null) {
        out.add(parts.sublist(1).join(' ').trim());
      } else {
        out.add(trimmed);
      }
    }
    return out;
  }

  /// Opens the camera, runs inference, and returns the top class.
  Future<MedicineInferenceResult> captureAndClassify() =>
      pickAndClassify(ImageSource.camera);

  /// Picks an image from [source] (camera or gallery), then runs inference.
  /// Uses [maxWidth]/[maxHeight] 600 so large camera photos (e.g. Samsung Galaxy Note9 SM-N960F)
  /// stay within a safe decode size before TFLite inference.
  Future<MedicineInferenceResult> pickAndClassify(ImageSource source) async {
    await _ensureModel();
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (xfile == null) {
      throw StateError('No image selected.');
    }
    return classifyImageFile(File(xfile.path));
  }

  Future<MedicineInferenceResult> classifyImageFile(File file) async {
    await _ensureModel();
    final interpreter = _interpreter!;

    final inputTensor = interpreter.getInputTensor(0);
    final shape = inputTensor.shape;
    final h = shape.length >= 3 ? shape[shape.length - 3] : _defaultInputSide;
    final w = shape.length >= 2 ? shape[shape.length - 2] : _defaultInputSide;
    final side = h == w ? h : _defaultInputSide;

    final rgb = await _resizeToRgbFloats(file, side);

    final inputObject = _buildNestedInput(
      rgbFloats: rgb,
      side: side,
      type: inputTensor.type,
    );

    final outputTensor = interpreter.getOutputTensor(0);
    final outputObject = _nestedZeros(outputTensor.shape);

    interpreter.run(inputObject, outputObject);

    final scores = _scoresFromOutput(outputObject, outputTensor);
    if (scores.isEmpty) {
      throw StateError('Model produced no scores.');
    }

    var probs = _toProbabilities(scores);
    var bestI = 0;
    var best = probs[0];
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > best) {
        best = probs[i];
        bestI = i;
      }
    }

    final label = bestI < _labels.length ? _labels[bestI] : 'class_$bestI';
    final confidence = best.clamp(0.0, 1.0);

    return MedicineInferenceResult(
      label: label,
      confidence: confidence,
      isConfident: confidence >= _confidenceThreshold,
    );
  }

  /// RGB floats in [0, 1], length [side * side * 3], row-major HWC.
  static Future<Float32List> _resizeToRgbFloats(File file, int side) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
      paint,
    );
    image.dispose();

    final picture = recorder.endRecording();
    final resized = await picture.toImage(side, side);
    picture.dispose();

    final rgba = await resized.toByteData(format: ui.ImageByteFormat.rawRgba);
    resized.dispose();

    if (rgba == null) {
      throw StateError('Could not read image pixels.');
    }

    final out = Float32List(side * side * 3);
    var o = 0;
    for (var i = 0; i < rgba.lengthInBytes; i += 4) {
      out[o++] = rgba.getUint8(i) / 255.0;
      out[o++] = rgba.getUint8(i + 1) / 255.0;
      out[o++] = rgba.getUint8(i + 2) / 255.0;
    }
    return out;
  }

  static Object _buildNestedInput({
    required Float32List rgbFloats,
    required int side,
    required TensorType type,
  }) {
    // Innermost pixel: uint8 uses 0–255 ints; float32 uses normalized doubles.
    final plane = List.generate(
      side,
      (y) => List.generate(
        side,
        (x) {
          final i = (y * side + x) * 3;
          final r = rgbFloats[i];
          final g = rgbFloats[i + 1];
          final b = rgbFloats[i + 2];
          if (type == TensorType.uint8) {
            return [
              (r * 255.0).round().clamp(0, 255),
              (g * 255.0).round().clamp(0, 255),
              (b * 255.0).round().clamp(0, 255),
            ];
          }
          return [r, g, b];
        },
      ),
    );
    return [plane];
  }

  static Object _nestedZeros(List<int> shape) {
    if (shape.isEmpty) {
      return 0;
    }
    if (shape.length == 1) {
      return List<dynamic>.filled(shape[0], 0);
    }
    return List<dynamic>.generate(
      shape[0],
      (_) => _nestedZeros(shape.sublist(1)),
    );
  }

  static List<double> _scoresFromOutput(Object out, Tensor tensor) {
    final flat = _flattenNums(out);
    final qp = tensor.params;
    switch (tensor.type) {
      case TensorType.uint8:
        return flat.map((e) {
          final q = e.round().clamp(0, 255);
          return (q - qp.zeroPoint) * qp.scale;
        }).toList();
      case TensorType.int8:
        return flat.map((e) {
          final q = e.round().clamp(-128, 127);
          return (q - qp.zeroPoint) * qp.scale;
        }).toList();
      case TensorType.float32:
      case TensorType.float16:
        return flat.map((e) => e.toDouble()).toList();
      default:
        return flat.map((e) => e.toDouble()).toList();
    }
  }

  static List<double> _flattenNums(Object o) {
    if (o is num) {
      return [o.toDouble()];
    }
    if (o is List) {
      final out = <double>[];
      for (final e in o) {
        out.addAll(_flattenNums(e));
      }
      return out;
    }
    return [];
  }

  /// If values already look like probabilities, keep them; otherwise softmax.
  static List<double> _toProbabilities(List<double> scores) {
    if (scores.isEmpty) return scores;
    final minV = scores.reduce(math.min);
    final maxV = scores.reduce(math.max);
    final sum = scores.fold<double>(0, (a, b) => a + b);
    final looksLikeProb =
        minV >= -0.05 && maxV <= 1.05 && (sum - 1.0).abs() < 0.35;
    if (looksLikeProb) {
      return scores.map((e) => e.clamp(0.0, 1.0)).toList();
    }
    var m = scores[0];
    for (final v in scores) {
      if (v > m) m = v;
    }
    var expSum = 0.0;
    final exps = List<double>.filled(scores.length, 0);
    for (var i = 0; i < scores.length; i++) {
      exps[i] = math.exp(scores[i] - m);
      expSum += exps[i];
    }
    if (expSum <= 0) {
      return List<double>.filled(scores.length, 1.0 / scores.length);
    }
    return exps.map((e) => e / expSum).toList();
  }
}
