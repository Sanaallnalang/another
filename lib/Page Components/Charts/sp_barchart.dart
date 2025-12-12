// lib/Components/Charts/sp_barchart.dart
import 'dart:math';

import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SchoolPopulationBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> studentData;

  const SchoolPopulationBarChart({super.key, required this.studentData});

  @override
  Widget build(BuildContext context) {
    if (studentData.isEmpty) {
      return _buildEmptyState('No school data available');
    }

    // Check if we have valid data
    final hasValidData = studentData.any((d) {
      final total = d['total'] as int? ?? 0;
      return total > 0;
    });

    if (!hasValidData) {
      return _buildEmptyState('No student population data available');
    }

    try {
      final maxStudents = studentData.isNotEmpty
          ? studentData
              .map((d) => d['total'] as int? ?? 0)
              .reduce((a, b) => a > b ? a : b)
          : 0;

      // Calculate better interval to prevent overlapping
      final interval = _calculateSmartInterval(maxStudents.toDouble());
      final maxY = _calculateMaxY(maxStudents.toDouble());

      // Calculate reserved size based on number of digits
      final maxDigits = maxY.toString().length;
      final reservedSize =
          24.0 + (maxDigits * 4.0); // Dynamic width based on digit count

      return Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex >= 0 && groupIndex < studentData.length) {
                        final school = studentData[groupIndex];
                        final gender = rodIndex == 0 ? 'Male' : 'Female';
                        final count = rodIndex == 0
                            ? school['male'] as int? ?? 0
                            : school['female'] as int? ?? 0;
                        final total = school['total'] as int? ?? 0;
                        final percentage =
                            total > 0 ? (count / total * 100) : 0;

                        return BarTooltipItem(
                          '${_getSchoolName(school)}\n$gender: $count (${percentage.toStringAsFixed(1)}%)',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }
                      return BarTooltipItem(
                        'No data',
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
                        final idx = value.toInt();
                        if (idx >= 0 && idx < studentData.length) {
                          final schoolName = _getSchoolName(studentData[idx]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _generateAcronym(schoolName),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
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
                      interval: interval,
                      reservedSize: reservedSize, // Dynamic reserved space
                      getTitlesWidget: (value, meta) {
                        // Only show integer values
                        if (value % interval == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                      dashArray: [3, 3],
                    );
                  },
                  checkToShowHorizontalLine: (value) {
                    // Show grid lines at interval points
                    return value % interval == 0;
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                barGroups: studentData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: (data['male'] as int? ?? 0).toDouble(),
                        width: 12,
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      BarChartRodData(
                        toY: (data['female'] as int? ?? 0).toDouble(),
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
          _buildGenderLegend(),
        ],
      );
    } catch (e) {
      print('Error rendering bar chart: $e');
      return _buildEmptyState('Error displaying chart data');
    }
  }

  // Improved interval calculation to prevent overlapping
  double _calculateSmartInterval(double maxValue) {
    if (maxValue <= 0) return 10;

    // Calculate nice intervals based on the max value
    final magnitude = (maxValue.log10()).floor();
    final fraction = maxValue / (10.pow(magnitude));

    double interval;

    if (fraction < 1.5) {
      interval = 0.2 * (10.pow(magnitude));
    } else if (fraction < 3) {
      interval = 0.5 * (10.pow(magnitude));
    } else if (fraction < 7) {
      interval = 1.0 * (10.pow(magnitude));
    } else {
      interval = 2.0 * (10.pow(magnitude));
    }

    // Ensure we don't have too many grid lines
    final numberOfIntervals = maxValue / interval;
    if (numberOfIntervals > 10) {
      interval = _calculateSmartInterval(maxValue * 1.2);
    }

    return interval;
  }

  // Calculate max Y value with some padding
  double _calculateMaxY(double maxValue) {
    if (maxValue <= 0) return 10;

    final interval = _calculateSmartInterval(maxValue);
    final numberOfIntervals = (maxValue / interval).ceil();
    return (numberOfIntervals * interval) * 1.1; // 10% padding
  }

  Widget _buildGenderLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Male', Colors.blue),
        const SizedBox(width: 16),
        _buildLegendItem('Female', Colors.pink),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _getSchoolName(Map<String, dynamic> school) {
    try {
      final schoolObj = school['school'];
      if (schoolObj is Map<String, dynamic>) {
        return schoolObj['schoolName']?.toString().trim() ?? 'Unknown School';
      } else if (schoolObj is SchoolProfile) {
        return schoolObj.schoolName.toString().trim();
      }
      return 'Unknown School';
    } catch (e) {
      return 'Unknown School';
    }
  }

  String _generateAcronym(String schoolName) {
    if (schoolName.isEmpty) return 'N/A';

    final words =
        schoolName.trim().split(' ').where((word) => word.isNotEmpty).toList();

    if (words.isEmpty) return 'N/A';

    if (words.length > 1) {
      return words.map((word) => word[0]).join('').toUpperCase();
    }

    return schoolName.length <= 3
        ? schoolName.toUpperCase()
        : schoolName.substring(0, 3).toUpperCase();
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Extension for power function
extension Power on num {
  double pow(int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent.abs(); i++) {
      result *= toDouble();
    }
    return exponent >= 0 ? result : 1 / result;
  }

  double log10() {
    return (log(this) / ln10);
  }
}
