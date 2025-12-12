// excel_external_cleaner.dart - UPDATED WITH MISSING COLUMN NAME
import 'package:district_dev/Pages/food_page.dart';

class ExcelCleanerConfig {
  static const maxFileSize = 50 * 1024 * 1024; // 50MB
  static const maxRowsToScan = 20;
  static const maxConsecutiveEmptyRows = 5;
  static const dataStartRow = 27; // SBFP format - student data starts at row 27

  // UPDATED: More specific patterns for grade sheets
  static const List<String> gradeSheetPatterns = [
    'kinder',
    'grade 1',
    'grade 2',
    'grade 3',
    'grade 4',
    'grade 5',
    'grade 6',
    'sped',
    'start here',
  ];

  static const List<String> skipSheetPatterns = [
    'summary',
    'bmi',
    'hfa',
    'sbfp list',
    'template',
    'instruction',
  ];
}

/// Column name constants - UPDATED WITH MISSING gradeLevel FIELD
class ColumnNames {
  static const number = 'number';
  static const name = 'name';
  static const birthdate = 'birthdate';
  static const weight = 'weight_kg';
  static const height = 'height_cm';
  static const sex = 'sex';
  static const age = 'age';
  static const bmi = 'bmi';
  static const nutritionalStatus = 'nutritional_status';
  static const heightForAge = 'height_for_age';
  static const section = 'section';
  static const period = 'period';
  static const schoolYear = 'school_year';
  static const weighingDate = 'weighing_date';
  static const gradeLevel = 'grade_level'; // ADDED MISSING FIELD
  static const lrn = 'lrn'; // ADDED FOR COMPLETENESS
}

/// School Profile data structure - ENHANCED
class SchoolProfileImport {
  final String schoolName;
  final String district;
  final String schoolYear;
  final String? region;
  final String? division;
  final String? schoolId;
  final String? schoolHead;
  final String? coordinator;
  final String? baselineDate;
  final String? endlineDate;

  SchoolProfileImport({
    required this.schoolName,
    required this.district,
    required this.schoolYear,
    this.region,
    this.division,
    this.schoolId,
    this.schoolHead,
    this.coordinator,
    this.baselineDate,
    this.endlineDate,
  });

  factory SchoolProfileImport.fromMap(Map<String, dynamic> map) {
    return SchoolProfileImport(
      schoolName: map['schoolName']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      schoolYear: map['schoolYear']?.toString() ?? '',
      region: map['region']?.toString(),
      division: map['division']?.toString(),
      schoolId: map['schoolId']?.toString(),
      schoolHead: map['schoolHead']?.toString(),
      coordinator: map['coordinator']?.toString(),
      baselineDate: map['baselineDate']?.toString(),
      endlineDate: map['endlineDate']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolName': schoolName,
      'district': district,
      'schoolYear': schoolYear,
      'region': region,
      'division': division,
      'schoolId': schoolId,
      'schoolHead': schoolHead,
      'coordinator': coordinator,
      'baselineDate': baselineDate,
      'endlineDate': endlineDate,
    };
  }

  @override
  String toString() {
    return 'SchoolProfileImport{\n'
        '  schoolName: $schoolName,\n'
        '  district: $district,\n'
        '  schoolYear: $schoolYear,\n'
        '  region: $region,\n'
        '  division: $division\n'
        '}';
  }
}

/// Enhanced Validation Result - UPDATED WITH SCHOOL MATCHING
// UPDATE THE ValidationResult CLASS IN excel_external_cleaner.dart

/// Enhanced Validation Result - UPDATED WITH SCHOOL MATCHING
class ValidationResult {
  bool isValid = false;
  bool matchedSchoolName = false;
  bool matchedDistrict = false;
  bool matchedSchoolYear = false;
  bool matchedRegion = false; // ADDED MISSING FIELD
  List<String> errors = [];
  List<String> warnings = [];
  Map<String, dynamic> details = {};

  @override
  String toString() {
    return 'ValidationResult(\n'
        '  valid: $isValid,\n'
        '  schoolMatch: $matchedSchoolName,\n'
        '  districtMatch: $matchedDistrict,\n'
        '  regionMatch: $matchedRegion,\n' // ADDED
        '  errors: ${errors.length},\n'
        '  warnings: ${warnings.length}\n'
        ')';
  }

  // In date_utilities.dart - ADD THIS METHOD

  static DateTime? cleanAndStandardizeDate(dynamic dateInput) {
    if (dateInput == null) return null;

    final rawString = dateInput.toString().trim();
    if (rawString.isEmpty) return null;

    try {
      // 1. Try direct DateTime parsing first (for ISO formats)
      final parsed = DateTime.tryParse(rawString);
      if (parsed != null) return parsed;

      // 2. Handle common string formats like "November 4, 2016"
      final monthMap = {
        'january': 1,
        'jan': 1,
        'february': 2,
        'feb': 2,
        'march': 3,
        'mar': 3,
        'april': 4,
        'apr': 4,
        'may': 5,
        'june': 6,
        'jun': 6,
        'july': 7,
        'jul': 7,
        'august': 8,
        'aug': 8,
        'september': 9,
        'sep': 9,
        'sept': 9,
        'october': 10,
        'oct': 10,
        'november': 11,
        'nov': 11,
        'december': 12,
        'dec': 12,
      };

      final lower = rawString.toLowerCase();

      // Pattern for "November 4, 2016" or "Nov 4, 2016"
      final textDatePattern = RegExp(r'([a-z]+)\s+(\d{1,2}),?\s+(\d{4})');
      final match = textDatePattern.firstMatch(lower);

      if (match != null) {
        final monthName = match.group(1)!;
        final day = int.parse(match.group(2)!);
        final year = int.parse(match.group(3)!);

        final month = monthMap[monthName];
        if (month != null) {
          return DateTime(year, month, day);
        }
      }

      // 3. Handle Excel serial dates (like 45520.0)
      if (RegExp(r'^\d+\.?\d*$').hasMatch(rawString)) {
        final excelSerial = double.tryParse(rawString);
        if (excelSerial != null) {
          // Excel date serial numbers: 1 = Jan 1, 1900
          final baseDate = DateTime(1900, 1, 1);
          return baseDate.add(
            Duration(days: excelSerial.toInt() - 2),
          ); // Excel leap year bug
        }
      }

      // 4. Handle MM/DD/YYYY format
      final slashPattern = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})');
      final slashMatch = slashPattern.firstMatch(rawString);
      if (slashMatch != null) {
        final month = int.parse(slashMatch.group(1)!);
        final day = int.parse(slashMatch.group(2)!);
        final year = int.parse(slashMatch.group(3)!);
        return DateTime(year, month, day);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Date standardization failed for "$rawString": $e');
      }
      return null;
    }
  }

  String toUserMessage() {
    if (isValid) {
      return '✅ File validation passed - Ready for import';
    } else {
      final buffer = StringBuffer('❌ File validation failed:\n');
      for (final error in errors) {
        buffer.writeln('• $error');
      }
      for (final warning in warnings) {
        buffer.writeln('⚠️ $warning');
      }
      return buffer.toString();
    }
  }
}

/// Data Quality Metrics - ENHANCED WITH NUTRITIONAL STATUS TRACKING
class DataQualityMetrics {
  int totalStudents = 0;
  int studentsWithCompleteData = 0;
  int studentsMissingWeight = 0;
  int studentsMissingHeight = 0;
  int studentsMissingSex = 0;
  int studentsMissingNutritionalStatus = 0;
  Map<String, int> nutritionalStatusDistribution = {};
  Map<String, int> periodDistribution = {};
  Map<String, int> gradeDistribution = {};

  double get dataCompletenessRate =>
      totalStudents > 0 ? studentsWithCompleteData / totalStudents * 100 : 0;

  Map<String, dynamic> toMap() {
    return {
      'total_students': totalStudents,
      'students_with_complete_data': studentsWithCompleteData,
      'students_missing_weight': studentsMissingWeight,
      'students_missing_height': studentsMissingHeight,
      'students_missing_sex': studentsMissingSex,
      'students_missing_nutritional_status': studentsMissingNutritionalStatus,
      'data_completeness_rate': dataCompletenessRate.toStringAsFixed(1),
      'nutritional_status_distribution': nutritionalStatusDistribution,
      'period_distribution': periodDistribution,
      'grade_distribution': gradeDistribution,
    };
  }

  // NEW: Update metrics from student data
  void updateFromStudent(Map<String, dynamic> student) {
    totalStudents++;

    final hasWeight = student[ColumnNames.weight] != null;
    final hasHeight = student[ColumnNames.height] != null;
    final hasSex = student[ColumnNames.sex]?.toString().isNotEmpty == true;
    final hasNutritionalStatus =
        student[ColumnNames.nutritionalStatus]?.toString().isNotEmpty == true;

    if (!hasWeight) studentsMissingWeight++;
    if (!hasHeight) studentsMissingHeight++;
    if (!hasSex) studentsMissingSex++;
    if (!hasNutritionalStatus) studentsMissingNutritionalStatus++;

    if (hasWeight && hasHeight && hasSex && hasNutritionalStatus) {
      studentsWithCompleteData++;
    }

    // Track distributions
    final status =
        student[ColumnNames.nutritionalStatus]?.toString() ?? 'Unknown';
    nutritionalStatusDistribution[status] =
        (nutritionalStatusDistribution[status] ?? 0) + 1;

    final period = student[ColumnNames.period]?.toString() ?? 'Unknown';
    periodDistribution[period] = (periodDistribution[period] ?? 0) + 1;

    final grade = student[ColumnNames.gradeLevel]?.toString() ?? 'Unknown';
    gradeDistribution[grade] = (gradeDistribution[grade] ?? 0) + 1;
  }
}

/// Simple analysis container
class SheetAnalysis {
  int headerRow = -1;
  int dataStartRow = 0;
  Map<String, int> columnMap = {};
  String sheetType = 'unknown'; // 'grade', 'summary', 'reference'

  @override
  String toString() =>
      'SheetAnalysis(headerRow:$headerRow, dataStartRow:$dataStartRow, type:$sheetType, columns:$columnMap)';
}

/// Progress tracking class
class CleanProgress {
  final int progress;
  final String status;
  final CleanResult? result;

  CleanProgress({required this.progress, required this.status, this.result});
}

/// Clean result container - ENHANCED WITH VALIDATION SUPPORT
/// Clean result container - ENHANCED WITH VALIDATION SUPPORT
class CleanResult {
  final List<Map<String, dynamic>> data;
  final List<String> problems;
  final bool success;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? reportMetadata;
  final ValidationResult? validationResult; // NEW: Validation support

  CleanResult({
    required this.data,
    required this.problems,
    required this.success,
    this.metadata,
    this.reportMetadata,
    this.validationResult,
  });

  // Helper to check if validation passed
  bool get isValidForImport => success && (validationResult?.isValid ?? true);

  // Helper to get user-friendly status message
  String get statusMessage {
    if (!success) {
      return '❌ Import failed: ${problems.isNotEmpty ? problems.first : 'Unknown error'}';
    }
    if (!isValidForImport) {
      return validationResult?.toUserMessage() ?? 'Validation failed';
    }
    return '✅ Successfully imported ${data.length} students';
  }

  // ✅ NEW: Student tracking helper
  bool get studentTrackingEnabled {
    return metadata?['student_tracking_enabled'] == true ||
        reportMetadata?['student_tracking_enabled'] == true;
  }

  // ✅ NEW: Get extracted school year
  String? get extractedSchoolYear {
    return reportMetadata?['school_year']?.toString() ??
        metadata?['extraction_stats']?['extracted_school_year']?.toString();
  }

  // ✅ NEW: Helper method to check if school validation passed
  bool get passedSchoolValidation {
    if (validationResult == null) return false;
    try {
      return validationResult!.isValid == true &&
          validationResult!.matchedSchoolName == true;
    } catch (_) {
      return false;
    }
  }
}
