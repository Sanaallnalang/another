// lib/Components/Charts/health_piechart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class HealthStatusPieChart extends StatelessWidget {
  final int severelyWasted;
  final int wasted;
  final int normal;
  final int overweight;
  final int obese;
  final int totalStudents;

  const HealthStatusPieChart({
    super.key,
    required this.severelyWasted,
    required this.wasted,
    required this.normal,
    required this.overweight,
    required this.obese,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    if (totalStudents == 0) {
      return _buildEmptyState('No health data available');
    }

    // Check if we have any non-zero statuses
    final hasHealthData =
        severelyWasted > 0 ||
        wasted > 0 ||
        normal > 0 ||
        overweight > 0 ||
        obese > 0;

    if (!hasHealthData) {
      return _buildEmptyState('Health status data not available');
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: _buildSections(),
              sectionsSpace: 1,
              centerSpaceRadius: 40,
              startDegreeOffset: -90,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildDetailedLegend(),
      ],
    );
  }

  List<PieChartSectionData> _buildSections() {
    final sections = <PieChartSectionData>[];
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.green,
      Colors.blue,
      Colors.deepPurple,
    ];

    final values = [severelyWasted, wasted, normal, overweight, obese];

    double total = totalStudents.toDouble();

    for (int i = 0; i < values.length; i++) {
      if (values[i] > 0) {
        final percentage = (values[i] / total * 100);
        sections.add(
          PieChartSectionData(
            value: values[i].toDouble(),
            color: colors[i],
            title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
            radius: _calculateRadius(values[i], total),
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    }

    return sections;
  }

  Widget _buildDetailedLegend() {
    final statuses = [
      {
        'label': 'Severely Wasted',
        'count': severelyWasted,
        'color': Colors.red,
      },
      {'label': 'Wasted', 'count': wasted, 'color': Colors.orange},
      {'label': 'Normal', 'count': normal, 'color': Colors.green},
      {'label': 'Overweight', 'count': overweight, 'color': Colors.blue},
      {'label': 'Obese', 'count': obese, 'color': Colors.deepPurple},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: statuses.map((status) {
        final count = status['count'] as int;
        final percentage = totalStudents > 0
            ? (count / totalStudents * 100)
            : 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (status['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: (status['color'] as Color).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: status['color'] as Color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: status['color'] as Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$count (${percentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  double _calculateRadius(int value, double total) {
    final percentage = value / total;
    if (percentage < 0.05) return 35;
    if (percentage < 0.1) return 40;
    if (percentage < 0.2) return 45;
    return 50;
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
