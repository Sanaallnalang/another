// academic_year_manager.dart - COMPLETE FIXED VERSION
import 'package:flutter/foundation.dart';

class AcademicYearManager {
  /// Get current school year (Philippine system: June to March next year)
  static String getCurrentSchoolYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Philippine school year: June (6) to March (3) of next year
    if (currentMonth >= 6) {
      return '$currentYear-${currentYear + 1}';
    } else {
      return '${currentYear - 1}-$currentYear';
    }
  }

  /// Detect school year from date
  static String detectSchoolYearFromDate(DateTime date) {
    final year = date.year;
    final month = date.month;

    if (month >= 6) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  /// Parse any academic year string to standard format
  static String parseAcademicYear(String yearString) {
    if (yearString.isEmpty) return getCurrentSchoolYear();

    final cleaned = yearString.trim().toLowerCase();

    // Remove common prefixes
    final cleanedString = cleaned
        .replaceAll('school year', '')
        .replaceAll('sy', '')
        .replaceAll('academic year', '')
        .replaceAll('ay', '')
        .trim();

    // Try direct format parsing
    if (isValidSchoolYear(cleanedString)) {
      return cleanedString;
    }

    // Try to extract years
    final yearMatches = RegExp(r'\d{4}').allMatches(cleanedString);
    if (yearMatches.length >= 2) {
      final years = yearMatches.map((m) => m.group(0)!).toList();
      final start = years[0];
      final end = years[1];
      return '$start-$end';
    } else if (yearMatches.length == 1) {
      final year = yearMatches.first.group(0)!;
      final yearNum = int.tryParse(year);
      if (yearNum != null) {
        return '$yearNum-${yearNum + 1}';
      }
    }

    // Try short format (e.g., 2023-24)
    final shortMatch = RegExp(r'(\d{4})[-_](\d{2})').firstMatch(cleanedString);
    if (shortMatch != null) {
      final startYear = shortMatch.group(1)!;
      final endShort = shortMatch.group(2)!;
      final startNum = int.tryParse(startYear);
      final endNum = int.tryParse(endShort);

      if (startNum != null && endNum != null) {
        // Determine if endShort is 2-digit (e.g., 24 means 2024)
        if (endShort.length == 2) {
          final century = (startNum ~/ 100) * 100;
          final fullEndYear = century + endNum;
          if (fullEndYear == startNum + 1) {
            return '$startYear-$fullEndYear';
          }
        } else {
          return '$startYear-$endNum';
        }
      }
    }

    // Fallback to current school year
    return getCurrentSchoolYear();
  }

  /// Extract year from filename for import matching
  static String? extractYearFromFileName(String fileName) {
    if (fileName.isEmpty) return null;

    // Try various filename patterns
    final patterns = [
      // Pattern 1: "SBFP_Baseline_2023-2024.xlsx" or "Endline_2024-2025.csv"
      RegExp(
        r'(?:(?:baseline|endline|sbfp)[_\s-]*)?(\d{4})[-_\s](\d{4})',
        caseSensitive: false,
      ),

      // Pattern 2: "Nutrition_Assessment_SY2023-2024.xlsx"
      RegExp(
        r'(?:sy|school[_\s]year)[_\s-]*(\d{4})[-_\s](\d{4})',
        caseSensitive: false,
      ),

      // Pattern 3: "2023-2024_BMI_Data.xlsx"
      RegExp(r'^(\d{4})[-_\s](\d{4})'),

      // Pattern 4: Just a year "2023" or "2024"
      RegExp(r'\b(20\d{2})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fileName);
      if (match != null) {
        if (match.groupCount >= 2) {
          // Two years found
          final startYear = match.group(1)!;
          final endYear = match.group(2)!;

          // Handle 2-digit end year (e.g., 2023-24)
          if (endYear.length == 2) {
            final startNum = int.tryParse(startYear);
            if (startNum != null) {
              final fullEndYear = startNum + 1;
              return '$startYear-$fullEndYear';
            }
          }

          // Full years found
          return '$startYear-$endYear';
        } else if (match.groupCount >= 1) {
          // Single year found
          final yearStr = match.group(1)!;
          final yearNum = int.tryParse(yearStr);
          if (yearNum != null && yearNum >= 2000 && yearNum <= 2100) {
            return '$yearNum-${yearNum + 1}';
          }
        }
      }
    }

    return null;
  }

  /// Validate school year format
  static bool isValidSchoolYear(String schoolYear) {
    final pattern = RegExp(r'^\d{4}-\d{4}$');
    if (!pattern.hasMatch(schoolYear)) return false;

    final parts = schoolYear.split('-');
    final startYear = int.tryParse(parts[0]);
    final endYear = int.tryParse(parts[1]);

    return startYear != null && endYear != null && endYear == startYear + 1;
  }

  /// Compare school years (newest first)
  static int compareSchoolYears(String year1, String year2) {
    if (!isValidSchoolYear(year1) || !isValidSchoolYear(year2)) return 0;

    final start1 = int.parse(year1.split('-')[0]);
    final start2 = int.parse(year2.split('-')[0]);

    return start2.compareTo(start1); // Newest first
  }

  /// Format school year for display
  static String formatSchoolYearForDisplay(
    String schoolYear, {
    bool shortFormat = false,
  }) {
    if (!isValidSchoolYear(schoolYear)) return schoolYear;

    final parts = schoolYear.split('-');
    if (shortFormat) {
      // Display as "SY 2023-24"
      final startYear = parts[0];
      final endShort = parts[1].substring(2); // Last 2 digits
      return 'SY $startYear-$endShort';
    } else {
      return 'School Year $schoolYear';
    }
  }

  /// Get next school year
  static String getNextSchoolYear(String currentSchoolYear) {
    if (!isValidSchoolYear(currentSchoolYear)) {
      return getCurrentSchoolYear();
    }

    final parts = currentSchoolYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);

    return '${startYear + 1}-${endYear + 1}';
  }

  /// Get previous school year
  static String getPreviousSchoolYear(String currentSchoolYear) {
    if (!isValidSchoolYear(currentSchoolYear)) {
      return getCurrentSchoolYear();
    }

    final parts = currentSchoolYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);

    return '${startYear - 1}-${endYear - 1}';
  }

  /// Get available school years
  static List<String> getAvailableSchoolYears({int yearsBack = 5}) {
    final currentSY = getCurrentSchoolYear();
    final years = <String>[currentSY];

    for (int i = 1; i <= yearsBack; i++) {
      final parts = currentSY.split('-');
      final startYear = int.parse(parts[0]) - i;
      final endYear = int.parse(parts[1]) - i;
      years.add('$startYear-$endYear');
    }

    return years;
  }

  /// Check if school year is in the past
  static bool isPastSchoolYear(String schoolYear) {
    if (!isValidSchoolYear(schoolYear)) return false;

    final currentSY = getCurrentSchoolYear();
    final currentParts = currentSY.split('-');
    final inputParts = schoolYear.split('-');

    final currentStart = int.parse(currentParts[0]);
    final inputStart = int.parse(inputParts[0]);

    return inputStart < currentStart;
  }

  /// Check if school year is in the future
  static bool isFutureSchoolYear(String schoolYear) {
    if (!isValidSchoolYear(schoolYear)) return false;

    final currentSY = getCurrentSchoolYear();
    final currentParts = currentSY.split('-');
    final inputParts = schoolYear.split('-');

    final currentStart = int.parse(currentParts[0]);
    final inputStart = int.parse(inputParts[0]);

    return inputStart > currentStart;
  }

  /// Get school year info
  static Map<String, dynamic> getSchoolYearInfo(String schoolYear) {
    final parts = schoolYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);

    return {
      'school_year': schoolYear,
      'start_year': startYear,
      'end_year': endYear,
      'is_current': schoolYear == getCurrentSchoolYear(),
      'is_past': isPastSchoolYear(schoolYear),
      'is_future': isFutureSchoolYear(schoolYear),
      'display_name': 'SY $schoolYear',
      'period': isPastSchoolYear(schoolYear) ? 'Archived' : 'Active',
    };
  }

  /// Get school years in range
  static List<String> getSchoolYearsInRange({
    int yearsBack = 5,
    int yearsForward = 1,
  }) {
    final currentSY = getCurrentSchoolYear();
    final years = <String>[currentSY];

    // Add previous years
    for (int i = 1; i <= yearsBack; i++) {
      years.add(getPreviousSchoolYear(years.last));
    }

    // Add future years
    var nextYear = currentSY;
    for (int i = 1; i <= yearsForward; i++) {
      nextYear = getNextSchoolYear(nextYear);
      years.insert(0, nextYear); // Insert at beginning (newest first)
    }

    // Sort newest to oldest
    years.sort(compareSchoolYears);

    return years;
  }

  /// Validate import file matches school year
  static Map<String, dynamic> validateImportFileForSchoolYear(
    String fileName,
    String expectedSchoolYear,
  ) {
    final extractedYear = extractYearFromFileName(fileName);
    final parsedExtractedYear =
        extractedYear != null ? parseAcademicYear(extractedYear) : null;

    final parsedExpectedYear = parseAcademicYear(expectedSchoolYear);

    return {
      'file_name': fileName,
      'extracted_year': extractedYear,
      'parsed_extracted_year': parsedExtractedYear,
      'expected_year': expectedSchoolYear,
      'parsed_expected_year': parsedExpectedYear,
      'matches': parsedExtractedYear == parsedExpectedYear,
      'is_valid': parsedExtractedYear != null &&
          // ignore: unnecessary_null_comparison
          parsedExpectedYear != null &&
          parsedExtractedYear == parsedExpectedYear,
      'suggestion': parsedExtractedYear != null
          ? 'File appears to be for $parsedExtractedYear'
          : 'Cannot determine school year from filename',
    };
  }

  /// Get school year date range
  static Map<String, DateTime> getSchoolYearDateRange(String schoolYear) {
    if (!isValidSchoolYear(schoolYear)) {
      throw ArgumentError('Invalid school year format: $schoolYear');
    }

    final parts = schoolYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);

    final startDate = DateTime(startYear, 6, 1);
    final endDate = DateTime(endYear, 5, 31);

    return {'start_date': startDate, 'end_date': endDate};
  }

  /// Check if date falls within school year
  static bool isDateInSchoolYear(DateTime date, String schoolYear) {
    if (!isValidSchoolYear(schoolYear)) return false;

    final dateRange = getSchoolYearDateRange(schoolYear);
    final startDate = dateRange['start_date'];
    final endDate = dateRange['end_date'];

    return (date.isAfter(startDate!) || date.isAtSameMomentAs(startDate)) &&
        (date.isBefore(endDate!) || date.isAtSameMomentAs(endDate));
  }

  /// Generate academic year options for dropdown
  static List<String> generateAcademicYearOptions({
    int yearsBack = 10,
    int yearsForward = 2,
  }) {
    final options = <String>['All Years'];
    final currentSY = getCurrentSchoolYear();
    final currentParts = currentSY.split('-');
    final currentStart = int.parse(currentParts[0]);

    // Future years
    for (int i = yearsForward; i >= 1; i--) {
      final startYear = currentStart + i;
      options.add('$startYear-${startYear + 1}');
    }

    // Current year
    options.add(currentSY);

    // Past years
    for (int i = 1; i <= yearsBack; i++) {
      final startYear = currentStart - i;
      options.add('$startYear-${startYear + 1}');
    }

    return options;
  }

  /// 🆕 UPDATED: Detect school year from file metadata
  static String detectSchoolYearFromFile(Map<String, dynamic>? metadata) {
    if (metadata == null) return getCurrentSchoolYear();

    // Try different metadata keys
    final potentialKeys = [
      'school_year',
      'academic_year',
      'year',
      'sy',
      'assessment_year',
      'report_year',
    ];

    for (final key in potentialKeys) {
      final value = metadata[key];
      if (value != null && value is String && value.isNotEmpty) {
        return parseAcademicYear(value); // Just parse and return
      }
    }

    return getCurrentSchoolYear();
  }

  /// 🆕 UPDATED: Get academic year from assessment data with better error handling
  static String getAcademicYearFromAssessment(Map<String, dynamic> assessment) {
    try {
      // First try explicit academic_year field
      final explicitYear = assessment['academic_year']?.toString();
      if (explicitYear != null &&
          explicitYear.isNotEmpty &&
          explicitYear.toLowerCase() != 'null') {
        return parseAcademicYear(explicitYear); // REMOVED .first
      }

      // Try school_year field
      final schoolYear = assessment['school_year']?.toString();
      if (schoolYear != null &&
          schoolYear.isNotEmpty &&
          schoolYear.toLowerCase() != 'null') {
        return parseAcademicYear(schoolYear); // REMOVED .first
      }

      // Try to extract from assessment_date
      final assessmentDate = assessment['assessment_date']?.toString();
      if (assessmentDate != null && assessmentDate.isNotEmpty) {
        final date = DateTime.tryParse(assessmentDate);
        if (date != null) {
          return detectSchoolYearFromDate(date);
        }
      }

      // Try weighing_date
      final weighingDate = assessment['weighing_date']?.toString();
      if (weighingDate != null && weighingDate.isNotEmpty) {
        final date = DateTime.tryParse(weighingDate);
        if (date != null) {
          return detectSchoolYearFromDate(date);
        }
      }

      // Try created_at
      final createdAt = assessment['created_at']?.toString();
      if (createdAt != null && createdAt.isNotEmpty) {
        final date = DateTime.tryParse(createdAt);
        if (date != null) {
          return detectSchoolYearFromDate(date);
        }
      }

      // Check if there's a period field that might indicate year
      final period = assessment['period']?.toString();
      if (period != null && period.toLowerCase().contains('202')) {
        // Try to extract year from period like "Baseline 2023"
        final yearMatch = RegExp(r'20\d{2}').firstMatch(period);
        if (yearMatch != null) {
          final year = int.tryParse(yearMatch.group(0)!);
          if (year != null) {
            return '$year-${year + 1}';
          }
        }
      }
    } catch (e) {
      // Log error but continue to default
      if (kDebugMode) {
        debugPrint('⚠️ Error extracting academic year: $e');
        debugPrint('Assessment data: $assessment');
      }
    }

    // Default to current school year
    return getCurrentSchoolYear();
  }

  static resolveImportSchoolYear(
    String extractedSchoolYear, {
    required bool allowPastYears,
    required int maxPastYears,
  }) {}
}
