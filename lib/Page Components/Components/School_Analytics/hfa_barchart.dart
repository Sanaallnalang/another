// hfa_barchart.dart - FIXED TYPE CASTING ISSUES
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class HFABarChart extends StatelessWidget {
  final List<Map<String, dynamic>> baselineStudents;
  final List<Map<String, dynamic>> endlineStudents;
  final String period; // 'baseline', 'endline', or 'combined'

  const HFABarChart({
    super.key,
    required this.baselineStudents,
    required this.endlineStudents,
    this.period = 'combined',
  });

  @override
  Widget build(BuildContext context) {
    final hfaData = _calculateHFADistribution();
    final grades = _getSortedGrades(hfaData.keys.toList());
    final categories = ['Severely Stunted', 'Stunted', 'Normal', 'Tall'];

    if (grades.isEmpty) {
      return const Center(child: Text('No HFA data available'));
    }

    return BarChart(
      BarChartData(
        backgroundColor: Colors.white,
        alignment: BarChartAlignment.spaceAround,
        maxY: _calculateMaxY(hfaData),
        minY: 0,
        groupsSpace: 16,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final category = categories[rodIndex];
              final value = rod.toY.toInt();
              final grade = grades[groupIndex];
              return BarTooltipItem(
                '$grade\n$category: $value students',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < grades.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _abbreviateGrade(grades[index]),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 5 == 0 && value <= _calculateMaxY(hfaData)) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
              reservedSize: 28,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey[300], strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[400]!, width: 1),
        ),
        barGroups: _generateBarGroups(hfaData, grades, categories),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups(
    Map<String, Map<String, int>> hfaData,
    List<String> grades,
    List<String> categories,
  ) {
    return grades.asMap().entries.map((gradeEntry) {
      final gradeIndex = gradeEntry.key;
      final grade = gradeEntry.value;

      final bars = categories.asMap().entries.map((categoryEntry) {
        final category = categoryEntry.value;
        final value = hfaData[grade]?[category]?.toDouble() ?? 0.0;

        return BarChartRodData(
          toY: value,
          fromY: 0,
          color: _getHFAColor(category),
          width: 12,
          borderRadius: BorderRadius.circular(2),
        );
      }).toList();

      return BarChartGroupData(x: gradeIndex, barsSpace: 4, barRods: bars);
    }).toList();
  }

  Map<String, Map<String, int>> _calculateHFADistribution() {
    final distribution = <String, Map<String, int>>{};

    // Use data based on selected period
    List<Map<String, dynamic>> studentsToUse;
    switch (period.toLowerCase()) {
      case 'baseline':
        studentsToUse = baselineStudents;
        break;
      case 'endline':
        studentsToUse = endlineStudents;
        break;
      case 'combined':
      default:
        studentsToUse = [...baselineStudents, ...endlineStudents];
        break;
    }

    for (final student in studentsToUse) {
      final grade = student['grade_level']?.toString() ?? 'Unknown';
      final status = _calculateHFAStatus(student);

      if (!distribution.containsKey(grade)) {
        distribution[grade] = {
          'Severely Stunted': 0,
          'Stunted': 0,
          'Normal': 0,
          'Tall': 0,
        };
      }

      if (distribution[grade]!.containsKey(status)) {
        distribution[grade]![status] = distribution[grade]![status]! + 1;
      }
    }

    return distribution;
  }

  List<String> _getSortedGrades(List<String> grades) {
    final gradeOrder = [
      'Kinder',
      'Grade 1',
      'Grade 2',
      'Grade 3',
      'Grade 4',
      'Grade 5',
      'Grade 6',
      'SPED', // 🆕 SPED added
      'Unknown',
    ];
    return gradeOrder.where(grades.contains).toList();
  }

  String _calculateHFAStatus(Map<String, dynamic> student) {
    // Try multiple possible field names for height
    final height = _getHeightValue(student);
    final age = _getAgeValue(student);
    final gender = student['sex']?.toString().toLowerCase() ?? 'unknown';

    // Use height_for_age if already available from imported data
    final existingHFA = student['height_for_age']?.toString();
    if (existingHFA != null &&
        existingHFA.isNotEmpty &&
        existingHFA != 'Unknown') {
      return _normalizeHFAStatus(existingHFA);
    }

    if (height == null || age == null || age < 5 || age > 19) {
      return 'Normal'; // Fallback for missing/invalid data
    }

    // Calculate HFA using WHO z-score formulas
    final zScore = _calculateHFAZScore(height, age, gender);
    return _getHFAStatusFromZScore(zScore);
  }

  double? _getHeightValue(Map<String, dynamic> student) {
    final height = student['height_cm'] ?? student['height'];
    if (height == null) return null;
    if (height is String) return double.tryParse(height);
    return height.toDouble();
  }

  int? _getAgeValue(Map<String, dynamic> student) {
    final age = student['age'];
    if (age == null) return null;
    if (age is String) return int.tryParse(age);
    return age.toInt();
  }

  double _calculateHFAZScore(double heightCm, int ageYears, String gender) {
    final ageInMonths = ageYears * 12;

    if (gender == 'male' || gender == 'm' || gender.contains('male')) {
      return _calculateZScoreForBoys(heightCm, ageInMonths.toDouble());
    } else if (gender == 'female' ||
        gender == 'f' ||
        gender.contains('female')) {
      return _calculateZScoreForGirls(heightCm, ageInMonths.toDouble());
    } else {
      final boyZ = _calculateZScoreForBoys(heightCm, ageInMonths.toDouble());
      final girlZ = _calculateZScoreForGirls(heightCm, ageInMonths.toDouble());
      return (boyZ + girlZ) / 2;
    }
  }

  String _getHFAStatusFromZScore(double zScore) {
    if (zScore < -3.0) return 'Severely Stunted';
    if (zScore < -2.0) return 'Stunted';
    if (zScore <= 2.0) return 'Normal';
    return 'Tall';
  }

  // FIXED: Proper type handling to prevent 'int' to 'double' cast errors
  double _calculateZScoreForBoys(double heightCm, double ageMonths) {
    final boyMedians = <double, double>{
      60.0: 110.0,
      72.0: 116.0,
      84.0: 121.7,
      96.0: 127.0,
      108.0: 132.2,
      120.0: 137.5,
      132.0: 143.1,
      144.0: 149.1,
      156.0: 156.0,
      168.0: 163.0,
      180.0: 168.0,
      192.0: 171.0,
      204.0: 172.5,
      216.0: 173.0,
      228.0: 173.0,
    };
    final boyStdDevs = <double, double>{
      60.0: 4.5,
      72.0: 4.7,
      84.0: 4.9,
      96.0: 5.1,
      108.0: 5.3,
      120.0: 5.5,
      132.0: 5.8,
      144.0: 6.1,
      156.0: 6.5,
      168.0: 6.8,
      180.0: 7.0,
      192.0: 7.1,
      204.0: 7.1,
      216.0: 7.1,
      228.0: 7.1,
    };

    double closestAge = boyMedians.keys.first;
    for (final age in boyMedians.keys) {
      if ((age - ageMonths).abs() < (closestAge - ageMonths).abs()) {
        closestAge = age;
      }
    }

    final medianHeight = boyMedians[closestAge] ?? 150.0;
    final stdDev = boyStdDevs[closestAge] ?? 6.0;
    return (heightCm - medianHeight) / stdDev;
  }

  // FIXED: Proper type handling for girls
  double _calculateZScoreForGirls(double heightCm, double ageMonths) {
    final girlMedians = <double, double>{
      60.0: 109.0,
      72.0: 115.0,
      84.0: 120.6,
      96.0: 126.3,
      108.0: 132.2,
      120.0: 138.3,
      132.0: 144.6,
      144.0: 150.9,
      156.0: 156.7,
      168.0: 160.5,
      180.0: 162.0,
      192.0: 162.5,
      204.0: 162.7,
      216.0: 163.0,
      228.0: 163.0,
    };
    final girlStdDevs = <double, double>{
      60.0: 4.4,
      72.0: 4.6,
      84.0: 4.8,
      96.0: 5.0,
      108.0: 5.3,
      120.0: 5.6,
      132.0: 6.0,
      144.0: 6.4,
      156.0: 6.6,
      168.0: 6.7,
      180.0: 6.7,
      192.0: 6.6,
      204.0: 6.6,
      216.0: 6.6,
      228.0: 6.6,
    };

    double closestAge = girlMedians.keys.first;
    for (final age in girlMedians.keys) {
      if ((age - ageMonths).abs() < (closestAge - ageMonths).abs()) {
        closestAge = age;
      }
    }

    final medianHeight = girlMedians[closestAge] ?? 150.0;
    final stdDev = girlStdDevs[closestAge] ?? 6.0;
    return (heightCm - medianHeight) / stdDev;
  }

  String _normalizeHFAStatus(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('severely') && lowerStatus.contains('stunt')) {
      return 'Severely Stunted';
    }
    if (lowerStatus.contains('stunt')) return 'Stunted';
    if (lowerStatus.contains('normal') || lowerStatus.contains('adequate')) {
      return 'Normal';
    }
    if (lowerStatus.contains('tall') || lowerStatus.contains('over')) {
      return 'Tall';
    }
    return 'Normal';
  }

  double _calculateMaxY(Map<String, Map<String, int>> hfaData) {
    int maxCount = 0;
    for (final gradeData in hfaData.values) {
      for (final count in gradeData.values) {
        if (count > maxCount) maxCount = count;
      }
    }
    return (maxCount * 1.2).ceilToDouble().clamp(10, double.infinity);
  }

  Color _getHFAColor(String category) {
    switch (category) {
      case 'Severely Stunted':
        return Colors.red[900]!;
      case 'Stunted':
        return Colors.red[400]!;
      case 'Normal':
        return Colors.green[400]!;
      case 'Tall':
        return Colors.blue[400]!;
      default:
        return Colors.grey;
    }
  }

  String _abbreviateGrade(String grade) {
    final abbreviations = {
      'Kinder': 'K',
      'Grade 1': 'G1',
      'Grade 2': 'G2',
      'Grade 3': 'G3',
      'Grade 4': 'G4',
      'Grade 5': 'G5',
      'Grade 6': 'G6',
      'SPED': 'SPED',
      'Unknown': 'Unk',
    };
    return abbreviations[grade] ?? grade;
  }
}
