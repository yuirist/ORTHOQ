import 'package:firebase_storage/firebase_storage.dart';

UploadTask uploadFromPath(
  Reference ref,
  String path,
  SettableMetadata metadata,
) {
  throw UnsupportedError('Path-based upload is not available on web');
}
