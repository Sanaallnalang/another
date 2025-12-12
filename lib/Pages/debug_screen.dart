import 'dart:async';
import 'package:district_dev/Services/Database/data_services.dart';
import 'package:district_dev/Services/Database/database_service.dart';
import 'package:flutter/material.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  _DebugScreenState createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _isLoading = false;
  String _currentOperation = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Endline Import Debug'),
        backgroundColor: Colors.orange,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.bug_report, size: 48, color: Colors.blue),
                        SizedBox(height: 8),
                        Text(
                          'Endline Import Diagnostics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Run these checks to find why Endline data is missing',
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Status Indicator
                if (_isLoading)
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _currentOperation,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: 10),

                // Debug Buttons
                Expanded(
                  child: ListView(
                    children: [
                      _buildDebugButton(
                        icon: Icons.search,
                        title: 'Check Endline Status',
                        subtitle: 'See current Endline records in database',
                        onPressed: () => _runOperation(
                          context,
                          'checkEndlineStatus',
                          _checkEndlineStatus,
                        ),
                      ),
                      _buildDebugButton(
                        icon: Icons.school,
                        title: 'Find School IDs',
                        subtitle: 'List all available schools',
                        onPressed: () => _runOperation(
                          context,
                          'findSchoolIds',
                          _findSchoolIds,
                        ),
                      ),
                      _buildDebugButton(
                        icon: Icons.storage,
                        title: 'Database Summary',
                        subtitle: 'Overview of all data',
                        onPressed: () => _runOperation(
                          context,
                          'databaseSummary',
                          _databaseSummary,
                        ),
                      ),
                      _buildDebugButton(
                        icon: Icons.history,
                        title: 'Import History',
                        subtitle: 'Check past import attempts',
                        onPressed: () => _runOperation(
                          context,
                          'importHistory',
                          _checkImportHistory,
                        ),
                      ),
                      _buildDebugButton(
                        icon: Icons.people,
                        title: 'Student Sample',
                        subtitle: 'Show sample student records',
                        onPressed: () => _runOperation(
                          context,
                          'studentSample',
                          _showStudentSample,
                        ),
                      ),
                      _buildDebugButton(
                        icon: Icons.build,
                        title: 'Fix Endline Issues',
                        subtitle: 'Run automatic fixes for Endline data',
                        onPressed: () => _runOperation(
                          context,
                          'fixEndline',
                          _fixEndlineIssues,
                        ),
                      ),
                      _buildDebugButton(
                        icon: Icons.analytics,
                        title: 'Diagnose Endline Problems',
                        subtitle: 'Detailed analysis of Endline data issues',
                        onPressed: () => _runOperation(
                          context,
                          'diagnoseEndline',
                          _diagnoseEndlineProblems,
                        ),
                      ),
                      _buildDebugButton(
                        icon: Icons.cleaning_services,
                        title: 'Remove Test Data',
                        subtitle: 'Clean out test records from database',
                        onPressed: () => _runOperation(
                          context,
                          'removeTestData',
                          _removeTestData,
                        ),
                      ),
                      _buildDebugButton(
                        icon: Icons.refresh,
                        title: 'Reset Database',
                        subtitle: 'Nuclear option - reset entire database',
                        onPressed: () => _runOperation(
                          context,
                          'resetDatabase',
                          _resetDatabase,
                        ),
                        color: Colors.red,
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

  Widget _buildDebugButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.blue),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onPressed,
      ),
    );
  }

  Future<void> _runOperation(
    BuildContext context,
    String operationName,
    Future Function() operation,
  ) async {
    if (_isLoading) return; // Prevent multiple simultaneous operations

    setState(() {
      _isLoading = true;
      _currentOperation = 'Running $operationName...';
    });

    try {
      await operation();
    } catch (e) {
      _showResult(context, 'Error', 'Operation failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentOperation = '';
      });
    }
  }

  Future<void> _checkEndlineStatus() async {
    try {
      final schools = await DatabaseService.instance.getSchools();
      if (schools.isEmpty) {
        _showResult(
          context,
          'No Schools',
          'No schools found in database. Please create a school first.',
        );
        return;
      }

      final schoolId = schools.first['id'] as String;

      // Get detailed Endline analysis
      final db = await DatabaseService.instance.database;

      // Check total Endline records
      final endlineCount = await db.rawQuery('''
        SELECT COUNT(*) as count FROM learners 
        WHERE period = 'Endline'
      ''');

      final totalEndline = endlineCount.first['count'] as int;

      // Check test vs real data
      final testEndlineCount = await db.rawQuery('''
        SELECT COUNT(*) as count FROM learners 
        WHERE period = 'Endline' AND learner_name LIKE '%John Santos%'
      ''');

      final testEndline = testEndlineCount.first['count'] as int;
      final realEndline = totalEndline - testEndline;

      final output = StringBuffer();
      output.writeln('🔍 ENDLINE STATUS ANALYSIS:');
      output.writeln('');
      output.writeln('📊 ENDLINE RECORDS BREAKDOWN:');
      output.writeln('   Total Endline records: $totalEndline');
      output.writeln('   Test records (John Santos): $testEndline');
      output.writeln('   Real Endline records: $realEndline');
      output.writeln('');

      if (realEndline == 0) {
        output.writeln('🚨 CRITICAL ISSUE:');
        output.writeln('   No real Endline data found in database!');
        output.writeln('');
        output.writeln('💡 SOLUTIONS:');
        output.writeln('   1. Use the dedicated Endline import function');
        output.writeln('   2. Ensure Excel files are marked as "Endline"');
        output.writeln('   3. Check that student names match Baseline records');
        output.writeln('   4. Verify school profile matches Excel file');
      }

      // Show sample of real Endline records
      if (realEndline > 0) {
        final realEndlineSamples = await db.rawQuery('''
          SELECT learner_name, academic_year, height, weight, student_id
          FROM learners 
          WHERE period = 'Endline' AND learner_name NOT LIKE '%John Santos%'
          LIMIT 5
        ''');

        output.writeln('🎯 REAL ENDLINE RECORDS:');
        for (final record in realEndlineSamples) {
          output.writeln('   👤 ${record['learner_name']}');
          output.writeln('      Year: ${record['academic_year']}');
          output.writeln('      Height: ${record['height']}');
          output.writeln('      Weight: ${record['weight']}');
          output.writeln('      Student ID: ${record['student_id']}');
          output.writeln('');
        }
      }

      _showResult(context, 'Endline Status', output.toString());
    } catch (e) {
      _showResult(context, 'Error', 'Failed to check Endline status: $e');
    }
  }

  Future<void> _findSchoolIds() async {
    try {
      final schools = await DatabaseService.instance.getSchools();
      final output = StringBuffer();
      output.writeln('🏫 AVAILABLE SCHOOLS:');
      output.writeln('');

      if (schools.isEmpty) {
        output.writeln('No schools found in database');
        output.writeln('');
        output.writeln(
          'Please create a school profile first before importing data.',
        );
      } else {
        for (final school in schools) {
          output.writeln('📝 ${school['school_name']}');
          output.writeln('   ID: ${school['id']}');
          output.writeln('   District: ${school['district']}');
          output.writeln('   Region: ${school['region']}');
          output.writeln(
            '   Academic Years: ${school['active_academic_years']}',
          );
          output.writeln(
            '   Baseline Date: ${school['baseline_date'] ?? "Not set"}',
          );
          output.writeln(
            '   Endline Date: ${school['endline_date'] ?? "Not set"}',
          );
          output.writeln('');
        }

        output.writeln(
          '💡 TIP: Use the first school ID for testing: ${schools.first['id']}',
        );
      }

      _showResult(context, 'School IDs', output.toString());
    } catch (e) {
      _showResult(context, 'Error', 'Failed to find schools: $e');
    }
  }

  Future<void> _databaseSummary() async {
    try {
      final db = await DatabaseService.instance.database;
      final output = StringBuffer();

      // Table counts
      final learnersCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM learners',
      );
      final schoolsCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM schools',
      );
      final assessmentsCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM bmi_assessments',
      );
      final importHistoryCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM import_history',
      );

      output.writeln('📈 DATABASE SUMMARY:');
      output.writeln('   Learners: ${learnersCount.first['count']}');
      output.writeln('   Schools: ${schoolsCount.first['count']}');
      output.writeln('   BMI Assessments: ${assessmentsCount.first['count']}');
      output.writeln('   Import History: ${importHistoryCount.first['count']}');
      output.writeln('');

      // Period distribution
      final periodDist = await db.rawQuery('''
        SELECT period, COUNT(*) as count 
        FROM learners 
        GROUP BY period
      ''');

      output.writeln('📊 PERIOD DISTRIBUTION:');
      bool hasEndline = false;
      for (final row in periodDist) {
        final period = row['period']?.toString() ?? 'Unknown';
        final count = row['count'] as int;
        output.writeln('   $period: $count records');
        if (period == 'Endline') hasEndline = true;
      }

      if (!hasEndline) {
        output.writeln('');
        output.writeln('⚠️  No Endline records found!');
        output.writeln('   This is likely why you cannot see progress data.');
      }

      // Academic year distribution
      final yearDist = await db.rawQuery('''
        SELECT academic_year, COUNT(*) as count 
        FROM learners 
        GROUP BY academic_year
      ''');

      output.writeln('');
      output.writeln('🎓 ACADEMIC YEAR DISTRIBUTION:');
      for (final row in yearDist) {
        output.writeln('   ${row['academic_year']}: ${row['count']} records');
      }

      _showResult(context, 'Database Summary', output.toString());
    } catch (e) {
      _showResult(context, 'Error', 'Failed to get database summary: $e');
    }
  }

  Future<void> _checkImportHistory() async {
    try {
      final schools = await DatabaseService.instance.getSchools();
      if (schools.isEmpty) {
        _showResult(
          context,
          'No Data',
          'No schools found. Please create a school first.',
        );
        return;
      }

      final schoolId = schools.first['id'] as String;
      final imports = await DatabaseService.instance.getImportHistory(schoolId);

      final output = StringBuffer();
      output.writeln('📋 IMPORT HISTORY:');
      output.writeln('');

      if (imports.isEmpty) {
        output.writeln('No import history found');
        output.writeln('');
        output.writeln('This means either:');
        output.writeln('1. No files have been imported yet');
        output.writeln('2. Import history is not being recorded');
        output.writeln('3. There is a database connection issue');
      } else {
        int endlineImports = 0;
        int baselineImports = 0;

        for (final import in imports.take(10)) {
          final period = import['period']?.toString() ?? 'Unknown';
          final status = import['import_status']?.toString() ?? 'Unknown';
          final records = import['records_processed'] ?? 0;

          output.writeln('📁 ${import['file_name']}');
          output.writeln('   Period: $period');
          output.writeln('   Status: $status');
          output.writeln('   Records: $records');
          output.writeln('   Date: ${import['import_date']}');
          output.writeln('');

          if (period == 'Endline') endlineImports++;
          if (period == 'Baseline') baselineImports++;
        }

        output.writeln('📊 IMPORT SUMMARY:');
        output.writeln('   Baseline imports: $baselineImports');
        output.writeln('   Endline imports: $endlineImports');

        if (endlineImports == 0) {
          output.writeln('');
          output.writeln('⚠️  No Endline imports found in history!');
          output.writeln('   You need to import Endline data specifically.');
          output.writeln(
            '   Use DataService.importEndlineExcelFile() for Endline imports.',
          );
        }
      }

      _showResult(context, 'Import History', output.toString());
    } catch (e) {
      _showResult(context, 'Error', 'Failed to load import history: $e');
    }
  }

  Future<void> _showStudentSample() async {
    try {
      final db = await DatabaseService.instance.database;
      final students = await db.rawQuery('''
        SELECT learner_name, period, academic_year, height, weight, nutritional_status, student_id
        FROM learners 
        ORDER BY created_at DESC 
        LIMIT 20
      ''');

      final output = StringBuffer();
      output.writeln('👥 RECENT STUDENT RECORDS (Latest 20):');
      output.writeln('');

      int endlineCount = 0;
      int baselineCount = 0;
      int testDataCount = 0;

      for (final student in students) {
        final period = student['period']?.toString() ?? 'Unknown';
        final name = student['learner_name']?.toString() ?? 'Unknown';

        if (period == 'Endline') endlineCount++;
        if (period == 'Baseline') baselineCount++;
        if (name.contains('John Santos') || name.contains('Test')) {
          testDataCount++;
        }

        output.writeln('🎯 $name');
        output.writeln('   Period: $period');
        output.writeln('   Year: ${student['academic_year']}');
        output.writeln('   Height: ${student['height'] ?? "NULL"}');
        output.writeln('   Weight: ${student['weight'] ?? "NULL"}');
        output.writeln('   Status: ${student['nutritional_status']}');
        output.writeln('   Student ID: ${_shortenId(student['student_id'])}');
        output.writeln('');
      }

      output.writeln('📊 SAMPLE SUMMARY:');
      output.writeln('   Baseline records: $baselineCount');
      output.writeln('   Endline records: $endlineCount');
      output.writeln('   Test data records: $testDataCount');
      output.writeln(
        '   Real data records: ${students.length - testDataCount}',
      );

      if (endlineCount == 0 || endlineCount == testDataCount) {
        output.writeln('');
        output.writeln('🚨 CRITICAL: No real Endline records found!');
        output.writeln(
          '   Only test data exists. Real Endline imports are failing.',
        );
      }

      _showResult(context, 'Student Sample', output.toString());
    } catch (e) {
      _showResult(context, 'Error', 'Failed to load students: $e');
    }
  }

  Future<void> _fixEndlineIssues() async {
    try {
      final schools = await DatabaseService.instance.getSchools();
      if (schools.isEmpty) {
        _showResult(context, 'No Schools', 'No schools found to fix.');
        return;
      }

      final schoolId = schools.first['id'] as String;

      // Run the Endline fix
      await DataService.fixEndlineStudentIds(schoolId);

      _showResult(
        context,
        'Fix Applied',
        'Endline student ID fix completed.\n\n'
            'This should resolve:\n'
            '• Missing student IDs in Endline records\n'
            '• Mismatched IDs between Baseline and Endline\n'
            '• Progress tracking issues',
      );
    } catch (e) {
      _showResult(context, 'Error', 'Failed to fix Endline issues: $e');
    }
  }

  Future<void> _diagnoseEndlineProblems() async {
    try {
      final schools = await DatabaseService.instance.getSchools();
      if (schools.isEmpty) {
        _showResult(context, 'No Schools', 'No schools found to diagnose.');
        return;
      }

      final schoolId = schools.first['id'] as String;

      // Run detailed diagnosis
      final diagnosis = await DataService.diagnoseEndlineIssues(schoolId);

      final output = StringBuffer();
      output.writeln('🔍 DETAILED ENDLINE DIAGNOSIS:');
      output.writeln('');

      if (diagnosis.containsKey('error')) {
        output.writeln('❌ Diagnosis failed: ${diagnosis['error']}');
      } else {
        output.writeln('📊 PERIOD DISTRIBUTION:');
        final periodDist =
            diagnosis['period_distribution'] as Map<String, dynamic>? ?? {};
        for (final entry in periodDist.entries) {
          output.writeln('   ${entry.key}: ${entry.value} records');
        }

        output.writeln('');
        output.writeln('🎯 STUDENT ID CONSISTENCY:');
        final consistency =
            diagnosis['student_id_consistency'] as Map<String, dynamic>? ?? {};
        output.writeln(
          '   Baseline students: ${consistency['baseline_students']}',
        );
        output.writeln(
          '   Endline students: ${consistency['endline_students']}',
        );
        output.writeln(
          '   Matched students: ${consistency['matched_students']}',
        );
        output.writeln('   Match rate: ${consistency['match_rate']}%');

        output.writeln('');
        output.writeln('🚨 PROBLEMATIC RECORDS:');
        output.writeln(
          '   Endline records needing fix: ${diagnosis['problematic_endline_records']}',
        );

        if (diagnosis['needs_fix'] == true) {
          output.writeln('');
          output.writeln('💡 RECOMMENDATION:');
          output.writeln(
            '   Run "Fix Endline Issues" to automatically resolve these problems.',
          );
        } else {
          output.writeln('');
          output.writeln('✅ No major ID issues detected.');
          output.writeln(
            '   The problem might be with the import process itself.',
          );
        }
      }

      _showResult(context, 'Endline Diagnosis', output.toString());
    } catch (e) {
      _showResult(context, 'Error', 'Failed to diagnose Endline problems: $e');
    }
  }

  Future<void> _removeTestData() async {
    try {
      await DatabaseService.instance.removeAllTestData();
      _showResult(
        context,
        'Test Data Removed',
        'All test records (John Santos, Maria Reyes, etc.) have been removed from the database.\n\n'
            'This will help you see if real data is being imported correctly.',
      );
    } catch (e) {
      _showResult(context, 'Error', 'Failed to remove test data: $e');
    }
  }

  Future<void> _resetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Database?'),
        content: Text(
          'This will DELETE ALL DATA and cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.nuclearDatabaseReset();
        _showResult(
          context,
          'Database Reset',
          'Database has been completely reset.\n\n'
              'All data has been wiped and the database has been recreated with proper schema.',
        );
      } catch (e) {
        _showResult(context, 'Error', 'Failed to reset database: $e');
      }
    }
  }

  String _shortenId(dynamic id) {
    if (id == null) return 'NULL';
    final idStr = id.toString();
    if (idStr.length <= 25) return idStr;
    return '${idStr.substring(0, 20)}...';
  }

  void _showResult(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            message,
            style: TextStyle(fontFamily: 'Monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (message.contains('needs fix') ||
              message.contains('No Endline') ||
              message.contains('CRITICAL'))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _fixEndlineIssues();
              },
              child: Text('Run Fix'),
            ),
        ],
      ),
    );
  }
}
