// lib/Components/Analytics/school_population_bar_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SchoolPopulationBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> studentData;

  const SchoolPopulationBarChart({super.key, required this.studentData});

  @override
  Widget build(BuildContext context) {
    // Calculate grade distribution by gender
    final gradeGenderData = _calculateGradeGenderDistribution();

    if (gradeGenderData.isEmpty) {
      return const Center(child: Text('No student data available'));
    }

    final maxValue = gradeGenderData.values
        .expand((gradeData) => gradeData.values)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'School Population Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          final grades = gradeGenderData.keys.toList();
                          if (idx >= 0 && idx < grades.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _abbreviateGrade(grades[idx]),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: gradeGenderData.entries.map((entry) {
                    final grade = entry.key;
                    final genderData = entry.value;
                    final index = gradeGenderData.keys.toList().indexOf(grade);

                    return BarChartGroupData(
                      x: index,
                      groupVertically: false,
                      barsSpace: 4,
                      barRods: [
                        // Male bar
                        BarChartRodData(
                          toY: (genderData['Male'] ?? 0).toDouble(),
                          width: 12,
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        // Female bar
                        BarChartRodData(
                          toY: (genderData['Female'] ?? 0).toDouble(),
                          width: 12,
                          color: Colors.pink,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Male', Colors.blue),
                const SizedBox(width: 16),
                _buildLegendItem('Female', Colors.pink),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Map<String, Map<String, int>> _calculateGradeGenderDistribution() {
    final distribution = <String, Map<String, int>>{};

    for (final student in studentData) {
      final grade =
          student['grade_name']?.toString() ??
          student['actual_grade_name']?.toString() ??
          'Unknown';
      final gender = student['sex']?.toString().toLowerCase() ?? 'unknown';

      final normalizedGender = gender == 'male'
          ? 'Male'
          : gender == 'female'
          ? 'Female'
          : 'Unknown';

      if (!distribution.containsKey(grade)) {
        distribution[grade] = {'Male': 0, 'Female': 0, 'Unknown': 0};
      }

      distribution[grade]![normalizedGender] =
          (distribution[grade]![normalizedGender] ?? 0) + 1;
    }

    return distribution;
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
      'Unknown': 'Unkn',
    };
    return abbreviations[grade] ?? grade;
  }
}
