// lib/Services/Data_Model/excel_extract.dart - UPDATED FOR DUAL-TABLE STRUCTURE AND NUTRITIONAL DATA IMPUTATION
import 'dart:io';
import 'dart:math';
import 'package:district_dev/Services/Data%20Model/date_utilities.dart';
import 'package:district_dev/Services/Data%20Model/exce_external_cleaner.dart';
import 'package:district_dev/Services/Data%20Model/import_student.dart';
import 'package:district_dev/Services/Data%20Model/nutri_stat_utilities.dart';
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:district_dev/Services/Database/database_service.dart';
import 'package:district_dev/Services/Extraction/csv_converter.dart'
    show StudentMatchingService;
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

// ADD MISSING CONSTANT FOR COMPATIBILITY
const bool kDebugMode = true;

/// Student Name Matcher for fuzzy matching
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

/// Assessment Completeness Tracker
class _AssessmentCompletenessTracker {
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

class SBFPExtractor {
  /// Extract students from SBFP Excel - WITH ACCURATE SCHOOL VALIDATION AND STUDENT TRACKING
  static Future<ExtractionResult> extractStudents(
    String filePath, {
    SchoolProfile? appSchoolProfile,
    bool strictValidation = false,
  }) async {
    if (kDebugMode) {
      print(
        '=== SBFP EXCEL EXTRACTION STARTED (ACCURATE VALIDATION + STUDENT TRACKING) ===',
      );
    }

    // 🛑 CRITICAL FIX: Block extraction if app school profile is missing but validation is required
    if (strictValidation && appSchoolProfile == null) {
      if (kDebugMode) {
        print(
          '❌ VALIDATION BLOCKED: App school profile is missing but strict validation was requested',
        );
      }

      final result = ExtractionResult();
      result.problems.add(
        'VALIDATION FAILED: Cannot perform school validation - application school profile is missing. Please configure school data first.',
      );
      result.success = false;
      return result;
    }

    try {
      return await compute(_extractInBackground, {
        'filePath': filePath,
        'appSchoolProfile': appSchoolProfile?.toMap(),
        'strictValidation': strictValidation,
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ BACKGROUND EXTRACTION ERROR: $e');
        print('Stack trace: $stackTrace');
      }

      final result = ExtractionResult();
      result.problems.add('Background extraction failed: $e');
      return result;
    }
  }

  /// Background extraction with ACCURATE SCHOOL VALIDATION AND STUDENT TRACKING
  static Future<ExtractionResult> _extractInBackground(
    Map<String, dynamic> params,
  ) async {
    final filePath = params['filePath'] as String;
    final appSchoolProfileMap =
        params['appSchoolProfile'] as Map<String, dynamic>?;
    final strictValidation = params['strictValidation'] as bool? ?? false;

    final result = ExtractionResult();
    SchoolProfile? appSchoolProfile;

    if (appSchoolProfileMap != null) {
      appSchoolProfile = SchoolProfile.fromMap(appSchoolProfileMap);
    }

    try {
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        result.problems.add('No sheets found in Excel file');
        return result;
      }

      if (kDebugMode) {
        print('📊 WORKBOOK INFO: ${excel.tables.keys.length} sheets found');
        print('📋 SHEETS: ${excel.tables.keys.toList()}');
      }

      // 🛠️ ADDED: Debug the actual cell contents
      _debugSchoolProfileCells(excel);

      // Extract school profile first - ENHANCED EXTRACTION WITH ROBUST YEAR DETECTION
      final extractedSchoolProfile = _extractSchoolProfileEnhanced(excel);

      // FIXED: Use the proper SchoolProfileImport class
      result.schoolProfile = extractedSchoolProfile.toMap();

      // ========== CRITICAL SCHOOL VALIDATION FIX ==========
      // ENHANCED: SCHOOL PROFILE VALIDATION - NOW WITH ACCURATE MATCHING
      if (appSchoolProfile != null) {
        final validationResult = _validateSchoolProfileStrict(
          extractedSchoolProfile,
          appSchoolProfile,
          strictValidation,
        );

        result.validationResult = validationResult;

        if (kDebugMode) {
          print('🏫 SCHOOL PROFILE VALIDATION:');
          print('   Extracted: "${extractedSchoolProfile.schoolName}"');
          print('   App: "${appSchoolProfile.schoolName}"');
          print('   Valid: ${validationResult.isValid}');
          print('   School Name Match: ${validationResult.matchedSchoolName}');
          print('   District Match: ${validationResult.matchedDistrict}');
          print('   Errors: ${validationResult.errors}');
          print('   Warnings: ${validationResult.warnings}');
        }

        // Add validation issues to problems
        result.problems.addAll(validationResult.errors);
        result.problems.addAll(validationResult.warnings);

        // 🚫 CRITICAL FIX: BLOCK EXTRACTION if validation fails
        if (!validationResult.isValid) {
          result.problems.add(
            '❌ SCHOOL VALIDATION FAILED - Import blocked. Excel school "${extractedSchoolProfile.schoolName}" does not match app school "${appSchoolProfile.schoolName}"',
          );
          result.success = false;

          if (kDebugMode) {
            print(
              '🚫 EXTRACTION BLOCKED due to school profile validation failure',
            );
          }

          return result; // STOP EXTRACTION HERE
        }

        // 🟡 WARNING for district mismatch but continue extraction
        if (!validationResult.matchedDistrict) {
          result.problems.add(
            '⚠️ DISTRICT MISMATCH - Continuing import (school name matched)',
          );
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ No app school profile provided - skipping validation');
        }

        if (strictValidation) {
          result.problems.add(
            '⚠️ SCHOOL VALIDATION SKIPPED: No application school profile available for validation',
          );
        }
      }
      // ========== END CRITICAL SCHOOL VALIDATION FIX ==========

      // ✅ ONLY PROCEED WITH DATA EXTRACTION IF SCHOOL VALIDATION PASSES
      if ((result.validationResult?.isValid ?? true) ||
          appSchoolProfile == null) {
        // Process all sheets that contain grade data (Kinder to SPED)
        final gradeSheets = excel.tables.keys
            .where((sheetName) => !_shouldSkipSheet(sheetName))
            .toList();

        if (kDebugMode) {
          print(
            '📚 PROCESSING ${gradeSheets.length} GRADE SHEETS: $gradeSheets',
          );
        }

        for (final sheetName in gradeSheets) {
          if (kDebugMode) {
            print('\n=== PROCESSING SHEET: "$sheetName" ===');
          }

          final sheet = excel.tables[sheetName]!;
          _processSheetWithDualPeriods(
            sheet,
            sheetName,
            result,
            extractedSchoolProfile,
          );
        }

        // ENHANCED: Add student tracking fields to all extracted students
        _enhanceStudentsWithTracking(result.students, extractedSchoolProfile);

        if (kDebugMode) {
          print(
            '\n🎯 EXTRACTION COMPLETE: ${result.students.length} students found',
          );
          print('❌ PROBLEMS: ${result.problems.length} issues');

          // Show period distribution
          final baselineCount =
              result.students.where((s) => s['period'] == 'Baseline').length;
          final endlineCount =
              result.students.where((s) => s['period'] == 'Endline').length;
          print(
            '📊 PERIOD DISTRIBUTION: Baseline: $baselineCount, Endline: $endlineCount',
          );

          // Show grade distribution - FIXED: Proper Map initialization
          final gradeCounts = <String, int>{};
          for (final student in result.students) {
            final grade = student['grade_level']?.toString() ?? 'Unknown';
            gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;
          }
          print('📊 GRADE DISTRIBUTION: $gradeCounts');

          // Show student tracking statistics
          final studentsWithIDs = result.students
              .where(
                (s) =>
                    s['student_id'] != null &&
                    s['student_id'].toString().isNotEmpty,
              )
              .length;
          final studentsWithCompleteness = result.students
              .where(
                (s) =>
                    s['assessment_completeness'] != null &&
                    s['assessment_completeness'].toString().isNotEmpty,
              )
              .length;
          print('🎯 STUDENT TRACKING STATS:');
          print(
            '   Students with IDs: $studentsWithIDs/${result.students.length}',
          );
          print(
            '   Students with completeness: $studentsWithCompleteness/${result.students.length}',
          );

          if (result.students.isNotEmpty) {
            print('\n👤 FIRST STUDENT SAMPLE:');
            final firstStudent = result.students.first;
            print('   Name: ${firstStudent['name']}');
            print('   Student ID: ${firstStudent['student_id']}');
            print('   Period: ${firstStudent['period']}');
            print('   Weight: ${firstStudent['weight_kg']} kg');
            print('   Height: ${firstStudent['height_cm']} cm');
            print('   BMI: ${firstStudent['bmi']}');
            print('   Status: ${firstStudent['nutritional_status']}');
            print('   Grade: ${firstStudent['grade_level']}');
            print(
              '   Assessment Completeness: ${firstStudent['assessment_completeness']}',
            );
          }
        }

        result.success = result.students.isNotEmpty;
      } else {
        if (kDebugMode) {
          print(
            '🚫 EXTRACTION BLOCKED due to school profile validation failure',
          );
        }
        result.success = false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ EXTRACTION ERROR: $e');
        print('Stack trace: $stackTrace');
      }
      result.problems.add('Extraction failed: $e');
    }

    return result;
  }

  /// 🛠️ ENHANCED: School Profile Extraction with ROBUST YEAR DETECTION
  static SchoolProfileImport _extractSchoolProfileEnhanced(Excel excel) {
    final firstSheetName = excel.tables.keys.first;
    final sheet = excel.tables[firstSheetName];
    if (sheet == null) {
      return SchoolProfileImport(
        schoolName: '',
        district: '',
        schoolYear: '',
        region: '',
        division: '',
        schoolId: '',
        schoolHead: '',
        coordinator: '',
        baselineDate: '',
        endlineDate: '',
      );
    }

    // 🎯 ENHANCED: More robust school year extraction
    String extractedSchoolYear = '';

    // Try multiple cell locations for school year
    final schoolYearLocations = [
      {'row': 9, 'col': 3}, // D9 (default)
      {'row': 8, 'col': 3}, // D8
      {'row': 10, 'col': 3}, // D10
      {'row': 7, 'col': 3}, // D7
      {'row': 6, 'col': 3}, // D6
    ];

    for (final location in schoolYearLocations) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: location['col']!,
          rowIndex: location['row']! - 1,
        ),
      );
      final value = _getCellValue(cell)?.trim() ?? '';

      if (value.isNotEmpty && _looksLikeSchoolYear(value)) {
        extractedSchoolYear = _normalizeSchoolYear(value);
        break;
      }
    }

    // If still not found, search entire sheet for year pattern
    if (extractedSchoolYear.isEmpty) {
      extractedSchoolYear = _searchForSchoolYearInSheet(sheet);
    }

    // Extract other profile data
    final schoolNameCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1),
    );
    final schoolName = _getCellValue(schoolNameCell)?.trim() ?? '';

    final districtCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2),
    );
    final district = _getCellValue(districtCell)?.trim() ?? '';

    // 🛠️ ENHANCED: Date extraction with better parsing
    final baselineDateCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 9),
    );
    final baselineDateStr = _getCellValue(baselineDateCell)?.trim() ?? '';
    final baselineDate = _parseExcelDateEnhanced(baselineDateStr) ??
        DateUtilities.parseDate(
          baselineDateStr,
        )?.toIso8601String().split('T').first;

    final endlineDateCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 10),
    );
    final endlineDateStr = _getCellValue(endlineDateCell)?.trim() ?? '';
    final endlineDate = _parseExcelDateEnhanced(endlineDateStr) ??
        DateUtilities.parseDate(
          endlineDateStr,
        )?.toIso8601String().split('T').first;

    if (kDebugMode) {
      print('🎯 ENHANCED SCHOOL PROFILE EXTRACTION:');
      print('   School: "$schoolName"');
      print('   District: "$district"');
      print('   School Year: "$extractedSchoolYear"');
      print('   Baseline Date: "$baselineDate"');
      print('   Endline Date: "$endlineDate"');
    }

    final profile = SchoolProfileImport(
      schoolName: schoolName,
      district: district,
      schoolYear: extractedSchoolYear,
      region: '',
      division: '',
      schoolId: '',
      schoolHead: '',
      coordinator: '',
      baselineDate: baselineDate,
      endlineDate: endlineDate,
    );

    return profile;
  }

  /// Helper to identify school year patterns
  static bool _looksLikeSchoolYear(String text) {
    final yearPattern = RegExp(
      r'20\d{2}-20\d{2}|\d{4}-\d{4}|\d{4}/\d{4}|SY\s*\d{4}-\d{4}',
    );
    return yearPattern.hasMatch(text);
  }

  /// Normalize school year format to YYYY-YYYY
  static String _normalizeSchoolYear(String year) {
    final match = RegExp(r'(\d{4}).*?(\d{4})').firstMatch(year);
    if (match != null) {
      return '${match.group(1)}-${match.group(2)}';
    }

    // Try to extract year from other patterns
    final numbers = RegExp(
      r'\d{4}',
    ).allMatches(year).map((m) => m.group(0)!).toList();
    if (numbers.length >= 2) {
      return '${numbers[0]}-${numbers[1]}';
    }

    return year.trim();
  }

  /// Search entire sheet for school year pattern
  static String _searchForSchoolYearInSheet(Sheet sheet) {
    final rowCount = min(sheet.rows.length, 50);
    final colCount = min(sheet.maxColumns, 20);

    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < colCount; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        );
        final value = _getCellValue(cell)?.trim() ?? '';
        if (value.isNotEmpty && _looksLikeSchoolYear(value)) {
          final normalizedYear = _normalizeSchoolYear(value);
          if (kDebugMode) {
            print(
              '🔍 Found school year at row $r, col $c: "$value" -> "$normalizedYear"',
            );
          }
          return normalizedYear;
        }
      }
    }

    return '2024-2025'; // Default fallback
  }

  /// 🛠️ ADD THIS METHOD: Enhanced Excel date parsing
  static String? _parseExcelDateEnhanced(String rawDate) {
    if (rawDate.isEmpty) return null;

    try {
      // Handle Excel serial number dates (like 45520.0)
      if (RegExp(r'^\d+\.?\d*$').hasMatch(rawDate)) {
        final excelSerial = double.tryParse(rawDate);
        if (excelSerial != null) {
          // Excel date serial numbers: 1 = Jan 1, 1900
          final baseDate = DateTime(1900, 1, 1);
          final date = baseDate.add(
            Duration(days: excelSerial.toInt() - 2),
          ); // Excel has leap year bug
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      }

      // Let the existing DateUtilities handle other formats
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Excel date parsing failed for "$rawDate": $e');
      }
      return null;
    }
  }

  /// 🛠️ ADD THIS METHOD: Debug school profile cells
  static void _debugSchoolProfileCells(Excel excel) {
    if (!kDebugMode) return;

    print('\n🔍 DEBUG SCHOOL PROFILE CELLS (Column D):');
    final firstSheetName = excel.tables.keys.first;
    final sheet = excel.tables[firstSheetName];
    if (sheet == null) return;

    final rowsToCheck = [2, 3, 6, 7, 8, 9, 10, 11]; // D2 through D11

    for (final row in rowsToCheck) {
      final cellIndex = CellIndex.indexByColumnRow(
        columnIndex: 3,
        rowIndex: row - 1,
      );
      final cell = sheet.cell(cellIndex);
      final value = cell.value?.toString() ?? 'NULL';
      print('   Row $row, Col D: "$value"');
    }
  }

  /// ENHANCED: Add student tracking fields to all extracted students
  static void _enhanceStudentsWithTracking(
    List<Map<String, dynamic>> students,
    SchoolProfileImport schoolProfile,
  ) {
    final schoolAcronym = _extractSchoolAcronym(schoolProfile.schoolName);

    for (final student in students) {
      // Add normalized name for fuzzy matching
      final name = student['name']?.toString() ?? '';
      student['normalized_name'] = StudentIdentificationService.normalizeName(
        name,
      );

      // 🛠️ CRITICAL FIX: Generate SHORTER student ID for ALL students
      if (student['student_id'] == null ||
          student['student_id'].toString().isEmpty) {
        student['student_id'] =
            StudentIdentificationService.generateDeterministicStudentID(
          name,
          schoolAcronym,
        );

        if (kDebugMode && students.indexOf(student) < 3) {
          print('🆔 GENERATED SHORT STUDENT ID: ${student['student_id']}');
        }
      }

      // 🛠️ CRITICAL FIX: Ensure assessment completeness is set
      if (student['assessment_completeness'] == null ||
          student['assessment_completeness'].toString().isEmpty) {
        student['assessment_completeness'] =
            _AssessmentCompletenessTracker.determineIndividualCompleteness(
          student,
        );
      }

      // Add school information for tracking
      student['extracted_school_name'] = schoolProfile.schoolName;
      student['extracted_district'] = schoolProfile.district;
      student['extracted_school_year'] = schoolProfile.schoolYear;

      // 🧪 Add flag for nutritional data imputation
      student['requires_nutritional_imputation'] =
          (student['weight_kg'] != null && student['height_cm'] != null) &&
              (student['nutritional_status'] == null ||
                  student['nutritional_status'] == 'Unknown');

      // 🛠️ CRITICAL FIX: Add debug logging for tracking
      if (kDebugMode && students.indexOf(student) < 3) {
        print('🎯 STUDENT TRACKING ENHANCED:');
        print('   Name: ${student['name']}');
        print('   Student ID: ${student['student_id']}');
        print('   Normalized Name: ${student['normalized_name']}');
        print(
          '   Assessment Completeness: ${student['assessment_completeness']}',
        );
        print(
          '   Requires Nutritional Imputation: ${student['requires_nutritional_imputation']}',
        );
      }
    }
  }

  /// 🆕 UPDATED: Extract school acronym for shorter student IDs
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

  /// Helper method to safely get cell value
  static String? _getCellValue(Data? cell) {
    if (cell == null || cell.value == null) return null;
    try {
      return cell.value.toString().trim();
    } catch (e) {
      return null;
    }
  }

  /// UPDATED: Use DateUtilities for centralized date parsing
  static String? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    final date = DateUtilities.parseDate(dateStr);
    return date != null ? DateUtilities.formatDateForDB(date) : null;
  }

  /// 🛑 CRITICAL FIX: STRICTER School Profile Validation
  static ValidationResult _validateSchoolProfileStrict(
    SchoolProfileImport extractedProfile,
    SchoolProfile appProfile,
    bool strictMode,
  ) {
    final result = ValidationResult();

    // CRITICAL FIX: STRICTER School Name Matching
    final extractedName = _normalizeSchoolNameStrict(
      extractedProfile.schoolName,
    );
    final appName = _normalizeSchoolNameStrict(appProfile.schoolName);

    if (extractedName.isEmpty) {
      result.errors.add('School name not found in Excel file');
      result.matchedSchoolName = false;
      result.isValid = false;

      if (kDebugMode) {
        print('❌ SCHOOL VALIDATION FAILED: No school name found in Excel');
      }
    } else {
      // 🛑 STRICTER MATCHING: Require exact or very close match
      final matchResult = _strictSchoolNameMatch(extractedName, appName);
      result.matchedSchoolName = matchResult['match'];
      result.isValid = matchResult['match'];

      if (!matchResult['match']) {
        final errorMsg =
            'CRITICAL MISMATCH: Excel school "$extractedName" does not match app school "$appName"';
        result.errors.add(errorMsg);

        if (kDebugMode) {
          print('❌ SCHOOL VALIDATION FAILED: $errorMsg');
          print('   Extracted (normalized): "$extractedName"');
          print('   Expected (normalized): "$appName"');
          print('   Similarity Score: ${matchResult['similarity']}%');
        }
      } else {
        if (kDebugMode) {
          print(
            '✅ SCHOOL NAME VALIDATION PASSED: "$extractedName" matches "$appName"',
          );
          print('   Similarity Score: ${matchResult['similarity']}%');
        }
      }
    }

    // District Matching - Also stricter
    final extractedDistrict = _normalizeSchoolNameStrict(
      extractedProfile.district,
    );
    final appDistrict = _normalizeSchoolNameStrict(appProfile.district);

    if (extractedDistrict.isEmpty) {
      result.warnings.add('District not found in Excel file');
      result.matchedDistrict = false;
    } else {
      final districtMatch = _strictDistrictMatch(
        extractedDistrict,
        appDistrict,
      );
      result.matchedDistrict = districtMatch['match'];

      if (!districtMatch['match']) {
        result.warnings.add(
          'District mismatch: Excel "$extractedDistrict" vs App "$appDistrict" (Similarity: ${districtMatch['similarity']}%)',
        );
      }
    }

    // 🎯 NEW: School Year Validation
    final extractedYear = extractedProfile.schoolYear;
    if (extractedYear.isNotEmpty) {
      result.warnings.add('Excel file school year: $extractedYear');
    }

    if (kDebugMode) {
      print('🔍 VALIDATION SUMMARY:');
      print('   School Match: ${result.matchedSchoolName}');
      print('   District Match: ${result.matchedDistrict}');
      print('   Overall Valid: ${result.isValid}');
    }

    return result;
  }

  /// 🛑 STRICTER: School name matching with higher threshold
  static Map<String, dynamic> _strictSchoolNameMatch(
    String name1,
    String name2,
  ) {
    if (name1 == name2) {
      return {'match': true, 'similarity': 100};
    }

    // Remove common suffixes for matching
    final clean1 = _removeSchoolSuffixesStrict(name1);
    final clean2 = _removeSchoolSuffixesStrict(name2);

    // Check exact match after cleaning
    if (clean1 == clean2) {
      return {'match': true, 'similarity': 100};
    }

    // Calculate similarity percentage
    final similarity = _calculateSimilarity(clean1, clean2);

    // 🛑 HIGHER THRESHOLD: Require 95% similarity for match (WAS: 90%)
    final bool matches = similarity >= 95;

    return {'match': matches, 'similarity': similarity};
  }

  /// 🛑 STRICTER: District matching
  static Map<String, dynamic> _strictDistrictMatch(
    String district1,
    String district2,
  ) {
    if (district1 == district2) {
      return {'match': true, 'similarity': 100};
    }

    final clean1 = _removeDistrictSuffixesStrict(district1);
    final clean2 = _removeDistrictSuffixesStrict(district2);

    if (clean1 == clean2) {
      return {'match': true, 'similarity': 100};
    }

    final similarity = _calculateSimilarity(clean1, clean2);
    final bool matches = similarity >= 85;

    return {'match': matches, 'similarity': similarity};
  }

  /// Calculate similarity percentage between two strings
  static double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;

    if (maxLength == 0) return 100.0;

    return ((1 - distance / maxLength) * 100).roundToDouble();
  }

  /// 🛑 STRICTER: School name normalization
  static String _normalizeSchoolNameStrict(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 🛑 STRICTER: Remove school suffixes
  static String _removeSchoolSuffixesStrict(String name) {
    return name
        .replaceAll(
          RegExp(
            r'\b(elementary school|es|school|high school|hs|integrated school|is|central|south|north|east|west)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  /// 🛑 STRICTER: Remove district suffixes
  static String _removeDistrictSuffixesStrict(String district) {
    return district
        .replaceAll(
          RegExp(r'\b(district|dist|d\.|division|div)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  // Levenshtein distance for similarity calculation
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    for (var i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= s1.length; i++) {
      for (var j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// 🆕 UPDATED: Extract and convert directly to StudentAssessment objects for dual-table structure
  static Future<List<StudentAssessment>> extractSBFPStudents(
    String filePath, {
    SchoolProfile? appSchoolProfile,
    required String schoolId,
    bool strictValidation = false,
  }) async {
    if (kDebugMode) {
      print(
        '=== SBFP EXCEL EXTRACTION STARTED (StudentAssessment MODE WITH DUAL-TABLE STRUCTURE) ===',
      );
    }

    // 🛑 CRITICAL FIX: Block extraction if app school profile is missing but validation is required
    if (strictValidation && appSchoolProfile == null) {
      if (kDebugMode) {
        print(
          '❌ VALIDATION BLOCKED: App school profile is missing but strict validation was requested',
        );
      }
      throw Exception(
        'VALIDATION FAILED: Cannot perform school validation - application school profile is missing. Please configure school data first.',
      );
    }

    try {
      final extractionResult = await extractStudents(
        filePath,
        appSchoolProfile: appSchoolProfile,
        strictValidation: strictValidation,
      );

      if (!extractionResult.success) {
        throw Exception(
          'Extraction failed: ${extractionResult.problems.join(', ')}',
        );
      }

      if (kDebugMode) {
        print(
          '✅ Extraction successful, converting ${extractionResult.students.length} students to StudentAssessment objects',
        );
      }

      // 🛠️ FIX: Extract academic year from school profile or use default
      final academicYear =
          extractionResult.schoolProfile['schoolYear']?.toString() ??
              '2024-2025';

      // Convert to StudentAssessment objects with validation AND DUAL-TABLE STRUCTURE
      final studentAssessments = extractionResult.students
          .map(
            (studentData) => StudentAssessment.fromCombinedData(
              studentData,
              schoolId,
              academicYear,
              studentData['period'] ?? 'Baseline',
            ),
          )
          .where(
            (student) => student.validate().isEmpty,
          ) // Only keep valid students
          .toList();

      if (kDebugMode) {
        print(
          '✅ Conversion complete: ${studentAssessments.length} valid StudentAssessment objects created',
        );
        if (studentAssessments.isNotEmpty) {
          print('\n👤 FIRST StudentAssessment SAMPLE:');
          final firstStudent = studentAssessments.first;
          print('   Name: ${firstStudent.learner.learnerName}');
          print('   Student ID: ${firstStudent.learner.studentId}');
          print('   Grade: ${firstStudent.learner.gradeLevel}');
          print('   Period: ${firstStudent.period}');
          print('   Status: ${firstStudent.assessment.nutritionalStatus}');
          print('   Valid: ${firstStudent.validate().isEmpty}');
          print('   Needs Feeding: ${firstStudent.needsFeedingProgram}');
          print(
            '   Assessment Completeness: ${firstStudent.assessment.assessmentCompleteness}',
          );
        }
      }

      return studentAssessments;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ StudentAssessment EXTRACTION ERROR: $e');
        print('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// 🛠️ FIXED: Process sheet with DUAL PERIOD support AND STUDENT TRACKING - ENHANCED ENDLINE EXTRACTION
  static void _processSheetWithDualPeriods(
    Sheet sheet,
    String sheetName,
    ExtractionResult result,
    SchoolProfileImport schoolProfile,
  ) {
    try {
      // Get actual row and column counts
      final rowCount = _getRowCount(sheet);
      final colCount = _getColumnCount(sheet);

      if (kDebugMode) {
        print('DEBUG: Sheet "$sheetName" - $rowCount rows, $colCount columns');
      }

      // DEBUG: Print sheet structure first
      _debugSheetStructure(sheet, sheetName);

      // Find header rows for BOTH periods
      final baselineHeaderInfo = _findHeaderAndMapForPeriod(sheet, 'baseline');
      final endlineHeaderInfo = _findHeaderAndMapForPeriod(sheet, 'endline');

      final baselineHeaderRow = baselineHeaderInfo['headerRow'] as int;
      var baselineColumnMap = baselineHeaderInfo['map'] as Map<String, int>;
      final baselineScore = baselineHeaderInfo['score'] as int;

      final endlineHeaderRow = endlineHeaderInfo['headerRow'] as int;
      var endlineColumnMap = endlineHeaderInfo['map'] as Map<String, int>;
      final endlineScore = endlineHeaderInfo['score'] as int;

      // APPLY MANUAL CORRECTIONS - ENHANCED FOR NUTRITIONAL STATUS
      baselineColumnMap = _correctColumnMapping(baselineColumnMap, 'baseline');
      endlineColumnMap = _correctColumnMapping(endlineColumnMap, 'endline');

      if (kDebugMode) {
        print('🔍 DUAL PERIOD HEADER DETECTION:');
        print('   BASELINE - Row: $baselineHeaderRow, Score: $baselineScore/8');
        print('   Mapping: $baselineColumnMap');
        print('   ENDLINE - Row: $endlineHeaderRow, Score: $endlineScore/8');
        print('   Mapping: $endlineColumnMap');

        // Debug nutritional status column specifically
        if (baselineColumnMap.containsKey('nutritional_status')) {
          print(
            '✅ BASELINE Nutritional Status column: ${baselineColumnMap['nutritional_status']}',
          );
        } else {
          print('❌ BASELINE Nutritional Status column NOT FOUND!');
        }
        if (endlineColumnMap.containsKey('nutritional_status')) {
          print(
            '✅ ENDLINE Nutritional Status column: ${endlineColumnMap['nutritional_status']}',
          );
        } else {
          print('❌ ENDLINE Nutritional Status column NOT FOUND!');
        }
      }

      if (baselineScore < 3) {
        result.problems.add(
          'Weak baseline header detection in "$sheetName" (score: $baselineScore/8)',
        );
        if (kDebugMode) {
          print('❌ WEAK BASELINE HEADER DETECTION - may miss data');
        }
      }

      if (endlineScore < 3) {
        result.problems.add(
          'Weak endline header detection in "$sheetName" (score: $endlineScore/8)',
        );
        if (kDebugMode) {
          print('❌ WEAK ENDLINE HEADER DETECTION - may miss data');
        }
      }

      // 🛠️ CRITICAL FIX: Extract from both periods with enhanced debugging
      if (baselineHeaderRow != -1 && baselineColumnMap.isNotEmpty) {
        // Debug first few student rows for baseline
        if (kDebugMode) {
          _debugFirstStudents(
            sheet,
            baselineHeaderRow,
            baselineColumnMap,
            'Baseline',
          );
        }

        _extractWithDynamicMapping(
          sheet,
          baselineHeaderRow,
          baselineColumnMap,
          sheetName,
          result,
          'Baseline',
          schoolProfile,
        );
      } else {
        result.problems.add('No baseline header found in "$sheetName"');
        if (kDebugMode) print('❌ NO BASELINE HEADER FOUND');
      }

      // 🛠️ CRITICAL FIX: Enhanced Endline extraction with better debugging
      if (endlineHeaderRow != -1 && endlineColumnMap.isNotEmpty) {
        // Debug first few student rows for endline
        if (kDebugMode) {
          print('🎯 ATTEMPTING ENDLINE EXTRACTION FOR SHEET: $sheetName');
          _debugFirstStudents(
            sheet,
            endlineHeaderRow,
            endlineColumnMap,
            'Endline',
          );
        }

        _extractWithDynamicMapping(
          sheet,
          endlineHeaderRow,
          endlineColumnMap,
          sheetName,
          result,
          'Endline',
          schoolProfile,
        );

        if (kDebugMode) {
          print('✅ ENDLINE EXTRACTION COMPLETED FOR SHEET: $sheetName');
        }
      } else {
        result.problems.add('No endline header found in "$sheetName"');
        if (kDebugMode) {
          print('❌ NO ENDLINE HEADER FOUND - Score: $endlineScore');
          print('   Available columns in endline range:');
          _debugEndlineArea(sheet, endlineHeaderRow);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR processing sheet "$sheetName": $e');
      }
      result.problems.add('Error in sheet "$sheetName": $e');
    }
  }

  /// 🛠️ ADDED: Debug Endline area to help identify why Endline extraction fails
  static void _debugEndlineArea(Sheet sheet, int startRow) {
    if (!kDebugMode) return;

    print(
      '🔍 DEBUG ENDLINE AREA (Columns AA-AO, Rows $startRow-${startRow + 5}):',
    );

    for (int r = startRow; r <= startRow + 5 && r < _getRowCount(sheet); r++) {
      List<String> rowVals = [];
      for (int c = 26; c <= 40 && c < _getColumnCount(sheet); c++) {
        // AA (26) to AO (40)
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        );
        final value = _getCellValue(cell) ?? '';
        if (value.isNotEmpty) {
          rowVals.add('Col$c:"$value"');
        }
      }
      if (rowVals.isNotEmpty) {
        print('   Row $r: ${rowVals.join(' | ')}');
      }
    }
  }

  /// ENHANCED: Find headers for specific period (Baseline or Endline) with NUTRITIONAL STATUS
  static Map<String, dynamic> _findHeaderAndMapForPeriod(
    Sheet sheet,
    String period, {
    int maxRowsToCheck = 40,
  }) {
    final expectedKeys = {
      'name': [
        'name',
        'student name',
        'full name',
        'names',
        'pupil',
        'learner',
      ],
      'birthdate': ['birthdate', 'date of birth', 'dob', 'birth date'],
      'weight': ['weight', 'weight (kg)', 'weight kg', 'weight_kg'],
      'height': ['height', 'height (m)', 'height m', 'height_m', 'height (cm)'],
      'sex': ['sex', 'gender', 'sex (m/f)', 'gender (m/f)', 'm/f'],
      'age': ['age', 'age (y:m)', 'age years', 'age y:m'],
      'bmi': ['bmi', 'body mass index', 'bmi value'],
      'nutritional_status': [
        'nutritional status',
        'status',
        'nutritional',
        'classification',
        'bmi category',
        'nutritional status (bmi)',
        'category',
      ],
      'height_for_age': [
        'height for age',
        'height-for-age',
        'hfa',
        'height age',
      ],
      'section': [
        'grade & section',
        'section',
        'grade section',
        'class section',
        'section',
      ],
      'lrn': ['lrn', 'learner reference number', 'student id'],
    };

    int bestRow = -1;
    int bestScore = -1;
    Map<String, int> bestMap = {};

    final rowCount = _getRowCount(sheet);
    final colCount = _getColumnCount(sheet);
    final rowsToCheck = maxRowsToCheck.clamp(1, rowCount);

    // Determine column range based on period
    final int startCol, endCol;
    if (period == 'baseline') {
      startCol = 0; // A
      endCol = 15; // P (extended to find nutritional status)
    } else {
      startCol = 26; // AA
      endCol = 41; // AO (extended to find nutritional status)
    }

    if (kDebugMode) {
      print('🔍 SCANNING FOR $period HEADERS (cols $startCol-$endCol)...');
    }

    for (var r = 0; r < rowsToCheck; r++) {
      int score = 0;
      Map<String, int> candidateMap = {};
      int nonEmptyCells = 0;

      // Only check columns in the target period range
      for (var c = startCol; c <= endCol && c < colCount; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        );
        final raw = cell.value;
        if (raw == null) continue;
        final cellValue = raw.toString().trim();
        if (cellValue.isEmpty) continue;

        nonEmptyCells++;
        final norm = _normalize(cellValue);

        // try to match this normalized header text to expected keys
        for (var entry in expectedKeys.entries) {
          final target = entry.key;
          final aliases = entry.value;
          for (var alias in aliases) {
            if (norm.contains(alias)) {
              score += 1;
              if (!candidateMap.containsKey(target)) {
                candidateMap[target] = c;
                if (kDebugMode && target == 'nutritional_status') {
                  print('✅ FOUND NUTRITIONAL STATUS at col $c: "$cellValue"');
                }
              }
              break;
            }
          }
        }
      }

      // Only consider rows with multiple non-empty cells
      if (nonEmptyCells >= 3 && score > bestScore) {
        bestScore = score;
        bestRow = r;
        bestMap = Map.from(candidateMap);

        if (kDebugMode && score >= 3) {
          print(
            '   $period Row $r: score=$score, nonEmpty=$nonEmptyCells, map=$candidateMap',
          );
        }
      }
    }

    if (kDebugMode) {
      if (bestRow != -1) {
        print('🎯 $period HEADER ROW: $bestRow with score $bestScore/8');
        print('   Column mapping: $bestMap');

        // Debug the winning row
        print('   WINNING ROW CONTENT ($period):');
        for (var c = startCol; c <= endCol && c < colCount; c++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: bestRow),
          );
          final value = cell.value?.toString().trim();
          if (value != null && value.isNotEmpty) {
            print('     Column $c: "$value"');
          }
        }
      } else {
        print('❌ NO $period HEADER ROW FOUND');
      }
    }

    return {'headerRow': bestRow, 'map': bestMap, 'score': bestScore};
  }

  /// ENHANCED: Correct column mapping with period awareness and NUTRITIONAL STATUS
  static Map<String, int> _correctColumnMapping(
    Map<String, int> columnMap,
    String period,
  ) {
    final corrected = Map<String, int>.from(columnMap);

    // Baseline corrections (A-P)
    if (period == 'baseline') {
      // Ensure nutritional status is mapped (typically column K/10)
      if (!corrected.containsKey('nutritional_status')) {
        // Try to find nutritional status in common positions
        corrected['nutritional_status'] = 10; // Column K
        if (kDebugMode) {
          print(
            '⚠️  Nutritional status not found, defaulting to column 10 (K) for baseline',
          );
        }
      }

      if (corrected.containsKey('height') && corrected['height'] == 38) {
        corrected['height'] = 4; // Correct height column in baseline
      }
    }
    // Endline corrections (AA-AO)
    else {
      // Ensure nutritional status is mapped (typically column AK/36)
      if (!corrected.containsKey('nutritional_status')) {
        corrected['nutritional_status'] = 36; // Column AK
        if (kDebugMode) {
          print(
            '⚠️  Nutritional status not found, defaulting to column 36 (AK) for endline',
          );
        }
      }

      if (corrected.containsKey('height') && corrected['height'] == 38) {
        corrected['height'] = 30; // Correct height column in endline (AD)
      }
    }

    // Add section column if missing
    if (!corrected.containsKey('section') &&
        corrected.containsKey('nutritional_status')) {
      if (period == 'baseline') {
        corrected['section'] = 11; // Baseline section column (L)
      } else {
        corrected['section'] = 37; // Endline section column (AL)
      }
    }

    return corrected;
  }

  /// 🛠️ FIXED: Extract with dynamic mapping and period info AND STUDENT TRACKING
  static void _extractWithDynamicMapping(
    Sheet sheet,
    int headerRow,
    Map<String, int> columnMap,
    String sheetName,
    ExtractionResult result,
    String period,
    SchoolProfileImport schoolProfile,
  ) {
    int studentsFound = 0;
    final rowCount = _getRowCount(sheet);
    int consecutiveEmptyRows = 0;
    const maxConsecutiveEmpty = 5;

    for (int r = headerRow + 1; r < rowCount && r < headerRow + 1000; r++) {
      // Check for consecutive empty rows to stop extraction
      if (_isRowEmpty(sheet, r)) {
        consecutiveEmptyRows++;
        if (consecutiveEmptyRows >= maxConsecutiveEmpty) {
          if (kDebugMode) {
            print(
              '🛑 Stopping extraction at row $r - $maxConsecutiveEmpty consecutive empty rows',
            );
          }
          break;
        }
        continue;
      } else {
        consecutiveEmptyRows = 0;
      }

      final student = _extractRowWithDynamicMapping(
        sheet,
        r,
        columnMap,
        sheetName,
        studentsFound,
        period,
        schoolProfile,
      );

      if (student != null && _hasEssentialData(student)) {
        result.students.add(student);
        studentsFound++;

        if (kDebugMode && studentsFound <= 2) {
          print(
            '✅ EXTRACTED $period STUDENT $studentsFound: ${student['name']}',
          );
          print(
            '   Weight: ${student['weight_kg']} kg, Height: ${student['height_cm']} cm',
          );
          print('   BMI: ${student['bmi']}');
          print('   Nutritional Status: ${student['nutritional_status']}');
          print('   Student ID: ${student['student_id']}');
          print(
            '   Assessment Completeness: ${student['assessment_completeness']}',
          );
        }
      }
    }

    if (kDebugMode) {
      print(
        '📊 Sheet "$sheetName" ($period): $studentsFound students extracted',
      );
    }
  }

  /// 🛠️ ENHANCED: Extract row with COMPREHENSIVE DATA EXTRACTION
  static Map<String, dynamic>? _extractRowWithDynamicMapping(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
    String sheetName,
    int studentsFound,
    String period,
    SchoolProfileImport schoolProfile,
  ) {
    try {
      final student = <String, dynamic>{};

      // === ESSENTIAL TRACKING FIELDS ===
      student['student_id'] = '';
      student['normalized_name'] = '';
      student['assessment_completeness'] = 'Unknown';
      student['period'] = period;

      // === SCHOOL PROFILE DATA ===
      student['school_name'] = schoolProfile.schoolName;
      student['district'] = schoolProfile.district;
      student['school_year'] = schoolProfile.schoolYear;
      student['region'] = schoolProfile.region;

      // === ASSESSMENT DATE ===
      String? assessmentDate = _extractAssessmentDate(
        sheet,
        rowIndex,
        columnMap,
        period,
        schoolProfile,
      );
      student['assessment_date'] =
          assessmentDate ?? DateTime.now().toIso8601String().split('T').first;
      student['weighing_date'] = student['assessment_date'];

      // === GRADE LEVEL ===
      student['grade_level'] = _extractGradeFromSheetName(sheetName);

      // === NAME - CRITICAL FIELD ===
      final name = _extractStudentName(sheet, rowIndex, columnMap);
      if (name == null) return null;
      student['name'] = name;
      student['normalized_name'] = StudentIdentificationService.normalizeName(
        name,
      );

      // === ENHANCED BIRTHDATE EXTRACTION ===
      student['birth_date'] = _extractBirthdateEnhanced(
        sheet,
        rowIndex,
        columnMap,
      );

      // === ENHANCED AGE EXTRACTION ===
      student['age'] = _extractAgeWithFallbacks(
        sheet,
        rowIndex,
        columnMap,
        student['assessment_date'],
      );

      // === LRN EXTRACTION ===
      student['lrn'] = _extractLRN(sheet, rowIndex, columnMap);

      // === WEIGHT EXTRACTION ===
      student['weight_kg'] = _extractWeight(sheet, rowIndex, columnMap);

      // === HEIGHT EXTRACTION ===
      student['height_cm'] = _extractHeight(sheet, rowIndex, columnMap);

      // === SEX/GENDER EXTRACTION ===
      student['sex'] = _extractSex(sheet, rowIndex, columnMap);

      // === BMI CALCULATION ===
      student['bmi'] = _calculateOrExtractBMI(
        student,
        sheet,
        rowIndex,
        columnMap,
      );

      // === NUTRITIONAL STATUS ===
      student['nutritional_status'] = _extractNutritionalStatusEnhanced(
        student,
        sheet,
        rowIndex,
        columnMap,
        period,
      );

      // === HEIGHT-FOR-AGE STATUS ===
      student['height_for_age'] = _extractHFAStatusEnhanced(
        student,
        sheet,
        rowIndex,
        columnMap,
      );

      // === SECTION EXTRACTION ===
      student['section'] = _extractSectionWithGradeFallback(
        sheet,
        rowIndex,
        columnMap,
        student,
      );

      // === STUDENT ID GENERATION ===
      if (student['student_id'] == null ||
          student['student_id'].toString().isEmpty) {
        final schoolAcronym = _extractSchoolAcronym(schoolProfile.schoolName);
        student['student_id'] =
            StudentIdentificationService.generateDeterministicStudentID(
          name,
          schoolAcronym,
        );
      }

      // === ASSESSMENT COMPLETENESS ===
      student['assessment_completeness'] =
          _AssessmentCompletenessTracker.determineIndividualCompleteness(
        student,
      );

      // === VALIDATION ===
      if (!_hasEssentialData(student) || !_hasRequiredTrackingFields(student)) {
        return null;
      }

      if (kDebugMode && studentsFound < 2) {
        print('✅ SUCCESSFULLY EXTRACTED STUDENT: ${student['name']}');
        print('   Student ID: ${student['student_id']}');
        print('   Period: ${student['period']}');
        print('   Age: ${student['age']}');
        print('   Birth Date: ${student['birth_date']}');
        print('   LRN: ${student['lrn']}');
        print(
          '   Assessment Completeness: ${student['assessment_completeness']}',
        );
      }

      return student;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR extracting $period row $rowIndex: $e');
      }
      return null;
    }
  }

  /// 🆕 ENHANCED: Extract assessment date with proper fallbacks
  static String? _extractAssessmentDate(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
    String period,
    SchoolProfileImport schoolProfile,
  ) {
    try {
      // 1. Try to extract individual assessment date first
      final dateCol = columnMap['assessment_date'];
      if (dateCol != null) {
        final dateCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: dateCol, rowIndex: rowIndex),
        );
        final individualDate = _parseDate(_getCellValue(dateCell) ?? '');
        if (individualDate != null && individualDate.isNotEmpty) {
          return individualDate;
        }
      }

      // 2. Fallback to school profile date for the period
      if (period == 'Baseline' &&
          schoolProfile.baselineDate != null &&
          schoolProfile.baselineDate!.isNotEmpty) {
        return schoolProfile.baselineDate;
      } else if (period == 'Endline' &&
          schoolProfile.endlineDate != null &&
          schoolProfile.endlineDate!.isNotEmpty) {
        return schoolProfile.endlineDate;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 ENHANCED: Extract student name with validation
  static String? _extractStudentName(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
  ) {
    final nameCol = columnMap['name'];
    if (nameCol == null) return null;

    final nameCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: nameCol, rowIndex: rowIndex),
    );
    final name = _getCellValue(nameCell)?.trim() ?? '';

    if (name.isEmpty ||
        name.length < 2 ||
        _looksLikeHeader(name) ||
        _isNumeric(name)) {
      return null;
    }

    return name;
  }

  /// 🆕 ENHANCED: Extract birthdate with multiple column name support
  static String? _extractBirthdateEnhanced(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
  ) {
    try {
      // Try multiple column names for birthdate
      final birthdateCol = columnMap['birthdate'];
      if (birthdateCol != null) {
        final birthdateCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: birthdateCol,
            rowIndex: rowIndex,
          ),
        );
        final birthdateValue = _getCellValue(birthdateCell) ?? '';

        if (birthdateValue.isNotEmpty) {
          // Enhanced Excel date parsing for birthdates
          final parsedDate = _parseExcelDateEnhanced(birthdateValue);
          if (parsedDate != null) return parsedDate;

          // Fallback to standard date parsing
          return _parseDate(birthdateValue);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 ENHANCED: Robust age extraction with multiple fallbacks
  static int? _extractAgeWithFallbacks(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
    String assessmentDate,
  ) {
    try {
      // 1. Try to extract from "Age (y:m)" column first
      final ageCol = columnMap['age'];
      if (ageCol != null) {
        final ageCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: ageCol, rowIndex: rowIndex),
        );
        final ageValue = _getCellValue(ageCell) ?? '';

        if (ageValue.isNotEmpty) {
          // Parse "6:4" format (years:months)
          final parsedAge = _parseAgeYearMonthFormat(ageValue);
          if (parsedAge != null) {
            return parsedAge;
          }

          // Try simple integer parsing as fallback
          final simpleAge = int.tryParse(ageValue);
          if (simpleAge != null && simpleAge > 0 && simpleAge < 25) {
            return simpleAge;
          }
        }
      }

      // 2. Calculate from Date of Birth if available
      final birthdate = _extractBirthdateEnhanced(sheet, rowIndex, columnMap);
      if (birthdate != null && birthdate.isNotEmpty) {
        final ageFromDOB = _calculateAgeFromDOB(birthdate, assessmentDate);
        if (ageFromDOB != null) {
          return ageFromDOB;
        }
      }

      // 3. Estimate from grade level as final fallback
      return _estimateAgeFromGrade(_extractGradeFromSheetName(sheet as String));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Age extraction error: $e');
      }
      return _estimateAgeFromGrade(_extractGradeFromSheetName(sheet as String));
    }
  }

  /// 🆕 Parse "6:4" year:month format
  static int? _parseAgeYearMonthFormat(String ageValue) {
    try {
      if (ageValue.contains(':')) {
        final parts = ageValue.split(':');
        if (parts.length == 2) {
          final years = int.tryParse(parts[0]);
          // Return just the years for the age field
          return years;
        }
      }

      // Also handle formats like "6 years 4 months"
      if (ageValue.toLowerCase().contains('year')) {
        final yearMatch = RegExp(
          r'(\d+)\s*year',
        ).firstMatch(ageValue.toLowerCase());
        if (yearMatch != null) {
          return int.tryParse(yearMatch.group(1)!);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Calculate age from Date of Birth
  static int? _calculateAgeFromDOB(String dobStr, String assessmentDateStr) {
    try {
      final dob = _parseExcelDateToDateTime(dobStr);
      final assessmentDate =
          DateTime.tryParse(assessmentDateStr) ?? DateTime.now();

      if (dob != null) {
        final age = assessmentDate.year - dob.year;

        // Adjust if birthday hasn't occurred yet this year
        final hasBirthdayOccurred = assessmentDate.month > dob.month ||
            (assessmentDate.month == dob.month &&
                assessmentDate.day >= dob.day);

        return hasBirthdayOccurred ? age : age - 1;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Enhanced Excel date parsing
  static DateTime? _parseExcelDateToDateTime(String dateStr) {
    if (dateStr.isEmpty) return null;

    try {
      // Handle Excel serial numbers (like 43207)
      if (RegExp(r'^\d+$').hasMatch(dateStr)) {
        final excelSerial = int.tryParse(dateStr);
        if (excelSerial != null) {
          // Excel date serial numbers: 1 = Jan 1, 1900
          final baseDate = DateTime(
            1899,
            12,
            30,
          ); // Excel's epoch with leap year adjustment
          return baseDate.add(Duration(days: excelSerial));
        }
      }

      // Use existing date parsing utilities
      return DateUtilities.parseDate(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Estimate age from grade level as final fallback
  static int? _estimateAgeFromGrade(String? gradeLevel) {
    if (gradeLevel == null) return 8; // Default age

    final gradeAgeMap = {
      'Kinder': 5,
      'Grade 1': 6,
      'Grade 2': 7,
      'Grade 3': 8,
      'Grade 4': 9,
      'Grade 5': 10,
      'Grade 6': 11,
      'Grade 7': 12,
      'Grade 8': 13,
      'Grade 9': 14,
      'Grade 10': 15,
      'Grade 11': 16,
      'Grade 12': 17,
    };

    // Try exact match first
    if (gradeAgeMap.containsKey(gradeLevel)) {
      return gradeAgeMap[gradeLevel];
    }

    // Try partial match (e.g., "Grade 1" contains "1")
    final gradeMatch = RegExp(r'(\d+)').firstMatch(gradeLevel);
    if (gradeMatch != null) {
      final gradeNum = int.tryParse(gradeMatch.group(1)!);
      if (gradeNum != null && gradeNum >= 1 && gradeNum <= 12) {
        return gradeNum + 5; // Typical age for grade (6 years old for Grade 1)
      }
    }

    return 8; // Default fallback
  }

  /// 🆕 Extract LRN (Learner Reference Number)
  static String? _extractLRN(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
  ) {
    try {
      final lrnCol = columnMap['lrn'];
      if (lrnCol != null) {
        final lrnCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: lrnCol, rowIndex: rowIndex),
        );
        final lrnValue = _getCellValue(lrnCell) ?? '';

        if (lrnValue.isNotEmpty) {
          // Validate LRN format (typically 12 digits)
          final cleanLRN = lrnValue.replaceAll(RegExp(r'[^\d]'), '');
          if (cleanLRN.length >= 10) {
            // Allow some flexibility in LRN length
            return cleanLRN;
          }
          return lrnValue; // Return original if not perfectly formatted
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Extract weight with enhanced parsing
  static double? _extractWeight(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
  ) {
    try {
      final weightCol = columnMap['weight'];
      if (weightCol != null) {
        final weightCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: weightCol,
            rowIndex: rowIndex,
          ),
        );
        return _parseDouble(_getCellValue(weightCell) ?? '');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Extract height with enhanced parsing
  static double? _extractHeight(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
  ) {
    try {
      final heightCol = columnMap['height'];
      if (heightCol != null) {
        final heightCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: heightCol,
            rowIndex: rowIndex,
          ),
        );
        final heightValue = _getCellValue(heightCell) ?? '';
        return _parseHeight(heightValue);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Extract sex/gender with enhanced normalization
  static String _extractSex(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
  ) {
    try {
      final sexCol = columnMap['sex'];
      if (sexCol != null) {
        final sexCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: sexCol, rowIndex: rowIndex),
        );
        return _cleanSex(_getCellValue(sexCell) ?? '');
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// 🆕 Calculate or extract BMI
  static double? _calculateOrExtractBMI(
    Map<String, dynamic> student,
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
  ) {
    try {
      // Prefer calculation from weight and height for accuracy
      final weight = student['weight_kg'];
      final height = student['height_cm'];

      if (weight != null && height != null && height > 0) {
        // Use NutritionalUtilities to calculate BMI
        final calculatedBMI = NutritionalUtilities.calculateBMI(weight, height);

        if (kDebugMode) {
          print(
            '🎯 BMI CALCULATION: $weight kg / ${height / 100}m = $calculatedBMI',
          );
        }

        return calculatedBMI;
      } else {
        // Fallback to extracted BMI column
        final bmiCol = columnMap['bmi'];
        if (bmiCol != null) {
          final bmiCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: bmiCol, rowIndex: rowIndex),
          );
          final bmiValue = _getCellValue(bmiCell) ?? '';

          // Skip Excel formulas and only parse actual numbers
          if (!_isExcelFormula(bmiValue)) {
            return _parseDouble(bmiValue);
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Enhanced nutritional status extraction
  static String _extractNutritionalStatusEnhanced(
    Map<String, dynamic> student,
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
    String period,
  ) {
    try {
      String? nutritionalStatus;

      // 1. Try to extract from nutritional_status column
      final statusCol = columnMap['nutritional_status'];
      if (statusCol != null) {
        final statusCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: statusCol,
            rowIndex: rowIndex,
          ),
        );
        final rawStatus = _getCellValue(statusCell) ?? '';
        nutritionalStatus = rawStatus.trim();
      }

      // 2. Fixed fallback for SBFP format
      if (nutritionalStatus == null || nutritionalStatus.isEmpty) {
        final fixedStatusCol = period == 'Baseline' ? 7 : 33; // H or AH
        final fixedStatusCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: fixedStatusCol,
            rowIndex: rowIndex,
          ),
        );
        final fixedRawStatus = _getCellValue(fixedStatusCell) ?? '';
        nutritionalStatus = fixedRawStatus.trim();
      }

      // 3. Use NutritionalUtilities for BMI-based classification as final fallback
      final bmi = student['bmi'];
      final age = student['age'];
      final sex = student['sex']?.toString().toLowerCase();

      if (bmi != null &&
          (nutritionalStatus.isEmpty || nutritionalStatus == 'Unknown')) {
        // Use actual age if available, otherwise provide reasonable default for classification
        final ageForClassification = age ??
            _estimateAgeFromGrade(student['grade_level']?.toString()) ??
            8;
        final ageInMonths = ageForClassification * 12;

        final classifiedStatus = NutritionalUtilities.classifyBMI(
          bmi,
          ageInMonths,
          sex,
        );

        if (classifiedStatus != 'Unknown') {
          nutritionalStatus = classifiedStatus;
          if (kDebugMode) {
            print(
              '✅ NUTRITIONALUTILITIES CLASSIFICATION: BMI $bmi, Age $ageForClassification -> $classifiedStatus',
            );
          }
        }
      }

      return nutritionalStatus;
    } catch (e) {
      return 'Unknown';
    }
  }

  /// 🆕 Enhanced Height-for-Age status extraction
  static String? _extractHFAStatusEnhanced(
    Map<String, dynamic> student,
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
  ) {
    try {
      final hfaCol = columnMap['height_for_age'];
      if (hfaCol != null) {
        final hfaCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: hfaCol, rowIndex: rowIndex),
        );
        return _cleanHFAStatus(_getCellValue(hfaCell) ?? '');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Extract section with grade fallback
  static String? _extractSectionWithGradeFallback(
    Sheet sheet,
    int rowIndex,
    Map<String, int> columnMap,
    Map<String, dynamic> student,
  ) {
    try {
      final sectionCol = columnMap['section'];
      if (sectionCol != null) {
        final sectionCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: sectionCol,
            rowIndex: rowIndex,
          ),
        );
        final section = _getCellValue(sectionCell);

        // Extract grade from section if available and update grade level
        if (section != null && section.toString().isNotEmpty) {
          final sectionGrade = _extractGradeFromSection(section.toString());
          if (sectionGrade != 'Unknown') {
            student['grade_level'] = sectionGrade;
          }
        }

        return section;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🛠️ NEW: Validate all required tracking fields are present
  static bool _hasRequiredTrackingFields(Map<String, dynamic> student) {
    final requiredFields = [
      'name',
      'student_id',
      'normalized_name',
      'assessment_completeness',
      'period',
      'grade_level',
    ];

    for (final field in requiredFields) {
      final value = student[field];
      if (value == null || value.toString().trim().isEmpty) {
        if (kDebugMode) {
          print('   Missing field: $field (value: $value)');
        }
        return false;
      }
    }
    return true;
  }

  /// 🛠️ ADDED: Check if cell value contains Excel formula
  static bool _isExcelFormula(String value) {
    if (value.isEmpty) return false;

    final upperValue = value.toUpperCase();
    return upperValue.contains('IFERROR') ||
        upperValue.contains('IF(') ||
        upperValue.contains('INDEX') ||
        upperValue.contains('MATCH') ||
        upperValue.contains('COUNTA') ||
        upperValue.contains('SUM') ||
        upperValue.contains('AVERAGE') ||
        upperValue.startsWith('=');
  }

  /// NEW: Check if sheet should be skipped
  static bool _shouldSkipSheet(String sheetName) {
    final lowerName = sheetName.toLowerCase();
    return lowerName.contains('bmi') ||
        lowerName.contains('hfa') ||
        lowerName.contains('summary') ||
        lowerName.contains('sbfp list') ||
        lowerName.contains('template') ||
        lowerName.contains('instruction');
  }

  /// Debug sheet structure - print rows around header area
  static void _debugSheetStructure(Sheet sheet, String sheetName) {
    if (!kDebugMode) return;

    print('\n🔍 DEBUG SHEET STRUCTURE: "$sheetName"');
    final rowCount = _getRowCount(sheet);
    final colCount = _getColumnCount(sheet);
    print('   Rows: $rowCount, Columns: $colCount');
    print('   Rows 20-30 (suspected header area):');

    int startRow = 20;
    int endRow = (rowCount < 30 ? rowCount : 30);

    for (var r = startRow; r < endRow; r++) {
      List<String> rowVals = [];
      for (var c = 0; c < (colCount < 15 ? colCount : 15); c++) {
        final raw = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value;
        rowVals.add(raw == null ? '""' : '"${raw.toString().trim()}"');
      }
      // Only print rows that have some content
      if (rowVals.any((val) => val != '""')) {
        print('   ROW $r: ${rowVals.join(' | ')}');
      }
    }

    // Show both baseline and endline areas
    print('   BASELINE AREA (A-P):');
    _debugArea(sheet, 20, 30, 0, 15);

    print('   ENDLINE AREA (AA-AO):');
    _debugArea(sheet, 20, 30, 26, 41);
  }

  static void _debugArea(
    Sheet sheet,
    int startRow,
    int endRow,
    int startCol,
    int endCol,
  ) {
    final rowCount = _getRowCount(sheet);
    final actualEndRow = (rowCount < endRow ? rowCount : endRow);

    for (var r = startRow; r < actualEndRow; r++) {
      List<String> rowVals = [];
      for (var c = startCol; c <= endCol && c < _getColumnCount(sheet); c++) {
        final raw = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value;
        rowVals.add(raw == null ? '""' : '"${raw.toString().trim()}"');
      }
      if (rowVals.any((val) => val != '""')) {
        print('   ROW $r: ${rowVals.join(' | ')}');
      }
    }
  }

  /// Debug first few student rows to see what's being extracted
  static void _debugFirstStudents(
    Sheet sheet,
    int headerRow,
    Map<String, int> columnMap,
    String period,
  ) {
    if (!kDebugMode) return;

    print('\n🔍 DEBUG FIRST 3 $period STUDENT ROWS:');
    for (int r = headerRow + 1;
        r < headerRow + 4 && r < _getRowCount(sheet);
        r++) {
      print('   ROW $r:');

      // Show key columns
      final columnsToShow = [
        'name',
        'weight',
        'height',
        'sex',
        'bmi',
        'nutritional_status',
      ];
      for (var colName in columnsToShow) {
        final colIndex = columnMap[colName];
        if (colIndex != null) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: r),
          );
          final value = _getCellValue(cell);
          if (value != null && value.isNotEmpty) {
            print('     $colName ($colIndex): "$value"');
          }
        }
      }

      // Check if row looks like real data
      final nameCol = columnMap['name'];
      if (nameCol != null) {
        final nameCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: nameCol, rowIndex: r),
        );
        final name = _getCellValue(nameCell) ?? '';
        if (name.isNotEmpty && !_looksLikeHeader(name) && name.length >= 2) {
          print('     ✅ VALID $period STUDENT ROW');
        } else {
          print('     ❌ INVALID ROW - name: "$name"');
        }
      }
      print('');
    }
  }

  static String _normalize(String s) {
    if (s.isEmpty) return '';
    return s
        .replaceAll('\u00A0', ' ') // non-breaking spaces
        .replaceAll(RegExp(r'\s+'), ' ') // multiple spaces to single space
        .trim()
        .toLowerCase();
  }

  static int _getRowCount(Sheet sheet) {
    return sheet.rows.length;
  }

  static int _getColumnCount(Sheet sheet) {
    if (sheet.rows.isEmpty) return 0;
    int maxCols = 0;
    for (var row in sheet.rows) {
      if (row.length > maxCols) {
        maxCols = row.length;
      }
    }
    return maxCols;
  }

  static double? _parseHeight(String heightValue) {
    if (heightValue.isEmpty) return null;

    try {
      // IGNORE EXCEL FORMULAS - if it contains IFERROR, INDEX, MATCH, etc.
      if (heightValue.toUpperCase().contains('IFERROR') ||
          heightValue.toUpperCase().contains('INDEX') ||
          heightValue.toUpperCase().contains('MATCH') ||
          heightValue.toUpperCase().contains('ROW')) {
        return null;
      }

      // Clean the value - remove any non-numeric characters except decimal point
      final cleanValue = heightValue.replaceAll(RegExp(r'[^\d.]'), '').trim();
      if (cleanValue.isEmpty) return null;

      // Parse as double
      final height = double.tryParse(cleanValue);
      if (height == null) return null;

      // Based on your file, height is in meters (1, 1.29, 1.43, etc.)
      // Convert meters to centimeters
      if (height > 0 && height < 3) {
        return double.parse((height * 100).toStringAsFixed(1));
      }

      // If already in reasonable cm range, return as-is
      if (height > 30 && height < 250) {
        return double.parse(height.toStringAsFixed(1));
      }

      return null; // Invalid height range
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing height "$heightValue": $e');
      }
      return null;
    }
  }

  static String _extractGradeFromSheetName(String sheetName) {
    final lowerName = sheetName.toLowerCase();

    if (lowerName.contains('kinder') || lowerName.contains('k')) {
      return 'Kinder';
    }
    if (lowerName.contains('grade 1') ||
        lowerName.contains('g1') ||
        lowerName.contains('1')) {
      return 'Grade 1';
    }
    if (lowerName.contains('grade 2') ||
        lowerName.contains('g2') ||
        lowerName.contains('2')) {
      return 'Grade 2';
    }
    if (lowerName.contains('grade 3') ||
        lowerName.contains('g3') ||
        lowerName.contains('3')) {
      return 'Grade 3';
    }
    if (lowerName.contains('grade 4') ||
        lowerName.contains('g4') ||
        lowerName.contains('4')) {
      return 'Grade 4';
    }
    if (lowerName.contains('grade 5') ||
        lowerName.contains('g5') ||
        lowerName.contains('5')) {
      return 'Grade 5';
    }
    if (lowerName.contains('grade 6') ||
        lowerName.contains('g6') ||
        lowerName.contains('6')) {
      return 'Grade 6';
    }
    if (lowerName.contains('sped')) return 'SPED';

    return 'Unknown';
  }

  static String _extractGradeFromSection(String section) {
    final cleanSection = section.trim();

    // Look for grade number at the beginning
    final gradeMatch = RegExp(r'^(\d+)').firstMatch(cleanSection);
    if (gradeMatch != null) {
      final gradeNum = gradeMatch.group(1);
      return 'Grade $gradeNum';
    }

    return 'Unknown';
  } // In excel_extract.dart

  Future<ExtractionResult> extractStudentsFromExcel(
    File file, {
    String? period,
    String? academicYear,
    String? district,
    String? schoolName,
  }) async {
    final result = ExtractionResult();
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      result.problems.add('The Excel file is empty or unreadable.');
      return result;
    }

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows == 0) continue;

      int headerRowIndex = _findHeaderRow(sheet);
      if (headerRowIndex == -1) continue;

      var headers = <String, int>{};
      var headerRow = sheet.rows[headerRowIndex];
      for (var i = 0; i < headerRow.length; i++) {
        var cellValue = headerRow[i]?.value?.toString().trim().toLowerCase();
        if (cellValue != null && cellValue.isNotEmpty) {
          headers[cellValue] = i;
        }
      }

      for (var i = headerRowIndex + 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty) continue;

        dynamic getValue(String key) {
          int? index = headers[key];
          if (index == null) {
            if (key == 'lrn')
              index = headers['lrn'] ?? headers['learner reference number'];
            if (key == 'name')
              index = headers['name'] ??
                  headers['learner name'] ??
                  headers['student name'];
            if (key == 'sex') index = headers['sex'] ?? headers['gender'];
            if (key == 'dob')
              index = headers['birthdate'] ??
                  headers['date of birth'] ??
                  headers['dob'];
            if (key == 'weight')
              index =
                  headers['weight'] ?? headers['weight (kg)'] ?? headers['wt'];
            if (key == 'height')
              index =
                  headers['height'] ?? headers['height (cm)'] ?? headers['ht'];
            if (key == 'period')
              index = headers['period'] ??
                  headers['phase'] ??
                  headers['assessment_period'];
          }
          if (index != null && index < row.length) {
            return row[index]?.value?.toString().trim();
          }
          return null;
        }

        String? name = getValue('name');
        String? lrn = getValue('lrn');

        if ((name == null || name.isEmpty) && (lrn == null || lrn.isEmpty))
          continue;

        // --- 🔍 FIX: Force Period Detection ---
        var rawRowPeriod = getValue('period');
        String? resolvedPeriod;

        // Priority 1: Check row data
        if (rawRowPeriod != null) {
          String p = rawRowPeriod.toString().trim().toLowerCase();
          if (p.contains('base') || p.contains('pre') || p == '1')
            resolvedPeriod = 'Baseline';
          else if (p.contains('end') || p.contains('post') || p == '2')
            resolvedPeriod = 'Endline';
        }

        // Priority 2: Check dropdown selection
        if (resolvedPeriod == null && period != null && period.isNotEmpty) {
          String globalP = period.toString().trim().toLowerCase();
          if (globalP.contains('base'))
            resolvedPeriod = 'Baseline';
          else if (globalP.contains('end')) resolvedPeriod = 'Endline';
        }

        // Priority 3: Default to Baseline if totally unknown (Prevent Null)
        resolvedPeriod ??= 'Baseline';
        // --------------------------------------

        Map<String, dynamic> studentData = {
          'lrn': lrn,
          'learner_name': name,
          'sex': getValue('sex'),
          'birthdate': getValue('dob'),
          'weight': getValue('weight'),
          'height': getValue('height'),
          'date_of_weighing': getValue('date_of_weighing') ?? getValue('date'),
          'grade_level': getValue('grade') ?? getValue('grade_level'),
          'section': getValue('section'),
          'academic_year': academicYear,
          'period': resolvedPeriod,
          'school_name': schoolName,
          'district': district,
        };

        result.students.add(studentData);
      }
    }

    result.success = result.students.isNotEmpty;
    return result;
  }

  /// Helper: Finds the header row index by looking for key columns
  int _findHeaderRow(Sheet sheet) {
    for (int i = 0; i < min(sheet.rows.length, 20); i++) {
      var row = sheet.rows[i];
      var rowString =
          row.map((e) => e?.value.toString().toLowerCase() ?? '').join(' ');

      // If row contains "name" and "lrn" or "weight", it's likely the header
      if ((rowString.contains('name') && rowString.contains('lrn')) ||
          (rowString.contains('name') && rowString.contains('weight'))) {
        return i;
      }
    }
    return -1;
  }

  static bool _hasEssentialData(Map<String, dynamic> student) {
    final name = student['name']?.toString().trim() ?? '';

    // Must have a valid name (not empty, not too short, not header-like)
    if (name.isEmpty || name.length < 3 || _looksLikeHeader(name)) {
      return false;
    }

    // Must have at least weight OR height data
    final hasWeight = student['weight_kg'] != null;
    final hasHeight = student['height_cm'] != null;

    return hasWeight || hasHeight;
  }

  static bool _isRowEmpty(Sheet sheet, int rowIndex) {
    final colCount = _getColumnCount(sheet);

    // 🛠️ FIX: Check BOTH Baseline AND Endline areas
    // Check if this is after header row (where data starts)
    if (rowIndex >= 24) {
      // For Endline data (columns 27-40)
      for (int c = 27; c <= 40 && c < colCount; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
        );
        final value = _getCellValue(cell);
        if (value != null && value.isNotEmpty && value != '-') {
          return false; // Row is NOT empty
        }
      }

      // Also check Baseline area (columns 0-15)
      for (int c = 0; c < 15 && c < colCount; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
        );
        final value = _getCellValue(cell);
        if (value != null && value.isNotEmpty && value != '-') {
          return false; // Row is NOT empty
        }
      }

      return true; // Both areas are empty
    }

    // For rows before header, check first few columns
    for (int c = 0; c < 5 && c < colCount; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
      );
      final value = _getCellValue(cell);
      if (value != null && value.isNotEmpty && value != '-') return false;
    }
    return true;
  }

  static double? _parseDouble(String value) {
    if (value.isEmpty) return null;

    // 🛠️ FIX: Skip Excel formulas
    if (_isExcelFormula(value)) return null;

    final clean = value.replaceAll(',', '').trim();
    return double.tryParse(clean);
  }

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
    ];

    for (var pattern in headerPatterns) {
      if (lower.contains(pattern)) {
        return true;
      }
    }

    return lower.contains('name') &&
        (lower.contains('birthdate') ||
            lower.contains('weight') ||
            lower.contains('height') ||
            lower.contains('sex') ||
            lower.contains('age') ||
            lower.contains('bmi') ||
            lower.contains('nutritional status') ||
            lower.contains('grade & section'));
  }

  static bool _isNumeric(String str) => double.tryParse(str) != null;

  static String _cleanSex(String sex) {
    final clean = sex.trim().toLowerCase();
    if (clean.isEmpty) return 'Unknown';

    if (clean == 'm' || clean == 'male' || clean == 'm.') return 'Male';
    if (clean == 'f' || clean == 'female' || clean == 'f.') return 'Female';
    return 'Unknown';
  }

  static String _cleanHFAStatus(String status) {
    final clean = status.trim().toLowerCase();
    if (clean.contains('severely') && clean.contains('stunted')) {
      return 'Severely Stunted';
    }
    if (clean.contains('stunted')) return 'Stunted';
    if (clean.contains('normal')) return 'Normal';
    return status.isNotEmpty ? status : 'No Data';
  }

  /// Processes the extracted data, resolves periods, merges records, and upserts to the database.
  Future<Map<String, dynamic>> importExtractedData(
    ExtractionResult extractionResult, // 🎯 CRITICAL FIX: Defined here
    DatabaseService dbService,
  ) async {
    // --- START OF METHOD BODY ---// excel_extract.dart (Import Orchestrator) - Full method body

// Assuming your method signature is defined correctly, replace the entire body:
// e.g., Future<Map<String, dynamic>> importExtractedData(ExtractionResult extractionResult, DatabaseService dbService) async {

    final batchResults = <String, dynamic>{
      'learners_inserted': 0,
      'learners_updated': 0,
      'assessments_inserted': 0,
      'assessments_updated': 0,
      'total_processed': extractionResult.students.length,
      'success': true,
    };

    final String academicYear = extractionResult.schoolYear;
    final String schoolId =
        extractionResult.schoolProfile['schoolId']?.toString() ?? '';

    for (final studentFromCSV in extractionResult.students) {
      final String studentId = studentFromCSV['student_id']?.toString() ?? '';

      if (studentId.isEmpty) continue;

      // 1. Fetch the existing student record (Now correctly defined in DatabaseService)
      final existingStudent =
          await dbService.getLearner(studentId, academicYear);

      // 🎯 FIX 1: DETERMINE EXISTING PERIOD (Resolves assessment_period: null)
      String existingPeriod = 'null';
      if (existingStudent.isNotEmpty) {
        final hasBaseline = existingStudent['has_baseline'] == 1 ||
            existingStudent['has_baseline'] == true;
        final hasEndline = existingStudent['has_endline'] == 1 ||
            existingStudent['has_endline'] == true;

        if (hasBaseline && !hasEndline) {
          existingPeriod = 'Baseline';
        } else if (hasEndline) {
          existingPeriod = 'Endline';
        }
      }

      // 🎯 FIX 2: DETERMINE IMPORT PERIOD (Resolves import_period: null)
      final String newPeriod = studentFromCSV['period']?.toString() ??
          extractionResult.schoolProfile['period']?.toString() ??
          'null';

      // 3. CALL THE RESOLVER WITH CORRECTLY ASSIGNED VARIABLES
      final mergedData = StudentMatchingService.resolveStudentData(
          existingStudent, studentFromCSV, existingPeriod, newPeriod);

      // 4. UPSERT: Fixed to include the missing academicYear argument
      try {
        mergedData['student_id'] = studentId;
        mergedData['school_id'] = schoolId;
        mergedData['academic_year'] = academicYear;

        // 🛑 CRITICAL FIX: Pass mergedData AND academicYear
        final Map<String, int> upsertResult = await dbService.upsertLearner(
          mergedData,
          academicYear, // <-- FIXES THE '2 positional arguments expected...' ERROR
        );

        // 5. Update batch results
        batchResults['learners_inserted'] +=
            upsertResult['learners_inserted'] ?? 0;
        batchResults['learners_updated'] +=
            upsertResult['learners_updated'] ?? 0;
        batchResults['assessments_inserted'] +=
            upsertResult['assessments_inserted'] ?? 0;
        batchResults['assessments_updated'] +=
            upsertResult['assessments_updated'] ?? 0;
      } catch (e) {
        if (kDebugMode)
          debugPrint(
              '❌ Database Upsert Error for ${studentFromCSV['learner_name']}: $e');
        batchResults['success'] = false;
      }
    }

    return batchResults;
  }
}

/// ENHANCED: Extraction Result with validation AND STUDENT TRACKING
class ExtractionResult {
  bool success = false;
  List<Map<String, dynamic>> students = [];
  List<String> problems = [];
  Map<String, dynamic> schoolProfile = {};
  ValidationResult? validationResult;

  // 🛠️ FIX: ADD HELPER GETTERS TO SAFELY ACCESS schoolProfile DATA

  /// Helper method to safely get school name
  String get schoolName {
    return schoolProfile['schoolName']?.toString() ??
        schoolProfile['school_name']?.toString() ??
        '';
  }

  /// Helper method to safely get school year
  String get schoolYear {
    return schoolProfile['schoolYear']?.toString() ??
        schoolProfile['school_year']?.toString() ??
        '';
  }

  /// Helper method to safely get district
  String get district {
    return schoolProfile['district']?.toString() ?? '';
  }

  String? get region {
    return schoolProfile['region']?.toString();
  }

  @override
  String toString() {
    // ... use the new getters in toString() as well
    return 'ExtractionResult(success: $success, students: ${students.length}, school: $schoolName, year: $schoolYear)';
  }
}
