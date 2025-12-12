// kill_switch_page.dart - UPDATED FOR MULTI-YEAR INFRASTRUCTURE
import 'package:district_dev/Services/Database/database_service.dart';
import 'package:flutter/material.dart';

class KillSwitchPage extends StatefulWidget {
  const KillSwitchPage({super.key});

  @override
  State<KillSwitchPage> createState() => _KillSwitchPageState();
}

class _KillSwitchPageState extends State<KillSwitchPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  bool _isLoading = false;
  bool _confirmationTyped = false;
  final TextEditingController _confirmationController = TextEditingController();
  final FocusNode _confirmationFocusNode = FocusNode();

  // Statistics - UPDATED FOR MULTI-YEAR
  int _totalSchools = 0;
  int _totalLearners = 0;
  int _totalAssessments = 0;
  int _totalImports = 0;
  int _totalAcademicYears = 0;
  int _totalCloudSyncs = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _confirmationController.addListener(_checkConfirmation);
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    _confirmationFocusNode.dispose();
    super.dispose();
  }

  void _checkConfirmation() {
    setState(() {
      _confirmationTyped =
          _confirmationController.text.trim() == 'DELETE ALL DATA';
    });
  }

  Future<void> _loadStatistics() async {
    try {
      final db = await _databaseService.database;

      // Get total schools
      final schools = await _databaseService.getSchools();
      _totalSchools = schools.length;

      // Get total learners across all academic years
      var learnersResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM learners',
      );
      _totalLearners = learnersResult.first['count'] as int;

      // Get total assessments
      var assessmentsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM bmi_assessments',
      );
      _totalAssessments = assessmentsResult.first['count'] as int;

      // Get total imports
      var importsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM import_history',
      );
      _totalImports = importsResult.first['count'] as int;

      // NEW: Count unique academic years across all schools
      final academicYears = <String>{};
      for (final school in schools) {
        final yearsString = school['active_academic_years']?.toString() ?? '';
        if (yearsString.isNotEmpty) {
          academicYears.addAll(yearsString.split(','));
        }
      }
      _totalAcademicYears = academicYears.length;

      // NEW: Count cloud sync records
      var cloudSyncsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM cloud_sync_history',
      );
      _totalCloudSyncs = cloudSyncsResult.first['count'] as int;

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading statistics: $e')));
      }
    }
  }

  Future<void> _deleteAllData() async {
    if (!_confirmationTyped) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _databaseService.database;
      final batch = db.batch();

      // UPDATED: Delete all data from all tables in correct order to respect foreign keys
      // Start with tables that have foreign key dependencies
      batch.delete('feeding_records');
      batch.delete('hfa_calculations');
      batch.delete('nutritional_statistics');
      batch.delete('sbfp_eligibility');
      batch.delete('bmi_assessments');

      // NEW: Delete multi-year support tables
      batch.delete('student_progress_tracking');
      batch.delete('cloud_sync_history');
      batch.delete('import_metadata');

      batch.delete('import_history');
      batch.delete('learners');
      batch.delete('schools');

      // Note: We don't delete grade_levels and user_profiles as they contain default data
      // batch.delete('grade_levels');
      // batch.delete('user_profiles');

      await batch.commit();

      // Reset statistics
      _totalSchools = 0;
      _totalLearners = 0;
      _totalAssessments = 0;
      _totalImports = 0;
      _totalAcademicYears = 0;
      _totalCloudSyncs = 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been successfully deleted'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset confirmation
        _confirmationController.clear();
        _confirmationTyped = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteDatabaseFile() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Nuclear Option'),
        content: const Text(
          'This will completely delete the database file and all its contents, including default data and user profiles. This action cannot be undone.\n\nAre you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Database File'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _databaseService.deleteDatabase();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Database file has been completely deleted. Restart the app.',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Reset statistics
          _totalSchools = 0;
          _totalLearners = 0;
          _totalAssessments = 0;
          _totalImports = 0;
          _totalAcademicYears = 0;
          _totalCloudSyncs = 0;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting database: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // NEW: Reset database for testing (useful for development)
  Future<void> _resetDatabaseForTesting() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔄 Reset Database for Testing'),
        content: const Text(
          'This will reset the entire database to a clean state while preserving the database structure. Useful for testing and development.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Reset Database'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _databaseService.resetDatabaseForTesting();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database has been reset for testing'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload statistics
          await _loadStatistics();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting database: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Text('Final Confirmation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are about to delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_totalSchools > 0) Text('• $_totalSchools schools'),
            if (_totalLearners > 0) Text('• $_totalLearners learners'),
            if (_totalAssessments > 0)
              Text('• $_totalAssessments BMI assessments'),
            if (_totalImports > 0) Text('• $_totalImports import records'),
            // NEW: Multi-year statistics
            if (_totalAcademicYears > 0)
              Text('• $_totalAcademicYears academic years'),
            if (_totalCloudSyncs > 0) Text('• $_totalCloudSyncs cloud syncs'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone. All application data will be permanently deleted.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ This includes all multi-year data, cloud sync records, and student progress tracking.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE EVERYTHING'),
          ),
        ],
      ),
    );
  }

  // Add this method to your _KillSwitchPageState class
  Future<void> _nuclearDatabaseReset() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Text('💥 NUCLEAR DATABASE RESET'),
          ],
        ),
        content: const Text(
          'This will DELETE ALL database files from ALL locations (main + fallback) and force a complete recreation with the period column.\n\n'
          'This is guaranteed to fix the "no column named period" error.\n\n'
          'ALL DATA WILL BE LOST. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('EXECUTE NUCLEAR RESET'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _databaseService.nuclearDatabaseReset();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nuclear reset completed! Database recreated with period column.',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Reload statistics to show empty state
          await _loadStatistics();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nuclear reset failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Add this method to your _KillSwitchPageState class
  Future<void> _emergencyFixPeriodColumn() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 EMERGENCY PERIOD COLUMN FIX'),
        content: const Text(
          'This will FORCE the database to be recreated with the period column. This is guaranteed to fix the import error.\n\nAll data will be lost. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('FIX PERIOD COLUMN'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _databaseService.emergencyFixPeriodColumn();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Period column fix completed! Restart the app.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fix failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Row(
                    children: [
                      Icon(Icons.delete_forever, size: 32, color: Colors.red),
                      SizedBox(width: 12),
                      Text(
                        'Data Management',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage and delete application data - Multi-Year Support',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Current Data Statistics - UPDATED LAYOUT
                  const Text(
                    'Current Data Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A4D7A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 3, // UPDATED: 3 columns for more stats
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildStatCard(
                        'Schools',
                        _totalSchools,
                        Icons.school,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Learners',
                        _totalLearners,
                        Icons.people,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Assessments',
                        _totalAssessments,
                        Icons.assessment,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Imports',
                        _totalImports,
                        Icons.file_upload,
                        Colors.purple,
                      ),
                      // NEW: Multi-year statistics
                      _buildStatCard(
                        'Academic Years',
                        _totalAcademicYears,
                        Icons.calendar_today,
                        Colors.teal,
                      ),
                      _buildStatCard(
                        'Cloud Syncs',
                        _totalCloudSyncs,
                        Icons.cloud_sync,
                        Colors.indigo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Add this after the Nuclear Option section
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.emergency, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                '🚨 EMERGENCY PERIOD COLUMN FIX',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'GUARANTEED FIX for "table learners has no column named period" error. This will force the database to be completely recreated with the correct schema.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _emergencyFixPeriodColumn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.construction),
                                  SizedBox(width: 8),
                                  Text(
                                    'FIX PERIOD COLUMN ERROR',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete All Application Data',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'This will permanently delete all schools, learners, assessments, import history, feeding records, cloud sync data, and multi-year tracking. Only default system data (grade levels, user profiles) will be preserved.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 20),

                          // Confirmation Input
                          const Text(
                            'Type "DELETE ALL DATA" to confirm:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _confirmationController,
                            focusNode: _confirmationFocusNode,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText: 'DELETE ALL DATA',
                              errorText:
                                  _confirmationController.text.isNotEmpty &&
                                          !_confirmationTyped
                                      ? 'Must type exactly "DELETE ALL DATA"'
                                      : null,
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 20),

                          // Delete Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _confirmationTyped
                                  ? _showConfirmationDialog
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_forever),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete All Data',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // NEW: Reset Database for Testing Section
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.refresh, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Reset Database for Testing',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'This will reset the entire database to a clean state while preserving the database structure. Useful for testing the multi-year system and development.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _resetDatabaseForTesting,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh),
                                  SizedBox(width: 8),
                                  Text(
                                    'Reset Database for Testing',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 💥 NUCLEAR RESET SECTION
                  Card(
                    color: Colors.red[100],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                '💥 NUCLEAR DATABASE RESET',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'GUARANTEED FIX: Deletes database files from ALL locations (main + fallback) and forces complete recreation with period column. This will 100% fix the import error.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _nuclearDatabaseReset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning_amber),
                                  SizedBox(width: 8),
                                  Text(
                                    'EXECUTE NUCLEAR RESET',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ), // Nuclear Option Section
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.dangerous, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Nuclear Option',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'This will completely delete the entire database file, including all default data and user profiles. The app will need to be restarted and will recreate the database with default values and multi-year support.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _deleteDatabaseFile,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_sweep),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete Entire Database File',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Safety Information - UPDATED
                  const SizedBox(height: 30),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Safety Information - Multi-Year Support',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            '• Data deletion is permanent and cannot be undone\n'
                            '• Always backup important data before proceeding\n'
                            '• Default system data (grade levels, user roles) will be preserved in normal delete\n'
                            '• Database file deletion requires app restart\n'
                            '• Multi-year data includes academic years, student progress tracking, and cloud sync records\n'
                            '• Reset for testing preserves database structure but removes all data\n'
                            '• These actions require proper user privileges',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
