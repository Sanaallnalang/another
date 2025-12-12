// nutritional_utilities.dart
// Centralized nutritional classification utilities for SBFP with WHO standards

class NutritionalUtilities {
  /// Classify nutritional status based on BMI, age, and sex using WHO standards
  static String classifyBMI(double? bmi, int? ageInMonths, String? sex) {
    if (bmi == null || bmi <= 0 || bmi.isNaN) return 'Unknown';
    if (ageInMonths == null || sex == null) {
      return _fallbackBMIClassification(bmi);
    }

    // Convert sex to standard format
    final cleanSex = _normalizeSex(sex);
    if (cleanSex != 'Male' && cleanSex != 'Female') {
      return _fallbackBMIClassification(bmi);
    }

    // WHO standards for children 5-19 years (61-228 months)
    if (ageInMonths >= 61 && ageInMonths <= 228) {
      return _classifyBMIForSchoolAge(bmi, ageInMonths, cleanSex);
    }

    // WHO standards for children under 5 (0-60 months)
    if (ageInMonths <= 60) {
      return _classifyBMIForUnderFive(bmi, ageInMonths, cleanSex);
    }

    // Fallback for ages outside WHO ranges
    return _fallbackBMIClassification(bmi);
  }

  /// WHO BMI-for-age classification for school-aged children (5-19 years)
  static String _classifyBMIForSchoolAge(
    double bmi,
    int ageInMonths,
    String sex,
  ) {
    // Get Z-score for BMI-for-age
    final zScore = _calculateBMIZScore(bmi, ageInMonths, sex);

    if (zScore == null) return _fallbackBMIClassification(bmi);

    // WHO classification for school-aged children
    if (zScore < -3) return 'Severely Wasted';
    if (zScore < -2) return 'Wasted';
    if (zScore < 1) return 'Normal';
    if (zScore < 2) return 'Overweight';
    return 'Obese';
  }

  /// WHO BMI-for-age classification for children under 5
  static String _classifyBMIForUnderFive(
    double bmi,
    int ageInMonths,
    String sex,
  ) {
    // Get Z-score for BMI-for-age
    final zScore = _calculateBMIZScore(bmi, ageInMonths, sex);

    if (zScore == null) return _fallbackBMIClassification(bmi);

    // WHO classification for children under 5
    if (zScore < -3) return 'Severely Wasted';
    if (zScore < -2) return 'Wasted';
    if (zScore < 2) return 'Normal';
    if (zScore < 3) return 'Overweight';
    return 'Obese';
  }

  /// Calculate BMI Z-score using WHO growth standards (simplified approximation)
  static double? _calculateBMIZScore(double bmi, int ageInMonths, String sex) {
    try {
      // Simplified WHO Z-score calculation based on published standards
      // This is an approximation - in production, use actual WHO growth tables

      // Base median BMI values by age (simplified from WHO standards)
      final medianBMI = _getMedianBMIForAge(ageInMonths, sex);
      final standardDeviation = _getBMIStandardDeviation(ageInMonths, sex);

      if (medianBMI == null || standardDeviation == null) return null;

      // Calculate Z-score: (observed - median) / standard deviation
      return (bmi - medianBMI) / standardDeviation;
    } catch (e) {
      return null;
    }
  }

  /// Get median BMI for age based on WHO standards (simplified)
  static double? _getMedianBMIForAge(int ageInMonths, String sex) {
    // Simplified median BMI values from WHO growth standards
    // These are approximate values - real implementation should use WHO tables

    final ageYears = ageInMonths / 12.0;

    if (ageYears < 5) {
      // For children under 5
      if (ageYears < 2) return 16.0;
      if (ageYears < 3) return 15.5;
      if (ageYears < 4) return 15.4;
      return 15.5; // Age 4
    }

    // For school-aged children (5-19 years)
    if (sex == 'Male') {
      if (ageYears < 6) return 15.3;
      if (ageYears < 7) return 15.2;
      if (ageYears < 8) return 15.3;
      if (ageYears < 9) return 15.5;
      if (ageYears < 10) return 15.8;
      if (ageYears < 11) return 16.2;
      if (ageYears < 12) return 16.7;
      if (ageYears < 13) return 17.3;
      if (ageYears < 14) return 17.9;
      if (ageYears < 15) return 18.5;
      if (ageYears < 16) return 19.1;
      if (ageYears < 17) return 19.6;
      if (ageYears < 18) return 20.1;
      return 20.4; // Age 18-19
    } else {
      // Female
      if (ageYears < 6) return 15.1;
      if (ageYears < 7) return 15.0;
      if (ageYears < 8) return 15.1;
      if (ageYears < 9) return 15.4;
      if (ageYears < 10) return 15.8;
      if (ageYears < 11) return 16.3;
      if (ageYears < 12) return 16.9;
      if (ageYears < 13) return 17.5;
      if (ageYears < 14) return 18.1;
      if (ageYears < 15) return 18.6;
      if (ageYears < 16) return 19.0;
      if (ageYears < 17) return 19.3;
      if (ageYears < 18) return 19.5;
      return 19.6; // Age 18-19
    }
  }

  /// Get BMI standard deviation for age based on WHO standards (simplified)
  static double? _getBMIStandardDeviation(int ageInMonths, String sex) {
    // Simplified standard deviation values
    // Real implementation should use WHO growth table values

    final ageYears = ageInMonths / 12.0;

    if (ageYears < 5) {
      return 1.2; // Consistent SD for under-5
    }

    // School-aged children have increasing SD with age
    if (ageYears < 10) return 1.5;
    if (ageYears < 15) return 2.0;
    return 2.5; // Older adolescents
  }

  /// Fallback classification when WHO standards can't be applied
  static String _fallbackBMIClassification(double bmi) {
    // Conservative fallback for edge cases
    if (bmi < 14.0) return 'Severely Wasted';
    if (bmi < 16.0) return 'Wasted';
    if (bmi < 18.5) return 'Normal';
    if (bmi < 25.0) return 'Overweight';
    if (bmi < 30.0) return 'Obese';
    return 'Severely Obese';
  }

  /// Normalize nutritional status string to standard SBFP values
  static String normalizeStatus(String rawStatus) {
    if (rawStatus.isEmpty) return 'Unknown';

    final status = rawStatus.trim().toLowerCase();

    // SBFP standard nutritional status categories
    if (status.contains('severely') && status.contains('wasted')) {
      return 'Severely Wasted';
    }
    if (status.contains('wasted') && !status.contains('over')) return 'Wasted';
    if (status.contains('normal') || status.contains('adequate')) {
      return 'Normal';
    }
    if (status.contains('overweight')) return 'Overweight';
    if (status.contains('obese')) return 'Obese';
    if (status.contains('severely') && status.contains('underweight')) {
      return 'Severely Underweight';
    }
    if (status.contains('underweight')) return 'Underweight';
    if (status.contains('stunted')) {
      return status.contains('severely') ? 'Severely Stunted' : 'Stunted';
    }

    // Handle numeric codes
    if (status == '1' || status == '1.0') return 'Severely Wasted';
    if (status == '2' || status == '2.0') return 'Wasted';
    if (status == '3' || status == '3.0') return 'Normal';
    if (status == '4' || status == '4.0') return 'Overweight';
    if (status == '5' || status == '5.0') return 'Obese';

    return 'Unknown';
  }

  /// Normalize sex to standard values
  static String _normalizeSex(String sex) {
    final cleanSex = sex.trim().toLowerCase();

    if (cleanSex == 'm' ||
        cleanSex == 'male' ||
        cleanSex == 'm.' ||
        cleanSex == '1') {
      return 'Male';
    }
    if (cleanSex == 'f' ||
        cleanSex == 'female' ||
        cleanSex == 'f.' ||
        cleanSex == '2') {
      return 'Female';
    }

    return sex; // Return original if not recognizable
  }

  /// Check if nutritional status is valid for SBFP
  static bool isValidStatus(String status) {
    final validStatuses = [
      'Normal',
      'Wasted',
      'Severely Wasted',
      'Overweight',
      'Obese',
      'Unknown',
      'Severely Underweight',
      'Underweight',
      'Stunted',
      'Severely Stunted',
    ];
    return validStatuses.contains(status);
  }

  /// Determine if student needs feeding program based on nutritional status
  static bool needsFeedingProgram(String nutritionalStatus) {
    return nutritionalStatus == 'Wasted' ||
        nutritionalStatus == 'Severely Wasted' ||
        nutritionalStatus == 'Underweight' ||
        nutritionalStatus == 'Severely Underweight' ||
        nutritionalStatus == 'Stunted' ||
        nutritionalStatus == 'Severely Stunted';
  }

  /// Calculate BMI from weight and height
  static double? calculateBMI(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || heightCm <= 0) return null;

    final heightM = heightCm / 100;
    if (heightM <= 0) return null;

    return weightKg / (heightM * heightM);
  }

  /// Validate BMI range for school-aged children
  static bool isValidBMI(double bmi) {
    return bmi > 10 && bmi < 50; // Reasonable range for school children
  }

  /// Get WHO classification description for a status
  static String getClassificationDescription(String status) {
    switch (status) {
      case 'Severely Wasted':
        return 'BMI-for-age < -3 SD (Severe acute malnutrition)';
      case 'Wasted':
        return 'BMI-for-age < -2 SD (Moderate acute malnutrition)';
      case 'Normal':
        return 'BMI-for-age -2 SD to +1 SD (Healthy weight)';
      case 'Overweight':
        return 'BMI-for-age > +1 SD (Risk of overweight)';
      case 'Obese':
        return 'BMI-for-age > +2 SD (Obesity)';
      case 'Stunted':
        return 'Height-for-age < -2 SD (Chronic malnutrition)';
      case 'Severely Stunted':
        return 'Height-for-age < -3 SD (Severe chronic malnutrition)';
      default:
        return 'Classification not available';
    }
  }

  /// 🆕 NEW: Calculate nutritional status for an assessment
  static String calculateNutritionalStatus(
    Map<String, dynamic> assessmentData,
  ) {
    final bmi = assessmentData['bmi'];
    final ageInMonths = assessmentData['age_in_months'];
    final sex = assessmentData['sex'];

    if (bmi != null) {
      return classifyBMI(bmi, ageInMonths, sex);
    }

    return assessmentData['nutritional_status']?.toString() ?? 'Unknown';
  }

  // Location: nutri_stat_utilities.dart
  static bool validateMeasurements(
    Map<String, dynamic> student,
    String period,
  ) {
    final weight = student['weight_kg'];
    final height = student['height_cm'];
    final status = student['nutritional_status'];

    // cite: nutri_stat_utilities.dart - Relaxed validation
    // A row is valid if it has at least a name and weight OR height.
    // This ensures baseline learners are created even if status is pending.
    if (weight != null ||
        height != null ||
        (status != null && status != 'Unknown')) {
      return true;
    }

    // Reject only if the row is completely empty of health metrics
    return false;
  }

  /// 🆕 NEW: Validate assessment data completeness
  static Map<String, dynamic> validateAssessmentData(
    Map<String, dynamic> data,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    final weight = data['weight_kg'];
    final height = data['height_cm'];
    final bmi = data['bmi'];
    final status = data['nutritional_status']?.toString();

    // Validate weight
    if (weight != null && (weight < 10 || weight > 200)) {
      errors.add('Weight must be between 10-200 kg');
    }

    // Validate height
    if (height != null && (height < 50 || height > 250)) {
      errors.add('Height must be between 50-250 cm');
    }

    // Validate BMI
    if (bmi != null && (bmi < 5 || bmi > 50)) {
      errors.add('BMI must be between 5-50');
    }

    // Validate nutritional status
    if (status != null && status.isNotEmpty && !isValidStatus(status)) {
      warnings.add('Nutritional status "$status" is not a standard value');
    }

    // Check if BMI can be calculated
    if (bmi == null && weight != null && height != null) {
      final calculatedBMI = calculateBMI(weight, height);
      if (calculatedBMI != null && isValidBMI(calculatedBMI)) {
        warnings.add('BMI can be calculated from weight and height');
      }
    }

    return {'isValid': errors.isEmpty, 'errors': errors, 'warnings': warnings};
  }
}
