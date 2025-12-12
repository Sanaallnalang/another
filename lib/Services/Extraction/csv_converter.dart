// csv_converter.dart - COMPLETE UPDATED CODE WITH SCHOOL YEAR FIX
import 'dart:convert';
import 'dart:math';
import 'package:district_dev/Services/Data%20Model/acad_schyear_manager.dart';
import 'package:district_dev/Services/Data%20Model/date_utilities.dart';
import 'package:district_dev/Services/Data%20Model/exce_external_cleaner.dart';
import 'package:district_dev/Services/Data%20Model/import_metadata.dart';
import 'package:district_dev/Services/Data%20Model/import_student.dart';
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:district_dev/Services/Database/database_service.dart';
import 'package:district_dev/Services/Extraction/excel_cleaner.dart'
    hide AssessmentCompletenessTracker;
import 'package:flutter/foundation.dart' hide kDebugMode;

// ADD MISSING CONSTANT FOR COMPATIBILITY
const bool kDebugMode = true;

/// 🆕 NEW: Learner data model
class Learner {
  final String learnerName;
  final String studentId;
  final String normalizedName;
  final String? lrn;
  final String sex;
  final String gradeLevel;
  final String? section;
  final String? dateOfBirth;
  final int? age;
  final String schoolId;
  final String academicYear;
  final DateTime createdAt;

  Learner({
    required this.learnerName,
    required this.studentId,
    required this.normalizedName,
    this.lrn,
    required this.sex,
    required this.gradeLevel,
    this.section,
    this.dateOfBirth,
    this.age,
    required this.schoolId,
    this.academicYear = '2024-2025',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'learner_name': learnerName,
      'student_id': studentId,
      'normalized_name': normalizedName,
      'lrn': lrn,
      'sex': sex,
      'grade_level': gradeLevel,
      'section': section,
      'date_of_birth': dateOfBirth,
      'age': age,
      'school_id': schoolId,
      'academic_year': academicYear,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 🆕 NEW: Assessment data model
class Assessment {
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final String nutritionalStatus;
  final String assessmentDate;
  final String assessmentCompleteness;

  Assessment({
    this.weightKg,
    this.heightCm,
    this.bmi,
    required this.nutritionalStatus,
    required this.assessmentDate,
    required this.assessmentCompleteness,
  });

  Map<String, dynamic> toMap() {
    return {
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'nutritional_status': nutritionalStatus,
      'assessment_date': assessmentDate,
      'assessment_completeness': assessmentCompleteness,
    };
  }
}

class StudentAssessment {
  final Learner learner;
  final Assessment assessment;
  final String period;
  final String academicYear;

  StudentAssessment({
    required this.learner,
    required this.assessment,
    required this.period,
    this.academicYear = '2024-2025',
  });

  /// Create from combined data map
  factory StudentAssessment.fromCombinedData(
    Map<String, dynamic> data,
    String schoolId,
    String academicYear,
    String period,
  ) {
    return StudentAssessment(
      learner: Learner(
        learnerName: data['name']?.toString() ?? '',
        studentId: data['student_id']?.toString() ?? '',
        normalizedName: data['normalized_name']?.toString() ??
            StudentIdentificationService.normalizeName(
              data['name']?.toString() ?? '',
            ),
        lrn: data['lrn']?.toString(),
        sex: data['sex']?.toString() ?? 'Unknown',
        gradeLevel: data['grade_level']?.toString() ?? 'Unknown',
        section: data['section']?.toString(),
        dateOfBirth: data['birth_date']?.toString(),
        age: data['age'] != null ? int.tryParse(data['age'].toString()) : null,
        schoolId: schoolId,
        academicYear: academicYear,
        createdAt: DateTime.now(),
      ),
      assessment: Assessment(
        weightKg: data['weight_kg'] != null
            ? double.tryParse(data['weight_kg'].toString())
            : null,
        heightCm: data['height_cm'] != null
            ? double.tryParse(data['height_cm'].toString())
            : null,
        bmi: data['bmi'] != null
            ? double.tryParse(data['bmi'].toString())
            : null,
        nutritionalStatus: data['nutritional_status']?.toString() ?? 'Unknown',
        assessmentDate: data['assessment_date']?.toString() ??
            data['weighing_date']?.toString() ??
            DateTime.now().toIso8601String().split('T').first,
        assessmentCompleteness: data['assessment_completeness']?.toString() ??
            AssessmentCompletenessTracker.determineIndividualCompleteness(data),
      ),
      period: period,
      academicYear: academicYear,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...learner.toMap(),
      ...assessment.toMap(),
      'period': period,
      'academic_year': academicYear,
    };
  }

  validate() {}
}

/// 🆕 UPDATED: Student Identification Service with SHORTER IDs
class StudentIdentificationService {
  /// Normalize student name for consistent matching
  static String normalizeName(String name) {
    if (name.isEmpty) return '';

    // Remove extra whitespace and convert to lowercase
    final cleaned = name.trim().toLowerCase();

    // Remove common titles and suffixes
    final withoutTitles = cleaned
        .replaceAll(RegExp(r'\b(mr|mrs|ms|dr|jr|sr|ii|iii|iv)\b'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();

    return withoutTitles;
  }

  /// 🆕 UPDATED: Generate SHORTER student ID based on school acronym and random number
  static String generateDeterministicStudentID(String name, String schoolId) {
    // Extract school acronym from school ID or name
    final schoolAcronym = _extractSchoolAcronym(schoolId);

    // Generate a shorter random number based on name and school
    final randomNumber = _generateShortRandomNumber(name, schoolId);

    // Format: SVES_24324
    return '${schoolAcronym}_$randomNumber';
  }

  /// 🆕 NEW: Extract school acronym from school name or ID
  static String _extractSchoolAcronym(String schoolId) {
    if (schoolId.isEmpty) return 'SCH';

    // If schoolId already looks like an acronym (all caps, short), use it
    if (schoolId == schoolId.toUpperCase() && schoolId.length <= 6) {
      return schoolId;
    }

    // Try to extract from school name patterns
    // Common pattern: "schoolName_district" or just school name
    final parts = schoolId.split('_');
    if (parts.isNotEmpty) {
      final schoolName = parts[0];

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
    }

    return 'SCH';
  }

  /// 🆕 NEW: Generate shorter random number (5 digits)
  static String _generateShortRandomNumber(String name, String schoolId) {
    // Create a consistent hash from name and school
    final hashInput = '${name.toLowerCase()}_$schoolId';
    final hashCode = hashInput.hashCode.abs();

    // Get last 5 digits of the hash (ensures it's always 5 digits)
    final shortNumber = hashCode % 100000;

    // Pad with leading zeros if needed (e.g., 00123)
    return shortNumber.toString().padLeft(5, '0');
  }

  /// OLD METHOD (Keep for reference/compatibility)
  static String _simpleHash(String input) {
    return input.hashCode.abs().toString();
  }
} // ADD THIS HELPER CLASS AT THE TOP OF csv_converter.dart

class ValidationResultHelper {
  static ValidationResult create({
    required bool isValid,
    required bool matchedSchoolName,
    required bool matchedDistrict,
    List<String> errors = const [],
    List<String> warnings = const [],
  }) {
    final result = ValidationResult();
    result.isValid = isValid;
    result.matchedSchoolName = matchedSchoolName;
    result.matchedDistrict = matchedDistrict;
    result.errors = errors;
    result.warnings = warnings;
    return result;
  }
}

/// 🆕 NEW: Bridge class to handle both CleanResult and List<StudentAssessment>
class DataPipelineBridge {
  /// Convert List<StudentAssessment> to CleanResult format
  static CleanResult studentAssessmentsToCleanResult(
    List<StudentAssessment> studentAssessments, {
    ValidationResult? validationResult,
    Map<String, dynamic>? metadata,
    List<String> problems = const [],
  }) {
    // Convert StudentAssessment objects to Map format
    final data = studentAssessments.map((assessment) {
      return {
        'name': assessment.learner.learnerName,
        'student_id': assessment.learner.studentId,
        'normalized_name': assessment.learner.normalizedName,
        'lrn': assessment.learner.lrn,
        'sex': assessment.learner.sex,
        'grade_level': assessment.learner.gradeLevel,
        'section': assessment.learner.section,
        'birth_date': assessment.learner.dateOfBirth,
        'age': assessment.learner.age,
        'weight_kg': assessment.assessment.weightKg,
        'height_cm': assessment.assessment.heightCm,
        'bmi': assessment.assessment.bmi,
        'nutritional_status': assessment.assessment.nutritionalStatus,
        'assessment_date': assessment.assessment.assessmentDate,
        'assessment_completeness': assessment.assessment.assessmentCompleteness,
        'period': assessment.period,
        'school_id': assessment.learner.schoolId,
        'academic_year': assessment.learner.academicYear,
        'created_at': assessment.learner.createdAt.toIso8601String(),
      };
    }).toList();

    // Extract report metadata from the first student if available
    Map<String, dynamic>? reportMetadata;
    if (studentAssessments.isNotEmpty) {
      final firstStudent = studentAssessments.first;
      reportMetadata = {
        'school_year': firstStudent.learner.academicYear,
        'period': firstStudent.period,
        'school_name': metadata?['school_name'] ?? 'Unknown School',
        'weighing_date': firstStudent.assessment.assessmentDate,
      };
    }

    return CleanResult(
      success: studentAssessments.isNotEmpty,
      data: data,
      problems: problems,
      metadata: metadata ?? {},
      reportMetadata: reportMetadata,
    );
  }

  /// Convert CleanResult to List<StudentAssessment>
  static List<StudentAssessment> cleanResultToStudentAssessments(
    CleanResult cleanResult,
    String schoolId,
    String academicYear,
  ) {
    return cleanResult.data.map((studentData) {
      return StudentAssessment.fromCombinedData(
        studentData,
        schoolId,
        academicYear,
        studentData['period'] ?? 'Baseline',
      );
    }).toList();
  }

  /// Enhanced method to handle both data types
  static CleanResult ensureCleanResult(
    dynamic data, {
    ValidationResult? validationResult,
    Map<String, dynamic>? metadata,
    String schoolId = '',
    String academicYear = '2024-2025',
  }) {
    if (data is CleanResult) {
      return data;
    } else if (data is List<StudentAssessment>) {
      return studentAssessmentsToCleanResult(
        data,
        validationResult: validationResult,
        metadata: metadata,
      );
    } else {
      throw ArgumentError(
        'Data must be either CleanResult or List<StudentAssessment>',
      );
    }
  }
}

class StudentNameMatcher {
  /// Calculate name similarity for fuzzy matching with better accuracy
  static double calculateNameSimilarity(String name1, String name2) {
    final clean1 = _normalizeName(name1);
    final clean2 = _normalizeName(name2);

    if (clean1 == clean2) return 1.0;
    if (clean1.isEmpty || clean2.isEmpty) return 0.0;

    // Use Jaro-Winkler distance for better accuracy
    return _jaroWinklerSimilarity(clean1, clean2);
  }

  /// Jaro-Winkler similarity implementation
  static double _jaroWinklerSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;

    final jaroDistance = _jaroDistance(s1, s2);
    final prefixScale = 0.1;
    final prefixLength = _commonPrefixLength(s1, s2);

    return jaroDistance + (prefixLength * prefixScale * (1 - jaroDistance));
  }

  static double _jaroDistance(String s1, String s2) {
    final maxDistance = (max(s1.length, s2.length) ~/ 2) - 1;
    var matches = 0;
    var transpositions = 0;

    final s1Matches = List<bool>.filled(s1.length, false);
    final s2Matches = List<bool>.filled(s2.length, false);

    // Count matches
    for (var i = 0; i < s1.length; i++) {
      final start = max(0, i - maxDistance);
      final end = min(i + maxDistance + 1, s2.length);

      for (var j = start; j < end; j++) {
        if (!s2Matches[j] && s1[i] == s2[j]) {
          s1Matches[i] = true;
          s2Matches[j] = true;
          matches++;
          break;
        }
      }
    }

    if (matches == 0) return 0.0;

    // Count transpositions
    var k = 0;
    for (var i = 0; i < s1.length; i++) {
      if (s1Matches[i]) {
        while (!s2Matches[k]) {
          k++;
        }
        if (s1[i] != s2[k]) transpositions++;
        k++;
      }
    }

    transpositions ~/= 2;

    return (matches / s1.length +
            matches / s2.length +
            (matches - transpositions) / matches) /
        3.0;
  }

  static int _commonPrefixLength(String s1, String s2) {
    final minLength = min(s1.length, s2.length);
    for (var i = 0; i < minLength; i++) {
      if (s1[i] != s2[i]) return i;
    }
    return minLength;
  }

  static String _normalizeName(String name) {
    return StudentIdentificationService.normalizeName(name);
  }

  /// Check if two names likely represent the same student
  static bool isLikelySameStudent(
    String name1,
    String name2, {
    double threshold = 0.85,
  }) {
    return calculateNameSimilarity(name1, name2) >= threshold;
  }
}

/// 🆕 ENHANCED: Data Pipeline Manager for robust connectivity
class CSVDataFlowManager {
  static final DatabaseService _dbService = DatabaseService.instance;

  /// 🎯 MAIN ENTRY POINT: Process Excel file through complete pipeline
  static Future<DatabaseExportResult> processExcelFileThroughPipeline(
    String filePath,
    String schoolId,
    SchoolProfile schoolProfile, {
    bool strictValidation = false,
    Map<String, dynamic>? importMetadata,
  }) async {
    try {
      print("🔄 STARTING COMPLETE DATA PIPELINE...");
      print("📁 File: $filePath");
      print("🏫 School: $schoolId");

      // Step 1: Extract and clean data from Excel
      print("1️⃣ EXTRACTING DATA FROM EXCEL...");
      final studentAssessments = await ExcelCleaner.cleanAndConvertStudents(
        filePath,
        schoolId,
        dashboardProfile: schoolProfile,
      );

      // 🛠️ FIX: Convert StudentAssessment list to CleanResult format
      final cleanResult = DataPipelineBridge.studentAssessmentsToCleanResult(
        studentAssessments.cast<StudentAssessment>(),
        metadata: {
          'school_name': schoolProfile.schoolName,
          'district': schoolProfile.district,
          'total_sheets': 1,
          'sheets_processed': ['Main Sheet'],
        },
      );

      if (!cleanResult.success || cleanResult.data.isEmpty) {
        print("❌ Excel extraction failed or returned no data");
        return DatabaseExportResult(
          success: false,
          recordsInserted: 0,
          message: 'Excel extraction failed: No valid data found',
          syncReady: false,
          validationStatus: false,
        );
      }

      print(
        "✅ Excel extraction successful: ${cleanResult.data.length} records",
      );

      // 🎯 NEW: Check for nutritional imputation
      if (cleanResult.reportMetadata?['imputation_applied'] == true) {
        print("🧪 NUTRITIONAL IMPUTATION WAS APPLIED DURING CLEANING");
      }

      // Step 2: Enhanced data validation and transformation
      print("2️⃣ ENHANCED DATA VALIDATION AND TRANSFORMATION...");
      final validatedData = await _validateAndTransformData(
        cleanResult.data,
        schoolId,
        cleanResult.validationResult,
      );

      if (validatedData.isEmpty) {
        print("❌ Data validation failed - no valid records");
        return DatabaseExportResult(
          success: false,
          recordsInserted: 0,
          message:
              'Data validation failed: No valid records after transformation',
          syncReady: false,
          validationStatus: false,
        );
      }

      print(
        "✅ Data validation successful: ${validatedData.length} valid records",
      );

      // Step 3: Save to database using enhanced method
      print("3️⃣ SAVING TO DATABASE WITH STUDENT TRACKING...");
      final enhancedCleanResult = CleanResult(
        success: true,
        data: validatedData,
        problems: cleanResult.problems,
        metadata: cleanResult.metadata,
        reportMetadata: cleanResult.reportMetadata,
        validationResult: cleanResult.validationResult,
      );

      final databaseResult = await CSVExporter.saveToDatabase(
        enhancedCleanResult,
        schoolId,
        importMetadata: importMetadata,
      );

      print("🎯 DATABASE SAVE RESULT:");
      print("   Success: ${databaseResult.success}");
      print("   Records: ${databaseResult.recordsInserted}");
      print("   Sync Ready: ${databaseResult.syncReady}");
      print("   Academic Year Used: ${databaseResult.academicYearUsed}");

      // Step 4: Verify database insertion
      if (databaseResult.success) {
        print("4️⃣ VERIFYING DATABASE INSERTION...");
        await _verifyDatabaseInsertion(
          schoolId,
          databaseResult.recordsInserted,
        );
      }

      return databaseResult;
    } catch (e, st) {
      print("❌ COMPLETE PIPELINE FAILED: $e");
      print(st);
      return DatabaseExportResult(
        success: false,
        recordsInserted: 0,
        message: 'Pipeline failed: $e',
        error: e.toString(),
        syncReady: false,
        validationStatus: false,
      );
    }
  }

  /// 🛠️ ENHANCED: Validate and transform data with better error handling
  static Future<List<Map<String, dynamic>>> _validateAndTransformData(
    List<Map<String, dynamic>> rawData,
    String schoolId,
    ValidationResult? validationResult,
  ) async {
    final validatedData = <Map<String, dynamic>>[];
    int skippedCount = 0;

    for (final student in rawData) {
      try {
        // Enhanced validation
        if (!_isValidStudentRecord(student)) {
          skippedCount++;
          continue;
        }

        // Ensure student ID generation with SHORTER IDs
        final studentWithId = await _ensureStudentId(student, schoolId);

        // Enhanced data transformation
        final transformedStudent = _transformStudentData(
          studentWithId,
          schoolId,
        );

        if (transformedStudent != null) {
          validatedData.add(transformedStudent);
        } else {
          skippedCount++;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error processing student ${student['name']}: $e');
        }
        skippedCount++;
      }
    }

    if (skippedCount > 0) {
      print("⚠️  Skipped $skippedCount invalid records during validation");
    }

    return validatedData;
  }

  /// 🔍 VALIDATION: Check if student record is valid
  static bool _isValidStudentRecord(Map<String, dynamic> student) {
    final name = student['name']?.toString().trim() ?? '';
    final gradeLevel = student['grade_level']?.toString().trim() ?? '';

    // Basic validation
    if (name.isEmpty || name.length < 2) return false;
    if (gradeLevel.isEmpty) return false;

    // Skip header-like entries
    if (_looksLikeHeader(name)) return false;

    // Must have at least some assessment data
    final hasWeight = student['weight_kg'] != null;
    final hasHeight = student['height_cm'] != null;
    final hasBMI = student['bmi'] != null;
    final hasStatus = student['nutritional_status'] != null &&
        student['nutritional_status'].toString().isNotEmpty;

    return hasWeight || hasHeight || hasBMI || hasStatus;
  }

  static bool _looksLikeHeader(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower.contains('name of') ||
        lower.contains('instruction') ||
        lower.contains('example') ||
        lower.contains('no.') ||
        lower.contains('lrn') ||
        lower.contains('sex') ||
        lower.contains('grade') ||
        lower.contains('section') ||
        lower.contains('weight') ||
        lower.contains('height') ||
        lower.contains('bmi') ||
        lower.contains('nutritional status');
  }

  /// 🛠️ UPDATED: Generate consistent student IDs based on name
  static Future<Map<String, dynamic>> _ensureStudentId(
    Map<String, dynamic> student,
    String schoolId,
  ) async {
    final studentName = student['name']?.toString().trim() ?? '';

    if (studentName.isEmpty) {
      return {...student, 'student_id': 'INVALID_EMPTY_NAME'};
    }

    // Try to find existing student to get their ID
    final existingStudent = await StudentMatchingService.findExistingStudent(
      student,
      schoolId,
      _dbService,
      null,
    );

    String finalStudentId;

    if (existingStudent != null) {
      // 🎯 USE EXISTING STUDENT ID (most important fix!)
      finalStudentId = existingStudent['student_id']?.toString() ?? '';

      if (finalStudentId.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('🎯 REUSING existing student ID: $finalStudentId');
        }
      } else {
        // Generate new ID for existing record that somehow doesn't have one
        final schoolAcronym = _extractSchoolAcronym(schoolId);
        finalStudentId =
            StudentIdentificationService.generateDeterministicStudentID(
          studentName,
          schoolAcronym,
        );
        if (kDebugMode) {
          debugPrint('🆕 Generated ID for existing student: $finalStudentId');
        }
      }
    } else {
      // Generate new ID for new student
      final schoolAcronym = _extractSchoolAcronym(schoolId);
      finalStudentId =
          StudentIdentificationService.generateDeterministicStudentID(
        studentName,
        schoolAcronym,
      );
      if (kDebugMode) {
        debugPrint('🆕 Generated new student ID: $finalStudentId');
      }
    }

    return {
      ...student,
      'student_id': finalStudentId,
      'normalized_name': StudentIdentificationService.normalizeName(
        studentName,
      ),
    };
  }

  /// 🆕 NEW: Extract school acronym for ID generation
  static String _extractSchoolAcronym(String schoolId) {
    if (schoolId.isEmpty) return 'SCH';

    // Try to extract from patterns like "schoolName_district"
    final parts = schoolId.split('_');
    if (parts.isNotEmpty) {
      final schoolName = parts[0];
      final words = schoolName.split(' ');

      if (words.length > 1) {
        // Multi-word school name
        final acronym = words.map((word) {
          if (word.isNotEmpty) {
            return word[0].toUpperCase();
          }
          return '';
        }).join('');

        if (acronym.length >= 3) {
          return acronym.length <= 4 ? acronym : acronym.substring(0, 4);
        }
      } else if (schoolName.length >= 3) {
        // Single word school name
        return schoolName.substring(0, min(4, schoolName.length)).toUpperCase();
      }
    }

    return 'SCH';
  } // csv_converter.dart - StudentMatchingService

// In csv_converter.dart

  static Map<String, dynamic> resolveStudentData(
    Map<String, dynamic> existingStudent,
    Map<String, dynamic> newStudent,
    String existingPeriod,
    String newPeriod,
  ) {
    final merged = Map<String, dynamic>.from(existingStudent);

    // Merge Demographics
    merged['lrn'] = newStudent['lrn'] ?? existingStudent['lrn'];
    merged['learner_name'] =
        newStudent['learner_name'] ?? existingStudent['learner_name'];
    merged['sex'] = newStudent['sex'] ?? existingStudent['sex'];
    merged['birthdate'] =
        newStudent['birthdate'] ?? existingStudent['birthdate'];
    merged['grade_level'] =
        newStudent['grade_level'] ?? existingStudent['grade_level'];
    merged['section'] = newStudent['section'] ?? existingStudent['section'];

    // --- 🔍 FIX: Create Safe Data Maps ---

    final newAssessment = {
      'weight_kg': newStudent['weight_kg'],
      'height_cm': newStudent['height_cm'],
      'bmi': newStudent['bmi'],
      'nutritional_status': newStudent['nutritional_status'],
      'weighing_date': newStudent['weighing_date'],
    };

    final oldBaseline = {
      'weight_kg': existingStudent['baseline_weight_kg'],
      'height_cm': existingStudent['baseline_height_cm'],
      'bmi': existingStudent['baseline_bmi'],
      'nutritional_status': existingStudent['baseline_nutritional_status'],
      'weighing_date': existingStudent['baseline_weighing_date'],
    };

    final oldEndline = {
      'weight_kg': existingStudent['endline_weight_kg'],
      'height_cm': existingStudent['endline_height_cm'],
      'bmi': existingStudent['endline_bmi'],
      'nutritional_status': existingStudent['endline_nutritional_status'],
      'weighing_date': existingStudent['endline_weighing_date'],
    };

    // --- 🔍 FIX: Smart Merge Logic ---

    // Case 1: Updating the same period (Overwrite)
    if (existingPeriod == newPeriod && newPeriod != 'null') {
      merged['weight_kg'] =
          newAssessment['weight_kg'] ?? existingStudent['weight_kg'];
      merged['height_cm'] =
          newAssessment['height_cm'] ?? existingStudent['height_cm'];
      merged['bmi'] = newAssessment['bmi'] ?? existingStudent['bmi'];
      merged['nutritional_status'] = newAssessment['nutritional_status'] ??
          existingStudent['nutritional_status'];
      merged['weighing_date'] =
          newAssessment['weighing_date'] ?? existingStudent['weighing_date'];
      merged['period'] = newPeriod;
    }
    // Case 2: New Period (Preserve Old + Add New)
    else if (newPeriod != 'null') {
      if (newPeriod == 'Baseline') {
        merged['baseline_data'] = newAssessment;
        // Keep Endline if it exists
        if (existingStudent['has_endline'] == true)
          merged['endline_data'] = oldEndline;
      } else if (newPeriod == 'Endline') {
        merged['endline_data'] = newAssessment;
        // Keep Baseline if it exists
        if (existingStudent['has_baseline'] == true)
          merged['baseline_data'] = oldBaseline;
      }
      merged['period_to_upsert'] = newPeriod;
    }

    // Update Flags
    merged['has_baseline'] = merged['baseline_data'] != null;
    merged['has_endline'] = merged['endline_data'] != null;

    return merged;
  }

  /// 🔄 ENHANCED: Transform student data for database
  static Map<String, dynamic>? _transformStudentData(
    Map<String, dynamic> student,
    String schoolId,
  ) {
    try {
      final period = student['period']?.toString() ?? 'Baseline';
      final assessmentCompleteness =
          student['assessment_completeness']?.toString() ??
              AssessmentCompletenessTracker.determineIndividualCompleteness(
                student,
              );

      return {
        ...student,
        'school_id': schoolId,
        'assessment_completeness': assessmentCompleteness,
        'period': period,
        // Ensure critical fields are present
        'grade_level_id': _mapGradeToId(student['grade_level']),
        'academic_year': student['academic_year']?.toString() ?? '2024-2025',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error transforming student data: $e');
      }
      return null;
    }
  }

  static int _mapGradeToId(dynamic grade) {
    if (grade == null) return 0;
    final gradeString = grade.toString();
    final gradeMap = {
      'Kinder': 0,
      'K': 0,
      'Grade 1': 1,
      '1': 1,
      'G1': 1,
      'Grade 2': 2,
      '2': 2,
      'G2': 2,
      'Grade 3': 3,
      '3': 3,
      'G3': 3,
      'Grade 4': 4,
      '4': 4,
      'G4': 4,
      'Grade 5': 5,
      '5': 5,
      'G5': 5,
      'Grade 6': 6,
      '6': 6,
      'G6': 6,
      'SPED': 7,
    };
    return gradeMap[gradeString] ?? 0;
  }

  /// 🔍 VERIFICATION: Check if data actually made it to database
  static Future<void> _verifyDatabaseInsertion(
    String schoolId,
    int expectedRecords,
  ) async {
    try {
      final learners = await _dbService.getLearnersBySchool(schoolId);
      final actualCount = learners.length;

      print("🔍 DATABASE VERIFICATION:");
      print("   Expected: $expectedRecords");
      print("   Actual: $actualCount");

      if (actualCount < expectedRecords) {
        print("⚠️  WARNING: Some records may not have been inserted properly");
        // Log details for debugging
        if (learners.isNotEmpty) {
          print("   Sample inserted records:");
          for (int i = 0; i < min(3, learners.length); i++) {
            print(
              "     - ${learners[i]['learner_name']} (ID: ${learners[i]['student_id']})",
            );
          }
        }
      } else {
        print("✅ Database insertion verified successfully");
      }
    } catch (e) {
      print("❌ Verification failed: $e");
    }
  }

  /// 🧪 TEST METHOD: Verify complete data pipeline
  static Future<Map<String, dynamic>> testCompletePipeline(
    String filePath,
    String schoolId,
    SchoolProfile schoolProfile,
  ) async {
    try {
      print("🧪 TESTING COMPLETE DATA PIPELINE...");

      // Test Excel extraction
      print("1. Testing Excel extraction...");
      final studentAssessments = await ExcelCleaner.cleanAndConvertStudents(
        filePath,
        schoolId,
        dashboardProfile: schoolProfile,
      );

      // Convert to CleanResult for compatibility
      final cleanResult = DataPipelineBridge.studentAssessmentsToCleanResult(
        studentAssessments.cast<StudentAssessment>(),
      );

      if (!cleanResult.success) {
        return {
          'success': false,
          'step': 'excel_extraction',
          'message': 'Excel extraction failed',
          'data_count': 0,
        };
      }

      // Test CSV conversion
      print("2. Testing CSV conversion...");
      final databaseData = await _validateAndTransformData(
        cleanResult.data,
        schoolId,
        cleanResult.validationResult,
      );

      if (databaseData.isEmpty) {
        return {
          'success': false,
          'step': 'csv_conversion',
          'message': 'CSV conversion failed',
          'data_count': 0,
        };
      }

      // Test database connection
      print("3. Testing database connection...");
      final db = await _dbService.database;
      final testQuery = await db.rawQuery('SELECT 1 as test');
      final dbConnected = testQuery.isNotEmpty;

      if (!dbConnected) {
        return {
          'success': false,
          'step': 'database_connection',
          'message': 'Database connection failed',
          'data_count': databaseData.length,
        };
      }

      return {
        'success': true,
        'message': 'Complete pipeline test passed',
        'excel_data_count': cleanResult.data.length,
        'converted_data_count': databaseData.length,
        'database_connected': true,
        'pipeline_ready': true,
      };
    } catch (e, st) {
      print("❌ Pipeline test failed: $e");
      print(st);
      return {
        'success': false,
        'message': 'Pipeline test failed: $e',
        'error': e.toString(),
        'stack_trace': st.toString(),
      };
    }
  }
}

/// Enhanced CSV Exporter with Student Tracking & Complete Data Exchange Capabilities
class CSVExporter {
  static final DatabaseService _dbService = DatabaseService.instance;

  // ========== CORE DATA EXPORT METHODS ==========

  /// 🛠️ ENHANCED: Save to database with SCHOOL YEAR FIX and NUTRITIONAL IMPUTATION support
  static Future<DatabaseExportResult> saveToDatabase(
    CleanResult result,
    String schoolId, {
    Map<String, dynamic>? importMetadata,
  }) async {
    try {
      print("🔄 CSV CONVERTER: Starting database save with SCHOOL YEAR FIX...");
      print("   CleanResult data count: ${result.data.length}");
      print("   CleanResult success: ${result.success}");
      print("   Validation result: ${result.validationResult?.isValid}");

      // 🎯 CRITICAL: Check for nutritional imputation
      final imputationApplied =
          result.reportMetadata?['imputation_applied'] == true;
      if (imputationApplied) {
        print("🧪 NUTRITIONAL IMPUTATION: Applied during cleaning");
      }

      // 🆕 ENHANCED: Debug the actual student data being passed
      if (result.data.isNotEmpty) {
        print("\n🔍 ENHANCED SAMPLE DATA BEFORE DATABASE TRANSFORMATION:");
        for (int i = 0; i < min(3, result.data.length); i++) {
          var student = result.data[i];
          print("   Student ${i + 1}:");
          print("     Name: ${student['name']}");
          print("     Grade: ${student['grade_level']}");
          print("     Status: ${student['nutritional_status']}");
          print("     BMI: ${student['bmi']}");
          print("     Weight: ${student['weight_kg']}");
          print("     Height: ${student['height_cm']}");
          print("     Period: ${student['period']}");
          print("     Student ID: ${student['student_id'] ?? 'Not Set'}");
          print(
            "     Missing Required Fields: ${_getMissingRequiredFields(student)}",
          );
        }
      }

      // 🛠️ ENHANCED FIX: Use emergency pipeline if main pipeline failed
      if (!result.success || result.data.isEmpty) {
        print("🔄 MAIN PIPELINE FAILED, TRYING ENHANCED EMERGENCY PIPELINE...");
        final emergencyData = _applyEnhancedEmergencyTransformation(
          result.data,
          schoolId,
        );
        if (emergencyData.isNotEmpty) {
          print(
            "✅ ENHANCED EMERGENCY TRANSFORMATION: ${emergencyData.length} students recovered",
          );
          // Replace original data with emergency data
          result = CleanResult(
            success: true,
            data: emergencyData,
            problems: result.problems,
            metadata: result.metadata,
            reportMetadata: result.reportMetadata,
            validationResult: result.validationResult,
          );
        }
      }

      // 🛑 ENHANCED FIX: Validate Grade Level IDs before proceeding
      final validationResult = await _validateGradeLevels(
        result.data,
        schoolId,
      );
      if (!validationResult.success) {
        return DatabaseExportResult(
          success: false,
          recordsInserted: 0,
          message: validationResult.message,
          syncReady: false,
          validationStatus: false,
        );
      }

      ValidationResultHelper.create(
        isValid: false,
        matchedSchoolName: false,
        matchedDistrict: false,
        errors: ['Error message'],
      );

      // ENHANCED: Critical verification for nutritional status data loss
      _verifyNutritionalStatusData(result);

      // 🎯🎯🎯 CRITICAL SCHOOL YEAR FIX: Extract academic year from reportMetadata
      // This prioritizes the year from the Excel file over any other source
      final academicYear = result.reportMetadata?['school_year']?.toString() ??
          importMetadata?['school_year'] as String? ??
          '2024-2025';

      if (kDebugMode) {
        print("📚 SCHOOL YEAR FOR IMPORT: $academicYear");
        if (result.reportMetadata?['school_year'] != null) {
          print("   Source: Excel File Report Metadata");
        } else if (importMetadata?['school_year'] != null) {
          print("   Source: Import Metadata");
        } else {
          print("   Source: Default Fallback");
        }
      }

      // Enhanced import metadata for basic sync
      final enhancedMetadata = {
        'school_year': academicYear, // 🎯 USING CORRECT YEAR FROM EXCEL
        'period': importMetadata?['period'] ?? result.reportMetadata?['period'],
        'school_name': importMetadata?['school_name'] ??
            result.reportMetadata?['school_name'],
        'weighing_date': importMetadata?['weighing_date'] ??
            result.reportMetadata?['weighing_date'],
        'total_sheets':
            importMetadata?['total_sheets'] ?? result.metadata?['total_sheets'],
        'sheets_processed': importMetadata?['sheets_processed'] ??
            result.metadata?['sheets_processed'],
        // NEW: Enhanced validation metadata
        'file_hash': _generateSimpleHash(result.data),
        'validation_result': _extractEnhancedValidation(result),
        'ready_for_sync': true,
        'import_timestamp': DateTime.now().millisecondsSinceEpoch,
        // NEW: Include validation results from extraction
        'school_validation_passed': result.validationResult?.isValid ?? false,
        'school_name_match':
            result.validationResult?.matchedSchoolName ?? false,
        'district_match': result.validationResult?.matchedDistrict ?? false,
        // NEW: Student tracking metadata
        'student_tracking_enabled': true,
        'fuzzy_matching_threshold': 0.85,
        'students_with_ids': result.data
            .where((student) => student['student_id'] != null)
            .length,
        'total_students': result.data.length,
        // 🛠️ NEW: Pipeline version info
        'pipeline_version': 'enhanced_robust_v3',
        'emergency_pipeline_used': !result.success,
        // 🎯 NEW: Store academic year explicitly
        'academic_year': academicYear,
        // 🎯 NEW: Nutritional imputation info
        'nutritional_imputation_applied': imputationApplied,
        'nutritional_status_analysis':
            result.metadata?['nutritional_status_analysis'],
      };

      // Convert CleanResult data to database-compatible format WITH STUDENT TRACKING
      final databaseReadyData = await processStudentsWithTracking(
        result.data,
        schoolId,
        result.validationResult,
        academicYear,
      );

      // 🛠️ ENHANCED FIX: If no data after processing, try enhanced emergency pipeline
      if (databaseReadyData.isEmpty && result.data.isNotEmpty) {
        print(
          "🔄 NO DATA AFTER PROCESSING, APPLYING ENHANCED EMERGENCY TRANSFORMATION...",
        );
        final emergencyData = _applyEnhancedEmergencyTransformation(
          result.data,
          schoolId,
        );
        databaseReadyData.addAll(emergencyData);
        print(
          "✅ ENHANCED EMERGENCY TRANSFORMATION: ${emergencyData.length} students recovered",
        );
      }

      // ENHANCED: Debug nutritional status before database insertion
      if (kDebugMode) {
        debugPrint('🔍 ENHANCED NUTRITIONAL STATUS CHECK BEFORE DATABASE:');
        for (int i = 0; i < min(3, databaseReadyData.length); i++) {
          final student = databaseReadyData[i];
          debugPrint('   Student ${i + 1}: ${student['learner_name']}');
          debugPrint(
            '     Nutritional Status: ${student['nutritional_status']}',
          );
          debugPrint('     BMI: ${student['bmi']}');
          debugPrint('     Grade Level ID: ${student['grade_level_id']}');
          debugPrint('     Student ID: ${student['student_id']}');
          debugPrint('     Period: ${student['period']}');
          debugPrint(
            '     Assessment Completeness: ${student['assessment_completeness']}',
          );
          debugPrint('     Academic Year: ${student['academic_year']}');
        }
      }

      // Use the bulk import method from DatabaseService WITH STUDENT TRACKING
      final importResult = await _dbService.bulkImportFromCSVData(
        databaseReadyData,
        schoolId,
        enhancedMetadata,
      );

      // 🎯 🎯 🎯 CRITICAL FIX: UPDATE SCHOOL'S ACTIVE ACADEMIC YEARS 🎯 🎯 🎯
      if (importResult['success'] == true &&
          importResult['records_processed'] != null &&
          importResult['records_processed'] > 0) {
        print("🎯 UPDATING SCHOOL ACTIVE ACADEMIC YEARS...");

        try {
          // Extract the academic year to add
          final yearToAdd = academicYear.trim();

          if (yearToAdd.isNotEmpty && yearToAdd.contains('-')) {
            // Call the method to update school's active academic years
            await _dbService.updateSchoolActiveAcademicYears(
              schoolId,
              yearToAdd,
            );

            print(
              "✅ SCHOOL METADATA UPDATED: Added $yearToAdd to active years",
            );

            // Also verify by checking current school data
            final schoolData = await _dbService.getSchool(schoolId);
            if (schoolData != null) {
              final currentActiveYears =
                  schoolData['active_academic_years']?.toString() ?? '';
              print("📋 CURRENT ACTIVE ACADEMIC YEARS: $currentActiveYears");
            }
          } else {
            print(
              "⚠️ Invalid academic year format for metadata update: $yearToAdd",
            );
          }
        } catch (e) {
          print("⚠️ Failed to update school academic years (non-critical): $e");
          // Don't fail the import - this is metadata only
        }
      }

      // ENHANCED: Prepare data for sync with ImportMetadata model
      await _prepareForSyncEnhanced(
        schoolId,
        importResult['import_batch_id'],
        databaseReadyData,
        result.validationResult,
      );

      return DatabaseExportResult(
        success: importResult['errors']?.isEmpty ?? false,
        recordsInserted: (importResult['learners_inserted'] ?? 0) +
            (importResult['assessments_inserted'] ?? 0),
        message:
            'Database import completed: ${importResult['learners_inserted'] ?? 0} learners, ${importResult['assessments_inserted'] ?? 0} assessments. Academic Year: $academicYear',
        importBatchId: importResult['import_batch_id'],
        errors: importResult['errors'] is List
            ? List<String>.from(importResult['errors'] as List)
            : null,
        // NEW: Enhanced sync info with validation status
        syncReady: importResult['errors']?.isEmpty ?? false,
        syncRecordCount: (importResult['learners_inserted'] ?? 0) +
            (importResult['assessments_inserted'] ?? 0),
        validationStatus: result.validationResult?.isValid ?? true,
        schoolNameMatch: result.validationResult?.matchedSchoolName ?? false,
        districtMatch: result.validationResult?.matchedDistrict ?? false,
        // NEW: Student tracking statistics
        studentTrackingStats: {
          'student_ids_created': importResult['student_ids_created'] ?? 0,
          'existing_students_matched':
              importResult['existing_students_matched'] ?? 0,
          'students_with_assessment_completeness': databaseReadyData
              .where(
                (student) =>
                    student['assessment_completeness'] != null &&
                    student['assessment_completeness'].toString().isNotEmpty,
              )
              .length,
          'emergency_transformation_used':
              databaseReadyData.length > result.data.length,
          // 🎯 NEW: Academic year info
          'academic_year_used': academicYear,
          'academic_year_source': result.reportMetadata?['school_year'] != null
              ? 'Excel File'
              : 'Fallback',
          'school_metadata_updated': true,
          // 🎯 NEW: Nutritional imputation info
          'nutritional_imputation_applied': imputationApplied,
          'nutritional_status_completion':
              result.metadata?['nutritional_status_analysis']
                      ?['completion_rate'] ??
                  0,
        },
        // 🎯 NEW: Academic year used
        academicYearUsed: academicYear,
      );
    } catch (e, stackTrace) {
      print('❌ ENHANCED DATABASE SAVE ERROR: $e');
      print(stackTrace);
      return DatabaseExportResult(
        success: false,
        recordsInserted: 0,
        message: 'Failed to save to database: $e',
        error: e.toString(),
        syncReady: false,
        validationStatus: false,
      );
    }
  }

  /// 🆕 NEW: Import with smart merging AND SCHOOL YEAR AWARENESS
  static Future<DatabaseExportResult> importWithSmartMerge(
    CleanResult result,
    String schoolId, {
    Map<String, dynamic>? importMetadata,
  }) async {
    try {
      print("🔄 STARTING SMART MERGE IMPORT WITH SCHOOL YEAR AWARENESS...");
      print("   Total records: ${result.data.length}");

      // 🎯 CRITICAL: Extract academic year from reportMetadata (Excel file)
      final academicYear = result.reportMetadata?['school_year']?.toString() ??
          importMetadata?['school_year']?.toString() ??
          '2024-2025';

      print(
        "   Academic year: $academicYear (From Excel: ${result.reportMetadata?['school_year'] != null ? 'YES' : 'NO'})",
      );

      // 🛠️ FIX: Pass ALL 4 parameters including academicYear
      final processedData = await CSVExporter.processStudentsWithTracking(
        result.data, // 1st param: students list
        schoolId, // 2nd param: schoolId
        result.validationResult, // 3rd param: validationResult
        academicYear, // 4th param: academicYear (FROM EXCEL)
      );

      if (processedData.isEmpty) {
        return DatabaseExportResult(
          success: false,
          recordsInserted: 0,
          message: 'No valid data to import after smart merging',
          syncReady: false,
          validationStatus: result.validationResult?.isValid ?? false,
        );
      }

      // Save to database using the enhanced method
      return await CSVExporter.saveToDatabase(
        result,
        schoolId,
        importMetadata: importMetadata,
      );
    } catch (e, st) {
      print('❌ Smart merge import failed: $e');
      print(st);
      return DatabaseExportResult(
        success: false,
        recordsInserted: 0,
        message: 'Smart merge import failed: $e',
        error: e.toString(),
        syncReady: false,
        validationStatus: false,
      );
    }
  }

  static Future<List<Map<String, dynamic>>> processStudentsWithTracking(
    List<Map<String, dynamic>> students,
    String schoolId,
    ValidationResult? validationResult,
    String? academicYear,
  ) async {
    // 🎯 ADD academicYear parameter

    final targetYear = academicYear ?? '2024-2025';
    final processedStudents = <Map<String, dynamic>>[];

    for (final student in students) {
      try {
        final studentWithId = await _ensureStudentId(student, schoolId);

        // 🎯 PASS academicYear to matching service
        final existingStudent =
            await StudentMatchingService.findExistingStudent(
          studentWithId,
          schoolId,
          DatabaseService.instance,
          targetYear,
        );

        if (existingStudent != null) {
          // 🎯 CHECK if we need NEW annual record
          if (StudentMatchingService.shouldCreateNewAnnualRecord(
            existingStudent,
            targetYear,
          )) {
            // DIFFERENT YEAR: Create NEW record with same student ID
            final newAnnualRecord = _createNewAnnualRecord(
              existingStudent,
              studentWithId,
              targetYear,
            );
            processedStudents.add(newAnnualRecord);
          } else {
            // SAME YEAR: Merge data
            final mergedStudent =
                StudentMatchingService.mergeStudentDataWithYearAwareness(
              existingStudent,
              studentWithId,
              targetYear,
            );

            if (mergedStudent.isNotEmpty) {
              processedStudents.add(mergedStudent);
            } else {
              // Should create new record for same year (different period)
              processedStudents.add(studentWithId);
            }
          }
        } else {
          // NEW STUDENT
          final databaseStudent = DataCompatibilityBridge.cleanResultToDatabase(
            studentWithId,
            schoolId,
          );
          databaseStudent['academic_year'] = targetYear; // 🎯 Set year
          processedStudents.add(databaseStudent);
        }
      } catch (e) {
        // Error handling
      }
    }

    return processedStudents;
  }

  /// 🆕 NEW: Create new annual record for existing student
  static Map<String, dynamic> _createNewAnnualRecord(
    Map<String, dynamic> existingStudent,
    Map<String, dynamic> newStudentData,
    String newAcademicYear,
  ) {
    // Start with existing student data
    final newRecord = Map<String, dynamic>.from(existingStudent);

    // 🎯 CRITICAL: Keep same student_id but NEW academic_year
    newRecord['academic_year'] = newAcademicYear;
    newRecord['id'] = '${existingStudent['student_id']}_$newAcademicYear';

    // Update with new measurements
    newRecord['weight'] = newStudentData['weight_kg'];
    newRecord['height'] = newStudentData['height_cm'];
    newRecord['bmi'] = newStudentData['bmi'];
    newRecord['nutritional_status'] = newStudentData['nutritional_status'];
    newRecord['period'] = newStudentData['period'];
    newRecord['assessment_date'] = newStudentData['assessment_date'];

    // Reset some fields for new year
    newRecord['created_at'] = DateTime.now().toIso8601String();
    newRecord['import_batch_id'] =
        'annual_${DateTime.now().millisecondsSinceEpoch}';

    return newRecord;
  }

  /// 🛠️ ENHANCED: Ensure consistent student ID assignment with SHORTER IDs
  static Future<Map<String, dynamic>> _ensureStudentId(
    Map<String, dynamic> student,
    String schoolId,
  ) async {
    final studentName = student['name']?.toString() ?? '';
    final existingStudentId = student['student_id']?.toString();

    String finalStudentId;

    // Check if existing ID is already in the new short format
    if (existingStudentId != null && existingStudentId.isNotEmpty) {
      if (existingStudentId.contains('_') &&
          existingStudentId.split('_')[0].length <= 4 &&
          existingStudentId.split('_')[1].length == 5) {
        finalStudentId = existingStudentId;
        if (kDebugMode) {
          debugPrint('✅ Using existing short student ID: $finalStudentId');
        }
      } else {
        // Convert old format to new short format
        final schoolAcronym = _extractSchoolAcronym(schoolId);
        finalStudentId =
            StudentIdentificationService.generateDeterministicStudentID(
          studentName,
          schoolAcronym,
        );
        if (kDebugMode) {
          debugPrint('🔄 Converted old ID to short format: $finalStudentId');
        }
      }
    } else {
      // Generate new short ID
      final schoolAcronym = _extractSchoolAcronym(schoolId);
      finalStudentId =
          StudentIdentificationService.generateDeterministicStudentID(
        studentName,
        schoolAcronym,
      );
      if (kDebugMode) {
        debugPrint('🆕 Generated new short student ID: $finalStudentId');
      }
    }

    return {
      ...student,
      'student_id': finalStudentId,
      'normalized_name': StudentIdentificationService.normalizeName(
        studentName,
      ),
    };
  }

  /// 🛠️ ENHANCED: Emergency transformation for when normal processing fails
  static List<Map<String, dynamic>> _applyEnhancedEmergencyTransformation(
    List<Map<String, dynamic>> students,
    String schoolId,
  ) {
    final transformed = <Map<String, dynamic>>[];
    int successCount = 0;
    int failureCount = 0;

    for (final student in students) {
      try {
        // 🛠️ ENHANCED FIX: Better transformation with enhanced validation
        final transformedStudent = _transformStudentForEnhancedEmergencyInsert(
          student,
          schoolId,
        );
        if (transformedStudent != null) {
          transformed.add(transformedStudent);
          successCount++;
        } else {
          failureCount++;
        }
      } catch (e) {
        failureCount++;
        print(
          '⚠️ Enhanced emergency transformation failed for student: ${student['name']} - $e',
        );
      }
    }

    print("🔄 ENHANCED EMERGENCY TRANSFORMATION RESULTS:");
    print("   Successfully transformed: $successCount");
    print("   Failed transformations: $failureCount");

    return transformed;
  }

  /// 🆕 FIXED: Transform student data for database with proper academic year
  static Map<String, dynamic>? _transformStudentForEnhancedEmergencyInsert(
    Map<String, dynamic> student,
    String schoolId,
  ) {
    try {
      final name = student['name']?.toString().trim() ?? '';
      if (name.isEmpty || name.length < 2) return null;

      // 🎯 CRITICAL: Extract academic year
      final academicYear = _extractAcademicYear(student);

      // 🛠️ ENHANCED: Generate SHORTER student ID
      final schoolAcronym = _extractSchoolAcronym(schoolId);
      final studentId = student['student_id']?.toString() ??
          StudentIdentificationService.generateDeterministicStudentID(
            name,
            schoolAcronym,
          );
      final normalizedName = student['normalized_name']?.toString() ??
          StudentIdentificationService.normalizeName(name);
      final period = student['period']?.toString() ?? 'Baseline';
      final gradeLevel = student['grade_level']?.toString() ?? 'Unknown';

      // Enhanced database record with better defaults
      return {
        'id':
            'enhanced_emergency_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}',
        'school_id': schoolId,
        'grade_level_id': _mapGradeToId(gradeLevel),
        'grade_name': gradeLevel,
        'learner_name': name,
        'sex': student['sex']?.toString() ?? 'Unknown',
        'date_of_birth': student['birth_date']?.toString(),
        'age': student['age'] ??
            DateUtilities.calculateAgeInYears(
              student['birth_date']?.toString(),
            ),
        'nutritional_status':
            student['nutritional_status']?.toString() ?? 'Unknown',
        'assessment_period': period,
        'assessment_date': student['assessment_date']?.toString() ??
            student['weighing_date']?.toString() ??
            DateTime.now().toIso8601String().split('T').first,
        'height': student['height_cm'] != null
            ? double.tryParse(student['height_cm'].toString())
            : null,
        'weight': student['weight_kg'] != null
            ? double.tryParse(student['weight_kg'].toString())
            : null,
        'bmi': student['bmi'] != null
            ? double.tryParse(student['bmi'].toString())
            : null,
        'lrn': student['lrn']?.toString(),
        'section': student['section']?.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'import_batch_id':
            'enhanced_emergency_batch_${DateTime.now().millisecondsSinceEpoch}',
        'cloud_sync_id': '',
        'last_synced': '',
        // 🎯 CRITICAL: Set academic_year
        'academic_year': academicYear,
        // 🛠️ ENHANCED: Student tracking fields with SHORTER IDs
        'student_id': studentId,
        'normalized_name': normalizedName,
        'assessment_completeness':
            student['assessment_completeness']?.toString() ??
                AssessmentCompletenessTracker.determineIndividualCompleteness(
                  student,
                ),
        'period': period,
      };
    } catch (e) {
      print('❌ Enhanced emergency transformation error: $e');
      return null;
    }
  }

  /// 🆕 Helper: Extract academic year from student data
  static String _extractAcademicYear(Map<String, dynamic> student) {
    // Try multiple possible fields
    final possibleFields = [
      'academic_year',
      'school_year',
      'assessment_year',
      'year',
      'sy',
    ];

    for (final field in possibleFields) {
      final value = student[field]?.toString();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        final year = AcademicYearManager.parseAcademicYear(value);
        if (year.isNotEmpty) {
          // Check if year string is not empty
          return year; // Just return the string, not year.first
        }
      }
    }

    // Try to extract from date fields
    final dateFields = ['assessment_date', 'weighing_date', 'created_at'];
    for (final field in dateFields) {
      final dateStr = student[field]?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          return AcademicYearManager.detectSchoolYearFromDate(date);
        }
      }
    }

    // Default to current school year
    return AcademicYearManager.getCurrentSchoolYear();
  }

  /// 🆕 NEW: Extract school acronym for shorter student IDs
  static String _extractSchoolAcronym(String schoolId) {
    if (schoolId.isEmpty) return 'SCH';

    // Try to extract from patterns like "schoolName_district"
    final parts = schoolId.split('_');
    if (parts.isNotEmpty) {
      final schoolName = parts[0];
      final words = schoolName.split(' ');

      if (words.length > 1) {
        // Multi-word school name
        final acronym = words.map((word) {
          if (word.isNotEmpty) {
            return word[0].toUpperCase();
          }
          return '';
        }).join('');

        if (acronym.length >= 3) {
          return acronym.length <= 4 ? acronym : acronym.substring(0, 4);
        }
      } else if (schoolName.length >= 3) {
        // Single word school name
        return schoolName.substring(0, min(4, schoolName.length)).toUpperCase();
      }
    }

    return 'SCH';
  }

  static int _mapGradeToId(String grade) {
    final gradeMap = {
      'Kinder': 0,
      'K': 0,
      'Grade 1': 1,
      '1': 1,
      'G1': 1,
      'Grade 2': 2,
      '2': 2,
      'G2': 2,
      'Grade 3': 3,
      '3': 3,
      'G3': 3,
      'Grade 4': 4,
      '4': 4,
      'G4': 4,
      'Grade 5': 5,
      '5': 5,
      'G5': 5,
      'Grade 6': 6,
      '6': 6,
      'G6': 6,
      'SPED': 7,
    };
    return gradeMap[grade] ?? 0;
  }

  /// 🛠️ ENHANCED: Get missing required fields for debugging
  static List<String> _getMissingRequiredFields(Map<String, dynamic> student) {
    final requiredFields = [
      'name',
      'student_id',
      'normalized_name',
      'assessment_completeness',
      'period',
      'grade_level',
    ];

    return requiredFields.where((field) {
      final value = student[field];
      return value == null || value.toString().trim().isEmpty;
    }).toList();
  }

  /// 🛠️ ENHANCED: Debug import pipeline at each stage
  static void _debugImportPipeline(Map<String, dynamic> student, String stage) {
    if (!kDebugMode) return;

    final period = student['period']?.toString() ?? 'Unknown';
    final studentId = student['student_id']?.toString() ?? 'No ID';

    debugPrint('🔍 ENHANCED IMPORT PIPELINE - $stage');
    debugPrint('   Period: $period');
    debugPrint('   Student ID: $studentId');
    debugPrint('   Name: ${student['name'] ?? student['learner_name']}');
    debugPrint('   Weight: ${student['weight_kg'] ?? student['weight']}');
    debugPrint('   Height: ${student['height_cm'] ?? student['height']}');

    if (period == 'Endline') {
      debugPrint('🚨 IMPORTANT: This is an ENDLINE record at stage: $stage');
    }
    debugPrint('   ---');
  }

  /// ENHANCED: Find existing student ID using fuzzy matching
  static Future<String> _findExistingStudentId(
    String studentName,
    String schoolId,
  ) async {
    try {
      // Use database service to find similar students
      final similarStudents = await _dbService.findStudentsByNameSimilarity(
        studentName,
        schoolId,
      );

      if (similarStudents.isNotEmpty) {
        final bestMatch = similarStudents.first;
        final existingName = bestMatch['learner_name']?.toString() ?? '';

        // Check if names are similar enough
        if (StudentNameMatcher.isLikelySameStudent(studentName, existingName)) {
          return bestMatch['student_id']?.toString() ?? '';
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error finding existing student ID: $e');
      }
    }

    return '';
  }

  /// 🛑 ENHANCED: Critical Grade Level Validation
  static Future<GradeLevelValidationResult> _validateGradeLevels(
    List<Map<String, dynamic>> students,
    String schoolId,
  ) async {
    try {
      if (students.isEmpty) {
        return GradeLevelValidationResult(
          success: true,
          message: 'No students to validate',
        );
      }

      // Extract all unique grade level IDs from students
      final requiredGradeIds = students
          .map((student) => student['grade_level_id'] as int? ?? 0)
          .where((id) => id != null)
          .toSet();

      if (kDebugMode) {
        debugPrint(
          '🔍 ENHANCED GRADE LEVEL VALIDATION: Checking IDs $requiredGradeIds',
        );
      }

      // Check which grade level IDs exist in database
      final existingIds = await _dbService.getExistingGradeLevelIds(
        requiredGradeIds,
      );

      // Common grade level mappings for auto-fix
      final commonGradeMappings = {
        0: 'Kinder',
        1: 'Grade 1',
        2: 'Grade 2',
        3: 'Grade 3',
        4: 'Grade 4',
        5: 'Grade 5',
        6: 'Grade 6',
        7: 'SPED',
      };

      final missingIds =
          requiredGradeIds.where((id) => !existingIds.contains(id)).toList();

      // 🛠️ ENHANCED AUTO-FIX: Try to create missing grade levels for common cases
      if (missingIds.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ Missing grade level IDs detected: $missingIds');
          debugPrint(
            '🛠️ Attempting enhanced auto-fix for common grade levels...',
          );
        }

        final autoFixedIds = <int>[];
        for (final missingId in missingIds) {
          if (commonGradeMappings.containsKey(missingId)) {
            final success = await _dbService.ensureGradeLevelExists(
              missingId,
              commonGradeMappings[missingId]!,
            );
            if (success) {
              autoFixedIds.add(missingId);
              if (kDebugMode) {
                debugPrint(
                  '✅ Auto-created missing grade level: $missingId (${commonGradeMappings[missingId]})',
                );
              }
            }
          }
        }

        // Re-check after auto-fix attempt
        final updatedExistingIds = await _dbService.getExistingGradeLevelIds(
          requiredGradeIds,
        );
        final stillMissingIds = requiredGradeIds
            .where((id) => !updatedExistingIds.contains(id))
            .toList();

        if (stillMissingIds.isNotEmpty) {
          return GradeLevelValidationResult(
            success: false,
            message: 'CRITICAL: Missing Grade Level IDs: $stillMissingIds. '
                'Cannot proceed with import. Please configure grade levels in the application.',
            missingIds: stillMissingIds,
            autoFixedIds: autoFixedIds.isNotEmpty ? autoFixedIds : null,
          );
        } else {
          return GradeLevelValidationResult(
            success: true,
            message:
                'Enhanced auto-fixed missing grade levels. All IDs now valid.',
            autoFixedIds: autoFixedIds.isNotEmpty ? autoFixedIds : null,
          );
        }
      }

      // All grade levels are valid
      return GradeLevelValidationResult(
        success: true,
        message: 'All grade level IDs validated successfully',
        existingIds: existingIds,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Enhanced grade level validation error: $e');
      }
      return GradeLevelValidationResult(
        success: false,
        message: 'Enhanced grade level validation failed: $e',
      );
    }
  }

  /// 🎯 NEW MAIN IMPORT METHOD: Unified import with enhanced pipeline
  static Future<DatabaseExportResult> importExcelFile(
    String filePath,
    String schoolId,
    SchoolProfile schoolProfile, {
    bool strictValidation = false,
    Map<String, dynamic>? importMetadata,
  }) async {
    return await CSVDataFlowManager.processExcelFileThroughPipeline(
      filePath,
      schoolId,
      schoolProfile,
      strictValidation: strictValidation,
      importMetadata: importMetadata,
    );
  }

  /// 🆕 NEW: Enhanced method to handle StudentAssessment objects directly
  static Future<DatabaseExportResult> saveStudentAssessmentsToDatabase(
    List<StudentAssessment> studentAssessments,
    String schoolId, {
    Map<String, dynamic>? importMetadata,
    ValidationResult? validationResult,
  }) async {
    try {
      // Convert StudentAssessment to CleanResult format
      final cleanResult = DataPipelineBridge.studentAssessmentsToCleanResult(
        studentAssessments,
        validationResult: validationResult,
        metadata: importMetadata,
      );

      // Use the existing saveToDatabase method
      return await saveToDatabase(
        cleanResult,
        schoolId,
        importMetadata: importMetadata,
      );
    } catch (e) {
      return DatabaseExportResult(
        success: false,
        recordsInserted: 0,
        message: 'Failed to save StudentAssessment objects: $e',
        error: e.toString(),
        syncReady: false,
        validationStatus: false,
      );
    }
  }

  /// ENHANCED: Unified import method that handles both CleanResult and StudentAssessment lists with validation
  static Future<DatabaseExportResult> importData(
    dynamic data, // Can be CleanResult or List<StudentAssessment>
    String schoolId, {
    Map<String, dynamic>? importMetadata,
    ValidationResult? validationResult,
  }) async {
    if (data is CleanResult) {
      return await saveToDatabase(
        data,
        schoolId,
        importMetadata: importMetadata,
      );
    } else if (data is List<StudentAssessment>) {
      return await saveStudentAssessmentsToDatabase(
        data,
        schoolId,
        importMetadata: importMetadata,
        validationResult: validationResult,
      );
    } else {
      throw ArgumentError(
        'Data must be either CleanResult or List<StudentAssessment>',
      );
    }
  }

  // ========== EXISTING METHODS (REST OF THE CODE REMAINS THE SAME) ==========
  // ... [Rest of the existing methods remain unchanged - they already work with CleanResult]

  /// ENHANCED: Get student progress across years
  static Future<List<Map<String, dynamic>>> getStudentProgress(
    String studentId,
  ) async {
    try {
      return await _dbService.getStudentProgressAcrossYears(studentId);
    } catch (e) {
      debugPrint('❌ Enhanced error getting student progress: $e');
      return [];
    }
  }

  /// ENHANCED: Get assessment completeness for school
  static Future<List<Map<String, dynamic>>> getAssessmentCompleteness(
    String schoolId,
    String academicYear,
  ) async {
    try {
      return await _dbService.getAssessmentCompleteness(schoolId, academicYear);
    } catch (e) {
      debugPrint('❌ Enhanced error getting assessment completeness: $e');
      return [];
    }
  }

  /// ENHANCED: Find students by name similarity
  static Future<List<Map<String, dynamic>>> findStudentsByNameSimilarity(
    String name,
    String schoolId,
  ) async {
    try {
      return await _dbService.findStudentsByNameSimilarity(name, schoolId);
    } catch (e) {
      debugPrint('❌ Enhanced error finding students by name similarity: $e');
      return [];
    }
  }

  /// ENHANCED: Get student progress timeline for charts
  static Future<List<Map<String, dynamic>>> getStudentProgressTimeline(
    String studentId,
  ) async {
    try {
      return await _dbService.getStudentProgressTimeline(studentId);
    } catch (e) {
      debugPrint('❌ Enhanced error getting student progress timeline: $e');
      return [];
    }
  }

  /// ENHANCED: Export student progress data for external analysis
  static Future<String> exportStudentProgressData(String studentId) async {
    try {
      final progressData = await getStudentProgressTimeline(studentId);

      final exportData = {
        'student_id': studentId,
        'export_timestamp': DateTime.now().toIso8601String(),
        'progress_data': progressData,
        'chart_data': _prepareChartData(progressData),
        'summary': _generateProgressSummary(progressData),
      };

      return jsonEncode(exportData);
    } catch (e) {
      return jsonEncode({
        'error': 'Enhanced: Failed to export progress data: $e',
        'student_id': studentId,
      });
    }
  }

  /// ENHANCED: Prepare chart data from progress timeline
  static Map<String, dynamic> _prepareChartData(
    List<Map<String, dynamic>> progressData,
  ) {
    final bmiData = <Map<String, dynamic>>[];
    final statusData = <Map<String, dynamic>>[];

    for (final record in progressData) {
      bmiData.add({
        'academic_year': record['academic_year'],
        'grade_level': record['grade_name'],
        'baseline_bmi': record['baseline_bmi'],
        'endline_bmi': record['endline_bmi'],
      });

      statusData.add({
        'academic_year': record['academic_year'],
        'grade_level': record['grade_name'],
        'baseline_status': record['baseline_status'],
        'endline_status': record['endline_status'],
      });
    }

    return {'bmi_data': bmiData, 'status_data': statusData};
  }

  /// 🎯 ENHANCED COMPLETE FIX SCRIPT: Run this to clean and fix everything
  static Future<void> executeCompleteFixScript(String schoolId) async {
    try {
      debugPrint('🎯 === EXECUTING ENHANCED COMPLETE FIX SCRIPT ===');

      // Step 1: Remove test data
      debugPrint('1️⃣ REMOVING TEST DATA...');
      await DatabaseService.instance.removeAllTestData();

      // Step 2: Diagnostic before fixes
      debugPrint('2️⃣ RUNNING ENHANCED DIAGNOSTIC...');
      await DatabaseService.instance.debugEndlineRecords();

      // Step 3: Fix Endline student IDs
      debugPrint('3️⃣ FIXING ENDLINE STUDENT IDs...');
      await DatabaseService.instance.fixEndlineStudentIds();

      // Step 4: Enhanced database verification
      debugPrint('4️⃣ RUNNING ENHANCED DATABASE VERIFICATION...');
      await DatabaseService.instance.debugDatabaseCounts();

      // Step 5: Diagnostic after fixes
      debugPrint('5️⃣ RUNNING FINAL ENHANCED DIAGNOSTIC...');
      await DatabaseService.instance.debugEndlineRecords();

      debugPrint('🎉 === ENHANCED COMPLETE FIX SCRIPT FINISHED ===');
    } catch (e) {
      debugPrint('❌ Enhanced error in fix script: $e');
      rethrow;
    }
  }

  /// 🎯 ENHANCED: Fix hardcoded year in generateQuickStatsPackage
  static Future<Map<String, dynamic>> generateQuickStatsPackage(
    String schoolId,
  ) async {
    final stats = await DatabaseService.instance.getSchoolStatistics(schoolId);

    // 🎯 CRITICAL FIX: Replace hardcoded year '2024-2025' with dynamic value
    final String currentAcademicYear =
        AcademicYearManager.getCurrentSchoolYear();

    return {
      'package_id': 'enhanced_quick_${DateTime.now().millisecondsSinceEpoch}',
      'school_id': schoolId,
      'type': 'enhanced_quick_stats',
      'generated_at': DateTime.now().toIso8601String(),
      'statistics': stats,
      'academic_year': currentAcademicYear, // <-- USE DYNAMIC YEAR
    };
  }

  /// ENHANCED: Generate progress summary
  static Map<String, dynamic> _generateProgressSummary(
    List<Map<String, dynamic>> progressData,
  ) {
    final yearsWithData = progressData
        .where((p) => p['baseline_bmi'] != null || p['endline_bmi'] != null)
        .length;

    final yearsWithBothAssessments = progressData
        .where((p) => p['baseline_bmi'] != null && p['endline_bmi'] != null)
        .length;

    return {
      'total_years_tracked': progressData.length,
      'years_with_data': yearsWithData,
      'years_with_complete_assessments': yearsWithBothAssessments,
      'completeness_percentage': progressData.isNotEmpty
          ? (yearsWithData / progressData.length * 100).round()
          : 0,
    };
  }

  /// ENHANCED: Critical verification for nutritional status data loss
  static void _verifyNutritionalStatusData(CleanResult result) {
    if (result.data.isEmpty) return;

    final studentsWithUnknownStatus = result.data.where((student) {
      final status = student['nutritional_status']?.toString();
      return status == null || status.isEmpty || status == 'Unknown';
    }).toList();

    final unknownCount = studentsWithUnknownStatus.length;
    final totalCount = result.data.length;
    final unknownPercentage =
        totalCount > 0 ? (unknownCount / totalCount * 100).round() : 0;

    if (unknownCount > 0) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ ENHANCED CRITICAL WARNING: NUTRITIONAL STATUS DATA LOSS DETECTED',
        );
        debugPrint('   Total students: $totalCount');
        debugPrint(
          '   Students with "Unknown" status: $unknownCount ($unknownPercentage%)',
        );
        debugPrint(
          '   This indicates potential data loss in the cleaning pipeline',
        );

        // Log sample of affected students for debugging
        if (studentsWithUnknownStatus.isNotEmpty) {
          final sampleSize = min(studentsWithUnknownStatus.length, 3);
          debugPrint('   Sample affected students:');
          for (int i = 0; i < sampleSize; i++) {
            final student = studentsWithUnknownStatus[i];
            debugPrint(
              '     - ${student['name']}: BMI=${student['bmi']}, Status=${student['nutritional_status']}',
            );
          }
        }
      }

      // Enhanced critical assertion to track data quality issues
      assert(
        unknownPercentage < 50, // Allow up to 50% unknown as warning threshold
        'High rate of unknown nutritional status ($unknownPercentage%). Check cleaning pipeline.',
      );
    } else {
      if (kDebugMode) {
        debugPrint('✅ All students have nutritional status data');
      }
    }
  }

  // ========== PRIVATE HELPER METHODS ==========

  /// ENHANCED: Enhanced validation extraction
  static String _extractEnhancedValidation(CleanResult result) {
    final validation = {
      'total_records': result.data.length,
      'has_valid_data': result.data.isNotEmpty,
      'problem_count': result.problems.length,
      'ready_for_sync': result.success && result.data.isNotEmpty,
      'validation_timestamp': DateTime.now().toIso8601String(),
      // NEW: Include school validation results
      'school_validation_passed': result.validationResult?.isValid ?? false,
      'school_name_match': result.validationResult?.matchedSchoolName ?? false,
      'district_match': result.validationResult?.matchedDistrict ?? false,
      'validation_errors': result.validationResult?.errors ?? [],
      'validation_warnings': result.validationResult?.warnings ?? [],
      // NEW: Student tracking info
      'student_tracking_enabled': true,
      'students_with_ids':
          result.data.where((student) => student['student_id'] != null).length,
      'students_with_completeness': result.data
          .where(
            (student) =>
                student['assessment_completeness'] != null &&
                student['assessment_completeness'].toString().isNotEmpty,
          )
          .length,
      // 🛠️ ENHANCED: Pipeline diagnostics
      'pipeline_diagnostics': {
        'main_pipeline_success': result.success,
        'data_count': result.data.length,
        'problems_count': result.problems.length,
        'emergency_pipeline_available': true,
        'pipeline_version': 'enhanced_robust_v3',
        'school_year_used':
            result.reportMetadata?['school_year'] ?? 'Not Found',
      },
    };

    return jsonEncode(validation);
  }

  /// ENHANCED: Prepare imported data for sync using ImportMetadata model with validation info
  static Future<void> _prepareForSyncEnhanced(
    String schoolId,
    String importBatchId,
    List<dynamic> data,
    ValidationResult? validationResult,
  ) async {
    try {
      // Get the newly imported students
      final newStudents = await _dbService.getLearnersBySchool(schoolId);

      // Mark them as needing sync (clear cloud_sync_id)
      for (final student in newStudents) {
        if (student['import_batch_id'] == importBatchId) {
          await _dbService.updateLearner({
            ...student,
            'cloud_sync_id': '', // Empty means needs sync
            'last_synced': '', // Never synced
          });
        }
      }

      // ENHANCED: Create ImportMetadata with validation info
      final importMetadata = ImportMetadata(
        id: 'enhanced_import_${DateTime.now().millisecondsSinceEpoch}',
        schoolId: schoolId,
        importBatchId: importBatchId,
        fileHash: _generateSimpleHash(data),
        validationResult: {
          'status': 'ready_for_sync',
          'success': true,
          'records_count': data.length,
          'school_profile_match': validationResult?.isValid ?? false,
          'school_name_match': validationResult?.matchedSchoolName ?? false,
          'district_match': validationResult?.matchedDistrict ?? false,
          'validation_timestamp': DateTime.now().toIso8601String(),
          'validation_errors': validationResult?.errors ?? [],
          'validation_warnings': validationResult?.warnings ?? [],
          // NEW: Student tracking info
          'student_tracking_enabled': true,
          'students_with_ids': data
              .where(
                (student) =>
                    student['student_id'] != null &&
                    student['student_id'].toString().isNotEmpty,
              )
              .length,
          'students_with_completeness': data
              .where(
                (student) =>
                    student['assessment_completeness'] != null &&
                    student['assessment_completeness'].toString().isNotEmpty,
              )
              .length,
          // 🛠️ NEW: Emergency pipeline info
          'emergency_pipeline_used': data.any(
            (student) =>
                student['id']?.toString().contains('emergency') ?? false,
          ),
          // 🎯 NEW: School year info
          'school_year_used': data.isNotEmpty
              ? data.first['academic_year']?.toString()
              : 'Unknown',
        },
        cloudSynced: false,
        syncTimestamp: null, // Correct: null for never synced
        createdAt: DateTime.now(),
      );

      // Use the helper method to check if ready for sync
      if (importMetadata.readyForCloudSync) {
        await _dbService.insertImportMetadata(importMetadata.toMap());

        if (kDebugMode) {
          debugPrint('✅ Enhanced data prepared for sync: $importBatchId');
          debugPrint(
            '📊 Enhanced ImportMetadata created: ${importMetadata.id}',
          );
          debugPrint(
            '🔄 Ready for cloud sync: ${importMetadata.readyForCloudSync}',
          );
          debugPrint(
            '🏫 Enhanced validation status: ${validationResult?.isValid ?? 'N/A'}',
          );
          debugPrint('🎯 Enhanced student tracking: ENABLED');
          debugPrint(
            '📈 Students with IDs: ${importMetadata.validationResult['students_with_ids'] ?? 0}',
          );
          debugPrint(
            '📚 School Year Used: ${importMetadata.validationResult['school_year_used'] ?? 'Unknown'}',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Enhanced ImportMetadata not ready for sync: ${importMetadata.validationResult}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Enhanced sync preparation failed: $e');
      }
      // Don't throw - sync prep shouldn't block import
    }
  }

  /// ENHANCED: Simple hash for basic duplicate detection
  static String _generateSimpleHash(List<dynamic> data) {
    if (data.isEmpty) return 'empty';

    // Enhanced hash based on record count and first few names
    final sampleData = data.take(3).map((item) {
      if (item is Map) {
        return item['name']?.toString() ??
            item['learner_name']?.toString() ??
            '';
      }
      return item.toString();
    }).join('');

    final hash = 'enhanced_${data.length}_${sampleData.hashCode}';
    return hash;
  }
}

// ========== ENHANCED SUPPORTING CLASSES ==========

/// ENHANCED: Grade Level Validation Result
class GradeLevelValidationResult {
  final bool success;
  final String message;
  final List<int>? missingIds;
  final List<int>? autoFixedIds;
  final Set<int>? existingIds;

  GradeLevelValidationResult({
    required this.success,
    required this.message,
    this.missingIds,
    this.autoFixedIds,
    this.existingIds,
  });

  @override
  String toString() {
    return 'EnhancedGradeLevelValidationResult(success: $success, message: $message, missingIds: $missingIds, autoFixedIds: $autoFixedIds)';
  }
}

// ========== ENHANCED DATA COMPATIBILITY BRIDGE WITH STUDENT TRACKING ==========

/// 🛠️ ENHANCED FIX: Enhanced data transformation with period preservation
class DataCompatibilityBridge {
  /// 🛠️ ENHANCED: Transform CleanResult data to database-compatible format WITH PROPER PERIOD MAPPING
  static Map<String, dynamic> cleanResultToDatabase(
    Map<String, dynamic> cleanData,
    String schoolId,
  ) {
    final batchId = 'enhanced_batch_${DateTime.now().millisecondsSinceEpoch}';

    // 🚨 ENHANCED FIX: Extract period BEFORE any transformation and ensure it's preserved
    final period = cleanData['period']?.toString() ?? 'Baseline';

    // 🚨 ENHANCED FIX: Debug the incoming data
    if (kDebugMode) {
      debugPrint('🔄 ENHANCED DATA TRANSFORMATION - INCOMING DATA:');
      debugPrint('   Period: $period');
      debugPrint('   Name: ${cleanData['name']}');
      debugPrint('   Weight: ${cleanData['weight_kg']}');
      debugPrint('   Height: ${cleanData['height_cm']}');
      debugPrint('   All keys: ${cleanData.keys}');
    }

    // ENHANCED FIX: Extract nutritional status as-is without transformation
    final nutritionalStatus =
        cleanData['nutritional_status']?.toString() ?? 'Unknown';

    // ENHANCED: Generate SHORTER student ID and normalized name for tracking
    final studentName = cleanData['name']?.toString() ?? '';
    final schoolAcronym = _extractSchoolAcronym(schoolId);
    final studentId = cleanData['student_id']?.toString() ??
        StudentIdentificationService.generateDeterministicStudentID(
          studentName,
          schoolAcronym,
        );
    final normalizedName = cleanData['normalized_name']?.toString() ??
        StudentIdentificationService.normalizeName(studentName);

    // ENHANCED: Assessment completeness
    final assessmentCompleteness =
        cleanData['assessment_completeness']?.toString() ??
            AssessmentCompletenessTracker.determineIndividualCompleteness(
              cleanData,
            );

    // 🛠️ ENHANCED FIX: Use the assessment_date from cleanData, don't override with current time
    final assessmentDate = cleanData['assessment_date']?.toString() ??
        cleanData['weighing_date']?.toString() ??
        DateTime.now().toIso8601String();

    // 🎯 CRITICAL: Extract academic year - prioritize from cleanData
    final academicYear = cleanData['academic_year']?.toString() ??
        cleanData['school_year']?.toString() ??
        AcademicYearManager.getCurrentSchoolYear();

    // 🚨 ENHANCED FIX: Build the database record with EXPLICIT period field
    final databaseRecord = {
      'id':
          'enhanced_import_${DateTime.now().millisecondsSinceEpoch}_${cleanData['name']}',
      'school_id': schoolId,
      'grade_level_id': _mapGradeToId(cleanData['grade_level']),
      'grade_name': cleanData['grade_level']?.toString() ?? 'Unknown',
      'learner_name': studentName,
      'sex': cleanData['sex']?.toString() ?? 'Unknown',
      'date_of_birth': cleanData['birth_date']?.toString(),
      'age': DateUtilities.calculateAgeInYears(
        cleanData['birth_date']?.toString(),
      ),
      'nutritional_status': nutritionalStatus,
      'assessment_period': period, // For backward compatibility
      'assessment_date': assessmentDate,
      'height': cleanData['height_cm'] != null
          ? double.tryParse(cleanData['height_cm'].toString())
          : null,
      'weight': cleanData['weight_kg'] != null
          ? double.tryParse(cleanData['weight_kg'].toString())
          : null,
      'bmi': cleanData['bmi'] != null
          ? double.tryParse(cleanData['bmi'].toString())
          : null,
      'lrn': cleanData['lrn']?.toString(),
      'section': cleanData['section']?.toString(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'import_batch_id': batchId,
      'cloud_sync_id': '',
      'last_synced': '',
      // 🎯 CRITICAL: Use extracted academic year
      'academic_year': academicYear,
      // 🚨 ENHANCED FIX: Student tracking fields with proper period and SHORTER ID
      'student_id': studentId,
      'normalized_name': normalizedName,
      'assessment_completeness': assessmentCompleteness,
      'period': period, // 🛠️ ENHANCED: This must be set explicitly
    };

    if (kDebugMode && period == 'Endline') {
      debugPrint('🎯 ENHANCED ENDLINE RECORD TRANSFORMED:');
      debugPrint(
        '   Final period in database record: ${databaseRecord['period']}',
      );
      debugPrint('   Student: $studentName');
      debugPrint('   Student ID: $studentId');
      debugPrint('   Academic Year: $academicYear');
    }

    return databaseRecord;
  }

  /// 🆕 NEW: Extract school acronym for shorter student IDs
  static String _extractSchoolAcronym(String schoolId) {
    if (schoolId.isEmpty) return 'SCH';

    // Try to extract from patterns like "schoolName_district"
    final parts = schoolId.split('_');
    if (parts.isNotEmpty) {
      final schoolName = parts[0];
      final words = schoolName.split(' ');

      if (words.length > 1) {
        // Multi-word school name
        final acronym = words.map((word) {
          if (word.isNotEmpty) {
            return word[0].toUpperCase();
          }
          return '';
        }).join('');

        if (acronym.length >= 3) {
          return acronym.length <= 4 ? acronym : acronym.substring(0, 4);
        }
      } else if (schoolName.length >= 3) {
        // Single word school name
        return schoolName.substring(0, min(4, schoolName.length)).toUpperCase();
      }
    }

    return 'SCH';
  }

  static int _mapGradeToId(dynamic grade) {
    if (grade == null) return 0;
    final gradeString = grade.toString();
    final gradeMap = {
      'Kinder': 0,
      'K': 0,
      'Grade 1': 1,
      '1': 1,
      'Grade 2': 2,
      '2': 2,
      'Grade 3': 3,
      '3': 3,
      'Grade 4': 4,
      '4': 4,
      'Grade 5': 5,
      '5': 5,
      'Grade 6': 6,
      '6': 6,
      'SPED': 7,
    };
    return gradeMap[gradeString] ?? 0;
  }
}

// ========== ENHANCED SUPPORTING CLASSES WITH STUDENT TRACKING ==========

/// Enhanced database export result with validation info AND STUDENT TRACKING
/// Enhanced database export result with validation info AND STUDENT TRACKING
class DatabaseExportResult {
  final bool success;
  final int recordsInserted;
  final String message;
  final String? error;
  final String? importBatchId;
  final List<String>? errors;

  // NEW: Enhanced sync and validation information
  final bool syncReady;
  final int syncRecordCount;
  final bool? validationStatus;
  final bool? schoolNameMatch;
  final bool? districtMatch;

  // NEW: Student tracking statistics
  final Map<String, dynamic>? studentTrackingStats;

  // 🎯 NEW: Academic year used in import
  final String? academicYearUsed;

  // 🛠️ NEW: Alias for consistency
  int get recordsProcessed => recordsInserted;

  DatabaseExportResult({
    required this.success,
    required this.recordsInserted,
    required this.message,
    this.error,
    this.importBatchId,
    this.errors,
    // NEW: Enhanced sync and validation fields
    this.syncReady = false,
    this.syncRecordCount = 0,
    this.validationStatus,
    this.schoolNameMatch,
    this.districtMatch,
    // NEW: Student tracking statistics
    this.studentTrackingStats,
    // 🎯 NEW: Academic year used
    this.academicYearUsed,
  });

  @override
  String toString() {
    return 'EnhancedDatabaseExportResult: $recordsInserted records, syncReady: $syncReady, validation: $validationStatus, academicYear: $academicYearUsed, studentTracking: ${studentTrackingStats != null}';
  }

  // NEW: Helper to check if import was fully validated
  bool get wasValidated => validationStatus ?? false;

  // NEW: Helper to check if school profile matched
  bool get schoolProfileMatched =>
      (schoolNameMatch ?? false) && (districtMatch ?? false);

  // NEW: Helper to check if student tracking was enabled
  bool get studentTrackingEnabled => studentTrackingStats != null;

  // NEW: Get student IDs created count
  int get studentIDsCreated =>
      studentTrackingStats?['student_ids_created'] ?? 0;

  // NEW: Get existing students matched count
  int get existingStudentsMatched =>
      studentTrackingStats?['existing_students_matched'] ?? 0;

  // NEW: Get students with assessment completeness count
  int get studentsWithCompleteness =>
      studentTrackingStats?['students_with_assessment_completeness'] ?? 0;

  // 🎯 NEW: Check if nutritional imputation was applied
  bool get nutritionalImputationApplied =>
      studentTrackingStats?['nutritional_imputation_applied'] == true;
}

class ImportResult {
  bool success;
  String message;
  int recordsProcessed;
  List<String>? errors;

  // NEW: Receiving-specific fields
  String? receivedFrom;
  String?
      dataType; // 'school_profile', 'students', 'assessments', 'full_package'
  Map<String, int>? breakdown; // {students: 50, assessments: 100}
  DateTime? receivedAt;

  // NEW: Validation information
  bool? validationStatus;
  bool? schoolNameMatch;
  bool? districtMatch;

  // NEW: Student tracking information
  bool? studentTrackingEnabled;
  Map<String, dynamic>? studentTrackingStats;

  // 🛠️ NEW: Cloud sync fields
  bool readyForCloudSync;
  String importBatchId;
  DateTime importTimestamp;
  Map<String, dynamic> validationSummary;

  // 🛠️ NEW: For compatibility with DatabaseExportResult
  int get recordsInserted => recordsProcessed; // Alias for compatibility

  ImportResult({
    required this.success,
    required this.message,
    required this.recordsProcessed,
    this.errors,
    this.receivedFrom,
    this.dataType, // 🛠️ Can be null
    this.breakdown,
    DateTime? receivedAt,
    this.validationStatus,
    this.schoolNameMatch,
    this.districtMatch,
    // NEW: Student tracking fields
    this.studentTrackingEnabled,
    this.studentTrackingStats,
    // 🛠️ NEW: Cloud sync fields with defaults
    this.readyForCloudSync = false,
    this.importBatchId = '',
    DateTime? importTimestamp,
    this.validationSummary = const {},
    required int totalRecords,
    required String batchId,
  })  : receivedAt = receivedAt ?? DateTime.now(),
        importTimestamp = importTimestamp ?? DateTime.now();

  @override
  String toString() {
    return 'ImportResult(from: $receivedFrom, type: $dataType, records: $recordsProcessed, success: $success, validated: $validationStatus, studentTracking: $studentTrackingEnabled)';
  }

  // Helper for receiving operations - provides default for dataType
  factory ImportResult.fromReceiving({
    required bool success,
    required String message,
    required int recordsProcessed,
    String? receivedFrom,
    String? dataType,
    Map<String, int>? breakdown,
    List<String>? errors,
    bool? validationStatus,
    bool? schoolNameMatch,
    bool? districtMatch,
    // NEW: Student tracking parameters
    bool? studentTrackingEnabled,
    Map<String, dynamic>? studentTrackingStats,
  }) {
    return ImportResult(
      success: success,
      message: message,
      recordsProcessed: recordsProcessed,
      errors: errors,
      receivedFrom: receivedFrom,
      dataType: dataType, // Can be null
      breakdown: breakdown,
      validationStatus: validationStatus,
      schoolNameMatch: schoolNameMatch,
      districtMatch: districtMatch,
      // NEW: Student tracking fields
      studentTrackingEnabled: studentTrackingEnabled,
      studentTrackingStats: studentTrackingStats,
      totalRecords: 0,
      batchId: '',
    );
  }
  bool get hasStudentTracking => studentTrackingEnabled == true;

  int get studentIDsCreated =>
      studentTrackingStats?['student_ids_created'] ?? 0;

  int get existingStudentsMatched =>
      studentTrackingStats?['existing_students_matched'] ?? 0;
}

/// 🆕 ENHANCED: Student Matching and Merging Service WITH SCHOOL YEAR AWARENESS
class StudentMatchingService {
  /// Find existing student by multiple criteria WITH SCHOOL YEAR CHECK
  static Future<Map<String, dynamic>?> findExistingStudent(
    Map<String, dynamic> newStudent,
    String schoolId,
    DatabaseService dbService,
    String? academicYear,
  ) async {
    try {
      final studentName = newStudent['name']?.toString().trim() ?? '';
      final normalizedName = newStudent['normalized_name']?.toString().trim() ??
          StudentIdentificationService.normalizeName(studentName);
      final lrn = newStudent['lrn']?.toString().trim();
      final gradeLevel = newStudent['grade_level']?.toString().trim();
      final period = newStudent['period']?.toString().trim();
      final targetAcademicYear = academicYear ??
          newStudent['academic_year']?.toString() ??
          '2024-2025';

      if (studentName.isEmpty) return null;

      // 🎯 CRITICAL: First check if we have SAME STUDENT IN SAME SCHOOL YEAR
      if (newStudent['student_id'] != null &&
          newStudent['student_id'].toString().isNotEmpty) {
        final existingById = await dbService.getLearnerByStudentIdAndYear(
          newStudent['student_id'].toString(),
          schoolId,
          targetAcademicYear,
        );
        if (existingById != null) {
          return existingById; // Same student, same year -> UPDATE
        }
      }

      // Try by LRN WITH SCHOOL YEAR
      if (lrn != null && lrn.isNotEmpty) {
        final existingByLRN = await dbService.getLearnerByLRNAndYear(
          lrn,
          schoolId,
          targetAcademicYear,
        );
        if (existingByLRN != null) {
          return existingByLRN;
        }
      }

      // Try fuzzy name matching WITHIN SAME SCHOOL YEAR
      final similarStudentsInYear =
          await dbService.findStudentsByNameSimilarityAndYear(
        studentName,
        schoolId,
        targetAcademicYear,
      );

      if (similarStudentsInYear.isNotEmpty) {
        // Find the best match
        for (final existingStudent in similarStudentsInYear) {
          final existingName =
              existingStudent['learner_name']?.toString() ?? '';
          final nameSimilarity = StudentNameMatcher.calculateNameSimilarity(
            studentName,
            existingName,
          );

          if (nameSimilarity >= 0.85) {
            return existingStudent;
          }
        }
      }

      // 🎯 IMPORTANT: If no match in SAME YEAR, check if student exists in ANY year
      // This helps with student tracking across years
      final allSimilarStudents = await dbService.findStudentsByNameSimilarity(
        studentName,
        schoolId,
      );

      if (allSimilarStudents.isNotEmpty) {
        // Find best match across all years (for ID preservation)
        for (final existingStudent in allSimilarStudents) {
          final existingName =
              existingStudent['learner_name']?.toString() ?? '';
          final nameSimilarity = StudentNameMatcher.calculateNameSimilarity(
            studentName,
            existingName,
          );

          if (nameSimilarity >= 0.90) {
            // Higher threshold for cross-year matching
            return existingStudent;
          }
        }
      }

      return null; // Completely new student
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error finding existing student: $e');
      }
      return null;
    }
  }

  /// 🆕 NEW: Smart merge with SCHOOL YEAR awareness
  static Map<String, dynamic> mergeStudentDataWithYearAwareness(
    Map<String, dynamic> existingStudent,
    Map<String, dynamic> newStudent,
    String targetAcademicYear,
  ) {
    final merged = Map<String, dynamic>.from(existingStudent);

    // 🎯 KEY CHECK: Are we in the SAME academic year?
    final existingYear = existingStudent['academic_year']?.toString() ?? '';
    final newYear = targetAcademicYear;

    if (existingYear == newYear) {
      // 🎯 SAME YEAR: Merge within same year
      return _mergeWithinSameYear(existingStudent, newStudent);
    } else {
      // 🎯 DIFFERENT YEAR: Create NEW annual record (don't merge)
      // Return null to indicate new record needed
      return {};
    }
  }

  /// Merge data within the same academic year
  static Map<String, dynamic> _mergeWithinSameYear(
    Map<String, dynamic> existingStudent,
    Map<String, dynamic> newStudent,
  ) {
    final merged = Map<String, dynamic>.from(existingStudent);

    final existingPeriod = existingStudent['period']?.toString() ?? 'Baseline';
    final newPeriod = newStudent['period']?.toString() ?? 'Baseline';

    // If same period, update measurements
    if (existingPeriod == newPeriod) {
      // Update only if new data is better/missing
      if (newStudent['weight_kg'] != null &&
          (existingStudent['weight'] == null ||
              existingStudent['weight'].toString().isEmpty)) {
        merged['weight'] = newStudent['weight_kg'];
      }

      if (newStudent['height_cm'] != null &&
          (existingStudent['height'] == null ||
              existingStudent['height'].toString().isEmpty)) {
        merged['height'] = newStudent['height_cm'];
      }

      if (newStudent['bmi'] != null &&
          (existingStudent['bmi'] == null ||
              existingStudent['bmi'].toString().isEmpty)) {
        merged['bmi'] = newStudent['bmi'];
      }

      // Always update nutritional status if new one is not "Unknown"
      if (newStudent['nutritional_status'] != null &&
          newStudent['nutritional_status'].toString() != 'Unknown') {
        merged['nutritional_status'] = newStudent['nutritional_status'];
      }
    } else {
      // 🎯 DIFFERENT PERIODS (Baseline vs Endline) IN SAME YEAR - THIS IS GOOD!
      merged['has_baseline'] =
          existingPeriod == 'Baseline' || newPeriod == 'Baseline';
      merged['has_endline'] =
          existingPeriod == 'Endline' || newPeriod == 'Endline';

      // Store both periods if available
      if (existingPeriod == 'Baseline' && newPeriod == 'Endline') {
        merged['baseline_data'] = {
          'weight': existingStudent['weight'],
          'height': existingStudent['height'],
          'bmi': existingStudent['bmi'],
          'nutritional_status': existingStudent['nutritional_status'],
        };
        merged['endline_data'] = {
          'weight': newStudent['weight_kg'],
          'height': newStudent['height_cm'],
          'bmi': newStudent['bmi'],
          'nutritional_status': newStudent['nutritional_status'],
        };
      }
    }

    return merged;
  }

  /// 🆕 NEW: Check if we should create new annual record
  static bool shouldCreateNewAnnualRecord(
    Map<String, dynamic> existingStudent,
    String newAcademicYear,
  ) {
    final existingYear = existingStudent['academic_year']?.toString() ?? '';

    // Different year = NEW annual record
    return existingYear != newAcademicYear;
  }

  static resolveStudentData(
      existingStudent,
      Map<String, dynamic> studentFromCSV,
      String existingPeriod,
      String newPeriod) {}
}
