// nutritional_status_line_chart.dart - UPDATED DATE FORMATTING
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NutritionalStatusLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> lineChartData;
  final bool isLoading;

  const NutritionalStatusLineChart({
    super.key,
    required this.lineChartData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lineChartData.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(height: 420, child: _buildEnhancedLineChart());
  }

  Widget _buildEnhancedLineChart() {
    // Group data by date and nutritional status
    final Map<String, Map<String, dynamic>> statusData = {};

    for (final data in lineChartData) {
      final date = data['assessment_date']?.toString() ?? '';
      final status = data['nutritional_status']?.toString() ?? 'Unknown';
      final count = (data['count'] as num?)?.toInt() ?? 0;
      final period = data['period']?.toString() ?? '';

      if (!statusData.containsKey(date)) {
        statusData[date] = {
          'date': date,
          'period': period,
          'Severely Wasted': 0,
          'Wasted': 0,
          'Normal': 0,
          'Overweight': 0,
          'Obese': 0,
          'total': 0,
        };
      }

      // Map status to standard categories
      final normalizedStatus = _normalizeStatus(status);
      statusData[date]![normalizedStatus] =
          (statusData[date]![normalizedStatus] as int) + count;
      statusData[date]!['total'] = (statusData[date]!['total'] as int) + count;
    }

    // Sort dates chronologically
    final sortedDates = statusData.keys.toList()
      ..sort((a, b) {
        try {
          // Handle academic year format like "2023-2024"
          if (a.contains('-') && b.contains('-')) {
            final aStart = int.tryParse(a.split('-').first) ?? 0;
            final bStart = int.tryParse(b.split('-').first) ?? 0;
            return aStart.compareTo(bStart);
          }
          // Handle regular dates
          final aDate = DateTime.tryParse(a) ?? DateTime(2000);
          final bDate = DateTime.tryParse(b) ?? DateTime(2000);
          return aDate.compareTo(bDate);
        } catch (e) {
          return a.compareTo(b);
        }
      });

    if (sortedDates.isEmpty) {
      return _buildEmptyState();
    }

    // Prepare data for each status line
    final Map<String, List<FlSpot>> statusLines = {
      'Severely Wasted': [],
      'Wasted': [],
      'Normal': [],
      'Overweight': [],
      'Obese': [],
    };

    // Calculate max Y value
    double maxY = 0;

    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final data = statusData[date]!;

      for (final status in statusLines.keys) {
        final count = (data[status] as int?) ?? 0;
        statusLines[status]!.add(FlSpot(i.toDouble(), count.toDouble()));

        if (count > maxY) maxY = count.toDouble();
      }
    }

    // Add padding
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100;

    // Create x-axis labels
    final xLabels = sortedDates.map((date) {
      final data = statusData[date]!;
      final period = data['period'] as String;
      final isAssessment = period == 'Baseline' || period == 'Endline';

      return {'date': date, 'period': period, 'isAssessment': isAssessment};
    }).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: sortedDates.isNotEmpty ? sortedDates.length - 1 : 1,
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.toInt();
                if (index < sortedDates.length) {
                  final date = sortedDates[index];
                  final data = statusData[date]!;
                  final period = data['period'] as String;

                  // Find which line this spot belongs to
                  String status = 'Unknown';
                  for (final entry in statusLines.entries) {
                    if (entry.value.length > index &&
                        entry.value[index].x == spot.x &&
                        entry.value[index].y == spot.y) {
                      status = entry.key;
                      break;
                    }
                  }

                  // Format date for display
                  String dateDisplay = _formatDateForDisplay(date);
                  final total = data['total'] as int;
                  final percentage = total > 0
                      ? (spot.y / total * 100).toStringAsFixed(1)
                      : '0.0';

                  return LineTooltipItem(
                    '$status\n'
                    'Count: ${spot.y.toInt()} ($percentage%)\n'
                    'Date: $dateDisplay\n'
                    '${period.isNotEmpty ? 'Period: $period' : ''}',
                    TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return LineTooltipItem(
                  'Unknown: ${spot.y.toInt()}',
                  TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
              dashArray: value % 5 == 0 ? null : [5, 5],
            );
          },
          getDrawingVerticalLine: (value) {
            final index = value.toInt();
            if (index < xLabels.length &&
                xLabels[index]['isAssessment'] as bool) {
              return FlLine(color: Colors.grey.shade400, strokeWidth: 1.5);
            }
            return FlLine(color: Colors.grey.shade100, strokeWidth: 0.5);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < xLabels.length) {
                  final label = xLabels[index];
                  final isAssessment = label['isAssessment'] as bool;
                  final period = label['period'] as String;
                  final date = label['date'] as String;

                  // Only show labels for assessment periods
                  if (isAssessment) {
                    String dateDisplay = _formatDateForDisplay(date);

                    return Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 90,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Date
                            Text(
                              dateDisplay,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 2),
                            // Period indicator
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: period == 'Baseline'
                                    ? Colors.blue.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: period == 'Baseline'
                                      ? Colors.blue.shade100
                                      : Colors.green.shade100,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                period,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: period == 'Baseline'
                                      ? Colors.blue.shade700
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // For regular months, just show a vertical line indicator
                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Container(
                      width: 4,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
              reservedSize: 50,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % (_getYInterval(maxY)) == 0 || value == 0) {
                  return Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
              reservedSize: 45,
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        lineBarsData: [
          // Severely Wasted Line
          _buildLineChartBarData(
            spots: statusLines['Severely Wasted']!,
            color: Colors.red.shade800,
          ),
          // Wasted Line
          _buildLineChartBarData(
            spots: statusLines['Wasted']!,
            color: Colors.red.shade400,
          ),
          // Normal Line
          _buildLineChartBarData(
            spots: statusLines['Normal']!,
            color: Colors.green.shade400,
          ),
          // Overweight Line
          _buildLineChartBarData(
            spots: statusLines['Overweight']!,
            color: Colors.orange.shade400,
          ),
          // Obese Line
          _buildLineChartBarData(
            spots: statusLines['Obese']!,
            color: Colors.deepOrange.shade400,
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineChartBarData({
    required List<FlSpot> spots,
    required Color color,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.15),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), color.withOpacity(0.05)],
        ),
      ),
    );
  }

  String _normalizeStatus(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('severely') && statusLower.contains('wasted')) {
      return 'Severely Wasted';
    } else if (statusLower.contains('wasted')) {
      return 'Wasted';
    } else if (statusLower.contains('normal')) {
      return 'Normal';
    } else if (statusLower.contains('overweight')) {
      return 'Overweight';
    } else if (statusLower.contains('obese')) {
      return 'Obese';
    }
    return 'Normal';
  }

  double _getYInterval(double maxY) {
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    if (maxY <= 200) return 50;
    return 100;
  }

  String _formatDateForDisplay(String date) {
    try {
      // Handle academic year format like "2023-2024"
      if (date.contains('-') && !date.contains('/') && !date.contains('.')) {
        final parts = date.split('-');
        if (parts.length >= 2) {
          final startYear = parts[0];
          final endYear = parts[1].substring(
            0,
            4,
          ); // Take first 4 chars for end year
          return '$startYear-$endYear';
        }
        return date;
      }

      // Try to parse as DateTime
      final dateTime = DateTime.tryParse(date);
      if (dateTime != null) {
        // Format as "MMM DD, YYYY" (e.g., "Jan 15, 2023")
        final monthNames = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final month = monthNames[dateTime.month - 1];
        final day = dateTime.day;
        final year = dateTime.year;
        return '$month $day, $year';
      }
    } catch (e) {
      // Fall through
    }

    // Return as is if parsing fails
    return date;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 60, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            'No nutritional timeline data available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
