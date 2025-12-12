// lib/Components/Charts/district_dashboard.dart
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:district_dev/Services/Database/database_service.dart'
    show DatabaseService;
import 'package:flutter/material.dart';

import 'sp_barchart.dart';
import 'ht_piechart.dart';
import 'stacked_barchart.dart';

class DistrictDashboardContent extends StatelessWidget {
  final List<SchoolProfile> schoolProfiles;
  final List<Map<String, dynamic>> allStudents;
  final Map<String, dynamic> districtStats;

  const DistrictDashboardContent({
    super.key,
    required this.schoolProfiles,
    required this.allStudents,
    required this.districtStats,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen =
            constraints.maxHeight < 800 || constraints.maxWidth < 1200;

        return SingleChildScrollView(child: _buildContent(isSmallScreen));
      },
    );
  }

  Widget _buildContent(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total District Population Section - Compact Row
        _buildTotalDistrictPopulationSection(),
        const SizedBox(height: 16),

        // School Profile Section with Horizontal Scroll
        _buildSchoolProfileSection(),
        const SizedBox(height: 16),

        // District Population Distribution Section
        _buildDistrictPopulationDistributionSection(isSmallScreen),
        const SizedBox(height: 16),

        // Nutritional Status Summary with Stacked Bar Chart
        _buildNutritionalStatusSummary(isSmallScreen),

        // Add some bottom padding for better scrolling
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTotalDistrictPopulationSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'District Population',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Compact Population Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildCompactPopulationStat(
                    'Total Schools',
                    (districtStats['total_schools'] as int?)?.toString() ?? '0',
                    Icons.school,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactPopulationStat(
                    'Male Students',
                    (districtStats['total_male'] as int?)?.toString() ?? '0',
                    Icons.male,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactPopulationStat(
                    'Female Students',
                    (districtStats['total_female'] as int?)?.toString() ?? '0',
                    Icons.female,
                    Colors.pink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactPopulationStat(
                    'Total Students',
                    (districtStats['total_students'] as int?)?.toString() ??
                        '0',
                    Icons.people,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactPopulationStat(
                    'At Risk',
                    (districtStats['at_risk'] as int?)?.toString() ?? '0',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPopulationStat(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolProfileSection() {
    final scrollController = ScrollController();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'School Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () {
                      scrollController.animateTo(
                        scrollController.offset - 200,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: schoolProfiles.length,
                      itemBuilder: (context, index) {
                        final school = schoolProfiles[index];
                        final schoolStudents = allStudents
                            .where((s) => s['school_id'] == school.id)
                            .length;

                        // Add safety check for school name with debug logging
                        final schoolName = school.schoolName;

                        // Debug logging to identify problematic school names
                        if (schoolName.trim().isEmpty) {
                          print(
                            '⚠️ WARNING: Empty school name detected for school ID: ${school.id}',
                          );
                        }

                        final acronym = _generateAcronym(schoolName);

                        return Container(
                          width: 220,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // School Name with Acronym
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      schoolName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue),
                                    ),
                                    child: Text(
                                      acronym,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'District: ${school.district}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Region: ${school.region}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$schoolStudents Students',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                    onPressed: () {
                      scrollController.animateTo(
                        scrollController.offset + 200,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateAcronym(String schoolName) {
    if (schoolName.isEmpty) return 'N/A';

    // Clean the school name - remove extra spaces and trim
    final cleanedName = schoolName.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleanedName.isEmpty) return 'N/A';

    final words = cleanedName.split(' ');

    // Filter out empty words and words that are too short
    final validWords =
        words.where((word) => word.isNotEmpty && word.isNotEmpty).toList();

    if (validWords.isEmpty) {
      // If no valid words, use first 3 characters of the cleaned name
      return cleanedName.length <= 3
          ? cleanedName.toUpperCase()
          : cleanedName.substring(0, 3).toUpperCase();
    }

    if (validWords.length == 1) {
      // For single word names, take first 3 characters
      final singleWord = validWords.first;
      return singleWord.length <= 3
          ? singleWord.toUpperCase()
          : singleWord.substring(0, 3).toUpperCase();
    }

    // For multiple words, take first letter of first 3 words
    final acronym = validWords
        .take(3)
        .map((word) {
          // Safety check for each word
          if (word.isEmpty) return '';
          return word[0];
        })
        .join('')
        .toUpperCase();

    // If somehow we still get empty acronym, fallback
    return acronym.isEmpty ? 'SCH' : acronym;
  }

  Widget _buildDistrictPopulationDistributionSection(bool isSmallScreen) {
    // Prepare student data for gender bar chart
    final studentData = schoolProfiles
        .map((school) {
          // Filter students for this school
          final schoolStudents = allStudents.where((s) {
            final studentSchoolId = s['school_id']?.toString() ?? '';
            return studentSchoolId == school.id;
          }).toList();

          // Count by gender
          final maleCount = schoolStudents.where((s) {
            final sex = s['sex']?.toString().toLowerCase() ?? '';
            return sex == 'male';
          }).length;

          final femaleCount = schoolStudents.where((s) {
            final sex = s['sex']?.toString().toLowerCase() ?? '';
            return sex == 'female';
          }).length;

          return {
            'school': school,
            'male': maleCount,
            'female': femaleCount,
            'total': maleCount + femaleCount,
          };
        })
        .where((data) => ((data['total'] as int?) ?? 0) > 0)
        .toList(); // Only include schools with students

    // Prepare health data for pie chart
    final healthData = _calculateHealthData();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'District Population Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // Use fixed height instead of IntrinsicHeight
            SizedBox(
              height: isSmallScreen ? 600 : 320,
              child: isSmallScreen
                  ? _buildSmallScreenLayout(studentData, healthData)
                  : _buildLargeScreenLayout(studentData, healthData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeScreenLayout(
    List<Map<String, dynamic>> studentData,
    Map<String, int> healthData,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'School Population by Gender',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              // Use fixed height for charts
              SizedBox(
                height: 280,
                child: SchoolPopulationBarChart(studentData: studentData),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Health Status Distribution',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              // Use fixed height for charts
              SizedBox(
                height: 280,
                child: HealthStatusPieChart(
                  severelyWasted: healthData['severelyWasted'] ?? 0,
                  wasted: healthData['wasted'] ?? 0,
                  normal: healthData['normal'] ?? 0,
                  overweight: healthData['overweight'] ?? 0,
                  obese: healthData['obese'] ?? 0,
                  totalStudents: allStudents.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallScreenLayout(
    List<Map<String, dynamic>> studentData,
    Map<String, int> healthData,
  ) {
    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'School Population by Gender',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: SchoolPopulationBarChart(studentData: studentData),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Status Distribution',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: HealthStatusPieChart(
                severelyWasted: healthData['severelyWasted'] ?? 0,
                wasted: healthData['wasted'] ?? 0,
                normal: healthData['normal'] ?? 0,
                overweight: healthData['overweight'] ?? 0,
                obese: healthData['obese'] ?? 0,
                totalStudents: allStudents.length,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutritionalStatusSummary(bool isSmallScreen) {
    final schoolNutritionalData = schoolProfiles
        .map((school) {
          final schoolStudents = allStudents.where((s) {
            final studentSchoolId = s['school_id']?.toString() ?? '';
            return studentSchoolId == school.id;
          });

          final severelyWasted = schoolStudents.where((s) {
            final status =
                s['nutritional_status']?.toString().toLowerCase() ?? '';
            return status.contains('severely wasted');
          }).length;
          final wasted = schoolStudents.where((s) {
            final status =
                s['nutritional_status']?.toString().toLowerCase() ?? '';
            return status.contains('wasted') && !status.contains('severely');
          }).length;
          final normal = schoolStudents.where((s) {
            final status =
                s['nutritional_status']?.toString().toLowerCase() ?? '';
            return status.contains('normal');
          }).length;
          final overweight = schoolStudents.where((s) {
            final status =
                s['nutritional_status']?.toString().toLowerCase() ?? '';
            return status.contains('overweight');
          }).length;
          final obese = schoolStudents.where((s) {
            final status =
                s['nutritional_status']?.toString().toLowerCase() ?? '';
            return status.contains('obese');
          }).length;

          return {
            'school': school,
            'severelyWasted': severelyWasted,
            'wasted': wasted,
            'normal': normal,
            'overweight': overweight,
            'obese': obese,
            'total': schoolStudents.length,
          };
        })
        .where((data) => ((data['total'] as int?) ?? 0) > 0)
        .toList(); // Only include schools with data

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nutritional Status Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: isSmallScreen ? 350 : 320,
              child: NutritionalStackedBarChart(
                schoolNutritionalData: schoolNutritionalData,
                isSmallScreen: isSmallScreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _calculateHealthData() {
    final severelyWasted = allStudents.where((s) {
      final status = s['nutritional_status']?.toString().toLowerCase() ?? '';
      return status.contains('severely wasted');
    }).length;
    final wasted = allStudents.where((s) {
      final status = s['nutritional_status']?.toString().toLowerCase() ?? '';
      return status.contains('wasted') && !status.contains('severely');
    }).length;
    final normal = allStudents.where((s) {
      final status = s['nutritional_status']?.toString().toLowerCase() ?? '';
      return status.contains('normal');
    }).length;
    final overweight = allStudents.where((s) {
      final status = s['nutritional_status']?.toString().toLowerCase() ?? '';
      return status.contains('overweight');
    }).length;
    final obese = allStudents.where((s) {
      final status = s['nutritional_status']?.toString().toLowerCase() ?? '';
      return status.contains('obese');
    }).length;

    return {
      'severelyWasted': severelyWasted,
      'wasted': wasted,
      'normal': normal,
      'overweight': overweight,
      'obese': obese,
    };
  }

  // Optional: Add a method to get school statistics via direct SQL
  // ignore: unused_element
  Future<Map<String, dynamic>> _getSchoolStatisticsDirect(
    String schoolId,
  ) async {
    try {
      final dbService = DatabaseService.instance;
      final db = await dbService.database;

      // DIRECT SQL QUERY FOR SCHOOL STATISTICS
      final sql = '''
      SELECT 
        -- Total students
        (SELECT COUNT(*) FROM baseline_learners WHERE school_id = ?) +
        (SELECT COUNT(*) FROM endline_learners WHERE school_id = ?) as total_students,
        
        -- Male students
        (SELECT COUNT(*) FROM baseline_learners WHERE school_id = ? AND sex = 'Male') +
        (SELECT COUNT(*) FROM endline_learners WHERE school_id = ? AND sex = 'Male') as male_students,
        
        -- Female students
        (SELECT COUNT(*) FROM baseline_learners WHERE school_id = ? AND sex = 'Female') +
        (SELECT COUNT(*) FROM endline_learners WHERE school_id = ? AND sex = 'Female') as female_students,
        
        -- At risk (wasted or severely wasted)
        (
          SELECT COUNT(*) FROM baseline_assessments ba
          JOIN baseline_learners bl ON ba.learner_id = bl.id
          WHERE bl.school_id = ? AND (ba.nutritional_status LIKE '%wasted%' OR ba.nutritional_status LIKE '%severely%')
        ) +
        (
          SELECT COUNT(*) FROM endline_assessments ea
          JOIN endline_learners el ON ea.learner_id = el.id
          WHERE el.school_id = ? AND (ea.nutritional_status LIKE '%wasted%' OR ea.nutritional_status LIKE '%severely%')
        ) as at_risk_students
      ''';

      final result = await db.rawQuery(sql, [
        schoolId, schoolId, // total_students
        schoolId, schoolId, // male_students
        schoolId, schoolId, // female_students
        schoolId, schoolId, // at_risk_students
      ]);

      if (result.isNotEmpty) {
        return {
          'total_students': result.first['total_students'] ?? 0,
          'male_students': result.first['male_students'] ?? 0,
          'female_students': result.first['female_students'] ?? 0,
          'at_risk_students': result.first['at_risk_students'] ?? 0,
        };
      }

      return {
        'total_students': 0,
        'male_students': 0,
        'female_students': 0,
        'at_risk_students': 0,
      };
    } catch (e) {
      print('Error in direct SQL school statistics: $e');
      return {
        'total_students': 0,
        'male_students': 0,
        'female_students': 0,
        'at_risk_students': 0,
      };
    }
  }
}
