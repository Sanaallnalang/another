import 'package:district_dev/Page%20Components/Charts/district_dashboard.dart';
import 'package:district_dev/Page%20Components/sidebar.dart';
import 'package:district_dev/Page%20Components/topbar.dart';
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:district_dev/Services/Database/database_service.dart';
import 'package:flutter/material.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.fromTransaction = false});

  final bool fromTransaction;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _showWelcomeBack = false;
  List<SchoolProfile> _schoolProfiles = [];
  bool _isLoading = true;
  bool _isSidebarCollapsed = false;
  int _currentPageIndex = 0;

  // District Dashboard data
  List<Map<String, dynamic>> _allStudents = [];
  Map<String, dynamic> _districtStats = {
    'total_students': 0,
    'total_male': 0,
    'total_female': 0,
    'at_risk': 0,
    'total_schools': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadAllData();

    if (widget.fromTransaction) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomeMessage();
      });
    }
  }

  Future<void> _loadAllData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _loadSchoolData();
      await _loadDistrictData();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSchoolData() async {
    try {
      final DatabaseService dbService = DatabaseService.instance;
      final schools = await dbService.getSchools();

      // Convert QueryRow to SchoolProfile properly
      _schoolProfiles = schools.map((schoolMap) {
        return SchoolProfile.fromMap(Map<String, dynamic>.from(schoolMap));
      }).toList();

      print('Loaded ${_schoolProfiles.length} schools from database');

      // Debug: Print school details
      for (final school in _schoolProfiles) {
        print(
          'School: ${school.schoolName}, ID: ${school.id}, District: ${school.district}',
        );
      }
    } catch (e) {
      print('Error loading school data: $e');
    }
  }

  Future<void> _loadDistrictData() async {
    try {
      final DatabaseService dbService = DatabaseService.instance;
      final db = await dbService.database;

      // DIRECT SQL QUERY FOR UNIQUE STUDENTS FROM BOTH TABLES
      final sql = '''
    -- Get unique students from baseline and endline, preferring baseline for duplicates
    WITH AllStudents AS (
      -- Baseline students with their latest assessment
      SELECT 
        bl.student_id,
        bl.learner_name as name,
        bl.sex,
        bl.grade_level,
        bl.school_id,
        ba.weight_kg,
        ba.height_cm,
        ba.bmi,
        ba.nutritional_status,
        ba.assessment_date,
        'Baseline' as period,
        bl.academic_year,
        1 as priority -- Baseline gets priority
      FROM baseline_learners bl
      JOIN baseline_assessments ba ON bl.id = ba.learner_id
      WHERE bl.student_id IS NOT NULL
      
      UNION ALL
      
      -- Endline students with their latest assessment
      SELECT 
        el.student_id,
        el.learner_name as name,
        el.sex,
        el.grade_level,
        el.school_id,
        ea.weight_kg,
        ea.height_cm,
        ea.bmi,
        ea.nutritional_status,
        ea.assessment_date,
        'Endline' as period,
        el.academic_year,
        2 as priority -- Endline is lower priority
      FROM endline_learners el
      JOIN endline_assessments ea ON el.id = ea.learner_id
      WHERE el.student_id IS NOT NULL
    ),
    RankedStudents AS (
      SELECT 
        *,
        ROW_NUMBER() OVER (
          PARTITION BY student_id 
          ORDER BY priority, assessment_date DESC
        ) as rn
      FROM AllStudents
    )
    -- Select only one record per student (priority: Baseline > Endline, then latest date)
    SELECT * FROM RankedStudents WHERE rn = 1
    ''';

      final results = await db.rawQuery(sql);
      print(
        '✅ Direct SQL query found ${results.length} UNIQUE student records',
      );

      // Convert to the format expected by the dashboard
      _allStudents = results.map((row) {
        return {
          'school_id': row['school_id']?.toString() ?? '',
          'student_id': row['student_id']?.toString() ?? '',
          'name': row['name']?.toString() ?? '',
          'sex': row['sex']?.toString() ?? 'Unknown',
          'grade_level': row['grade_level']?.toString() ?? '',
          'weight_kg': row['weight_kg'] is double
              ? row['weight_kg']
              : (row['weight_kg'] != null
                  ? double.tryParse(row['weight_kg'].toString())
                  : null),
          'height_cm': row['height_cm'] is double
              ? row['height_cm']
              : (row['height_cm'] != null
                  ? double.tryParse(row['height_cm'].toString())
                  : null),
          'bmi': row['bmi'] is double
              ? row['bmi']
              : (row['bmi'] != null
                  ? double.tryParse(row['bmi'].toString())
                  : null),
          'nutritional_status':
              row['nutritional_status']?.toString() ?? 'Unknown',
          'assessment_date': row['assessment_date']?.toString() ?? '',
          'period': row['period']?.toString() ?? '',
          'academic_year': row['academic_year']?.toString() ?? '',
        };
      }).toList();

      // If no data found in Phase 2 tables, try the old table
      if (_allStudents.isEmpty) {
        print('⚠️ No data in Phase 2 tables, checking old learners table...');
        final fallbackSql = '''
      -- Get unique students from old table (deduplicate by student_id)
      WITH RankedOldStudents AS (
        SELECT 
          *,
          ROW_NUMBER() OVER (
            PARTITION BY student_id 
            ORDER BY assessment_date DESC
          ) as rn
        FROM learners 
        WHERE student_id IS NOT NULL
      )
      SELECT 
        student_id,
        learner_name as name,
        sex,
        grade_name as grade_level,
        school_id,
        weight as weight_kg,
        height as height_cm,
        bmi,
        nutritional_status,
        assessment_date,
        period,
        academic_year
      FROM RankedOldStudents 
      WHERE rn = 1
      ''';

        final fallbackResults = await db.rawQuery(fallbackSql);
        print(
          '📋 Fallback query found ${fallbackResults.length} UNIQUE records',
        );

        _allStudents = fallbackResults.map((row) {
          return {
            'school_id': row['school_id']?.toString() ?? '',
            'student_id': row['student_id']?.toString() ?? '',
            'name': row['name']?.toString() ?? '',
            'sex': row['sex']?.toString() ?? 'Unknown',
            'grade_level': row['grade_level']?.toString() ?? '',
            'weight_kg': row['weight_kg'],
            'height_cm': row['height_cm'],
            'bmi': row['bmi'],
            'nutritional_status':
                row['nutritional_status']?.toString() ?? 'Unknown',
            'assessment_date': row['assessment_date']?.toString() ?? '',
            'period': row['period']?.toString() ?? '',
            'academic_year': row['academic_year']?.toString() ?? '',
          };
        }).toList();
      }

      // Debug: Count duplicates to verify
      final studentIds = _allStudents.map((s) => s['student_id']).toSet();
      print(
        '📊 Verification: ${studentIds.length} unique student IDs out of ${_allStudents.length} total records',
      );

      if (studentIds.length < _allStudents.length) {
        print('⚠️ WARNING: Still have duplicates!');
      }

      // Debug: Print sample data
      if (_allStudents.isNotEmpty) {
        print('📋 Sample student data:');
        for (int i = 0;
            i < (_allStudents.length > 3 ? 3 : _allStudents.length);
            i++) {
          final student = _allStudents[i];
          print(
            '  Student ${i + 1}: ${student['name']} (${student['student_id']})',
          );
          print('    School: ${student['school_id']}');
          print('    Sex: ${student['sex']}');
          print('    Status: ${student['nutritional_status']}');
          print('    Period: ${student['period']}');
          print('    ---');
        }
      } else {
        print('⚠️ No student data found at all, creating mock data...');
        _createMockData();
      }

      _calculateDistrictStats();
    } catch (e) {
      print('❌ Error loading district data: $e');

      // Create mock data for testing if everything fails
      if (_allStudents.isEmpty && _schoolProfiles.isNotEmpty) {
        print('⚠️ Creating mock data for testing...');
        _createMockData();
        _calculateDistrictStats();
      }
    }
  }

  void _createMockData() {
    _allStudents = [];

    for (final school in _schoolProfiles) {
      // Add some mock students for each school
      final mockStudents = [
        {
          'school_id': school.id,
          'student_id': 'mock_1_${school.id}',
          'name': 'Juan Dela Cruz',
          'sex': 'Male',
          'grade_level': 'Grade 5',
          'weight_kg': 35.5,
          'height_cm': 140.0,
          'bmi': 18.1,
          'nutritional_status': 'Normal',
          'assessment_date': DateTime.now().toIso8601String(),
        },
        {
          'school_id': school.id,
          'student_id': 'mock_2_${school.id}',
          'name': 'Maria Santos',
          'sex': 'Female',
          'grade_level': 'Grade 4',
          'weight_kg': 28.0,
          'height_cm': 130.0,
          'bmi': 16.6,
          'nutritional_status': 'Wasted',
          'assessment_date': DateTime.now().toIso8601String(),
        },
        {
          'school_id': school.id,
          'student_id': 'mock_3_${school.id}',
          'name': 'Pedro Reyes',
          'sex': 'Male',
          'grade_level': 'Grade 6',
          'weight_kg': 45.0,
          'height_cm': 145.0,
          'bmi': 21.4,
          'nutritional_status': 'Overweight',
          'assessment_date': DateTime.now().toIso8601String(),
        },
        {
          'school_id': school.id,
          'student_id': 'mock_4_${school.id}',
          'name': 'Ana Gonzales',
          'sex': 'Female',
          'grade_level': 'Grade 3',
          'weight_kg': 22.0,
          'height_cm': 115.0,
          'bmi': 16.6,
          'nutritional_status': 'Severely Wasted',
          'assessment_date': DateTime.now().toIso8601String(),
        },
        {
          'school_id': school.id,
          'student_id': 'mock_5_${school.id}',
          'name': 'Luis Torres',
          'sex': 'Male',
          'grade_level': 'Grade 2',
          'weight_kg': 50.0,
          'height_cm': 135.0,
          'bmi': 27.4,
          'nutritional_status': 'Obese',
          'assessment_date': DateTime.now().toIso8601String(),
        },
      ];

      _allStudents.addAll(mockStudents);
    }

    print('✅ Created ${_allStudents.length} mock students for testing');
  }

  void _calculateDistrictStats() {
    final totalStudents = _allStudents.length;
    final totalMale = _allStudents
        .where((s) => s['sex']?.toString().toLowerCase() == 'male')
        .length;
    final totalFemale = _allStudents
        .where((s) => s['sex']?.toString().toLowerCase() == 'female')
        .length;
    final atRisk = _allStudents.where((s) {
      final status = s['nutritional_status']?.toString().toLowerCase() ?? '';
      return status.contains('wasted') || status.contains('severely');
    }).length;

    setState(() {
      _districtStats = {
        'total_students': totalStudents,
        'total_male': totalMale,
        'total_female': totalFemale,
        'at_risk': atRisk,
        'total_schools': _schoolProfiles.length,
      };
    });

    print('📊 District stats calculated:');
    print('  Total Students: $totalStudents');
    print('  Male: $totalMale');
    print('  Female: $totalFemale');
    print('  At Risk: $atRisk');
    print('  Total Schools: ${_schoolProfiles.length}');
  }

  void _showWelcomeMessage() {
    setState(() {
      _showWelcomeBack = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showWelcomeBack = false;
        });
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

  void _onProfileEdit() {
    print('Profile edit pressed');
  }

  String _getPageTitle() {
    return Sidebar.getPageTitle(_currentPageIndex);
  }

  // Method to manually refresh data
  Future<void> _refreshData() async {
    await _loadAllData();
  }

  // Debug database check with direct SQL
  Future<void> _checkDatabase() async {
    try {
      final dbService = DatabaseService.instance;
      final db = await dbService.database;

      print('🔍 DATABASE CHECK WITH DIRECT SQL:');

      // Check schools
      final schools = await db.rawQuery(
        'SELECT COUNT(*) as count FROM schools',
      );
      print('   Schools: ${schools.first['count']}');

      // Check Phase 2 tables
      final baselineCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM baseline_learners',
      );
      print('   Baseline learners: ${baselineCount.first['count']}');

      final baselineAssessments = await db.rawQuery(
        'SELECT COUNT(*) as count FROM baseline_assessments',
      );
      print('   Baseline assessments: ${baselineAssessments.first['count']}');

      final endlineCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM endline_learners',
      );
      print('   Endline learners: ${endlineCount.first['count']}');

      final endlineAssessments = await db.rawQuery(
        'SELECT COUNT(*) as count FROM endline_assessments',
      );
      print('   Endline assessments: ${endlineAssessments.first['count']}');

      // Check old learners table
      final oldCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM learners',
      );
      print('   Old learners table: ${oldCount.first['count']}');

      // Test the dashboard query
      final testQuery = '''
      SELECT COUNT(*) as total_students FROM (
        SELECT bl.id FROM baseline_learners bl
        JOIN baseline_assessments ba ON bl.id = ba.learner_id
        UNION ALL
        SELECT el.id FROM endline_learners el
        JOIN endline_assessments ea ON el.id = ea.learner_id
      )
      ''';

      final testResult = await db.rawQuery(testQuery);
      print(
        '   Combined students (test query): ${testResult.first['total_students']}',
      );

      // Show sample data
      final sampleQuery = '''
      SELECT 
        bl.learner_name,
        bl.sex,
        ba.nutritional_status,
        bl.school_id
      FROM baseline_learners bl
      JOIN baseline_assessments ba ON bl.id = ba.learner_id
      LIMIT 3
      ''';

      final sampleResults = await db.rawQuery(sampleQuery);
      print('   Sample baseline records: ${sampleResults.length}');

      // Show alert
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Database Check Results'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Schools: ${schools.first['count']}'),
                  Text('Baseline Learners: ${baselineCount.first['count']}'),
                  Text(
                    'Baseline Assessments: ${baselineAssessments.first['count']}',
                  ),
                  Text('Endline Learners: ${endlineCount.first['count']}'),
                  Text(
                    'Endline Assessments: ${endlineAssessments.first['count']}',
                  ),
                  Text('Old Learners: ${oldCount.first['count']}'),
                  Text(
                    'Combined Students: ${testResult.first['total_students']}',
                  ),
                  SizedBox(height: 10),
                  Text('Loaded Students in App: ${_allStudents.length}'),
                  SizedBox(height: 10),
                  if (sampleResults.isNotEmpty) ...[
                    Text(
                      'Sample Data:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...sampleResults.map(
                      (row) => Text(
                        '  ${row['learner_name']} - ${row['sex']} - ${row['nutritional_status']}',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _refreshData();
                },
                child: Text('Refresh Data'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Database check error: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Database Error'),
            content: Text('Error checking database: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
                  title: _getPageTitle(),
                  onProfileEdit: _onProfileEdit,
                ),

                // Main Content Area
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _isLoading
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1A4D7A),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading dashboard data...',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _schoolProfiles.isEmpty
                                ? _buildEmptyState()
                                : RefreshIndicator(
                                    onRefresh: _refreshData,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // District Dashboard Content
                                          DistrictDashboardContent(
                                            schoolProfiles: _schoolProfiles,
                                            allStudents: _allStudents,
                                            districtStats: _districtStats,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                      ),

                      // Welcome back message
                      if (_showWelcomeBack)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Material(
                            elevation: 8,
                            color: Colors.green,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Transaction completed successfully! Welcome back to Dashboard.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showWelcomeBack = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
          Icon(Icons.school, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'No Data Available',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Check database connection or import data',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadAllData,
            child: Text('Retry Loading Data'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _checkDatabase,
            child: Text('Check Database'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              print('=== DEBUG INFO ===');
              print('Schools: ${_schoolProfiles.length}');
              print('Students: ${_allStudents.length}');
              print('District Stats: $_districtStats');
              print('School IDs: ${_schoolProfiles.map((s) => s.id).toList()}');
              if (_allStudents.isNotEmpty) {
                print('Sample student: ${_allStudents.first}');
              }
            },
            child: Text('Debug Info'),
          ),
        ],
      ),
    );
  }
}
