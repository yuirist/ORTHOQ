/// Strips leading "Dr." / "Dr " prefixes from a stored doctor name.
String stripDoctorPrefix(String raw) {
  var name = raw.trim();
  while (name.isNotEmpty) {
    final lower = name.toLowerCase();
    if (lower.startsWith('dr.')) {
      name = name.substring(3).trim();
    } else if (lower.startsWith('dr ')) {
      name = name.substring(3).trim();
    } else {
      break;
    }
  }
  return name;
}

/// Formats a stored doctor name for UI display (e.g. "Dr. Jamal Bin Kassim").
String formatDoctorDisplayName(String raw) {
  final clean = stripDoctorPrefix(raw);
  if (clean.isEmpty) return 'Doctor';
  return 'Dr. $clean';
}
