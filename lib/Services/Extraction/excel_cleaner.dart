// excel_cleaner.dart - UPDATED WITH NUTRITIONAL DATA IMPUTATION AND FIXED SCHOOL YEAR
import 'dart:io';
import 'dart:math';
// ✅ CORRECT IMPORTS ✅
import 'package:district_dev/Services/Data%20Model/exce_external_cleaner.dart';
import 'package:district_dev/Services/Data%20Model/import_student.dart';
import 'package:district_dev/Services/Data%20Model/nutri_stat_utilities.dart';
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:district_dev/Services/Database/data_services.dart'
    hide ImportResult;
import 'package:district_dev/Services/Extraction/csv_converter.dart'
    hide StudentAssessment, StudentIdentificationService;

import 'package:excel/excel.dart';

import 'excel_extract.dart' hide kDebugMode;

// ADD MISSING CONSTANTS FOR COMPATIBILITY
const bool kDebugMode = true;

/// Assessment Completeness Tracker
class AssessmentCompletenessTracker {
  /// Assess student completeness across periods
  static Map<String, dynamic> assessStudentCompleteness(
    List<Map<String, dynamic>> studentAssessments,
  ) {
    final baseline = studentAssessments.firstWhere(
      (assessment) =>
          assessment['period']?.toString().toLowerCase() == 'baseline',
      orElse: () => {},
    );

    final endline = studentAssessments.firstWhere(
      (assessment) =>
          assessment['period']?.toString().toLowerCase() == 'endline',
      orElse: () => {},
    );

    return {
      'student_id': studentAssessments.isNotEmpty
          ? studentAssessments.first['student_id']
          : '',
      'name':
          studentAssessments.isNotEmpty ? studentAssessments.first['name'] : '',
      'has_baseline': baseline.isNotEmpty,
      'has_endline': endline.isNotEmpty,
      'completeness_status': _determineStatus(baseline, endline),
      'baseline_data': baseline,
      'endline_data': endline,
      'missing_period': _getMissingPeriod(baseline, endline),
    };
  }

  static String _determineStatus(
    Map<String, dynamic> baseline,
    Map<String, dynamic> endline,
  ) {
    if (baseline.isNotEmpty && endline.isNotEmpty) return 'Complete';
    if (baseline.isNotEmpty && endline.isEmpty) return 'Missing Endline';
    if (baseline.isEmpty && endline.isNotEmpty) return 'Missing Baseline';
    return 'No Data';
  }

  static String _getMissingPeriod(
    Map<String, dynamic> baseline,
    Map<String, dynamic> endline,
  ) {
    if (baseline.isEmpty && endline.isNotEmpty) return 'Baseline';
    if (baseline.isNotEmpty && endline.isEmpty) return 'Endline';
    if (baseline.isEmpty && endline.isEmpty) return 'Both';
    return 'None';
  }

  /// Determine assessment completeness for individual student
  static String determineIndividualCompleteness(Map<String, dynamic> student) {
    final hasWeight = student['weight_kg'] != null;
    final hasHeight = student['height_cm'] != null;
    final hasBMI = student['bmi'] != null;
    final hasStatus = student['nutritional_status'] != null &&
        student['nutritional_status'].toString().isNotEmpty &&
        student['nutritional_status'].toString() != 'Unknown';

    if (hasWeight && hasHeight && hasBMI && hasStatus) return 'Complete';
    if (hasWeight && hasHeight && hasBMI) return 'Measurements Complete';
    if (hasStatus) return 'Status Only';
    if (hasWeight || hasHeight) return 'Partial Measurements';
    return 'Incomplete';
  }
}

// ========== EXISTING CLASSES (ENHANCED WITH STUDENT TRACKING) ==========

class ColumnCandidate {
  final int columnIndex;
  final String headerText;
  final int confidence;
  final String source;

  ColumnCandidate(
    this.columnIndex,
    this.headerText,
    this.confidence,
    this.source,
  );

  @override
  String toString() =>
      'Candidate(col:$columnIndex, text:"$headerText", conf:$confidence, src:$source)';
}

class CellValueExtractor {
  static String? getCellValue(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final value = cell.value;
    if (value != null) {
      return value.toString().trim();
    }
    return '';
  }

  static String safeGet(List<Data?> row, int? idx) {
    if (idx == null) return '';
    if (idx < 0 || idx >= row.length) return '';
    return getCellValue(row[idx]) ?? '';
  }

  static double? safeDouble(String s) {
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }
}

// Sheet Analyzer - UPDATED FOR SBFP FORMAT
class SheetAnalyzer {
  static SheetAnalysis analyzeStructure(Sheet sheet) {
    final analysis = SheetAnalysis();
    analysis.headerRow = _findHeaderRow(sheet);
    if (analysis.headerRow < 0) {
      analysis.headerRow = 13; // Default to row 13 for SBFP
    }
    analysis.dataStartRow = analysis.headerRow + 1;
    analysis.columnMap = _discoverColumnsSBFP(sheet, analysis.headerRow);
    return analysis;
  }

  static int _findHeaderRow(Sheet sheet) {
    // Look for SBFP header pattern
    for (int i = 0; i < min(20, sheet.rows.length); i++) {
      final row = sheet.rows[i];
      final rowText = row
          .map((c) => CellValueExtractor.getCellValue(c) ?? '')
          .join(' ')
          .toLowerCase();

      // SBFP header pattern: No., LRN, Name, Sex, Grade Level, Section, Weight, Height, BMI, Nutritional Status
      if ((rowText.contains('no.') || rowText.contains('number')) &&
          (rowText.contains('lrn') || rowText.contains('name')) &&
          (rowText.contains('sex') || rowText.contains('gender')) &&
          (rowText.contains('grade') || rowText.contains('level')) &&
          (rowText.contains('weight') || rowText.contains('kg')) &&
          (rowText.contains('height') || rowText.contains('cm'))) {
        if (kDebugMode) debugPrint('✅ SBFP header found at row $i: $rowText');
        return i;
      }
    }

    // Default to row 13 for SBFP format
    return 13;
  }

  /// UPDATED: Discover columns for SBFP format
  static Map<String, int> _discoverColumnsSBFP(Sheet sheet, int headerRow) {
    // Use fixed SBFP column structure
    final result = <String, int>{
      ColumnNames.number: 0, // A: No.
      ColumnNames.lrn: 1, // B: LRN
      ColumnNames.name: 2, // C: Name of Learner
      ColumnNames.sex: 3, // D: Sex
      ColumnNames.gradeLevel: 4, // E: Grade Level
      ColumnNames.section: 5, // F: Section
      ColumnNames.weight: 6, // G: Weight (kg)
      ColumnNames.height: 7, // H: Height (cm)
      ColumnNames.bmi: 8, // I: BMI
      ColumnNames.nutritionalStatus: 9, // J: Nutritional Status
    };

    if (kDebugMode) debugPrint('✅ Using SBFP fixed column mapping: $result');
    return result;
  }
}

// Student Data Extractor - UPDATED FOR SBFP FORMAT WITH STUDENT TRACKING
class StudentDataExtractor {
  static List<Map<String, dynamic>> extractFromSheet(
    Sheet sheet,
    SheetAnalysis analysis,
    String gradeLevel,
    List<String> problems,
  ) {
    final students = <Map<String, dynamic>>[];
    final rows = sheet.rows;
    int consecutiveEmptyRows = 0;

    for (int i = analysis.dataStartRow; i < rows.length; i++) {
      final row = rows[i];

      if (_isEmptyRow(row)) {
        consecutiveEmptyRows++;
        if (consecutiveEmptyRows >=
            ExcelCleanerConfig.maxConsecutiveEmptyRows) {
          if (kDebugMode) {
            debugPrint('🛑 Stopping at row $i - too many empty rows');
          }
          break;
        }
        continue;
      } else {
        consecutiveEmptyRows = 0;
      }

      if (_isSeparatorRow(row) || _isMostlyEmptyRow(row)) {
        continue;
      }

      final student = _extractStudentWithValidation(
        row,
        i + 1,
        analysis.columnMap,
        gradeLevel,
      );
      if (student != null) {
        students.add(student);
      }
    }

    return students;
  }

  static Map<String, dynamic>? _extractStudentWithValidation(
    List<Data?> row,
    int rowNum,
    Map<String, int> columnMap,
    String gradeLevel,
  ) {
    try {
      final student = _extractWithColumnMapSBFP(row, columnMap);
      if (student == null) return null;

      student[ColumnNames.gradeLevel] = gradeLevel;
      student['original_row'] = rowNum;

      if (!_isRealStudentSBFP(student)) {
        return null;
      }

      // ENHANCED: Add student tracking fields
      student['normalized_name'] = StudentIdentificationService.normalizeName(
        student[ColumnNames.name],
      );
      student['assessment_completeness'] =
          AssessmentCompletenessTracker.determineIndividualCompleteness(
        student,
      );

      if (kDebugMode) {
        debugPrint(
          '✅ Student accepted - Row $rowNum: ${student[ColumnNames.name]}',
        );
        debugPrint(
          '   Assessment Completeness: ${student['assessment_completeness']}',
        );
      }

      // 🛠️ CRITICAL: Apply SBFP cleaning with date standardization
      ExcelCleaner._cleanStudentDataSBFP(student);

      return student;
    } catch (e) {
      if (kDebugMode) debugPrint('Error extracting row $rowNum: $e');
      return null;
    }
  }

  /// EXTRACT STUDENT USING SBFP COLUMN STRUCTURE
  static Map<String, dynamic>? _extractWithColumnMapSBFP(
    List<Data?> row,
    Map<String, int> columnMap,
  ) {
    try {
      final name = _extractName(row, columnMap[ColumnNames.name]);
      if (name.isEmpty || name.length < 2) return null;

      if (_looksLikeHeader(name) || _looksLikeInstruction(name)) {
        return null;
      }

      return {
        ColumnNames.number: CellValueExtractor.safeGet(
          row,
          columnMap[ColumnNames.number],
        ),
        ColumnNames.lrn: CellValueExtractor.safeGet(
          row,
          columnMap[ColumnNames.lrn],
        ),
        ColumnNames.name: name,
        ColumnNames.sex: _extractSex(row, columnMap[ColumnNames.sex]),
        ColumnNames.gradeLevel: CellValueExtractor.safeGet(
          row,
          columnMap[ColumnNames.gradeLevel],
        ),
        ColumnNames.section: CellValueExtractor.safeGet(
          row,
          columnMap[ColumnNames.section],
        ),
        ColumnNames.weight: _extractWeight(row, columnMap[ColumnNames.weight]),
        ColumnNames.height: _extractHeight(row, columnMap[ColumnNames.height]),
        ColumnNames.bmi: ExcelCleaner._parseBMI(
          CellValueExtractor.safeGet(row, columnMap[ColumnNames.bmi]),
        ),
        ColumnNames.nutritionalStatus: CellValueExtractor.safeGet(
          row,
          columnMap[ColumnNames.nutritionalStatus],
        ),
        // NEW: Student tracking placeholder (will be filled later)
        'student_id': '', // To be assigned during import
        'normalized_name': StudentIdentificationService.normalizeName(name),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('extractWithColumnMapSBFP error: $e');
      return null;
    }
  }

  static bool _looksLikeDate(String text) {
    final datePatterns = [
      RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}'),
      RegExp(r'\d{1,2}-\d{1,2}-\d{2,4}'),
      RegExp(r'\d{4}-\d{1,2}-\d{1,2}'),
      RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}'),
    ];
    return datePatterns.any((pattern) => pattern.hasMatch(text));
  }

  static bool _containsDatePattern(String text) {
    final lowerText = text.toLowerCase();
    return lowerText.contains('birthdate') ||
        lowerText.contains('birth date') ||
        lowerText.contains('date of birth') ||
        lowerText.contains('mm/dd') ||
        lowerText.contains('birthdate');
  }

  static String _cleanSex(dynamic value) {
    final sex = _cleanText(value).toLowerCase();
    if (sex.isEmpty) return 'Unknown';

    if (sex == 'm' ||
        sex == 'male' ||
        sex == 'm.' ||
        sex == 'boy' ||
        sex == 'lalaki' ||
        sex == '1' ||
        sex == '1.0') {
      return 'Male';
    }
    if (sex == 'f' ||
        sex == 'female' ||
        sex == 'f.' ||
        sex == 'girl' ||
        sex == 'babae' ||
        sex == '2' ||
        sex == '2.0') {
      return 'Female';
    }

    return 'Unknown';
  }

  // Update the student validation method
  static bool _isRealStudentSBFP(Map<String, dynamic> student) {
    final name = student[ColumnNames.name]?.toString().trim() ?? '';

    // More strict name validation
    if (name.isEmpty || name == '-' || name == '—' || name.length < 2) {
      return false;
    }

    // Check if name looks like a date
    if (_looksLikeDate(name)) {
      return false;
    }

    // Check if name contains date patterns
    if (_containsDatePattern(name)) {
      return false;
    }

    if (ExcelCleaner._isNumeric(name) ||
        ExcelCleaner._isOnlySpecialCharacters(name)) {
      return false;
    }

    final lowerName = name.toLowerCase();
    final excludePatterns = [
      'birthdate',
      'birth date',
      'date of birth',
      'mm/dd/yy',
      'mm/dd/yyyy',
      'name of district',
      'name of school head',
      'example:',
      'instruction',
      'note:',
      'warning:',
      'total',
      'average',
      'baseline',
      'endline',
      'school:',
      'district:',
      'height',
      'weight',
      'bmi',
      'nutritional status',
      'remarks',
      'sbfp',
      'feeding program',
      'beneficiary',
      'names',
      'lrn',
      'sex',
      'grade level',
      'section',
    ];

    for (final pattern in excludePatterns) {
      if (lowerName.contains(pattern)) return false;
    }

    final hasName = name.isNotEmpty && name.length >= 2;
    final hasSomeData =
        student[ColumnNames.number]?.toString().trim().isNotEmpty == true ||
            student[ColumnNames.lrn]?.toString().isNotEmpty == true ||
            student[ColumnNames.weight] != null ||
            student[ColumnNames.height] != null;

    return hasName && hasSomeData;
  }

  static String _extractName(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return _cleanText(CellValueExtractor.getCellValue(row[index]));
  }

  static String _extractSex(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return _cleanSex(CellValueExtractor.getCellValue(row[index]));
  }

  static double? _extractWeight(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    return ExcelCleaner._parseWeight(
      CellValueExtractor.getCellValue(row[index]),
    );
  }

  static double? _extractHeight(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    return ExcelCleaner._parseHeight(
      CellValueExtractor.getCellValue(row[index]),
    );
  }

  static String _cleanText(dynamic value) => value?.toString().trim() ?? '';

  static bool _isEmptyRow(List<Data?> row) {
    for (final cell in row) {
      final value = CellValueExtractor.getCellValue(cell) ?? '';
      if (value.isNotEmpty && value != '-' && value != '—') return false;
    }
    return true;
  }

  static bool _isSeparatorRow(List<Data?> row) {
    int separatorCount = 0;
    for (final cell in row) {
      final value = CellValueExtractor.getCellValue(cell) ?? '';
      if (value == '-' || value == '—' || value == '---' || value == '___') {
        separatorCount++;
      } else if (value.isNotEmpty) return false;
    }
    return separatorCount > 0;
  }

  static bool _isMostlyEmptyRow(List<Data?> row) {
    int dataCells = 0;
    for (final cell in row) {
      final value = CellValueExtractor.getCellValue(cell) ?? '';
      if (value.isNotEmpty && value != '-' && value != '—') {
        dataCells++;
        if (dataCells >= 2) return false;
      }
    }
    return true;
  }

  static bool _looksLikeHeader(String text) {
    final lower = text.toLowerCase();
    return lower.contains('names') ||
        lower.contains('name') ||
        lower.contains('lrn') ||
        lower.contains('sex') ||
        lower.contains('grade') ||
        lower.contains('section') ||
        lower.contains('weight') ||
        lower.contains('height') ||
        lower.contains('bmi') ||
        lower.contains('nutritional') ||
        lower.contains('status') ||
        lower.contains('remarks');
  }

  static bool _looksLikeInstruction(String text) {
    final lower = text.toLowerCase();
    return lower.contains('example') ||
        lower.contains('instruction') ||
        lower.contains('note:') ||
        lower.contains('warning:') ||
        lower.contains('copy') ||
        lower.contains('paste') ||
        lower.contains('template');
  }
}

// NEW: School Profile Validator - ENHANCED FOR COMPATIBILITY
class SchoolProfileValidator {
  static ValidationResult validateImport(
    Map<String, dynamic> extractedProfile,
    SchoolProfile dashboardProfile, {
    bool strictMode = false,
  }) {
    final result = ValidationResult();

    // Convert dynamic values to strings safely
    final extractedName = _normalizeName(
      _safeToString(
        extractedProfile['school_name'] ?? extractedProfile['schoolName'],
      ),
    );
    final dashboardName = _normalizeName(dashboardProfile.schoolName);

    if (extractedName.isEmpty) {
      result.warnings.add('School name not found in Excel file');
    } else if (!_namesMatch(extractedName, dashboardName, strict: strictMode)) {
      result.errors.add(
        'School name mismatch: Excel contains "$extractedName" but dashboard expects "${dashboardProfile.schoolName}"',
      );
    } else {
      result.matchedSchoolName = true;
    }

    // District Matching
    final extractedDistrict = _normalizeName(
      _safeToString(extractedProfile['district']),
    );
    final dashboardDistrict = _normalizeName(dashboardProfile.district);

    if (extractedDistrict.isEmpty) {
      result.warnings.add('District not found in Excel file');
    } else if (!_namesMatch(
      extractedDistrict,
      dashboardDistrict,
      strict: strictMode,
    )) {
      result.warnings.add(
        'District mismatch: Excel contains "$extractedDistrict" but dashboard expects "${dashboardProfile.district}"',
      );
    } else {
      result.matchedDistrict = true;
    }

    // Region Matching (if available)
    final extractedRegion = _normalizeName(
      _safeToString(extractedProfile['region']),
    );
    final dashboardRegion = _normalizeName(dashboardProfile.region);

    if (extractedRegion.isNotEmpty && dashboardRegion.isNotEmpty) {
      if (!_namesMatch(extractedRegion, dashboardRegion, strict: strictMode)) {
        result.warnings.add(
          'Region mismatch: Excel contains "$extractedRegion" but dashboard expects "$dashboardRegion"',
        );
      } else {
        result.matchedRegion = true;
      }
    }

    result.isValid = result.errors.isEmpty;
    return result;
  }

  // NEW: Safe conversion from dynamic to String
  static String _safeToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _namesMatch(String name1, String name2, {bool strict = false}) {
    if (strict) {
      return name1 == name2;
    }

    // Fuzzy matching for lenient mode
    final n1 = _normalizeName(name1);
    final n2 = _normalizeName(name2);

    if (n1 == n2) return true;

    // Check if one contains the other
    if (n1.contains(n2) || n2.contains(n1)) return true;

    // Check for common abbreviations
    final abbreviations = {
      'elementary': 'elem',
      'school': 'sch',
      'national': 'nat',
      'high': 'hs',
      'integrated': 'int',
    };

    String expanded1 = n1;
    String expanded2 = n2;

    abbreviations.forEach((full, abbr) {
      expanded1 = expanded1.replaceAll(abbr, full);
      expanded2 = expanded2.replaceAll(abbr, full);
    });

    return expanded1 == expanded2 ||
        expanded1.contains(expanded2) ||
        expanded2.contains(expanded1);
  }
}

/// Enhanced Excel File Processor with School Validation AND STUDENT TRACKING
class ExcelFileProcessor {
  final String filePath;
  final SchoolProfile? dashboardProfile;
  final List<Map<String, dynamic>> cleanData = [];
  final List<String> problems = [];
  final Map<String, dynamic> meta = {};
  final DataQualityMetrics qualityMetrics = DataQualityMetrics();
  dynamic validationResult;

  ExcelFileProcessor(this.filePath, {this.dashboardProfile});

  // UPDATED: Use SBFPExtractor for extraction (now handles validation AND STUDENT TRACKING)
  CleanResult process() {
    try {
      // Use our unified extractor with validation
      final extracted = SBFPExtractor.extractStudents(
        filePath,
        appSchoolProfile: dashboardProfile,
        strictValidation: false, // Use lenient mode for cleaning
      );

      // Wait for the extraction to complete
      final extractionResult = extracted as ExtractionResult?;
      if (extractionResult == null) {
        problems.add('Failed to extract data from Excel file');
        return CleanResult(data: [], problems: problems, success: false);
      }

      // ENHANCED: Process extracted data with student tracking AND IMPUTATION
      final processedData = _processWithStudentTrackingAndImputation(
        extractionResult.students,
      );
      cleanData.addAll(processedData);
      problems.addAll(extractionResult.problems);

      // Update quality metrics with student tracking info
      for (final student in processedData) {
        qualityMetrics.updateFromStudent(student);
      }

      // Build metadata with student tracking info
      meta['school_profile'] = extractionResult.schoolProfile;
      meta['quality_metrics'] = qualityMetrics.toMap();

      // 🎯 CRITICAL: Ensure schoolYear is included with correct key
      if (extractionResult.schoolProfile.containsKey('schoolYear')) {
        meta['schoolYear'] = extractionResult.schoolProfile['schoolYear'];
        meta['academic_year'] = extractionResult.schoolProfile['schoolYear'];
      }

      // ENHANCED: Include student tracking statistics in metadata
      final studentsWithIDs = processedData
          .where(
            (student) =>
                student['student_id'] != null &&
                student['student_id'].toString().isNotEmpty,
          )
          .length;
      meta['student_tracking_stats'] = {
        'total_students': processedData.length,
        'students_with_ids': studentsWithIDs,
        'student_id_coverage': processedData.isNotEmpty
            ? (studentsWithIDs / processedData.length * 100).round()
            : 0,
        // 🎯 Add academic year info
        'academic_year':
            extractionResult.schoolProfile['schoolYear'] ?? '2024-2025',
      };

      // STREAMLINED: Use validation result from extractor
      validationResult = extractionResult.validationResult;
      if (validationResult != null) {
        meta['validation_result'] = {
          'is_valid': validationResult!.isValid,
          'matched_school_name': validationResult!.matchedSchoolName,
          'matched_district': validationResult!.matchedDistrict,
          'errors': validationResult!.errors,
          'warnings': validationResult!.warnings,
        };
      }

      return CleanResult(
        data: cleanData,
        problems: problems,
        success: cleanData.isNotEmpty,
        metadata: meta,
        reportMetadata: _aggregateReportMetadata(
          meta['sheets_processed'] ?? [],
        ),
        validationResult: validationResult,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('ExcelFileProcessor error: $e\n$st');
      problems.add('Failed to process SBFP Excel file: $e');
      return CleanResult(data: [], problems: problems, success: false);
    }
  }

  /// 🛠️ ENHANCED: Process extracted data with student tracking AND NUTRITIONAL DATA IMPUTATION
  List<Map<String, dynamic>> _processWithStudentTrackingAndImputation(
    List<Map<String, dynamic>> students,
  ) {
    final processed = <Map<String, dynamic>>[];

    for (final student in students) {
      final processedStudent = Map<String, dynamic>.from(student);

      // 🧪 CRITICAL: IMPUTE MISSING NUTRITIONAL DATA
      ExcelCleaner._imputeMissingNutritionalData(processedStudent);

      // Ensure normalized name is set
      if (!processedStudent.containsKey('normalized_name') ||
          processedStudent['normalized_name'].toString().isEmpty) {
        final name = processedStudent['name']?.toString() ?? '';
        processedStudent['normalized_name'] =
            StudentIdentificationService.normalizeName(name);
      }

      // Ensure assessment completeness is set
      if (!processedStudent.containsKey('assessment_completeness') ||
          processedStudent['assessment_completeness'].toString().isEmpty) {
        processedStudent['assessment_completeness'] =
            AssessmentCompletenessTracker.determineIndividualCompleteness(
          processedStudent,
        );
      }

      // 🎯 CRITICAL: Ensure academic_year is set from extraction
      if (!processedStudent.containsKey('academic_year') ||
          processedStudent['academic_year'].toString().isEmpty) {
        // Try to get from extraction result
        final extractedYear =
            processedStudent['extracted_school_year']?.toString() ??
                processedStudent['school_year']?.toString();

        if (extractedYear != null && extractedYear.isNotEmpty) {
          processedStudent['academic_year'] = extractedYear;
        } else {
          // Default fallback
          processedStudent['academic_year'] = '2024-2025';
        }
      }

      processed.add(processedStudent);
    }

    return processed;
  }

  SchoolProfileImport extractSchoolProfile() {
    try {
      // Use SBFPExtractor for school profile extraction
      final extracted = SBFPExtractor.extractStudents(filePath);
      final extractionResult = extracted as ExtractionResult?;

      if (extractionResult != null &&
          extractionResult.schoolProfile.isNotEmpty) {
        return SchoolProfileImport.fromMap(extractionResult.schoolProfile);
      }

      return SchoolProfileImport.fromMap({});
    } catch (e) {
      return SchoolProfileImport.fromMap({});
    }
  }

  Stream<CleanProgress> processWithProgress() async* {
    yield CleanProgress(progress: 0, status: 'Starting SBFP processing...');

    try {
      final file = File(filePath);
      final fileSize = await file.length();

      if (fileSize > ExcelCleanerConfig.maxFileSize) {
        yield CleanProgress(
          progress: 100,
          status: 'Error',
          result: CleanResult(
            data: [],
            problems: [
              'File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB',
            ],
            success: false,
          ),
        );
        return;
      }

      yield CleanProgress(
        progress: 10,
        status: 'Extracting data from Excel...',
      );

      // Use SBFPExtractor with validation
      final extracted = await SBFPExtractor.extractStudents(
        filePath,
        appSchoolProfile: dashboardProfile,
      );

      final extractionResult = extracted as ExtractionResult?;

      if (extractionResult == null) {
        yield CleanProgress(
          progress: 100,
          status: 'Error',
          result: CleanResult(
            data: [],
            problems: ['Failed to extract data from Excel file'],
            success: false,
          ),
        );
        return;
      }

      yield CleanProgress(progress: 50, status: 'Processing extracted data...');

      // ENHANCED: Process the validated extracted data with student tracking AND IMPUTATION
      final processedData = _processWithStudentTrackingAndImputation(
        extractionResult.students,
      );
      cleanData.addAll(processedData);
      problems.addAll(extractionResult.problems);
      validationResult = extractionResult.validationResult;

      // Update quality metrics
      for (final student in processedData) {
        qualityMetrics.updateFromStudent(student);
      }

      // Build metadata
      meta['total_sheets'] = extractionResult.schoolProfile.isNotEmpty ? 1 : 0;
      meta['sheets_processed'] = [
        {
          'sheet_name': 'extracted',
          'students_found': extractionResult.students.length,
          'school_name': extractionResult.schoolProfile['schoolName'],
          'district': extractionResult.schoolProfile['district'],
          'student_tracking_enabled': true,
        },
      ];

      meta['school_profile'] = extractionResult.schoolProfile;
      meta['quality_metrics'] = qualityMetrics.toMap();

      // Add student tracking statistics
      final studentsWithIDs = processedData
          .where(
            (student) =>
                student['student_id'] != null &&
                student['student_id'].toString().isNotEmpty,
          )
          .length;
      meta['student_tracking_stats'] = {
        'total_students': processedData.length,
        'students_with_ids': studentsWithIDs,
        'student_id_coverage': processedData.isNotEmpty
            ? (studentsWithIDs / processedData.length * 100).round()
            : 0,
      };

      if (validationResult != null) {
        meta['validation_result'] = {
          'is_valid': validationResult!.isValid,
          'matched_school_name': validationResult!.matchedSchoolName,
          'matched_district': validationResult!.matchedDistrict,
          'errors': validationResult!.errors,
          'warnings': validationResult!.warnings,
        };
      }

      yield CleanProgress(progress: 100, status: 'Complete');

      yield CleanProgress(
        progress: 100,
        status: 'Complete',
        result: CleanResult(
          data: cleanData,
          problems: problems,
          success: cleanData.isNotEmpty,
          metadata: meta,
          validationResult: validationResult,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('ExcelFileProcessor error: $e\n$st');
      problems.add('Failed to read Excel file: $e');
      yield CleanProgress(
        progress: 100,
        status: 'Error',
        result: CleanResult(data: [], problems: problems, success: false),
      );
    }
  }

  Map<String, dynamic> _aggregateReportMetadata(List<dynamic> sheetsProcessed) {
    final periods = <String, int>{};
    String? schoolYear;
    String? schoolName;

    for (final sheet in sheetsProcessed) {
      final period = sheet['period']?.toString();
      if (period != null && period.isNotEmpty) {
        periods[period] = (periods[period] ?? 0) + 1;
      }
      schoolYear ??= sheet['school_year']?.toString();
      schoolName ??= sheet['school_name']?.toString();
    }

    return {
      'period': periods.keys.firstOrNull,
      'school_year': schoolYear,
      'school_name': schoolName,
      'period_distribution': periods,
      'total_sheets': sheetsProcessed.length,
      'student_tracking_enabled': true,
    };
  }
}

/// Enhanced Main Excel Cleaner class - REFACTORED WITH FIXED VALIDATION PIPELINE AND STUDENT TRACKING
class ExcelCleaner {
  // 🧪 NEW: NUTRITIONAL DATA IMPUTATION METHOD
  static Map<String, dynamic> _imputeMissingNutritionalData(
    Map<String, dynamic> student,
  ) {
    // Extract data with type safety
    final weight = student['weight_kg'];
    final height = student['height_cm'];
    final bmi = student['bmi'];
    final status = student['nutritional_status']?.toString() ?? '';
    final ageMonths = student['age_months'] as int?;
    final sex = student['sex']?.toString();

    // Check if we have valid measurements for imputation
    final hasValidWeight = weight is num && weight > 10 && weight < 200;
    final hasValidHeight = height is num && height > 50 && height < 250;
    final hasValidMeasurements = hasValidWeight && hasValidHeight;

    // Check if nutritional data is missing
    final hasMissingBmi = bmi == null || (bmi is num && bmi <= 0);
    final hasUnknownStatus = status.isEmpty ||
        status == 'Unknown' ||
        status == 'No Data' ||
        status.toLowerCase().contains('unknown');

    // 🎯 IMputation Logic
    if (hasValidMeasurements && (hasMissingBmi || hasUnknownStatus)) {
      // 1. Calculate BMI
      final calculatedBmi = NutritionalUtilities.calculateBMI(
        height.toDouble(),
        weight.toDouble(),
      );

      student['bmi'] = calculatedBmi;

      // 2. Determine nutritional status if age and sex are available
      if (ageMonths != null && ageMonths >= 60 && sex != null) {
        final imputedStatus = NutritionalUtilities.classifyBMI(
          calculatedBmi,
          ageMonths,
          sex,
        );

        if (imputedStatus != 'Unknown') {
          student['nutritional_status'] = imputedStatus;

          if (kDebugMode) {
            print('🧪 IMPUTED NUTRITIONAL DATA:');
            print('   Student: ${student['name']}');
            print('   Weight: ${weight}kg, Height: ${height}cm');
            print('   Calculated BMI: ${calculatedBmi?.toStringAsFixed(2)}');
            print('   Imputed Status: $imputedStatus');
          }
        }
      } else if (hasValidMeasurements && hasUnknownStatus) {
        // Fallback: Use basic BMI categories if age/sex not available
        final basicStatus = _classifyBMIAdult(calculatedBmi!);
        if (basicStatus != 'Unknown') {
          student['nutritional_status'] = basicStatus;

          if (kDebugMode) {
            print('🧪 BASIC BMI CLASSIFICATION (age/sex unknown):');
            print('   Student: ${student['name']}');
            print('   Weight: ${weight}kg, Height: ${height}cm');
            print('   Calculated BMI: ${calculatedBmi.toStringAsFixed(2)}');
            print('   Basic Status: $basicStatus');
          }
        }
      }
    }

    return student;
  }

  /// Basic BMI classification for adults/unknown age
  static String _classifyBMIAdult(double bmi) {
    if (bmi < 16.0) return 'Severely Wasted';
    if (bmi < 18.5) return 'Wasted';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    if (bmi < 35.0) return 'Obese Class I';
    if (bmi < 40.0) return 'Obese Class II';
    return 'Obese Class III';
  }

  /// 🛠️ NEW: ADD ALL MISSING CLEANING METHODS

  /// 🛠️ CRITICAL FIX: Clean student data for SBFP format with date standardization
  static void _cleanStudentDataSBFP(Map<String, dynamic> student) {
    // Clean basic text fields
    student[ColumnNames.name] = _cleanText(student[ColumnNames.name]);
    student[ColumnNames.lrn] = _cleanText(student[ColumnNames.lrn]);
    student[ColumnNames.sex] = _cleanSex(student[ColumnNames.sex]);
    student['sex_missing'] = student[ColumnNames.sex] == 'Unknown';

    // Clean grade level and section
    student[ColumnNames.gradeLevel] = _cleanGradeLevel(
      student[ColumnNames.gradeLevel],
    );
    student[ColumnNames.section] = _cleanText(student[ColumnNames.section]);

    // 🛠️ CRITICAL FIX: Clean and standardize dates
    if (student['birth_date'] != null) {
      final standardizedDate = _cleanAndStandardizeDate(student['birth_date']);
      if (standardizedDate != null) {
        student['birth_date'] = _formatDateForDB(standardizedDate);
      } else {
        student['birth_date'] = null;
      }
    }

    // Clean assessment dates
    if (student['assessment_date'] != null) {
      final standardizedDate = _cleanAndStandardizeDate(
        student['assessment_date'],
      );
      if (standardizedDate != null) {
        student['assessment_date'] = _formatDateForDB(standardizedDate);
      }
    }

    if (student['weighing_date'] != null) {
      final standardizedDate = _cleanAndStandardizeDate(
        student['weighing_date'],
      );
      if (standardizedDate != null) {
        student['weighing_date'] = _formatDateForDB(standardizedDate);
      }
    }

    // Clean measurements
    student[ColumnNames.weight] = _parseWeight(student[ColumnNames.weight]);
    student['weight_missing'] = student[ColumnNames.weight] == null;

    student[ColumnNames.height] = _parseHeight(student[ColumnNames.height]);
    student['height_missing'] = student[ColumnNames.height] == null;

    student[ColumnNames.bmi] = _parseBMI(student[ColumnNames.bmi]);

    // ENHANCED: Use NutritionalUtilities for consistent classification
    final currentStatus = student[ColumnNames.nutritionalStatus]?.toString();
    final cleanedStatus = _cleanNutritionStatusSBFP(currentStatus);

    // 🛠️ CRITICAL FIX: Calculate age for BMI classification
    int? ageInMonths;
    if (student['birth_date'] != null) {
      final birthDate = _parseDate(student['birth_date']);
      final assessmentDate =
          _parseDate(student['assessment_date']) ?? DateTime.now();

      if (birthDate != null) {
        ageInMonths = _calculateAgeInMonths(birthDate, assessmentDate);
        student['age_months'] = ageInMonths;
      }
    }

    // CRITICAL FIX: If status is unknown, classify from BMI using unified utility
    if ((cleanedStatus.isEmpty || cleanedStatus == 'Unknown') &&
        student[ColumnNames.bmi] != null) {
      final sex = student[ColumnNames.sex];
      student[ColumnNames.nutritionalStatus] = NutritionalUtilities.classifyBMI(
        student[ColumnNames.bmi],
        ageInMonths ?? 72,
        sex,
      );
    } else {
      student[ColumnNames.nutritionalStatus] = cleanedStatus;
    }

    // Calculate BMI if missing
    if (student[ColumnNames.bmi] == null &&
        student[ColumnNames.weight] != null &&
        student[ColumnNames.height] != null) {
      final heightM = student[ColumnNames.height]! / 100;
      if (heightM > 0) {
        student[ColumnNames.bmi] =
            student[ColumnNames.weight]! / (heightM * heightM);

        // Re-classify nutritional status if we just computed BMI
        if (student[ColumnNames.nutritionalStatus] == 'Unknown') {
          student[ColumnNames.nutritionalStatus] =
              NutritionalUtilities.classifyBMI(
            student[ColumnNames.bmi],
            ageInMonths ?? 72,
            student[ColumnNames.sex],
          );
        }
      }
    }

    // Track missing fields for SBFP
    final missingFields = <String>[];
    if (student['sex_missing'] == true) missingFields.add('sex');
    if (student['weight_missing'] == true) missingFields.add('weight');
    if (student['height_missing'] == true) missingFields.add('height');

    student['missing_required_fields'] = missingFields;
    student['has_required_data'] = missingFields.isEmpty;

    // ENHANCED: Update assessment completeness after all cleaning
    student['assessment_completeness'] =
        AssessmentCompletenessTracker.determineIndividualCompleteness(student);

    // 🧪 FINAL STEP: Impute any still-missing nutritional data
    _imputeMissingNutritionalData(student);
  }

  /// 🛠️ MISSING METHOD: Robust date standardization
  static DateTime? _cleanAndStandardizeDate(dynamic dateInput) {
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

  /// 🛠️ MISSING METHOD: Format date for database
  static String _formatDateForDB(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 🛠️ MISSING METHOD: Parse date from string
  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    // Try direct parsing first
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) return parsed;

    // Try our custom standardization
    return _cleanAndStandardizeDate(dateStr);
  }

  /// 🛠️ MISSING METHOD: Calculate age in months
  static int _calculateAgeInMonths(
    DateTime birthDate,
    DateTime assessmentDate,
  ) {
    final years = assessmentDate.year - birthDate.year;
    final months = assessmentDate.month - birthDate.month;

    // Adjust for negative months
    if (months < 0) {
      return (years - 1) * 12 + (12 + months);
    }

    return years * 12 + months;
  }

  /// 🛠️ MISSING METHOD: Clean grade level
  static String _cleanGradeLevel(dynamic value) {
    final grade = _cleanText(value).toUpperCase();
    if (grade.contains('KINDER') || grade == 'K') return 'Kinder';
    if (grade == '1' || grade == 'GRADE 1') return 'Grade 1';
    if (grade == '2' || grade == 'GRADE 2') return 'Grade 2';
    if (grade == '3' || grade == 'GRADE 3') return 'Grade 3';
    if (grade == '4' || grade == 'GRADE 4') return 'Grade 4';
    if (grade == '5' || grade == 'GRADE 5') return 'Grade 5';
    if (grade == '6' || grade == 'GRADE 6') return 'Grade 6';

    return grade.isNotEmpty ? grade : 'Unknown';
  }

  /// 🛠️ MISSING METHOD: Clean nutritional status for SBFP
  static String _cleanNutritionStatusSBFP(dynamic value) {
    if (value == null) return 'Unknown';
    final status = _cleanText(value);

    // Map common status variations to standard values
    final statusMap = {
      'severely wasted': 'Severely Wasted',
      'wasted': 'Wasted',
      'normal': 'Normal',
      'overweight': 'Overweight',
      'obese': 'Obese',
      'severely underweight': 'Severely Wasted',
      'underweight': 'Wasted',
      'severely stunted': 'Severely Stunted',
      'stunted': 'Stunted',
    };

    final lowerStatus = status.toLowerCase();

    for (final key in statusMap.keys) {
      if (lowerStatus.contains(key)) {
        return statusMap[key]!;
      }
    }

    return status.isNotEmpty ? status : 'Unknown';
  }

  /// 🛠️ FIXED: Parse BMI value with Excel formula handling
  static double? _parseBMI(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str.contains('#VALUE!') || str.contains('#ERROR!')) {
      return null;
    }

    // 🛠️ CRITICAL FIX: Handle Excel formulas by extracting numbers
    if (_isExcelFormula(str)) {
      final extractedNumber = _extractNumberFromFormula(str);
      if (extractedNumber != null) {
        if (kDebugMode) {
          print('✅ EXTRACTED BMI FROM FORMULA: "$str" -> $extractedNumber');
        }
        return extractedNumber;
      }
    }

    return _parseNumber(str);
  }

  /// 🛠️ NEW: Smart Excel formula handling - EXTRACT values instead of rejecting
  static bool _isExcelFormula(String value) {
    if (value.isEmpty) return false;

    final upperValue = value.toUpperCase().trim();

    // Only consider it a formula if it starts with = or contains function patterns
    return upperValue.startsWith('=') ||
        (upperValue.contains('IFERROR') && upperValue.contains('(')) ||
        (upperValue.contains('IF(') && upperValue.contains(')'));
  }

  /// 🛠️ NEW: Extract numeric value from Excel formulas
  static double? _extractNumberFromFormula(String formula) {
    try {
      // Look for numeric patterns in formulas
      final numberPattern = RegExp(r'(\d+\.?\d*)');
      final matches = numberPattern.allMatches(formula);

      for (final match in matches) {
        final numberStr = match.group(1);
        final number = double.tryParse(numberStr!);
        if (number != null && number > 0) {
          return number;
        }
      }

      // Try to find calculated results in IFERROR patterns
      if (formula.contains('IFERROR')) {
        final parts = formula.split(',');
        if (parts.length >= 2) {
          final resultPart = parts[
              0]; // First part before comma often contains the calculation
          final resultMatch = numberPattern.firstMatch(resultPart);
          if (resultMatch != null) {
            return double.tryParse(resultMatch.group(1)!);
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🛠️ MISSING METHOD: Parse weight
  static double? _parseWeight(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim().toLowerCase();
    if (str.isEmpty) return null;
    final regex = RegExp(r'(\d+[.,]?\d*)\s*kg?');
    final m = regex.firstMatch(str);
    if (m != null) {
      final kg = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (kg != null && kg > 10 && kg < 200) {
        return kg;
      }
    }
    final number = _parseNumber(str);
    if (number != null && number > 10 && number < 200) {
      return number;
    }
    return null;
  }

  /// 🛠️ MISSING METHOD: Parse height
  static double? _parseHeight(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim().toLowerCase();
    if (str.isEmpty) return null;
    final regexMeters = RegExp(r'(\d+[.,]?\d*)\s*m?');
    final m = regexMeters.firstMatch(str);
    if (m != null) {
      final meters = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (meters != null && meters > 0.5 && meters < 2.5) {
        return meters * 100;
      }
    }
    final regexCm = RegExp(r'(\d+[.,]?\d*)\s*cm?');
    final cmMatch = regexCm.firstMatch(str);
    if (cmMatch != null) {
      final cm = double.tryParse(cmMatch.group(1)!.replaceAll(',', '.'));
      if (cm != null && cm > 50 && cm < 250) {
        return cm;
      }
    }
    final number = _parseNumber(str);
    if (number != null && number > 50 && number < 250) {
      return number;
    }
    return null;
  }

  /// 🛠️ MISSING METHOD: Parse number from string
  static double? _parseNumber(String s) {
    final cleaned = s.replaceAll(',', '.').replaceAll(RegExp(r'[^\d\.\-]'), '');
    return double.tryParse(cleaned);
  }

  /// 🛠️ MISSING METHOD: Clean text
  static String _cleanText(dynamic value) => value?.toString().trim() ?? '';

  /// 🛠️ MISSING METHOD: Clean sex
  static String _cleanSex(dynamic value) {
    final sex = _cleanText(value).toLowerCase();
    if (sex.isEmpty) return 'Unknown';

    if (sex == 'm' ||
        sex == 'male' ||
        sex == 'm.' ||
        sex == 'boy' ||
        sex == 'lalaki' ||
        sex == '1' ||
        sex == '1.0') {
      return 'Male';
    }
    if (sex == 'f' ||
        sex == 'female' ||
        sex == 'f.' ||
        sex == 'girl' ||
        sex == 'babae' ||
        sex == '2' ||
        sex == '2.0') {
      return 'Female';
    }

    return 'Unknown';
  }

  /// 🛠️ MISSING METHOD: Check if string is numeric
  static bool _isNumeric(String str) =>
      double.tryParse(str.replaceAll(',', '.')) != null;

  /// 🛠️ MISSING METHOD: Check if text contains only special characters
  static bool _isOnlySpecialCharacters(String text) {
    if (text.isEmpty) return true;
    final specialCharRegex = RegExp(r'^[-\s_–—\.]+$');
    return specialCharRegex.hasMatch(text);
  }

  // ========== EXISTING METHODS CONTINUE BELOW ==========

  /// 🚨 EMERGENCY FALLBACK: Use when new pipeline fails
  static Future<CleanResult> emergencyFallbackPipeline(String filePath) async {
    try {
      print('🚨 USING EMERGENCY FALLBACK PIPELINE');

      // Use the extractor but skip complex validation
      final extracted = await SBFPExtractor.extractStudents(
        filePath,
        strictValidation: false, // 🛠️ TURN OFF strict validation
      );

      final extractionResult = extracted as ExtractionResult?;
      if (extractionResult == null) {
        return CleanResult(
          data: [],
          problems: ['Extraction failed'],
          success: false,
        );
      }

      // 🛠️ MINIMAL CLEANING - Preserve all extracted data
      final cleanedStudents = extractionResult.students.map((student) {
        // Ensure basic tracking fields exist
        final enhancedStudent = Map<String, dynamic>.from(student);

        // Generate missing tracking fields with SHORTER IDs
        if (enhancedStudent['student_id'] == null ||
            enhancedStudent['student_id'].toString().isEmpty) {
          final name = enhancedStudent['name']?.toString() ?? '';
          final schoolName =
              enhancedStudent['extracted_school_name']?.toString() ?? 'Unknown';
          // Extract school acronym for shorter IDs
          final schoolAcronym = _extractSchoolAcronym(schoolName);
          enhancedStudent['student_id'] =
              StudentIdentificationService.generateDeterministicStudentID(
            name,
            schoolAcronym,
          );
        }

        if (enhancedStudent['normalized_name'] == null ||
            enhancedStudent['normalized_name'].toString().isEmpty) {
          final name = enhancedStudent['name']?.toString() ?? '';
          enhancedStudent['normalized_name'] =
              StudentIdentificationService.normalizeName(name);
        }

        if (enhancedStudent['assessment_completeness'] == null ||
            enhancedStudent['assessment_completeness'].toString().isEmpty) {
          enhancedStudent['assessment_completeness'] =
              AssessmentCompletenessTracker.determineIndividualCompleteness(
            enhancedStudent,
          );
        }

        // 🧪 Apply nutritional data imputation
        _imputeMissingNutritionalData(enhancedStudent);

        return enhancedStudent;
      }).toList();

      // 🛠️ LENIENT FILTERING - Only remove obviously invalid data
      final validStudents = cleanedStudents.where((student) {
        final name = student['name']?.toString().trim() ?? '';

        // Only reject if name is clearly invalid
        if (name.isEmpty || name.length < 2) return false;
        if (_looksLikeHeader(name)) return false;
        if (name.toLowerCase().contains('total') ||
            name.toLowerCase().contains('average')) {
          return false;
        }

        return true;
      }).toList();

      print('🎯 EMERGENCY PIPELINE RESULTS:');
      print('   Extracted: ${extractionResult.students.length}');
      print('   After Cleaning: ${validStudents.length}');
      print('   Period Distribution:');
      final baselineCount =
          validStudents.where((s) => s['period'] == 'Baseline').length;
      final endlineCount =
          validStudents.where((s) => s['period'] == 'Endline').length;
      print('     Baseline: $baselineCount, Endline: $endlineCount');

      return CleanResult(
        data: validStudents,
        problems: extractionResult.problems,
        success: validStudents.isNotEmpty,
        validationResult: extractionResult.validationResult,
      );
    } catch (e, st) {
      print('❌ EMERGENCY PIPELINE FAILED: $e');
      print(st);
      return CleanResult(
        data: [],
        problems: ['Emergency pipeline failed: $e'],
        success: false,
      );
    }
  }

  /// 🆕 NEW: Extract school acronym for shorter student IDs
  static String _extractSchoolAcronym(String schoolName) {
    if (schoolName.isEmpty) return 'SCH';

    // Check if it's already an acronym-like (all caps, short)
    if (schoolName == schoolName.toUpperCase() && schoolName.length <= 6) {
      return schoolName;
    }

    // Extract acronym from school name
    final words = schoolName.split(' ');
    if (words.length > 1) {
      // For multi-word names like "San Vicente Elementary School"
      final acronym = words.map((word) {
        if (word.isNotEmpty) {
          return word[0].toUpperCase();
        }
        return '';
      }).join('');

      // Return 3-4 character acronym
      if (acronym.length >= 3) {
        return acronym.length <= 4 ? acronym : acronym.substring(0, 4);
      }
    }

    // For single word names, take first 3-4 letters
    if (schoolName.length >= 3) {
      final shortName =
          schoolName.substring(0, min(4, schoolName.length)).toUpperCase();
      // Remove any special characters
      return shortName.replaceAll(RegExp(r'[^A-Z]'), '');
    }

    return 'SCH';
  }

  /// 🛠️ FIXED: Main cleaning method with fallback
  static Future<CleanResult> cleanSchoolExcel(
    String filePath, {
    SchoolProfile? dashboardProfile,
    bool strictValidation = false,
  }) async {
    try {
      // Try the enhanced pipeline first
      final enhancedResult = await _enhancedPipelineWithFix(
        filePath,
        dashboardProfile: dashboardProfile,
        strictValidation: strictValidation,
      );

      if (enhancedResult.success && enhancedResult.data.isNotEmpty) {
        print(
          '✅ ENHANCED PIPELINE SUCCESS: ${enhancedResult.data.length} students',
        );
        return enhancedResult;
      }

      // Fall back to emergency pipeline if enhanced fails
      print('🔄 ENHANCED PIPELINE FAILED, USING EMERGENCY FALLBACK');
      return await emergencyFallbackPipeline(filePath);
    } catch (e) {
      print('❌ ALL PIPELINES FAILED, USING ULTIMATE FALLBACK: $e');
      // Ultimate fallback - try basic extraction only
      return await emergencyFallbackPipeline(filePath);
    }
  }

  /// 🛠️ FIXED: Enhanced pipeline with all the fixes applied
  static Future<CleanResult> _enhancedPipelineWithFix(
    String filePath, {
    SchoolProfile? dashboardProfile,
    bool strictValidation = false,
  }) async {
    final extracted = await SBFPExtractor.extractStudents(
      filePath,
      appSchoolProfile: dashboardProfile,
      strictValidation: strictValidation,
    );

    final extractionResult = extracted as ExtractionResult?;
    if (extractionResult == null) {
      return CleanResult(
        data: [],
        problems: ['Extraction failed'],
        success: false,
      );
    }

    // 🛠️ USE FIXED VALIDATION instead of the broken one
    final processedData = _processWithLenientValidationAndImputation(
      extractionResult.students,
    );

    return CleanResult(
      data: processedData,
      problems: extractionResult.problems,
      success: processedData.isNotEmpty,
      metadata: {
        'school_profile': extractionResult.schoolProfile,
        'extraction_stats': {
          'total_extracted': extractionResult.students.length,
          'total_processed': processedData.length,
          'rejection_rate': extractionResult.students.isNotEmpty
              ? ((extractionResult.students.length - processedData.length) /
                      extractionResult.students.length *
                      100)
                  .round()
              : 0,
          'pipeline_version': 'fixed_validation_v2',
          // 🎯 IMPORTANT: Include extracted school year
          'extracted_school_year':
              extractionResult.schoolProfile['schoolYear'] ?? '2024-2025',
        },
      },
      validationResult: extractionResult.validationResult,
    );
  }

  /// 🛠️ NEW: Lenient validation processing WITH IMPUTATION
  static List<Map<String, dynamic>> _processWithLenientValidationAndImputation(
    List<Map<String, dynamic>> students,
  ) {
    final processed = <Map<String, dynamic>>[];
    int rejectedCount = 0;

    for (final student in students) {
      final processedStudent = Map<String, dynamic>.from(student);

      // Apply fixes to tracking fields
      _ensureTrackingFields(processedStudent);

      // 🧪 APPLY NUTRITIONAL DATA IMPUTATION
      _imputeMissingNutritionalData(processedStudent);

      // Use LENIENT validation
      final validationResult = _validateStudentForImportWithReason(
        processedStudent,
      );

      if (validationResult['isValid'] == true) {
        processed.add(processedStudent);
      } else {
        rejectedCount++;
        if (kDebugMode && rejectedCount <= 5) {
          print(
            '❌ REJECTED: ${processedStudent['name']} - ${validationResult['reason']}',
          );
        }
      }
    }

    print(
      '📊 LENIENT VALIDATION RESULTS: ${processed.length} accepted, $rejectedCount rejected',
    );
    return processed;
  }

  /// 🛠️ FIXED: Enhanced validation for student import with better error reporting
  static Map<String, dynamic> _validateStudentForImportWithReason(
    Map<String, dynamic> student,
  ) {
    if (kDebugMode) {
      print('\n🔍 VALIDATING STUDENT: ${student['name']}');
    }

    // 🛠️ CRITICAL FIX: Only require ABSOLUTELY essential fields
    final essentialFields = ['name', 'period'];
    final missingEssential = essentialFields.where((field) {
      final value = student[field];
      return value == null || value.toString().trim().isEmpty;
    }).toList();

    if (missingEssential.isNotEmpty) {
      if (kDebugMode) {
        print('❌ MISSING ESSENTIAL FIELDS: $missingEssential');
      }
      return {
        'isValid': false,
        'reason': 'Missing essential fields: ${missingEssential.join(", ")}',
      };
    }

    final name = student['name']?.toString().trim() ?? '';

    // 🛠️ CRITICAL FIX: More lenient name validation
    if (name.length < 2) {
      if (kDebugMode) print('❌ NAME TOO SHORT: "$name"');
      return {'isValid': false, 'reason': 'Name too short: "$name"'};
    }
    if (_looksLikeHeader(name)) {
      if (kDebugMode) print('❌ NAME LOOKS LIKE HEADER: "$name"');
      return {'isValid': false, 'reason': 'Name looks like header: "$name"'};
    }

    // 🛠️ CRITICAL FIX: Allow students with partial data
    final hasWeight = student['weight_kg'] != null;
    final hasHeight = student['height_cm'] != null;
    final hasStatus = student['nutritional_status'] != null &&
        student['nutritional_status'].toString().isNotEmpty &&
        student['nutritional_status'].toString() != 'Unknown';

    final hasSomeMeasurementData = hasWeight || hasHeight || hasStatus;

    if (!hasSomeMeasurementData) {
      // 🛠️ CRITICAL FIX: Allow students with only basic info for tracking
      // They might get measurements in future imports
      if (kDebugMode) {
        print('⚠️ STUDENT HAS NO MEASUREMENTS BUT KEEPING FOR TRACKING: $name');
      }
      // DON'T reject - keep for student tracking purposes
    }

    // 🛠️ CRITICAL FIX: Ensure tracking fields are populated
    _ensureTrackingFields(student);

    if (kDebugMode) {
      print('✅ VALIDATION PASSED for ${student['name']}');
      print('   Student ID: ${student['student_id']}');
      print('   Period: ${student['period']}');
      print(
        '   Measurements: weight=$hasWeight, height=$hasHeight, status=$hasStatus',
      );
    }

    return {'isValid': true, 'reason': 'Valid student data'};
  }

  /// 🛠️ NEW: Ensure all tracking fields are properly set
  static void _ensureTrackingFields(Map<String, dynamic> student) {
    // Ensure normalized name is set
    if (!student.containsKey('normalized_name') ||
        student['normalized_name'].toString().isEmpty) {
      final name = _cleanText(student['name']);
      student['normalized_name'] = StudentIdentificationService.normalizeName(
        name,
      );
    }

    // Ensure assessment completeness is set
    if (!student.containsKey('assessment_completeness') ||
        student['assessment_completeness'].toString().isEmpty) {
      student['assessment_completeness'] =
          AssessmentCompletenessTracker.determineIndividualCompleteness(
        student,
      );
    }

    // 🛠️ CRITICAL FIX: Generate student ID if missing
    if (!student.containsKey('student_id') ||
        student['student_id'].toString().isEmpty) {
      final name = _cleanText(student['name']);
      final schoolName = _cleanText(
        student['school_name'] ??
            student['extracted_school_name'] ??
            'Unknown School',
      );
      final schoolAcronym = _extractSchoolAcronym(schoolName);
      student['student_id'] =
          StudentIdentificationService.generateDeterministicStudentID(
        name,
        schoolAcronym,
      );
    }

    // 🛠️ CRITICAL FIX: Ensure grade_level is set (check multiple possible field names)
    if (!student.containsKey('grade_level') ||
        student['grade_level'].toString().isEmpty) {
      // Try different field names that might contain grade information
      student['grade_level'] = student['grade'] ??
          student['Grade Level'] ??
          student['gradeLevel'] ??
          student[ColumnNames.gradeLevel] ??
          'Unknown';

      // If still empty, try to extract from section
      if (student['grade_level'].toString().isEmpty &&
          student.containsKey('section')) {
        final section = student['section'].toString();
        if (section.contains('Grade') || section.contains('G')) {
          student['grade_level'] = section;
        }
      }

      // Final fallback
      if (student['grade_level'].toString().isEmpty) {
        student['grade_level'] = 'Unknown';
      }
    }

    // 🛠️ CRITICAL FIX: Ensure period is set
    if (!student.containsKey('period') ||
        student['period'].toString().isEmpty) {
      student['period'] = 'Baseline'; // Default to Baseline
    }
  }

  /// 🛠️ FIXED: Enhanced student data cleaning with tracking field preservation
  static Map<String, dynamic> _cleanStudentData(Map<String, dynamic> student) {
    final cleaned = Map<String, dynamic>.from(student);

    // 🛠️ CRITICAL FIX: PRESERVE tracking fields
    final trackingFields = [
      'student_id',
      'normalized_name',
      'assessment_completeness',
      'extracted_school_name',
      'extracted_district',
      'extracted_school_year',
    ];

    for (final field in trackingFields) {
      if (student.containsKey(field)) {
        cleaned[field] = student[field];
      }
    }

    // 🛠️ CRITICAL FIX: Ensure student_id is never empty
    if (cleaned['student_id'] == null ||
        cleaned['student_id'].toString().isEmpty) {
      final name = cleaned['name']?.toString() ?? '';
      final schoolName = cleaned['extracted_school_name']?.toString() ?? '';
      final schoolAcronym = _extractSchoolAcronym(schoolName);
      cleaned['student_id'] =
          StudentIdentificationService.generateDeterministicStudentID(
        name,
        schoolAcronym,
      );

      if (kDebugMode) {
        print('🔄 REGENERATED STUDENT ID for: $name');
        print('   New ID: ${cleaned['student_id']}');
      }
    }

    // 🛠️ CRITICAL FIX: Ensure normalized_name is never empty
    if (cleaned['normalized_name'] == null ||
        cleaned['normalized_name'].toString().isEmpty) {
      final name = cleaned['name']?.toString() ?? '';
      cleaned['normalized_name'] = StudentIdentificationService.normalizeName(
        name,
      );
    }

    // 🧪 APPLY NUTRITIONAL DATA IMPUTATION
    _imputeMissingNutritionalData(cleaned);

    return cleaned;
  }

  /// 🛠️ Check if text looks like a header row rather than student data
  static bool _looksLikeHeader(String text) {
    if (text.isEmpty) return false;

    final lower = text.toLowerCase();

    // Common header-like patterns
    final headerPatterns = [
      'congressional district',
      'designation',
      'school year',
      'date of weighing',
      'baseline',
      'endline',
      'nutritional status report',
      'kagawaran',
      'rehiyon',
      'tangapan',
      'sipocot',
      'district',
      'elementary school',
      'republika ng pilipinas',
      'no.',
      'number',
      'lrn',
      'name of learner',
      'sex',
      'grade level',
      'section',
      'weight',
      'height',
      'bmi',
      'nutritional status',
      'height for age',
      'total',
      'average',
      'mean',
      'count',
    ];

    for (var pattern in headerPatterns) {
      if (lower.contains(pattern)) {
        return true;
      }
    }

    // Check for header-like patterns with multiple field names
    final headerFieldCount = [
      lower.contains('name') &&
          (lower.contains('birthdate') ||
              lower.contains('weight') ||
              lower.contains('height')),
      lower.contains('no.') && lower.contains('lrn') && lower.contains('name'),
      lower.contains('weight') &&
          lower.contains('height') &&
          lower.contains('bmi'),
    ];

    if (headerFieldCount.any((pattern) => pattern == true)) {
      return true;
    }

    return false;
  }

  /// 🆕 UPDATED: Convert extracted student maps to StudentAssessment objects for dual-table structure
  static List<StudentAssessment> convertToStudentAssessments(
    List<Map<String, dynamic>> studentMaps,
    String schoolId,
    String academicYear,
  ) {
    return studentMaps
        .map((studentData) {
          return StudentAssessment.fromCombinedData(
            studentData,
            schoolId,
            academicYear,
            studentData['period'] ?? 'Baseline',
          );
        })
        .where(
          (student) => student.validate().isEmpty,
        ) // Only keep valid students
        .toList();
  }

  /// 🆕 UPDATED: Enhanced cleaning that returns StudentAssessment objects with validated data AND DUAL-TABLE STRUCTURE
  static Future<List<StudentAssessment>> cleanAndConvertStudents(
    String filePath,
    String schoolId, {
    SchoolProfile? dashboardProfile,
  }) async {
    // Use the validated extraction pipeline
    final cleanResult = await cleanSchoolExcel(
      filePath,
      dashboardProfile: dashboardProfile,
    );

    if (!cleanResult.success) {
      throw Exception('Cleaning failed: ${cleanResult.problems.join(', ')}');
    }

    // 🛠️ FIX: Extract academic year from clean result or use default
    final academicYear =
        cleanResult.reportMetadata?['school_year']?.toString() ??
            cleanResult.metadata?['extraction_stats']?['extracted_school_year']
                ?.toString() ??
            '2023-2024';

    // Convert validated data to StudentAssessment objects for dual-table structure
    return convertToStudentAssessments(
      cleanResult.data,
      schoolId,
      academicYear,
    );
  }

  /// 🆕 NEW: Clean already extracted data and convert to StudentAssessment objects
  static Future<List<StudentAssessment>> cleanExtractedDataAndConvert(
    ExtractionResult extracted,
    String schoolId,
  ) async {
    try {
      final cleanedData = <Map<String, dynamic>>[];

      for (final student in extracted.students) {
        // Apply additional cleaning logic if needed
        final cleanedStudent = _cleanStudentData(student);
        cleanedData.add(cleanedStudent);
      }

      // 🛠️ FIX: Extract academic year from extraction result
      final academicYear =
          extracted.schoolProfile['schoolYear']?.toString() ?? '2023-2024';

      return convertToStudentAssessments(cleanedData, schoolId, academicYear);
    } catch (e) {
      throw Exception('Failed to clean and convert extracted data: $e');
    }
  }

  /// 🆕 NEW: Clean StudentAssessment objects with enhanced validation
  static List<StudentAssessment> cleanStudentAssessments(
    List<StudentAssessment> students,
  ) {
    return students
        .map((student) {
          // Compute BMI if missing
          final updatedAssessment = student.assessment.computeBMI();

          // Update completeness
          final finalAssessment = updatedAssessment.updateCompleteness();

          return StudentAssessment(
            learner: student.learner,
            assessment: finalAssessment,
            period: student.period,
          );
        })
        .where((student) => student.validate().isEmpty)
        .toList();
  }

  /// 🆕 NEW: Convert StudentAssessment to SBFPStudent for backward compatibility
  static List<SBFPStudent> convertToSBFPStudents(
    List<StudentAssessment> studentAssessments,
  ) {
    return studentAssessments
        .map(
          (studentAssessment) =>
              SBFPStudent.fromStudentAssessment(studentAssessment),
        )
        .where((student) => student.isValidForImport)
        .toList();
  }

  // COMPATIBILITY METHODS FOR EXISTING CODE - UNCHANGED
  static Future<CleanResult> cleanExcelData(String filePath) async {
    return cleanSchoolExcel(filePath);
  }

  static Stream<CleanProgress> cleanExcelDataWithProgress(
    String filePath,
  ) async* {
    yield CleanProgress(progress: 0, status: 'Starting SBFP processing...');

    try {
      final result = await cleanSchoolExcel(filePath);
      yield CleanProgress(progress: 100, status: 'Complete', result: result);
    } catch (e) {
      yield CleanProgress(
        progress: 100,
        status: 'Error',
        result: CleanResult(data: [], problems: ['Error: $e'], success: false),
      );
    }
  }

  static Future<SchoolProfileImport> extractSchoolProfile(
    String filePath,
  ) async {
    final processor = ExcelFileProcessor(filePath);
    return processor.extractSchoolProfile();
  }

  /// UPDATED: Validate school profile using the extractor's validation
  static Future<ValidationResult> validateSchoolExcel(
    String filePath,
    SchoolProfile dashboardProfile,
  ) async {
    try {
      final extracted = await SBFPExtractor.extractStudents(filePath);
      final extractionResult = extracted as ExtractionResult?;

      if (extractionResult == null || extractionResult.schoolProfile.isEmpty) {
        return ValidationResult()
          ..isValid = false
          ..errors.add('Could not extract school profile from Excel file');
      }

      // Use the validation result from the extractor, ensure correct typing
      final vr = extractionResult.validationResult;
      if (vr != null) return vr;

      return ValidationResult()
        ..isValid = false
        ..errors.add('Validation result not available');
    } catch (e) {
      return ValidationResult()
        ..isValid = false
        ..errors.add('Validation failed: $e');
    }
  }

  /// 🆕 UPDATED: Unified import pipeline using validated StudentAssessment model WITH DUAL-TABLE STRUCTURE
  static Future<ImportResult> importSBFPExcelFile(
    String filePath,
    String schoolId,
    SchoolProfile schoolProfile,
  ) async {
    try {
      // 1. Extract and convert to StudentAssessment objects using validated pipeline
      final studentAssessments = await cleanAndConvertStudents(
        filePath,
        schoolId,
        dashboardProfile: schoolProfile,
      );

      // 2. Additional cleaning and validation
      final cleanedStudentAssessments = cleanStudentAssessments(
        studentAssessments,
      );

      // 3. Prepare import result
      return ImportResult(
        success: cleanedStudentAssessments.isNotEmpty,
        recordsProcessed: cleanedStudentAssessments.length,
        message:
            'Successfully imported ${cleanedStudentAssessments.length} students',
        receivedFrom: schoolProfile.schoolName,
        dataType: 'sbfp_excel',
        breakdown: {
          'students': cleanedStudentAssessments.length,
          'valid_students':
              cleanedStudentAssessments.length, // All are validated
          'needs_feeding': cleanedStudentAssessments
              .where((s) => s.needsFeedingProgram)
              .length,
          'baseline': cleanedStudentAssessments
              .where((s) => s.period == 'Baseline')
              .length,
          'endline': cleanedStudentAssessments
              .where((s) => s.period == 'Endline')
              .length,
        },
        batchId: '',
        totalRecords: 0,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        recordsProcessed: 0,
        message: 'Import failed: $e',
        receivedFrom: schoolProfile.schoolName,
        dataType: 'sbfp_excel',
        batchId: '',
        totalRecords: 0,
        breakdown: {},
      );
    }
  }
}

// ========== SUPPORTING CLASSES (ENHANCED WITH STUDENT TRACKING) ==========

class SheetAnalysis {
  int headerRow = -1;
  int dataStartRow = -1;
  Map<String, int> columnMap = {};
}

class ColumnNames {
  static const String number = 'number';
  static const String lrn = 'lrn';
  static const String name = 'name';
  static const String sex = 'sex';
  static const String gradeLevel = 'grade_level';
  static const String section = 'section';
  static const String weight = 'weight';
  static const String height = 'height';
  static const String bmi = 'bmi';
  static const String nutritionalStatus = 'nutritional_status';
}

class CleanProgress {
  final int progress;
  final String status;
  final CleanResult? result;

  CleanProgress({required this.progress, required this.status, this.result});
}

class ResultCompatibility {
  /// Convert ImportResult to Map with both recordsProcessed and recordsInserted
  static Map<String, dynamic> importResultToMap(ImportResult result) {
    return {
      'success': result.success,
      'message': result.message,
      'recordsProcessed': result.recordsProcessed,
      'recordsInserted': result.recordsProcessed, // Compatibility alias
      'errors': result.errors,
      'receivedFrom': result.receivedFrom,
      'dataType': result.dataType,
      'breakdown': result.breakdown,
      'receivedAt': result.receivedAt?.toIso8601String(),
      'validationStatus': result.validationStatus,
      'schoolNameMatch': result.schoolNameMatch,
      'districtMatch': result.districtMatch,
      'studentTrackingEnabled': result.studentTrackingEnabled,
      'studentTrackingStats': result.studentTrackingStats,
      'readyForCloudSync': result.readyForCloudSync,
      'importBatchId': result.importBatchId,
      'importTimestamp': result.importTimestamp.toIso8601String(),
      'validationSummary': result.validationSummary,
    };
  }

  /// Convert DatabaseExportResult to Map
  static Map<String, dynamic> databaseExportResultToMap(
    DatabaseExportResult result,
  ) {
    return {
      'success': result.success,
      'message': result.message,
      'recordsProcessed': result.recordsProcessed,
      'recordsInserted': result.recordsInserted,
      'error': result.error,
      'importBatchId': result.importBatchId,
      'errors': result.errors,
      'syncReady': result.syncReady,
      'syncRecordCount': result.syncRecordCount,
      'validationStatus': result.validationStatus,
      'schoolNameMatch': result.schoolNameMatch,
      'districtMatch': result.districtMatch,
      'studentTrackingStats': result.studentTrackingStats,
      'academicYearUsed': result.academicYearUsed,
    };
  }
}
