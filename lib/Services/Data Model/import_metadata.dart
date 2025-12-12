// lib/Services/Data_Model/import_metadata.dart
import 'dart:convert';

/// 🆕 UPDATED: Enhanced Import Metadata for dual-table structure tracking
class ImportMetadata {
  final String id;
  final String schoolId;
  final String importBatchId;
  final String fileHash;
  final Map<String, dynamic> validationResult;
  final bool cloudSynced;
  final DateTime? syncTimestamp;
  final DateTime createdAt;

  // 🆕 NEW: Dual-table import statistics
  final int? baselineLearnersInserted;
  final int? baselineAssessmentsInserted;
  final int? endlineLearnersInserted;
  final int? endlineAssessmentsInserted;
  final int? totalRecordsProcessed;
  final String? importPeriod;
  final String? resolvedAcademicYear;

  ImportMetadata({
    required this.id,
    required this.schoolId,
    required this.importBatchId,
    required this.fileHash,
    required this.validationResult,
    required this.cloudSynced,
    this.syncTimestamp,
    required this.createdAt,

    // 🆕 NEW: Dual-table statistics
    this.baselineLearnersInserted,
    this.baselineAssessmentsInserted,
    this.endlineLearnersInserted,
    this.endlineAssessmentsInserted,
    this.totalRecordsProcessed,
    this.importPeriod,
    this.resolvedAcademicYear,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_id': schoolId,
      'import_batch_id': importBatchId,
      'file_hash': fileHash,
      'validation_result': validationResult.isNotEmpty
          ? jsonEncode(validationResult)
          : '',
      'cloud_synced': cloudSynced ? 1 : 0,
      'sync_timestamp': syncTimestamp?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      // 🆕 NEW: Dual-table statistics
      'baseline_learners_inserted': baselineLearnersInserted,
      'baseline_assessments_inserted': baselineAssessmentsInserted,
      'endline_learners_inserted': endlineLearnersInserted,
      'endline_assessments_inserted': endlineAssessmentsInserted,
      'total_records_processed': totalRecordsProcessed,
      'import_period': importPeriod,
      'resolved_academic_year': resolvedAcademicYear,
    };
  }

  factory ImportMetadata.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> validationResult = {};
    try {
      if (map['validation_result'] != null &&
          map['validation_result'].toString().isNotEmpty) {
        validationResult = jsonDecode(map['validation_result'].toString());
      }
    } catch (e) {
      validationResult = {'error': 'Failed to parse validation result'};
    }

    return ImportMetadata(
      id: map['id'] ?? '',
      schoolId: map['school_id'] ?? '',
      importBatchId: map['import_batch_id'] ?? '',
      fileHash: map['file_hash'] ?? '',
      validationResult: validationResult,
      cloudSynced: (map['cloud_synced'] ?? 0) == 1,
      syncTimestamp: map['sync_timestamp'] != null
          ? DateTime.parse(map['sync_timestamp'])
          : null,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      // 🆕 NEW: Dual-table statistics
      baselineLearnersInserted: map['baseline_learners_inserted'],
      baselineAssessmentsInserted: map['baseline_assessments_inserted'],
      endlineLearnersInserted: map['endline_learners_inserted'],
      endlineAssessmentsInserted: map['endline_assessments_inserted'],
      totalRecordsProcessed: map['total_records_processed'],
      importPeriod: map['import_period'],
      resolvedAcademicYear: map['resolved_academic_year'],
    );
  }

  // 🆕 NEW: Factory constructor for import results
  factory ImportMetadata.fromImportResults({
    required String schoolId,
    required String importBatchId,
    required String fileHash,
    required Map<String, dynamic> importResults,
    required String period,
    required String academicYear,
  }) {
    final validationResult = {
      'success': importResults['success'] ?? false,
      'total_processed': importResults['total_processed'] ?? 0,
      'successful_inserts': importResults['successful_inserts'] ?? 0,
      'failed_inserts': importResults['failed_inserts'] ?? 0,
      'errors': importResults['errors'] ?? <String>[],
      'import_timestamp': DateTime.now().toIso8601String(),
      // 🆕 NEW: Dual-table specific metrics
      'baseline_learners_inserted':
          importResults['baseline_learners_inserted'] ?? 0,
      'baseline_assessments_inserted':
          importResults['baseline_assessments_inserted'] ?? 0,
      'endline_learners_inserted':
          importResults['endline_learners_inserted'] ?? 0,
      'endline_assessments_inserted':
          importResults['endline_assessments_inserted'] ?? 0,
      'student_ids_created': importResults['student_ids_created'] ?? 0,
      'existing_students_matched':
          importResults['existing_students_matched'] ?? 0,
      'fuzzy_matches_found': importResults['fuzzy_matches_found'] ?? 0,
    };

    return ImportMetadata(
      id: 'meta_$importBatchId',
      schoolId: schoolId,
      importBatchId: importBatchId,
      fileHash: fileHash,
      validationResult: validationResult,
      cloudSynced: false,
      createdAt: DateTime.now(),
      // 🆕 NEW: Dual-table statistics
      baselineLearnersInserted: importResults['baseline_learners_inserted'],
      baselineAssessmentsInserted:
          importResults['baseline_assessments_inserted'],
      endlineLearnersInserted: importResults['endline_learners_inserted'],
      endlineAssessmentsInserted: importResults['endline_assessments_inserted'],
      totalRecordsProcessed: importResults['total_processed'],
      importPeriod: period,
      resolvedAcademicYear: academicYear,
    );
  }

  // 🆕 NEW: Update with import results
  ImportMetadata updateWithImportResults(Map<String, dynamic> importResults) {
    return ImportMetadata(
      id: id,
      schoolId: schoolId,
      importBatchId: importBatchId,
      fileHash: fileHash,
      validationResult: {
        ...validationResult,
        ...importResults,
        'update_timestamp': DateTime.now().toIso8601String(),
      },
      cloudSynced: cloudSynced,
      syncTimestamp: syncTimestamp,
      createdAt: createdAt,
      // 🆕 NEW: Update dual-table statistics
      baselineLearnersInserted:
          importResults['baseline_learners_inserted'] ??
          baselineLearnersInserted,
      baselineAssessmentsInserted:
          importResults['baseline_assessments_inserted'] ??
          baselineAssessmentsInserted,
      endlineLearnersInserted:
          importResults['endline_learners_inserted'] ?? endlineLearnersInserted,
      endlineAssessmentsInserted:
          importResults['endline_assessments_inserted'] ??
          endlineAssessmentsInserted,
      totalRecordsProcessed:
          importResults['total_processed'] ?? totalRecordsProcessed,
      importPeriod: importResults['period'] ?? importPeriod,
      resolvedAcademicYear:
          importResults['resolved_academic_year'] ?? resolvedAcademicYear,
    );
  }

  // Helper methods
  bool get isDuplicateImport =>
      fileHash.isNotEmpty; // Can check against previous hashes

  bool get passedValidation {
    return validationResult['success'] == true &&
        validationResult['school_profile_match'] == true;
  }

  bool get readyForCloudSync => passedValidation && !cloudSynced;

  // 🆕 NEW: Dual-table specific helper methods
  int get totalLearnersInserted {
    return (baselineLearnersInserted ?? 0) + (endlineLearnersInserted ?? 0);
  }

  int get totalAssessmentsInserted {
    return (baselineAssessmentsInserted ?? 0) +
        (endlineAssessmentsInserted ?? 0);
  }

  bool get hasBaselineData => (baselineLearnersInserted ?? 0) > 0;
  bool get hasEndlineData => (endlineLearnersInserted ?? 0) > 0;

  String get importSummary {
    final baseline = hasBaselineData
        ? '$baselineLearnersInserted baseline'
        : '';
    final endline = hasEndlineData ? '$endlineLearnersInserted endline' : '';
    final separator = hasBaselineData && hasEndlineData ? ' + ' : '';

    return '${baselineLearnersInserted ?? 0} learners, ${baselineAssessmentsInserted ?? 0} assessments ($baseline$separator$endline)';
  }

  // 🆕 NEW: Get detailed breakdown for UI display
  Map<String, dynamic> getDetailedBreakdown() {
    return {
      'total_records': totalRecordsProcessed ?? 0,
      'baseline': {
        'learners': baselineLearnersInserted ?? 0,
        'assessments': baselineAssessmentsInserted ?? 0,
        'period': 'Baseline',
      },
      'endline': {
        'learners': endlineLearnersInserted ?? 0,
        'assessments': endlineAssessmentsInserted ?? 0,
        'period': 'Endline',
      },
      'academic_year': resolvedAcademicYear,
      'import_period': importPeriod,
      'success_rate':
          totalRecordsProcessed != null && totalRecordsProcessed! > 0
          ? ((totalLearnersInserted / totalRecordsProcessed!) * 100)
                .toStringAsFixed(1)
          : '0.0',
    };
  }

  // 🆕 NEW: Check if import was successful
  bool get wasSuccessful {
    return passedValidation &&
        (baselineLearnersInserted != null || endlineLearnersInserted != null) &&
        (totalRecordsProcessed == null || totalLearnersInserted > 0);
  }

  // 🆕 NEW: Get error summary
  List<String> get errorSummary {
    final errors = validationResult['errors'] as List<dynamic>?;
    if (errors == null || errors.isEmpty) return [];

    return errors.map((e) => e.toString()).toList();
  }

  @override
  String toString() {
    return 'ImportMetadata{\n'
        '  id: $id,\n'
        '  schoolId: $schoolId,\n'
        '  batchId: $importBatchId,\n'
        '  period: $importPeriod,\n'
        '  academicYear: $resolvedAcademicYear,\n'
        '  baselineLearners: $baselineLearnersInserted,\n'
        '  baselineAssessments: $baselineAssessmentsInserted,\n'
        '  endlineLearners: $endlineLearnersInserted,\n'
        '  endlineAssessments: $endlineAssessmentsInserted,\n'
        '  totalProcessed: $totalRecordsProcessed,\n'
        '  success: ${validationResult['success']},\n'
        '  cloudSynced: $cloudSynced\n'
        '}';
  }
}
