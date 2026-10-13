import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

import 'storage_path_upload_stub.dart'
    if (dart.library.io) 'storage_path_upload_io.dart' as path_upload;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload referral letter
  Future<String> uploadReferralLetter({
    required String userId,
    required String appointmentId,
    required PlatformFile file,
  }) async {
    try {
      String fileName = 'referral_${DateTime.now().millisecondsSinceEpoch}.${file.extension ?? 'pdf'}';
      String path = 'referrals/$userId/$appointmentId/$fileName';

      Reference ref = _storage.ref().child(path);

      UploadTask uploadTask;
      if (file.bytes != null) {
        uploadTask = ref.putData(
          file.bytes!,
          SettableMetadata(contentType: _getContentType(file.extension)),
        );
      } else if (file.path != null) {
        uploadTask = path_upload.uploadFromPath(
          ref,
          file.path!,
          SettableMetadata(contentType: _getContentType(file.extension)),
        );
      } else {
        throw 'File data is null';
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Error uploading referral letter: $e';
    }
  }

  // Get content type based on file extension
  String? _getContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  // Delete referral letter
  Future<void> deleteReferralLetter(String fileUrl) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      throw 'Error deleting referral letter: $e';
    }
  }

  /// Uploads a patient profile photo to `profile_photos/{userId}.jpg`.
  Future<String> uploadProfilePhoto({
    required String userId,
    required String filePath,
  }) async {
    try {
      final ref = _storage.ref().child('profile_photos/$userId.jpg');
      final uploadTask = path_upload.uploadFromPath(
        ref,
        filePath,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw 'Error uploading profile photo: $e';
    }
  }

  /// Uploads profile photo from in-memory bytes (fallback when path is unavailable).
  Future<String> uploadProfilePhotoBytes({
    required String userId,
    required List<int> bytes,
  }) async {
    try {
      final ref = _storage.ref().child('profile_photos/$userId.jpg');
      final uploadTask = ref.putData(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw 'Error uploading profile photo: $e';
    }
  }
}
















