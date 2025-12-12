// archives_page.dart
// ignore_for_file: unnecessary_null_comparison, avoid_print, unnecessary_brace_in_string_interps, deprecated_member_use

import 'package:district_dev/Page%20Components/sidebar.dart';
import 'package:district_dev/Page%20Components/topbar.dart';
import 'package:district_dev/Services/Database/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ArchivesPage extends StatefulWidget {
  const ArchivesPage({super.key});

  @override
  State<ArchivesPage> createState() => _ArchivesPageState();
}

class _ArchivesPageState extends State<ArchivesPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<Map<String, dynamic>> _importHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  String _selectedSchool = 'All Schools';
  List<String> _schools = ['All Schools'];
  bool _isLoading = true;
  String _debugInfo = 'Initializing...';
  bool _hasData = false;

  // Sidebar state
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _debugInfo = 'Initializing database connection...';
        _isLoading = true;
      });

      // Reset database connection if needed
      await _databaseService.resetDatabaseIfReadOnly();

      setState(() {
        _debugInfo = 'Loading data...';
      });

      await _loadData();

      setState(() {
        _debugInfo = 'Data loaded successfully';
      });
    } catch (e) {
      final errorMsg = 'Failed to initialize: $e';
      setState(() {
        _debugInfo = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _debugInfo = 'Loading schools...';
      });

      // Load schools
      final schoolsData = await _databaseService.getSchools();

      setState(() {
        _debugInfo = 'Found ${schoolsData.length} schools';
      });

      setState(() {
        _schools = ['All Schools'];
        _schools.addAll(schoolsData
            .map((school) => school['school_name'] as String)
            .where((name) => name != null && name.isNotEmpty && name != 'null')
            .toSet()
            .toList()
          ..sort());
      });

      // Load import history
      await _loadImportHistory();
    } catch (e) {
      final errorMsg = 'Error loading data: $e';
      setState(() {
        _debugInfo = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadImportHistory() async {
    try {
      setState(() {
        _debugInfo = 'Loading import history...';
        _importHistory = [];
        _filteredHistory = [];
        _hasData = false;
      });

      final allHistory = <Map<String, dynamic>>[];

      // Get import history for all schools
      final schools = await _databaseService.getSchools();

      if (schools.isEmpty) {
        setState(() {
          _debugInfo = 'No schools found.';
          _hasData = false;
        });
        return;
      }

      setState(() {
        _debugInfo = 'Processing ${schools.length} schools...';
      });

      int totalRecords = 0;
      int successfulSchools = 0;
      int failedSchools = 0;

      for (final school in schools) {
        final schoolId = school['id'] as String;
        final schoolName = school['school_name'] as String;

        setState(() {
          _debugInfo = 'Loading history for $schoolName...';
        });

        try {
          // Use the new SAFE query method that captures data immediately
          final history = await _safeImportHistoryQuery(schoolId, schoolName);

          if (history.isNotEmpty) {
            allHistory.addAll(history);
            totalRecords += history.length;
            successfulSchools++;

            if (kDebugMode) {
              print(
                  '✅ SAFE query loaded ${history.length} records for $schoolName');
            }
          } else {
            if (kDebugMode) {
              print('ℹ️  No records found for $schoolName');
            }
          }
        } catch (e) {
          failedSchools++;
          final errorMsg = 'Error loading history for $schoolName: $e';
          if (kDebugMode) {
            print('❌ $errorMsg');
          }
        }
      }

      setState(() {
        _debugInfo =
            'Found $totalRecords import records from $successfulSchools/${schools.length} schools (${failedSchools} failed)';
      });

      if (kDebugMode) {
        print('📊 Total records loaded: $totalRecords');
        print('🏫 Schools processed: $successfulSchools/${schools.length}');
        print('❌ Schools failed: $failedSchools');
        if (allHistory.isNotEmpty) {
          print('📝 Sample record structure:');
          print('   Keys: ${allHistory.first.keys}');
          print('   School name: ${allHistory.first['school_name']}');
          print('   File name: ${allHistory.first['file_name']}');
        }
      }

      // Sort by import date (newest first)
      allHistory.sort((a, b) {
        try {
          final dateAStr = a['import_date']?.toString() ?? '';
          final dateBStr = b['import_date']?.toString() ?? '';

          if (dateAStr.isEmpty || dateBStr.isEmpty) return 0;

          final dateA = DateTime.parse(dateAStr);
          final dateB = DateTime.parse(dateBStr);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _importHistory = allHistory;
        _hasData = allHistory.isNotEmpty;
        _applyFilter();
        _debugInfo =
            'Displaying ${_filteredHistory.length} filtered records from ${_importHistory.length} total';
      });

      if (kDebugMode) {
        print('✅ Archives loaded ${_importHistory.length} records');
        print('🔍 After filter: ${_filteredHistory.length} records');
        if (_importHistory.isNotEmpty) {
          print('📋 All school names in data:');
          final schoolNames = _importHistory
              .map((r) => r['school_name']?.toString() ?? 'Unknown')
              .toSet();
          for (final name in schoolNames) {
            print('   - "$name"');
          }
          print('📋 Available schools in filter: $_schools');
        }
      }
    } catch (e) {
      final errorMsg = 'Error loading import history: $e';
      setState(() {
        _debugInfo = errorMsg;
        _hasData = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Set empty state on error
      setState(() {
        _importHistory = [];
        _filteredHistory = [];
        _hasData = false;
      });

      if (kDebugMode) {
        print('❌ Error loading import history: $e');
      }
    }
  }

  // Safe query method that captures data immediately and handles read-only gracefully
  Future<List<Map<String, dynamic>>> _safeImportHistoryQuery(
      String schoolId, String schoolName) async {
    try {
      if (kDebugMode) {
        print('🔍 SAFE query for school $schoolId ($schoolName)');
      }

      // Get database instance
      final db = await _databaseService.database;

      // Check if table exists
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='import_history'");

      if (tables.isEmpty) {
        if (kDebugMode) {
          print('ℹ️  import_history table does not exist');
        }
        return [];
      }

      // Execute query and IMMEDIATELY capture the results
      final List<Map<String, dynamic>> rawResults = await db.query(
        'import_history',
        where: 'school_id = ?',
        whereArgs: [schoolId],
        orderBy: 'import_date DESC',
      );

      if (kDebugMode) {
        print('📦 RAW query returned ${rawResults.length} records');
        if (rawResults.isNotEmpty) {
          print('📋 Available columns: ${rawResults.first.keys}');
        }
      }

      // IMMEDIATELY process and transform the results
      final processedResults = <Map<String, dynamic>>[];

      for (final rawRecord in rawResults) {
        // Create a new map with enhanced data
        final processedRecord = Map<String, dynamic>.from(rawRecord);

        // Add school info
        processedRecord['school_name'] = schoolName;
        processedRecord['school_id'] = schoolId;

        // Extract period and school year from file name or description
        final fileName = rawRecord['file_name']?.toString() ?? '';
        final description = rawRecord['description']?.toString() ?? '';

        // Try to extract period
        String? extractedPeriod;
        String? extractedSchoolYear;

        if (fileName.toLowerCase().contains('baseline')) {
          extractedPeriod = 'Baseline';
        } else if (fileName.toLowerCase().contains('endline')) {
          extractedPeriod = 'Endline';
        } else if (description.toLowerCase().contains('baseline')) {
          extractedPeriod = 'Baseline';
        } else if (description.toLowerCase().contains('endline')) {
          extractedPeriod = 'Endline';
        }

        // Try to extract school year from various sources
        final yearPattern = RegExp(r'(\d{4}[-/]\d{4}|\d{4})');

        // Check file name
        final yearMatchInFileName = yearPattern.firstMatch(fileName);
        if (yearMatchInFileName != null) {
          extractedSchoolYear = yearMatchInFileName.group(0);
        }

        // Check description
        if (extractedSchoolYear == null) {
          final yearMatchInDesc = yearPattern.firstMatch(description);
          if (yearMatchInDesc != null) {
            extractedSchoolYear = yearMatchInDesc.group(0);
          }
        }

        // Check import_date for year
        if (extractedSchoolYear == null) {
          final importDateStr = rawRecord['import_date']?.toString();
          if (importDateStr != null && importDateStr.length >= 4) {
            extractedSchoolYear = importDateStr.substring(0, 4);
          }
        }

        // Add extracted data
        processedRecord['period'] = extractedPeriod ?? 'Unknown';
        processedRecord['school_year'] = extractedSchoolYear ?? 'Unknown';

        // Calculate records processed if not present
        if (processedRecord['records_processed'] == null &&
            processedRecord['total_records'] != null &&
            processedRecord['import_status']?.toString().toLowerCase() ==
                'completed') {
          processedRecord['records_processed'] =
              processedRecord['total_records'];
        }

        // Ensure status has proper display text
        final status = processedRecord['import_status']?.toString() ?? '';
        if (status.toLowerCase().contains('error') ||
            status.toLowerCase().contains('failed')) {
          processedRecord['import_status_display'] = 'Failed';
        } else if (status.toLowerCase().contains('completed')) {
          processedRecord['import_status_display'] = 'Completed';
        } else {
          processedRecord['import_status_display'] =
              status.isNotEmpty ? status : 'Unknown';
        }

        processedResults.add(processedRecord);
      }

      if (kDebugMode) {
        print(
            '✅ SAFE query successfully processed ${processedResults.length} records');
        if (processedResults.isNotEmpty) {
          print('📝 Processed record sample:');
          print('   File: ${processedResults.first['file_name']}');
          print('   Period: ${processedResults.first['period']}');
          print('   School Year: ${processedResults.first['school_year']}');
          print(
              '   Status: ${processedResults.first['import_status_display']}');
        }
      }

      return processedResults;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SAFE query failed for $schoolName: $e');
      }

      // If we get a read-only error, try one more approach
      if (e.toString().contains('read-only') ||
          e.toString().contains('Unsupported operation')) {
        return await _finalAttemptQuery(schoolId, schoolName);
      }

      rethrow;
    }
  }

  // FINAL ATTEMPT: Use a completely different approach with transaction
  Future<List<Map<String, dynamic>>> _finalAttemptQuery(
      String schoolId, String schoolName) async {
    try {
      if (kDebugMode) {
        print('🔄 FINAL ATTEMPT for $schoolName using transaction');
      }

      final db = await _databaseService.database;

      // Use transaction which might handle read-only differently
      return await db.transaction((txn) async {
        final results = await txn.query(
          'import_history',
          where: 'school_id = ?',
          whereArgs: [schoolId],
          orderBy: 'import_date DESC',
        );

        // Process immediately within transaction
        final processed = <Map<String, dynamic>>[];
        for (final record in results) {
          final newRecord = Map<String, dynamic>.from(record);
          newRecord['school_name'] = schoolName;
          newRecord['school_id'] = schoolId;

          // Add extracted period and year info
          final fileName = newRecord['file_name']?.toString() ?? '';
          if (fileName.toLowerCase().contains('baseline')) {
            newRecord['period'] = 'Baseline';
          } else if (fileName.toLowerCase().contains('endline')) {
            newRecord['period'] = 'Endline';
          } else {
            newRecord['period'] = 'Unknown';
          }

          processed.add(newRecord);
        }

        return processed;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Final attempt also failed for $schoolName: $e');
      }
      return [];
    }
  }

  void _applyFilter() {
    if (_selectedSchool == 'All Schools') {
      _filteredHistory = List.from(_importHistory);
    } else {
      _filteredHistory = _importHistory.where((record) {
        final recordSchool = record['school_name']?.toString() ?? '';
        return recordSchool == _selectedSchool;
      }).toList();
    }

    if (kDebugMode) {
      print('🔍 Applied filter: "$_selectedSchool"');
      print('   Total records: ${_importHistory.length}');
      print('   Filtered records: ${_filteredHistory.length}');
      if (_filteredHistory.isEmpty && _importHistory.isNotEmpty) {
        print('   ⚠️  No matches found for "$_selectedSchool"');
        print('   Available school names in data:');
        final schoolNames = _importHistory
            .map((r) => r['school_name']?.toString() ?? 'Unknown')
            .where((name) => name != null && name.isNotEmpty)
            .toSet();
        for (final name in schoolNames) {
          print('     - "$name"');
        }
      }
    }
  }

  String _getStatusBadge(String status) {
    if (status == null || status.isEmpty) return 'Unknown';

    final lowerStatus = status.toLowerCase();

    if (lowerStatus.contains('completed')) {
      if (lowerStatus.contains('error')) {
        return 'Partial';
      }
      return 'Saved';
    } else if (lowerStatus.contains('failed')) {
      return 'Failed';
    } else if (lowerStatus.contains('processing')) {
      return 'Processing';
    } else if (lowerStatus.contains('saved')) {
      return 'Saved';
    } else if (lowerStatus.contains('partial')) {
      return 'Partial';
    }

    return 'Unknown';
  }

  Color _getStatusColor(String status) {
    if (status == null || status.isEmpty) return Colors.grey;

    final lowerStatus = status.toLowerCase();

    if (lowerStatus.contains('completed') && !lowerStatus.contains('error')) {
      return Colors.green;
    } else if (lowerStatus.contains('completed with errors') ||
        lowerStatus.contains('partial')) {
      return Colors.orange;
    } else if (lowerStatus.contains('failed')) {
      return Colors.red;
    } else if (lowerStatus.contains('processing')) {
      return Colors.blue;
    } else if (lowerStatus.contains('saved')) {
      return Colors.green;
    }

    return Colors.grey;
  }

  void _showRecordMenu(BuildContext context, Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reimport File'),
              onTap: () {
                Navigator.pop(context);
                _reimportFile(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _viewRecordDetails(record);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _reimportFile(Map<String, dynamic> record) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reimporting ${record['file_name']}...')),
    );
  }

  void _viewRecordDetails(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('Import Details - ${record['file_name'] ?? 'Unknown File'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('School', record['school_name'] ?? 'Unknown'),
              _buildDetailRow('File Name', record['file_name'] ?? 'Unknown'),
              _buildDetailRow(
                'Import Date',
                _formatDate(record['import_date']),
              ),
              _buildDetailRow(
                  'Total Records', '${record['total_records'] ?? 0}'),
              _buildDetailRow(
                  'Records Processed', '${record['records_processed'] ?? 0}'),
              _buildDetailRow(
                  'Status',
                  record['import_status_display'] ??
                      record['import_status'] ??
                      'Unknown'),
              if (record['period'] != null && record['period'] != 'Unknown')
                _buildDetailRow('Period', record['period'] as String),
              if (record['school_year'] != null &&
                  record['school_year'] != 'Unknown')
                _buildDetailRow('School Year', record['school_year'] as String),
              if (record['description'] != null &&
                  (record['description'] as String).isNotEmpty)
                _buildDetailRow('Description', record['description'] as String),
              if (record['uploaded_by'] != null &&
                  (record['uploaded_by'] as String).isNotEmpty)
                _buildDetailRow('Uploaded By', record['uploaded_by'] as String),
              if (record['file_size'] != null)
                _buildDetailRow('File Size', '${record['file_size']} KB'),
              if (record['error_log'] != null &&
                  (record['error_log'] as String).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Error Log:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record['error_log'] as String,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';

    try {
      final dateString = dateValue.toString();
      if (dateString.isEmpty) return 'Unknown';

      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return dateValue.toString();
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _onPageChanged(int pageIndex) {
    // Handle navigation to other pages
    // This will be handled by the Sidebar widget's navigation methods
  }

  void _retryLoading() {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Retrying data load...';
    });
    _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Sidebar
          Sidebar(
            isCollapsed: _isSidebarCollapsed,
            onToggle: _toggleSidebar,
            currentPageIndex: 13, // Archives page index
            onPageChanged: _onPageChanged,
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                TopBar(
                  onMenuToggle: _toggleSidebar,
                  isSidebarCollapsed: _isSidebarCollapsed,
                  title: 'Archives',
                  showBackButton: false,
                ),

                // Debug info (only visible in debug mode)
                if (kDebugMode && _debugInfo.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Debug: $_debugInfo',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blue),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: _retryLoading,
                        ),
                      ],
                    ),
                  ),

                // Main content area
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar with School Filter
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Import History',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A4D7A),
                              ),
                            ),
                            const Spacer(),

                            // Test data button (only in debug mode)
                            if (kDebugMode)
                              ElevatedButton(
                                onPressed: () {
                                  if (kDebugMode) {
                                    print('🧪 Test button pressed');
                                    print('📊 Current data status:');
                                    print(
                                        '   Total records: ${_importHistory.length}');
                                    print(
                                        '   Filtered records: ${_filteredHistory.length}');
                                    print('   Schools: $_schools');
                                    print('   Selected: $_selectedSchool');
                                    print('   Has data: $_hasData');
                                    if (_importHistory.isNotEmpty) {
                                      print('📋 First record:');
                                      print(_importHistory.first);
                                    }
                                  }
                                },
                                child: const Text('Test'),
                              ),

                            const SizedBox(width: 16),
                            const Text(
                              'School:',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedSchool,
                                underline: const SizedBox(),
                                items: _schools.map((String school) {
                                  return DropdownMenuItem<String>(
                                    value: school,
                                    child: Text(
                                      school,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedSchool = newValue!;
                                    _applyFilter();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Data Header Bar
                      if (_hasData && _filteredHistory.isNotEmpty)
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A4D7A),
                            border: Border.all(color: const Color(0xFF1A4D7A)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'File Name',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'School Name | Last Added',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Loading Status',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: SizedBox(), // Space for hamburger button
                              ),
                            ],
                          ),
                        ),

                      // Data List
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : !_hasData || _filteredHistory.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.folder_open,
                                            size: 64, color: Colors.grey),
                                        const SizedBox(height: 16),
                                        Text(
                                          _importHistory.isEmpty
                                              ? 'No Import Records Found'
                                              : 'No records match the filter',
                                          style: const TextStyle(
                                              fontSize: 18, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _importHistory.isEmpty
                                              ? 'Import data will appear here after successful file imports'
                                              : 'Try selecting a different school filter',
                                          style: const TextStyle(
                                              fontSize: 14, color: Colors.grey),
                                        ),

                                        // Show database status information
                                        if (_debugInfo.contains('read-only') ||
                                            _debugInfo.contains('Error'))
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.orange),
                                              ),
                                              child: Column(
                                                children: [
                                                  const Row(
                                                    children: [
                                                      Icon(Icons.warning,
                                                          color: Colors.orange),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Database Issue Detected',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.orange,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _debugInfo,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.orange),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ElevatedButton(
                                                    onPressed: _retryLoading,
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                    child: const Text(
                                                        'Retry Loading Data'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                        const SizedBox(height: 16),
                                        if (kDebugMode &&
                                            _importHistory.isNotEmpty)
                                          Column(
                                            children: [
                                              const Text(
                                                'Debug: Data exists but not displayed',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.orange),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  if (kDebugMode) {
                                                    print(
                                                        '📊 Debug data dump:');
                                                    print(
                                                        '   Total records: ${_importHistory.length}');
                                                    print(
                                                        '   Schools in data: ${_importHistory.map((r) => r['school_name']).toSet()}');
                                                    print(
                                                        '   Available filters: $_schools');
                                                    print(
                                                        '   Debug info: $_debugInfo');
                                                  }
                                                },
                                                child: const Text('Debug Data'),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _filteredHistory.length,
                                    itemBuilder: (context, index) {
                                      final record = _filteredHistory[index];
                                      final fileName =
                                          record['file_name'] as String? ??
                                              'Unknown File';
                                      final schoolName =
                                          record['school_name'] as String? ??
                                              'Unknown School';
                                      final importDate = record['import_date'];
                                      final status =
                                          record['import_status_display']
                                                  as String? ??
                                              record['import_status']
                                                  as String? ??
                                              'Unknown';
                                      final totalRecords =
                                          record['total_records'] as int? ?? 0;
                                      final processedRecords =
                                          record['records_processed'] as int? ??
                                              0;
                                      final period =
                                          record['period'] as String? ?? '';
                                      final schoolYear =
                                          record['school_year'] as String? ??
                                              '';

                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                          title: Row(
                                            children: [
                                              // File Name
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.insert_drive_file,
                                                        color: Colors.blue,
                                                        size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            fileName,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          if (period
                                                                  .isNotEmpty &&
                                                              period !=
                                                                  'Unknown')
                                                            Text(
                                                              '(${period}${schoolYear.isNotEmpty && schoolYear != 'Unknown' ? ' - $schoolYear' : ''})',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // School Name and Date
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      schoolName,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Last Added: ${_formatDate(importDate)}',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey),
                                                    ),
                                                    Text(
                                                      'Records: $processedRecords/$totalRecords',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Loading Status
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _getStatusColor(status)
                                                            .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                        color: _getStatusColor(
                                                            status)),
                                                  ),
                                                  child: Text(
                                                    _getStatusBadge(status),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _getStatusColor(
                                                          status),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Hamburger Menu Button
                                              Expanded(
                                                flex: 1,
                                                child: IconButton(
                                                  icon: const Icon(
                                                      Icons.more_vert,
                                                      size: 20),
                                                  onPressed: () =>
                                                      _showRecordMenu(
                                                          context, record),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
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
}
