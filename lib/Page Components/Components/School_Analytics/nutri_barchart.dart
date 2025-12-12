// nutri_barchart.dart - UPDATED WITH PROPER SPACING
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AverageStudentStatusChart extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  final bool isLoading;

  const AverageStudentStatusChart({
    super.key,
    required this.chartData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (chartData.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 380,
      child: Column(
        children: [
          Expanded(child: _buildSideBySideBarChart()),
          SizedBox(height: 16),
          _buildChartLegend(),
        ],
      ),
    );
  }

  Widget _buildSideBySideBarChart() {
    // Group data by year and period
    final Map<String, Map<String, dynamic>> groupedData = {};

    for (final data in chartData) {
      final year = data['academic_year']?.toString() ?? '';
      final period = data['period']?.toString() ?? '';
      final key = '$year:$period';

      groupedData[key] = {
        'year': year,
        'period': period,
        'avg_bmi': (data['avg_bmi'] as num?)?.toDouble() ?? 0,
        'avg_height': (data['avg_height'] as num?)?.toDouble() ?? 0,
        'avg_weight': (data['avg_weight'] as num?)?.toDouble() ?? 0,
        'avg_hfa': (data['hfa_at_risk'] as num?)?.toDouble() ?? 0,
        'total_at_risk': (data['total_at_risk'] as num?)?.toDouble() ?? 0,
      };
    }

    // Sort keys chronologically (oldest first)
    final sortedKeys = groupedData.keys.toList()
      ..sort((a, b) {
        final aParts = a.split(':');
        final bParts = b.split(':');
        final aYear = aParts[0];
        final bYear = bParts[0];

        try {
          final aStart = int.tryParse(aYear.split('-').first) ?? 0;
          final bStart = int.tryParse(bYear.split('-').first) ?? 0;
          if (aStart != bStart) return aStart.compareTo(bStart);
        } catch (e) {
          if (aYear != bYear) return aYear.compareTo(bYear);
        }

        final aPeriod = aParts[1];
        final bPeriod = bParts[1];
        if (aPeriod == 'Baseline' && bPeriod == 'Endline') return -1;
        if (aPeriod == 'Endline' && bPeriod == 'Baseline') return 1;
        return 0;
      });

    if (sortedKeys.isEmpty) {
      return _buildEmptyState();
    }

    // Group data by year
    final Map<String, List<Map<String, dynamic>>> groupedByYear = {};
    for (final key in sortedKeys) {
      final parts = key.split(':');
      final year = parts[0];
      if (!groupedByYear.containsKey(year)) {
        groupedByYear[year] = [];
      }
      groupedByYear[year]!.add(groupedData[key]!);
    }

    // Get sorted years
    final years = groupedByYear.keys.toList()
      ..sort((a, b) {
        try {
          final aStart = int.tryParse(a.split('-').first) ?? 0;
          final bStart = int.tryParse(b.split('-').first) ?? 0;
          return aStart.compareTo(bStart);
        } catch (e) {
          return a.compareTo(b);
        }
      });

    // Calculate max Y value
    double maxY = 0;
    for (final year in years) {
      for (final periodData in groupedByYear[year]!) {
        final values = [
          periodData['avg_bmi'] as double,
          periodData['avg_height'] as double,
          periodData['avg_weight'] as double,
          periodData['avg_hfa'] as double,
          periodData['total_at_risk'] as double,
        ];
        final maxValue = values.reduce((a, b) => a > b ? a : b);
        if (maxValue > maxY) maxY = maxValue;
      }
    }

    // Add padding
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100;

    // Define metrics and their colors
    final metrics = [
      {'label': 'Avg BMI', 'color': Colors.blue.shade400},
      {'label': 'Avg Height', 'color': Colors.green.shade400},
      {'label': 'Avg Weight', 'color': Colors.orange.shade400},
      {'label': 'Avg HFA', 'color': Colors.purple.shade400},
      {'label': 'Total At Risk', 'color': Colors.red.shade400},
    ];

    // Create bar groups with proper spacing
    final barGroups = <BarChartGroupData>[];

    // Calculate spacing
    final double groupSpace = 0.3; // Space between year groups
    final double barSpace = 0.15; // Space between bars in same group
    final double barWidth = 0.12; // Width of individual bars

    for (int yearIndex = 0; yearIndex < years.length; yearIndex++) {
      final year = years[yearIndex];
      final yearData = groupedByYear[year]!;

      // Sort by period: Baseline first, then Endline
      yearData.sort((a, b) {
        final aPeriod = a['period'] as String;
        final bPeriod = b['period'] as String;
        if (aPeriod == 'Baseline' && bPeriod == 'Endline') return -1;
        if (aPeriod == 'Endline' && bPeriod == 'Baseline') return 1;
        return 0;
      });

      // Calculate base x position for this year
      final double baseX = yearIndex.toDouble() * (1 + groupSpace);

      for (int periodIndex = 0; periodIndex < yearData.length; periodIndex++) {
        final periodData = yearData[periodIndex];
        final period = periodData['period'] as String;

        // Calculate x position for this period
        final double periodOffset =
            yearData.length > 1 ? (periodIndex == 0 ? -barSpace : barSpace) : 0;
        final double groupX = baseX + periodOffset;

        // Create bar rods for each metric
        final List<BarChartRodData> barRods = [];

        for (int metricIndex = 0; metricIndex < metrics.length; metricIndex++) {
          final metric = metrics[metricIndex];
          final value = [
            periodData['avg_bmi'],
            periodData['avg_height'],
            periodData['avg_weight'],
            periodData['avg_hfa'],
            periodData['total_at_risk'],
          ][metricIndex] as double;

          // Calculate bar position with proper spacing
          final double barPosition = metricIndex * (barWidth + barSpace);

          barRods.add(
            BarChartRodData(
              toY: value,
              width: barWidth,
              color: metric['color'] as Color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
          );
        }

        barGroups.add(
          BarChartGroupData(
            x: groupX.toInt(),
            groupVertically: false,
            barsSpace: barSpace,
            barRods: barRods,
          ),
        );
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: maxY,
        minY: 0,
        groupsSpace: groupSpace,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              // Find the year and period for this group
              int yearIndex = 0;
              double accumulated = 0;
              for (int i = 0; i < years.length; i++) {
                final yearData = groupedByYear[years[i]]!;
                final periodsInYear = yearData.length;

                if (groupIndex < (accumulated + periodsInYear)) {
                  yearIndex = i;
                  break;
                }
                accumulated += periodsInYear;
              }

              final year = years[yearIndex];
              final period = groupedByYear[year]!.first['period'] as String;
              final metric = metrics[rodIndex];
              final value = rod.toY;

              final unit = rodIndex == 1
                  ? ' cm'
                  : rodIndex == 2
                      ? ' kg'
                      : '';

              return BarTooltipItem(
                '${metric['label']}: ${value.toStringAsFixed(1)}$unit\n'
                '$year $period',
                TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
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
                if (index >= 0 && index < years.length) {
                  final year = years[index];
                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 80,
                      child: Text(
                        year,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % (_getYInterval(maxY)) == 0 || value == 0) {
                  return Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
              reservedSize: 40,
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine:
              false, // Remove vertical grid lines for cleaner look
          drawHorizontalLine: true,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        barGroups: barGroups,
      ),
    );
  }

  double _getYInterval(double maxY) {
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    if (maxY <= 200) return 50;
    return 100;
  }

  Widget _buildChartLegend() {
    final metrics = [
      {'label': 'Avg BMI', 'color': Colors.blue.shade400},
      {'label': 'Avg Height', 'color': Colors.green.shade400},
      {'label': 'Avg Weight', 'color': Colors.orange.shade400},
      {'label': 'Avg HFA', 'color': Colors.purple.shade400},
      {'label': 'Total At Risk', 'color': Colors.red.shade400},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: metrics.map((metric) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: metric['color'] as Color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    metric['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Baseline',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Endline',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade400),
          SizedBox(height: 12),
          Text(
            'No data available for average student status',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
