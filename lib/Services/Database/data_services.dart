// data_service.dart - COMPLETE UPDATED VERSION WITH ACADEMIC YEAR FIX
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:district_dev/Services/Data%20Model/acad_schyear_manager.dart';
import 'package:district_dev/Services/Data%20Model/date_utilities.dart';
import 'package:district_dev/Services/Data%20Model/exce_external_cleaner.dart';
import 'package:district_dev/Services/Data%20Model/food_datamodel.dart';
import 'package:district_dev/Services/Data%20Model/import_student.dart';
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:district_dev/Services/Database/database_service.dart'
    show DatabaseService;
import 'package:district_dev/Services/Extraction/excel_cleaner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor, ConflictAlgorithm;

// ADD MISSING CONSTANTS FOR COMPATIBILITY
const bool kDebugMode = true;

// Nutritional Status Enum
enum NutritionalStatus {
  normal,
  underweight,
  severelyMalnourished,
  overweight,
  obese,
  wasted,
  severelyWasted,
}

// Add these extensions to your Learner class
extension LearnerTableMaps on Learner {
  Map<String, dynamic> toEndlineLearnerMap() {
    return toBaselineLearnerMap(); // Same structure for both
  }
}

extension AssessmentTableMaps on Assessment {
  Assessment copyWith({
    int? id,
    int? learnerId,
    double? weightKg,
    double? heightCm,
    double? bmi,
    String? nutritionalStatus,
    String? assessmentDate,
    String? assessmentCompleteness,
    DateTime? createdAt,
    String? cloudSyncId,
    String? lastSynced,
  }) {
    return Assessment(
      id: id ?? this.id,
      learnerId: learnerId ?? this.learnerId, // 🛠️ FIX: Add required learnerId
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bmi: bmi ?? this.bmi,
      nutritionalStatus: nutritionalStatus ?? this.nutritionalStatus,
      assessmentDate: assessmentDate ?? this.assessmentDate,
      assessmentCompleteness:
          assessmentCompleteness ?? this.assessmentCompleteness,
      createdAt: createdAt ?? this.createdAt, // 🛠️ FIX: Add required createdAt
      cloudSyncId: cloudSyncId ?? this.cloudSyncId,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  Map<String, dynamic> toEndlineAssessmentMap() {
    return toBaselineAssessmentMap(); // Same structure for both
  }
}

// HFA Status Enum
enum HFAStatus { normal, stunted, severelyStunted, tall }

// Dietary Plan Result
class DietaryPlanResult {
  final String planName;
  final String description;
  final List<FoodItem> recommendedFoods;
  final double totalDailyCalories;
  final double totalDailyProtein;
  final Map<String, int> foodTypeDistribution;

  DietaryPlanResult({
    required this.planName,
    required this.description,
    required this.recommendedFoods,
    required this.totalDailyCalories,
    required this.totalDailyProtein,
    required this.foodTypeDistribution,
  });

  Map<String, dynamic> toMap() {
    return {
      'planName': planName,
      'description': description,
      'recommendedFoods': recommendedFoods.map((food) => food.name).toList(),
      'totalDailyCalories': totalDailyCalories,
      'totalDailyProtein': totalDailyProtein,
      'foodTypeDistribution': foodTypeDistribution,
    };
  }
}

// Projection Result
class HealthProjectionResult {
  final double initialWeight;
  final double projectedFinalWeight;
  final double totalWeightGain;
  final Map<int, double> dailyProjections;
  final int totalFeedingDays;
  final int absentDays;

  HealthProjectionResult({
    required this.initialWeight,
    required this.projectedFinalWeight,
    required this.totalWeightGain,
    required this.dailyProjections,
    required this.totalFeedingDays,
    required this.absentDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'initialWeight': initialWeight,
      'projectedFinalWeight': projectedFinalWeight,
      'totalWeightGain': totalWeightGain,
      'totalFeedingDays': totalFeedingDays,
      'absentDays': absentDays,
      'dailyProjections': dailyProjections,
    };
  }
}

class DataService {
  static final DatabaseService _dbService = DatabaseService.instance;
  static final FoodDataRepository _foodRepo = FoodDataRepository();

  // ========== DUAL-TABLE STRUCTURE METHODS ==========

  /// 🆕 NEW: Enhanced import method using dual-table structure
  /// 🆕 NEW: Enhanced import method using dual-table structure
  static Future<ImportResult> importExcelFileWithDualTable(
    String filePath,
    String schoolId,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 ========== DUAL-TABLE IMPORT START ==========');
        debugPrint('   File Path: $filePath');
        debugPrint('   School ID: $schoolId');
      }

      // Step 1: Get the current school profile for validation
      final schoolProfile = await _getSchoolProfile(schoolId);
      final phase2TablesExist = await _verifyPhase2TablesExist();

      if (schoolProfile == null) {
        final errorMessage =
            'Cannot proceed: Application School Profile (ID: $schoolId) not found. Please set up the school profile first.';
        return ImportResult(
          success: false,
          message: errorMessage,
          recordsProcessed: 0,
          errors: ['Missing school profile - validation blocked'],
          validationSummary: {
            'valid': false,
            'reason': 'School profile missing',
            'dual_table_system': phase2TablesExist,
          },
          receivedFrom: '',
          dataType: '',
          breakdown: {},
          batchId: '',
          totalRecords: 0,
        );
      }

      if (kDebugMode) {
        debugPrint('✅ SCHOOL PROFILE FOUND: ${schoolProfile.schoolName}');
        debugPrint('✅ PHASE 2 TABLES: $phase2TablesExist');
      }

      final cleanResult = await ExcelCleaner.cleanSchoolExcel(
        filePath,
        dashboardProfile: schoolProfile,
        strictValidation: true,
      );
      // Detect period from metadata and data
      final detectedPeriodFromMetadata =
          cleanResult.reportMetadata?['period']?.toString() ?? 'Baseline';
      final detectedPeriodFromData = _detectPeriodFromData(cleanResult.data);
      final detectedPeriod = detectedPeriodFromMetadata != 'Baseline'
          ? detectedPeriodFromMetadata
          : detectedPeriodFromData;

      if (kDebugMode) {
        debugPrint('🎯 PERIOD DETECTION:');
        debugPrint('   From Metadata: $detectedPeriodFromMetadata');
        debugPrint('   From Data: $detectedPeriodFromData');
        debugPrint('   Final: $detectedPeriod');
        debugPrint('📊 EXCEL DATA: ${cleanResult.data.length} records');
      }

      // Validation check - use dynamic type checking instead of cast
      if (cleanResult.validationResult != null) {
        final validationResult = cleanResult.validationResult;
        // Check if isValid property exists using reflection
        final isValid = _isValidationResultValid(validationResult);
        if (!isValid) {
          return ImportResult(
            success: false,
            message: '🚫 IMPORT BLOCKED: School validation failed.',
            recordsProcessed: 0,
            errors: _getValidationErrors(validationResult) ??
                ['School profile mismatch'],
            validationSummary: {
              'valid': false,
              'reason': 'school_mismatch',
              'dual_table_system': phase2TablesExist,
            },
            receivedFrom: '',
            dataType: '',
            breakdown: {},
            batchId: '',
            totalRecords: 0,
          );
        }
      }

      if (!cleanResult.success || cleanResult.data.isEmpty) {
        return ImportResult(
          success: false,
          message: 'No valid student data found in Excel file.',
          recordsProcessed: 0,
          errors: cleanResult.problems,
          validationSummary: {
            'valid': false,
            'reason': 'no_valid_data',
            'dual_table_system': phase2TablesExist,
          },
          receivedFrom: '',
          dataType: '',
          breakdown: {},
          batchId: '',
          totalRecords: 0,
        );
      }

      // 🛠️ FIX: Call nutritional status verification safely
      _verifyNutritionalStatusDataSafe(cleanResult);

      // Step 3: Prepare import metadata with proper academic year
      final importMetadata = await _prepareImportMetadataWithYearFix(
        cleanResult,
        schoolProfile,
        detectedPeriod,
      );

      // Step 4: Save using appropriate system based on table availability
      Map<String, dynamic> dbResult;
      if (phase2TablesExist) {
        dbResult = await _saveWithDualTableSystem(
          cleanResult.data,
          schoolId,
          detectedPeriod,
          importMetadata,
        );
      } else {
        dbResult = await _saveWithLegacySystem(
          cleanResult.data,
          schoolId,
          detectedPeriod,
          importMetadata,
        );
      }

      // Step 5: Prepare result
      String finalMessage;
      if (dbResult['success'] == true) {
        finalMessage =
            'Successfully imported ${dbResult['records_processed']} student records as $detectedPeriod data. ';
        finalMessage += phase2TablesExist
            ? 'Using dual-table system.'
            : 'Using legacy system.';

        if (dbResult['student_tracking_stats'] != null) {
          final stats = dbResult['student_tracking_stats'];
          finalMessage +=
              ' Student tracking: ${stats['student_ids_created']} new IDs created.';
        }

        if (dbResult['errors']?.isNotEmpty == true) {
          finalMessage +=
              ' Note: ${dbResult['errors']?.length} minor issues were encountered.';
        }
      } else {
        finalMessage = 'Import failed: ${dbResult['message']}';
      }

      return ImportResult(
        success: dbResult['success'] == true,
        message: finalMessage,
        recordsProcessed: dbResult['records_processed'] ?? 0,
        errors: dbResult['errors'] is List
            ? List<String>.from(dbResult['errors'] as List)
            : null,
        validationSummary: {
          'valid': dbResult['success'] == true,
          'records_processed': dbResult['records_processed'] ?? 0,
          'student_tracking_enabled': true,
          'student_ids_created':
              dbResult['student_tracking_stats']?['student_ids_created'] ?? 0,
          'import_period': detectedPeriod,
          'dual_table_system': phase2TablesExist,
          'academic_year_imported': dbResult['academic_year'] ?? 'Unknown',
        },
        receivedFrom: '',
        dataType: '',
        breakdown: {},
        batchId: '',
        totalRecords: 0,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ DUAL-TABLE IMPORT ERROR: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return ImportResult(
        success: false,
        message: 'Import failed: $e',
        recordsProcessed: 0,
        errors: [e.toString(), stackTrace.toString()],
        validationSummary: {
          'valid': false,
          'reason': e.toString(),
          'dual_table_system': false,
        },
        receivedFrom: '',
        dataType: '',
        breakdown: {},
        batchId: '',
        totalRecords: 0,
      );
    }
  }

  /// 🆕 NEW: Safe version of nutritional status verification
  static void _verifyNutritionalStatusDataSafe(dynamic cleanResult) {
    try {
      // Try to access data property dynamically
      if (cleanResult.data != null && cleanResult.data is List) {
        final data = cleanResult.data as List<Map<String, dynamic>>;
        if (data.isEmpty) return;

        final studentsWithUnknownStatus = data.where((student) {
          final status = student['nutritional_status']?.toString();
          return status == null || status.isEmpty || status == 'Unknown';
        }).toList();

        final unknownCount = studentsWithUnknownStatus.length;
        final totalCount = data.length;
        final unknownPercentage =
            totalCount > 0 ? (unknownCount / totalCount * 100).round() : 0;

        if (unknownCount > 0 && kDebugMode) {
          debugPrint(
            '⚠️ CRITICAL WARNING: NUTRITIONAL STATUS DATA LOSS DETECTED',
          );
          debugPrint('   Total students: $totalCount');
          debugPrint(
            '   Students with "Unknown" status: $unknownCount ($unknownPercentage%)',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Could not verify nutritional status: $e');
      }
    }
  }

  /// 🆕 NEW: Check validation result dynamically
  static bool _isValidationResultValid(dynamic validationResult) {
    try {
      // Try multiple ways to check if validation is valid
      if (validationResult == null) return true;

      if (validationResult is Map) {
        return validationResult['isValid'] == true;
      }

      // Use reflection to check if isValid property exists
      return validationResult.isValid != false;
    } catch (e) {
      return true; // Default to true if we can't determine
    }
  }

  /// 🆕 NEW: Get validation errors dynamically
  static List<String>? _getValidationErrors(dynamic validationResult) {
    try {
      if (validationResult == null) return null;

      if (validationResult is Map) {
        return List<String>.from(validationResult['errors'] ?? []);
      }

      // Try to access errors property
      if (validationResult.errors != null && validationResult.errors is List) {
        return List<String>.from(validationResult.errors as List);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 NEW: Prepare import metadata with proper academic year extraction
  static Future<Map<String, dynamic>> _prepareImportMetadataWithYearFix(
    CleanResult cleanResult,
    SchoolProfile schoolProfile,
    String detectedPeriod,
  ) async {
    final metadata = <String, dynamic>{
      'period': detectedPeriod,
      'school_name': cleanResult.reportMetadata?['school_name'] ??
          schoolProfile.schoolName,
      'weighing_date': cleanResult.reportMetadata?['weighing_date'],
      'import_timestamp': DateTime.now().toIso8601String(),
      'student_tracking_enabled': true,
      'school_profile': {
        'schoolName': schoolProfile.schoolName,
        'district': schoolProfile.district,
        'region': schoolProfile.region,
      },
    };

    // 🎯 CRITICAL FIX: Extract academic year with multiple fallback strategies
    final academicYear = _extractAcademicYearFromCleanResult(cleanResult);

    metadata['schoolYear'] = academicYear; // 🎯 CORRECT KEY
    metadata['school_year'] = academicYear; // Compatibility key
    metadata['academic_year'] = academicYear; // Alternative key

    if (kDebugMode) {
      debugPrint('🎯 ACADEMIC YEAR EXTRACTION RESULT:');
      debugPrint('   Final Year: $academicYear');
      debugPrint(
        '   Metadata Keys with Year: ${metadata.keys.where((k) => k.contains('year') || k.contains('Year')).toList()}',
      );
    }

    return metadata;
  }

  /// 🎯 CRITICAL FIX: Extract academic year from CleanResult with multiple fallbacks
  static String _extractAcademicYearFromCleanResult(CleanResult cleanResult) {
    // Try multiple sources in priority order

    // 1. From report metadata (highest priority)
    final reportYear = cleanResult.reportMetadata?['school_year']?.toString();
    if (reportYear != null && reportYear.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('✅ Found year in report_metadata: $reportYear');
      }
      return reportYear.trim();
    }

    // 2. From school profile in metadata
    if (cleanResult.metadata != null &&
        cleanResult.metadata!['school_profile'] is Map) {
      final profile =
          cleanResult.metadata!['school_profile'] as Map<String, dynamic>;
      final profileYear = profile['schoolYear']?.toString();
      if (profileYear != null && profileYear.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('✅ Found year in school_profile: $profileYear');
        }
        return profileYear.trim();
      }
    }

    // 3. From validation result school profile
    if (cleanResult.validationResult != null) {
      // Try to extract from validation if available
      final validationYear = _extractYearFromValidation(
        cleanResult.validationResult!,
      );
      if (validationYear.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('✅ Found year in validation: $validationYear');
        }
        return validationYear;
      }
    }

    // 4. From extracted data itself (scan first few records)
    final extractedYear = _extractYearFromStudentData(cleanResult.data);
    if (extractedYear.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('✅ Found year in student data: $extractedYear');
      }
      return extractedYear;
    }

    // 5. Use current academic year as final fallback
    final currentYear = AcademicYearManager.getCurrentSchoolYear();
    if (kDebugMode) debugPrint('⚠️ Using current academic year: $currentYear');
    return currentYear;
  }

  /// 🆕 NEW: Extract year from validation result
  static String _extractYearFromValidation(ValidationResult validationResult) {
    // This depends on how your ValidationResult is structured
    // Adjust based on your actual implementation
    try {
      if (validationResult is Map) {
        final year = (validationResult as Map)['schoolYear']?.toString();
        if (year != null && year.isNotEmpty) return year.trim();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Could not extract year from validation: $e');
      }
    }
    return '';
  }

  /// 🆕 NEW: Extract year from student data
  static String _extractYearFromStudentData(
    List<Map<String, dynamic>> students,
  ) {
    if (students.isEmpty) return '';

    // Check first few students for academic_year field
    for (int i = 0; i < min(5, students.length); i++) {
      final student = students[i];
      final year = student['academic_year']?.toString() ??
          student['school_year']?.toString() ??
          student['schoolYear']?.toString();
      if (year != null && year.isNotEmpty) {
        return year.trim();
      }
    }
    return '';
  }

  /// 🆕 NEW: Save using dual-table system - WITH TRANSACTION FIX
  static Future<Map<String, dynamic>> _saveWithDualTableSystem(
    List<Map<String, dynamic>> students,
    String schoolId,
    String period,
    Map<String, dynamic> importMetadata,
  ) async {
    final db = await DatabaseService.instance.database;

    // 🎯 CRITICAL: Start transaction to ensure all-or-nothing
    return await db.transaction((txn) async {
      final results = {
        'success': true,
        'records_processed': 0,
        'errors': <String>[],
        'student_tracking_stats': {
          'student_ids_created': 0,
          'existing_students_matched': 0,
          'baseline_inserted': 0,
          'endline_inserted': 0,
          'skipped_duplicates': 0,
        },
      };

      try {
        final academicYear = _extractAcademicYearWithDebug(importMetadata);
        results['academic_year'] = academicYear;

        int successfulInserts = 0;
        int skippedDuplicates = 0;
        int baselineCount = 0;
        int endlineCount = 0;

        for (final student in students) {
          try {
            final individualPeriod = _detectIndividualPeriod(student);

            // 🎯 CRITICAL: Check if student already exists in SAME YEAR
            final existingStudent = await _findExistingStudentInTransaction(
              txn,
              student,
              schoolId,
              academicYear,
              individualPeriod,
            );

            if (existingStudent != null) {
              // Student already exists - SKIP or UPDATE based on conflict strategy
              if (shouldUpdateExisting(existingStudent, student)) {
                // Update existing record
                await _updateExistingStudent(
                  txn,
                  existingStudent,
                  student,
                  individualPeriod,
                );
                successfulInserts++;
              } else {
                // Skip duplicate
                skippedDuplicates++;
                continue;
              }
            } else {
              // New student - insert
              await _insertNewStudent(
                txn,
                student,
                schoolId,
                academicYear,
                individualPeriod,
              );
              successfulInserts++;

              final stats =
                  results['student_tracking_stats'] as Map<String, dynamic>;
              stats['student_ids_created'] =
                  (stats['student_ids_created'] as int) + 1;
            }

            // Track counts
            if (individualPeriod.toLowerCase() == 'baseline') {
              baselineCount++;
            } else if (individualPeriod.toLowerCase() == 'endline') {
              endlineCount++;
            }
          } catch (e) {
            // Log error but continue with other students
            (results['errors'] as List<String>).add(
              'Error processing ${student['name']}: $e',
            );
          }
        }

        // Update results
        results['records_processed'] = successfulInserts;
        final stats = results['student_tracking_stats'] as Map<String, dynamic>;
        stats['baseline_inserted'] = baselineCount;
        stats['endline_inserted'] = endlineCount;
        stats['skipped_duplicates'] = skippedDuplicates;

        // If too many errors, rollback the transaction
        if ((results['errors'] as List).length > students.length * 0.5) {
          // More than 50% errors - rollback
          throw Exception('Import failed: Too many errors');
        }

        return results;
      } catch (e) {
        // Transaction will automatically rollback on exception
        rethrow;
      }
    });
  }

  /// 🆕 Helper: Update existing student record
  static Future<void> _updateExistingStudent(
    DatabaseExecutor txn,
    Map<String, dynamic> existingStudent,
    Map<String, dynamic> newStudent,
    String period,
  ) async {
    final table = period.toLowerCase() == 'baseline'
        ? 'baseline_learners'
        : 'endline_learners';
    final assessmentTable = period.toLowerCase() == 'baseline'
        ? 'baseline_assessments'
        : 'endline_assessments';

    final learnerId = existingStudent['id'] as int;

    // Update learner information if needed
    final updates = <String, dynamic>{};

    // Only update if new data is more complete
    if (existingStudent['weight'] == null && newStudent['weight_kg'] != null) {
      updates['weight'] = newStudent['weight_kg'];
    }
    if (existingStudent['height'] == null && newStudent['height_cm'] != null) {
      updates['height'] = newStudent['height_cm'];
    }
    if (existingStudent['bmi'] == null && newStudent['bmi'] != null) {
      updates['bmi'] = newStudent['bmi'];
    }
    if ((existingStudent['nutritional_status'] == null ||
            existingStudent['nutritional_status'] == 'Unknown') &&
        newStudent['nutritional_status'] != null) {
      updates['nutritional_status'] = newStudent['nutritional_status'];
    }

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await txn.update(table, updates, where: 'id = ?', whereArgs: [learnerId]);
    }

    // Update assessment table if applicable
    final assessmentUpdates = <String, dynamic>{};

    if (newStudent['weight_kg'] != null) {
      assessmentUpdates['weight_kg'] = newStudent['weight_kg'];
    }
    if (newStudent['height_cm'] != null) {
      assessmentUpdates['height_cm'] = newStudent['height_cm'];
    }
    if (newStudent['bmi'] != null) {
      assessmentUpdates['bmi'] = newStudent['bmi'];
    }
    if (newStudent['nutritional_status'] != null) {
      assessmentUpdates['nutritional_status'] =
          newStudent['nutritional_status'];
    }

    if (assessmentUpdates.isNotEmpty) {
      assessmentUpdates['updated_at'] = DateTime.now().toIso8601String();

      // Check if assessment exists
      final existingAssessment = await txn.query(
        assessmentTable,
        where: 'learner_id = ?',
        whereArgs: [learnerId],
        limit: 1,
      );

      if (existingAssessment.isNotEmpty) {
        await txn.update(
          assessmentTable,
          assessmentUpdates,
          where: 'learner_id = ?',
          whereArgs: [learnerId],
        );
      } else {
        // Create new assessment
        assessmentUpdates['learner_id'] = learnerId;
        assessmentUpdates['assessment_date'] = DateTime.now().toIso8601String();
        assessmentUpdates['assessment_completeness'] = 'Complete';
        assessmentUpdates['created_at'] = DateTime.now().toIso8601String();

        await txn.insert(assessmentTable, assessmentUpdates);
      }
    }
  }

  /// 🆕 Helper: Insert new student record
  static Future<void> _insertNewStudent(
    DatabaseExecutor txn,
    Map<String, dynamic> student,
    String schoolId,
    String academicYear,
    String period,
  ) async {
    final table = period.toLowerCase() == 'baseline'
        ? 'baseline_learners'
        : 'endline_learners';
    final assessmentTable = period.toLowerCase() == 'baseline'
        ? 'baseline_assessments'
        : 'endline_assessments';

    // Prepare learner data
    final normalizedName = StudentIdentificationService.normalizeName(
      student['name']?.toString() ?? '',
    );

    final learnerData = {
      'student_id': student['student_id']?.toString() ??
          StudentIdentificationService.generateDeterministicStudentID(
            student['name']?.toString() ?? '',
            schoolId,
          ),
      'learner_name': student['name']?.toString() ?? '',
      'lrn': student['lrn']?.toString(),
      'sex': student['sex']?.toString() ?? 'Unknown',
      'grade_level': student['grade_level']?.toString() ?? 'Unknown',
      'section': student['section']?.toString(),
      'date_of_birth': student['birth_date']?.toString(),
      'age': student['age'] != null
          ? int.tryParse(student['age'].toString())
          : null,
      'school_id': schoolId,
      'normalized_name': normalizedName,
      'academic_year': academicYear,
      'cloud_sync_id': '',
      'last_synced': '',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Insert learner
    final learnerId = await txn.insert(
      table,
      learnerData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Prepare and insert assessment data if available
    final hasMeasurements =
        student['weight_kg'] != null || student['height_cm'] != null;

    if (hasMeasurements) {
      final assessmentData = {
        'learner_id': learnerId,
        'weight_kg': student['weight_kg'],
        'height_cm': student['height_cm'],
        'bmi': student['bmi'],
        'nutritional_status':
            student['nutritional_status']?.toString() ?? 'Unknown',
        'assessment_date': student['weighing_date']?.toString() ??
            DateTime.now().toIso8601String(),
        'assessment_completeness': _determineAssessmentCompleteness(student),
        'created_at': DateTime.now().toIso8601String(),
        'cloud_sync_id': '',
        'last_synced': '',
      };

      await txn.insert(
        assessmentTable,
        assessmentData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// 🆕 Helper: Determine assessment completeness
  static String _determineAssessmentCompleteness(Map<String, dynamic> student) {
    final hasWeight = student['weight_kg'] != null;
    final hasHeight = student['height_cm'] != null;
    final hasBMI = student['bmi'] != null;
    final hasStatus = student['nutritional_status'] != null &&
        student['nutritional_status'].toString().isNotEmpty &&
        student['nutritional_status'].toString() != 'Unknown';

    if (hasWeight && hasHeight && hasBMI && hasStatus) {
      return 'Complete';
    } else if (hasWeight && hasHeight && hasBMI) {
      return 'Measurements Complete';
    } else if (hasWeight || hasHeight) {
      return 'Partial Measurements';
    } else if (hasStatus) {
      return 'Status Only';
    }

    return 'Incomplete';
  }

  /// 🆕 EMERGENCY: Repair corrupted data
  Future<Map<String, dynamic>> _repairSchoolData(String schoolId) async {
    try {
      debugPrint('🛠️ STARTING DATA REPAIR FOR SCHOOL: $schoolId');

      final db = await DatabaseService.instance.database;
      final results = {
        'success': false,
        'message': '',
        'recovered_records': 0,
        'errors': [],
      };

      await db.transaction((txn) async {
        // Step 1: Find and remove duplicate students (keep the most complete one)
        final duplicates = await txn.rawQuery(
          '''
        SELECT student_id, academic_year, COUNT(*) as count,
               GROUP_CONCAT(id) as ids
        FROM baseline_learners 
        WHERE school_id = ?
        GROUP BY student_id, academic_year
        HAVING COUNT(*) > 1
      ''',
          [schoolId],
        );

        int recovered = 0;

        for (final dup in duplicates) {
          final studentId = dup['student_id'] as String;
          final idsString = dup['ids'] as String;
          // Sort IDs to ensure consistent handling (optional but good practice)
          final ids = idsString.split(',').map((e) => int.parse(e)).toList()
            ..sort();

          // Strategy: Keep the OLDEST record (first), but move NEW data to it.
          final keepId = ids.first;
          final deleteIds = ids.sublist(1);

          // 1. RE-PARENT ASSESSMENTS (Crucial Step!)
          // Instead of deleting assessments, move them to the 'keepId' learner.
          // This ensures that if the 'duplicate' had the data, the 'kept' learner now owns it.
          await txn.rawUpdate('''
            UPDATE baseline_assessments 
            SET learner_id = ? 
            WHERE learner_id IN (${deleteIds.map((_) => '?').join(',')})
          ''', [keepId, ...deleteIds]);

          // 2. NOW delete the duplicate learner rows
          // Since we moved the assessments, it is safe to delete the learner container.
          await txn.rawDelete('''
            DELETE FROM baseline_learners 
            WHERE id IN (${deleteIds.map((_) => '?').join(',')})
          ''', deleteIds);

          recovered++;
          debugPrint(
            '✅ Merged ${deleteIds.length} duplicates for $studentId into ID: $keepId',
          );
        }

        // Step 2: Recalculate academic year statistics
        final baselineYears = await txn.rawQuery(
          '''
        SELECT academic_year, COUNT(*) as count
        FROM baseline_learners 
        WHERE school_id = ?
        GROUP BY academic_year
        ORDER BY academic_year
      ''',
          [schoolId],
        );

        final endlineYears = await txn.rawQuery(
          '''
        SELECT academic_year, COUNT(*) as count
        FROM endline_learners 
        WHERE school_id = ?
        GROUP BY academic_year
        ORDER BY academic_year
      ''',
          [schoolId],
        );

        results['recovered_records'] = recovered;
        results['success'] = true;
        results['message'] =
            'Repair completed: Removed $recovered duplicate records';

        debugPrint('📊 FINAL COUNTS AFTER REPAIR:');
        for (final row in baselineYears) {
          debugPrint(
            '   Baseline ${row['academic_year']}: ${row['count']} students',
          );
        }
        for (final row in endlineYears) {
          debugPrint(
            '   Endline ${row['academic_year']}: ${row['count']} students',
          );
        }
      });

      return results;
    } catch (e, stackTrace) {
      debugPrint('❌ DATA REPAIR FAILED: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Repair failed: $e',
        'recovered_records': 0,
        'errors': [e.toString()],
      };
    }
  }

  /// 🆕 Helper: Find existing student in transaction
  static Future<Map<String, dynamic>?> _findExistingStudentInTransaction(
    DatabaseExecutor txn,
    Map<String, dynamic> newStudent,
    String schoolId,
    String academicYear,
    String period,
  ) async {
    final name = newStudent['name']?.toString().trim() ?? '';
    final normalizedName = StudentIdentificationService.normalizeName(name);

    final table = period.toLowerCase() == 'baseline'
        ? 'baseline_learners'
        : 'endline_learners';

    // Try by exact match: student_id + academic_year + period
    if (newStudent['student_id'] != null) {
      final existing = await txn.rawQuery(
        '''
      SELECT * FROM $table 
      WHERE school_id = ? 
      AND academic_year = ?
      AND student_id = ?
      LIMIT 1
    ''',
        [schoolId, academicYear, newStudent['student_id']],
      );

      if (existing.isNotEmpty) return existing.first;
    }

    // Try by normalized name + academic_year + period
    final existingByName = await txn.rawQuery(
      '''
    SELECT * FROM $table 
    WHERE school_id = ? 
    AND academic_year = ?
    AND normalized_name = ?
    LIMIT 1
  ''',
      [schoolId, academicYear, normalizedName],
    );

    return existingByName.isNotEmpty ? existingByName.first : null;
  }

  /// 🆕 Helper: Check if we should update existing student
  static bool shouldUpdateExisting(
    Map<String, dynamic> existingStudent,
    Map<String, dynamic> newStudent,
  ) {
    // Only update if new data has measurements and existing doesn't
    final existingHasData =
        existingStudent['weight'] != null && existingStudent['height'] != null;
    final newHasData =
        newStudent['weight_kg'] != null && newStudent['height_cm'] != null;

    return !existingHasData && newHasData;
  }

  /// 🎯 CRITICAL FIX: Extract academic year with proper key handling
  static String _extractAcademicYearWithDebug(
    Map<String, dynamic> importMetadata,
  ) {
    if (kDebugMode) {
      debugPrint('🔍 ACADEMIC YEAR EXTRACTION - DEBUG:');
      debugPrint('   All Metadata Keys: ${importMetadata.keys.toList()}');

      // Check all possible year-related keys
      final yearKeys = importMetadata.keys
          .where(
            (key) =>
                key.toString().toLowerCase().contains('year') ||
                key.toString().toLowerCase().contains('school'),
          )
          .toList();

      debugPrint('   Year-related Keys: $yearKeys');

      for (final key in yearKeys) {
        debugPrint('   - "$key": ${importMetadata[key]}');
      }
    }

    // 🎯 FIXED: Multiple fallback strategies for academic year extraction
    final yearExtractionStrategies = [
      // Primary: 'schoolYear' - the correct key from SchoolProfileImport
      () => importMetadata['schoolYear']?.toString().trim(),

      // Secondary: 'school_year' - compatibility fallback
      () => importMetadata['school_year']?.toString().trim(),

      // Tertiary: 'academic_year' - alternative key
      () => importMetadata['academic_year']?.toString().trim(),

      // Fourth: Extract from nested school_profile
      () {
        if (importMetadata['school_profile'] is Map) {
          final profile =
              importMetadata['school_profile'] as Map<String, dynamic>;
          return profile['schoolYear']?.toString().trim() ??
              profile['school_year']?.toString().trim() ??
              profile['academic_year']?.toString().trim();
        }
        return null;
      },

      // Fifth: Extract from validation_result
      () {
        if (importMetadata['validation_result'] is Map) {
          final validation =
              importMetadata['validation_result'] as Map<String, dynamic>;
          return validation['schoolYear']?.toString().trim();
        }
        return null;
      },

      // Sixth: Try to parse from report_metadata
      () {
        if (importMetadata['report_metadata'] is Map) {
          final report =
              importMetadata['report_metadata'] as Map<String, dynamic>;
          return report['school_year']?.toString().trim();
        }
        return null;
      },
    ];

    // Try each strategy in order
    for (final strategy in yearExtractionStrategies) {
      try {
        final year = strategy();
        if (year != null && year.isNotEmpty && year != 'null') {
          if (kDebugMode) {
            debugPrint('✅ Found academic year: $year');
          }
          return year;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Strategy failed: $e');
        }
      }
    }

    // Final fallback: Use current academic year
    final currentYear = AcademicYearManager.getCurrentSchoolYear();
    if (kDebugMode) {
      debugPrint('⚠️ No academic year found, using current: $currentYear');
    }
    return currentYear;
  }

  /// 🆕 NEW: Update school academic years with error handling
  static Future<void> _updateSchoolAcademicYears(
    String schoolId,
    String academicYear,
    int successfulInserts,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('🎯 UPDATING SCHOOL ACTIVE ACADEMIC YEARS...');
        debugPrint('   School: $schoolId');
        debugPrint('   Academic Year: $academicYear');
        debugPrint('   Successful Inserts: $successfulInserts');
      }

      // 🎯 FIX 1: Get current school profile to see existing active years
      final schoolProfile = await _getSchoolProfile(schoolId);
      if (schoolProfile != null) {
        final currentYears = schoolProfile.activeAcademicYears;
        if (kDebugMode) {
          debugPrint('📋 SCHOOL PROFILE BEFORE UPDATE:');
          debugPrint('   School Name: ${schoolProfile.schoolName}');
          debugPrint('   Current Active Years: $currentYears');
          debugPrint(
            '   Contains $academicYear: ${currentYears.contains(academicYear)}',
          );
        }
      }

      // 🎯 FIX 2: Call the method to update school's active academic years
      final updated = await DatabaseService.instance
          .updateSchoolActiveAcademicYears(schoolId, academicYear);

      if (updated) {
        if (kDebugMode) {
          debugPrint(
            '✅ SCHOOL METADATA UPDATED: Added $academicYear to active years',
          );

          // Verify the update by fetching fresh school data
          final updatedSchool = await _getSchoolProfile(schoolId);
          if (updatedSchool != null) {
            debugPrint('📋 SCHOOL AFTER UPDATE:');
            debugPrint('   Active Years: ${updatedSchool.activeAcademicYears}');
            debugPrint('   Primary Year: ${updatedSchool.primaryAcademicYear}');

            // 🎯 FIX 3: Also update primary academic year if needed
            if (updatedSchool.primaryAcademicYear != academicYear) {
              // Optional: Update primary academic year to the newly imported year
              await DatabaseService.instance.updateSchoolPrimaryAcademicYear(
                schoolId,
                academicYear,
              );
              debugPrint('✅ UPDATED PRIMARY ACADEMIC YEAR: $academicYear');
            }
          }
        }
      } else {
        throw Exception('Failed to update school active academic years');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('⚠️ SCHOOL METADATA UPDATE FAILED (non-critical): $e');
        debugPrint('Stack trace: $stackTrace');
      }
      // Don't mark import as failed for metadata update issue
    }
  }

  /// 🛠️ DEBUG: Trace academic year through the pipeline
  static void _debugAcademicYearTrace(Map<String, dynamic> data, String stage) {
    if (!kDebugMode) return;

    debugPrint('🎯 ACADEMIC YEAR TRACE - $stage:');
    debugPrint('   Has schoolYear key: ${data.containsKey('schoolYear')}');
    debugPrint('   Has school_year key: ${data.containsKey('school_year')}');
    debugPrint(
      '   Has academic_year key: ${data.containsKey('academic_year')}',
    );

    if (data.containsKey('schoolYear')) {
      debugPrint('   schoolYear value: ${data['schoolYear']}');
    }
    if (data.containsKey('school_year')) {
      debugPrint('   school_year value: ${data['school_year']}');
    }
    if (data.containsKey('academic_year')) {
      debugPrint('   academic_year value: ${data['academic_year']}');
    }

    // Check nested school_profile
    if (data.containsKey('school_profile') && data['school_profile'] is Map) {
      final profile = data['school_profile'] as Map<String, dynamic>;
      debugPrint('   school_profile.schoolYear: ${profile['schoolYear']}');
    }

    debugPrint('---');
  }

  /// 🆕 NEW: Get school profile with active academic years
  static Future<Map<String, dynamic>?> getSchoolProfileWithActiveYears(
    String schoolId,
  ) async {
    try {
      final db = await DatabaseService.instance.database;

      final schoolData = await db.query(
        'schools',
        where: 'id = ?',
        whereArgs: [schoolId],
        limit: 1,
      );

      if (schoolData.isNotEmpty) {
        final school = schoolData.first;

        // If active_academic_years is empty, try to discover from database
        if (school['active_academic_years'] == null ||
            school['active_academic_years'].toString().isEmpty) {
          // Discover academic years from baseline_learners table
          final baselineYears = await db.rawQuery(
            '''
          SELECT DISTINCT academic_year 
          FROM baseline_learners 
          WHERE school_id = ?
          UNION
          SELECT DISTINCT academic_year 
          FROM endline_learners 
          WHERE school_id = ?
          ORDER BY academic_year DESC
        ''',
            [schoolId, schoolId],
          );

          final discoveredYears = baselineYears
              .map((row) => row['academic_year']?.toString())
              .where((year) => year != null && year.isNotEmpty)
              .toList();

          if (discoveredYears.isNotEmpty) {
            // Update the school with discovered years
            final yearsString = discoveredYears.join(',');
            await db.update(
              'schools',
              {
                'active_academic_years': yearsString,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [schoolId],
            );

            // Return updated school data
            school['active_academic_years'] = yearsString;

            if (kDebugMode) {
              debugPrint('🔍 DISCOVERED ACADEMIC YEARS: $yearsString');
            }
          }
        }

        return school;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting school profile with active years: $e');
      }
      return null;
    }
  }

  /// 🛠️ CRITICAL: Enhanced individual period detection
  static String _detectIndividualPeriod(Map<String, dynamic> student) {
    // Check multiple possible period fields with priority order
    final period = student['period']?.toString().trim();
    final assessmentPeriod = student['assessment_period']?.toString().trim();
    final importPeriod = student['import_period']?.toString().trim();
    final weighingDate = student['weighing_date']?.toString();

    if (kDebugMode && period != null && period.isNotEmpty) {
      debugPrint('🔍 PERIOD DETECTION for ${student['name']}:');
      debugPrint('   period field: $period');
      debugPrint('   assessment_period: $assessmentPeriod');
      debugPrint('   import_period: $importPeriod');
    }

    // Priority 1: Explicit period fields
    if (period != null && period.isNotEmpty && period != 'Unknown') {
      return period;
    }
    if (assessmentPeriod != null &&
        assessmentPeriod.isNotEmpty &&
        assessmentPeriod != 'Unknown') {
      return assessmentPeriod;
    }
    if (importPeriod != null &&
        importPeriod.isNotEmpty &&
        importPeriod != 'Unknown') {
      return importPeriod;
    }

    // Priority 2: Infer from weighing date or other metadata
    if (weighingDate != null && weighingDate.isNotEmpty) {
      // You could add logic here to infer period from date ranges
      // For now, return the fallback behavior
    }

    // Priority 3: Check for Endline indicators in the data
    final weightKg = student['weight_kg'];
    final heightCm = student['height_cm'];
    final bmi = student['bmi'];

    // If data looks like follow-up measurements, it might be Endline
    if (weightKg != null && heightCm != null && bmi != null) {
      // Add your Endline detection logic here if needed
    }

    // Final fallback
    return 'Baseline';
  }

  /// 🛠️ ENHANCED: Direct insertion for StudentAssessment with better period handling
  static Future<Map<String, dynamic>> _insertStudentAssessmentDirectly(
    StudentAssessment studentAssessment,
    String period,
  ) async {
    try {
      final db = await DatabaseService.instance.database;

      // Determine which tables to use based on INDIVIDUAL period
      final learnerTable = period.toLowerCase() == 'baseline'
          ? 'baseline_learners'
          : 'endline_learners';
      final assessmentTable = period.toLowerCase() == 'baseline'
          ? 'baseline_assessments'
          : 'endline_assessments';

      if (kDebugMode) {
        debugPrint('🎯 DIRECT INSERTION:');
        debugPrint('   Table: $learnerTable');
        debugPrint('   Student: ${studentAssessment.learner.learnerName}');
        debugPrint('   Period: $period');
        debugPrint(
          '   Academic Year: ${studentAssessment.learner.academicYear}',
        );
      }

      return await db.transaction((txn) async {
        // 1. Insert learner
        final learnerData = period.toLowerCase() == 'baseline'
            ? studentAssessment.learner.toBaselineLearnerMap()
            : studentAssessment.learner.toEndlineLearnerMap();

        final learnerId = await txn.insert(
          learnerTable,
          learnerData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 2. Insert assessment with correct learner ID
        final assessmentData = studentAssessment.assessment.copyWith(
          learnerId: learnerId,
        );

        final assessmentMap = period.toLowerCase() == 'baseline'
            ? assessmentData.toBaselineAssessmentMap()
            : assessmentData.toEndlineAssessmentMap();

        final assessmentId = await txn.insert(
          assessmentTable,
          assessmentMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (kDebugMode) {
          debugPrint('✅ DIRECT INSERTION SUCCESS:');
          debugPrint('   Learner ID: $learnerId');
          debugPrint('   Assessment ID: $assessmentId');
          debugPrint('   Period: $period');
        }

        return {
          'success': true,
          'learner_id': learnerId,
          'assessment_id': assessmentId,
          'student_id': studentAssessment.learner.studentId,
          'period': period,
        };
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ DIRECT INSERTION FAILED: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 🆕 NEW: Save using legacy system (fallback)
  static Future<Map<String, dynamic>> _saveWithLegacySystem(
    List<Map<String, dynamic>> students,
    String schoolId,
    String period,
    Map<String, dynamic> importMetadata,
  ) async {
    final results = {
      'success': true,
      'records_processed': 0,
      'errors': <String>[],
      'student_tracking_stats': {
        'student_ids_created': 0,
        'existing_students_matched': 0,
      },
      'import_batch_id': 'batch_${DateTime.now().millisecondsSinceEpoch}',
      'message': 'Import completed successfully (Legacy System)',
      'dual_table_system': false,
    };

    try {
      if (kDebugMode) {
        debugPrint('🔄 LEGACY SYSTEM: IMPORT STARTED');
        debugPrint('   Period: $period');
        debugPrint('   Students: ${students.length}');
      }

      // 🎯 Extract academic year for legacy system too
      final academicYear = _extractAcademicYearWithDebug(importMetadata);
      results['academic_year'] = academicYear;

      int successfulInserts = 0;
      final errors = <String>[];

      // Get database instance
      final db = await DatabaseService.instance.database;

      for (final student in students) {
        try {
          // Enhance student data
          final enhancedStudent = Map<String, dynamic>.from(student);
          enhancedStudent['school_id'] = schoolId;
          enhancedStudent['academic_year'] =
              academicYear; // 🎯 Using extracted year
          enhancedStudent['period'] = period;

          // Generate student ID if not present
          if (enhancedStudent['student_id'] == null) {
            enhancedStudent['student_id'] =
                StudentIdentificationService.generateDeterministicStudentID(
              enhancedStudent['name']?.toString() ?? '',
              schoolId,
            );
            final stats =
                results['student_tracking_stats'] as Map<String, dynamic>;
            stats['student_ids_created'] =
                (stats['student_ids_created'] as int) + 1;
          }

          // Map to legacy learner table
          final learnerData = _mapToLegacyLearnerTable(enhancedStudent, period);

          // Insert into learners table
          await db.insert(
            'learners',
            learnerData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          successfulInserts++;
        } catch (e) {
          final errorMsg = 'Error processing ${student['name']}: $e';
          errors.add(errorMsg);
          if (kDebugMode) {
            debugPrint('   ❌ $errorMsg');
          }
        }
      }

      // Update results
      results['records_processed'] = successfulInserts;
      results['errors'] = errors;

      // 🎯 Update school academic years for legacy system too
      if (successfulInserts > 0 &&
          academicYear.isNotEmpty &&
          academicYear.contains('-')) {
        await _updateSchoolAcademicYears(
          schoolId,
          academicYear,
          successfulInserts,
        );
      }

      if (errors.isNotEmpty) {
        results['success'] = false;
        results['message'] = 'Import completed with ${errors.length} errors';
      }

      if (kDebugMode) {
        debugPrint('🔄 LEGACY SYSTEM: IMPORT COMPLETED');
        debugPrint('   Successful: $successfulInserts');
        debugPrint('   Errors: ${errors.length}');
        debugPrint('   Academic Year: $academicYear');
      }

      return results;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ LEGACY SYSTEM FAILED: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return {
        'success': false,
        'records_processed': 0,
        'errors': ['Legacy import failed: $e'],
        'message': 'Legacy import failed',
        'dual_table_system': false,
      };
    }
  }

  /// 🆕 NEW: Get students using dual-table structure
  static Future<List<Map<String, dynamic>>> getStudentsBySchoolAndPeriod(
    String schoolId,
    String period,
    String academicYear,
  ) async {
    try {
      final phase2TablesExist = await _verifyPhase2TablesExist();

      if (phase2TablesExist) {
        // Try to use dual-table system
        try {
          final db = await DatabaseService.instance.database;

          final learnerTable = period.toLowerCase() == 'baseline'
              ? 'baseline_learners'
              : 'endline_learners';
          final assessmentTable = period.toLowerCase() == 'baseline'
              ? 'baseline_assessments'
              : 'endline_assessments';

          final results = await db.rawQuery(
            '''
            SELECT 
              l.*,
              a.weight_kg, a.height_cm, a.bmi, a.nutritional_status,
              a.assessment_date, a.assessment_completeness
            FROM $learnerTable l
            LEFT JOIN $assessmentTable a ON l.id = a.learner_id
            WHERE l.school_id = ? AND l.academic_year = ?
          ''',
            [schoolId, academicYear],
          );

          return results;
        } catch (e) {
          // Fallback to legacy if dual-table query fails
          debugPrint('Dual-table query failed, using legacy: $e');
          return await _dbService.getLearnersBySchoolAndYear(
            schoolId,
            academicYear,
          );
        }
      } else {
        // Use legacy system
        return await _dbService.getLearnersBySchoolAndYear(
          schoolId,
          academicYear,
        );
      }
    } catch (e) {
      debugPrint('Error getting students: $e');
      return [];
    }
  }

  /// 🆕 NEW: Get student progress using dual-table structure
  static Future<List<Map<String, dynamic>>> getStudentProgressDualTable(
    String studentId,
  ) async {
    try {
      final phase2TablesExist = await _verifyPhase2TablesExist();

      if (phase2TablesExist) {
        // Try to get progress from both baseline and endline tables
        final db = await DatabaseService.instance.database;

        final progressResults = await db.rawQuery(
          '''
          SELECT 
            'Baseline' as period,
            l.learner_name, l.grade_level, l.section,
            a.weight_kg, a.height_cm, a.bmi, a.nutritional_status,
            a.assessment_date, l.academic_year
          FROM baseline_learners l
          JOIN baseline_assessments a ON l.id = a.learner_id
          WHERE l.student_id = ?
          
          UNION ALL
          
          SELECT 
            'Endline' as period,
            l.learner_name, l.grade_level, l.section,
            a.weight_kg, a.height_cm, a.bmi, a.nutritional_status,
            a.assessment_date, l.academic_year
          FROM endline_learners l
          JOIN endline_assessments a ON l.id = a.learner_id
          WHERE l.student_id = ?
          
          ORDER BY academic_year, period
        ''',
          [studentId, studentId],
        );

        return progressResults;
      } else {
        // Use legacy progress tracking
        return await _dbService.getStudentProgressAcrossYears(studentId);
      }
    } catch (e) {
      debugPrint('Error getting student progress: $e');
      return [];
    }
  }

  /// 🆕 NEW: Enhanced school statistics using dual-table structure
  static Future<Map<String, dynamic>> getSchoolStatisticsDualTable(
    String schoolId,
    String academicYear,
  ) async {
    try {
      final phase2TablesExist = await _verifyPhase2TablesExist();

      if (phase2TablesExist) {
        final db = await DatabaseService.instance.database;

        // Get baseline statistics
        final baselineStats = await db.rawQuery(
          '''
          SELECT 
            COUNT(*) as total_students,
            SUM(CASE WHEN a.nutritional_status LIKE '%wasted%' THEN 1 ELSE 0 END) as wasted_count,
            SUM(CASE WHEN a.nutritional_status = 'Normal' THEN 1 ELSE 0 END) as normal_count
          FROM baseline_learners l
          JOIN baseline_assessments a ON l.id = a.learner_id
          WHERE l.school_id = ? AND l.academic_year = ?
        ''',
          [schoolId, academicYear],
        );

        // Get endline statistics
        final endlineStats = await db.rawQuery(
          '''
          SELECT 
            COUNT(*) as total_students,
            SUM(CASE WHEN a.nutritional_status LIKE '%wasted%' THEN 1 ELSE 0 END) as wasted_count,
            SUM(CASE WHEN a.nutritional_status = 'Normal' THEN 1 ELSE 0 END) as normal_count
          FROM endline_learners l
          JOIN endline_assessments a ON l.id = a.learner_id
          WHERE l.school_id = ? AND l.academic_year = ?
        ''',
          [schoolId, academicYear],
        );

        final baselineData =
            baselineStats.isNotEmpty ? baselineStats.first : {};
        final endlineData = endlineStats.isNotEmpty ? endlineStats.first : {};

        // Calculate improvement
        final baselineTotal = (baselineData['total_students'] as int?) ?? 0;
        final endlineTotal = (endlineData['total_students'] as int?) ?? 0;
        final baselineWasted = (baselineData['wasted_count'] as int?) ?? 0;
        final endlineWasted = (endlineData['wasted_count'] as int?) ?? 0;
        final baselineNormal = (baselineData['normal_count'] as int?) ?? 0;
        final endlineNormal = (endlineData['normal_count'] as int?) ?? 0;

        final improvement = {
          'totalStudentsChange': endlineTotal - baselineTotal,
          'wastedReduction': baselineWasted - endlineWasted,
          'normalImprovement': endlineNormal - baselineNormal,
          'improvementRate': baselineTotal > 0
              ? ((baselineWasted - endlineWasted) / baselineTotal) * 100
              : 0,
        };

        return {
          'school_id': schoolId,
          'academic_year': academicYear,
          'baseline_stats': baselineData,
          'endline_stats': endlineData,
          'improvement': improvement,
          'calculated_at': DateTime.now().toIso8601String(),
          'dual_table_system': true,
        };
      } else {
        // Use legacy statistics
        return await _dbService.getSchoolStatisticsByYear(
          schoolId,
          academicYear,
        );
      }
    } catch (e) {
      debugPrint('Error getting school statistics: $e');
      return {'error': e.toString(), 'dual_table_system': false};
    }
  }

  /// 🆕 NEW: Migrate data from legacy to dual-table structure
  static Future<Map<String, dynamic>> migrateToDualTable() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 STARTING DATA MIGRATION TO DUAL-TABLE STRUCTURE...');
      }

      final db = await DatabaseService.instance.database;

      // Check if Phase 2 tables exist, if not create them
      final phase2TablesExist = await _verifyPhase2TablesExist();
      if (!phase2TablesExist) {
        // Create the dual-table structure
        await db.execute('''
          CREATE TABLE IF NOT EXISTS baseline_learners (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id TEXT NOT NULL,
            learner_name TEXT NOT NULL,
            lrn TEXT,
            sex TEXT NOT NULL,
            grade_level TEXT NOT NULL,
            section TEXT,
            date_of_birth TEXT,
            age INTEGER,
            school_id TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            academic_year TEXT NOT NULL,
            cloud_sync_id TEXT,
            last_synced TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(student_id, academic_year)
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS endline_learners (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id TEXT NOT NULL,
            learner_name TEXT NOT NULL,
            lrn TEXT,
            sex TEXT NOT NULL,
            grade_level TEXT NOT NULL,
            section TEXT,
            date_of_birth TEXT,
            age INTEGER,
            school_id TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            academic_year TEXT NOT NULL,
            cloud_sync_id TEXT,
            last_synced TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(student_id, academic_year)
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS baseline_assessments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            learner_id INTEGER NOT NULL,
            weight_kg REAL,
            height_cm REAL,
            bmi REAL,
            nutritional_status TEXT,
            assessment_date TEXT NOT NULL,
            assessment_completeness TEXT NOT NULL,
            created_at TEXT NOT NULL,
            cloud_sync_id TEXT,
            last_synced TEXT,
            FOREIGN KEY (learner_id) REFERENCES baseline_learners (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS endline_assessments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            learner_id INTEGER NOT NULL,
            weight_kg REAL,
            height_cm REAL,
            bmi REAL,
            nutritional_status TEXT,
            assessment_date TEXT NOT NULL,
            assessment_completeness TEXT NOT NULL,
            created_at TEXT NOT NULL,
            cloud_sync_id TEXT,
            last_synced TEXT,
            FOREIGN KEY (learner_id) REFERENCES endline_learners (id) ON DELETE CASCADE
          )
        ''');
      }

      // Migrate data from legacy learners table
      final legacyLearners = await db.rawQuery('''
        SELECT * FROM learners WHERE period IN ('Baseline', 'Endline')
      ''');

      int migratedCount = 0;
      final errors = <String>[];

      for (final learner in legacyLearners) {
        try {
          final period = learner['period']?.toString() ?? 'Baseline';
          final learnerTable = period.toLowerCase() == 'baseline'
              ? 'baseline_learners'
              : 'endline_learners';
          final assessmentTable = period.toLowerCase() == 'baseline'
              ? 'baseline_assessments'
              : 'endline_assessments';

          // Insert into appropriate learner table
          final learnerData = {
            'student_id': learner['student_id'] ?? '',
            'learner_name': learner['learner_name'] ?? '',
            'lrn': learner['lrn'],
            'sex': learner['sex'] ?? 'Unknown',
            'grade_level': learner['grade_name'] ?? 'Unknown',
            'section': learner['section'],
            'date_of_birth': learner['date_of_birth'],
            'age': learner['age'],
            'school_id': learner['school_id'] ?? '',
            'normalized_name': learner['normalized_name'] ?? '',
            'academic_year': learner['academic_year'] ?? '2023-2024',
            'cloud_sync_id': learner['cloud_sync_id'] ?? '',
            'last_synced': learner['last_synced'] ?? '',
            'created_at':
                learner['created_at'] ?? DateTime.now().toIso8601String(),
            'updated_at':
                learner['updated_at'] ?? DateTime.now().toIso8601String(),
          };

          final learnerId = await db.insert(
            learnerTable,
            learnerData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Insert assessment data
          final assessmentData = {
            'learner_id': learnerId,
            'weight_kg': learner['weight'],
            'height_cm': learner['height'],
            'bmi': learner['bmi'],
            'nutritional_status': learner['nutritional_status'] ?? 'Unknown',
            'assessment_date':
                learner['assessment_date'] ?? DateTime.now().toIso8601String(),
            'assessment_completeness':
                learner['assessment_completeness'] ?? 'Unknown',
            'created_at':
                learner['created_at'] ?? DateTime.now().toIso8601String(),
            'cloud_sync_id': learner['cloud_sync_id'] ?? '',
            'last_synced': learner['last_synced'] ?? '',
          };

          await db.insert(
            assessmentTable,
            assessmentData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          migratedCount++;
        } catch (e) {
          errors.add(
            'Failed to migrate learner ${learner['learner_name']}: $e',
          );
        }
      }

      final migrationResult = {
        'success': errors.isEmpty,
        'migrated_students': migratedCount,
        'total_legacy_students': legacyLearners.length,
        'errors': errors,
      };

      if (kDebugMode) {
        debugPrint('📊 MIGRATION RESULTS:');
        debugPrint('   Success: ${migrationResult['success']}');
        debugPrint('   Students Migrated: $migratedCount');
        debugPrint('   Total Legacy: ${legacyLearners.length}');
        debugPrint('   Errors: ${errors.length}');
      }

      return migrationResult;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ MIGRATION FAILED: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Migration failed',
      };
    }
  }

  /// 🆕 NEW: Verify Phase 2 tables exist
  static Future<bool> _verifyPhase2TablesExist() async {
    try {
      final db = await DatabaseService.instance.database;

      // Check if baseline_learners table exists
      final baselineCheck = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='baseline_learners'
      ''');

      // Check if endline_learners table exists
      final endlineCheck = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='endline_learners'
      ''');

      final baselineExists = baselineCheck.isNotEmpty;
      final endlineExists = endlineCheck.isNotEmpty;

      if (kDebugMode) {
        debugPrint('🔍 PHASE 2 TABLE VERIFICATION:');
        debugPrint('   baseline_learners: $baselineExists');
        debugPrint('   endline_learners: $endlineExists');
      }

      return baselineExists && endlineExists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error verifying Phase 2 tables: $e');
      }
      return false;
    }
  }

  /// 🆕 NEW: Enhanced dietary planning with dual-table structure
  static Future<DietaryPlanResult> generateDietaryPlanDualTable(
    String studentId,
  ) async {
    try {
      // Get student progress data
      final progressData = await getStudentProgressDualTable(studentId);

      if (progressData.isEmpty) {
        throw Exception('No assessment data found for student: $studentId');
      }

      // Use the latest assessment
      final latestAssessment = progressData.last;

      // Get all available food items
      final allFoodItems = await _foodRepo.getAllFoodItems();

      // Parse nutritional status
      final nutritionalStatus = _parseNutritionalStatus(
        latestAssessment['nutritional_status']?.toString(),
      );

      // Apply dietary logic based on status
      List<FoodItem> recommendedFoods = [];
      String planName = 'Basic Nutrition Plan';
      String planDescription = 'General nutritional support';

      if (nutritionalStatus == NutritionalStatus.severelyMalnourished) {
        recommendedFoods = _getHighCalorieFoods(allFoodItems);
        planName = 'High-Calorie Recovery Plan';
        planDescription = 'Energy-dense foods for weight recovery';
      } else if (nutritionalStatus == NutritionalStatus.underweight) {
        recommendedFoods = _getBalancedWeightGainFoods(allFoodItems);
        planName = 'Weight Gain Support Plan';
        planDescription = 'Balanced nutrition for healthy weight gain';
      } else if (nutritionalStatus == NutritionalStatus.overweight ||
          nutritionalStatus == NutritionalStatus.obese) {
        recommendedFoods = _getWeightManagementFoods(allFoodItems);
        planName = 'Weight Management Plan';
        planDescription = 'Balanced nutrition for healthy weight management';
      } else {
        recommendedFoods = _getMaintenanceFoods(allFoodItems);
        planName = 'Maintenance Nutrition Plan';
        planDescription = 'Balanced diet for maintaining health';
      }

      // Calculate nutritional totals
      final totalDailyCalories = recommendedFoods.fold(
        0.0,
        (sum, food) => sum + food.averageCalories,
      );
      final totalDailyProtein = recommendedFoods.fold(
        0.0,
        (sum, food) => sum + food.minProtein,
      );

      // Analyze food type distribution
      final foodTypeDistribution = <String, int>{};
      for (final food in recommendedFoods) {
        foodTypeDistribution[food.foodType] =
            (foodTypeDistribution[food.foodType] ?? 0) + 1;
      }

      return DietaryPlanResult(
        planName: planName,
        description: planDescription,
        recommendedFoods: recommendedFoods,
        totalDailyCalories: totalDailyCalories,
        totalDailyProtein: totalDailyProtein,
        foodTypeDistribution: foodTypeDistribution,
      );
    } catch (e) {
      debugPrint('Error generating dietary plan: $e');
      rethrow;
    }
  }

  // ========== COMPATIBILITY METHODS ==========

  /// 🛠️ UPDATED: Main import method with automatic dual-table detection
  static Future<ImportResult> importExcelFile(
    String filePath,
    String schoolId, {
    required String academicYear,
  }) async {
    return await importExcelFileWithDualTable(filePath, schoolId);
  }

  /// 🛠️ UPDATED: Cloud preparation import
  static Future<ImportResult> importExcelFileWithCloudPrep(
    String filePath,
    String schoolId,
    SchoolProfile dashboardProfile,
  ) async {
    // Use the dual-table version
    final result = await importExcelFileWithDualTable(filePath, schoolId);

    // Enhance with cloud-specific information
    return ImportResult(
      success: result.success,
      message: result.message,
      recordsProcessed: result.recordsProcessed,
      errors: result.errors,
      readyForCloudSync: result.success && result.recordsProcessed > 0,
      importBatchId: 'cloud_${DateTime.now().millisecondsSinceEpoch}',
      importTimestamp: DateTime.now(),
      validationSummary: {
        ...result.validationSummary,
        'cloud_ready': result.success && result.recordsProcessed > 0,
      },
      receivedFrom: '',
      dataType: '',
      breakdown: {},
      batchId: '',
      totalRecords: 0,
    );
  }

  /// 🛠️ UPDATED: Get student progress (maintains backward compatibility)
  static Future<List<Map<String, dynamic>>> getStudentProgress(
    String studentId,
  ) async {
    return await getStudentProgressDualTable(studentId);
  }

  /// 🛠️ UPDATED: Get students by school (maintains backward compatibility)
  static Future<List<Map<String, dynamic>>> getStudentsBySchool(
    String schoolId,
    String academicYear,
  ) async {
    // For backward compatibility, return baseline students
    return await getStudentsBySchoolAndPeriod(
      schoolId,
      'Baseline',
      academicYear,
    );
  }

  // ========== EXISTING ORIGINAL METHODS (PRESERVED) ==========

  /// 🛠️ ENHANCED: Main import method with PERIOD PRESERVATION
  /// Now uses dual-table structure automatically
  static Future<ImportResult> importExcelFileOriginal(
    String filePath,
    String schoolId,
  ) async {
    // Delegate to the new dual-table method
    return await importExcelFileWithDualTable(filePath, schoolId);
  }

  /// 🛠️ ENHANCED: Save with automatic fallback if Phase 2 tables don't exist
  static Future<Map<String, dynamic>> _saveStudentRecordsWithDualTable(
    List<Map<String, dynamic>> students,
    String schoolId,
    String period,
    Map<String, dynamic> importMetadata,
  ) async {
    // Delegate to the appropriate system
    final phase2TablesExist = await _verifyPhase2TablesExist();

    if (phase2TablesExist) {
      return await _saveWithDualTableSystem(
        students,
        schoolId,
        period,
        importMetadata,
      );
    } else {
      return await _saveWithLegacySystem(
        students,
        schoolId,
        period,
        importMetadata,
      );
    }
  }

  /// 🛠️ LEGACY: Fallback system using original learners table
  static Future<Map<String, dynamic>> _saveStudentRecordsLegacy(
    List<Map<String, dynamic>> students,
    String schoolId,
    String period,
    Map<String, dynamic> importMetadata,
  ) async {
    return await _saveWithLegacySystem(
      students,
      schoolId,
      period,
      importMetadata,
    );
  }

  /// 🛠️ CRITICAL: Force database migration if needed
  static Future<bool> ensureDatabaseMigration() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 CHECKING DATABASE MIGRATION STATUS...');
      }

      // Close and reopen database to trigger migration
      await DatabaseService.instance.close();

      // Reopen database - this should trigger onUpgrade if needed
      final db = await DatabaseService.instance.database;

      // Verify Phase 2 tables exist
      final phase2TablesExist = await _verifyPhase2TablesExist();

      if (kDebugMode) {
        debugPrint('📊 DATABASE MIGRATION STATUS:');
        debugPrint('   Phase 2 tables exist: $phase2TablesExist');
        if (!phase2TablesExist) {
          debugPrint('   ⚠️ Database may need manual migration');
        }
      }

      return phase2TablesExist;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DATABASE MIGRATION CHECK FAILED: $e');
      }
      return false;
    }
  }

  // ========== DIETARY SERVICES INTEGRATION ==========

  // 1. STUDENT DIETARY SUGGESTION FUNCTION
  static Future<DietaryPlanResult> generateDietaryPlan(String studentId) async {
    return await generateDietaryPlanDualTable(studentId);
  }

  // 2. DYNAMIC PROJECTED HEALTH STATUS FUNCTION
  static Future<HealthProjectionResult> getProjectedHealthStatus({
    required String studentId,
    required Set<int> daysAbsent,
    required int projectionDays,
    required String studentUid,
  }) async {
    try {
      // 1. FETCH BASE STUDENT DATA FROM DATABASE
      final studentData = await _getStudentData(studentId);
      final currentWeight = studentData['weight'] as double? ?? 0.0;

      // 2. GET DIETARY PLAN FROM FOODDB FOR CALORIE CALCULATION
      final dietaryPlan = await generateDietaryPlan(studentId);
      final dailyCalorieSurplus = dietaryPlan.totalDailyCalories;

      // 3. CALCULATE DAILY WEIGHT GAIN
      const int caloriesPerKgGain = 7700;
      final double dailyGainKg = dailyCalorieSurplus / caloriesPerKgGain;

      // 4. PERFORM DYNAMIC PROJECTION
      final Map<int, double> dailyProjections = {};
      double currentProjectedWeight = currentWeight;

      for (int day = 1; day <= projectionDays; day++) {
        if (!daysAbsent.contains(day)) {
          // Student is present - apply weight gain from SBFP nutrition
          currentProjectedWeight += dailyGainKg;
        }
        // If absent, weight remains the same (no SBFP nutrition)

        dailyProjections[day] = double.parse(
          currentProjectedWeight.toStringAsFixed(2),
        );
      }

      // 5. CALCULATE SUMMARY STATISTICS
      final totalWeightGain = dailyProjections[projectionDays]! - currentWeight;
      final presentDays = projectionDays - daysAbsent.length;

      // 6. RETURN COMPLETE PROJECTION RESULT
      return HealthProjectionResult(
        initialWeight: currentWeight,
        projectedFinalWeight: dailyProjections[projectionDays]!,
        totalWeightGain: double.parse(totalWeightGain.toStringAsFixed(2)),
        dailyProjections: dailyProjections,
        totalFeedingDays: projectionDays,
        absentDays: daysAbsent.length,
      );
    } catch (e) {
      debugPrint('Error generating health projection: $e');
      rethrow;
    }
  }

  // 3. GET STUDENT ATTENDANCE DATA FOR PROJECTION
  static Future<Set<int>> getStudentAbsenceDays(
    String studentId,
    int totalDays,
  ) async {
    try {
      // This would fetch actual attendance data from database
      // For now, return empty set (no absences) or implement based on your attendance records
      return <int>{};
    } catch (e) {
      debugPrint('Error getting student attendance: $e');
      return <int>{};
    }
  }

  // 4. GET MULTIPLE STUDENTS DIETARY PLANS (BATCH PROCESSING)
  static Future<Map<String, DietaryPlanResult>> getBatchDietaryPlans(
    List<String> studentIds,
  ) async {
    final results = <String, DietaryPlanResult>{};
    for (final studentId in studentIds) {
      try {
        final plan = await generateDietaryPlan(studentId);
        results[studentId] = plan;
      } catch (e) {
        debugPrint('Error generating plan for student $studentId: $e');
        // Continue with other students even if one fails
      }
    }
    return results;
  }

  // ========== HELPER METHODS ==========

  // Food Selection Logic Methods (Empty database fallback)
  static List<FoodItem> _getSevereCatchUpFoods(List<FoodItem> allFoods) {
    if (allFoods.isEmpty) return [];
    return allFoods
        .where(
          (food) =>
              food.dietaryFocus.contains('High-Calorie') &&
              food.minProtein >= 5.0,
        )
        .take(4)
        .toList();
  }

  static List<FoodItem> _getHighCalorieFoods(List<FoodItem> allFoods) {
    if (allFoods.isEmpty) return [];
    return allFoods
        .where((food) => food.averageCalories >= 250)
        .take(3)
        .toList();
  }

  static List<FoodItem> _getHighProteinFoods(List<FoodItem> allFoods) {
    if (allFoods.isEmpty) return [];
    return allFoods.where((food) => food.minProtein >= 5.0).take(3).toList();
  }

  static List<FoodItem> _getBalancedWeightGainFoods(List<FoodItem> allFoods) {
    if (allFoods.isEmpty) return [];
    return allFoods
        .where((food) => food.averageCalories >= 200 && food.minProtein >= 3.0)
        .take(3)
        .toList();
  }

  static List<FoodItem> _getWeightManagementFoods(List<FoodItem> allFoods) {
    if (allFoods.isEmpty) return [];
    return allFoods
        .where(
          (food) =>
              food.averageCalories <= 200 &&
              food.dietaryFocus.contains('Balanced'),
        )
        .take(3)
        .toList();
  }

  static List<FoodItem> _getMaintenanceFoods(List<FoodItem> allFoods) {
    if (allFoods.isEmpty) return [];
    return allFoods
        .where(
          (food) =>
              food.targetStatus == 'Normal' ||
              food.dietaryFocus.contains('Balanced'),
        )
        .take(2)
        .toList();
  }

  /// Helper method to get student data for dietary planning
  static Future<Map<String, dynamic>> _getStudentData(String studentId) async {
    try {
      // Try to get data using the dual-table structure first
      final progressData = await getStudentProgressDualTable(studentId);
      if (progressData.isNotEmpty) {
        final latestAssessment = progressData.last;
        return {
          'nutritional_status':
              latestAssessment['nutritional_status'] ?? 'Unknown',
          'height_for_age_status':
              latestAssessment['height_for_age_status'] ?? 'Unknown',
          'weight': latestAssessment['weight_kg'] ?? 0.0,
          'height': latestAssessment['height_cm'] ?? 0.0,
          'age': latestAssessment['age'] ?? 0,
          'learner_name': latestAssessment['learner_name'] ?? 'Unknown',
          'academic_year': latestAssessment['academic_year'] ?? '2023-2024',
        };
      }

      // Fallback to legacy method if dual-table fails
      final allLearners = await _dbService.getAllLearners();

      // Find student by student_id field
      final student = allLearners.firstWhere(
        (learner) => learner['student_id'] == studentId,
        orElse: () => throw Exception('Student not found with ID: $studentId'),
      );

      return {
        'nutritional_status': student['nutritional_status'] ?? 'Unknown',
        'height_for_age_status': student['height_for_age_status'] ?? 'Unknown',
        'weight': student['weight'] ?? 0.0,
        'height': student['height'] ?? 0.0,
        'age': student['age'] ?? 0,
        'learner_name': student['learner_name'] ?? 'Unknown',
        'academic_year': student['academic_year'] ?? '2023-2024',
      };
    } catch (e) {
      debugPrint('Error fetching student data: $e');
      rethrow;
    }
  }

  // Status Parsing Methods
  static NutritionalStatus _parseNutritionalStatus(String? status) {
    final statusStr = (status ?? '').toLowerCase();
    if (statusStr.contains('severely') && statusStr.contains('wasted')) {
      return NutritionalStatus.severelyWasted;
    }
    if (statusStr.contains('severely') && statusStr.contains('malnourished')) {
      return NutritionalStatus.severelyMalnourished;
    }
    if (statusStr.contains('wasted')) return NutritionalStatus.wasted;
    if (statusStr.contains('underweight')) return NutritionalStatus.underweight;
    if (statusStr.contains('overweight')) return NutritionalStatus.overweight;
    if (statusStr.contains('obese')) return NutritionalStatus.obese;
    return NutritionalStatus.normal;
  }

  // Utility method to get available food types
  static Future<List<String>> getAvailableFoodTypes() async {
    return await _foodRepo.getAvailableFoodTypes();
  }

  // Utility method to get foods by type
  static Future<List<FoodItem>> getFoodsByType(String foodType) async {
    return await _foodRepo.getFoodItemsByType(foodType);
  }

  /// NEW: Get student progress across multiple years
  static Future<List<Map<String, dynamic>>> getStudentProgressOriginal(
    String studentId,
  ) async {
    try {
      return await _dbService.getStudentProgressAcrossYears(studentId);
    } catch (e) {
      debugPrint('Error getting student progress: $e');
      return [];
    }
  }

  /// 🛠️ ENHANCED: Endline import with dual-table support
  static Future<ImportResult> importEndlineExcelFile(
    String filePath,
    String schoolId,
  ) async {
    try {
      debugPrint('🎯 === DEDICATED ENDLINE IMPORT START ===');

      // 1. Get school profile
      final schoolProfile = await _getSchoolProfile(schoolId);
      if (schoolProfile == null) {
        throw Exception('School profile not found for Endline import');
      }

      // 2. Extract with explicit Endline focus
      final cleanResult = await ExcelCleaner.cleanSchoolExcel(
        filePath,
        dashboardProfile: schoolProfile,
        strictValidation: true,
      );

      debugPrint('📊 ENDLINE EXTRACTION: ${cleanResult.data.length} records');

      // 🛠️ CRITICAL FIX: Force Endline period at data level
      final endlineData = cleanResult.data.map((student) {
        return {
          ...student,
          'period': 'Endline', // 🛠️ FORCE Endline period at data level
          'assessment_period': 'Endline',
          // 🛠️ CRITICAL: Ensure metadata reflects Endline
          'import_period': 'Endline',
        };
      }).toList();

      debugPrint('🔍 ENHANCED ENDLINE DATA SAMPLE:');
      for (int i = 0; i < endlineData.length && i < 3; i++) {
        final student = endlineData[i];
        debugPrint(
          '   ${i + 1}. ${student['name']} - Period: ${student['period']} - Weight: ${student['weight_kg']}',
        );
      }

      // Use dual-table import system
      final dbResult =
          await _saveWithDualTableSystem(endlineData, schoolId, 'Endline', {
        'school_year':
            cleanResult.reportMetadata?['school_year'] ?? '2023-2024',
        'school_name':
            cleanResult.reportMetadata?['school_name'] ?? 'Unknown School',
      });

      return ImportResult(
        success: dbResult['success'] == true,
        message: dbResult['message'] ?? 'Endline import completed',
        recordsProcessed: dbResult['records_processed'] ?? 0,
        errors: dbResult['errors'] is List
            ? List<String>.from(dbResult['errors'] as List)
            : null,
        validationSummary: {
          'dual_table_system': true,
          'import_period': 'Endline',
        },
        receivedFrom: '',
        dataType: '',
        breakdown: {},
        batchId: '',
        totalRecords: 0,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ ENDLINE IMPORT FAILED: $e');
      debugPrint('Stack trace: $stackTrace');
      return ImportResult(
        success: false,
        message: 'Endline import failed: $e',
        recordsProcessed: 0,
        errors: [e.toString()],
        validationSummary: {'dual_table_system': false},
        receivedFrom: '',
        dataType: '',
        breakdown: {},
        batchId: '',
        totalRecords: 0,
      );
    }
  }

  /// 🎯 CRITICAL: Check Endline import status
  static Future<void> checkEndlineImportStatus(String schoolId) async {
    try {
      final db = await DatabaseService.instance.database;

      debugPrint('🔍 === ENDLINE IMPORT STATUS CHECK ===');

      // 1. Check import history for Endline imports
      final importHistory = await db.rawQuery(
        '''
      SELECT file_name, import_date, period, records_processed, import_status
      FROM import_history 
      WHERE school_id = ? 
      ORDER BY import_date DESC
      LIMIT 10
    ''',
        [schoolId],
      );

      debugPrint('📋 IMPORT HISTORY:');
      for (final import in importHistory) {
        debugPrint(
          '   📁 ${import['file_name']} | ${import['period']} | ${import['import_status']} | ${import['records_processed']} records | ${import['import_date']}',
        );
      }

      // 2. Check actual Endline records in database
      final endlineCount = await db.rawQuery(
        '''
      SELECT COUNT(*) as count FROM learners 
      WHERE school_id = ? AND period = 'Endline'
    ''',
        [schoolId],
      );

      final totalCount = await db.rawQuery(
        '''
      SELECT COUNT(*) as count FROM learners 
      WHERE school_id = ?
    ''',
        [schoolId],
      );

      debugPrint('📊 DATABASE COUNTS:');
      debugPrint('   Total students: ${totalCount.first['count']}');
      debugPrint('   Endline students: ${endlineCount.first['count']}');

      // 3. Check if Endline records have assessment data
      final endlineWithData = await db.rawQuery(
        '''
      SELECT COUNT(*) as count FROM learners 
      WHERE school_id = ? AND period = 'Endline' 
      AND height IS NOT NULL AND weight IS NOT NULL
    ''',
        [schoolId],
      );

      debugPrint(
        '   Endline with height/weight: ${endlineWithData.first['count']}',
      );

      // 4. Show sample Endline records
      final sampleEndline = await db.rawQuery(
        '''
      SELECT learner_name, academic_year, height, weight, student_id
      FROM learners 
      WHERE school_id = ? AND period = 'Endline'
      LIMIT 5
    ''',
        [schoolId],
      );

      debugPrint('🎯 SAMPLE ENDLINE RECORDS:');
      for (final record in sampleEndline) {
        debugPrint(
          '   👤 ${record['learner_name']} | ${record['academic_year']} | H:${record['height']} | W:${record['weight']} | ID:${record['student_id']}',
        );
      }
    } catch (e) {
      debugPrint('❌ Status check failed: $e');
    }
  }

  static Future<void> fixEndlineStudentIds(String schoolId) async {
    try {
      final dbService = DatabaseService.instance;
      final db = await dbService.database;

      debugPrint('🔧 EXECUTING ENDLINE STUDENT ID FIX...');

      // Get all Endline records with problematic student IDs
      final problemRecords = await db.rawQuery(
        '''
      SELECT 
        l.id, 
        l.learner_name, 
        l.student_id, 
        l.academic_year,
        l.grade_name,
        l.section
      FROM learners l
      WHERE l.school_id = ? 
        AND l.period = 'Endline' 
        AND (l.student_id IS NULL 
             OR l.student_id = '' 
             OR l.student_id LIKE 'learner_%'
             OR l.student_id NOT IN (
               SELECT DISTINCT student_id 
               FROM learners 
               WHERE school_id = ? 
                 AND period = 'Baseline' 
                 AND student_id IS NOT NULL 
                 AND student_id != ''
             ))
    ''',
        [schoolId, schoolId],
      );

      debugPrint(
        '📋 Found ${problemRecords.length} Endline records needing ID fix',
      );

      int fixedCount = 0;
      int newIdCount = 0;

      for (final record in problemRecords) {
        final recordId = record['id'] as String;
        final studentName = record['learner_name'] as String;
        final academicYear = record['academic_year'] as String;

        debugPrint('🔄 Processing: $studentName ($academicYear)');

        // STRATEGY 1: Find matching Baseline record
        final baselineMatch = await db.rawQuery(
          '''
        SELECT student_id 
        FROM learners 
        WHERE school_id = ?
          AND learner_name = ? 
          AND academic_year = ? 
          AND period = 'Baseline'
          AND student_id IS NOT NULL 
          AND student_id != ''
        LIMIT 1
      ''',
          [schoolId, studentName, academicYear],
        );

        if (baselineMatch.isNotEmpty) {
          // FOUND MATCH: Use Baseline student ID
          final correctStudentId = baselineMatch.first['student_id'] as String;

          await db.update(
            'learners',
            {
              'student_id': correctStudentId,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [recordId],
          );

          fixedCount++;
          debugPrint(
            '✅ Fixed: $studentName → $correctStudentId (Baseline match)',
          );
        } else {
          // STRATEGY 2: Generate new consistent student ID
          final newStudentId = DatabaseService.generateStudentID(
            studentName,
            schoolId,
          );

          await db.update(
            'learners',
            {
              'student_id': newStudentId,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [recordId],
          );

          newIdCount++;
          debugPrint(
            '🆕 New ID: $studentName → $newStudentId (no Baseline match)',
          );
        }
      }

      debugPrint('🎯 ENDLINE FIX COMPLETED:');
      debugPrint('   Fixed with Baseline match: $fixedCount records');
      debugPrint('   Assigned new IDs: $newIdCount records');
      debugPrint('   Total processed: ${fixedCount + newIdCount} records');
    } catch (e, stackTrace) {
      debugPrint('❌ ENDLINE FIX FAILED: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Enhanced student progress query that handles Endline records properly
  static Future<List<Map<String, dynamic>>> getStudentProgressWithEndline(
    String studentId,
  ) async {
    try {
      final db = await DatabaseService.instance.database;

      debugPrint('🔍 ENHANCED PROGRESS QUERY FOR: $studentId');

      // First, get ALL records for this student ID (both Baseline and Endline)
      final allRecords = await db.rawQuery(
        '''
      SELECT 
        id,
        student_id,
        learner_name,
        grade_name,
        grade_level_id,
        sex,
        date_of_birth,
        age,
        nutritional_status,
        assessment_period,
        assessment_date,
        height,
        weight,
        bmi,
        lrn,
        section,
        academic_year,
        period,
        assessment_completeness,
        created_at,
        updated_at
      FROM learners 
      WHERE student_id = ? 
      ORDER BY 
        academic_year ASC,
        CASE 
          WHEN period = 'Baseline' THEN 1
          WHEN period = 'Endline' THEN 2
          ELSE 3
        END,
        assessment_date ASC
    ''',
        [studentId],
      );

      debugPrint(
        '📊 ENHANCED QUERY RESULTS: ${allRecords.length} total records',
      );

      // Debug: Show what we found
      if (allRecords.isNotEmpty) {
        debugPrint('📋 RECORD BREAKDOWN:');
        final periods = <String, int>{};
        final years = <String, int>{};

        for (final record in allRecords) {
          final period = record['period']?.toString() ?? 'Unknown';
          final year = record['academic_year']?.toString() ?? 'Unknown';

          periods[period] = (periods[period] ?? 0) + 1;
          years[year] = (years[year] ?? 0) + 1;

          if (kDebugMode) {
            debugPrint('   - $period ($year): ${record['learner_name']}');
            debugPrint(
              '     Weight: ${record['weight']}, Height: ${record['height']}',
            );
          }
        }

        debugPrint('🎯 PERIOD DISTRIBUTION: $periods');
        debugPrint('🎯 YEAR DISTRIBUTION: $years');
      }

      return allRecords;
    } catch (e, stackTrace) {
      debugPrint('❌ ENHANCED PROGRESS QUERY ERROR: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Diagnostic method to check Endline data issues
  static Future<Map<String, dynamic>> diagnoseEndlineIssues(
    String schoolId,
  ) async {
    try {
      final db = await DatabaseService.instance.database;

      debugPrint('🔍 DIAGNOSING ENDLINE ISSUES FOR SCHOOL: $schoolId');

      // 1. Check period distribution
      final periodDistribution = await db.rawQuery(
        '''
      SELECT period, COUNT(*) as count 
      FROM learners 
      WHERE school_id = ? 
      GROUP BY period
    ''',
        [schoolId],
      );

      debugPrint('📊 PERIOD DISTRIBUTION:');
      for (final row in periodDistribution) {
        debugPrint('   ${row['period']}: ${row['count']} records');
      }

      // 2. Check student ID consistency between Baseline and Endline
      final idConsistency = await db.rawQuery(
        '''
      SELECT 
        COUNT(DISTINCT baseline.student_id) as baseline_students,
        COUNT(DISTINCT endline.student_id) as endline_students,
        COUNT(DISTINCT CASE WHEN baseline.student_id = endline.student_id THEN baseline.student_id END) as matched_students
      FROM learners baseline
      LEFT JOIN learners endline ON 
        baseline.learner_name = endline.learner_name 
        AND baseline.academic_year = endline.academic_year
        AND baseline.school_id = endline.school_id
        AND endline.period = 'Endline'
      WHERE baseline.school_id = ? 
        AND baseline.period = 'Baseline'
    ''',
        [schoolId],
      );

      final baselineStudents = idConsistency.first['baseline_students'] as int;
      final endlineStudents = idConsistency.first['endline_students'] as int;
      final matchedStudents = idConsistency.first['matched_students'] as int;

      debugPrint('🎯 STUDENT ID CONSISTENCY:');
      debugPrint('   Baseline students: $baselineStudents');
      debugPrint('   Endline students: $endlineStudents');
      debugPrint('   Matched students: $matchedStudents');
      debugPrint(
        '   Match rate: ${baselineStudents > 0 ? (matchedStudents / baselineStudents * 100).toStringAsFixed(1) : 0}%',
      );

      // 3. Check problematic Endline records
      final problemEndline = await db.rawQuery(
        '''
      SELECT COUNT(*) as count
      FROM learners 
      WHERE school_id = ? 
        AND period = 'Endline' 
        AND (student_id IS NULL 
             OR student_id = '' 
             OR student_id LIKE 'learner_%'
             OR student_id NOT IN (
               SELECT DISTINCT student_id 
               FROM learners 
               WHERE school_id = ? 
                 AND period = 'Baseline'
             ))
    ''',
        [schoolId, schoolId],
      );

      final problemCount = problemEndline.first['count'] as int;

      debugPrint('🚨 PROBLEMATIC ENDLINE RECORDS: $problemCount');

      return {
        'period_distribution': {
          for (var row in periodDistribution)
            row['period'].toString(): row['count'],
        },
        'student_id_consistency': {
          'baseline_students': baselineStudents,
          'endline_students': endlineStudents,
          'matched_students': matchedStudents,
          'match_rate': baselineStudents > 0
              ? (matchedStudents / baselineStudents * 100).round()
              : 0,
        },
        'problematic_endline_records': problemCount,
        'needs_fix': problemCount > 0,
      };
    } catch (e) {
      debugPrint('❌ DIAGNOSIS FAILED: $e');
      return {'error': e.toString()};
    }
  }

  /// NEW: Get assessment completeness for school
  static Future<List<Map<String, dynamic>>> getAssessmentCompleteness(
    String schoolId,
    String academicYear,
  ) async {
    try {
      return await _dbService.getAssessmentCompleteness(schoolId, academicYear);
    } catch (e) {
      debugPrint('Error getting assessment completeness: $e');
      return [];
    }
  }

  /// NEW: Find students by name similarity
  static Future<List<Map<String, dynamic>>> findStudentsByNameSimilarity(
    String name,
    String schoolId,
  ) async {
    try {
      return await _dbService.findStudentsByNameSimilarity(name, schoolId);
    } catch (e) {
      debugPrint('Error finding students by name similarity: $e');
      return [];
    }
  }

  /// NEW: Generate student progress report
  static Future<Map<String, dynamic>> generateStudentProgressReport(
    String studentId,
  ) async {
    try {
      final progressData = await getStudentProgress(studentId);
      if (progressData.isEmpty) {
        return {
          'student_id': studentId,
          'has_data': false,
          'message': 'No progress data found for this student',
        };
      }

      // Analyze progress
      final years = progressData
          .map((e) => e['academic_year']?.toString())
          .toSet()
          .toList();
      years.sort();

      final baselineData = progressData
          .where((e) => e['period']?.toString() == 'Baseline')
          .toList();

      final endlineData = progressData
          .where((e) => e['period']?.toString() == 'Endline')
          .toList();

      return {
        'student_id': studentId,
        'student_name': progressData.first['learner_name'] ?? 'Unknown',
        'has_data': true,
        'years_tracked': years,
        'total_assessments': progressData.length,
        'baseline_assessments': baselineData.length,
        'endline_assessments': endlineData.length,
        'completeness_score': _calculateCompletenessScore(
          baselineData.length,
          endlineData.length,
          years.length,
        ),
        'progress_data': progressData,
        'summary': _generateProgressSummary(progressData),
      };
    } catch (e) {
      debugPrint('Error generating student progress report: $e');
      return {
        'student_id': studentId,
        'has_data': false,
        'error': e.toString(),
      };
    }
  }

  static double _calculateCompletenessScore(
    int baselineCount,
    int endlineCount,
    int yearCount,
  ) {
    final totalPossible = yearCount * 2; // Baseline + Endline per year
    if (totalPossible == 0) return 0.0;
    return ((baselineCount + endlineCount) / totalPossible) * 100;
  }

  static String _generateProgressSummary(
    List<Map<String, dynamic>> progressData,
  ) {
    if (progressData.isEmpty) return 'No data available';
    final statusChanges = <String>[];
    String? lastStatus;

    for (final assessment in progressData) {
      final currentStatus = assessment['nutritional_status']?.toString();
      if (currentStatus != null && currentStatus != lastStatus) {
        if (lastStatus != null) {
          statusChanges.add('$lastStatus → $currentStatus');
        }
        lastStatus = currentStatus;
      }
    }

    if (statusChanges.isNotEmpty) {
      return 'Nutritional status changes: ${statusChanges.join(', ')}';
    } else {
      return 'Stable nutritional status: ${lastStatus ?? "Unknown"}';
    }
  }

  /// 🛠️ ENHANCED: Cloud preparation import with PERIOD PRESERVATION
  static Future<ImportResult> importExcelFileWithCloudPrepOriginal(
    String filePath,
    String schoolId,
    SchoolProfile dashboardProfile,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint(
          '🔍 ========== CLOUD IMPORT WITH PERIOD PRESERVATION START ==========',
        );
        debugPrint('   File Path: $filePath');
        debugPrint('   School ID: $schoolId');
        debugPrint('   Dashboard Profile: ${dashboardProfile.schoolName}');
        debugPrint('   Using STUDENT TRACKING mode');
      }

      // 🛑 CRITICAL FIX: Enforce stop if the dashboard profile is missing
      if (dashboardProfile.schoolName.isEmpty) {
        final errorMessage =
            'Cannot proceed: Dashboard School Profile is invalid or missing. Please set up the school profile first.';
        if (kDebugMode) {
          debugPrint('❌ CRITICAL ERROR: $errorMessage');
        }
        return ImportResult(
          success: false,
          message: errorMessage,
          recordsProcessed: 0,
          readyForCloudSync: false,
          importBatchId: '',
          importTimestamp: DateTime.now(),
          validationSummary: {
            'valid': false,
            'reason': 'Dashboard school profile missing',
            'school_profile_match': false,
            'expected_school': 'Not available',
            'validation_errors': [errorMessage],
          },
          receivedFrom: '',
          dataType: '',
          breakdown: {},
          batchId: '',
          totalRecords: 0,
        );
      }

      // Step 1: Extract and clean data from Excel WITH STRICT VALIDATION
      final cleanResult = await ExcelCleaner.cleanSchoolExcel(
        filePath,
        dashboardProfile: dashboardProfile,
        strictValidation: true,
      );

      // 🛠️ CRITICAL: Detect and preserve period from Excel
      final detectedPeriod =
          cleanResult.reportMetadata?['period']?.toString() ?? 'Baseline';

      if (kDebugMode) {
        debugPrint('🎯 CLOUD IMPORT - DETECTED PERIOD: $detectedPeriod');
        debugPrint('📊 CLOUD EXCEL CLEANER RESULTS:');
        debugPrint('   Success: ${cleanResult.success}');
        debugPrint('   Data Count: ${cleanResult.data.length}');
        debugPrint(
          '   Has Validation: ${cleanResult.validationResult != null}',
        );
      }

      // ========== CRITICAL VALIDATION BLOCK ==========
      if (cleanResult.validationResult?.isValid == false) {
        if (kDebugMode) {
          debugPrint('❌ CLOUD VALIDATION FAILED - IMPORT BLOCKED');
        }
        // Enhanced error message
        final extractedSchool =
            cleanResult.validationResult?.matchedSchoolName ?? 'Unknown School';
        final errorDetails = cleanResult.validationResult?.errors.join(', ') ??
            'School profile mismatch';
        return ImportResult(
          success: false,
          message: '🚫 IMPORT BLOCKED: School profile validation failed. '
              'Expected "${dashboardProfile.schoolName}" but file contains "$extractedSchool". '
              'Details: $errorDetails',
          recordsProcessed: 0,
          readyForCloudSync: false,
          importBatchId: '',
          importTimestamp: DateTime.now(),
          validationSummary: {
            'valid': false,
            'reason': 'School name mismatch',
            'school_profile_match': false,
            'expected_school': dashboardProfile.schoolName,
            'extracted_school': extractedSchool,
            'validation_errors': cleanResult.validationResult?.errors ?? [],
          },
          receivedFrom: '',
          dataType: '',
          breakdown: {},
          batchId: '',
          totalRecords: 0,
        );
      }
      // ========== END CRITICAL VALIDATION BLOCK ==========

      // ENHANCED: Critical nutritional status verification before proceeding
      if (kDebugMode) {
        _verifyNutritionalStatusData(cleanResult);
      }

      if (!cleanResult.success || cleanResult.data.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ CLOUD IMPORT - NO VALID DATA');
        }
        return ImportResult(
          success: false,
          message:
              'No student records found in Excel file. Please verify the file contains valid student data in the correct format.',
          recordsProcessed: 0,
          readyForCloudSync: false,
          importBatchId: '',
          importTimestamp: DateTime.now(),
          validationSummary: {
            'valid': false,
            'reason': 'No valid student data found',
            'problems': cleanResult.problems,
          },
          receivedFrom: '',
          dataType: '',
          breakdown: {},
          batchId: '',
          totalRecords: 0,
        );
      }

      // 🆕 NEW: Validate grade levels before database operations
      final gradeValidation = await _dbService.validateGradeLevels(
        cleanResult.data,
        schoolId,
      );
      if (!gradeValidation.success) {
        if (kDebugMode) {
          debugPrint(
            '❌ CLOUD GRADE LEVEL VALIDATION FAILED: ${gradeValidation.message}',
          );
        }
        return ImportResult(
          success: false,
          message: 'Grade level validation failed: ${gradeValidation.message}',
          recordsProcessed: 0,
          readyForCloudSync: false,
          importBatchId: '',
          importTimestamp: DateTime.now(),
          validationSummary: {
            'valid': false,
            'reason': 'missing_grade_levels',
            'missing_ids': gradeValidation.missingIds,
            'auto_fixed_ids': gradeValidation.autoFixedIds,
          },
          receivedFrom: '',
          dataType: '',
          breakdown: {},
          batchId: '',
          totalRecords: 0,
        );
      }

      // 🆕 NEW: Extract and update school dates if available
      final baselineDate = cleanResult.reportMetadata?['baseline_date'];
      final endlineDate = cleanResult.reportMetadata?['endline_date'];

      if (baselineDate != null || endlineDate != null) {
        try {
          await _dbService.updateSchoolDates(
            schoolId,
            baselineDate ?? '',
            endlineDate ?? '',
          );

          if (kDebugMode) {
            debugPrint('✅ Updated school dates from Excel metadata:');
            debugPrint('   Baseline: $baselineDate');
            debugPrint('   Endline: $endlineDate');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Could not update school dates: $e');
          }
          // Continue with import even if date update fails
        }
      }

      // Step 2: Generate file hash for duplicate detection
      final fileHash = await _generateFileHash(filePath);

      // Step 3: Extract validation results from clean result
      final validationResult = _extractValidationResult(
        cleanResult,
      );

      // Step 4: Prepare enhanced import metadata WITH PRESERVED PERIOD
      final importMetadata = {
        'school_year':
            cleanResult.reportMetadata?['school_year'] ?? '2023-2024',
        'period': detectedPeriod, // 🛠️ USE DETECTED PERIOD
        'school_name':
            cleanResult.reportMetadata?['school_name'] ?? 'Unknown School',
        'weighing_date': cleanResult.reportMetadata?['weighing_date'],
        'import_timestamp': DateTime.now().toIso8601String(),
        // Cloud sync metadata
        'file_hash': fileHash,
        'validation_result': jsonEncode(validationResult),
        'school_profile_match':
            validationResult['school_profile_match'] ?? false,
        // NEW: Student tracking metadata
        'student_tracking_enabled': true,
        'fuzzy_matching_threshold': 0.85,
        // 🆕 NEW: Period tracking
        'detected_period': detectedPeriod,
        // 🆕 NEW: Grade level validation info
        'grade_validation_passed': gradeValidation.success,
        'grade_auto_fixed_ids': gradeValidation.autoFixedIds,
        // 🆕 NEW: Date metadata
        'baseline_date': baselineDate,
        'endline_date': endlineDate,
      };

      // ENHANCED: Use DateUtilities for school year validation
      final extractedSchoolYear = cleanResult.reportMetadata?['school_year'];
      if (extractedSchoolYear != null &&
          !DateUtilities.isValidSchoolYear(extractedSchoolYear)) {
        cleanResult.problems.add(
          'Invalid school year format: $extractedSchoolYear',
        );
      }

      // Step 5: Save to database WITH STUDENT TRACKING USING DUAL-TABLE SYSTEM
      final dbResult = await _saveStudentRecordsWithDualTable(
        cleanResult.data,
        schoolId,
        detectedPeriod,
        importMetadata,
      );

      // Step 6: Determine if ready for cloud sync
      final readyForCloudSync =
          validationResult['school_profile_match'] == true &&
              dbResult['success'] == true &&
              (dbResult['records_processed'] ?? 0) > 0 &&
              gradeValidation.success; // 🆕 NEW: Include grade validation

      // ✅ ENHANCED: Provide detailed success message with student tracking info
      String finalMessage;
      if (dbResult['success'] == true) {
        finalMessage =
            'Successfully imported ${dbResult['records_processed']} student records as $detectedPeriod data using dual-table system. ';
        // NEW: Include student tracking statistics
        if (dbResult['student_tracking_stats'] != null) {
          final stats = dbResult['student_tracking_stats'];
          finalMessage +=
              'Student tracking: ${stats['student_ids_created']} new IDs created, '
              '${stats['existing_students_matched']} existing students matched. ';
        }
        // 🆕 NEW: Include grade level auto-fix info
        if (gradeValidation.autoFixedIds != null &&
            gradeValidation.autoFixedIds!.isNotEmpty) {
          finalMessage +=
              ' Auto-created missing grade levels: ${gradeValidation.autoFixedIds}. ';
        }
        // 🆕 NEW: Include date update info
        if (baselineDate != null || endlineDate != null) {
          finalMessage += ' School assessment dates updated. ';
        }
        if (readyForCloudSync) {
          finalMessage += 'Data is ready for cloud synchronization.';
        } else {
          finalMessage +=
              'Note: Data requires school profile validation before cloud sync.';
        }
        if (dbResult['errors']?.isNotEmpty == true) {
          finalMessage +=
              '\nMinor issues: ${dbResult['errors']?.length} warnings were logged.';
        }
        if (kDebugMode) {
          debugPrint('✅ CLOUD IMPORT SUCCESSFUL');
          debugPrint('   Records: ${dbResult['records_processed']}');
          debugPrint('   Cloud Ready: $readyForCloudSync');
          debugPrint('   School validation: CONFIRMED ✅');
          debugPrint('   Student tracking: ACTIVE ✅');
          debugPrint('   Grade levels: VALIDATED ✅');
          debugPrint('   Period: $detectedPeriod ✅');
          debugPrint('   Dual-table system: ACTIVE ✅');
        }
      } else {
        finalMessage = 'Import completed with errors: ${dbResult['message']}';
        if (dbResult['errors']?.isNotEmpty == true) {
          finalMessage +=
              '\nDetailed errors: ${dbResult['errors']?.take(3).join(', ')}';
        }
        if (kDebugMode) {
          debugPrint('❌ CLOUD IMPORT FAILED');
          debugPrint('   Error: ${dbResult['message']}');
        }
      }

      final result = ImportResult(
        success: dbResult['success'] == true,
        message: finalMessage,
        recordsProcessed: dbResult['records_processed'] ?? 0,
        errors: dbResult['errors'] is List
            ? List<String>.from(dbResult['errors'] as List)
            : null,
        readyForCloudSync: readyForCloudSync,
        importBatchId: dbResult['import_batch_id'] ?? '',
        importTimestamp: DateTime.now(),
        validationSummary: {
          ...validationResult,
          // NEW: Student tracking info
          'student_tracking_enabled': true,
          'student_ids_created':
              dbResult['student_tracking_stats']?['student_ids_created'] ?? 0,
          'existing_students_matched': dbResult['student_tracking_stats']
                  ?['existing_students_matched'] ??
              0,
          // 🆕 NEW: Grade level validation info
          'grade_validation_passed': gradeValidation.success,
          'grade_auto_fixed_ids': gradeValidation.autoFixedIds,
          'grade_missing_ids': gradeValidation.missingIds,
          // 🆕 NEW: Date info
          'baseline_date': baselineDate,
          'endline_date': endlineDate,
          // 🛠️ CRITICAL: Include period in validation summary
          'import_period': detectedPeriod,
          // 🆕 NEW: Dual-table system indicator
          'dual_table_system': true,
        },
        receivedFrom: '',
        dataType: '',
        breakdown: {},
        batchId: '',
        totalRecords: 0,
      );

      if (kDebugMode) {
        debugPrint('📋 CLOUD IMPORT FINAL RESULT:');
        debugPrint('   Success: ${result.success}');
        debugPrint('   Cloud Ready: ${result.readyForCloudSync}');
        debugPrint('   Student Tracking: ${result.studentTrackingEnabled}');
        debugPrint('   Grade Validation: ${gradeValidation.success}');
        debugPrint('   Period: $detectedPeriod');
        debugPrint('   Dual-Table: ${result.dualTableSystem}');
        debugPrint(
          '========== CLOUD IMPORT WITH PERIOD PRESERVATION COMPLETE ==========',
        );
      }
      return result;
    } catch (e, stackTrace) {
      // ✅ ENHANCED: Detailed error logging
      if (kDebugMode) {
        debugPrint('❌ CLOUD IMPORT CRITICAL ERROR:');
        debugPrint('   Error: $e');
        debugPrint('   Stack Trace: $stackTrace');
      }
      String errorMessage;
      if (e.toString().contains('school') && e.toString().contains('profile')) {
        errorMessage =
            'School profile validation failed. Please ensure the Excel file matches your school profile.';
      } else if (e.toString().contains('FileSystemException')) {
        errorMessage =
            'Unable to read Excel file. Please check file permissions and format.';
      } else if (e.toString().contains('database')) {
        errorMessage =
            'Database error during import. The system will retry automatically.';
      } else {
        errorMessage = 'Import preparation failed: ${e.toString()}';
      }
      final errorResult = ImportResult(
        success: false,
        message: errorMessage,
        recordsProcessed: 0,
        readyForCloudSync: false,
        importBatchId: '',
        importTimestamp: DateTime.now(),
        validationSummary: {
          'valid': false,
          'reason': e.toString(),
          'stack_trace': stackTrace.toString(),
          'error_type': e.runtimeType.toString(),
          'student_tracking_enabled': false,
          'dual_table_system': false,
        },
        receivedFrom: '',
        dataType: '',
        breakdown: {},
        batchId: '',
        totalRecords: 0,
      );
      if (kDebugMode) {
        debugPrint('❌ CLOUD IMPORT ERROR RESULT:');
        debugPrint('   Message: ${errorResult.message}');
        debugPrint(
          '========== CLOUD IMPORT WITH PERIOD PRESERVATION FAILED ==========',
        );
      }
      return errorResult;
    }
  }

  /// 🛠️ UPDATED: Map to legacy learner table (for fallback)
  static Map<String, dynamic> _mapToLegacyLearnerTable(
    Map<String, dynamic> data,
    String period,
  ) {
    final normalizedName = StudentIdentificationService.normalizeName(
      data['name']?.toString() ?? '',
    );

    // Determine assessment completeness
    final hasWeight = data['weight_kg'] != null;
    final hasHeight = data['height_cm'] != null;
    final hasBMI = data['bmi'] != null;
    final hasStatus = data['nutritional_status'] != null &&
        data['nutritional_status'].toString().isNotEmpty &&
        data['nutritional_status'].toString() != 'Unknown';

    String assessmentCompleteness = 'Incomplete';
    if (hasWeight && hasHeight && hasBMI && hasStatus) {
      assessmentCompleteness = 'Complete';
    } else if (hasWeight && hasHeight && hasBMI) {
      assessmentCompleteness = 'Measurements Complete';
    } else if (hasStatus) {
      assessmentCompleteness = 'Status Only';
    } else if (hasWeight || hasHeight) {
      assessmentCompleteness = 'Partial Measurements';
    }

    return {
      'id': data['id']?.toString() ??
          'learner_${DateTime.now().millisecondsSinceEpoch}_${data['name']}',
      'school_id': data['school_id']?.toString() ?? '',
      'grade_level_id': _mapGradeToId(data['grade_level']),
      'grade_name': data['grade_level']?.toString() ?? 'Unknown',
      'learner_name': data['name']?.toString() ?? '',
      'sex': data['sex']?.toString() ?? 'Unknown',
      'date_of_birth': data['birth_date']?.toString(),
      'age': data['age'] != null ? int.tryParse(data['age'].toString()) : null,
      'nutritional_status': data['nutritional_status']?.toString() ?? 'Unknown',
      'assessment_period': period,
      'assessment_date':
          data['weighing_date']?.toString() ?? DateTime.now().toIso8601String(),
      'height': data['height_cm'],
      'weight': data['weight_kg'],
      'bmi': data['bmi'],
      'lrn': data['lrn']?.toString(),
      'section': data['section']?.toString(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'import_batch_id': 'batch_${DateTime.now().millisecondsSinceEpoch}',
      'cloud_sync_id': '',
      'last_synced': '',
      'academic_year': data['academic_year']?.toString() ?? '2023-2024',
      'student_id': data['student_id']?.toString() ?? '',
      'normalized_name': normalizedName,
      'assessment_completeness': assessmentCompleteness,
      'period': period,
    };
  }

  /// 🛠️ Helper method to map grade level to ID
  static int _mapGradeToId(dynamic grade) {
    if (grade == null) return 0;
    final gradeString = grade.toString().trim();
    final gradeMap = {
      'K': 0,
      'Kinder': 0,
      '1': 1,
      'Grade 1': 1,
      'G1': 1,
      '2': 2,
      'Grade 2': 2,
      'G2': 2,
      '3': 3,
      'Grade 3': 3,
      'G3': 3,
      '4': 4,
      'Grade 4': 4,
      'G4': 4,
      '5': 5,
      'Grade 5': 5,
      'G5': 5,
      '6': 6,
      'Grade 6': 6,
      'G6': 6,
      'SPED': 7,
    };
    return gradeMap[gradeString] ?? 0;
  }

  /// Helper method to get school profile
  static Future<SchoolProfile?> _getSchoolProfile(String schoolId) async {
    try {
      final schoolData = await _dbService.getSchool(schoolId);
      if (schoolData != null) {
        return SchoolProfile.fromMap(schoolData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting school profile: $e');
      return null;
    }
  }

  /// Generate file hash for duplicate detection
  static Future<String> _generateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final hash = bytes.hashCode.toRadixString(16);
      return hash;
    } catch (e) {
      return 'hash_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Extract validation results from clean result
  static Map<String, dynamic> _extractValidationResult(
    CleanResult cleanResult,
  ) {
    final validation = <String, dynamic>{
      'total_records': cleanResult.data.length,
      'success': cleanResult.success,
      'problems_count': cleanResult.problems.length,
      'school_profile_match': false,
      'data_quality': {},
    };

    // Extract school profile match from validation result if available
    if (cleanResult.validationResult != null) {
      validation['school_profile_match'] =
          cleanResult.validationResult!.matchedSchoolName;
      validation['is_valid'] = cleanResult.validationResult!.isValid;
      validation['validation_errors'] = cleanResult.validationResult!.errors;
      validation['validation_warnings'] =
          cleanResult.validationResult!.warnings;
    }

    // Extract data quality metrics
    if (cleanResult.metadata != null &&
        cleanResult.metadata!['quality_metrics'] != null) {
      validation['data_quality'] = cleanResult.metadata!['quality_metrics'];
    }

    return validation;
  }

  /// NEW: Critical verification for nutritional status data loss
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
          '⚠️ CRITICAL WARNING: NUTRITIONAL STATUS DATA LOSS DETECTED',
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
          final sampleSize = studentsWithUnknownStatus.length < 3
              ? studentsWithUnknownStatus.length
              : 3;
          debugPrint('   Sample affected students:');
          for (int i = 0; i < sampleSize; i++) {
            final student = studentsWithUnknownStatus[i];
            debugPrint(
              '     - ${student['name']}: BMI=${student['bmi']}, Status=${student['nutritional_status']}',
            );
          }
        }
      }
      // Critical assertion to track data quality issues
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

  /// 🛠️ NEW: Utility method to detect period from file name and content
  static String _detectPeriodFromData(List<Map<String, dynamic>> data) {
    // Check for period indicators in the data
    for (final student in data) {
      final period = student['period']?.toString();
      if (period != null && period.isNotEmpty && period != 'Unknown') {
        return period;
      }
    }

    // Default to Baseline as last resort
    return 'Baseline';
  }
}

/// ENHANCED: Result of import operation with STUDENT TRACKING support
class ImportResult {
  final bool success;
  final String message;
  final int recordsProcessed;
  final List<String>? errors;
  // Cloud sync fields
  final bool readyForCloudSync;
  final String importBatchId;
  final DateTime importTimestamp;
  final Map<String, dynamic> validationSummary;

  ImportResult({
    required this.success,
    required this.message,
    required this.recordsProcessed,
    this.errors,
    // Cloud sync fields with defaults
    this.readyForCloudSync = false,
    this.importBatchId = '',
    DateTime? importTimestamp,
    this.validationSummary = const {},
    required String receivedFrom,
    required String dataType,
    required Map<String, int> breakdown,
    required String batchId,
    required int totalRecords,
  }) : importTimestamp = importTimestamp ?? DateTime.now();

  @override
  String toString() {
    return 'ImportResult(success: $success, records: $recordsProcessed, message: $message, readyForCloudSync: $readyForCloudSync)';
  }

  // NEW: Student tracking helpers
  bool get studentTrackingEnabled =>
      validationSummary['student_tracking_enabled'] == true;

  int get studentIDsCreated => validationSummary['student_ids_created'] ?? 0;

  int get existingStudentsMatched =>
      validationSummary['existing_students_matched'] ?? 0;

  // 🆕 NEW: Grade level validation helpers
  bool get gradeValidationPassed =>
      validationSummary['grade_validation_passed'] == true;

  List<int>? get gradeAutoFixedIds => validationSummary['grade_auto_fixed_ids'];

  List<int>? get gradeMissingIds => validationSummary['grade_missing_ids'];

  // 🆕 NEW: Date field helpers
  String? get baselineDate => validationSummary['baseline_date']?.toString();
  String? get endlineDate => validationSummary['endline_date']?.toString();

  // 🛠️ CRITICAL: Period field helper
  String? get importPeriod => validationSummary['import_period']?.toString();

  // 🆕 NEW: Dual-table system indicator
  bool get dualTableSystem => validationSummary['dual_table_system'] == true;

  // 🆕 NEW: Academic year imported
  String? get academicYearImported =>
      validationSummary['academic_year_imported']?.toString();

  // Helper methods for cloud sync
  bool get hasValidationErrors {
    return validationSummary['school_profile_match'] == false ||
        (validationSummary['validation_errors'] != null &&
            (validationSummary['validation_errors'] as List).isNotEmpty);
  }

  /// Check if school validation passed
  bool get passedSchoolValidation =>
      validationSummary['school_profile_match'] == true;

  List<String> get allValidationIssues {
    final issues = <String>[];
    if (validationSummary['validation_errors'] != null) {
      issues.addAll(
        (validationSummary['validation_errors'] as List).cast<String>(),
      );
    }
    if (validationSummary['validation_warnings'] != null) {
      issues.addAll(
        (validationSummary['validation_warnings'] as List).cast<String>(),
      );
    }
    if (errors != null) {
      issues.addAll(errors!);
    }
    return issues;
  }

  double get dataQualityScore {
    if (recordsProcessed == 0) return 0.0;
    final quality = validationSummary['data_quality'] ?? {};
    final completeData = quality['students_with_complete_data'] ?? 0;
    return (completeData / recordsProcessed) * 100;
  }

  // Nutritional status specific helpers
  bool get hasNutritionalStatusData {
    final analysis = validationSummary['nutritional_status_analysis'];
    if (analysis is Map) {
      return (analysis['with_status'] ?? 0) > 0;
    }
    return false;
  }

  int get nutritionalStatusCompletionRate {
    final analysis = validationSummary['nutritional_status_analysis'];
    if (analysis is Map) {
      return analysis['completion_rate'] ?? 0;
    }
    return 0;
  }
}

// Add debugPrint for non-debug mode compatibility
void debugPrint(String message) {
  // This will work in both debug and release modes
  print(message);
}
