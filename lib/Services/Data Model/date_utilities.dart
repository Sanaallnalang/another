// date_utilities.dart
// Centralized date parsing and calculation utilities

class DateUtilities {
  /// Calculate age in months from date of birth
  static int? calculateAgeInMonths(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return null;

    try {
      final dob = DateTime.tryParse(dateOfBirth);
      if (dob == null) return null;

      final now = DateTime.now();
      final months = (now.year - dob.year) * 12 + (now.month - dob.month);
      return months > 0 ? months : 0;
    } catch (e) {
      return null;
    }
  }

  /// Calculate age in years from date of birth
  static int? calculateAgeInYears(String? dateOfBirth) {
    final months = calculateAgeInMonths(dateOfBirth);
    return months != null ? (months / 12).floor() : null;
  }

  /// Parse various date formats commonly found in Excel files
  static DateTime? parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    try {
      // Handle Excel serial dates (days since 1900-01-01)
      if (_isNumeric(dateStr)) {
        final serial = double.tryParse(dateStr);
        if (serial != null && serial > 100) {
          final date = DateTime(
            1899,
            12,
            30,
          ).add(Duration(days: serial.toInt()));
          if (_isReasonableDate(date)) {
            return date;
          }
        }
      }

      // Common date formats in SBFP Excel files
      final formats = [
        'MMMM d, yyyy', // "August 9, 2013"
        'MMM d, yyyy', // "Aug 9, 2013"
        'MM/dd/yyyy', // "08/09/2013"
        'dd/MM/yyyy', // "09/08/2013"
        'yyyy-MM-dd', // "2013-08-09"
        'MM-dd-yyyy', // "08-09-2013"
        'dd-MM-yyyy', // "09-08-2013"
      ];

      for (final format in formats) {
        try {
          // Using manual parsing to avoid intl package dependency
          final parsed = _parseWithFormat(dateStr, format);
          if (parsed != null && _isReasonableDate(parsed)) {
            return parsed;
          }
        } catch (_) {}
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Format date to ISO string for database storage
  static String formatDateForDB(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if date is within reasonable range (not future and not too old)
  static bool _isReasonableDate(DateTime date) {
    final now = DateTime.now();
    return date.year > now.year - 25 && date.year <= now.year + 1;
  }

  /// Check if string is numeric
  static bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  /// Manual date parsing for common formats
  static DateTime? _parseWithFormat(String dateStr, String format) {
    try {
      if (format == 'MMMM d, yyyy' || format == 'MMM d, yyyy') {
        // Handle "August 9, 2013" or "Aug 9, 2013"
        final parts = dateStr.split(' ');
        if (parts.length >= 3) {
          final month = _parseMonth(parts[0]);
          final day = int.tryParse(parts[1].replaceAll(',', '')) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
          if (month != null) {
            return DateTime(year, month, day);
          }
        }
      } else if (format == 'MM/dd/yyyy' || format == 'dd/MM/yyyy') {
        // Handle "08/09/2013"
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final month = int.tryParse(parts[0]) ?? 1;
          final day = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
          return DateTime(year, month, day);
        }
      } else if (format == 'yyyy-MM-dd') {
        // Handle "2013-08-09"
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]) ?? DateTime.now().year;
          final month = int.tryParse(parts[1]) ?? 1;
          final day = int.tryParse(parts[2]) ?? 1;
          return DateTime(year, month, day);
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Parse month name to number
  static int? _parseMonth(String monthStr) {
    final months = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    return months[monthStr.toLowerCase()];
  }

  /// Get current school year in format "2024-2025"
  static String getCurrentSchoolYear() {
    final now = DateTime.now();
    final year = now.year;
    // If after June, consider it the start of next school year
    if (now.month >= 6) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  /// Validate school year format (YYYY-YYYY or YYYY/YYYY)
  static bool isValidSchoolYear(String schoolYear) {
    return RegExp(r'^\d{4}[-/]\d{4}$').hasMatch(schoolYear);
  }

  /// 🆕 NEW: Calculate age in months at specific assessment date
  static int? calculateAgeAtAssessment(
    String? dateOfBirth,
    String? assessmentDate,
  ) {
    if (dateOfBirth == null || assessmentDate == null) return null;

    try {
      final dob = DateTime.tryParse(dateOfBirth);
      final assessment = DateTime.tryParse(assessmentDate);

      if (dob == null || assessment == null) return null;

      final months =
          (assessment.year - dob.year) * 12 + (assessment.month - dob.month);
      return months > 0 ? months : 0;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 NEW: Validate assessment period dates
  static Map<String, dynamic> validateAssessmentPeriod(
    String baselineDate,
    String endlineDate,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    final baseline = DateTime.tryParse(baselineDate);
    final endline = DateTime.tryParse(endlineDate);

    if (baseline == null) {
      errors.add('Invalid baseline date format');
    }

    if (endline == null) {
      errors.add('Invalid endline date format');
    }

    if (baseline != null && endline != null) {
      if (endline.isBefore(baseline)) {
        errors.add('Endline date cannot be before baseline date');
      }

      final difference = endline.difference(baseline).inDays;
      if (difference < 30) {
        warnings.add('Assessment period is very short (less than 30 days)');
      } else if (difference > 365) {
        warnings.add('Assessment period is very long (more than 1 year)');
      }
    }

    return {'isValid': errors.isEmpty, 'errors': errors, 'warnings': warnings};
  }

  /// 🆕 NEW: Get academic year from date
  static String getAcademicYearFromDate(DateTime date) {
    final year = date.year;
    final month = date.month;

    if (month >= 6) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  /// 🆕 NEW: Format date for display
  static String formatDateForDisplay(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// 🆕 NEW: Check if date is within school year
  static bool isDateInSchoolYear(DateTime date, String schoolYear) {
    if (!isValidSchoolYear(schoolYear)) return false;

    final parts = schoolYear.split(RegExp(r'[-/]'));
    final startYear = int.tryParse(parts[0]);
    final endYear = int.tryParse(parts[1]);

    if (startYear == null || endYear == null) return false;

    // School year typically runs from June to May
    final schoolYearStart = DateTime(startYear, 6, 1);
    final schoolYearEnd = DateTime(endYear, 5, 31);

    return (date.isAfter(schoolYearStart) ||
            date.isAtSameMomentAs(schoolYearStart)) &&
        (date.isBefore(schoolYearEnd) || date.isAtSameMomentAs(schoolYearEnd));
  }
}
