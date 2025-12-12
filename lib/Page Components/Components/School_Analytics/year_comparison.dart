// year_comparison.dart - REMOVED YEAR SELECTION HEADER
import 'package:district_dev/Page%20Components/Components/School_Analytics/nutri_barchart.dart';
import 'package:district_dev/Page%20Components/Components/School_Analytics/nutri_linechart.dart';
import 'package:district_dev/Services/Database/database_service.dart';
import 'package:flutter/material.dart';

class YearComparisonPage extends StatefulWidget {
  final String schoolId;
  final List<String> availableYears;
  final String schoolName;
  final int schoolPopulation;
  final List<String> selectedYears; // Add this parameter

  const YearComparisonPage({
    super.key,
    required this.schoolId,
    required this.availableYears,
    required this.schoolName,
    required this.schoolPopulation,
    required this.selectedYears, // Add this
  });

  @override
  State<YearComparisonPage> createState() => _YearComparisonPageState();
}

class _YearComparisonPageState extends State<YearComparisonPage> {
  // State
  bool _isLoading = false;
  List<String> _selectedYears = [];

  // Data
  List<Map<String, dynamic>> _barChartData = [];
  List<Map<String, dynamic>> _lineChartData = [];
  List<Map<String, dynamic>> _detailedComparison = [];

  final DatabaseService _dbService = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _selectedYears = widget.selectedYears; // Use the passed selected years
    _loadAllData();
  }

  @override
  void didUpdateWidget(YearComparisonPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data if selected years changed
    if (widget.selectedYears != _selectedYears) {
      setState(() {
        _selectedYears = widget.selectedYears;
      });
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    if (_selectedYears.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadBarChartData(),
        _loadLineChartData(),
        _loadDetailedComparison(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
      _showErrorSnackBar('Failed to load comparison data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBarChartData() async {
    try {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> allData = [];

      // IMPORTANT: Sort years in chronological order for processing
      final sortedYears = List<String>.from(_selectedYears)
        ..sort((a, b) {
          try {
            final aStart = int.tryParse(a.split('-').first) ?? 0;
            final bStart = int.tryParse(b.split('-').first) ?? 0;
            return aStart.compareTo(bStart);
          } catch (e) {
            return a.compareTo(b);
          }
        });

      for (final year in sortedYears) {
        final baselineData = await db.rawQuery(
          '''
          SELECT 
            ? as academic_year,
            'Baseline' as period,
            COUNT(*) as total_students,
            ROUND(AVG(bmi), 2) as avg_bmi,
            ROUND(AVG(height_cm), 2) as avg_height,
            ROUND(AVG(weight_kg), 2) as avg_weight,
            COUNT(CASE WHEN nutritional_status LIKE '%stunted%' THEN 1 END) as hfa_at_risk,
            COUNT(CASE WHEN nutritional_status LIKE '%wasted%' OR nutritional_status LIKE '%underweight%' OR nutritional_status LIKE '%severely_wasted%' THEN 1 END) as bmi_at_risk,
            COUNT(CASE WHEN nutritional_status LIKE '%stunted%' OR nutritional_status LIKE '%wasted%' OR nutritional_status LIKE '%underweight%' OR nutritional_status LIKE '%severely_wasted%' THEN 1 ELSE 0 END) as total_at_risk
          FROM baseline_learners bl
          LEFT JOIN baseline_assessments ba ON bl.id = ba.learner_id
          WHERE bl.school_id = ? AND bl.academic_year = ?
            AND (bmi IS NOT NULL OR height_cm IS NOT NULL OR weight_kg IS NOT NULL)
        ''',
          [year, widget.schoolId, year],
        );

        final endlineData = await db.rawQuery(
          '''
          SELECT 
            ? as academic_year,
            'Endline' as period,
            COUNT(*) as total_students,
            ROUND(AVG(bmi), 2) as avg_bmi,
            ROUND(AVG(height_cm), 2) as avg_height,
            ROUND(AVG(weight_kg), 2) as avg_weight,
            COUNT(CASE WHEN nutritional_status LIKE '%stunted%' THEN 1 END) as hfa_at_risk,
            COUNT(CASE WHEN nutritional_status LIKE '%wasted%' OR nutritional_status LIKE '%underweight%' OR nutritional_status LIKE '%severely_wasted%' THEN 1 END) as bmi_at_risk,
            COUNT(CASE WHEN nutritional_status LIKE '%stunted%' OR nutritional_status LIKE '%wasted%' OR nutritional_status LIKE '%underweight%' OR nutritional_status LIKE '%severely_wasted%' THEN 1 ELSE 0 END) as total_at_risk
          FROM endline_learners el
          LEFT JOIN endline_assessments ea ON el.id = ea.learner_id
          WHERE el.school_id = ? AND el.academic_year = ?
            AND (bmi IS NOT NULL OR height_cm IS NOT NULL OR weight_kg IS NOT NULL)
        ''',
          [year, widget.schoolId, year],
        );

        allData.addAll(baselineData);
        allData.addAll(endlineData);
      }

      _barChartData = allData;
    } catch (e) {
      debugPrint('Error loading bar chart data: $e');
      _barChartData = [];
    }
  }

  Future<void> _loadLineChartData() async {
    try {
      final db = await _dbService.database;

      // Get nutritional status data for all selected years
      final baselineData = await db.rawQuery(
        '''
        SELECT 
          bl.academic_year,
          'Baseline' as period,
          nutritional_status,
          COUNT(*) as count
        FROM baseline_learners bl
        LEFT JOIN baseline_assessments ba ON bl.id = ba.learner_id
        WHERE bl.school_id = ? 
          AND bl.academic_year IN (${_selectedYears.map((_) => '?').join(',')})
          AND nutritional_status IS NOT NULL
        GROUP BY bl.academic_year, nutritional_status
        ORDER BY bl.academic_year
      ''',
        [widget.schoolId, ..._selectedYears],
      );

      final endlineData = await db.rawQuery(
        '''
        SELECT 
          el.academic_year,
          'Endline' as period,
          nutritional_status,
          COUNT(*) as count
        FROM endline_learners el
        LEFT JOIN endline_assessments ea ON el.id = ea.learner_id
        WHERE el.school_id = ? 
          AND el.academic_year IN (${_selectedYears.map((_) => '?').join(',')})
          AND nutritional_status IS NOT NULL
        GROUP BY el.academic_year, nutritional_status
        ORDER BY el.academic_year
      ''',
        [widget.schoolId, ..._selectedYears],
      );

      // Combine and format data
      final combinedData = [...baselineData, ...endlineData];

      _lineChartData = combinedData.map((data) {
        return {
          'assessment_date': data['academic_year']?.toString() ?? '',
          'nutritional_status':
              data['nutritional_status']?.toString() ?? 'Unknown',
          'count': (data['count'] as int?) ?? 0,
          'period': data['period']?.toString() ?? '',
        };
      }).toList();

      // Sort by academic year (ascending)
      _lineChartData.sort((a, b) {
        final aYear = a['assessment_date']?.toString() ?? '';
        final bYear = b['assessment_date']?.toString() ?? '';
        return aYear.compareTo(bYear);
      });
    } catch (e) {
      debugPrint('Error loading line chart data: $e');
      _lineChartData = [];
    }
  }

  Future<void> _loadDetailedComparison() async {
    try {
      final db = await _dbService.database;

      final baselineData = await db.rawQuery(
        '''
        SELECT 
          bl.academic_year,
          'Baseline' as period,
          ? as school,
          COUNT(*) as total_students,
          ROUND(AVG(ba.bmi), 2) as avg_bmi,
          ROUND(AVG(ba.height_cm), 2) as avg_height,
          ROUND(AVG(ba.weight_kg), 2) as avg_weight,
          COUNT(CASE WHEN ba.nutritional_status = 'Normal' THEN 1 END) as normal_count,
          COUNT(CASE WHEN ba.nutritional_status != 'Normal' THEN 1 END) as at_risk_count,
          COUNT(CASE WHEN ba.nutritional_status LIKE '%stunted%' THEN 1 END) as hfa_at_risk,
          COUNT(CASE WHEN ba.nutritional_status LIKE '%wasted%' OR ba.nutritional_status LIKE '%underweight%' OR ba.nutritional_status LIKE '%severely_wasted%' THEN 1 END) as bmi_at_risk,
          0.0 as improvement_rate
        FROM baseline_learners bl
        LEFT JOIN baseline_assessments ba ON bl.id = ba.learner_id
        WHERE bl.school_id = ? AND bl.academic_year IN (${_selectedYears.map((_) => '?').join(',')})
          AND (ba.bmi IS NOT NULL OR ba.height_cm IS NOT NULL OR ba.weight_kg IS NOT NULL)
        GROUP BY bl.academic_year
        ORDER BY bl.academic_year
      ''',
        [widget.schoolName, widget.schoolId, ..._selectedYears],
      );

      final endlineData = await db.rawQuery(
        '''
        SELECT 
          el.academic_year,
          'Endline' as period,
          ? as school,
          COUNT(*) as total_students,
          ROUND(AVG(ea.bmi), 2) as avg_bmi,
          ROUND(AVG(ea.height_cm), 2) as avg_height,
          ROUND(AVG(ea.weight_kg), 2) as avg_weight,
          COUNT(CASE WHEN ea.nutritional_status = 'Normal' THEN 1 END) as normal_count,
          COUNT(CASE WHEN ea.nutritional_status != 'Normal' THEN 1 END) as at_risk_count,
          COUNT(CASE WHEN ea.nutritional_status LIKE '%stunted%' THEN 1 END) as hfa_at_risk,
          COUNT(CASE WHEN ea.nutritional_status LIKE '%wasted%' OR ea.nutritional_status LIKE '%underweight%' OR ea.nutritional_status LIKE '%severely_wasted%' THEN 1 END) as bmi_at_risk,
          0.0 as improvement_rate
        FROM endline_learners el
        LEFT JOIN endline_assessments ea ON el.id = ea.learner_id
        WHERE el.school_id = ? AND el.academic_year IN (${_selectedYears.map((_) => '?').join(',')})
          AND (ea.bmi IS NOT NULL OR ea.height_cm IS NOT NULL OR ea.weight_kg IS NOT NULL)
        GROUP BY el.academic_year
        ORDER BY el.academic_year
      ''',
        [widget.schoolName, widget.schoolId, ..._selectedYears],
      );

      final combinedData = [...baselineData, ...endlineData];

      // Calculate improvement rates
      _detailedComparison = _calculateImprovementRates(combinedData);

      // Sort by year (ascending) and period (Baseline first)
      _detailedComparison.sort((a, b) {
        final yearA = a['academic_year'].toString();
        final yearB = b['academic_year'].toString();
        final periodA = a['period'].toString();
        final periodB = b['period'].toString();

        if (yearA != yearB) {
          return yearA.compareTo(yearB); // Ascending
        }
        return periodA == 'Baseline' ? -1 : 1;
      });
    } catch (e) {
      debugPrint('Error loading detailed comparison: $e');
      _detailedComparison = await _generateFallbackData();
    }
  }

  List<Map<String, dynamic>> _calculateImprovementRates(
    List<Map<String, dynamic>> data,
  ) {
    final Map<String, Map<String, dynamic>> yearData = {};

    for (final item in data) {
      final year = item['academic_year'].toString();
      final period = item['period'].toString();

      if (!yearData.containsKey(year)) {
        yearData[year] = {'Baseline': null, 'Endline': null};
      }

      yearData[year]![period] = item;
    }

    final List<Map<String, dynamic>> result = [];

    for (final year in yearData.keys) {
      final baseline = yearData[year]!['Baseline'];
      final endline = yearData[year]!['Endline'];

      if (baseline != null) {
        result.add(baseline);
      }

      if (endline != null && baseline != null) {
        final baselineAtRisk = baseline['at_risk_count'] as int? ?? 0;
        final endlineAtRisk = endline['at_risk_count'] as int? ?? 0;
        final baselineTotal = baseline['total_students'] as int? ?? 0;

        double improvementRate = 0.0;
        if (baselineAtRisk > 0 && baselineTotal > 0) {
          final reduction = baselineAtRisk - endlineAtRisk;
          improvementRate = (reduction / baselineAtRisk * 100);
        }

        final updatedEndline = Map<String, dynamic>.from(endline);
        updatedEndline['improvement_rate'] = improvementRate.toStringAsFixed(1);
        result.add(updatedEndline);
      } else if (endline != null) {
        result.add(endline);
      }
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> _generateFallbackData() async {
    final fallbackData = <Map<String, dynamic>>[];

    for (final year in _selectedYears) {
      for (final period in ['Baseline', 'Endline']) {
        fallbackData.add({
          'academic_year': year,
          'period': period,
          'school': widget.schoolName,
          'total_students': 0,
          'avg_bmi': 0.0,
          'avg_height': 0.0,
          'avg_weight': 0.0,
          'normal_count': 0,
          'at_risk_count': 0,
          'hfa_at_risk': 0,
          'bmi_at_risk': 0,
          'improvement_rate': '0.0',
        });
      }
    }

    return fallbackData;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Bar Chart and Detailed Comparison
          _buildTopRow(),
          SizedBox(height: 20),

          // Line Chart - Full width below
          _buildLineChartSection(),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          // Mobile/Tablet layout - stacked
          return Column(
            children: [
              _buildBarChartSection(),
              SizedBox(height: 16),
              _buildDetailedComparisonSection(),
            ],
          );
        } else {
          // Desktop layout - side by side
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildBarChartSection()),
              SizedBox(width: 16),
              Expanded(flex: 2, child: _buildDetailedComparisonSection()),
            ],
          );
        }
      },
    );
  }

  Widget _buildBarChartSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(Icons.bar_chart, color: Color(0xFF1A4D7A), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Student Metrics by Assessment Period',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A4D7A),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Side-by-side comparison of average metrics across different assessment periods',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            SizedBox(height: 20),

            // Chart
            SizedBox(
              height: 380,
              child: _barChartData.isEmpty
                  ? _buildNoChartDataState('Student Metrics')
                  : AverageStudentStatusChart(
                      chartData: _barChartData,
                      isLoading: false,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedComparisonSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        height: 500, // Fixed height with vertical scroll
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Header
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.table_chart,
                        color: Color(0xFF1A4D7A),
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Detailed Metrics Table',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A4D7A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Scroll to view all comparison data',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Scrollable Table Area
            Expanded(
              child: _detailedComparison.isEmpty
                  ? _buildNoDataState()
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _buildComparisonTable(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(Icons.timeline, color: Color(0xFF1A4D7A), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nutritional Status Over Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A4D7A),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Track changes in nutritional status categories. Hover/click on data points for details.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            SizedBox(height: 20),

            // Chart with scroll
            Container(
              constraints: BoxConstraints(maxHeight: 450),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _lineChartData.isEmpty ? 400 : 800,
                  height: 450,
                  child: _lineChartData.isEmpty
                      ? _buildNoChartDataState('Nutritional Status Timeline')
                      : NutritionalStatusLineChart(
                          lineChartData: _lineChartData,
                          isLoading: false,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable() {
    try {
      return DataTable(
        columnSpacing: 16,
        horizontalMargin: 8,
        headingRowHeight: 50,
        dataRowHeight: 50,
        headingTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A4D7A),
        ),
        dataTextStyle: TextStyle(fontSize: 12),
        columns: [
          DataColumn(label: Text('Year'), numeric: false),
          DataColumn(label: Text('Period'), numeric: false),
          DataColumn(label: Text('Students'), numeric: true),
          DataColumn(label: Text('BMI'), numeric: true),
          DataColumn(label: Text('Ht (cm)'), numeric: true),
          DataColumn(label: Text('Wt (kg)'), numeric: true),
          DataColumn(label: Text('Normal'), numeric: true),
          DataColumn(label: Text('At Risk'), numeric: true),
          DataColumn(label: Text('Improv %'), numeric: true),
        ],
        rows: _detailedComparison.map((data) {
          try {
            final year = data['academic_year']?.toString() ?? '';
            final period = data['period']?.toString() ?? '';
            final totalStudents = data['total_students'] as int? ?? 0;
            final avgBMI =
                (data['avg_bmi'] as num?)?.toStringAsFixed(1) ?? '0.0';
            final avgHeight =
                (data['avg_height'] as num?)?.toStringAsFixed(0) ?? '0';
            final avgWeight =
                (data['avg_weight'] as num?)?.toStringAsFixed(0) ?? '0';
            final normalCount = data['normal_count'] as int? ?? 0;
            final atRiskCount = data['at_risk_count'] as int? ?? 0;
            final improvement = (data['improvement_rate']?.toString()) ?? '0.0';

            final isBaseline = period.toLowerCase() == 'baseline';
            final improvementValue = double.tryParse(improvement) ?? 0.0;

            return DataRow(
              cells: [
                DataCell(
                  Text(year, style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                DataCell(
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBaseline ? Colors.blue[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isBaseline ? Colors.blue[100]! : Colors.green[100]!,
                      ),
                    ),
                    child: Text(
                      period,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            isBaseline ? Colors.blue[700] : Colors.green[700],
                      ),
                    ),
                  ),
                ),
                DataCell(Center(child: Text(totalStudents.toString()))),
                DataCell(Center(child: Text(avgBMI))),
                DataCell(Center(child: Text(avgHeight))),
                DataCell(Center(child: Text(avgWeight))),
                DataCell(
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        normalCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: atRiskCount > 0
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        atRiskCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: atRiskCount > 0
                              ? Colors.red[700]
                              : Colors.green[700],
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: improvementValue > 0
                            ? Colors.green.withOpacity(0.1)
                            : improvementValue < 0
                                ? Colors.red.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$improvement%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: improvementValue > 0
                              ? Colors.green[700]
                              : improvementValue < 0
                                  ? Colors.red[700]
                                  : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } catch (e) {
            debugPrint('Error creating table row: $e');
            return DataRow(
              cells: List.generate(9, (index) => DataCell(Text('Error'))),
            );
          }
        }).toList(),
      );
    } catch (e) {
      debugPrint('Error building comparison table: $e');
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Error loading table data'),
        ),
      );
    }
  }

  Widget _buildNoChartDataState(String chartName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
          SizedBox(height: 12),
          Text(
            'No data available for\n$chartName',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.data_usage, size: 48, color: Colors.grey[400]),
          SizedBox(height: 12),
          Text(
            'No comparison data available',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
