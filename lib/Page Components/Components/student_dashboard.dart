import 'package:district_dev/Page%20Components/Components/Student_Components/student_comparison.dart';
import 'package:district_dev/Page%20Components/Components/Student_Components/student_linechart.dart';
import 'package:district_dev/Page%20Components/Components/Student_Components/student_timelchart.dart';
import 'package:district_dev/Page%20Components/topbar.dart';
import 'package:district_dev/Services/Database/database_service.dart'
    as db_service;
import 'package:flutter/material.dart';

class StudentHealthHistoryPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String schoolId;

  const StudentHealthHistoryPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.schoolId,
  });

  @override
  State<StudentHealthHistoryPage> createState() =>
      _StudentHealthHistoryPageState();
}

class _StudentHealthHistoryPageState extends State<StudentHealthHistoryPage> {
  Map<String, dynamic> _studentInfo = {};
  bool _isLoading = true;
  String _selectedView = 'timeline';
  List<Map<String, dynamic>> _assessments = [];

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
    _loadAssessments();
  }

  Future<void> _loadStudentInfo() async {
    try {
      final dbService = db_service.DatabaseService.instance;
      final db = await dbService.database;

      // Get student from baseline_learners first
      var baselineResult = await db.rawQuery(
        '''
        SELECT 
          student_id,
          learner_name,
          sex,
          grade_level,
          age,
          academic_year
        FROM baseline_learners 
        WHERE student_id = ?
        LIMIT 1
      ''',
        [widget.studentId],
      );

      Map<String, dynamic>? studentData;
      String period = 'Unknown';
      bool hasEndlineData = false;

      if (baselineResult.isNotEmpty) {
        studentData = baselineResult.first;
        period = 'Baseline';
      }

      // Check for endline data
      final endlineResult = await db.rawQuery(
        '''
        SELECT 
          student_id,
          learner_name,
          sex,
          grade_level,
          age,
          academic_year
        FROM endline_learners 
        WHERE student_id = ?
        LIMIT 1
      ''',
        [widget.studentId],
      );

      if (endlineResult.isNotEmpty) {
        if (studentData == null) {
          studentData = endlineResult.first;
          period = 'Endline';
        }
        hasEndlineData = true;
      }

      // Get nutritional status from the most recent assessment
      String nutritionalStatus = 'Unknown';
      final statusResult = await db.rawQuery(
        '''
        SELECT nutritional_status, assessment_date 
        FROM (
          SELECT ba.nutritional_status, ba.assessment_date
          FROM baseline_learners bl
          JOIN baseline_assessments ba ON bl.id = ba.learner_id
          WHERE bl.student_id = ?
          UNION ALL
          SELECT ea.nutritional_status, ea.assessment_date
          FROM endline_learners el
          JOIN endline_assessments ea ON el.id = ea.learner_id
          WHERE el.student_id = ?
        )
        WHERE nutritional_status IS NOT NULL AND nutritional_status != ''
        ORDER BY assessment_date DESC
        LIMIT 1
      ''',
        [widget.studentId, widget.studentId],
      );

      if (statusResult.isNotEmpty) {
        nutritionalStatus =
            statusResult.first['nutritional_status']?.toString() ?? 'Unknown';
      }

      // Update state
      setState(() {
        _studentInfo = {
          'name':
              studentData?['learner_name']?.toString() ?? widget.studentName,
          'grade': studentData?['grade_level']?.toString() ?? 'Unknown',
          'age': studentData?['age']?.toString() ?? '0',
          'sex': studentData?['sex']?.toString() ?? 'Unknown',
          'status': nutritionalStatus,
          'student_id': widget.studentId,
          'period': period,
          'academic_year':
              studentData?['academic_year']?.toString() ?? 'Unknown',
          'has_endline_data': hasEndlineData,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading student info: $e');
      setState(() {
        _studentInfo = {
          'name': widget.studentName,
          'grade': 'Unknown',
          'age': '0',
          'sex': 'Unknown',
          'status': 'Error loading data',
          'student_id': widget.studentId,
          'period': 'Unknown',
          'academic_year': 'Unknown',
          'has_endline_data': false,
        };
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAssessments() async {
    try {
      final dbService = db_service.DatabaseService.instance;
      final assessments = await dbService.getStudentAssessmentsForCharts(
        widget.studentId,
      );
      setState(() {
        _assessments = assessments;
      });
    } catch (e) {
      debugPrint('Error loading assessments: $e');
    }
  }

  void _changeView(String view) {
    setState(() {
      _selectedView = view;
    });
  }

  void _refreshData() {
    setState(() {
      _isLoading = true;
    });
    _loadStudentInfo();
    _loadAssessments();
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  Widget _buildStudentProfile() {
    return Container(
      width: 320, // Increased width for better readability
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 8,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Student Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Student Name (Large)
          _buildProfileItemLarge(
            'Student Name',
            _studentInfo['name'] as String? ?? widget.studentName,
            Icons.person,
            Colors.blue[700]!,
          ),

          // Nutritional Status (Added as requested)
          _buildProfileItemLarge(
            'Nutritional Status',
            _studentInfo['status'] as String? ?? 'Unknown',
            _getStatusIcon(_studentInfo['status'] as String? ?? 'Unknown'),
            _getStatusColor(_studentInfo['status'] as String? ?? 'Unknown'),
          ),

          const Divider(
              height: 30,
              thickness: 1,
              color: Color.fromARGB(255, 207, 204, 204)),

          // Other Details
          _buildProfileItem(
            'Grade Level:',
            _studentInfo['grade'] as String? ?? 'Unknown',
          ),

          _buildProfileItem(
            'Age:',
            _studentInfo['age'] as String? ?? '0',
          ),

          _buildProfileItem(
            'Gender:',
            _studentInfo['sex'] as String? ?? 'Unknown',
          ),

          _buildProfileItem(
            "Learner's ID:",
            _studentInfo['student_id'] as String? ?? widget.studentId,
          ),

          _buildProfileItem(
            'Academic Year:',
            _studentInfo['academic_year'] as String? ?? 'Unknown',
          ),

          _buildProfileItem(
            'Period:',
            _studentInfo['period'] as String? ?? 'Unknown',
          ),

          const SizedBox(height: 20),

          // Endline Data Indicator
          if (_studentInfo['has_endline_data'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[200]!, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_turned_in,
                      size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Has Endline Data',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileItemLarge(
      String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('normal')) return Icons.check_circle;
    if (lowerStatus.contains('wasted')) return Icons.warning;
    if (lowerStatus.contains('overweight') || lowerStatus.contains('obese'))
      return Icons.trending_up;
    return Icons.help;
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('normal')) return Colors.green[700]!;
    if (lowerStatus.contains('severely wasted')) return Colors.red[700]!;
    if (lowerStatus.contains('wasted')) return Colors.orange[700]!;
    if (lowerStatus.contains('overweight')) return Colors.blue[700]!;
    if (lowerStatus.contains('obese')) return Colors.purple[700]!;
    return Colors.grey[700]!;
  }

  Widget _buildTabSelector() {
    return Row(
      children: [
        _buildTabButton('Timeline', 'timeline'),
        _buildTabButton('Growth Summary', 'growth'),
        _buildTabButton('Comparison', 'comparison'),
      ],
    );
  }

  Widget _buildTabButton(String label, String view) {
    final isSelected = _selectedView == view;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        child: ElevatedButton(
          onPressed: () => _changeView(view),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue[700] : Colors.white,
            foregroundColor: isSelected ? Colors.white : Colors.blue[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected ? Colors.blue[700]! : Colors.blue[700]!,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.blue[700],
            ),
            const SizedBox(height: 20),
            Text(
              'Loading student health data...',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataState() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab Selector
            _buildTabSelector(),
            const SizedBox(height: 24),

            // Content Area
            Expanded(child: _buildContentArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    switch (_selectedView) {
      case 'timeline':
        return StatusTimelineChart(
          studentId: widget.studentId,
          studentName: widget.studentName,
        );
      case 'growth':
        return _buildGrowthSummary();
      case 'comparison':
        return BaselineEndlineComparison(
          studentId: widget.studentId,
          studentName: widget.studentName,
          assessments: _assessments,
        );
      default:
        return Container();
    }
  }

  Widget _buildGrowthSummary() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Single Column Layout for Charts
          SizedBox(
            height: 300,
            child: StudentGrowthLineChart(
              studentId: widget.studentId,
              metricType: 'weight',
              studentName: widget.studentName,
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 300,
            child: StudentGrowthLineChart(
              studentId: widget.studentId,
              metricType: 'height',
              studentName: widget.studentName,
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 300,
            child: StudentGrowthLineChart(
              studentId: widget.studentId,
              metricType: 'bmi',
              studentName: widget.studentName,
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 300,
            child: StudentGrowthLineChart(
              studentId: widget.studentId,
              metricType: 'hfa',
              studentName: widget.studentName,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          TopBar(
            onMenuToggle: () {},
            isSidebarCollapsed: false,
            title: 'Student Health History',
            showBackButton: true,
            onBackPressed: _goBack,
          ),
          if (_isLoading) _buildLoadingState(),
          if (!_isLoading) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Enlarged Student Profile
                    _buildStudentProfile(),

                    const SizedBox(width: 24),

                    // Right side - Dynamic Content
                    Expanded(child: _buildDataState()),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        tooltip: 'Refresh Data',
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.refresh, color: Colors.white, size: 24),
      ),
    );
  }
}
