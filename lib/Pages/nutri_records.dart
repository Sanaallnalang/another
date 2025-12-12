// nutritional_records.dart - UPDATED VERSION WITH DIRECT DATABASE QUERY
import 'dart:convert';
import 'package:district_dev/Page%20Components/Components/student_dashboard.dart';
import 'package:district_dev/Page%20Components/sidebar.dart';
import 'package:district_dev/Page%20Components/topbar.dart';
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:district_dev/Services/Database/database_service.dart'
    as db_service;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NutritionalRecordsPage extends StatefulWidget {
  const NutritionalRecordsPage({super.key});

  @override
  State<NutritionalRecordsPage> createState() => _NutritionalRecordsPageState();
}

class _NutritionalRecordsPageState extends State<NutritionalRecordsPage> {
  bool _isSidebarCollapsed = false;
  int _currentPageIndex = 12;
  String _selectedStatus = 'All';

  List<NutritionalRecord> _records = [];
  List<NutritionalRecord> _filteredRecords = [];
  bool _isLoading = true;

  final List<String> _statusFilters = [
    'All',
    'Normal',
    'Wasted',
    'Severely Wasted',
    'Overweight',
    'Obese',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    _loadNutritionalRecords();
  }

  /// 🆕 FIXED: Load student data directly from database with proper height and age
  Future<void> _loadNutritionalRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = db_service.DatabaseService.instance;
      final schoolsData = await dbService.getSchools();

      // Convert map data to SchoolProfile objects
      final schools = schoolsData
          .map((schoolMap) => SchoolProfile.fromMap(schoolMap))
          .toList();

      List<NutritionalRecord> allRecords = [];

      for (final school in schools) {
        // 🆕 CRITICAL FIX: Use direct SQL query to get students with height and age
        final students = await _getStudentsFromDatabase(school.id);

        if (students.isEmpty) {
          continue;
        }

        for (final student in students) {
          try {
            // 🆕 ENHANCED: Extract data with proper field names
            final studentName = student['learner_name'] as String? ?? 'Unknown';
            final studentId = student['student_id'] as String? ?? '';
            final grade = student['grade_level'] as String? ?? 'Unknown';
            final sex = student['sex'] as String? ?? 'Unknown';

            // 🆕 PROPER HEIGHT AND AGE EXTRACTION
            final height = student['height_cm'] as double?;
            final age = student['age'] as int?;

            // Parse assessment history from JSON string
            List<dynamic> assessmentHistory = [];
            try {
              final historyJson = student['assessment_history'] as String?;
              if (historyJson != null && historyJson.isNotEmpty) {
                assessmentHistory = json.decode(historyJson);
              }
            } catch (e) {
              debugPrint('Error parsing assessment history: $e');
            }

            // 🆕 CALCULATE HFA STATUS with proper data
            final hfaStatus = _calculateHFAStatus({
              'height': height,
              'age': age,
              'sex': sex,
            });

            final record = NutritionalRecord(
              studentName: studentName,
              schoolName: school.schoolName,
              grade: grade,
              bmi: (student['bmi'] ?? 0.0) as double,
              hfa: hfaStatus,
              nutritionalStatus:
                  student['nutritional_status']?.toString() ?? 'Unknown',
              learnerId: studentId,
              schoolId: school.id,
              schoolProfile: school,
              totalAssessments: student['total_assessments'] as int? ?? 0,
              baselineCount: student['baseline_count'] as int? ?? 0,
              endlineCount: student['endline_count'] as int? ?? 0,
              assessmentHistory: List<Map<String, dynamic>>.from(
                assessmentHistory,
              ),
              latestAcademicYear:
                  student['latest_academic_year']?.toString() ?? 'Unknown',
              height: height,
              age: age,
              bmiStatus: student['nutritional_status']?.toString() ?? 'Unknown',
              sex: '',
            );

            allRecords.add(record);
          } catch (e) {
            debugPrint('Error creating record for student: $e');
            continue;
          }
        }
      }

      // Sort records by school name, then by student name
      allRecords.sort((a, b) {
        final schoolCompare = a.schoolName.compareTo(b.schoolName);
        if (schoolCompare != 0) return schoolCompare;
        return a.studentName.compareTo(b.studentName);
      });

      setState(() {
        _records = allRecords;
        _filteredRecords = allRecords;
        _isLoading = false;
      });

      if (kDebugMode) {
        debugPrint('✅ LOADED ${allRecords.length} STUDENT RECORDS');

        // Debug: Check if height and age data is available
        final recordsWithHeight =
            allRecords.where((r) => r.height != null).length;
        final recordsWithAge = allRecords.where((r) => r.age != null).length;
        debugPrint('📊 Data Availability:');
        debugPrint(
          '   With height data: $recordsWithHeight/${allRecords.length}',
        );
        debugPrint('   With age data: $recordsWithAge/${allRecords.length}');

        // Show sample records
        if (allRecords.isNotEmpty) {
          final sample = allRecords.first;
          debugPrint('📋 SAMPLE RECORD:');
          debugPrint('   Name: ${sample.studentName}');
          debugPrint('   Height: ${sample.height} cm');
          debugPrint('   Age: ${sample.age} years');
          debugPrint('   HFA Status: ${sample.hfa}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading nutritional records: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading nutritional records: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 🆕 DIRECT DATABASE QUERY METHOD
  Future<List<Map<String, dynamic>>> _getStudentsFromDatabase(
    String schoolId,
  ) async {
    final db = await db_service.DatabaseService.instance.database;

    final sql = '''
    WITH StudentAssessments AS (
      -- Baseline assessments
      SELECT 
        bl.student_id,
        bl.learner_name,
        bl.school_id,
        bl.grade_level,
        bl.age,
        ba.weight_kg,
        ba.height_cm,
        ba.bmi,
        ba.nutritional_status,
        ba.assessment_date,
        'Baseline' AS period,
        bl.academic_year,
        bl.sex,
        bl.date_of_birth
      FROM baseline_learners bl
      JOIN baseline_assessments ba ON bl.id = ba.learner_id
      WHERE bl.school_id = ?
      
      UNION ALL
      
      -- Endline assessments  
      SELECT 
        el.student_id,
        el.learner_name,
        el.school_id,
        el.grade_level,
        el.age,
        ea.weight_kg,
        ea.height_cm,
        ea.bmi,
        ea.nutritional_status,
        ea.assessment_date,
        'Endline' AS period,
        el.academic_year,
        el.sex,
        el.date_of_birth
      FROM endline_learners el
      JOIN endline_assessments ea ON el.id = ea.learner_id
      WHERE el.school_id = ?
    ),
    
    LatestAssessment AS (
      SELECT 
        student_id,
        learner_name,
        school_id,
        grade_level,
        age,
        weight_kg,
        height_cm,
        bmi,
        nutritional_status,
        academic_year,
        sex,
        date_of_birth,
        period,
        ROW_NUMBER() OVER (
          PARTITION BY student_id 
          ORDER BY assessment_date DESC
        ) as rn
      FROM StudentAssessments
    ),
    
    AssessmentSummary AS (
      SELECT 
        student_id,
        learner_name,
        school_id,
        grade_level,
        age,
        weight_kg,
        height_cm,
        bmi,
        nutritional_status,
        academic_year,
        sex,
        date_of_birth,
        COUNT(*) as total_assessments,
        COUNT(CASE WHEN period = 'Baseline' THEN 1 END) as baseline_count,
        COUNT(CASE WHEN period = 'Endline' THEN 1 END) as endline_count
      FROM StudentAssessments
      GROUP BY student_id, learner_name, school_id, grade_level, age, 
               weight_kg, height_cm, bmi, nutritional_status, academic_year, 
               sex, date_of_birth
    )
    
    SELECT 
      la.student_id,
      la.learner_name,
      la.school_id,
      la.grade_level,
      la.age,
      la.height_cm,
      la.bmi,
      la.nutritional_status,
      la.academic_year as latest_academic_year,
      la.sex,
      la.date_of_birth,
      asum.total_assessments,
      asum.baseline_count,
      asum.endline_count,
      -- Create assessment history JSON
      (
        SELECT json_group_array(json_object(
          'assessment_date', sa.assessment_date,
          'period', sa.period,
          'academic_year', sa.academic_year,
          'weight', sa.weight_kg,
          'height', sa.height_cm,
          'bmi', sa.bmi,
          'nutritional_status', sa.nutritional_status,
          'age', sa.age,
          'sex', sa.sex
        ))
        FROM StudentAssessments sa
        WHERE sa.student_id = la.student_id
        ORDER BY sa.assessment_date
      ) as assessment_history
    FROM LatestAssessment la
    JOIN AssessmentSummary asum ON la.student_id = asum.student_id
    WHERE la.rn = 1
    ORDER BY la.learner_name, la.grade_level
    ''';

    try {
      final results = await db.rawQuery(sql, [schoolId, schoolId]);

      if (kDebugMode) {
        debugPrint(
          '📊 Database query for school $schoolId returned ${results.length} students',
        );
        if (results.isNotEmpty) {
          debugPrint('📋 Sample record fields: ${results.first.keys.toList()}');
          final sample = results.first;
          debugPrint('   Height: ${sample['height_cm']}');
          debugPrint('   Age: ${sample['age']}');
          debugPrint('   BMI: ${sample['bmi']}');
          debugPrint('   Nutritional Status: ${sample['nutritional_status']}');
        }
      }

      return results;
    } catch (e) {
      debugPrint('❌ Database query error: $e');
      return [];
    }
  }

  /// 🆕 FIXED HFA CALCULATION - Now receives direct height and age
  String _calculateHFAStatus(Map<String, dynamic> studentData) {
    try {
      final height = studentData['height'] as double?;
      final age = studentData['age'] as int?;
      final sex = studentData['sex'] as String? ?? 'Unknown';

      // Check if we have valid data
      if (height == null || age == null) {
        return 'No Data';
      }

      // Age validation (WHO standards typically for 5-19 years)
      if (age < 5 || age > 19) {
        return 'Age Out of Range';
      }

      // Get expected height for age based on WHO standards
      final expectedHeight = _getExpectedHeightForAge(age);
      if (expectedHeight <= 0) return 'No Data';

      final heightRatio = height / expectedHeight;

      // Classify based on WHO standards for Height-for-Age
      if (heightRatio < 0.90) return 'Severely Stunted';
      if (heightRatio < 0.95) return 'Stunted';
      if (heightRatio <= 1.05) return 'Normal';
      if (heightRatio <= 1.10) return 'Tall';
      return 'Very Tall';
    } catch (e) {
      debugPrint('Error calculating HFA: $e');
      return 'No Data';
    }
  }

  /// 🆕 Get expected height for age based on WHO standards
  double _getExpectedHeightForAge(int age) {
    // WHO Height-for-Age standards (in cm) for children 5-19 years
    // These are approximate median values; you may want to use exact WHO tables
    final Map<int, double> heightStandards = {
      5: 110.0, // 5 years
      6: 116.0, // 6 years
      7: 121.0, // 7 years
      8: 127.0, // 8 years
      9: 132.0, // 9 years
      10: 138.0, // 10 years
      11: 143.0, // 11 years
      12: 149.0, // 12 years
      13: 156.0, // 13 years
      14: 163.0, // 14 years
      15: 168.0, // 15 years
      16: 172.0, // 16 years
      17: 175.0, // 17 years
      18: 176.0, // 18 years
      19: 176.5, // 19 years
    };

    return heightStandards[age] ?? (100 + (age * 4.5)).toDouble();
  }

  /// 🆕 GET HFA STATUS COLOR
  Color _getHFAStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'tall':
      case 'very tall':
        return Colors.blue;
      case 'stunted':
        return Colors.orange;
      case 'severely stunted':
        return Colors.red;
      case 'no data':
      case 'age out of range':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _filterRecords(String status) {
    setState(() {
      _selectedStatus = status;
      if (status == 'All') {
        _filteredRecords = _records;
      } else {
        _filteredRecords = _records
            .where((record) => record.nutritionalStatus == status)
            .toList();
      }
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _onPageChanged(int index) {
    if (index == _currentPageIndex) return;
    setState(() {
      _currentPageIndex = index;
    });
  }

  void _onStudentRecordTap(NutritionalRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentHealthHistoryPage(
          studentId: record.learnerId,
          studentName: record.studentName,
          schoolId: record.schoolId,
        ),
      ),
    );
  }

  void _showStudentDetails(NutritionalRecord record) {
    // Get sex from assessment history if available
    String studentSex = 'Unknown';
    if (record.assessmentHistory.isNotEmpty) {
      final lastAssessment = record.assessmentHistory.last;
      studentSex = lastAssessment['sex']?.toString() ?? 'Unknown';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          record.studentName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A4D7A),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('School:', record.schoolName),
              _buildDetailRow('School ID:', record.schoolProfile.schoolId),
              _buildDetailRow('District:', record.schoolProfile.district),
              if (record.schoolProfile.region.isNotEmpty)
                _buildDetailRow('Region:', record.schoolProfile.region),
              _buildDetailRow('Grade:', record.grade),
              _buildDetailRow(
                'Sex:',
                studentSex,
              ), // FIXED: Now gets from student data
              if (record.age != null)
                _buildDetailRow('Age:', '${record.age} years'),
              if (record.height != null)
                _buildDetailRow(
                  'Height:',
                  '${record.height!.toStringAsFixed(1)} cm',
                ),
              _buildDetailRow('BMI:', '${record.bmi.toStringAsFixed(2)} kg/m²'),
              _buildDetailRow('HFA Status:', record.hfa),
              _buildDetailRow('Nutritional Status:', record.nutritionalStatus),
              _buildDetailRow(
                'Total Assessments:',
                record.totalAssessments.toString(),
              ),
              _buildDetailRow(
                'Baseline Records:',
                record.baselineCount.toString(),
              ),
              _buildDetailRow(
                'Endline Records:',
                record.endlineCount.toString(),
              ),
              _buildDetailRow(
                'Latest Academic Year:',
                record.latestAcademicYear,
              ),
              if (record.schoolProfile.principalName.isNotEmpty)
                _buildDetailRow(
                  'Principal:',
                  record.schoolProfile.principalName,
                ),
              if (record.schoolProfile.contactNumber.isNotEmpty)
                _buildDetailRow('Contact:', record.schoolProfile.contactNumber),
              const SizedBox(height: 16),
              // Nutritional Status Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    record.nutritionalStatus,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(record.nutritionalStatus),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(record.nutritionalStatus),
                      color: _getStatusColor(record.nutritionalStatus),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nutritional Status: ${record.nutritionalStatus}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(record.nutritionalStatus),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // HFA Status Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getHFAStatusColor(record.hfa).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getHFAStatusColor(record.hfa)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getHFAStatusIcon(record.hfa),
                      color: _getHFAStatusColor(record.hfa),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Height-for-Age: ${record.hfa}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getHFAStatusColor(record.hfa),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onStudentRecordTap(record);
            },
            child: const Text('View Full Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'wasted':
        return Colors.orange;
      case 'severely wasted':
        return Colors.red;
      case 'overweight':
        return Colors.amber;
      case 'obese':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return Icons.check_circle;
      case 'wasted':
        return Icons.warning;
      case 'severely wasted':
        return Icons.error;
      case 'overweight':
        return Icons.warning_amber;
      case 'obese':
        return Icons.error_outline;
      default:
        return Icons.help;
    }
  }

  /// 🆕 HFA STATUS ICONS
  IconData _getHFAStatusIcon(String hfaStatus) {
    switch (hfaStatus.toLowerCase()) {
      case 'normal':
        return Icons.check_circle;
      case 'stunted':
        return Icons.warning;
      case 'severely stunted':
        return Icons.error;
      case 'tall':
      case 'very tall':
        return Icons.arrow_upward;
      default:
        return Icons.help;
    }
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutritional Status Records',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A4D7A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Comprehensive overview of student nutritional assessments',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [_buildStatsSummary(), _buildStatusFilter()],
        ),
      ],
    );
  }

  Widget _buildStatsSummary() {
    final totalRecords = _records.length;
    final filteredRecords = _filteredRecords.length;

    if (_isLoading) {
      return const SizedBox();
    }

    return Row(
      children: [
        _buildStatCard('Total Students', totalRecords.toString(), Colors.blue),
        const SizedBox(width: 12),
        if (_selectedStatus != 'All')
          _buildStatCard(
            _selectedStatus,
            filteredRecords.toString(),
            _getStatusColor(_selectedStatus),
          ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1A4D7A)),
          style: const TextStyle(fontSize: 16, color: Color(0xFF1A4D7A)),
          onChanged: (String? newValue) {
            if (newValue != null) {
              _filterRecords(newValue);
            }
          },
          items: _statusFilters.map((String status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: status == 'All'
                          ? Colors.grey
                          : _getStatusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(status),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecordsTable() {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading nutritional records...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredRecords.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
              Text(
                _selectedStatus == 'All'
                    ? 'No Nutritional Records Found'
                    : 'No Records with "$_selectedStatus" Status',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Student nutritional records will appear here',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadNutritionalRecords,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Data'),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A4D7A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  // Student Name Header
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Student Name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  // School Name Header
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'School Name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  // Grade Header (Centered)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(
                        'Grade',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  // BMI Header (Centered)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(
                        'BMI',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  // HFA Status Header (Centered)
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Center(
                        child: Text(
                          'HFA Status',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Nutritional Status Header (Centered)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Center(
                        child: Text(
                          'Nutritional Status',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Table Content
            Expanded(
              child: ListView.separated(
                itemCount: _filteredRecords.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final record = _filteredRecords[index];
                  return _buildStudentRow(record);
                },
              ),
            ),
            // Summary Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${_filteredRecords.length} of ${_records.length} students',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    'Filtered by: $_selectedStatus',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A4D7A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRow(NutritionalRecord record) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onStudentRecordTap(record),
        onLongPress: () => _showStudentDetails(record),
        hoverColor: const Color(0xFF1A4D7A).withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Student Name
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    record.studentName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // School Name
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    record.schoolName,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Grade (Centered)
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    record.grade,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ),
              // BMI (Centered)
              Expanded(
                flex: 1,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(record.bmiStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getStatusColor(record.bmiStatus),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      record.bmi.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(record.bmiStatus),
                      ),
                    ),
                  ),
                ),
              ),
              // HFA Status (Centered)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getHFAStatusColor(record.hfa).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getHFAStatusColor(record.hfa),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        record.hfa,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getHFAStatusColor(record.hfa),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
              ),
              // Nutritional Status (Centered)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          record.nutritionalStatus,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(record.nutritionalStatus),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(record.nutritionalStatus),
                            size: 12,
                            color: _getStatusColor(record.nutritionalStatus),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              record.nutritionalStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(
                                  record.nutritionalStatus,
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // Sidebar
          Sidebar(
            isCollapsed: _isSidebarCollapsed,
            onToggle: _toggleSidebar,
            currentPageIndex: _currentPageIndex,
            onPageChanged: _onPageChanged,
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                TopBar(
                  onMenuToggle: _toggleSidebar,
                  isSidebarCollapsed: _isSidebarCollapsed,
                  title: Sidebar.getPageTitle(_currentPageIndex),
                  showBackButton: false,
                ),

                // Main Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildRecordsTable(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NutritionalRecord {
  final String studentName;
  final String schoolName;
  final String grade;
  final double bmi;
  final String hfa;
  final String nutritionalStatus;
  final String learnerId;
  final String schoolId;
  final SchoolProfile schoolProfile;
  final int totalAssessments;
  final int baselineCount;
  final int endlineCount;
  final List<Map<String, dynamic>> assessmentHistory;
  final String latestAcademicYear;
  final double? height;
  final int? age;
  final String bmiStatus;
  final String sex; // Keep as required but update constructor

  NutritionalRecord({
    required this.studentName,
    required this.schoolName,
    required this.grade,
    required this.bmi,
    required this.hfa,
    required this.nutritionalStatus,
    required this.learnerId,
    required this.schoolId,
    required this.schoolProfile,
    required this.totalAssessments,
    required this.baselineCount,
    required this.endlineCount,
    required this.assessmentHistory,
    required this.latestAcademicYear,
    this.height,
    this.age,
    required this.bmiStatus,
    this.sex = 'Unknown', // Make optional with default value
  });
}
