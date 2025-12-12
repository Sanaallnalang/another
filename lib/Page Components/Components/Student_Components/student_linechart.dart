import 'package:district_dev/Page%20Components/Components/School_Analytics/who_standard.dart';
import 'package:district_dev/Services/Database/database_service.dart'
    as db_service;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StudentGrowthLineChart extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String metricType; // 'weight', 'height', 'bmi', or 'hfa'

  const StudentGrowthLineChart({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.metricType,
  });

  @override
  State<StudentGrowthLineChart> createState() => _StudentGrowthLineChartState();
}

class _StudentGrowthLineChartState extends State<StudentGrowthLineChart> {
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showDetailedView = false;

  final db_service.DatabaseService _dbService =
      db_service.DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final db = await _dbService.database;

      List<Map<String, dynamic>> results;

      if (widget.metricType == 'hfa') {
        // Get height, age, and sex data to calculate HFA
        final sql = '''
        SELECT 
          assessment_date,
          height_cm,
          age,
          sex,
          period,
          academic_year,
          grade_level
        FROM (
          -- Baseline
          SELECT 
            ba.assessment_date,
            ba.height_cm,
            bl.age,
            bl.sex,
            'Baseline' AS period,
            bl.academic_year,
            bl.grade_level
          FROM baseline_learners bl
          JOIN baseline_assessments ba ON bl.id = ba.learner_id
          WHERE bl.student_id = ? AND ba.height_cm IS NOT NULL AND bl.age IS NOT NULL
          
          UNION ALL
          
          -- Endline
          SELECT 
            ea.assessment_date,
            ea.height_cm,
            el.age,
            el.sex,
            'Endline' AS period,
            el.academic_year,
            el.grade_level
          FROM endline_learners el
          JOIN endline_assessments ea ON el.id = ea.learner_id
          WHERE el.student_id = ? AND ea.height_cm IS NOT NULL AND el.age IS NOT NULL
        )
        ORDER BY assessment_date
        ''';

        results = await db.rawQuery(sql, [widget.studentId, widget.studentId]);

        // Process and calculate HFA
        final processedData = await _prepareHFAChartData(results);
        setState(() {
          _chartData = processedData;
          _isLoading = false;
        });
        return;
      } else {
        // Regular query for weight, height, bmi
        final metricField = _getMetricField();
        final sql = '''
        SELECT 
          assessment_date,
          $metricField as value,
          period,
          academic_year,
          grade_level,
          age
        FROM (
          -- Baseline
          SELECT 
            ba.assessment_date,
            ba.$metricField,
            'Baseline' AS period,
            bl.academic_year,
            bl.grade_level,
            bl.age
          FROM baseline_learners bl
          JOIN baseline_assessments ba ON bl.id = ba.learner_id
          WHERE bl.student_id = ? AND ba.$metricField IS NOT NULL
          
          UNION ALL
          
          -- Endline
          SELECT 
            ea.assessment_date,
            ea.$metricField,
            'Endline' AS period,
            el.academic_year,
            el.grade_level,
            el.age
          FROM endline_learners el
          JOIN endline_assessments ea ON el.id = ea.learner_id
          WHERE el.student_id = ? AND ea.$metricField IS NOT NULL
        )
        ORDER BY assessment_date
        ''';

        results = await db.rawQuery(sql, [widget.studentId, widget.studentId]);
      }

      // Process the data
      final processedData = await _prepareChartData(results);

      setState(() {
        _chartData = processedData;
        _isLoading = false;
      });

      debugPrint(
        '📈 ${_getChartTitle()} loaded: ${_chartData.length} data points',
      );
    } catch (e) {
      debugPrint('❌ Error loading chart data: $e');
      setState(() {
        _errorMessage = 'Failed to load ${widget.metricType} data';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _prepareHFAChartData(
    List<Map<String, dynamic>> rawData,
  ) async {
    final enhancedData = <Map<String, dynamic>>[];

    for (final dataPoint in rawData) {
      final height = dataPoint['height_cm'] as num? ?? 0;
      final age = dataPoint['age'] as int? ?? 0;
      final sex = dataPoint['sex'] as String? ?? 'Unknown';

      // Calculate HFA status using WHO standards
      String hfaStatus = 'No Data';
      double zscore = 0.0;
      double medianHeight = 0.0;

      if (height > 0 && age >= 5 && age <= 19) {
        final hfaResult = WHOStandardsService.calculateHFA(
          height.toDouble(),
          age,
          sex,
        );
        hfaStatus = hfaResult['status'] as String? ?? 'No Data';
        zscore = hfaResult['zscore'] as double? ?? 0.0;
        medianHeight = hfaResult['median_height'] as double? ?? 0.0;
      }

      final numericValue = _hfaStatusToNumber(hfaStatus);

      enhancedData.add({
        'date': dataPoint['assessment_date'] as String? ?? '',
        'value': numericValue,
        'raw_value': hfaStatus,
        'zscore': zscore,
        'median_height': medianHeight,
        'period': dataPoint['period'] as String? ?? 'Unknown',
        'academic_year': dataPoint['academic_year'] as String? ?? 'Unknown',
        'grade': dataPoint['grade_level'] as String? ?? 'Unknown',
        'age': age,
        'sex': sex,
        'height_cm': height,
        'formatted_date': _formatDateForChart(
          dataPoint['assessment_date'] as String? ?? '',
        ),
        'formatted_date_short': _formatDateShort(
          dataPoint['assessment_date'] as String? ?? '',
          enhancedData.length,
        ),
        'index': enhancedData.length,
        'has_calculated_hfa': hfaStatus != 'No Data',
      });
    }

    return enhancedData;
  }

  Future<List<Map<String, dynamic>>> _prepareChartData(
    List<Map<String, dynamic>> rawData,
  ) async {
    // Process numeric data (weight, height, bmi)
    final filteredData = rawData.where((dataPoint) {
      final value = dataPoint['value'];
      final date = dataPoint['assessment_date'] as String?;

      return value != null &&
          (value as num) > 0 &&
          date != null &&
          date.isNotEmpty &&
          DateTime.tryParse(date) != null;
    }).toList();

    // Sort by date
    filteredData.sort((a, b) {
      final dateAStr = a['assessment_date'] as String? ?? '';
      final dateBStr = b['assessment_date'] as String? ?? '';
      final dateA = DateTime.tryParse(dateAStr) ?? DateTime(1900);
      final dateB = DateTime.tryParse(dateBStr) ?? DateTime(1900);
      return dateA.compareTo(dateB);
    });

    // Add additional context data
    final enhancedData = <Map<String, dynamic>>[];
    for (final dataPoint in filteredData) {
      enhancedData.add({
        'date': dataPoint['assessment_date'] as String? ?? '',
        'value': dataPoint['value'] as num? ?? 0.0,
        'period': dataPoint['period'] as String? ?? 'Unknown',
        'academic_year': dataPoint['academic_year'] as String? ?? 'Unknown',
        'grade': dataPoint['grade_level'] as String? ?? 'Unknown',
        'age': dataPoint['age'] as int? ?? 0,
        'formatted_date': _formatDateForChart(
          dataPoint['assessment_date'] as String? ?? '',
        ),
        'formatted_date_short': _formatDateShort(
          dataPoint['assessment_date'] as String? ?? '',
          enhancedData.length,
        ),
        'index': enhancedData.length,
      });
    }

    return enhancedData;
  }

  double _hfaStatusToNumber(String hfaStatus) {
    switch (hfaStatus.toLowerCase()) {
      case 'severely stunted':
        return 1.0;
      case 'stunted':
        return 2.0;
      case 'normal':
        return 3.0;
      case 'tall':
        return 4.0;
      case 'very tall':
        return 5.0;
      default:
        return 0.0;
    }
  }

  String _hfaNumberToStatus(double value) {
    if (value <= 1.5) return 'Severely Stunted';
    if (value <= 2.5) return 'Stunted';
    if (value <= 3.5) return 'Normal';
    if (value <= 4.5) return 'Tall';
    return 'Very Tall';
  }

  Future<void> _refreshData() async {
    await _loadChartData();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getChartTitle(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (_chartData.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${_chartData.length} measurement${_chartData.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isLoading && _chartData.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          _showDetailedView
                              ? Icons.table_chart
                              : Icons.show_chart,
                          size: 18,
                          color: Colors.blue[700],
                        ),
                        onPressed: () {
                          setState(() {
                            _showDetailedView = !_showDetailedView;
                          });
                        },
                        tooltip:
                            _showDetailedView ? 'Show chart' : 'Show table',
                      ),
                    if (_isLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue[700],
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      onPressed: _refreshData,
                      tooltip: 'Refresh data',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main content area
            if (_isLoading) SizedBox(height: 90, child: _buildLoadingState()),
            if (!_isLoading && _errorMessage.isNotEmpty)
              SizedBox(height: 90, child: _buildErrorState(_errorMessage)),
            if (!_isLoading && _chartData.isEmpty)
              SizedBox(
                height: 90,
                child: _buildEmptyState(
                  'No ${widget.metricType} data available',
                ),
              ),
            if (!_isLoading && _chartData.isNotEmpty) ...[
              // Chart or Table view
              Container(
                height: 100, // Increased from 90 to 100
                padding: const EdgeInsets.all(8),
                child: _showDetailedView
                    ? _buildDataTable()
                    : (widget.metricType == 'hfa'
                        ? _buildHFAChart()
                        : _buildChart()),
              ),
              const SizedBox(height: 18),
              // Summary section
              if (_chartData.length >= 2)
                SizedBox(height: 70, child: _buildChartSummary()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final hasManyPoints = _chartData.length > 8;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getYInterval(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
              dashArray: [3, 3],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _chartData.length) {
                  if (hasManyPoints) {
                    if (index % 3 == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _chartData[index]['formatted_date_short'],
                          style: TextStyle(fontSize: 9, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }
                  } else {
                    if (index % 2 == 0 || _chartData.length <= 4) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _chartData[index]['formatted_date'],
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }
                  }
                }
                return const SizedBox.shrink();
              },
              reservedSize: hasManyPoints ? 18 : 22,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _getYInterval(),
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: hasManyPoints ? 9 : 10,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
              reservedSize: hasManyPoints ? 35 : 40, // Increased from 28/32
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[400]!, width: 1),
        ),
        minX: 0,
        maxX: _chartData.isEmpty ? 1 : (_chartData.length - 1).toDouble(),
        minY: _getMinY(),
        maxY: _getMaxY(),
        lineBarsData: [
          LineChartBarData(
            spots: _chartData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return FlSpot(index.toDouble(), data['value'].toDouble());
            }).toList(),
            isCurved: _chartData.length > 2,
            color: _getChartColor(),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: _chartData.length <= 12,
              getDotPainter: (spot, percent, barData, index) {
                final period = _chartData[index]['period'] as String? ?? '';
                return FlDotCirclePainter(
                  radius: period == 'Baseline' ? 4 : 3.5,
                  color: _getChartColor(),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: _chartData.length <= 15,
              gradient: LinearGradient(
                colors: [
                  _getChartColor().withOpacity(0.25),
                  _getChartColor().withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.white,
            tooltipBorder: BorderSide(color: _getChartColor(), width: 1),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final index = touchedSpot.spotIndex;
                if (index >= 0 && index < _chartData.length) {
                  final data = _chartData[index];
                  return LineTooltipItem(
                    '${data['formatted_date']}\n'
                    '${data['value'].toStringAsFixed(1)} ${_getUnit()}\n'
                    '${data['period']} • ${data['academic_year']}',
                    const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return LineTooltipItem('', const TextStyle());
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHFAChart() {
    final hasManyPoints = _chartData.length > 8;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            if (value.toInt() == 3) {
              return FlLine(
                color: Colors.green[700]!,
                strokeWidth: 1.5,
                dashArray: [4, 4],
              );
            }
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
              dashArray: [2, 2],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _chartData.length) {
                  if (hasManyPoints) {
                    if (index % 3 == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _chartData[index]['formatted_date_short'],
                          style: TextStyle(fontSize: 9, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }
                  } else {
                    if (index % 2 == 0 || _chartData.length <= 4) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _chartData[index]['formatted_date'],
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }
                  }
                }
                return const SizedBox.shrink();
              },
              reservedSize: hasManyPoints ? 18 : 22,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final status = _hfaNumberToStatus(value);
                if (value.toInt() == 1 ||
                    value.toInt() == 2 ||
                    value.toInt() == 3 ||
                    value.toInt() == 4) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: hasManyPoints ? 8 : 9,
                        color: _getHFAStatusColor(status),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: hasManyPoints ? 55 : 65, // Increased from 45/55
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[500]!, width: 1),
        ),
        minX: 0,
        maxX: _chartData.isEmpty ? 1 : (_chartData.length - 1).toDouble(),
        minY: 0.5,
        maxY: 5.5,
        lineBarsData: [
          LineChartBarData(
            spots: _chartData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return FlSpot(index.toDouble(), data['value'].toDouble());
            }).toList(),
            isCurved: _chartData.length > 2,
            color: _getChartColor(),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final hfaValue = _chartData[index]['raw_value'] as String;
                return FlDotCirclePainter(
                  radius: 4,
                  color: _getHFAStatusColor(hfaValue),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: _chartData.length <= 15,
              gradient: LinearGradient(
                colors: [
                  _getChartColor().withOpacity(0.2),
                  _getChartColor().withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.white,
            tooltipBorder: BorderSide(color: _getChartColor(), width: 1),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final index = touchedSpot.spotIndex;
                if (index >= 0 && index < _chartData.length) {
                  final data = _chartData[index];
                  final zscore = data['zscore'] as double? ?? 0.0;
                  final height = data['height_cm'] as num? ?? 0;
                  final age = data['age'] as int? ?? 0;
                  final medianHeight = data['median_height'] as double? ?? 0.0;

                  return LineTooltipItem(
                    '${data['formatted_date']}\n'
                    'HFA: ${data['raw_value']}\n'
                    'Z-score: ${zscore.toStringAsFixed(2)}\n'
                    'Height: ${height.toStringAsFixed(1)} cm (Age: $age)\n'
                    'Expected: ${medianHeight.toStringAsFixed(1)} cm\n'
                    '${data['period']} • ${data['academic_year']}',
                    const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return LineTooltipItem('', const TextStyle());
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 35,
            dataRowHeight: 32,
            headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
            columns: [
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: widget.metricType == 'hfa' ? 90 : 70,
                  child: Text(
                    widget.metricType == 'hfa' ? 'HFA Status' : 'Value',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              if (widget.metricType == 'hfa')
                DataColumn(
                  label: SizedBox(
                    width: 60,
                    child: Text(
                      'Z-score',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              DataColumn(
                label: SizedBox(
                  width: 70,
                  child: Text(
                    'Period',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 70,
                  child: Text(
                    'Year',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
            rows: _chartData.map((data) {
              final displayValue = widget.metricType == 'hfa'
                  ? (data['raw_value'] as String? ?? 'N/A')
                  : '${data['value'].toStringAsFixed(1)} ${_getUnit()}';

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: Text(
                        data['formatted_date'],
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: widget.metricType == 'hfa' ? 90 : 70,
                      child: Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.metricType == 'hfa'
                              ? _getHFAStatusColor(displayValue)
                              : _getChartColor(),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (widget.metricType == 'hfa')
                    DataCell(
                      SizedBox(
                        width: 60,
                        child: Text(
                          data['zscore'] != null
                              ? (data['zscore'] as double).toStringAsFixed(2)
                              : 'N/A',
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  DataCell(
                    Container(
                      width: 70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: data['period'] == 'Baseline'
                            ? Colors.blue.withOpacity(0.15)
                            : Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: data['period'] == 'Baseline'
                              ? Colors.blue.withOpacity(0.5)
                              : Colors.green.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        data['period'],
                        style: TextStyle(
                          fontSize: 9,
                          color: data['period'] == 'Baseline'
                              ? Colors.blue[800]
                              : Colors.green[800],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 70,
                      child: Text(
                        data['academic_year'],
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildChartSummary() {
    if (_chartData.length < 2) return const SizedBox();

    final firstValue = _chartData.first['value'];
    final lastValue = _chartData.last['value'];

    if (widget.metricType == 'hfa') {
      final firstStatus = _chartData.first['raw_value'] as String? ?? 'N/A';
      final lastStatus = _chartData.last['raw_value'] as String? ?? 'N/A';
      final firstZscore = _chartData.first['zscore'] as double? ?? 0.0;
      final lastZscore = _chartData.last['zscore'] as double? ?? 0.0;

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getHFAIcon(lastStatus),
                  size: 16,
                  color: _getHFAStatusColor(lastStatus),
                ),
                const SizedBox(width: 8),
                Text(
                  'HFA Progression',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'Start',
                  firstStatus,
                  _chartData.first['formatted_date'],
                  isHFA: true,
                ),
                Icon(Icons.arrow_forward, size: 16, color: Colors.grey[700]),
                _buildSummaryItem(
                  'Current',
                  lastStatus,
                  _chartData.last['formatted_date'],
                  isHFA: true,
                ),
              ],
            ),
            if (firstZscore != 0.0 || lastZscore != 0.0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Z-score: ${firstZscore.toStringAsFixed(2)} → ${lastZscore.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ),
          ],
        ),
      );
    }

    final change = lastValue - firstValue;
    final changePercent = firstValue > 0 ? (change / firstValue * 100) : 0;

    final startDate = _formatDateForSummary(_chartData.first['date']);
    final endDate = _formatDateForSummary(_chartData.last['date']);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _getChartColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getChartColor().withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                change >= 0 ? Icons.trending_up : Icons.trending_down,
                color: change >= 0 ? Colors.green[700] : Colors.red[700],
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Growth Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getChartColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'Start',
                '${firstValue.toStringAsFixed(1)}',
                startDate,
              ),
              _buildSummaryItem(
                'Current',
                '${lastValue.toStringAsFixed(1)}',
                endDate,
              ),
              _buildSummaryItem(
                'Change',
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                '${changePercent.toStringAsFixed(1)}%',
                highlight: change != 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    String subValue, {
    bool highlight = false,
    bool isHFA = false,
  }) {
    Color valueColor = isHFA
        ? _getHFAStatusColor(value)
        : (highlight
            ? (value.startsWith('+') ? Colors.green[700]! : Colors.red[700]!)
            : _getChartColor());

    return SizedBox(
      width: 70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            subValue,
            style: TextStyle(fontSize: 8, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue[700]),
          const SizedBox(height: 8),
          Text(
            'Loading ${widget.metricType} data...',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 32, color: Colors.red[700]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh, size: 12, color: Colors.white),
            label: const Text(
              'Retry',
              style: TextStyle(fontSize: 11, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 32, color: Colors.grey[500]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.studentName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getChartTitle() {
    switch (widget.metricType) {
      case 'weight':
        return 'Weight Progress (kg)';
      case 'height':
        return 'Height Progress (cm)';
      case 'bmi':
        return 'BMI Progression';
      case 'hfa':
        return 'Height-for-Age (HFA) Status';
      default:
        return 'Growth Progress';
    }
  }

  String _getUnit() {
    switch (widget.metricType) {
      case 'weight':
        return 'kg';
      case 'height':
        return 'cm';
      case 'bmi':
        return 'BMI';
      case 'hfa':
        return '';
      default:
        return '';
    }
  }

  Color _getChartColor() {
    switch (widget.metricType) {
      case 'weight':
        return Colors.blue[700]!;
      case 'height':
        return Colors.green[700]!;
      case 'bmi':
        return Colors.purple[700]!;
      case 'hfa':
        return Colors.orange[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Color _getHFAStatusColor(String hfaStatus) {
    final lowerStatus = hfaStatus.toLowerCase();
    if (lowerStatus.contains('normal')) return Colors.green[700]!;
    if (lowerStatus.contains('stunted')) {
      return lowerStatus.contains('severely')
          ? Colors.red[700]!
          : Colors.orange[700]!;
    }
    if (lowerStatus.contains('tall')) return Colors.blue[700]!;
    return Colors.grey[700]!;
  }

  IconData _getHFAIcon(String hfaStatus) {
    final lowerStatus = hfaStatus.toLowerCase();
    if (lowerStatus.contains('normal')) return Icons.check_circle;
    if (lowerStatus.contains('stunted')) return Icons.arrow_downward;
    if (lowerStatus.contains('tall')) return Icons.arrow_upward;
    return Icons.help;
  }

  String _getMetricField() {
    switch (widget.metricType) {
      case 'weight':
        return 'weight_kg';
      case 'height':
        return 'height_cm';
      case 'bmi':
        return 'bmi';
      default:
        return 'bmi';
    }
  }

  double _getYInterval() {
    if (_chartData.isEmpty) return 10;

    final values = _chartData.map((d) => d['value'] as num).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minValue = values.reduce((a, b) => a < b ? a : b).toDouble();
    final range = maxValue - minValue;

    if (range <= 5) return 1;
    if (range <= 10) return 2;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    return 20;
  }

  double _getMinY() {
    if (_chartData.isEmpty) return 0;
    final values = _chartData.map((d) => d['value'] as num).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b).toDouble();
    return minValue * 0.9;
  }

  double _getMaxY() {
    if (_chartData.isEmpty) return 100;
    final values = _chartData.map((d) => d['value'] as num).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
    return maxValue * 1.1;
  }

  String _formatDateForChart(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatDateShort(String dateString, int index) {
    try {
      final date = DateTime.parse(dateString);
      if (_chartData.length > 12) {
        return '${date.month}';
      }
      return '${date.month}/${date.year.toString().substring(2)}';
    } catch (e) {
      return '${index + 1}';
    }
  }

  String _formatDateForSummary(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
