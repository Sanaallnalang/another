// import_schoolprofile.dart - UPDATED MODEL FOR EXCEL SCHOOL PROFILES

import 'package:district_dev/Services/Data%20Model/date_utilities.dart';

class SchoolProfileImport {
  String schoolName;
  String district;
  String schoolYear;
  String? region;
  String? division;
  String? schoolId;
  String? schoolHead;
  String? coordinator;
  String? baselineDate;
  String? endlineDate;
  DateTime? createdAt;
  DateTime? updatedAt;

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
    this.createdAt,
    this.updatedAt,
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 🆕 NEW: Convert to database map for schools table
  Map<String, dynamic> toDatabaseMap() {
    return {
      'school_name': schoolName,
      'district': district,
      'school_year': schoolYear,
      'region': region,
      'division': division,
      'school_id': schoolId,
      'principal_name': schoolHead,
      'sbfp_coordinator': coordinator,
      'baseline_date': baselineDate,
      'endline_date': endlineDate,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'active_academic_years': schoolYear,
      'primary_academic_year': schoolYear,
    };
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
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Validation methods
  bool get hasRequiredFields =>
      schoolName.isNotEmpty && district.isNotEmpty && schoolYear.isNotEmpty;

  bool get hasCompleteProfile =>
      schoolName.isNotEmpty &&
      district.isNotEmpty &&
      schoolYear.isNotEmpty &&
      schoolHead != null &&
      coordinator != null;

  List<String> validate() {
    final errors = <String>[];
    if (schoolName.isEmpty) errors.add('School name is required');
    if (district.isEmpty) errors.add('District is required');
    if (schoolYear.isEmpty) errors.add('School year is required');

    // Validate school year format
    if (!DateUtilities.isValidSchoolYear(schoolYear)) {
      errors.add('School year must be in format YYYY-YYYY');
    }

    // Validate dates if provided
    if (baselineDate != null && baselineDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(baselineDate!);
      if (parsed == null) {
        errors.add('Invalid baseline date format');
      }
    }

    if (endlineDate != null && endlineDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(endlineDate!);
      if (parsed == null) {
        errors.add('Invalid endline date format');
      }
    }

    // Validate assessment period
    if (baselineDate != null &&
        baselineDate!.isNotEmpty &&
        endlineDate != null &&
        endlineDate!.isNotEmpty) {
      final validation = DateUtilities.validateAssessmentPeriod(
        baselineDate!,
        endlineDate!,
      );
      errors.addAll(validation['errors'] as List<String>);
    }

    return errors;
  }

  // Copy with method
  SchoolProfileImport copyWith({
    String? schoolName,
    String? district,
    String? schoolYear,
    String? region,
    String? division,
    String? schoolId,
    String? schoolHead,
    String? coordinator,
    String? baselineDate,
    String? endlineDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SchoolProfileImport(
      schoolName: schoolName ?? this.schoolName,
      district: district ?? this.district,
      schoolYear: schoolYear ?? this.schoolYear,
      region: region ?? this.region,
      division: division ?? this.division,
      schoolId: schoolId ?? this.schoolId,
      schoolHead: schoolHead ?? this.schoolHead,
      coordinator: coordinator ?? this.coordinator,
      baselineDate: baselineDate ?? this.baselineDate,
      endlineDate: endlineDate ?? this.endlineDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 🆕 NEW: Get assessment period information
  Map<String, dynamic> getAssessmentPeriodInfo() {
    final baseline =
        baselineDate != null ? DateTime.tryParse(baselineDate!) : null;
    final endline =
        endlineDate != null ? DateTime.tryParse(endlineDate!) : null;

    Duration? duration;
    if (baseline != null && endline != null) {
      duration = endline.difference(baseline);
    }

    return {
      'has_baseline': baseline != null,
      'has_endline': endline != null,
      'baseline_date': baselineDate,
      'endline_date': endlineDate,
      'duration_days': duration?.inDays,
      'is_complete': baseline != null && endline != null,
      'is_valid_period':
          baseline != null && endline != null && endline.isAfter(baseline),
    };
  }

  /// 🆕 NEW: Update academic years
  SchoolProfileImport updateAcademicYears(List<String> academicYears) {
    // This would typically update the active_academic_years field
    // For now, just return a copy with the latest school year
    final latestYear =
        academicYears.isNotEmpty ? academicYears.last : schoolYear;

    return copyWith(schoolYear: latestYear, updatedAt: DateTime.now());
  }

  @override
  String toString() {
    return 'SchoolProfileImport{\n'
        '  schoolName: $schoolName,\n'
        '  district: $district,\n'
        '  schoolYear: $schoolYear,\n'
        '  region: $region,\n'
        '  division: $division,\n'
        '  schoolHead: $schoolHead,\n'
        '  coordinator: $coordinator,\n'
        '  baselineDate: $baselineDate,\n'
        '  endlineDate: $endlineDate\n'
        '}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolProfileImport &&
          runtimeType == other.runtimeType &&
          schoolName == other.schoolName &&
          district == other.district &&
          schoolYear == other.schoolYear;

  @override
  int get hashCode =>
      schoolName.hashCode ^ district.hashCode ^ schoolYear.hashCode;
}

/// 🆕 NEW: School Statistics Model
class SchoolStatisticsModel {
  final String schoolId;
  final String academicYear;
  final int totalStudents;
  final Map<String, int> nutritionalBreakdown;
  final Map<String, int> gradeDistribution;
  final int sbfpEligibleCount;
  final DateTime calculatedAt;

  SchoolStatisticsModel({
    required this.schoolId,
    required this.academicYear,
    required this.totalStudents,
    required this.nutritionalBreakdown,
    required this.gradeDistribution,
    required this.sbfpEligibleCount,
    required this.calculatedAt,
  });

  /// Calculate improvement from baseline to endline
  Map<String, dynamic> calculateImprovement(SchoolStatisticsModel baseline) {
    final wastedReduction = (baseline.nutritionalBreakdown['wasted'] ?? 0) -
        (nutritionalBreakdown['wasted'] ?? 0);
    final normalImprovement = (nutritionalBreakdown['normal'] ?? 0) -
        (baseline.nutritionalBreakdown['normal'] ?? 0);

    return {
      'wasted_reduction': wastedReduction,
      'normal_improvement': normalImprovement,
      'improvement_rate': baseline.totalStudents > 0
          ? (wastedReduction / baseline.totalStudents) * 100
          : 0,
      'is_improved': wastedReduction > 0,
    };
  }

  /// Convert to database map for nutritional_statistics table
  Map<String, dynamic> toDatabaseMap() {
    return {
      'school_id': schoolId,
      'academic_year': academicYear,
      'total_learners': totalStudents,
      'normal_count': nutritionalBreakdown['normal'] ?? 0,
      'wasted_count': nutritionalBreakdown['wasted'] ?? 0,
      'severely_wasted_count': nutritionalBreakdown['severely_wasted'] ?? 0,
      'overweight_count': nutritionalBreakdown['overweight'] ?? 0,
      'obese_count': nutritionalBreakdown['obese'] ?? 0,
      'sbfp_eligible_count': sbfpEligibleCount,
      'statistics_date': calculatedAt.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
