// learner_page.dart - UPDATED WITH BETTER DATA FILTERING LOGIC
import 'package:flutter/material.dart';

class LearnersPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final List<Map<String, dynamic>> baselineStudents;
  final List<Map<String, dynamic>> endlineStudents;

  const LearnersPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.baselineStudents,
    required this.endlineStudents,
  });

  @override
  State<LearnersPage> createState() => _LearnersPageState();
}

class _LearnersPageState extends State<LearnersPage> {
  List<Map<String, dynamic>> _filteredStudents = [];
  String _selectedSchoolYear = '';
  String _selectedAssessmentPeriod = 'Baseline';
  String _selectedGradeFilter = 'All';
  String _selectedStatusFilter = 'All';

  List<String> _availableSchoolYears = [];
  final List<String> _availablePeriods = ['Baseline', 'Endline'];
  final List<String> _availableGrades = ['All'];
  final List<String> _availableStatuses = [];

  // Scroll controllers for synchronized scrolling
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _extractAvailableFilters();
    _applyFilters();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _extractAvailableFilters() {
    final grades = <String>{'All'};
    final statuses = <String>{'All'};
    final schoolYears = <String>{};

    // Combine baseline and endline students for filter extraction
    final allStudents = [...widget.baselineStudents, ...widget.endlineStudents];

    for (final student in allStudents) {
      // Extract school year - ensure we get the correct field name
      final year = student['academic_year']?.toString() ??
          student['school_year']?.toString() ??
          student['year']?.toString() ??
          '';
      if (year.isNotEmpty && year != 'null') schoolYears.add(year);

      // Extract grade - check multiple possible field names
      final grade = student['grade_level']?.toString() ??
          student['grade']?.toString() ??
          student['class_level']?.toString() ??
          'Unknown';
      if (grade.isNotEmpty && grade != 'Unknown' && grade != 'null') {
        grades.add(grade);
      }

      // Add SPED option if student is SPED
      final isSped = student['is_sped'] == true ||
          student['sped'] == true ||
          student['special_education'] == true ||
          (student['is_sped']?.toString().toLowerCase() == 'true') ||
          (student['sped']?.toString().toLowerCase() == 'true');
      if (isSped) {
        grades.add('SPED');
      }

      // Extract status - filter out unwanted statuses
      final status = student['nutritional_status']?.toString() ??
          student['status']?.toString() ??
          'Unknown';
      if (status != '0:4' &&
          status != '8:11' &&
          status.isNotEmpty &&
          status != 'null') {
        statuses.add(status);
      }
    }

    // Sort years in descending order (newest first)
    final sortedYears = schoolYears.toList()..sort((a, b) => b.compareTo(a));

    // Sort grades: All first, then SPED, then numeric grades
    final sortedGrades = grades.toList()
      ..sort((a, b) {
        if (a == 'All') return -1;
        if (b == 'All') return 1;
        if (a == 'SPED') return -1;
        if (b == 'SPED') return 1;

        // Try to parse as numbers for numeric comparison
        final aNum = int.tryParse(a);
        final bNum = int.tryParse(b);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        return a.compareTo(b);
      });

    setState(() {
      _availableSchoolYears =
          sortedYears.isNotEmpty ? sortedYears : ['2024-2025'];
      _selectedSchoolYear =
          _availableSchoolYears.isNotEmpty ? _availableSchoolYears.first : '';

      _availableGrades.clear();
      _availableGrades.addAll(sortedGrades);

      _availableStatuses.clear();
      _availableStatuses.addAll(
        statuses.toList()
          ..sort((a, b) {
            if (a == 'All') return -1;
            if (b == 'All') return 1;
            return a.compareTo(b);
          }),
      );
    });
  }

  List<Map<String, dynamic>> _getStudentsForSelectedPeriod() {
    switch (_selectedAssessmentPeriod) {
      case 'Baseline':
        return widget.baselineStudents;
      case 'Endline':
        return widget.endlineStudents;
      default:
        return widget.baselineStudents;
    }
  }

  bool _matchesGradeFilter(Map<String, dynamic> student) {
    if (_selectedGradeFilter == 'All') return true;

    final grade = student['grade_level']?.toString() ??
        student['grade']?.toString() ??
        student['class_level']?.toString() ??
        '';

    // Check SPED status
    final isSped = student['is_sped'] == true ||
        student['sped'] == true ||
        student['special_education'] == true ||
        (student['is_sped']?.toString().toLowerCase() == 'true') ||
        (student['sped']?.toString().toLowerCase() == 'true');

    if (_selectedGradeFilter == 'SPED') {
      return isSped;
    }

    // Check if grade matches selected grade
    return grade == _selectedGradeFilter;
  }

  bool _matchesStatusFilter(Map<String, dynamic> student) {
    if (_selectedStatusFilter == 'All') return true;

    final status = student['nutritional_status']?.toString() ??
        student['status']?.toString() ??
        'Unknown';

    // Filter out unwanted statuses
    if (status == '0:4' || status == '8:11' || status == 'null') return false;

    return status == _selectedStatusFilter;
  }

  bool _matchesSchoolYearFilter(Map<String, dynamic> student) {
    if (_selectedSchoolYear.isEmpty || _selectedSchoolYear == 'All')
      return true;

    final studentYear = student['academic_year']?.toString() ??
        student['school_year']?.toString() ??
        student['year']?.toString() ??
        '';

    return studentYear == _selectedSchoolYear;
  }

  void _applyFilters() {
    setState(() {
      final periodStudents = _getStudentsForSelectedPeriod();

      if (periodStudents.isEmpty) {
        _filteredStudents = [];
        return;
      }

      _filteredStudents = periodStudents.where((student) {
        // Apply all filters
        if (!_matchesSchoolYearFilter(student)) return false;
        if (!_matchesGradeFilter(student)) return false;
        if (!_matchesStatusFilter(student)) return false;

        return true;
      }).toList();
    });
  }

  Widget _buildCompactStatsBar() {
    final totalStudents = _filteredStudents.length;
    final totalMale = _filteredStudents.where((s) {
      final sex = s['sex']?.toString().toLowerCase() ??
          s['gender']?.toString().toLowerCase() ??
          '';
      return sex == 'male' || sex == 'm';
    }).length;
    final totalFemale = _filteredStudents.where((s) {
      final sex = s['sex']?.toString().toLowerCase() ??
          s['gender']?.toString().toLowerCase() ??
          '';
      return sex == 'female' || sex == 'f';
    }).length;

    // At-risk calculation
    final atRiskCount = _filteredStudents.where((s) {
      final status = s['nutritional_status']?.toString().toLowerCase() ??
          s['status']?.toString().toLowerCase() ??
          '';
      return status.contains('wasted') ||
          status.contains('severely wasted') ||
          status.contains('severely stunted') ||
          status.contains('stunted') ||
          status.contains('underweight');
    }).length;

    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Students
          _buildStatItem(
            'Total',
            totalStudents.toString(),
            Colors.blue,
            Icons.people,
          ),
          _buildVerticalDivider(),
          // Male
          _buildStatItem('Male', totalMale.toString(), Colors.blue, Icons.male),
          _buildVerticalDivider(),
          // Female
          _buildStatItem(
            'Female',
            totalFemale.toString(),
            Colors.pink,
            Icons.female,
          ),
          _buildVerticalDivider(),
          // At Risk
          _buildStatItem(
            'At Risk',
            atRiskCount.toString(),
            Colors.orange,
            Icons.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 0.5,
      height: 35,
      color: Colors.grey[300],
    );
  }

  Widget _buildCompactFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Compact horizontal filter layout - all 4 filters in one row
          Row(
            children: [
              // School Year filter
              Expanded(
                child: _buildCompactFilter(
                  'School Year',
                  _selectedSchoolYear,
                  _availableSchoolYears,
                  (value) {
                    if (value != null) {
                      setState(() {
                        _selectedSchoolYear = value;
                        _applyFilters();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Period filter
              Expanded(
                child: _buildCompactFilter(
                  'Period',
                  _selectedAssessmentPeriod,
                  _availablePeriods,
                  (value) {
                    if (value != null) {
                      setState(() {
                        _selectedAssessmentPeriod = value;
                        _applyFilters();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Grade filter (including SPED)
              Expanded(
                child: _buildCompactFilter(
                  'Grade',
                  _selectedGradeFilter,
                  _availableGrades,
                  (value) {
                    if (value != null) {
                      setState(() {
                        _selectedGradeFilter = value;
                        _applyFilters();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Status filter
              Expanded(
                child: _buildCompactFilter(
                  'Status',
                  _selectedStatusFilter,
                  _availableStatuses,
                  (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatusFilter = value;
                        _applyFilters();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilter(
    String title,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 30),
                  iconSize: 28,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  items: items.map((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Learner Records - ${widget.schoolName}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A4D7A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 1,
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            // Compact Filter Section (all filters in one row)
            _buildCompactFilterSection(),

            // Compact Stats Bar
            _buildCompactStatsBar(),

            // Students Table - Expanded to fill remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: _buildStudentsTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTable() {
    // Updated columns without SPED column
    final columns = [
      'Student Name',
      'Gender',
      'Birthday',
      'Age',
      'Height (cm)',
      'Weight (kg)',
      'BMI',
      'Nutritional Status',
      'HFA Status',
      'Grade Level',
    ];

    // Calculate available width and distribute proportionally
    final availableWidth =
        MediaQuery.of(context).size.width - 40; // Account for padding
    final columnWidths = [
      availableWidth * 0.20,
      availableWidth * 0.07,
      availableWidth * 0.11,
      availableWidth * 0.06,
      availableWidth * 0.08,
      availableWidth * 0.08,
      availableWidth * 0.07,
      availableWidth * 0.12,
      availableWidth * 0.12,
      availableWidth * 0.09,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header - Fixed
          Container(
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFF1A4D7A),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: availableWidth,
                child: Row(
                  children: List.generate(columns.length, (index) {
                    final column = columns[index];
                    final width = columnWidths[index];

                    return SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: index < columns.length - 1
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          column,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          // Table Content - Scrollable
          Expanded(
            child: _filteredStudents.isEmpty
                ? _buildEmptyState()
                : Scrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      child: SizedBox(
                        width: availableWidth,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            final isEven = index % 2 == 0;

                            return Container(
                              height: 58,
                              decoration: BoxDecoration(
                                color: isEven ? Colors.white : Colors.grey[50],
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200]!,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Student Name
                                  SizedBox(
                                    width: columnWidths[0],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          student['learner_name']?.toString() ??
                                              student['name']?.toString() ??
                                              student['student_name']
                                                  ?.toString() ??
                                              'Unknown',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Gender
                                  SizedBox(
                                    width: columnWidths[1],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _formatGender(
                                            student['sex']?.toString() ??
                                                student['gender']?.toString(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Birthday
                                  SizedBox(
                                    width: columnWidths[2],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _formatDate(
                                              student['date_of_birth'] ??
                                                  student['birthday'] ??
                                                  student['dob']),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Age
                                  SizedBox(
                                    width: columnWidths[3],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          student['age']?.toString() ?? '-',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Height
                                  SizedBox(
                                    width: columnWidths[4],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _formatHeight(
                                            student['height_cm'] ??
                                                student['height'] ??
                                                student['height_value'],
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Weight
                                  SizedBox(
                                    width: columnWidths[5],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _formatWeight(
                                            student['weight_kg'] ??
                                                student['weight'] ??
                                                student['weight_value'],
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // BMI
                                  SizedBox(
                                    width: columnWidths[6],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _formatBMI(student['bmi']),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Nutritional Status
                                  SizedBox(
                                    width: columnWidths[7],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 90,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              student['nutritional_status']
                                                      ?.toString() ??
                                                  student['status']
                                                      ?.toString() ??
                                                  'Unknown',
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              student['nutritional_status']
                                                      ?.toString() ??
                                                  student['status']
                                                      ?.toString() ??
                                                  'Unknown',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // HFA Status
                                  SizedBox(
                                    width: columnWidths[8],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 90,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getHFAStatusColor(
                                              _calculateHFAStatus(student),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              _calculateHFAStatus(student),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Grade Level
                                  SizedBox(
                                    width: columnWidths[9],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Center(
                                        child: Text(
                                          student['grade_level']?.toString() ??
                                              student['grade']?.toString() ??
                                              student['class_level']
                                                  ?.toString() ??
                                              'Unknown',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'No students found',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Try adjusting your filter settings',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty || gender == 'null') return '-';
    final lowerGender = gender.toLowerCase();
    if (lowerGender == 'male' || lowerGender == 'm') return 'M';
    if (lowerGender == 'female' || lowerGender == 'f') return 'F';
    return gender;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dateString = date.toString();
      if (dateString.isEmpty || dateString == 'null') return '-';
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    } catch (e) {
      return '-';
    }
  }

  String _formatHeight(dynamic height) {
    if (height == null) return '-';
    try {
      if (height is double) {
        return height.toStringAsFixed(1);
      }
      if (height is int) {
        return height.toDouble().toStringAsFixed(1);
      }
      final heightValue = double.tryParse(height.toString());
      return heightValue?.toStringAsFixed(1) ?? '-';
    } catch (e) {
      return '-';
    }
  }

  String _formatWeight(dynamic weight) {
    if (weight == null) return '-';
    try {
      if (weight is double) {
        return weight.toStringAsFixed(1);
      }
      if (weight is int) {
        return weight.toDouble().toStringAsFixed(1);
      }
      final weightValue = double.tryParse(weight.toString());
      return weightValue?.toStringAsFixed(1) ?? '-';
    } catch (e) {
      return '-';
    }
  }

  String _formatBMI(dynamic bmi) {
    if (bmi == null) return '-';
    try {
      if (bmi is double) {
        return bmi.toStringAsFixed(1);
      }
      if (bmi is int) {
        return bmi.toDouble().toStringAsFixed(1);
      }
      final bmiValue = double.tryParse(bmi.toString());
      return bmiValue?.toStringAsFixed(1) ?? '-';
    } catch (e) {
      return '-';
    }
  }

  String _calculateHFAStatus(Map<String, dynamic> student) {
    final height = student['height_cm'] as double? ??
        student['height'] as double? ??
        (student['height'] is int
            ? (student['height'] as int).toDouble()
            : null);
    final age = student['age'] as int? ??
        (student['age'] is String
            ? int.tryParse(student['age'] as String)
            : null);

    if (height == null || age == null || age < 5 || age > 18) {
      return '-';
    }

    final expectedHeight = _getExpectedHeightForAge(age);
    final heightRatio = height / expectedHeight;

    if (heightRatio < 0.85) return 'Severely Stunted';
    if (heightRatio < 0.95) return 'Stunted';
    if (heightRatio <= 1.05) return 'Normal';
    return 'Tall';
  }

  double _getExpectedHeightForAge(int age) {
    final Map<int, double> heightStandards = {
      5: 110.0,
      6: 116.0,
      7: 121.0,
      8: 127.0,
      9: 132.0,
      10: 138.0,
      11: 143.0,
      12: 149.0,
      13: 156.0,
      14: 163.0,
      15: 168.0,
      16: 172.0,
      17: 175.0,
      18: 176.0,
    };
    return heightStandards[age] ?? (100 + (age * 5)).toDouble();
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('normal')) {
      return Colors.green;
    } else if (lowerStatus.contains('wasted')) {
      if (lowerStatus.contains('severely')) {
        return Colors.red;
      }
      return Colors.orange;
    } else if (lowerStatus.contains('stunted')) {
      if (lowerStatus.contains('severely')) {
        return Colors.red[300]!;
      }
      return Colors.orange[300]!;
    } else if (lowerStatus.contains('overweight')) {
      return Colors.amber[700]!;
    } else if (lowerStatus.contains('obese')) {
      return Colors.deepOrange;
    } else if (lowerStatus.contains('underweight')) {
      return Colors.orange[400]!;
    } else if (lowerStatus.contains('tall')) {
      return Colors.blue;
    }
    return Colors.grey;
  }

  Color _getHFAStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('normal')) {
      return Colors.green;
    } else if (lowerStatus.contains('stunted')) {
      if (lowerStatus.contains('severely')) {
        return Colors.red;
      }
      return Colors.orange;
    } else if (lowerStatus.contains('tall')) {
      return Colors.blue;
    }
    return Colors.grey;
  }
}
