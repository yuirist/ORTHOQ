import 'package:cloud_firestore/cloud_firestore.dart';

/// Safe display string for UI (handles [Timestamp], [String], or null).
String firestoreDateToDisplayString(dynamic dateValue) {
  if (dateValue == null) return '';
  return (dateValue is Timestamp)
      ? dateValue.toDate().toString()
      : dateValue.toString();
}

/// Parses Firestore [Timestamp], ISO [String], or [DateTime] to [DateTime].
DateTime parseFirestoreDateTime(
  dynamic value, {
  DateTime? fallback,
}) {
  if (value == null) {
    return fallback ?? DateTime.now();
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return fallback ?? DateTime.now();
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return fallback ?? DateTime.now();
}

/// Nullable variant — returns null when [value] is missing or unparseable.
DateTime? parseFirestoreDateTimeNullable(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}
