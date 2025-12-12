// lib/Services/who_standards_service.dart
import 'dart:math';

class WHOStandardsService {
  // WHO Height-for-Age standards (5-19 years) - Median and Z-scores
  // Source: WHO Child Growth Standards (2007) and WHO Reference 2007
  static final Map<String, Map<int, Map<String, double>>> _hfaStandards = {
    'male': {
      // Age in years: {median, -3sd, -2sd, -1sd, +1sd, +2sd, +3sd}
      5: {
        'median': 110.0,
        '-3sd': 99.1,
        '-2sd': 102.9,
        '-1sd': 106.7,
        '+1sd': 114.5,
        '+2sd': 118.4,
        '+3sd': 122.3,
      },
      6: {
        'median': 116.0,
        '-3sd': 104.5,
        '-2sd': 108.5,
        '-1sd': 112.5,
        '+1sd': 120.6,
        '+2sd': 124.7,
        '+3sd': 128.8,
      },
      7: {
        'median': 121.7,
        '-3sd': 109.7,
        '-2sd': 113.8,
        '-1sd': 117.9,
        '+1sd': 126.1,
        '+2sd': 130.2,
        '+3sd': 134.4,
      },
      8: {
        'median': 127.3,
        '-3sd': 114.8,
        '-2sd': 119.0,
        '-1sd': 123.2,
        '+1sd': 131.6,
        '+2sd': 135.9,
        '+3sd': 140.1,
      },
      9: {
        'median': 132.6,
        '-3sd': 119.7,
        '-2sd': 124.0,
        '-1sd': 128.3,
        '+1sd': 136.9,
        '+2sd': 141.3,
        '+3sd': 145.7,
      },
      10: {
        'median': 137.8,
        '-3sd': 124.5,
        '-2sd': 128.9,
        '-1sd': 133.3,
        '+1sd': 142.1,
        '+2sd': 146.6,
        '+3sd': 151.1,
      },
      11: {
        'median': 143.1,
        '-3sd': 129.4,
        '-2sd': 133.9,
        '-1sd': 138.4,
        '+1sd': 147.4,
        '+2sd': 152.0,
        '+3sd': 156.6,
      },
      12: {
        'median': 149.1,
        '-3sd': 134.8,
        '-2sd': 139.5,
        '-1sd': 144.1,
        '+1sd': 153.4,
        '+2sd': 158.1,
        '+3sd': 162.9,
      },
      13: {
        'median': 156.0,
        '-3sd': 140.9,
        '-2sd': 145.7,
        '-1sd': 150.5,
        '+1sd': 160.0,
        '+2sd': 164.9,
        '+3sd': 169.9,
      },
      14: {
        'median': 163.2,
        '-3sd': 147.4,
        '-2sd': 152.3,
        '-1sd': 157.2,
        '+1sd': 167.1,
        '+2sd': 172.1,
        '+3sd': 177.2,
      },
      15: {
        'median': 169.0,
        '-3sd': 152.8,
        '-2sd': 157.8,
        '-1sd': 162.8,
        '+1sd': 172.9,
        '+2sd': 178.0,
        '+3sd': 183.1,
      },
      16: {
        'median': 172.9,
        '-3sd': 156.4,
        '-2sd': 161.4,
        '-1sd': 166.5,
        '+1sd': 176.7,
        '+2sd': 181.9,
        '+3sd': 187.1,
      },
      17: {
        'median': 175.2,
        '-3sd': 158.4,
        '-2sd': 163.5,
        '-1sd': 168.5,
        '+1sd': 178.9,
        '+2sd': 184.1,
        '+3sd': 189.3,
      },
      18: {
        'median': 176.1,
        '-3sd': 159.3,
        '-2sd': 164.3,
        '-1sd': 169.3,
        '+1sd': 179.7,
        '+2sd': 184.9,
        '+3sd': 190.2,
      },
      19: {
        'median': 176.5,
        '-3sd': 159.6,
        '-2sd': 164.7,
        '-1sd': 169.7,
        '+1sd': 180.2,
        '+2sd': 185.4,
        '+3sd': 190.7,
      },
    },
    'female': {
      5: {
        'median': 109.4,
        '-3sd': 98.5,
        '-2sd': 102.3,
        '-1sd': 106.1,
        '+1sd': 113.9,
        '+2sd': 117.7,
        '+3sd': 121.6,
      },
      6: {
        'median': 115.1,
        '-3sd': 103.7,
        '-2sd': 107.6,
        '-1sd': 111.5,
        '+1sd': 119.5,
        '+2sd': 123.5,
        '+3sd': 127.5,
      },
      7: {
        'median': 120.8,
        '-3sd': 108.8,
        '-2sd': 112.8,
        '-1sd': 116.8,
        '+1sd': 124.9,
        '+2sd': 129.0,
        '+3sd': 133.1,
      },
      8: {
        'median': 126.6,
        '-3sd': 114.0,
        '-2sd': 118.1,
        '-1sd': 122.2,
        '+1sd': 130.5,
        '+2sd': 134.7,
        '+3sd': 138.9,
      },
      9: {
        'median': 132.5,
        '-3sd': 119.3,
        '-2sd': 123.5,
        '-1sd': 127.7,
        '+1sd': 136.1,
        '+2sd': 140.4,
        '+3sd': 144.7,
      },
      10: {
        'median': 138.3,
        '-3sd': 124.5,
        '-2sd': 128.8,
        '-1sd': 133.1,
        '+1sd': 141.8,
        '+2sd': 146.2,
        '+3sd': 150.6,
      },
      11: {
        'median': 144.0,
        '-3sd': 129.7,
        '-2sd': 134.1,
        '-1sd': 138.5,
        '+1sd': 147.4,
        '+2sd': 151.9,
        '+3sd': 156.4,
      },
      12: {
        'median': 150.1,
        '-3sd': 135.2,
        '-2sd': 139.7,
        '-1sd': 144.2,
        '+1sd': 153.3,
        '+2sd': 157.9,
        '+3sd': 162.6,
      },
      13: {
        'median': 156.3,
        '-3sd': 140.8,
        '-2sd': 145.4,
        '-1sd': 150.0,
        '+1sd': 159.4,
        '+2sd': 164.1,
        '+3sd': 168.9,
      },
      14: {
        'median': 160.7,
        '-3sd': 144.9,
        '-2sd': 149.6,
        '-1sd': 154.3,
        '+1sd': 164.0,
        '+2sd': 168.9,
        '+3sd': 173.8,
      },
      15: {
        'median': 162.5,
        '-3sd': 146.5,
        '-2sd': 151.2,
        '-1sd': 156.0,
        '+1sd': 165.8,
        '+2sd': 170.8,
        '+3sd': 175.7,
      },
      16: {
        'median': 163.2,
        '-3sd': 147.1,
        '-2sd': 151.9,
        '-1sd': 156.6,
        '+1sd': 166.6,
        '+2sd': 171.6,
        '+3sd': 176.6,
      },
      17: {
        'median': 163.3,
        '-3sd': 147.2,
        '-2sd': 152.0,
        '-1sd': 156.8,
        '+1sd': 166.8,
        '+2sd': 171.8,
        '+3sd': 176.9,
      },
      18: {
        'median': 163.4,
        '-3sd': 147.2,
        '-2sd': 152.0,
        '-1sd': 156.8,
        '+1sd': 166.9,
        '+2sd': 171.9,
        '+3sd': 177.0,
      },
      19: {
        'median': 163.4,
        '-3sd': 147.3,
        '-2sd': 152.1,
        '-1sd': 156.9,
        '+1sd': 166.9,
        '+2sd': 172.0,
        '+3sd': 177.1,
      },
    },
  };

  // WHO BMI-for-Age standards (5-19 years)
  static final Map<String, Map<int, Map<String, double>>> _bmiStandards = {
    'male': {
      // Age in years: {median, -3sd, -2sd, -1sd, +1sd, +2sd, +3sd}
      5: {
        'median': 15.3,
        '-3sd': 13.4,
        '-2sd': 14.0,
        '-1sd': 14.6,
        '+1sd': 16.3,
        '+2sd': 17.2,
        '+3sd': 18.3,
      },
      6: {
        'median': 15.3,
        '-3sd': 13.5,
        '-2sd': 14.1,
        '-1sd': 14.7,
        '+1sd': 16.4,
        '+2sd': 17.4,
        '+3sd': 18.6,
      },
      7: {
        'median': 15.4,
        '-3sd': 13.6,
        '-2sd': 14.2,
        '-1sd': 14.8,
        '+1sd': 16.6,
        '+2sd': 17.6,
        '+3sd': 18.9,
      },
      8: {
        'median': 15.5,
        '-3sd': 13.7,
        '-2sd': 14.3,
        '-1sd': 14.9,
        '+1sd': 16.8,
        '+2sd': 17.9,
        '+3sd': 19.2,
      },
      9: {
        'median': 15.8,
        '-3sd': 13.9,
        '-2sd': 14.5,
        '-1sd': 15.1,
        '+1sd': 17.1,
        '+2sd': 18.3,
        '+3sd': 19.7,
      },
      10: {
        'median': 16.0,
        '-3sd': 14.1,
        '-2sd': 14.7,
        '-1sd': 15.3,
        '+1sd': 17.5,
        '+2sd': 18.8,
        '+3sd': 20.3,
      },
      11: {
        'median': 16.3,
        '-3sd': 14.4,
        '-2sd': 15.0,
        '-1sd': 15.7,
        '+1sd': 18.0,
        '+2sd': 19.4,
        '+3sd': 21.0,
      },
      12: {
        'median': 16.7,
        '-3sd': 14.7,
        '-2sd': 15.4,
        '-1sd': 16.1,
        '+1sd': 18.6,
        '+2sd': 20.1,
        '+3sd': 21.8,
      },
      13: {
        'median': 17.2,
        '-3sd': 15.2,
        '-2sd': 15.9,
        '-1sd': 16.6,
        '+1sd': 19.3,
        '+2sd': 20.9,
        '+3sd': 22.8,
      },
      14: {
        'median': 17.7,
        '-3sd': 15.6,
        '-2sd': 16.4,
        '-1sd': 17.2,
        '+1sd': 20.1,
        '+2sd': 21.9,
        '+3sd': 23.9,
      },
      15: {
        'median': 18.3,
        '-3sd': 16.2,
        '-2sd': 17.0,
        '-1sd': 17.8,
        '+1sd': 20.9,
        '+2sd': 22.9,
        '+3sd': 25.1,
      },
      16: {
        'median': 18.9,
        '-3sd': 16.7,
        '-2sd': 17.6,
        '-1sd': 18.5,
        '+1sd': 21.8,
        '+2sd': 24.0,
        '+3sd': 26.4,
      },
      17: {
        'median': 19.4,
        '-3sd': 17.2,
        '-2sd': 18.2,
        '-1sd': 19.1,
        '+1sd': 22.6,
        '+2sd': 25.0,
        '+3sd': 27.7,
      },
      18: {
        'median': 19.9,
        '-3sd': 17.7,
        '-2sd': 18.7,
        '-1sd': 19.7,
        '+1sd': 23.4,
        '+2sd': 26.0,
        '+3sd': 28.9,
      },
      19: {
        'median': 20.3,
        '-3sd': 18.1,
        '-2sd': 19.1,
        '-1sd': 20.2,
        '+1sd': 24.1,
        '+2sd': 26.8,
        '+3sd': 29.9,
      },
    },
    'female': {
      5: {
        'median': 15.2,
        '-3sd': 13.3,
        '-2sd': 13.9,
        '-1sd': 14.5,
        '+1sd': 16.2,
        '+2sd': 17.2,
        '+3sd': 18.4,
      },
      6: {
        'median': 15.2,
        '-3sd': 13.4,
        '-2sd': 14.0,
        '-1sd': 14.6,
        '+1sd': 16.4,
        '+2sd': 17.4,
        '+3sd': 18.7,
      },
      7: {
        'median': 15.4,
        '-3sd': 13.6,
        '-2sd': 14.2,
        '-1sd': 14.8,
        '+1sd': 16.7,
        '+2sd': 17.8,
        '+3sd': 19.2,
      },
      8: {
        'median': 15.7,
        '-3sd': 13.8,
        '-2sd': 14.5,
        '-1sd': 15.1,
        '+1sd': 17.2,
        '+2sd': 18.4,
        '+3sd': 19.9,
      },
      9: {
        'median': 16.1,
        '-3sd': 14.2,
        '-2sd': 14.9,
        '-1sd': 15.6,
        '+1sd': 17.9,
        '+2sd': 19.2,
        '+3sd': 20.8,
      },
      10: {
        'median': 16.6,
        '-3sd': 14.6,
        '-2sd': 15.3,
        '-1sd': 16.1,
        '+1sd': 18.6,
        '+2sd': 20.1,
        '+3sd': 21.9,
      },
      11: {
        'median': 17.2,
        '-3sd': 15.1,
        '-2sd': 15.9,
        '-1sd': 16.7,
        '+1sd': 19.5,
        '+2sd': 21.1,
        '+3sd': 23.1,
      },
      12: {
        'median': 17.8,
        '-3sd': 15.7,
        '-2sd': 16.5,
        '-1sd': 17.4,
        '+1sd': 20.4,
        '+2sd': 22.2,
        '+3sd': 24.4,
      },
      13: {
        'median': 18.4,
        '-3sd': 16.2,
        '-2sd': 17.2,
        '-1sd': 18.1,
        '+1sd': 21.3,
        '+2sd': 23.4,
        '+3sd': 25.8,
      },
      14: {
        'median': 19.0,
        '-3sd': 16.8,
        '-2sd': 17.8,
        '-1sd': 18.8,
        '+1sd': 22.2,
        '+2sd': 24.5,
        '+3sd': 27.1,
      },
      15: {
        'median': 19.4,
        '-3sd': 17.2,
        '-2sd': 18.3,
        '-1sd': 19.4,
        '+1sd': 23.0,
        '+2sd': 25.5,
        '+3sd': 28.3,
      },
      16: {
        'median': 19.7,
        '-3sd': 17.5,
        '-2sd': 18.6,
        '-1sd': 19.8,
        '+1sd': 23.6,
        '+2sd': 26.3,
        '+3sd': 29.3,
      },
      17: {
        'median': 19.9,
        '-3sd': 17.7,
        '-2sd': 18.9,
        '-1sd': 20.1,
        '+1sd': 24.0,
        '+2sd': 26.8,
        '+3sd': 29.9,
      },
      18: {
        'median': 20.0,
        '-3sd': 17.8,
        '-2sd': 19.0,
        '-1sd': 20.2,
        '+1sd': 24.2,
        '+2sd': 27.1,
        '+3sd': 30.3,
      },
      19: {
        'median': 20.1,
        '-3sd': 17.9,
        '-2sd': 19.1,
        '-1sd': 20.3,
        '+1sd': 24.4,
        '+2sd': 27.3,
        '+3sd': 30.6,
      },
    },
  };

  /// Calculate Height-for-Age (HFA) Z-score and status
  static Map<String, dynamic> calculateHFA(
    double heightCm,
    int ageYears,
    String sex,
  ) {
    if (heightCm <= 0 || ageYears < 5 || ageYears > 19) {
      return {'status': 'Unknown', 'zscore': 0.0, 'category': 'Unknown'};
    }

    String sexKey = _normalizeSex(sex);

    if (!_hfaStandards.containsKey(sexKey) ||
        !_hfaStandards[sexKey]!.containsKey(ageYears)) {
      return {'status': 'Unknown', 'zscore': 0.0, 'category': 'Unknown'};
    }

    final standards = _hfaStandards[sexKey]![ageYears]!;
    final median = standards['median']!;
    final sd = (standards['+1sd']! - median) / 1; // Approximate SD

    // Calculate Z-score
    double zscore = (heightCm - median) / sd;

    // Determine status
    String status;
    String category;

    if (zscore < -3) {
      status = 'Severely Stunted';
      category = 'Severe';
    } else if (zscore < -2) {
      status = 'Stunted';
      category = 'Moderate';
    } else if (zscore <= 2) {
      status = 'Normal';
      category = 'Normal';
    } else if (zscore <= 3) {
      status = 'Tall';
      category = 'Tall';
    } else {
      status = 'Very Tall';
      category = 'Very Tall';
    }

    return {
      'status': status,
      'zscore': zscore,
      'category': category,
      'height_cm': heightCm,
      'age_years': ageYears,
      'median_height': median,
      'sd': sd,
    };
  }

  /// Calculate BMI-for-Age Z-score and status
  static Map<String, dynamic> calculateBMIForAge(
    double bmi,
    int ageYears,
    String sex,
  ) {
    if (bmi <= 0 || ageYears < 5 || ageYears > 19) {
      return {'status': 'Unknown', 'zscore': 0.0, 'category': 'Unknown'};
    }

    String sexKey = _normalizeSex(sex);

    if (!_bmiStandards.containsKey(sexKey) ||
        !_bmiStandards[sexKey]!.containsKey(ageYears)) {
      return {'status': 'Unknown', 'zscore': 0.0, 'category': 'Unknown'};
    }

    final standards = _bmiStandards[sexKey]![ageYears]!;
    final median = standards['median']!;
    final sd = (standards['+1sd']! - median) / 1; // Approximate SD

    // Calculate Z-score
    double zscore = (bmi - median) / sd;

    // Determine status based on WHO standards
    String status;
    String category;

    if (zscore < -3) {
      status = 'Severely Wasted';
      category = 'Severe Acute Malnutrition';
    } else if (zscore < -2) {
      status = 'Wasted';
      category = 'Moderate Acute Malnutrition';
    } else if (zscore <= 1) {
      status = 'Normal';
      category = 'Normal';
    } else if (zscore <= 2) {
      status = 'Overweight';
      category = 'Overweight';
    } else {
      status = 'Obese';
      category = 'Obese';
    }

    return {
      'status': status,
      'zscore': zscore,
      'category': category,
      'bmi': bmi,
      'age_years': ageYears,
      'median_bmi': median,
      'sd': sd,
    };
  }

  /// Calculate Weight-for-Height Z-score (for children under 5)
  static Map<String, dynamic> calculateWFH(
    double weightKg,
    double heightCm,
    String sex,
  ) {
    if (weightKg <= 0 || heightCm <= 0) {
      return {'status': 'Unknown', 'zscore': 0.0, 'category': 'Unknown'};
    }

    // Simplified WFH calculation - for children under 5
    // In practice, you'd need WHO WFH tables

    double wfh = (weightKg / heightCm) * 100; // Weight-for-height index

    // Simplified categorization
    String status;
    String category;

    if (wfh < 70) {
      status = 'Severely Wasted';
      category = 'Severe Acute Malnutrition';
    } else if (wfh < 80) {
      status = 'Wasted';
      category = 'Moderate Acute Malnutrition';
    } else if (wfh <= 120) {
      status = 'Normal';
      category = 'Normal';
    } else if (wfh <= 130) {
      status = 'Overweight';
      category = 'Overweight';
    } else {
      status = 'Obese';
      category = 'Obese';
    }

    return {
      'status': status,
      'zscore': 0.0, // Would need proper tables
      'category': category,
      'wfh_index': wfh,
      'weight_kg': weightKg,
      'height_cm': heightCm,
    };
  }

  /// Calculate Nutritional Status (comprehensive)
  static Map<String, dynamic> calculateNutritionalStatus(
    double weightKg,
    double heightCm,
    double? bmi,
    int ageYears,
    String sex,
  ) {
    // Calculate BMI if not provided
    double calculatedBmi = bmi ?? (weightKg / pow(heightCm / 100, 2));

    // Get HFA status
    final hfa = calculateHFA(heightCm, ageYears, sex);

    // Get BMI-for-age status
    final bfa = calculateBMIForAge(calculatedBmi, ageYears, sex);

    // Determine overall nutritional status
    String overallStatus = 'Normal';

    // Priority: Severe conditions first
    if (hfa['status'] == 'Severely Stunted' ||
        bfa['status'] == 'Severely Wasted') {
      overallStatus = 'Severely Malnourished';
    } else if (hfa['status'] == 'Stunted' || bfa['status'] == 'Wasted') {
      overallStatus = 'Moderately Malnourished';
    } else if (bfa['status'] == 'Overweight') {
      overallStatus = 'Overweight';
    } else if (bfa['status'] == 'Obese') {
      overallStatus = 'Obese';
    } else if (hfa['status'] == 'Tall' || hfa['status'] == 'Very Tall') {
      overallStatus = 'Tall';
    }

    return {
      'overall_status': overallStatus,
      'hfa_status': hfa['status'],
      'hfa_zscore': hfa['zscore'],
      'bmi_status': bfa['status'],
      'bmi_zscore': bfa['zscore'],
      'bmi': calculatedBmi,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'age_years': ageYears,
    };
  }

  /// Helper method to normalize sex input
  static String _normalizeSex(String sex) {
    final sexLower = sex.toLowerCase();
    if (sexLower.contains('male') || sexLower == 'm') {
      return 'male';
    } else if (sexLower.contains('female') || sexLower == 'f') {
      return 'female';
    }
    return 'male'; // Default to male if unknown
  }

  /// Get all available ages for a specific sex
  static List<int> getAvailableAges(String sex) {
    String sexKey = _normalizeSex(sex);
    return _hfaStandards[sexKey]?.keys.toList() ?? [];
  }

  /// Get median height for specific age and sex
  static double? getMedianHeight(int ageYears, String sex) {
    String sexKey = _normalizeSex(sex);
    return _hfaStandards[sexKey]?[ageYears]?['median'];
  }

  /// Get median BMI for specific age and sex
  static double? getMedianBMI(int ageYears, String sex) {
    String sexKey = _normalizeSex(sex);
    return _bmiStandards[sexKey]?[ageYears]?['median'];
  }
}
