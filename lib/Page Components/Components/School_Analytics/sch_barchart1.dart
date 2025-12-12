// lib/Components/Analytics/period_distribution_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PeriodDistributionChart extends StatelessWidget {
  final Map<String, int> data;

  const PeriodDistributionChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('No data available'));

    final maxValue = data.values.reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.1,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entries[idx].key,
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
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: e.value.toDouble(),
                width: 16,
                color: _getPeriodColor(e.key),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getPeriodColor(String period) {
    switch (period.toLowerCase()) {
      case 'baseline':
        return Colors.blue;
      case 'endline':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
