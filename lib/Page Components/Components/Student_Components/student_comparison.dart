import 'package:district_dev/Page%20Components/Components/School_Analytics/who_standard.dart';
import 'package:district_dev/Services/Database/database_service.dart'
    as db_service;
import 'package:flutter/material.dart';

class BaselineEndlineComparison extends StatefulWidget {
  final String studentId;
  final String studentName;
  final List assessments;

  const BaselineEndlineComparison({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.assessments,
  });

  @override
  State<BaselineEndlineComparison> createState() =>
      _BaselineEndlineComparisonState();
}

class _BaselineEndlineComparisonState extends State<BaselineEndlineComparison> {
  List<Map<String, dynamic>> _comparisonData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final db_service.DatabaseService _dbService =
      db_service.DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _loadComparisonData();
  }

  Future<void> _loadComparisonData() async {
    try {
      debugPrint('🔍 Loading comparison data for student: ${widget.studentId}');

      final db = await _dbService.database;

      // Get all assessment data for the student
      final sql = '''
      SELECT 
        'Baseline' as period,
        bl.academic_year,
        ba.assessment_date,
        ba.weight_kg,
        ba.height_cm,
        ba.bmi,
        ba.nutritional_status,
        bl.grade_level,
        bl.age,
        bl.sex
      FROM baseline_learners bl
      LEFT JOIN baseline_assessments ba ON bl.id = ba.learner_id
      WHERE bl.student_id = ? 
      AND (ba.weight_kg IS NOT NULL OR ba.height_cm IS NOT NULL OR ba.bmi IS NOT NULL)
      
      UNION ALL
      
      SELECT 
        'Endline' as period,
        el.academic_year,
        ea.assessment_date,
        ea.weight_kg,
        ea.height_cm,
        ea.bmi,
        ea.nutritional_status,
        el.grade_level,
        el.age,
        el.sex
      FROM endline_learners el
      LEFT JOIN endline_assessments ea ON el.id = ea.learner_id
      WHERE el.student_id = ? 
      AND (ea.weight_kg IS NOT NULL OR ea.height_cm IS NOT NULL OR ea.bmi IS NOT NULL)
      
      ORDER BY academic_year, period
      ''';

      final results = await db.rawQuery(sql, [
        widget.studentId,
        widget.studentId,
      ]);

      debugPrint('📊 Raw comparison results: ${results.length} records');

      if (results.isEmpty) {
        debugPrint('⚠️ No comparison data found');
        setState(() {
          _errorMessage =
              'No assessment data available for ${widget.studentName}';
          _isLoading = false;
        });
        return;
      }

      // Group by academic year
      final groupedData = <String, Map<String, dynamic>>{};

      for (final record in results) {
        final academicYear = record['academic_year'] as String? ?? 'Unknown';
        final period = record['period'] as String? ?? 'Unknown';

        if (!groupedData.containsKey(academicYear)) {
          groupedData[academicYear] = {
            'academic_year': academicYear,
            'baseline_date': null,
            'endline_date': null,
            'baseline_weight': null,
            'endline_weight': null,
            'baseline_height': null,
            'endline_height': null,
            'baseline_bmi': null,
            'endline_bmi': null,
            'baseline_status': null,
            'endline_status': null,
            'baseline_grade': null,
            'endline_grade': null,
            'baseline_age': null,
            'endline_age': null,
            'baseline_sex': null,
            'endline_sex': null,
            'has_baseline': false,
            'has_endline': false,
          };
        }

        final yearData = groupedData[academicYear]!;

        if (period == 'Baseline') {
          yearData['baseline_date'] = record['assessment_date'];
          yearData['baseline_weight'] = record['weight_kg'];
          yearData['baseline_height'] = record['height_cm'];
          yearData['baseline_bmi'] = record['bmi'];
          yearData['baseline_status'] = record['nutritional_status'];
          yearData['baseline_grade'] = record['grade_level'];
          yearData['baseline_age'] = record['age'];
          yearData['baseline_sex'] = record['sex'];
          yearData['has_baseline'] = true;
        } else if (period == 'Endline') {
          yearData['endline_date'] = record['assessment_date'];
          yearData['endline_weight'] = record['weight_kg'];
          yearData['endline_height'] = record['height_cm'];
          yearData['endline_bmi'] = record['bmi'];
          yearData['endline_status'] = record['nutritional_status'];
          yearData['endline_grade'] = record['grade_level'];
          yearData['endline_age'] = record['age'];
          yearData['endline_sex'] = record['sex'];
          yearData['has_endline'] = true;
        }
      }

      // Convert to list and calculate has_both
      final comparisonList = groupedData.values.map((yearData) {
        final hasBaseline = yearData['has_baseline'] == true;
        final hasEndline = yearData['has_endline'] == true;

        return {...yearData, 'has_both': hasBaseline && hasEndline ? 1 : 0};
      }).toList();

      // Sort by academic year (newest first)
      comparisonList.sort((a, b) {
        final yearA = a['academic_year'] as String;
        final yearB = b['academic_year'] as String;
        return yearB.compareTo(yearA);
      });

      setState(() {
        _comparisonData = comparisonList;
        _isLoading = false;
      });

      debugPrint(
        '✅ Comparison loaded: ${_comparisonData.length} academic years',
      );
      for (final year in _comparisonData) {
        debugPrint(
          '📅 ${year['academic_year']}: Baseline=${year['has_baseline']}, Endline=${year['has_endline']}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading comparison data: $e');
      setState(() {
        _errorMessage = 'Error loading comparison data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    await _loadComparisonData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Baseline & Endline Comparison',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: 18, color: Colors.blue[700]),
              onPressed: _refreshData,
              tooltip: 'Refresh Comparison',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Data Summary
        _buildDataSummary(),
        const SizedBox(height: 16),

        // Main Content
        if (_isLoading) _buildLoadingState(),
        if (!_isLoading && _errorMessage.isNotEmpty)
          _buildErrorState(_errorMessage),
        if (!_isLoading && _comparisonData.isEmpty) _buildEmptyState(),
        if (!_isLoading && _comparisonData.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _comparisonData
                    .map((yearData) => _buildYearComparison(yearData))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDataSummary() {
    final totalYears = _comparisonData.length;
    final yearsWithBoth =
        _comparisonData.where((data) => data['has_both'] == 1).length;
    final yearsWithBaselineOnly = _comparisonData
        .where(
          (data) =>
              data['has_baseline'] == true && data['has_endline'] == false,
        )
        .length;
    final yearsWithEndlineOnly = _comparisonData
        .where(
          (data) =>
              data['has_baseline'] == false && data['has_endline'] == true,
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Years', totalYears.toString()),
          _buildSummaryItem(
            'Complete Pairs',
            yearsWithBoth.toString(),
            highlight: yearsWithBoth > 0,
          ),
          _buildSummaryItem('Baseline Only', yearsWithBaselineOnly.toString()),
          _buildSummaryItem('Endline Only', yearsWithEndlineOnly.toString()),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.green[700] : Colors.blue[700],
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is num) return value.toStringAsFixed(1);
    if (value is String) return value;
    return value.toString();
  }

  String _calculateChange(dynamic baseline, dynamic endline) {
    if (baseline == null || endline == null) return 'N/A';

    final baseNum = baseline is num
        ? baseline.toDouble()
        : double.tryParse(baseline.toString());
    final endNum = endline is num
        ? endline.toDouble()
        : double.tryParse(endline.toString());

    if (baseNum == null || endNum == null) return 'N/A';

    final change = endNum - baseNum;
    return '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}';
  }

  Widget _buildYearComparison(Map<String, dynamic> yearData) {
    final year = yearData['academic_year'] as String? ?? 'Unknown';
    final hasBoth = yearData['has_both'] == 1;
    final baselineDate = _formatDate(yearData['baseline_date']);
    final endlineDate = _formatDate(yearData['endline_date']);

    // Clean grade values
    String baselineGrade = yearData['baseline_grade'] as String? ?? 'N/A';
    String endlineGrade = yearData['endline_grade'] as String? ?? 'N/A';

    if (baselineGrade.toLowerCase().contains('grade')) {
      baselineGrade =
          baselineGrade.replaceAll('Grade', '').replaceAll('grade', '').trim();
      if (baselineGrade.isEmpty) {
        baselineGrade = yearData['baseline_grade'] as String? ?? 'N/A';
      }
    }

    if (endlineGrade.toLowerCase().contains('grade')) {
      endlineGrade =
          endlineGrade.replaceAll('Grade', '').replaceAll('grade', '').trim();
      if (endlineGrade.isEmpty) {
        endlineGrade = yearData['endline_grade'] as String? ?? 'N/A';
      }
    }

    final baselineAge = yearData['baseline_age'];
    final endlineAge = yearData['endline_age'];
    final baselineSex = yearData['baseline_sex'] as String? ?? 'Unknown';
    final endlineSex = yearData['endline_sex'] as String? ?? 'Unknown';

    // Calculate HFA from height data if available
    String baselineHFA = 'No Data';
    String endlineHFA = 'No Data';

    final baselineHeight = yearData['baseline_height'] as num? ?? 0;
    final endlineHeight = yearData['endline_height'] as num? ?? 0;
    final baselineAgeNum = baselineAge is int
        ? baselineAge
        : (baselineAge is num ? baselineAge.toInt() : 0);
    final endlineAgeNum = endlineAge is int
        ? endlineAge
        : (endlineAge is num ? endlineAge.toInt() : 0);

    if (baselineHeight > 0 && baselineAgeNum >= 5) {
      final hfaResult = WHOStandardsService.calculateHFA(
        baselineHeight.toDouble(),
        baselineAgeNum,
        baselineSex,
      );
      baselineHFA = hfaResult['status'] as String? ?? 'No Data';
    }

    if (endlineHeight > 0 && endlineAgeNum >= 5) {
      final hfaResult = WHOStandardsService.calculateHFA(
        endlineHeight.toDouble(),
        endlineAgeNum,
        endlineSex,
      );
      endlineHFA = hfaResult['status'] as String? ?? 'No Data';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasBoth ? Colors.green[700]! : Colors.orange[700]!,
          width: hasBoth ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
        color: hasBoth ? Colors.green[50] : Colors.orange[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Academic Year: $year',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: hasBoth ? Colors.green[700] : Colors.orange[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasBoth)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Complete Pair',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Incomplete Data',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Grade and Age Information
          if (baselineGrade != 'N/A' ||
              endlineGrade != 'N/A' ||
              baselineAge != null ||
              endlineAge != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (baselineGrade != 'N/A' && endlineGrade != 'N/A')
                    Text(
                      'Grade: $baselineGrade → $endlineGrade',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  if (baselineAge != null && endlineAge != null)
                    Text(
                      'Age: $baselineAge → $endlineAge years',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),

          // HFA Status
          if (baselineHFA != 'No Data' || endlineHFA != 'No Data')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Text(
                    'HFA: ',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getHFAStatusColor(baselineHFA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getHFAStatusColor(baselineHFA),
                      ),
                    ),
                    child: Text(
                      baselineHFA,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _getHFAStatusColor(baselineHFA),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: Colors.grey,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getHFAStatusColor(endlineHFA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getHFAStatusColor(endlineHFA)),
                    ),
                    child: Text(
                      endlineHFA,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _getHFAStatusColor(endlineHFA),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Comparison Table
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Metric',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Baseline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 18, 97, 177),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Endline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 56, 150, 61),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Change',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // Date Row
                _buildComparisonRow(
                  'Date',
                  baselineDate,
                  endlineDate,
                  hasBoth ? '✓' : '⚠',
                  false,
                ),

                // Weight Row
                _buildComparisonRow(
                  'Weight (kg)',
                  _getValue(yearData['baseline_weight']),
                  _getValue(yearData['endline_weight']),
                  hasBoth
                      ? _calculateChange(
                          yearData['baseline_weight'],
                          yearData['endline_weight'],
                        )
                      : 'N/A',
                  false,
                ),

                // Height Row
                _buildComparisonRow(
                  'Height (cm)',
                  _getValue(yearData['baseline_height']),
                  _getValue(yearData['endline_height']),
                  hasBoth
                      ? _calculateChange(
                          yearData['baseline_height'],
                          yearData['endline_height'],
                        )
                      : 'N/A',
                  false,
                ),

                // BMI Row
                _buildComparisonRow(
                  'BMI',
                  _getValue(yearData['baseline_bmi']),
                  _getValue(yearData['endline_bmi']),
                  hasBoth
                      ? _calculateChange(
                          yearData['baseline_bmi'],
                          yearData['endline_bmi'],
                        )
                      : 'N/A',
                  false,
                ),

                // Status Row
                _buildComparisonRow(
                  'Status',
                  yearData['baseline_status']?.toString() ?? 'N/A',
                  yearData['endline_status']?.toString() ?? 'N/A',
                  hasBoth
                      ? _getStatusChange(
                          yearData['baseline_status']?.toString(),
                          yearData['endline_status']?.toString(),
                        )
                      : 'N/A',
                  false,
                ),
              ],
            ),
          ),

          // Warning for incomplete data
          if (!hasBoth) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      yearData['has_baseline'] == true
                          ? '⚠️ Missing Endline assessment for this academic year'
                          : '⚠️ Missing Baseline assessment for this academic year',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String metric,
    String baseline,
    String endline,
    String change,
    bool isHeader,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: !isHeader
            ? const Border(bottom: BorderSide(color: Colors.grey, width: 0.5))
            : null,
        color: isHeader ? Colors.grey[100] : Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              metric,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? Colors.black87 : Colors.black87,
                fontSize: isHeader ? 13 : 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              baseline,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: _getValueColor(baseline, isHeader),
                fontSize: isHeader ? 13 : 12,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              endline,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: _getValueColor(endline, isHeader),
                fontSize: isHeader ? 13 : 12,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: _getChangeBackgroundColor(change),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getChangeColor(change, isHeader).withOpacity(0.3),
                ),
              ),
              child: Text(
                change,
                style: TextStyle(
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
                  color: _getChangeColor(change, isHeader),
                  fontSize: isHeader ? 12 : 11,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getValueColor(String value, bool isHeader) {
    if (isHeader) return Colors.black87;
    if (value == 'N/A' || value == 'Unknown' || value == 'No Data') {
      return Colors.grey[700]!;
    }
    return Colors.black87;
  }

  String _getStatusChange(String? baseline, String? endline) {
    if (baseline == null ||
        endline == null ||
        baseline == 'N/A' ||
        endline == 'N/A') {
      return 'N/A';
    }
    if (baseline == endline) return 'No Δ';

    final improvedStatuses = ['Normal', 'Improved'];
    final worsenedStatuses = [
      'Severely Wasted',
      'Wasted',
      'Overweight',
      'Obese',
    ];

    if (improvedStatuses.contains(endline) &&
        worsenedStatuses.contains(baseline)) {
      return '↑';
    } else if (worsenedStatuses.contains(endline) &&
        improvedStatuses.contains(baseline)) {
      return '↓';
    }

    return '↔';
  }

  Color _getChangeColor(String change, bool isHeader) {
    if (isHeader) return Colors.black87;
    if (change == 'N/A' || change == 'Unknown') return Colors.grey[700]!;
    if (change == '↑') return Colors.green[700]!;
    if (change == '↓') return Colors.red[700]!;
    if (change == '↔') return Colors.purple[700]!;
    if (change.startsWith('+')) return Colors.green[700]!;
    if (change.startsWith('-')) return Colors.red[700]!;
    if (change == 'No Δ') return Colors.blue[700]!;
    return Colors.grey[700]!;
  }

  Color _getChangeBackgroundColor(String change) {
    if (change == 'N/A' || change == 'Unknown') return Colors.transparent;
    if (change == '↑') return Colors.green.withOpacity(0.1);
    if (change == '↓') return Colors.red.withOpacity(0.1);
    if (change == '↔') return Colors.purple.withOpacity(0.1);
    if (change.startsWith('+')) return Colors.green.withOpacity(0.1);
    if (change.startsWith('-')) return Colors.red.withOpacity(0.1);
    if (change == 'No Δ') return Colors.blue.withOpacity(0.1);
    return Colors.transparent;
  }

  Color _getHFAStatusColor(String hfaStatus) {
    switch (hfaStatus.toLowerCase()) {
      case 'normal':
        return Colors.green[700]!;
      case 'stunted':
        return Colors.orange[700]!;
      case 'severely stunted':
        return Colors.red[700]!;
      case 'tall':
        return Colors.blue[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading comparison data...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 16),
            Text(
              'No comparison data available',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.studentName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
