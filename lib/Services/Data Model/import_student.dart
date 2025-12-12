import 'dart:math';

// ===================================================================
// 🛠️ UPDATED: Centralized Student Identification Service
// ===================================================================

class StudentIdentificationService {
  /// 🔑 Generate a deterministic, persistent student ID.
  static String generateDeterministicStudentID(String name, String schoolId) {
    final cleanName = normalizeName(name);
    final nameHash = cleanName.length > 12
        ? cleanName.substring(0, 12).toUpperCase()
        : cleanName.toUpperCase();
    return '${schoolId}_$nameHash';
  }

  /// Normalize name for consistent matching
  static String normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calculates Jaro-Winkler similarity between two strings
  static double jaroWinklerSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

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

  /// Check if two names likely represent the same student
  static bool isLikelySameStudent(
    String name1,
    String name2, {
    double threshold = 0.85,
  }) {
    return jaroWinklerSimilarity(name1, name2) >= threshold;
  }
}

/// Assessment Completeness Tracker
class AssessmentCompletenessTracker {
  /// Determine assessment completeness for individual student
  static String determineIndividualCompleteness(
    Map<String, dynamic> assessment,
  ) {
    final hasWeight = assessment['weight_kg'] != null;
    final hasHeight = assessment['height_cm'] != null;
    final hasBMI = assessment['bmi'] != null;
    final hasStatus = assessment['nutritional_status'] != null &&
        assessment['nutritional_status'].toString().isNotEmpty &&
        assessment['nutritional_status'].toString() != 'Unknown';

    if (hasWeight && hasHeight && hasBMI && hasStatus) return 'Complete';
    if (hasWeight && hasHeight && hasBMI) return 'Measurements Complete';
    if (hasStatus) return 'Status Only';
    if (hasWeight || hasHeight) return 'Partial Measurements';
    return 'Incomplete';
  }
}

// ===================================================================
// 🆕 SEPARATED DATA MODELS FOR DUAL-TABLE STRUCTURE
// ===================================================================

/// 🆕 Learner demographic data (for baseline_learners/endline_learners tables)
class Learner {
  final int? id; // Database primary key (auto-increment)
  final String studentId; // Business identifier
  final String learnerName;
  final String? lrn;
  final String sex;
  final String gradeLevel;
  final String? section;
  final String? dateOfBirth;
  final int? age;
  final String schoolId;
  final String normalizedName;
  final String academicYear;
  final String? cloudSyncId;
  final String? lastSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  Learner({
    this.id,
    required this.studentId,
    required this.learnerName,
    this.lrn,
    required this.sex,
    required this.gradeLevel,
    this.section,
    this.dateOfBirth,
    this.age,
    required this.schoolId,
    required this.normalizedName,
    required this.academicYear,
    this.cloudSyncId,
    this.lastSynced,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor from raw data
  factory Learner.fromMap(
    Map<String, dynamic> data,
    String schoolId,
    String academicYear,
  ) {
    final name = data['name']?.toString() ?? '';
    final studentId = data['student_id']?.toString() ??
        StudentIdentificationService.generateDeterministicStudentID(
          name,
          schoolId,
        );

    return Learner(
      studentId: studentId,
      learnerName: name,
      lrn: data['lrn']?.toString(),
      sex: data['sex']?.toString() ?? 'Unknown',
      gradeLevel: data['grade_level']?.toString() ?? '',
      section: data['section']?.toString(),
      dateOfBirth: data['birth_date']?.toString(),
      age: data['age'] != null ? int.tryParse(data['age'].toString()) : null,
      schoolId: schoolId,
      normalizedName: StudentIdentificationService.normalizeName(name),
      academicYear: academicYear,
      cloudSyncId: '',
      lastSynced: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to database map for baseline_learners
  Map<String, dynamic> toBaselineLearnerMap() {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      'learner_name': learnerName,
      'lrn': lrn,
      'sex': sex,
      'grade_level': gradeLevel,
      'section': section,
      'date_of_birth': dateOfBirth,
      'age': age,
      'school_id': schoolId,
      'normalized_name': normalizedName,
      'academic_year': academicYear,
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to database map for endline_learners
  Map<String, dynamic> toEndlineLearnerMap() {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      'learner_name': learnerName,
      'lrn': lrn,
      'sex': sex,
      'grade_level': gradeLevel,
      'section': section,
      'date_of_birth': dateOfBirth,
      'age': age,
      'school_id': schoolId,
      'normalized_name': normalizedName,
      'academic_year': academicYear,
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Copy with method
  Learner copyWith({
    int? id,
    String? studentId,
    String? learnerName,
    String? lrn,
    String? sex,
    String? gradeLevel,
    String? section,
    String? dateOfBirth,
    int? age,
    String? schoolId,
    String? normalizedName,
    String? academicYear,
    String? cloudSyncId,
    String? lastSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final updatedName = learnerName ?? this.learnerName;

    return Learner(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      learnerName: updatedName,
      lrn: lrn ?? this.lrn,
      sex: sex ?? this.sex,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      schoolId: schoolId ?? this.schoolId,
      normalizedName: normalizedName ??
          StudentIdentificationService.normalizeName(updatedName),
      academicYear: academicYear ?? this.academicYear,
      cloudSyncId: cloudSyncId ?? this.cloudSyncId,
      lastSynced: lastSynced ?? this.lastSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Validation
  List<String> validate() {
    final errors = <String>[];
    if (learnerName.isEmpty) errors.add('Learner name is required');
    if (sex.isEmpty) errors.add('Sex is required');
    if (gradeLevel.isEmpty) errors.add('Grade level is required');
    if (studentId.isEmpty) errors.add('Student ID is required');
    if (normalizedName.isEmpty) errors.add('Normalized name is required');
    return errors;
  }

  @override
  String toString() {
    return 'Learner{id: $id, studentId: $studentId, name: $learnerName, grade: $gradeLevel, school: $schoolId}';
  }
}

/// 🆕 Assessment data (for baseline_assessments/endline_assessments tables)
class Assessment {
  final int? id; // Database primary key (auto-increment)
  final int learnerId; // Foreign key to learner table
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final String? nutritionalStatus;
  final String assessmentDate;
  final String assessmentCompleteness;
  final DateTime createdAt;
  final String? cloudSyncId;
  final String? lastSynced;

  Assessment({
    this.id,
    required this.learnerId,
    this.weightKg,
    this.heightCm,
    this.bmi,
    this.nutritionalStatus,
    required this.assessmentDate,
    required this.assessmentCompleteness,
    required this.createdAt,
    this.cloudSyncId,
    this.lastSynced,
  });

  /// Factory constructor from raw data
  factory Assessment.fromMap(Map<String, dynamic> data, int learnerId) {
    final completeness =
        AssessmentCompletenessTracker.determineIndividualCompleteness(data);

    return Assessment(
      learnerId: learnerId,
      weightKg: data['weight_kg'] != null
          ? double.tryParse(data['weight_kg'].toString())
          : null,
      heightCm: data['height_cm'] != null
          ? double.tryParse(data['height_cm'].toString())
          : null,
      bmi: data['bmi'] != null ? double.tryParse(data['bmi'].toString()) : null,
      nutritionalStatus: data['nutritional_status']?.toString() ?? 'Unknown',
      assessmentDate:
          data['weighing_date']?.toString() ?? DateTime.now().toIso8601String(),
      assessmentCompleteness: completeness,
      createdAt: DateTime.now(),
      cloudSyncId: '',
      lastSynced: '',
    );
  }

  /// Convert to database map for baseline_assessments
  Map<String, dynamic> toBaselineAssessmentMap() {
    return {
      if (id != null) 'id': id,
      'learner_id': learnerId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'nutritional_status': nutritionalStatus ?? 'Unknown',
      'assessment_date': assessmentDate,
      'assessment_completeness': assessmentCompleteness,
      'created_at': createdAt.toIso8601String(),
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
    };
  }

  /// Convert to database map for endline_assessments
  Map<String, dynamic> toEndlineAssessmentMap() {
    return {
      if (id != null) 'id': id,
      'learner_id': learnerId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'nutritional_status': nutritionalStatus ?? 'Unknown',
      'assessment_date': assessmentDate,
      'assessment_completeness': assessmentCompleteness,
      'created_at': createdAt.toIso8601String(),
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
    };
  }

  /// Compute BMI if not provided
  Assessment computeBMI() {
    if (bmi != null) return this;
    if (weightKg == null || heightCm == null) return this;

    final heightM = heightCm! / 100;
    final computedBMI = weightKg! / (heightM * heightM);

    return copyWith(bmi: double.parse(computedBMI.toStringAsFixed(2)));
  }

  /// Update completeness
  Assessment updateCompleteness() {
    final completeness =
        AssessmentCompletenessTracker.determineIndividualCompleteness({
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'nutritional_status': nutritionalStatus,
    });

    return copyWith(assessmentCompleteness: completeness);
  }

  /// Copy with method
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
      learnerId: learnerId ?? this.learnerId,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bmi: bmi ?? this.bmi,
      nutritionalStatus: nutritionalStatus ?? this.nutritionalStatus,
      assessmentDate: assessmentDate ?? this.assessmentDate,
      assessmentCompleteness:
          assessmentCompleteness ?? this.assessmentCompleteness,
      createdAt: createdAt ?? this.createdAt,
      cloudSyncId: cloudSyncId ?? this.cloudSyncId,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  /// Validation
  List<String> validate() {
    final errors = <String>[];

    if (weightKg != null && (weightKg! < 10 || weightKg! > 200)) {
      errors.add('Weight must be between 10-200 kg');
    }

    if (heightCm != null && (heightCm! < 50 || heightCm! > 250)) {
      errors.add('Height must be between 50-250 cm');
    }

    if (bmi != null && (bmi! < 5 || bmi! > 50)) {
      errors.add('BMI must be between 5-50');
    }

    if (assessmentDate.isEmpty) {
      errors.add('Assessment date is required');
    }

    return errors;
  }

  @override
  String toString() {
    return 'Assessment{id: $id, learnerId: $learnerId, weight: $weightKg, height: $heightCm, bmi: $bmi, status: $nutritionalStatus}';
  }
}

/// 🆕 Combined entity for business logic (transient, not stored)
class StudentAssessment {
  final Learner learner;
  final Assessment assessment;
  final String period;

  StudentAssessment({
    required this.learner,
    required this.assessment,
    required this.period,
  });

  /// 🛠️ FIX: Update the StudentAssessment.fromCombinedData factory constructor
  factory StudentAssessment.fromCombinedData(
    Map<String, dynamic> data,
    String schoolId,
    String academicYear,
    String period,
  ) {
    final name = data['name']?.toString() ?? '';
    final studentId = data['student_id']?.toString() ??
        StudentIdentificationService.generateDeterministicStudentID(
          name,
          schoolId,
        );

    // Create Learner with all required parameters
    final learner = Learner(
      studentId: studentId,
      learnerName: name,
      lrn: data['lrn']?.toString(),
      sex: data['sex']?.toString() ?? 'Unknown',
      gradeLevel: data['grade_level']?.toString() ?? 'Unknown',
      section: data['section']?.toString(),
      dateOfBirth: data['birth_date']?.toString(),
      age: data['age'] != null ? int.tryParse(data['age'].toString()) : null,
      schoolId: schoolId,
      normalizedName: StudentIdentificationService.normalizeName(name),
      academicYear: academicYear,
      cloudSyncId: '',
      lastSynced: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create Assessment with all required parameters
    final assessment = Assessment(
      learnerId: 0, // Will be set to actual learnerId during insertion
      weightKg: data['weight_kg'] != null
          ? double.tryParse(data['weight_kg'].toString())
          : null,
      heightCm: data['height_cm'] != null
          ? double.tryParse(data['height_cm'].toString())
          : null,
      bmi: data['bmi'] != null ? double.tryParse(data['bmi'].toString()) : null,
      nutritionalStatus: data['nutritional_status']?.toString() ?? 'Unknown',
      assessmentDate: data['assessment_date']?.toString() ??
          data['weighing_date']?.toString() ??
          DateTime.now().toIso8601String(),
      assessmentCompleteness: data['assessment_completeness']?.toString() ??
          AssessmentCompletenessTracker.determineIndividualCompleteness(data),
      createdAt: DateTime.now(),
      cloudSyncId: '',
      lastSynced: '',
    );

    return StudentAssessment(
      learner: learner,
      assessment: assessment,
      period: period,
    );
  }

  /// Check if has complete measurements
  bool get hasCompleteMeasurements =>
      assessment.weightKg != null &&
      assessment.heightCm != null &&
      assessment.bmi != null;

  /// Check if has nutritional assessment
  bool get hasNutritionalAssessment =>
      assessment.nutritionalStatus != null &&
      assessment.nutritionalStatus!.isNotEmpty &&
      assessment.nutritionalStatus! != 'Unknown';

  /// Determine if needs feeding program
  bool get needsFeedingProgram {
    final status = assessment.nutritionalStatus?.toLowerCase() ?? '';
    return status.contains('wasted') ||
        status.contains('severely') ||
        status.contains('underweight');
  }

  /// Get feeding priority
  String get feedingPriority {
    final status = assessment.nutritionalStatus?.toLowerCase() ?? '';
    if (status.contains('severely')) return 'High';
    if (status.contains('wasted') || status.contains('underweight')) {
      return 'Medium';
    }
    return 'Low';
  }

  /// Validation
  List<String> validate() {
    final errors = <String>[];
    errors.addAll(learner.validate());
    errors.addAll(assessment.validate());

    if (period.isEmpty) {
      errors.add('Assessment period is required');
    }

    if (!hasCompleteMeasurements && !hasNutritionalAssessment) {
      errors.add(
        'Student must have at least measurements or nutritional status',
      );
    }

    return errors;
  }

  @override
  String toString() {
    return 'StudentAssessment{learner: ${learner.learnerName}, period: $period, completeness: ${assessment.assessmentCompleteness}}';
  }
}

// ===================================================================
// 🆕 PROGRESS TRACKING AND ANALYTICS MODELS
// ===================================================================

/// Student progress across periods
class StudentProgress {
  final String studentId;
  final String studentName;
  final List<Assessment> assessments;
  final Map<String, String> gradeProgression; // academicYear -> gradeLevel

  StudentProgress({
    required this.studentId,
    required this.studentName,
    required this.assessments,
    required this.gradeProgression,
  });

  /// Get baseline assessment
  Assessment? get baselineAssessment => assessments.firstWhere(
        (assessment) => _getAssessmentPeriod(assessment) == 'Baseline',
        orElse: () => Assessment(
          learnerId: 0,
          assessmentDate: '',
          assessmentCompleteness: 'Unknown',
          createdAt: DateTime.now(),
        ),
      );

  /// Get endline assessment
  Assessment? get endlineAssessment => assessments.firstWhere(
        (assessment) => _getAssessmentPeriod(assessment) == 'Endline',
        orElse: () => Assessment(
          learnerId: 0,
          assessmentDate: '',
          assessmentCompleteness: 'Unknown',
          createdAt: DateTime.now(),
        ),
      );

  /// Calculate progress
  Map<String, dynamic> calculateProgress() {
    final baseline = baselineAssessment;
    final endline = endlineAssessment;

    if (baseline == null || endline == null) {
      return {
        'hasProgress': false,
        'message': 'Incomplete data for progress tracking',
      };
    }

    final weightChange = endline.weightKg != null && baseline.weightKg != null
        ? endline.weightKg! - baseline.weightKg!
        : null;

    final heightChange = endline.heightCm != null && baseline.heightCm != null
        ? endline.heightCm! - baseline.heightCm!
        : null;

    final bmiChange = endline.bmi != null && baseline.bmi != null
        ? endline.bmi! - baseline.bmi!
        : null;

    final statusImproved = _calculateStatusImprovement(
      baseline.nutritionalStatus,
      endline.nutritionalStatus,
    );

    return {
      'hasProgress': true,
      'weightChange': weightChange,
      'heightChange': heightChange,
      'bmiChange': bmiChange,
      'statusImproved': statusImproved,
      'baseline': {
        'weight': baseline.weightKg,
        'height': baseline.heightCm,
        'bmi': baseline.bmi,
        'status': baseline.nutritionalStatus,
      },
      'endline': {
        'weight': endline.weightKg,
        'height': endline.heightCm,
        'bmi': endline.bmi,
        'status': endline.nutritionalStatus,
      },
    };
  }

  // Helper method to extract period from assessment (would need database context)
  String _getAssessmentPeriod(Assessment assessment) {
    // This would typically come from joined query or additional field
    // For now, return a placeholder
    return 'Baseline'; // Would need actual implementation
  }

  bool _calculateStatusImprovement(
    String? baselineStatus,
    String? endlineStatus,
  ) {
    if (baselineStatus == null || endlineStatus == null) return false;

    final statusHierarchy = {
      'Severely Wasted': 0,
      'Wasted': 1,
      'Underweight': 2,
      'Normal': 3,
      'Overweight': 4,
      'Obese': 5,
    };

    final baselineScore = statusHierarchy[baselineStatus] ?? 0;
    final endlineScore = statusHierarchy[endlineStatus] ?? 0;

    return endlineScore > baselineScore; // Higher is better in this hierarchy
  }
}

/// School statistics model
class SchoolStatistics {
  final String schoolId;
  final String academicYear;
  final Map<String, dynamic> baselineStats;
  final Map<String, dynamic> endlineStats;
  final DateTime calculatedAt;

  SchoolStatistics({
    required this.schoolId,
    required this.academicYear,
    required this.baselineStats,
    required this.endlineStats,
    required this.calculatedAt,
  });

  /// Calculate improvement metrics
  Map<String, dynamic> calculateImprovement() {
    final baselineTotal = baselineStats['total_students'] as int? ?? 0;
    final endlineTotal = endlineStats['total_students'] as int? ?? 0;

    final baselineWasted = baselineStats['wasted_count'] as int? ?? 0;
    final endlineWasted = endlineStats['wasted_count'] as int? ?? 0;

    final baselineNormal = baselineStats['normal_count'] as int? ?? 0;
    final endlineNormal = endlineStats['normal_count'] as int? ?? 0;

    return {
      'totalStudentsChange': endlineTotal - baselineTotal,
      'wastedReduction': baselineWasted - endlineWasted,
      'normalImprovement': endlineNormal - baselineNormal,
      'improvementRate': baselineTotal > 0
          ? ((baselineWasted - endlineWasted) / baselineTotal) * 100
          : 0,
    };
  }
}

// ===================================================================
// 🆕 UPDATED: SBFP Student model for backward compatibility and data transformation
// ===================================================================

class SBFPStudent {
  // ========== LEARNER FIELDS (for baseline_learners/endline_learners tables) ==========
  final String id;
  final String studentId;
  final String name;
  final String? lrn;
  final String sex;
  final String gradeLevel;
  final String? section;
  final String? dateOfBirth;
  final int? age;
  final String schoolId;
  final String normalizedName;
  final String academicYear;
  final String? cloudSyncId;
  final String? lastSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ========== ASSESSMENT FIELDS (for baseline_assessments/endline_assessments tables) ==========
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final String? nutritionalStatus;
  final String period;
  final String? weighingDate;
  final String assessmentCompleteness;

  // ========== CONSTRUCTOR ==========
  SBFPStudent({
    // Learner fields
    required this.id,
    required this.studentId,
    required this.name,
    this.lrn,
    required this.sex,
    required this.gradeLevel,
    this.section,
    this.dateOfBirth,
    this.age,
    required this.schoolId,
    required this.normalizedName,
    required this.academicYear,
    this.cloudSyncId,
    this.lastSynced,
    required this.createdAt,
    required this.updatedAt,

    // Assessment fields
    this.weightKg,
    this.heightCm,
    this.bmi,
    this.nutritionalStatus,
    required this.period,
    this.weighingDate,
    this.assessmentCompleteness = 'Unknown',
  });

  /// 🆕 NEW: Convert from StudentAssessment to SBFPStudent (for backward compatibility)
  factory SBFPStudent.fromStudentAssessment(
    StudentAssessment studentAssessment,
  ) {
    return SBFPStudent(
      id: 'import_${DateTime.now().millisecondsSinceEpoch}_${studentAssessment.learner.learnerName}',
      studentId: studentAssessment.learner.studentId,
      name: studentAssessment.learner.learnerName,
      lrn: studentAssessment.learner.lrn,
      sex: studentAssessment.learner.sex,
      gradeLevel: studentAssessment.learner.gradeLevel,
      section: studentAssessment.learner.section,
      dateOfBirth: studentAssessment.learner.dateOfBirth,
      age: studentAssessment.learner.age,
      schoolId: studentAssessment.learner.schoolId,
      normalizedName: studentAssessment.learner.normalizedName,
      academicYear: studentAssessment.learner.academicYear,
      cloudSyncId: studentAssessment.learner.cloudSyncId,
      lastSynced: studentAssessment.learner.lastSynced,
      createdAt: studentAssessment.learner.createdAt,
      updatedAt: studentAssessment.learner.updatedAt,
      // Assessment fields
      weightKg: studentAssessment.assessment.weightKg,
      heightCm: studentAssessment.assessment.heightCm,
      bmi: studentAssessment.assessment.bmi,
      nutritionalStatus: studentAssessment.assessment.nutritionalStatus,
      period: studentAssessment.period,
      weighingDate: studentAssessment.assessment.assessmentDate,
      assessmentCompleteness:
          studentAssessment.assessment.assessmentCompleteness,
    );
  }

  /// 🆕 NEW: Convert SBFPStudent to StudentAssessment
  StudentAssessment toStudentAssessment() {
    final learner = Learner(
      studentId: studentId,
      learnerName: name,
      lrn: lrn,
      sex: sex,
      gradeLevel: gradeLevel,
      section: section,
      dateOfBirth: dateOfBirth,
      age: age,
      schoolId: schoolId,
      normalizedName: normalizedName,
      academicYear: academicYear,
      cloudSyncId: cloudSyncId ?? '',
      lastSynced: lastSynced ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final assessment = Assessment(
      learnerId: 0, // Will be set when inserted
      weightKg: weightKg,
      heightCm: heightCm,
      bmi: bmi,
      nutritionalStatus: nutritionalStatus,
      assessmentDate: weighingDate ?? createdAt.toIso8601String(),
      assessmentCompleteness: assessmentCompleteness,
      createdAt: createdAt,
      cloudSyncId: cloudSyncId ?? '',
      lastSynced: lastSynced ?? '',
    );

    return StudentAssessment(
      learner: learner,
      assessment: assessment,
      period: period,
    );
  }

  /// 🆕 NEW: Convert to Learner and Assessment separate objects
  Map<String, dynamic> toSeparatedModels() {
    final learner = Learner(
      studentId: studentId,
      learnerName: name,
      lrn: lrn,
      sex: sex,
      gradeLevel: gradeLevel,
      section: section,
      dateOfBirth: dateOfBirth,
      age: age,
      schoolId: schoolId,
      normalizedName: normalizedName,
      academicYear: academicYear,
      cloudSyncId: cloudSyncId ?? '',
      lastSynced: lastSynced ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final assessment = Assessment(
      learnerId: 0, // Will be set when inserted
      weightKg: weightKg,
      heightCm: heightCm,
      bmi: bmi,
      nutritionalStatus: nutritionalStatus,
      assessmentDate: weighingDate ?? createdAt.toIso8601String(),
      assessmentCompleteness: assessmentCompleteness,
      createdAt: createdAt,
      cloudSyncId: cloudSyncId ?? '',
      lastSynced: lastSynced ?? '',
    );

    return {'learner': learner, 'assessment': assessment, 'period': period};
  }

  // ========== EXISTING METHODS (PRESERVED FOR BACKWARD COMPATIBILITY) ==========

  /// Map to baseline_learners table
  Map<String, dynamic> toBaselineLearnerMap() {
    return {
      'student_id': studentId,
      'learner_name': name,
      'lrn': lrn,
      'sex': sex,
      'grade_level': gradeLevel,
      'section': section,
      'date_of_birth': dateOfBirth,
      'age': age,
      'school_id': schoolId,
      'normalized_name': normalizedName,
      'academic_year': academicYear,
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Map to endline_learners table
  Map<String, dynamic> toEndlineLearnerMap() {
    return {
      'student_id': studentId,
      'learner_name': name,
      'lrn': lrn,
      'sex': sex,
      'grade_level': gradeLevel,
      'section': section,
      'date_of_birth': dateOfBirth,
      'age': age,
      'school_id': schoolId,
      'normalized_name': normalizedName,
      'academic_year': academicYear,
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Map to baseline_assessments table (requires learner_id from database)
  Map<String, dynamic> toBaselineAssessmentMap(int learnerId) {
    return {
      'learner_id': learnerId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'nutritional_status': nutritionalStatus ?? 'Unknown',
      'assessment_date': weighingDate ?? createdAt.toIso8601String(),
      'assessment_completeness': assessmentCompleteness,
      'created_at': createdAt.toIso8601String(),
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
    };
  }

  /// Map to endline_assessments table (requires learner_id from database)
  Map<String, dynamic> toEndlineAssessmentMap(int learnerId) {
    return {
      'learner_id': learnerId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'nutritional_status': nutritionalStatus ?? 'Unknown',
      'assessment_date': weighingDate ?? createdAt.toIso8601String(),
      'assessment_completeness': assessmentCompleteness,
      'created_at': createdAt.toIso8601String(),
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
    };
  }

  // ========== FACTORY CONSTRUCTORS ==========
  /// Create from CleanResult data
  factory SBFPStudent.fromCleanData(
    Map<String, dynamic> studentData,
    String schoolId, [
    String academicYear = '2023-2024',
  ]) {
    final name = studentData['name']?.toString() ?? '';
    final studentId =
        StudentIdentificationService.generateDeterministicStudentID(
      name,
      schoolId,
    );
    final normalizedName = StudentIdentificationService.normalizeName(name);
    final period = studentData['period']?.toString() ?? 'Baseline';

    return SBFPStudent(
      id: 'import_${DateTime.now().millisecondsSinceEpoch}_$name',
      studentId: studentId,
      name: name,
      lrn: studentData['lrn']?.toString(),
      sex: studentData['sex']?.toString() ?? 'Unknown',
      gradeLevel: studentData['grade_level']?.toString() ?? '',
      section: studentData['section']?.toString(),
      dateOfBirth: studentData['birth_date']?.toString(),
      age: studentData['age'] != null
          ? int.tryParse(studentData['age'].toString())
          : null,
      schoolId: schoolId,
      normalizedName: normalizedName,
      academicYear: academicYear,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      // Assessment fields
      weightKg: studentData['weight_kg'] != null
          ? double.tryParse(studentData['weight_kg'].toString())
          : null,
      heightCm: studentData['height_cm'] != null
          ? double.tryParse(studentData['height_cm'].toString())
          : null,
      bmi: studentData['bmi'] != null
          ? double.tryParse(studentData['bmi'].toString())
          : null,
      nutritionalStatus: studentData['nutritional_status']?.toString(),
      period: period,
      weighingDate: studentData['weighing_date']?.toString(),
      assessmentCompleteness:
          AssessmentCompletenessTracker.determineIndividualCompleteness(
        studentData,
      ),
    );
  }

  /// Create from Excel extraction data
  factory SBFPStudent.fromExtractedData(
    Map<String, dynamic> extractedData,
    String schoolId, [
    String academicYear = '2023-2024',
  ]) {
    final name = extractedData['name']?.toString() ?? '';
    final studentId =
        StudentIdentificationService.generateDeterministicStudentID(
      name,
      schoolId,
    );
    final normalizedName = StudentIdentificationService.normalizeName(name);
    final period = extractedData['period']?.toString() ?? 'Baseline';

    return SBFPStudent(
      id: 'extracted_${DateTime.now().millisecondsSinceEpoch}_$name',
      studentId: studentId,
      name: name,
      lrn: extractedData['lrn']?.toString(),
      sex: extractedData['sex']?.toString() ?? 'Unknown',
      gradeLevel: extractedData['grade_level']?.toString() ?? '',
      section: extractedData['section']?.toString(),
      dateOfBirth: extractedData['birth_date']?.toString(),
      age: extractedData['age'] != null
          ? int.tryParse(extractedData['age'].toString())
          : null,
      schoolId: schoolId,
      normalizedName: normalizedName,
      academicYear: academicYear,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      // Assessment fields
      weightKg: extractedData['weight_kg'] != null
          ? double.tryParse(extractedData['weight_kg'].toString())
          : null,
      heightCm: extractedData['height_cm'] != null
          ? double.tryParse(extractedData['height_cm'].toString())
          : null,
      bmi: extractedData['bmi'] != null
          ? double.tryParse(extractedData['bmi'].toString())
          : null,
      nutritionalStatus: extractedData['nutritional_status']?.toString(),
      period: period,
      weighingDate: extractedData['weighing_date']?.toString(),
      assessmentCompleteness:
          AssessmentCompletenessTracker.determineIndividualCompleteness(
        extractedData,
      ),
    );
  }

  // ========== HELPER METHODS ==========

  /// Generate consistent student ID using the new service
  static String generateStudentID(String name, String schoolId) {
    return StudentIdentificationService.generateDeterministicStudentID(
      name,
      schoolId,
    );
  }

  // ========== VALIDATION METHODS ==========

  bool get hasStudentTracking =>
      studentId.isNotEmpty && normalizedName.isNotEmpty;

  bool get canBeTrackedAcrossYears => hasStudentTracking && hasRequiredData;

  bool get hasRequiredData =>
      name.isNotEmpty && sex.isNotEmpty && gradeLevel.isNotEmpty;

  bool get hasCompleteMeasurements =>
      weightKg != null && heightCm != null && bmi != null;

  bool get hasNutritionalAssessment =>
      nutritionalStatus != null &&
      nutritionalStatus!.isNotEmpty &&
      nutritionalStatus! != 'Unknown';

  bool get hasWeightKg => weightKg != null;

  bool get hasHeightCm => heightCm != null;

  bool get hasBMI => bmi != null;

  bool get isValidForImport =>
      hasRequiredData &&
      (hasCompleteMeasurements ||
          hasNutritionalAssessment ||
          hasWeightKg ||
          hasHeightCm);

  bool get isBaseline => period.toLowerCase() == 'baseline';

  bool get isEndline => period.toLowerCase() == 'endline';

  bool get hasProgressData =>
      hasCompleteMeasurements && hasNutritionalAssessment;

  String get progressTrackingStatus {
    if (!hasStudentTracking) return 'No Tracking';
    if (!hasRequiredData) return 'Incomplete Data';
    if (hasProgressData) return 'Ready for Tracking';
    if (hasNutritionalAssessment) return 'Status Only - Needs Measurements';
    if (hasCompleteMeasurements) return 'Measurements Complete - Needs Status';
    return 'Needs Assessment';
  }

  List<String> validate() {
    final errors = <String>[];

    if (name.isEmpty) errors.add('Student name is required');
    if (sex.isEmpty) errors.add('Sex is required');
    if (gradeLevel.isEmpty) errors.add('Grade level is required');
    if (period.isEmpty) errors.add('Assessment period is required');

    if (weightKg != null && (weightKg! < 10 || weightKg! > 200)) {
      errors.add('Weight must be between 10-200 kg');
    }

    if (heightCm != null && (heightCm! < 50 || heightCm! > 250)) {
      errors.add('Height must be between 50-250 cm');
    }

    if (bmi != null && (bmi! < 5 || bmi! > 50)) {
      errors.add('BMI must be between 5-50');
    }

    if (studentId.isEmpty) {
      errors.add('Student ID is required for tracking');
    }

    if (normalizedName.isEmpty) {
      errors.add('Normalized name is required for fuzzy matching');
    }

    if (!hasWeightKg && !hasHeightCm && !hasNutritionalAssessment) {
      errors.add(
        'Student must have at least weight, height, or nutritional status data',
      );
    }

    return errors;
  }

  // ========== BUSINESS LOGIC METHODS ==========

  bool get needsFeedingProgram {
    final status = nutritionalStatus?.toLowerCase() ?? '';
    return status.contains('wasted') ||
        status.contains('severely') ||
        status.contains('underweight');
  }

  String get feedingPriority {
    final status = nutritionalStatus?.toLowerCase() ?? '';
    if (status.contains('severely')) return 'High';
    if (status.contains('wasted') || status.contains('underweight')) {
      return 'Medium';
    }
    return 'Low';
  }

  // ========== COPY/MODIFICATION METHODS ==========

  SBFPStudent copyWith({
    // Learner fields
    String? name,
    String? lrn,
    String? sex,
    String? gradeLevel,
    String? section,
    String? dateOfBirth,
    int? age,
    String? schoolId,
    String? studentId,
    String? normalizedName,
    String? academicYear,
    String? cloudSyncId,
    String? lastSynced,

    // Assessment fields
    double? weightKg,
    double? heightCm,
    double? bmi,
    String? nutritionalStatus,
    String? period,
    String? weighingDate,
    String? assessmentCompleteness,
  }) {
    final updatedName = name ?? this.name;
    final updatedSchoolId = schoolId ?? this.schoolId;

    return SBFPStudent(
      id: id,
      // Learner fields
      studentId: studentId ?? this.studentId,
      name: updatedName,
      lrn: lrn ?? this.lrn,
      sex: sex ?? this.sex,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      schoolId: updatedSchoolId,
      normalizedName: normalizedName ??
          StudentIdentificationService.normalizeName(updatedName),
      academicYear: academicYear ?? this.academicYear,
      cloudSyncId: cloudSyncId ?? this.cloudSyncId,
      lastSynced: lastSynced ?? this.lastSynced,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      // Assessment fields
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bmi: bmi ?? this.bmi,
      nutritionalStatus: nutritionalStatus ?? this.nutritionalStatus,
      period: period ?? this.period,
      weighingDate: weighingDate ?? this.weighingDate,
      assessmentCompleteness: assessmentCompleteness ??
          AssessmentCompletenessTracker.determineIndividualCompleteness({
            'weight_kg': weightKg ?? this.weightKg,
            'height_cm': heightCm ?? this.heightCm,
            'bmi': bmi ?? this.bmi,
            'nutritional_status': nutritionalStatus ?? this.nutritionalStatus,
          }),
    );
  }

  SBFPStudent computeBMI() {
    if (bmi != null) return this;
    if (weightKg == null || heightCm == null) return this;

    final heightM = heightCm! / 100;
    final computedBMI = weightKg! / (heightM * heightM);

    return copyWith(bmi: double.parse(computedBMI.toStringAsFixed(2)));
  }

  SBFPStudent updateCompleteness() {
    return copyWith(
      assessmentCompleteness:
          AssessmentCompletenessTracker.determineIndividualCompleteness({
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'bmi': bmi,
        'nutritional_status': nutritionalStatus,
      }),
    );
  }

  SBFPStudent updateStudentTracking() {
    return copyWith(
      normalizedName: StudentIdentificationService.normalizeName(name),
    );
  }

  // ========== UTILITY METHODS ==========

  @override
  String toString() {
    return 'SBFPStudent{name: $name, studentId: $studentId, grade: $gradeLevel, period: $period, status: $nutritionalStatus, completeness: $assessmentCompleteness, tracking: $progressTrackingStatus}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SBFPStudent &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          name == other.name &&
          lrn == other.lrn &&
          gradeLevel == other.gradeLevel &&
          period == other.period &&
          academicYear == other.academicYear;

  @override
  int get hashCode =>
      studentId.hashCode ^
      name.hashCode ^
      lrn.hashCode ^
      gradeLevel.hashCode ^
      period.hashCode ^
      academicYear.hashCode;

  // ========== SERIALIZATION METHODS ==========

  Map<String, dynamic> toProgressMap() {
    return {
      'student_id': studentId,
      'name': name,
      'grade_level': gradeLevel,
      'period': period,
      'school_year': academicYear,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'nutritional_status': nutritionalStatus,
      'assessment_completeness': assessmentCompleteness,
      'assessment_date': weighingDate ?? createdAt.toIso8601String(),
      'has_complete_data': hasCompleteMeasurements && hasNutritionalAssessment,
      'progress_tracking_status': progressTrackingStatus,
    };
  }

  Map<String, dynamic> toChartData() {
    return {
      'academic_year': academicYear,
      'period': period,
      'bmi': bmi,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'nutritional_status': nutritionalStatus,
      'label': '$academicYear $period',
      'grade_level': gradeLevel,
    };
  }

  // ========== DATABASE COMPATIBILITY METHODS ==========

  /// Convert to Database-ready map with correct field names (for backward compatibility)
  Map<String, dynamic> toDatabaseMap({String? importBatchId}) {
    final batchId =
        importBatchId ?? 'batch_${DateTime.now().millisecondsSinceEpoch}';

    return {
      'id': id,
      'school_id': schoolId,
      'grade_level_id': _mapGradeToId(gradeLevel),
      'grade_name': gradeLevel,
      'learner_name': name,
      'sex': sex,
      'date_of_birth': dateOfBirth,
      'age': _calculateAge(dateOfBirth),
      'nutritional_status': nutritionalStatus ?? 'Unknown',
      'assessment_period': period,
      'assessment_date': weighingDate ?? createdAt.toIso8601String(),
      'height': heightCm,
      'weight': weightKg,
      'bmi': bmi,
      'lrn': lrn,
      'section': section,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'import_batch_id': batchId,
      'cloud_sync_id': cloudSyncId ?? '',
      'last_synced': lastSynced ?? '',
      'academic_year': academicYear,
      // Student tracking fields
      'student_id': studentId,
      'normalized_name': normalizedName,
      'assessment_completeness': assessmentCompleteness,
      'period': period,
    };
  }

  /// Convert to legacy map format
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lrn': lrn,
      'sex': sex,
      'grade_level': gradeLevel,
      'section': section,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'nutritional_status': nutritionalStatus,
      'period': period,
      'school_year': academicYear,
      'weighing_date': weighingDate,
      'school_id': schoolId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Student tracking fields
      'student_id': studentId,
      'normalized_name': normalizedName,
      'assessment_completeness': assessmentCompleteness,
    };
  }

  // ========== HELPER METHODS ==========

  static int _mapGradeToId(String gradeLevel) {
    final gradeMap = {
      'Kinder': 0,
      'Grade 1': 1,
      'Grade 2': 2,
      'Grade 3': 3,
      'Grade 4': 4,
      'Grade 5': 5,
      'Grade 6': 6,
      'SPED': 7,
      'K': 0,
      '1': 1,
      '2': 2,
      '3': 3,
      '4': 4,
      '5': 5,
      '6': 6,
    };
    return gradeMap[gradeLevel] ?? 0;
  }

  static int? _calculateAge(String? birthDate) {
    if (birthDate == null) return null;
    try {
      final birth = DateTime.parse(birthDate);
      final now = DateTime.now();
      return now.year - birth.year;
    } catch (e) {
      return null;
    }
  }

  /// Check if student matches another student (for fuzzy matching)
  bool matchesStudent(SBFPStudent other, {double similarityThreshold = 0.85}) {
    if (studentId == other.studentId) return true;
    if (lrn != null && other.lrn != null && lrn == other.lrn) return true;

    final similarity = StudentIdentificationService.jaroWinklerSimilarity(
      name,
      other.name,
    );

    return similarity >= similarityThreshold;
  }
}
