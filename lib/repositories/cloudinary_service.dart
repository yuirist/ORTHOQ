import 'dart:convert';
import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Uploads referral letters and other documents to Cloudinary.
///
/// Uses the `/auto/upload` endpoint with `resource_type: auto` so PDFs are
/// stored correctly (not as broken image assets).
class CloudinaryService {
  CloudinaryService({
    String cloudName = 'dfz9svj5s',
    String uploadPreset = 'orthoq_app',
    Dio? dio,
  })  : _cloudName = cloudName,
        _uploadPreset = uploadPreset,
        _dio = dio ?? Dio();

  static const String referralAllowedExtensionsHint =
      'PDF, JPG, JPEG, PNG';

  static const List<String> _referralExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
  ];

  final String _cloudName;
  final String _uploadPreset;
  final Dio _dio;

  String get _autoUploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  /// Picks a referral file (PDF or image).
  Future<PlatformFile?> pickReferralFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _referralExtensions,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (!kIsWeb && (file.path == null || file.path!.isEmpty)) {
      return null;
    }
    if (kIsWeb && file.bytes == null) {
      return null;
    }
    return file;
  }

  /// Uploads [file] and returns the HTTPS [secure_url] from Cloudinary.
  Future<String> uploadReferralLetter(PlatformFile file) async {
    final multipart = await _toMultipartFile(file);

    final formData = FormData.fromMap({
      'file': multipart,
      'upload_preset': _uploadPreset,
      'resource_type': 'auto',
    });

    final response = await _dio.post<Map<String, dynamic>>(
      _autoUploadUrl,
      data: formData,
    );

    if (response.statusCode != 200 || response.data == null) {
      throw CloudinaryException(
        jsonEncode(response.data),
        response.statusCode ?? 0,
      );
    }

    return secureUrlFromMap(response.data!);
  }

  /// Uploads a doctor profile photo and returns the HTTPS delivery URL.
  Future<String> uploadDoctorProfileImage(File file) async {
    final pathSegments = file.path.split(Platform.pathSeparator);
    final filename = pathSegments.isNotEmpty && pathSegments.last.isNotEmpty
        ? pathSegments.last
        : 'doctor_profile.jpg';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: filename),
      'upload_preset': _uploadPreset,
      'resource_type': 'image',
      'folder': 'doctors',
    });

    final response = await _dio.post<Map<String, dynamic>>(
      _autoUploadUrl,
      data: formData,
    );

    if (response.statusCode != 200 || response.data == null) {
      throw CloudinaryException(
        jsonEncode(response.data),
        response.statusCode ?? 0,
      );
    }

    return secureUrlFromMap(response.data!);
  }

  /// Prefer [secure_url]; fall back to [url] upgraded to HTTPS.
  static String secureUrlFromMap(Map<String, dynamic> data) {
    final secure = data['secure_url']?.toString().trim() ?? '';
    if (secure.isNotEmpty) return secure;

    final url = data['url']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw StateError('Cloudinary response did not include a delivery URL');
    }
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  /// Prefer [CloudinaryResponse.secureUrl] for Firestore storage / display.
  static String secureUrlFromResponse(CloudinaryResponse response) {
    if (response.secureUrl.trim().isNotEmpty) {
      return response.secureUrl.trim();
    }
    return secureUrlFromMap(response.data);
  }

  static bool isPdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.pdf') || lower.contains('/raw/upload/');
  }

  Future<MultipartFile> _toMultipartFile(PlatformFile file) async {
    final filename = file.name.isNotEmpty ? file.name : 'referral';

    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      return MultipartFile.fromFile(file.path!, filename: filename);
    }

    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: filename);
    }

    throw StateError('Could not read the selected file');
  }
}
