import 'package:district_dev/Services/Data%20Model/food_datamodel.dart';
import 'package:district_dev/Services/Database/data_services.dart';

class DietaryAnalysisController {
  final FoodDataRepository _foodRepo;

  DietaryAnalysisController() : _foodRepo = FoodDataRepository();

  // ========== CORE ANALYSIS METHODS ==========

  /// 1. COMPLETE STUDENT ANALYSIS (Main Orchestration Method)
  Future<Map<String, dynamic>> runCompleteDietaryAnalysis({
    required String studentId,
    required Set<int> absentDays,
    int projectionDays = 60,
    bool includeFoodDetails = true,
  }) async {
    try {
      print('🔍 Starting Complete Dietary Analysis for Student: $studentId');

      // Step 1: Generate Dietary Plan
      final dietaryPlan = await DataService.generateDietaryPlan(studentId);

      // Step 2: Generate Health Projection
      final healthProjection = await DataService.getProjectedHealthStatus(
        studentId: studentId,
        daysAbsent: absentDays,
        projectionDays: projectionDays,
        studentUid: '',
      );

      // Step 3: Format Results for UI
      return _formatAnalysisResults(
        studentId: studentId,
        dietaryPlan: dietaryPlan,
        healthProjection: healthProjection,
        absentDays: absentDays,
        includeFoodDetails: includeFoodDetails,
      );
    } catch (e) {
      print('❌ Dietary Analysis Failed: $e');
      return _formatErrorResult(studentId, e);
    }
  }

  /// 2. QUICK DIETARY ASSESSMENT (Lightweight Version)
  Future<Map<String, dynamic>> getQuickDietaryAssessment(
    String studentId,
  ) async {
    try {
      final dietaryPlan = await DataService.generateDietaryPlan(studentId);

      return {
        'success': true,
        'type': 'quick_assessment',
        'studentId': studentId,
        'planName': dietaryPlan.planName,
        'description': dietaryPlan.description,
        'totalCalories': dietaryPlan.totalDailyCalories,
        'totalProtein': dietaryPlan.totalDailyProtein,
        'recommendedFoodCount': dietaryPlan.recommendedFoods.length,
        'foodTypes': dietaryPlan.foodTypeDistribution,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return _formatErrorResult(studentId, e);
    }
  }

  /// 3. PROJECTION-ONLY ANALYSIS
  Future<Map<String, dynamic>> getHealthProjection({
    required String studentId,
    required Set<int> absentDays,
    int projectionDays = 60,
  }) async {
    try {
      final projection = await DataService.getProjectedHealthStatus(
        studentId: studentId,
        daysAbsent: absentDays,
        projectionDays: projectionDays,
        studentUid: '',
      );

      return {
        'success': true,
        'type': 'projection_only',
        'studentId': studentId,
        'initialWeight': projection.initialWeight,
        'finalWeight': projection.projectedFinalWeight,
        'totalGain': projection.totalWeightGain,
        'absentDays': projection.absentDays,
        'totalDays': projection.totalFeedingDays,
        'attendanceRate':
            ((projectionDays - projection.absentDays) / projectionDays * 100)
                .round(),
        'dailyProjections': projection.dailyProjections,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return _formatErrorResult(studentId, e);
    }
  }

  // ========== FOOD DATABASE QUERIES ==========

  /// 4. GET ALL AVAILABLE FOOD TYPES
  Future<List<String>> getAvailableFoodTypes() async {
    return await _foodRepo.getAvailableFoodTypes();
  }

  /// 5. GET FOODS BY TYPE WITH UI-FRIENDLY FORMAT
  Future<List<Map<String, dynamic>>> getFoodsByType(String foodType) async {
    final foods = await _foodRepo.getFoodItemsByType(foodType);
    return foods.map((food) => _formatFoodForUI(food)).toList();
  }

  /// 6. SEARCH FOODS BY CRITERIA
  Future<List<Map<String, dynamic>>> searchFoods({
    String? name,
    double? minCalories,
    double? minProtein,
    String? dietaryFocus,
  }) async {
    var foods = await _foodRepo.getAllFoodItems();

    if (name != null) {
      foods = foods
          .where((food) => food.name.toLowerCase().contains(name.toLowerCase()))
          .toList();
    }
    if (minCalories != null) {
      foods =
          foods.where((food) => food.averageCalories >= minCalories).toList();
    }
    if (minProtein != null) {
      foods = foods.where((food) => food.minProtein >= minProtein).toList();
    }
    if (dietaryFocus != null) {
      foods = foods
          .where(
            (food) => food.dietaryFocus.toLowerCase().contains(
                  dietaryFocus.toLowerCase(),
                ),
          )
          .toList();
    }

    return foods.map((food) => _formatFoodForUI(food)).toList();
  }

  /// 7. GET FOODS FOR SPECIFIC NUTRITIONAL STATUS
  Future<List<Map<String, dynamic>>> getFoodsForStatus(
    String nutritionalStatus,
  ) async {
    final foods = await _foodRepo.getFoodItemsByStatus(nutritionalStatus);
    return foods.map((food) => _formatFoodForUI(food)).toList();
  }

  // ========== ANALYSIS TOOLS ==========

  /// 8. SIMULATE DIFFERENT SCENARIOS
  Future<Map<String, dynamic>> simulateAttendanceScenarios({
    required String studentId,
    required int projectionDays,
    List<int> absentDayOptions = const [0, 5, 10, 15],
  }) async {
    final scenarios = <String, Map<String, dynamic>>{};

    for (final absentDays in absentDayOptions) {
      final absentSet = Set<int>.from(
        List.generate(absentDays, (i) => (i + 1) * 7),
      ); // Spread absences

      final projection = await DataService.getProjectedHealthStatus(
        studentId: studentId,
        daysAbsent: absentSet,
        projectionDays: projectionDays,
        studentUid: '',
      );

      scenarios['${absentDays}_absences'] = {
        'absentDays': absentDays,
        'finalWeight': projection.projectedFinalWeight,
        'weightGain': projection.totalWeightGain,
        'attendanceRate':
            ((projectionDays - absentDays) / projectionDays * 100).round(),
      };
    }

    return {
      'success': true,
      'type': 'attendance_simulation',
      'studentId': studentId,
      'scenarios': scenarios,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 9. COMPARE MULTIPLE STUDENTS
  Future<Map<String, dynamic>> compareStudents({
    required List<String> studentIds,
    required int projectionDays,
    int absentDays = 7,
  }) async {
    final comparisons = <String, Map<String, dynamic>>{};

    for (final studentId in studentIds) {
      final absentSet = Set<int>.from(
        List.generate(absentDays, (i) => (i + 1) * 7),
      );

      final dietaryPlan = await DataService.generateDietaryPlan(studentId);
      final projection = await DataService.getProjectedHealthStatus(
        studentId: studentId,
        daysAbsent: absentSet,
        projectionDays: projectionDays,
        studentUid: '',
      );

      comparisons[studentId] = {
        'planName': dietaryPlan.planName,
        'dailyCalories': dietaryPlan.totalDailyCalories,
        'initialWeight': projection.initialWeight,
        'finalWeight': projection.projectedFinalWeight,
        'weightGain': projection.totalWeightGain,
        'foodTypes': dietaryPlan.foodTypeDistribution,
      };
    }

    return {
      'success': true,
      'type': 'student_comparison',
      'comparisons': comparisons,
      'projectionDays': projectionDays,
      'absentDays': absentDays,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ========== BATCH PROCESSING METHODS ==========

  /// 10. GET DIETARY PLANS FOR MULTIPLE STUDENTS
  Future<Map<String, DietaryPlanResult>> getBatchDietaryPlans(
    List<String> studentIds,
  ) async {
    return await DataService.getBatchDietaryPlans(studentIds);
  }

  /// 11. GET STUDENT ABSENCE DATA
  Future<Set<int>> getStudentAbsenceDays(
    String studentId,
    int totalDays,
  ) async {
    return await DataService.getStudentAbsenceDays(studentId, totalDays);
  }

  // ========== FORMATTING HELPERS ==========

  Map<String, dynamic> _formatAnalysisResults({
    required String studentId,
    required DietaryPlanResult dietaryPlan,
    required HealthProjectionResult healthProjection,
    required Set<int> absentDays,
    bool includeFoodDetails = true,
  }) {
    return {
      'success': true,
      'type': 'complete_analysis',
      'studentId': studentId,

      // Dietary Plan Section
      'dietaryPlan': {
        'planName': dietaryPlan.planName,
        'description': dietaryPlan.description,
        'totalDailyCalories': dietaryPlan.totalDailyCalories,
        'totalDailyProtein': dietaryPlan.totalDailyProtein,
        'foodTypeDistribution': dietaryPlan.foodTypeDistribution,
        'recommendedFoods': includeFoodDetails
            ? dietaryPlan.recommendedFoods.map(_formatFoodForUI).toList()
            : dietaryPlan.recommendedFoods.map((f) => f.name).toList(),
      },

      // Health Projection Section
      'healthProjection': {
        'initialWeight': healthProjection.initialWeight,
        'finalWeight': healthProjection.projectedFinalWeight,
        'totalWeightGain': healthProjection.totalWeightGain,
        'totalFeedingDays': healthProjection.totalFeedingDays,
        'absentDays': healthProjection.absentDays,
        'attendanceRate':
            ((healthProjection.totalFeedingDays - healthProjection.absentDays) /
                    healthProjection.totalFeedingDays *
                    100)
                .round(),
        'dailyProjections': healthProjection.dailyProjections,
        'keyMilestones': _extractKeyMilestones(
          healthProjection.dailyProjections,
        ),
      },

      // Analysis Metadata
      'analysisSummary': {
        'estimatedWeeklyGain': (healthProjection.totalWeightGain /
                (healthProjection.totalFeedingDays / 7))
            .toStringAsFixed(3),
        'calorieEfficiency': (healthProjection.totalWeightGain *
                7700 /
                (dietaryPlan.totalDailyCalories *
                    (healthProjection.totalFeedingDays -
                        healthProjection.absentDays)))
            .toStringAsFixed(2),
        'riskFactors': _assessRiskFactors(
          absentDays,
          healthProjection.totalWeightGain,
        ),
      },

      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _formatFoodForUI(FoodItem food) {
    return {
      'name': food.name,
      'type': food.foodType,
      'servingSize': food.servingSize,
      'calories': food.averageCalories,
      'calorieRange': '${food.minCalories}-${food.maxCalories}',
      'protein': food.minProtein,
      'vitaminA': food.minVitaminA,
      'dietaryFocus': food.dietaryFocus,
      'targetStatus': food.targetStatus,
      'icon': _getFoodIcon(food.foodType), // For UI display
    };
  }

  Map<String, dynamic> _formatErrorResult(String studentId, dynamic error) {
    return {
      'success': false,
      'studentId': studentId,
      'error': error.toString(),
      'errorType': error.runtimeType.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'suggestion': _getErrorSuggestion(error),
    };
  }

  // ========== UI HELPER METHODS ==========

  String _getFoodIcon(String foodType) {
    switch (foodType.toLowerCase()) {
      case 'bakery':
        return '🍞';
      case 'dairy':
        return '🥛';
      case 'grains':
        return '🌾';
      case 'protein':
        return '🥚';
      default:
        return '🍽️';
    }
  }

  Map<String, double> _extractKeyMilestones(Map<int, double> projections) {
    return {
      'week4': projections[28] ?? 0.0,
      'week8': projections[56] ?? 0.0,
      'week12': projections[84] ?? 0.0,
    };
  }

  List<String> _assessRiskFactors(Set<int> absentDays, double totalGain) {
    final risks = <String>[];

    if (absentDays.length > 10) {
      risks.add('High absenteeism may limit program effectiveness');
    }

    if (totalGain < 0.5) {
      risks.add('Low projected weight gain - consider intensive intervention');
    }

    if (absentDays.length >= 5 && absentDays.length <= 10) {
      risks.add('Moderate absenteeism - monitor attendance closely');
    }

    return risks;
  }

  String _getErrorSuggestion(dynamic error) {
    if (error.toString().contains('Student data not found')) {
      return 'Please check the student ID and ensure the student exists in the system.';
    } else if (error.toString().contains('nutritional_status')) {
      return 'Student nutritional data appears incomplete. Please update student health records.';
    } else if (error.toString().contains('database')) {
      return 'Database connection issue. Please try again or contact support.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}
