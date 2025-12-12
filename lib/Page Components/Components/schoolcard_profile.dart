import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:district_dev/Services/Database/database_service.dart';
import 'package:flutter/material.dart';

class SchoolProfileCard extends StatelessWidget {
  final SchoolProfile profile;
  final VoidCallback? onTap;
  final bool isSelected;
  final DatabaseService dbService;

  const SchoolProfileCard({
    super.key,
    required this.profile,
    this.onTap,
    this.isSelected = false,
    required this.dbService,
    required isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSchoolDataStatus(profile.id),
      builder: (context, snapshot) {
        final hasImportedData = snapshot.data?['has_imported_data'] ?? false;
        final studentCount = snapshot.data?['student_count'] ?? 0;
        final baselineCount = snapshot.data?['baseline_count'] ?? 0;
        final endlineCount = snapshot.data?['endline_count'] ?? 0;
        final academicYears = snapshot.data?['academic_years'] ?? [];
        final importHistoryCount = snapshot.data?['import_history_count'] ?? 0;

        final hasCompleteBasicInfo = _hasCompleteSchoolData(profile);
        final isDataComplete = hasCompleteBasicInfo && hasImportedData;

        return Card(
          margin: EdgeInsets.zero,
          elevation: 4,
          color: isSelected ? Colors.blue[50] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? Color(0xFF1A4D7A) : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: () {
              _showDataStatusDialog(
                context,
                profile,
                hasImportedData,
                studentCount,
                baselineCount,
                endlineCount,
                academicYears,
                importHistoryCount,
                isDataComplete,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with school name and status icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // School Name
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF1A4D7A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            profile.schoolName.isNotEmpty
                                ? profile.schoolName
                                : 'Unnamed School',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A4D7A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Dynamic Status Icon
                      _buildStatusIcon(isDataComplete),
                    ],
                  ),
                  SizedBox(height: 12),

                  // School Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // School ID
                        _buildDetailContainer(
                          'School ID:',
                          profile.schoolId.isNotEmpty
                              ? profile.schoolId
                              : 'Not set',
                        ),
                        SizedBox(height: 6),

                        // District and Region
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailContainer(
                                'District:',
                                profile.district.isNotEmpty
                                    ? profile.district
                                    : 'No District',
                              ),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: _buildDetailContainer(
                                'Region:',
                                profile.region.isNotEmpty
                                    ? profile.region
                                    : 'No Region',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),

                        // Principal
                        _buildDetailContainer(
                          'Principal:',
                          profile.principalName.isNotEmpty
                              ? profile.principalName
                              : 'No Principal',
                        ),
                        SizedBox(height: 6),

                        // SBFP Coordinator (if available)
                        if (profile.sbfpCoordinator.isNotEmpty) ...[
                          _buildDetailContainer(
                            'SBFP Coordinator:',
                            profile.sbfpCoordinator,
                          ),
                          SizedBox(height: 6),
                        ],

                        // Academic Years
                        if (academicYears.isNotEmpty) ...[
                          _buildDetailContainer(
                            'Academic Years:',
                            academicYears.length > 2
                                ? '${academicYears.length} years'
                                : academicYears.join(', '),
                          ),
                          SizedBox(height: 6),
                        ],

                        // Data Status
                        _buildDataStatusRow(
                          hasImportedData,
                          studentCount,
                          baselineCount,
                          endlineCount,
                        ),
                        SizedBox(height: 6),

                        // Import History
                        if (importHistoryCount > 0) ...[
                          _buildDetailContainer(
                            'Import History:',
                            '$importHistoryCount imports',
                          ),
                          SizedBox(height: 6),
                        ],

                        // Status Badge - positioned at the bottom
                        Align(
                          alignment: Alignment.bottomRight,
                          child: _buildStatusBadge(
                            isDataComplete,
                            hasCompleteBasicInfo,
                            hasImportedData,
                            academicYears.isNotEmpty ? academicYears.length : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataStatusRow(
    bool hasImportedData,
    int studentCount,
    int baselineCount,
    int endlineCount,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            hasImportedData ? Icons.check_circle : Icons.warning,
            size: 16,
            color: hasImportedData ? Colors.green : Colors.orange,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasImportedData
                      ? '$studentCount total students'
                      : 'No student data',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasImportedData ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasImportedData && (baselineCount > 0 || endlineCount > 0))
                  Text(
                    '($baselineCount baseline, $endlineCount endline)',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isDataComplete) {
    Color iconColor;
    Color backgroundColor;
    IconData iconData;
    String tooltip;

    if (isDataComplete) {
      iconColor = Colors.green;
      backgroundColor = Colors.green[50]!;
      iconData = Icons.check_circle;
      tooltip = 'Data Complete - School has all information and imported data';
    } else {
      iconColor = Colors.orange;
      backgroundColor = Colors.orange[50]!;
      iconData = Icons.warning_amber_rounded;
      tooltip = 'Data Incomplete - Missing information or no imported data';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: iconColor, width: 2),
        ),
        child: Icon(iconData, color: iconColor, size: 16),
      ),
    );
  }

  Widget _buildDetailContainer(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    bool isDataComplete,
    bool hasBasicInfo,
    bool hasImportedData,
    int yearCount,
  ) {
    Color badgeColor;
    Color textColor;
    String statusText;
    String tooltip;

    if (isDataComplete) {
      badgeColor = Colors.green;
      textColor = Colors.white;
      statusText = yearCount > 1 ? 'Complete ($yearCount yrs)' : 'Complete';
      tooltip = 'All school information and student data is complete';
    } else if (!hasBasicInfo) {
      badgeColor = Colors.red;
      textColor = Colors.white;
      statusText = 'Missing Info';
      tooltip = 'School profile information is incomplete';
    } else if (!hasImportedData) {
      badgeColor = Colors.orange;
      textColor = Colors.white;
      statusText = 'No Data';
      tooltip = 'School profile complete but no student data imported';
    } else {
      badgeColor = Colors.blue;
      textColor = Colors.white;
      statusText = 'Partial';
      tooltip = 'Some data available but may be incomplete';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDataComplete ? Icons.check_circle : Icons.info_outline,
              size: 14,
              color: textColor,
            ),
            SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Check data status from database
  Future<Map<String, dynamic>> _getSchoolDataStatus(String schoolId) async {
    try {
      // Get baseline and endline student counts
      final baselineStudents = await dbService.getBaselineStudents(schoolId);
      final endlineStudents = await dbService.getEndlineStudents(schoolId);

      final hasImportedData =
          baselineStudents.isNotEmpty || endlineStudents.isNotEmpty;
      final studentCount = baselineStudents.length + endlineStudents.length;

      // Get import history count
      final importHistory = await dbService.getImportHistory(schoolId);
      final importHistoryCount = importHistory.length;

      // Get academic years
      final academicYears = await dbService.getAcademicYearsForSchool(schoolId);

      return {
        'has_imported_data': hasImportedData,
        'student_count': studentCount,
        'baseline_count': baselineStudents.length,
        'endline_count': endlineStudents.length,
        'academic_years': academicYears,
        'import_history_count': importHistoryCount,
      };
    } catch (e) {
      return {
        'has_imported_data': false,
        'student_count': 0,
        'baseline_count': 0,
        'endline_count': 0,
        'academic_years': [],
        'import_history_count': 0,
      };
    }
  }

  // Show detailed data status dialog
  void _showDataStatusDialog(
    BuildContext context,
    SchoolProfile profile,
    bool hasImportedData,
    int studentCount,
    int baselineCount,
    int endlineCount,
    List<dynamic> academicYears,
    int importHistoryCount,
    bool isDataComplete,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('School Data Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'School: ${profile.schoolName}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            _buildStatusRow(
              'Profile Complete',
              _hasCompleteSchoolData(profile),
            ),
            _buildStatusRow('Student Data Imported', hasImportedData),
            if (hasImportedData) ...[
              SizedBox(height: 5),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Total Students: $studentCount'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      size: 16,
                      color: Colors.green,
                    ),
                    SizedBox(width: 8),
                    Text('Baseline: $baselineCount'),
                    SizedBox(width: 16),
                    Icon(Icons.assignment, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Endline: $endlineCount'),
                  ],
                ),
              ),
            ],
            if (academicYears.isNotEmpty) ...[
              SizedBox(height: 5),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Academic Years: ${academicYears.length}'),
                  ],
                ),
              ),
            ],
            if (importHistoryCount > 0) ...[
              SizedBox(height: 5),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Import History: $importHistoryCount records'),
                  ],
                ),
              ),
            ],
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDataComplete ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isDataComplete
                    ? '✅ All data is complete and ready for use'
                    : '⚠️ Some data is missing or not imported',
                style: TextStyle(
                  color:
                      isDataComplete ? Colors.green[800] : Colors.orange[800],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.circle,
            color: status ? Colors.green : Colors.grey,
            size: 16,
          ),
          SizedBox(width: 8),
          Text(label),
          Spacer(),
          Text(
            status ? 'Yes' : 'No',
            style: TextStyle(
              color: status ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasCompleteSchoolData(SchoolProfile profile) {
    return profile.schoolName.isNotEmpty &&
        profile.schoolId.isNotEmpty &&
        profile.district.isNotEmpty &&
        profile.region.isNotEmpty &&
        profile.principalName.isNotEmpty;
  }
}
