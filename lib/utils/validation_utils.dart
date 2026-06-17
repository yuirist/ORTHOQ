/// Malaysian validation utilities for phone numbers and IC (MyKad) numbers.
/// 
/// These methods are designed to be reusable on both client-side (Flutter)
/// and server-side (Cloud Functions) for data integrity.
class ValidationUtils {
  /// Validates a Malaysian phone number.
  /// 
  /// Accepted formats:
  /// - 01X-XXXXXXX (10 digits with hyphen)
  /// - 01XXXXXXXXX (10-11 digits without hyphen)
  /// - +601XXXXXXXXX (international format)
  /// 
  /// Rules:
  /// - Must start with 01 or +601
  /// - Total numeric digits: 10 or 11
  /// - Allows optional hyphens but rejects spaces, letters, and special characters
  /// 
  /// Returns error message if invalid, null if valid.
  static String? validateMalaysianPhone(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      return 'Please enter a valid Malaysian phone number (e.g., 012-3456789).';
    }

    // Remove all whitespace for validation
    String cleaned = phoneNumber.trim().replaceAll(RegExp(r'\s+'), '');

    // Reject if contains letters
    if (RegExp(r'[a-zA-Z]').hasMatch(cleaned)) {
      return 'Please enter a valid Malaysian phone number (e.g., 012-3456789).';
    }

    // Remove optional hyphens and other non-digit chars (except +) for numeric count
    String digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9+]'), '');

    // Check length: must be 10 or 11 numeric digits (after removing +)
    String numericDigits = digitsOnly.replaceAll('+', '');
    if (numericDigits.length != 10 && numericDigits.length != 11) {
      return 'Please enter a valid Malaysian phone number (e.g., 012-3456789).';
    }

    // Additional check: Must start with 01 or +601
    if (!cleaned.startsWith('01') && !cleaned.startsWith('+601')) {
      return 'Please enter a valid Malaysian phone number (e.g., 012-3456789).';
    }

    // Validate format: 
    // - For 10 digits: 01X-XXXXXXX (01 + [1-9] + 7 digits) = 0 + 1 + [1-9] + 7 digits
    // - For 11 digits: +601XXXXXXXXX or 01XXXXXXXXXX (+601 or 01 + [1-9] + 8 digits)
    // Pattern: Remove prefix (0 or +60) to get core number starting with 1[1-9][0-9]{7,8}
    
    String normalizedForPattern = numericDigits;
    
    // Handle +601 format (12 digits: +60 + 1 + [1-9] + [0-9]{7,8})
    if (numericDigits.startsWith('60') && numericDigits.length == 12) {
      normalizedForPattern = numericDigits.substring(2); // Remove "60", keep "1..."
    }
    // Handle 01 format with 0 prefix (10 or 11 digits: 0 + 1 + [1-9] + [0-9]{7,8})
    else if (numericDigits.startsWith('0')) {
      normalizedForPattern = numericDigits.substring(1); // Remove "0", keep "1..."
    }
    // Handle format starting directly with 1 (shouldn't happen with Malaysian numbers, but handle it)
    // else: already starts with 1, use as is
    
    // Now check pattern: should be 1[1-9][0-9]{7,8} (9-10 digits after removing prefix)
    // This represents: 1 + second digit (1-9) + 7-8 more digits
    final phoneRegex = RegExp(r'^1[1-9][0-9]{7,8}$');
    
    if (!phoneRegex.hasMatch(normalizedForPattern)) {
      return 'Please enter a valid Malaysian phone number (e.g., 012-3456789).';
    }

    return null; // Valid
  }

  /// Strips hyphens and spaces from phone number for storage.
  /// 
  /// Converts formats like "012-3456789" or "+60123456789" to clean format
  /// suitable for database storage.
  static String normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.trim().replaceAll(RegExp(r'[\s-]'), '');
  }

  /// Validates digits typed after a visible `+60 ` field prefix.
  static String? validateMalaysianPhoneAfterPrefix(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }

    final digits = normalizePhoneNumber(value);

    if (digits.startsWith('0') || digits.startsWith('60')) {
      return 'Start typing directly after the +60 prefix';
    }

    if (digits.length < 9 || digits.length > 10) {
      return 'Enter a valid Malaysian phone number (9-10 digits)';
    }

    if (RegExp(r'[a-zA-Z]').hasMatch(digits)) {
      return 'Enter a valid Malaysian phone number (9-10 digits)';
    }

    // National mobile number after country code: 1[1-9] + 7–8 digits.
    final nationalNumberRegex = RegExp(r'^1[1-9][0-9]{7,8}$');
    if (!nationalNumberRegex.hasMatch(digits)) {
      return 'Enter a valid Malaysian phone number (9-10 digits)';
    }

    return null;
  }

  /// Stores Malaysian numbers as `60XXXXXXXXX` (no plus sign).
  static String normalizePhoneWithCountryCode(String value) {
    final trimmed = normalizePhoneNumber(value);
    if (trimmed.startsWith('60')) return trimmed;
    if (trimmed.startsWith('0')) return '60${trimmed.substring(1)}';
    return '60$trimmed';
  }

  /// Digits shown in a `+60 ` prefixed field (strips stored `60` / leading `0`).
  static String phoneDigitsForPrefixDisplay(String? storedPhone) {
    final raw = normalizePhoneNumber(storedPhone ?? '');
    if (raw.startsWith('60') && raw.length > 2) {
      return raw.substring(2);
    }
    if (raw.startsWith('0') && raw.length > 1) {
      return raw.substring(1);
    }
    return raw;
  }

  /// Validates a Malaysian IC (MyKad) number.
  /// 
  /// Format: YYMMDD-SS-#### (12 numeric digits ignoring optional hyphens)
  /// 
  /// Rules:
  /// - Must be exactly 12 numeric digits (ignoring hyphens)
  /// - First 6 digits (YYMMDD) must represent a valid date
  /// - 7th-8th digits (SS) must be between 01-59 (state code)
  /// - No letters allowed
  /// 
  /// Returns error message if invalid, null if valid.
  static String? validateMalaysianIC(String? icNumber) {
    if (icNumber == null || icNumber.trim().isEmpty) {
      return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
    }

    // Remove whitespace and hyphens for validation
    String cleaned = icNumber.trim().replaceAll(RegExp(r'[\s-]'), '');
    String digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');

    // Check length: must be exactly 12 digits
    if (digitsOnly.length != 12) {
      return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
    }

    // Check if contains any letters
    if (RegExp(r'[a-zA-Z]').hasMatch(icNumber)) {
      return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
    }

    // Extract components
    final yy = int.tryParse(digitsOnly.substring(0, 2));
    final mm = int.tryParse(digitsOnly.substring(2, 4));
    final dd = int.tryParse(digitsOnly.substring(4, 6));
    final ss = int.tryParse(digitsOnly.substring(6, 8));

    if (yy == null || mm == null || dd == null || ss == null) {
      return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
    }

    // Validate month (1-12)
    if (mm < 1 || mm > 12) {
      return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
    }

    // Validate day (1-31)
    if (dd < 1 || dd > 31) {
      return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
    }

    // Validate state code (01-59)
    if (ss < 1 || ss > 59) {
      return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
    }

    // Validate date existence (check if date is actually valid)
    // Convert 2-digit year to 4-digit (assume years 00-30 are 2000-2030, 31-99 are 1931-1999)
    int fullYear = yy < 31 ? 2000 + yy : 1900 + yy;

    // Check if date exists (e.g., reject Feb 30, April 31, etc.)
    try {
      final date = DateTime(fullYear, mm, dd);
      // Verify the date components match (to catch invalid dates like Feb 30)
      if (date.year != fullYear || date.month != mm || date.day != dd) {
        return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
      }
    } catch (e) {
      return 'Please enter a valid Malaysian IC number (e.g., 990101-14-5678).';
    }

    return null; // Valid
  }

  /// Extracts gender from Malaysian IC number.
  /// 
  /// Gender is determined by the 12th (last) digit:
  /// - Odd number (1, 3, 5, 7, 9) = Male
  /// - Even number (0, 2, 4, 6, 8) = Female
  /// 
  /// Returns 'Male' or 'Female', or null if IC is invalid.
  static String? extractGenderFromIC(String icNumber) {
    if (validateMalaysianIC(icNumber) != null) {
      return null; // Invalid IC
    }

    // Remove whitespace and hyphens
    String cleaned = icNumber.trim().replaceAll(RegExp(r'[\s-]'), '');
    String digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length != 12) {
      return null;
    }

    // Get 12th digit (last digit, index 11)
    final lastDigit = int.tryParse(digitsOnly[11]);

    if (lastDigit == null) {
      return null;
    }

    // Odd = Male, Even = Female
    return lastDigit.isOdd ? 'Male' : 'Female';
  }

  /// Strips hyphens and spaces from IC number for storage.
  /// 
  /// Converts format like "990101-14-5678" to "990101145678" for database storage.
  static String normalizeICNumber(String icNumber) {
    return icNumber.trim().replaceAll(RegExp(r'[\s-]'), '');
  }
}

