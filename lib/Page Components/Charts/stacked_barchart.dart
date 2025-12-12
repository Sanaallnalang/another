// lib/Components/Charts/nutritional_stacked_bar_chart.dart
import 'dart:math' show ln10, log;

import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NutritionalStackedBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> schoolNutritionalData;
  final bool isSmallScreen;

  const NutritionalStackedBarChart({
    super.key,
    required this.schoolNutritionalData,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (schoolNutritionalData.isEmpty) {
      return _buildEmptyState();
    }

    // Check if we have valid data
    final hasValidData = schoolNutritionalData.any((d) {
      final total = d['total'] as int? ?? 0;
      return total > 0;
    });

    if (!hasValidData) {
      return _buildEmptyState();
    }

    try {
      final maxStudents = schoolNutritionalData.isNotEmpty
          ? schoolNutritionalData
              .map((d) => d['total'] as int? ?? 0)
              .reduce((a, b) => a > b ? a : b)
          : 0;

      // Calculate smart interval and max Y
      final interval = _calculateSmartInterval(maxStudents.toDouble());
      final maxY = _calculateMaxY(maxStudents.toDouble());

      // Calculate reserved size based on number of digits
      final maxDigits = maxY.toString().length;
      final reservedSize =
          28.0 + (maxDigits * 4.0); // Dynamic width based on digit count

      return Column(
        children: [
          const Text(
            'Nutritional Status by School',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
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
                      if (groupIndex >= 0 &&
                          groupIndex < schoolNutritionalData.length) {
                        final school = schoolNutritionalData[groupIndex];
                        final status = _getStatusLabel(rodIndex);
                        final count = _getStatusCount(school, rodIndex);
                        final total = school['total'] as int? ?? 0;
                        final percentage =
                            total > 0 ? (count / total * 100) : 0;

                        return BarTooltipItem(
                          '${_getSchoolName(school)}\n$status: $count (${percentage.toStringAsFixed(1)}%)',
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
                        if (idx >= 0 && idx < schoolNutritionalData.length) {
                          final schoolName = _getSchoolName(
                            schoolNutritionalData[idx],
                          );
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
                      reservedSize: reservedSize,
                      getTitlesWidget: (value, meta) {
                        // Only show labels at interval points
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
                    // Only show grid lines at interval points
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
                barGroups: schoolNutritionalData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(
                        toY: (data['severelyWasted'] as int? ?? 0).toDouble(),
                        width: isSmallScreen ? 16 : 20,
                        color: Colors.red,
                        borderRadius: BorderRadius.zero,
                      ),
                      BarChartRodData(
                        toY: (data['wasted'] as int? ?? 0).toDouble(),
                        width: isSmallScreen ? 16 : 20,
                        color: Colors.orange,
                        borderRadius: BorderRadius.zero,
                      ),
                      BarChartRodData(
                        toY: (data['normal'] as int? ?? 0).toDouble(),
                        width: isSmallScreen ? 16 : 20,
                        color: Colors.green,
                        borderRadius: BorderRadius.zero,
                      ),
                      BarChartRodData(
                        toY: (data['overweight'] as int? ?? 0).toDouble(),
                        width: isSmallScreen ? 16 : 20,
                        color: Colors.yellow,
                        borderRadius: BorderRadius.zero,
                      ),
                      BarChartRodData(
                        toY: (data['obese'] as int? ?? 0).toDouble(),
                        width: isSmallScreen ? 16 : 20,
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.zero,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildNutritionalLegend(),
        ],
      );
    } catch (e) {
      print('Error rendering stacked bar chart: $e');
      return _buildEmptyState();
    }
  }

  Widget _buildNutritionalLegend() {
    final statuses = [
      {'label': 'Severely Wasted', 'color': Colors.red},
      {'label': 'Wasted', 'color': Colors.orange},
      {'label': 'Normal', 'color': Colors.green},
      {'label': 'Overweight', 'color': Colors.yellow},
      {'label': 'Obese', 'color': Colors.deepOrange},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: statuses.map((status) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (status['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: (status['color'] as Color).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status['color'] as Color,
                  shape: BoxShape.rectangle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                status['label'] as String,
                style: TextStyle(
                  fontSize: 9,
                  color: status['color'] as Color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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

  String _getStatusLabel(int index) {
    switch (index) {
      case 0:
        return 'Severely Wasted';
      case 1:
        return 'Wasted';
      case 2:
        return 'Normal';
      case 3:
        return 'Overweight';
      case 4:
        return 'Obese';
      default:
        return '';
    }
  }

  int _getStatusCount(Map<String, dynamic> school, int index) {
    switch (index) {
      case 0:
        return school['severelyWasted'] as int? ?? 0;
      case 1:
        return school['wasted'] as int? ?? 0;
      case 2:
        return school['normal'] as int? ?? 0;
      case 3:
        return school['overweight'] as int? ?? 0;
      case 4:
        return school['obese'] as int? ?? 0;
      default:
        return 0;
    }
  }

  // Smart interval calculation to prevent overlapping
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

    // Ensure minimum interval of 5 for readability
    return interval < 5 ? 5.0 : interval;
  }

  // Calculate max Y value with some padding
  double _calculateMaxY(double maxValue) {
    if (maxValue <= 0) return 10;

    final interval = _calculateSmartInterval(maxValue);
    final numberOfIntervals = (maxValue / interval).ceil();
    return (numberOfIntervals * interval) * 1.1; // 10% padding
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No nutritional data available',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

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
