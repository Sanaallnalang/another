// bmi_barchart.dart - UPDATED WITH SPED SUPPORT
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class BMIBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> baselineStudents;
  final List<Map<String, dynamic>> endlineStudents;
  final String period; // 'baseline', 'endline', or 'combined'

  const BMIBarChart({
    super.key,
    required this.baselineStudents,
    required this.endlineStudents,
    this.period = 'combined',
  });

  @override
  Widget build(BuildContext context) {
    final bmiData = _calculateBMIDistribution();
    final grades = _getSortedGrades(bmiData.keys.toList());
    final categories = [
      'Severely Wasted',
      'Wasted',
      'Normal',
      'Overweight',
      'Obese',
    ];

    if (grades.isEmpty) {
      return const Center(
        child: Text(
          'No BMI data available',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return BarChart(
      BarChartData(
        backgroundColor: Colors.white,
        alignment: BarChartAlignment.spaceAround,
        maxY: _calculateMaxY(bmiData),
        minY: 0,
        groupsSpace: 20,
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
                if (value % 5 == 0 && value <= _calculateMaxY(bmiData)) {
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
        barGroups: _generateBarGroups(bmiData, grades, categories),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups(
    Map<String, Map<String, int>> bmiData,
    List<String> grades,
    List<String> categories,
  ) {
    return grades.asMap().entries.map((gradeEntry) {
      final gradeIndex = gradeEntry.key;
      final grade = gradeEntry.value;

      final bars = categories.asMap().entries.map((categoryEntry) {
        // ignore: unused_local_variable
        final categoryIndex = categoryEntry.key;
        final category = categoryEntry.value;
        final value = bmiData[grade]?[category]?.toDouble() ?? 0.0;

        return BarChartRodData(
          toY: value,
          fromY: 0,
          color: _getBMIColor(category),
          width: 14,
          borderRadius: BorderRadius.circular(2),
        );
      }).toList();

      return BarChartGroupData(x: gradeIndex, barsSpace: 4, barRods: bars);
    }).toList();
  }

  Map<String, Map<String, int>> _calculateBMIDistribution() {
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
      final status = student['nutritional_status']?.toString() ?? 'Unknown';

      if (!distribution.containsKey(grade)) {
        distribution[grade] = {
          'Severely Wasted': 0,
          'Wasted': 0,
          'Normal': 0,
          'Overweight': 0,
          'Obese': 0,
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
      'SPED',
      'Unknown',
    ];
    return gradeOrder.where(grades.contains).toList();
  }

  double _calculateMaxY(Map<String, Map<String, int>> bmiData) {
    int maxCount = 0;
    for (final gradeData in bmiData.values) {
      for (final count in gradeData.values) {
        if (count > maxCount) maxCount = count;
      }
    }
    return (maxCount * 1.2).ceilToDouble().clamp(10, double.infinity);
  }

  Color _getBMIColor(String category) {
    switch (category) {
      case 'Severely Wasted':
        return Colors.red[900]!;
      case 'Wasted':
        return Colors.red[400]!;
      case 'Normal':
        return Colors.green[400]!;
      case 'Overweight':
        return Colors.orange[400]!;
      case 'Obese':
        return Colors.red[800]!;
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
