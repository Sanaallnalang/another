import 'package:district_dev/Page%20Components/Components/School_Analytics/who_standard.dart';
import 'package:district_dev/Services/Database/database_service.dart'
    as db_service;
import 'package:flutter/material.dart';

class StatusTimelineChart extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StatusTimelineChart({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StatusTimelineChart> createState() => _StatusTimelineChartState();
}

class _StatusTimelineChartState extends State<StatusTimelineChart> {
  List<Map<String, dynamic>> _timelineData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  List<String> _availableSchoolYears = [];

  final db_service.DatabaseService _dbService =
      db_service.DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _loadTimelineData();
  }

  Future<void> _loadTimelineData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load student details first
      await _loadStudentDetails();

      // Load available school years
      await _loadAvailableSchoolYears();

      // Load timeline data
      final sql = '''
      SELECT 
        assessment_date,
        period,
        nutritional_status,
        academic_year,
        weight_kg,
        height_cm,
        bmi,
        grade_level,
        age,
        sex
      FROM (
        -- Baseline assessments
        SELECT 
          ba.assessment_date,
          'Baseline' as period,
          ba.nutritional_status,
          bl.academic_year,
          ba.weight_kg,
          ba.height_cm,
          ba.bmi,
          bl.grade_level,
          bl.age,
          bl.sex
        FROM baseline_learners bl
        JOIN baseline_assessments ba ON bl.id = ba.learner_id
        WHERE bl.student_id = ?
        
        UNION ALL
        
        -- Endline assessments
        SELECT 
          ea.assessment_date,
          'Endline' as period,
          ea.nutritional_status,
          el.academic_year,
          ea.weight_kg,
          ea.height_cm,
          ea.bmi,
          el.grade_level,
          el.age,
          el.sex
        FROM endline_learners el
        JOIN endline_assessments ea ON el.id = ea.learner_id
        WHERE el.student_id = ?
      )
      WHERE weight_kg IS NOT NULL AND height_cm IS NOT NULL AND age IS NOT NULL
      ORDER BY assessment_date
      ''';

      final db = await _dbService.database;
      final results = await db.rawQuery(sql, [
        widget.studentId,
        widget.studentId,
      ]);

      if (results.isEmpty) {
        setState(() {
          _timelineData = [];
          _isLoading = false;
        });
        return;
      }

      // Process the data with WHO classification
      final processedData = await _prepareTimelineData(results);

      setState(() {
        _timelineData = processedData;
        _isLoading = false;
      });

      debugPrint('📊 Timeline loaded: ${_timelineData.length} records');
    } catch (e) {
      debugPrint('❌ Error loading timeline data: $e');
      setState(() {
        _errorMessage = 'Failed to load timeline data';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentDetails() async {
    try {
      final db = await _dbService.database;

      var result = await db.rawQuery(
        '''
        SELECT 
          learner_name, 
          grade_level, 
          age, 
          sex,
          student_id,
          academic_year
        FROM baseline_learners 
        WHERE student_id = ?
        LIMIT 1
      ''',
        [widget.studentId],
      );

      if (result.isEmpty) {
        result = await db.rawQuery(
          '''
          SELECT 
            learner_name, 
            grade_level, 
            age, 
            sex,
            student_id,
            academic_year
          FROM endline_learners 
          WHERE student_id = ?
          LIMIT 1
        ''',
          [widget.studentId],
        );
      }

      if (result.isNotEmpty) {
        final grade = result.first['grade_level']?.toString() ?? 'Unknown';
        String cleanGrade = grade;
        if (grade.toLowerCase().contains('grade')) {
          cleanGrade =
              grade.replaceAll('Grade', '').replaceAll('grade', '').trim();
          if (cleanGrade.isEmpty) cleanGrade = grade;
        }
      } else {}
    } catch (e) {
      debugPrint('⚠️ Error loading student details: $e');
    }
  }

  Future<void> _loadAvailableSchoolYears() async {
    try {
      final db = await _dbService.database;

      final baselineYears = await db.rawQuery(
        '''
        SELECT DISTINCT academic_year 
        FROM baseline_learners 
        WHERE student_id = ? AND academic_year IS NOT NULL
      ''',
        [widget.studentId],
      );

      final endlineYears = await db.rawQuery(
        '''
        SELECT DISTINCT academic_year 
        FROM endline_learners 
        WHERE student_id = ? AND academic_year IS NOT NULL
      ''',
        [widget.studentId],
      );

      final Set<String> years = {};
      for (var row in baselineYears) {
        if (row['academic_year'] != null) {
          years.add(row['academic_year'].toString());
        }
      }
      for (var row in endlineYears) {
        if (row['academic_year'] != null) {
          years.add(row['academic_year'].toString());
        }
      }

      setState(() {
        _availableSchoolYears = years.toList()..sort((a, b) => b.compareTo(a));
      });
    } catch (e) {
      debugPrint('⚠️ Error loading school years: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _prepareTimelineData(
    List<Map<String, dynamic>> rawData,
  ) async {
    if (rawData.isEmpty) return [];

    // Sort by date
    final sortedData = List<Map<String, dynamic>>.from(rawData);
    sortedData.sort((a, b) {
      final dateAStr = a['assessment_date'] as String? ?? '';
      final dateBStr = b['assessment_date'] as String? ?? '';
      final dateA = DateTime.tryParse(dateAStr) ?? DateTime(1900);
      final dateB = DateTime.tryParse(dateBStr) ?? DateTime(1900);
      return dateA.compareTo(dateB);
    });

    return sortedData.map((assessment) {
      final weight = assessment['weight_kg'] as num? ?? 0;
      final height = assessment['height_cm'] as num? ?? 0;
      final bmi = assessment['bmi'] as num? ?? 0;
      final age = assessment['age'] as int? ?? 0;
      final sex = assessment['sex'] as String? ?? 'Unknown';

      // Calculate WHO nutritional status
      String nutritionalStatus = 'Data Insufficient';
      String hfaStatus = 'No Data';
      String bfaStatus = 'No Data';
      double hfaZscore = 0.0;
      double bfaZscore = 0.0;

      if (height > 0 && age >= 5 && age <= 19) {
        final hfaResult = WHOStandardsService.calculateHFA(
          height.toDouble(),
          age,
          sex,
        );
        hfaStatus = hfaResult['status'] as String? ?? 'No Data';
        hfaZscore = hfaResult['zscore'] as double? ?? 0.0;

        if (bmi > 0) {
          final bfaResult = WHOStandardsService.calculateBMIForAge(
            bmi.toDouble(),
            age,
            sex,
          );
          bfaStatus = bfaResult['status'] as String? ?? 'No Data';
          bfaZscore = bfaResult['zscore'] as double? ?? 0.0;
        }

        nutritionalStatus = _determineWHONutritionalStatus(
          hfaStatus,
          bfaStatus,
        );
      } else if (weight > 0 && height > 0) {
        nutritionalStatus = 'Assessment Required';
      }

      String grade = assessment['grade_level'] as String? ?? 'Unknown';
      if (grade.toLowerCase().contains('grade')) {
        grade = grade.replaceAll('Grade', '').replaceAll('grade', '').trim();
        if (grade.isEmpty) {
          grade = assessment['grade_level'] as String? ?? 'Unknown';
        }
      }

      return {
        'date': assessment['assessment_date'] as String? ?? '',
        'period': assessment['period'] as String? ?? 'Unknown',
        'status': nutritionalStatus,
        'original_status':
            assessment['nutritional_status'] as String? ?? 'Unknown',
        'academic_year': assessment['academic_year'] as String? ?? 'Unknown',
        'hfa': hfaStatus,
        'hfa_zscore': hfaZscore,
        'bfa': bfaStatus,
        'bfa_zscore': bfaZscore,
        'grade': grade,
        'age': age,
        'sex': sex,
        'weight': weight,
        'height': height,
        'bmi': bmi,
        'formatted_date': _formatDisplayDate(
          assessment['assessment_date'] as String? ?? '',
        ),
        'month_year': _formatMonthYear(
          assessment['assessment_date'] as String? ?? '',
        ),
        'has_data': weight > 0 && height > 0,
        'calculated_status': true,
      };
    }).toList();
  }

  String _determineWHONutritionalStatus(String hfaStatus, String bfaStatus) {
    if (bfaStatus == 'Severely Wasted') {
      return 'Severely Wasted';
    } else if (bfaStatus == 'Wasted') {
      return 'Wasted';
    } else if (bfaStatus == 'Obese') {
      return 'Obese';
    } else if (bfaStatus == 'Overweight') {
      return 'Overweight';
    } else if (hfaStatus == 'Severely Stunted') {
      return 'Severely Stunted';
    } else if (hfaStatus == 'Stunted') {
      return 'Stunted';
    } else if (hfaStatus == 'Tall' || hfaStatus == 'Very Tall') {
      return 'Tall for Age';
    } else if (hfaStatus == 'Normal' && bfaStatus == 'Normal') {
      return 'Normal';
    }

    return 'Assessment Required';
  }

  Future<void> _refreshData() async {
    await _loadTimelineData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with School Years
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nutritional Timeline',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (_availableSchoolYears.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 10),
                    Text(
                      'School Years:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ..._availableSchoolYears.map((year) {
                      return Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue[300]!),
                        ),
                        child: Text(
                          year,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        if (_isLoading) _buildLoadingState(),
        if (!_isLoading && _errorMessage.isNotEmpty)
          _buildErrorState(_errorMessage),
        if (!_isLoading && _timelineData.isEmpty)
          _buildEmptyState('No assessment history found'),
        if (!_isLoading && _timelineData.isNotEmpty) ...[
          // Timeline Visualization - ENLARGED
          Container(
            height: 240, // Increased height
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
            ),
            child: _buildTimelineVisualization(),
          ),
          const SizedBox(height: 24),

          // Timeline Data Cards - ENLARGED
          SizedBox(
            height: 240, // Increased height
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _timelineData.length,
              itemBuilder: (context, index) {
                return _buildTimelineCard(_timelineData[index]);
              },
            ),
          ),
          const SizedBox(height: 24),

          // WHO Legend - UPDATED with requested categories
          _buildWHOLegend(),
        ],
      ],
    );
  }

  Widget _buildTimelineVisualization() {
    return Stack(
      children: [
        // Timeline line
        Positioned(
          left: 60, // Increased left/right padding
          right: 60,
          top: 100, // Adjusted for larger layout
          child: Container(
            height: 4, // Thicker line
            color: Colors.blue[400],
          ),
        ),

        // Data points
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _timelineData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final monthYear = data['month_year'] as String;
            final status = data['status'] as String;

            return Column(
              children: [
                // Month-Year (Top)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    monthYear,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Data point
                Container(
                  width: 32, // Larger data point
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getWHOStatusColor(status),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Status (Bottom)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getWHOStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getWHOStatusColor(status),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getWHOStatusColor(status),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> data) {
    final status = data['status'];
    final monthYear = data['month_year'];
    final weight = data['weight'] ?? 0;
    final height = data['height'] ?? 0;
    final bmi = data['bmi'] ?? 0;
    final age = data['age'] ?? 0;
    final hfa = data['hfa'] as String? ?? 'No Data';
    final bfa = data['bfa'] as String? ?? 'No Data';

    return Container(
      width: 240, // Wider cards
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getWHOStatusColor(status),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Status
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _getWHOStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  monthYear,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getWHOStatusColor(status),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Measurements Grid
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildMeasurementCard(
                'Weight',
                '${weight.toStringAsFixed(1)} kg',
                Colors.blue[700]!,
                Icons.monitor_weight,
              ),
              _buildMeasurementCard(
                'Height',
                '${height.toStringAsFixed(1)} cm',
                Colors.green[700]!,
                Icons.height,
              ),
              _buildMeasurementCard(
                'BMI',
                '${bmi.toStringAsFixed(1)}',
                Colors.purple[700]!,
                Icons.calculate,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Age and Indicators
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cake, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Age: $age years',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (hfa != 'No Data')
                Row(
                  children: [
                    Icon(
                      _getHFAIcon(hfa),
                      size: 14,
                      color: _getHFAStatusColor(hfa),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'HFA: $hfa',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getHFAStatusColor(hfa),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              if (bfa != 'No Data')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        _getBFAIcon(bfa),
                        size: 14,
                        color: _getBFAStatusColor(bfa),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'BFA: $bfa',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getBFAStatusColor(bfa),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWHOLegend() {
    final whoCategories = [
      {
        'label': 'Severely Wasted',
        'color': Colors.red[700]!,
        'icon': Icons.warning,
      },
      {
        'label': 'Wasted',
        'color': Colors.orange[700]!,
        'icon': Icons.trending_down,
      },
      {
        'label': 'Normal',
        'color': Colors.green[700]!,
        'icon': Icons.check_circle,
      },
      {
        'label': 'Overweight',
        'color': Colors.blue[700]!,
        'icon': Icons.trending_up,
      },
      {
        'label': 'Obese',
        'color': Colors.purple[700]!,
        'icon': Icons.trending_up,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nutritional Status Legend',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: whoCategories.map((category) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (category['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (category['color'] as Color).withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 18,
                    color: category['color'] as Color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: category['color'] as Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 20),
          Text(
            'Loading timeline data...',
            style: TextStyle(color: Colors.grey[800], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh, size: 18, color: Colors.white),
            label: Text(
              'Retry',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.studentName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Color _getWHOStatusColor(String status) {
    if (status.contains('Severely Wasted') ||
        status.contains('Severely Stunted')) {
      return Colors.red[700]!;
    } else if (status.contains('Wasted') || status.contains('Stunted')) {
      return Colors.orange[700]!;
    } else if (status.contains('Normal')) {
      return Colors.green[700]!;
    } else if (status.contains('Overweight')) {
      return Colors.blue[700]!;
    } else if (status.contains('Obese')) {
      return Colors.purple[700]!;
    } else if (status.contains('Tall for Age')) {
      return Colors.cyan[700]!;
    }
    return Colors.grey[700]!;
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

  Color _getBFAStatusColor(String bfaStatus) {
    final lowerStatus = bfaStatus.toLowerCase();
    if (lowerStatus.contains('normal')) return Colors.green[700]!;
    if (lowerStatus.contains('wasted')) {
      return lowerStatus.contains('severely')
          ? Colors.red[700]!
          : Colors.orange[700]!;
    }
    if (lowerStatus.contains('overweight')) return Colors.blue[700]!;
    if (lowerStatus.contains('obese')) return Colors.purple[700]!;
    return Colors.grey[700]!;
  }

  IconData _getHFAIcon(String hfaStatus) {
    final lowerStatus = hfaStatus.toLowerCase();
    if (lowerStatus.contains('normal')) return Icons.check_circle;
    if (lowerStatus.contains('stunted')) return Icons.arrow_downward;
    if (lowerStatus.contains('tall')) return Icons.arrow_upward;
    return Icons.help;
  }

  IconData _getBFAIcon(String bfaStatus) {
    final lowerStatus = bfaStatus.toLowerCase();
    if (lowerStatus.contains('normal')) return Icons.check_circle;
    if (lowerStatus.contains('wasted')) return Icons.trending_down;
    if (lowerStatus.contains('overweight') || lowerStatus.contains('obese')) {
      return Icons.trending_up;
    }
    return Icons.help;
  }

  String _formatDisplayDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Date unknown';
    }
  }

  String _formatMonthYear(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
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
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
