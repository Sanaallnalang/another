import 'package:district_dev/Page%20Components/Components/school_dashboard.dart';
import 'package:district_dev/Page%20Components/Components/school_profile_creator.dart';
import 'package:district_dev/Page%20Components/Components/schoolcard_profile.dart';
import 'package:district_dev/Page%20Components/sidebar.dart';
import 'package:district_dev/Services/Data%20Model/acad_schyear_manager.dart';
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../Services/Database/database_service.dart' as db_service
    show DatabaseService;

class SchoolManagement extends StatefulWidget {
  const SchoolManagement({super.key});

  @override
  State<SchoolManagement> createState() => _SchoolManagementState();
}

class _SchoolManagementState extends State<SchoolManagement>
    with WidgetsBindingObserver {
  List<SchoolProfile> schoolProfiles = [];
  List<SchoolProfile> filteredSchoolProfiles = [];
  bool _isLoading = false;
  final SchoolManagementController _controller = SchoolManagementController();
  bool _isSidebarCollapsed = false;
  int _currentPageIndex = 2;
  final TextEditingController _searchController = TextEditingController();
  Map<String, Map<String, dynamic>> _schoolDataStatus = {};

  // Timer for periodic refresh
  Timer? _refreshTimer;
  bool _isVisible = true;

  // Database service instance
  final db_service.DatabaseService _dbService =
      db_service.DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSchools();
    _setupSearchListener();
    _startPeriodicRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this page
    if (_isVisible) {
      _refreshDataStatus();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - refresh data
      _isVisible = true;
      _refreshDataStatus();
    } else if (state == AppLifecycleState.paused) {
      // App went to background - stop refreshing
      _isVisible = false;
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isVisible && mounted) {
        _refreshDataStatus();
      }
    });
  }

  Future<void> _refreshDataStatus() async {
    if (!mounted || _isLoading) return;

    try {
      await _checkSchoolsDataStatus();
      if (kDebugMode) {
        debugPrint('🔄 Auto-refreshed school data status');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error in auto-refresh: $e');
      }
    }
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      _filterSchools();
    });
  }

  void _filterSchools() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        filteredSchoolProfiles = List.from(schoolProfiles);
      });
      return;
    }

    setState(() {
      filteredSchoolProfiles = schoolProfiles.where((school) {
        return school.schoolName.toLowerCase().contains(query) ||
            school.district.toLowerCase().contains(query) ||
            school.region.toLowerCase().contains(query) ||
            school.schoolId.toLowerCase().contains(query) ||
            school.principalName.toLowerCase().contains(query) ||
            school.activeAcademicYears.any(
              (year) => year.toLowerCase().contains(query),
            ) ||
            school.primaryAcademicYear.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadSchools() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final schools = await _controller.loadSchools();
      if (mounted) {
        setState(() {
          schoolProfiles = schools;
          filteredSchoolProfiles = List.from(schools);
        });
      }

      await _checkSchoolsDataStatus();
    } catch (e) {
      debugPrint('Error loading schools: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load schools: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkSchoolsDataStatus() async {
    final Map<String, Map<String, dynamic>> statusMap = {};

    for (final school in schoolProfiles) {
      try {
        // Check both baseline and endline data
        final baselineStudents = await _dbService.getBaselineStudents(
          school.id,
        );
        final endlineStudents = await _dbService.getEndlineStudents(school.id);

        final totalStudents = baselineStudents.length + endlineStudents.length;
        final hasData = totalStudents > 0;

        // Get unique academic years from the data
        final yearsSet = <String>{};
        for (final student in baselineStudents) {
          final year = student['academic_year']?.toString();
          if (year != null && year.isNotEmpty) {
            yearsSet.add(year);
          }
        }
        for (final student in endlineStudents) {
          final year = student['academic_year']?.toString();
          if (year != null && year.isNotEmpty) {
            yearsSet.add(year);
          }
        }

        statusMap[school.id] = {
          'has_imported_data': hasData,
          'student_count': totalStudents,
          'baseline_count': baselineStudents.length,
          'endline_count': endlineStudents.length,
          'academic_years': yearsSet.toList(),
          'data_complete': hasData && school.activeAcademicYears.isNotEmpty,
        };

        if (kDebugMode) {
          debugPrint(
            '📊 School ${school.schoolName}: $totalStudents students, ${baselineStudents.length} baseline, ${endlineStudents.length} endline',
          );
        }
      } catch (e) {
        statusMap[school.id] = {
          'has_imported_data': false,
          'student_count': 0,
          'baseline_count': 0,
          'endline_count': 0,
          'academic_years': [],
          'data_complete': false,
        };
        if (kDebugMode) {
          debugPrint('❌ Error checking data for ${school.schoolName}: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _schoolDataStatus = statusMap;
      });
    }
  }

  Future<void> refreshSchoolDataStatus(String schoolId) async {
    if (kDebugMode) {
      debugPrint(
        '🎯 CALLBACK TRIGGERED: Refreshing data status for school $schoolId',
      );
    }

    try {
      // Refresh school data from database
      final school = await _dbService.getSchool(schoolId);
      if (school != null) {
        // Find and update the school profile
        final index = schoolProfiles.indexWhere((s) => s.id == schoolId);
        if (index != -1) {
          final updatedProfile = SchoolProfile.fromMap(school);
          setState(() {
            schoolProfiles[index] = updatedProfile;
          });
        }
      }

      // Refresh data status for this school
      final baselineStudents = await _dbService.getBaselineStudents(schoolId);
      final endlineStudents = await _dbService.getEndlineStudents(schoolId);
      final totalStudents = baselineStudents.length + endlineStudents.length;

      final yearsSet = <String>{};
      for (final student in baselineStudents) {
        final year = student['academic_year']?.toString();
        if (year != null && year.isNotEmpty) {
          yearsSet.add(year);
        }
      }
      for (final student in endlineStudents) {
        final year = student['academic_year']?.toString();
        if (year != null && year.isNotEmpty) {
          yearsSet.add(year);
        }
      }

      if (mounted) {
        setState(() {
          _schoolDataStatus[schoolId] = {
            'has_imported_data': totalStudents > 0,
            'student_count': totalStudents,
            'baseline_count': baselineStudents.length,
            'endline_count': endlineStudents.length,
            'academic_years': yearsSet.toList(),
            'data_complete': totalStudents > 0,
          };
        });
      }

      if (kDebugMode) {
        debugPrint('🔄 Refreshed data status for school $schoolId');
        debugPrint('📊 Total students: $totalStudents');
        debugPrint('📊 Years found: ${yearsSet.toList()}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error refreshing data status for school $schoolId: $e');
      }
    }
  }

  Future<void> refreshAllSchoolsDataStatus() async {
    await _checkSchoolsDataStatus();
  }

  void _openSchoolDashboard(SchoolProfile profile) {
    if (kDebugMode) {
      debugPrint('🚀 Opening dashboard for ${profile.schoolName}');
      debugPrint('📞 Setting up callbacks for school ${profile.id}');
      debugPrint('🎓 Active academic years: ${profile.activeAcademicYears}');
      debugPrint('🎯 Primary academic year: ${profile.primaryAcademicYear}');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SchoolDashboard(
          schoolProfile: profile,
          onDataImported: () {
            if (kDebugMode) {
              debugPrint(
                '✅ DATA IMPORT CALLBACK FIRED for ${profile.schoolName}',
              );
            }
            refreshSchoolDataStatus(profile.id);
            refreshAllSchoolsDataStatus(); // Also refresh all schools status
          },
          onDataChanged: () {
            if (kDebugMode) {
              debugPrint(
                '🔄 DATA CHANGE CALLBACK FIRED for ${profile.schoolName}',
              );
            }
            refreshSchoolDataStatus(profile.id);
            refreshAllSchoolsDataStatus(); // Also refresh all schools status
          },
        ),
      ),
    ).then((_) {
      // Refresh when returning from dashboard
      if (kDebugMode) {
        debugPrint('🏠 Returned from dashboard, refreshing data status');
      }
      _refreshDataStatus();
    });
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Create New School Profile',
          style: TextStyle(fontSize: 20),
        ),
        content: const Text(
          'Are you sure you want to create a new school profile? This will set up a new database for this school.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openSchoolInfoForm();
            },
            child: const Text('Create', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _openSchoolInfoForm() {
    final defaultProfile = SchoolProfileHelper.createDefaultProfile();

    showDialog(
      context: context,
      builder: (context) => SchoolProfileCreator(
        schoolProfile: defaultProfile,
        onSave: _handleSaveProfile,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _handleSaveProfile(SchoolProfile profile) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _controller.saveSchoolProfile(profile);
      await _loadSchools(); // Reload schools with fresh data

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar(
          'School profile "${profile.schoolName}" created successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error creating profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectSchool(int index) {
    final profile = filteredSchoolProfiles[index];
    _openSchoolDashboard(profile);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'School Manager',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A4D7A),
          ),
        ),
        const SizedBox(height: 12),
        _buildSearchBar(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 400,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search, size: 24, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search school profiles...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(fontSize: 16),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: Colors.blue),
            onPressed: _isLoading
                ? null
                : () {
                    _refreshDataStatus();
                    _showSuccessSnackBar('School data status refreshed');
                  },
            tooltip: 'Refresh data status',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _showConfirmationDialog,
      icon: const Icon(Icons.add, size: 22),
      label: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Create School Profile', style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A4D7A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'No School Profiles Created',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Click "Create School Profile" to get started',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsInfo() {
    if (_searchController.text.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            'Showing ${filteredSchoolProfiles.length} of ${schoolProfiles.length} schools',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
          _buildDataStatusSummary(),
        ],
      ),
    );
  }

  Widget _buildDataStatusSummary() {
    final totalSchools = schoolProfiles.length;
    final schoolsWithData = _schoolDataStatus.values
        .where((status) => status['has_imported_data'] == true)
        .length;

    final totalStudents = _schoolDataStatus.values.fold<int>(
      0,
      (sum, status) => sum + (status['student_count'] as int),
    );

    return Row(
      children: [
        Icon(
          Icons.data_usage,
          size: 16,
          color: schoolsWithData > 0 ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 4),
        Text(
          '$schoolsWithData/$totalSchools with data',
          style: TextStyle(
            fontSize: 12,
            color: schoolsWithData > 0 ? Colors.green : Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.people, size: 16, color: Colors.blue),
        const SizedBox(width: 4),
        Text(
          '$totalStudents students total',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNoSearchResults() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'No schools found for "${_searchController.text}"',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try adjusting your search terms',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
              },
              child: const Text('Clear Search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolGrid() {
    return Expanded(
      child: Column(
        children: [
          _buildSearchResultsInfo(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                int crossAxisCount;

                if (availableWidth > 1200) {
                  crossAxisCount = 3;
                } else if (availableWidth > 800) {
                  crossAxisCount = 2;
                } else {
                  crossAxisCount = 1;
                }

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: _getChildAspectRatio(crossAxisCount),
                  ),
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredSchoolProfiles.length,
                  itemBuilder: (context, index) {
                    final profile = filteredSchoolProfiles[index];
                    final schoolData = _schoolDataStatus[profile.id] ??
                        {
                          'has_imported_data': false,
                          'student_count': 0,
                          'baseline_count': 0,
                          'endline_count': 0,
                          'academic_years': [],
                          'data_complete': false,
                        };

                    if (kDebugMode) {
                      debugPrint(
                        '🎨 Building card for ${profile.schoolName} - hasData: ${schoolData['has_imported_data']}, Students: ${schoolData['student_count']}',
                      );
                    }

                    return SchoolProfileCard(
                      profile: profile,
                      dbService: _dbService,
                      onTap: () => _selectSchool(index),
                      isSelected: false,
                      isLoading: null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _getChildAspectRatio(int crossAxisCount) {
    switch (crossAxisCount) {
      case 1:
        return 2.0;
      case 2:
        return 1.6;
      case 3:
        return 1.4;
      default:
        return 1.4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          Sidebar(
            isCollapsed: _isSidebarCollapsed,
            onToggle: _toggleSidebar,
            currentPageIndex: _currentPageIndex,
            onPageChanged: _onPageChanged,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isLargeScreen = constraints.maxWidth > 768;

                      if (isLargeScreen) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [_buildHeader(), _buildActionButtons()],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            _buildActionButtons(),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  if (_isLoading && schoolProfiles.isEmpty)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (schoolProfiles.isEmpty)
                    _buildEmptyState()
                  else if (filteredSchoolProfiles.isEmpty &&
                      _searchController.text.isNotEmpty)
                    _buildNoSearchResults()
                  else
                    _buildSchoolGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SchoolManagementController {
  final db_service.DatabaseService _databaseService =
      db_service.DatabaseService.instance;

  Future<List<SchoolProfile>> loadSchools() async {
    try {
      final schools = await _databaseService.getSchools();
      return schools.map((schoolMap) {
        return SchoolProfile.fromMap(schoolMap);
      }).toList();
    } catch (e) {
      debugPrint('Error loading schools: $e');
      rethrow;
    }
  }

  Future<void> saveSchoolProfile(SchoolProfile profile) async {
    try {
      await _databaseService.insertSchool(profile.toMap());
    } catch (e) {
      debugPrint('Error saving school profile: $e');
      rethrow;
    }
  }

  Future<void> deleteSchoolProfile(String schoolId) async {
    try {
      final school = await _databaseService.getSchool(schoolId);
      if (school == null) {
        throw Exception('School not found');
      }

      final db = await _databaseService.database;
      final schoolDeleteResult = await db.delete(
        'schools',
        where: 'id = ?',
        whereArgs: [schoolId],
      );

      if (schoolDeleteResult == 0) {
        throw Exception('Failed to delete school profile from database');
      }
    } catch (e) {
      debugPrint('Error deleting school profile: $e');
      rethrow;
    }
  }

  Future<void> updateSchoolProfile(SchoolProfile profile) async {
    try {
      await _databaseService.updateSchool(
        profile.toMap(),
        district: '',
        contactNumber: '',
        totalLearners: 0,
        schoolId: '',
        name: '',
        region: '',
      );
    } catch (e) {
      debugPrint('Error updating school profile: $e');
      rethrow;
    }
  }

  Future<String> getOrCreateSchoolByNameAndDistrict(
    String schoolName,
    String district,
    String region,
  ) async {
    try {
      return await _databaseService.getOrCreateSchoolByNameAndDistrict(
        schoolName,
        district,
        region,
      );
    } catch (e) {
      debugPrint('Error in getOrCreateSchoolByNameAndDistrict: $e');
      rethrow;
    }
  }

  Future<List<String>> getAvailableAcademicYears(String schoolId) async {
    try {
      return await _databaseService.getAvailableAcademicYears(schoolId);
    } catch (e) {
      debugPrint('Error getting available academic years: $e');
      return [AcademicYearManager.getCurrentSchoolYear()];
    }
  }

  Future<void> debugSchoolOperations() async {
    try {
      final schools = await loadSchools();
      debugPrint('Current schools in database: ${schools.length}');

      for (final school in schools) {
        debugPrint('School: ${school.schoolName} (ID: ${school.id})');
        debugPrint('  Active Years: ${school.activeAcademicYears}');
        debugPrint('  Primary Year: ${school.primaryAcademicYear}');
      }
    } catch (e) {
      debugPrint('Error in debugSchoolOperations: $e');
    }
  }
}

class SchoolProfileValidator {
  static String? validateSchoolName(String? value) {
    if (value == null || value.isEmpty) {
      return 'School name is required';
    }
    if (value.length < 3) {
      return 'School name must be at least 3 characters long';
    }
    return null;
  }

  static String? validateDistrict(String? value) {
    if (value == null || value.isEmpty) {
      return 'District is required';
    }
    return null;
  }

  static String? validateSchoolId(String? value) {
    if (value == null || value.isEmpty) {
      return 'School ID is required';
    }
    return null;
  }

  static String? validateTotalLearners(String? value) {
    if (value == null || value.isEmpty) {
      return 'Total learners is required';
    }
    final number = int.tryParse(value);
    if (number == null || number <= 0) {
      return 'Total learners must be a positive number';
    }
    return null;
  }

  static String? validateAcademicYearForOperation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Academic year is required';
    }
    if (!AcademicYearManager.isValidSchoolYear(value)) {
      return 'Academic year must be in format: 2024-2025';
    }
    return null;
  }

  static bool isValidProfile(SchoolProfile profile) {
    return validateSchoolName(profile.schoolName) == null &&
        validateDistrict(profile.district) == null &&
        validateSchoolId(profile.schoolId) == null &&
        profile.activeAcademicYears.isNotEmpty;
  }
}

class SchoolProfileHelper {
  static String formatAcademicYear(String academicYear) {
    final pattern = RegExp(r'(\d{4})[-/](\d{4})');
    final match = pattern.firstMatch(academicYear);
    if (match != null) {
      return '${match.group(1)}-${match.group(2)}';
    }
    return academicYear;
  }

  static String formatDateForDisplay(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static List<String> getAvailableDistricts() {
    return [
      'Department Of Education',
      'District 1',
      'District 2',
      'District 3',
      'District 4',
      'District 5',
      'District 6',
    ];
  }

  static List<String> getAvailableRegions() {
    return [
      'Region I',
      'Region II',
      'Region III',
      'Region IV-A',
      'Region IV-B',
      'Region V',
      'Region VI',
      'Region VII',
      'Region VIII',
      'Region IX',
      'Region X',
      'Region XI',
      'Region XII',
      'Region XIII',
      'NCR',
      'CAR',
      'BARMM',
    ];
  }

  static SchoolProfile createDefaultProfile() {
    final now = DateTime.now();
    final currentYear = AcademicYearManager.getCurrentSchoolYear();

    return SchoolProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      schoolName: '',
      schoolId: '',
      district: 'Department Of Education',
      region: 'NCR',
      address: '',
      principalName: '',
      sbfpCoordinator: '',
      platformUrl: '',
      contactNumber: '',
      totalLearners: 0,
      createdAt: now,
      updatedAt: now,
      lastUpdated: now,
      activeAcademicYears: [currentYear],
      primaryAcademicYear: currentYear,
    );
  }

  static SchoolProfile createFromImportData(
    String schoolName,
    String district,
    String region,
    String schoolYear,
  ) {
    final now = DateTime.now();
    final resolvedYear = AcademicYearManager.resolveImportSchoolYear(
      schoolYear,
      allowPastYears: true,
      maxPastYears: 5,
    );

    return SchoolProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      schoolName: schoolName,
      schoolId: '',
      district: district,
      region: region,
      address: '',
      principalName: '',
      sbfpCoordinator: '',
      platformUrl: '',
      contactNumber: '',
      totalLearners: 0,
      createdAt: now,
      updatedAt: now,
      lastUpdated: now,
      activeAcademicYears: [resolvedYear],
      primaryAcademicYear: resolvedYear,
    );
  }
}

class SchoolManagementAnalytics {
  static Map<String, dynamic> getSchoolStats(List<SchoolProfile> profiles) {
    final totalSchools = profiles.length;
    final districts = profiles.map((p) => p.district).toSet();
    final regions = profiles.map((p) => p.region).toSet();

    final schoolsWithData =
        profiles.where((p) => p.activeAcademicYears.isNotEmpty).length;

    final allAcademicYears = <String>{};
    for (final profile in profiles) {
      allAcademicYears.addAll(profile.activeAcademicYears);
    }

    return {
      'total_schools': totalSchools,
      'unique_districts': districts.length,
      'unique_regions': regions.length,
      'schools_with_data': schoolsWithData,
      'total_academic_years': allAcademicYears.length,
      'academic_years': allAcademicYears.toList()..sort(),
      'districts': districts.toList(),
      'regions': regions.toList(),
    };
  }

  static List<Map<String, dynamic>> getSchoolsByDistrict(
    List<SchoolProfile> profiles,
  ) {
    final districtMap = <String, int>{};

    for (final profile in profiles) {
      districtMap[profile.district] = (districtMap[profile.district] ?? 0) + 1;
    }

    return districtMap.entries
        .map((entry) => {'district': entry.key, 'count': entry.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  static List<Map<String, dynamic>> getSchoolsByRegion(
    List<SchoolProfile> profiles,
  ) {
    final regionMap = <String, int>{};

    for (final profile in profiles) {
      regionMap[profile.region] = (regionMap[profile.region] ?? 0) + 1;
    }

    return regionMap.entries
        .map((entry) => {'region': entry.key, 'count': entry.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  static List<Map<String, dynamic>> getSchoolsByAcademicYear(
    List<SchoolProfile> profiles,
  ) {
    final yearMap = <String, int>{};

    for (final profile in profiles) {
      for (final year in profile.activeAcademicYears) {
        yearMap[year] = (yearMap[year] ?? 0) + 1;
      }
    }

    return yearMap.entries
        .map((entry) => {'academic_year': entry.key, 'count': entry.value})
        .toList()
      ..sort(
        (a, b) => (b['academic_year'] as String).compareTo(
          a['academic_year'] as String,
        ),
      );
  }

  static Map<String, dynamic> getCrossYearStats(List<SchoolProfile> profiles) {
    final multiYearSchools =
        profiles.where((p) => p.activeAcademicYears.length > 1).length;
    final singleYearSchools =
        profiles.where((p) => p.activeAcademicYears.length == 1).length;

    final allYears = <String>{};
    for (final profile in profiles) {
      allYears.addAll(profile.activeAcademicYears);
    }

    final yearFrequency = <String, int>{};
    for (final year in allYears) {
      yearFrequency[year] = (yearFrequency[year] ?? 0) + 1;
    }

    return {
      'multi_year_schools': multiYearSchools,
      'single_year_schools': singleYearSchools,
      'most_common_year':
          yearFrequency.entries.reduce((a, b) => a.value > b.value ? a : b).key,
      'year_frequency': yearFrequency,
    };
  }
}
