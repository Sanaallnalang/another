// lib/Components/Analytics/grade_distribution_pie_chart.dart - COMPLETE
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GradeDistributionPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> baselineStudents;
  final List<Map<String, dynamic>> endlineStudents;
  final String period; // 'baseline', 'endline', or 'combined'

  const GradeDistributionPieChart({
    super.key,
    required this.baselineStudents,
    required this.endlineStudents,
    this.period = 'combined',
  });

  @override
  Widget build(BuildContext context) {
    final gradeDistribution = _calculateGradeDistribution();
    final totalStudents = baselineStudents.length + endlineStudents.length;

    if (totalStudents == 0) {
      return const Center(child: Text('No student data available'));
    }

    final sections = gradeDistribution.entries.map((entry) {
      final percentage = (entry.value / totalStudents * 100);
      return PieChartSectionData(
        color: _getGradeColor(entry.key),
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grade Distribution - ${period.capitalize()}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Baseline: ${baselineStudents.length} students, Endline: ${endlineStudents.length} students',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 30,
                        sectionsSpace: 4,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildLegend(gradeDistribution, totalStudents),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Map<String, int> distribution, int totalStudents) {
    final entries = distribution.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        final percentage = (entry.value / totalStudents * 100).toStringAsFixed(
          1,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                color: _getGradeColor(entry.key),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_abbreviateGrade(entry.key)}: $percentage%',
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, int> _calculateGradeDistribution() {
    final distribution = <String, int>{};

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
      distribution[grade] = (distribution[grade] ?? 0) + 1;
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

  Color _getGradeColor(String grade) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.brown,
      Colors.blueGrey,
    ];
    final grades = [
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
    final index = grades.indexOf(grade);
    return index != -1 ? colors[index] : Colors.grey;
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
