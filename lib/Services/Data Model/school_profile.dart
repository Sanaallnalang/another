// school_profile.dart - UPDATED WITH DYNAMIC SCHOOL YEAR
import 'package:district_dev/Services/Data%20Model/acad_schyear_manager.dart';
import 'package:district_dev/Services/Data%20Model/exce_external_cleaner.dart';

class SchoolProfile {
  final String id;
  final String schoolName;
  final String schoolId;
  final String district;
  final String region;
  final String address;
  final String principalName;
  final String sbfpCoordinator;
  final String platformUrl;
  final String contactNumber;
  // REMOVED: final String academicYear; // No longer hardcoded
  final int totalLearners;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastUpdated;

  // Cloud sync fields
  final String cloudId;
  final DateTime lastCloudSync;
  final bool cloudEnabled;
  final String syncFrequency;
  final String cloudStatus;

  // NEW: Multi-year support
  final List<String> activeAcademicYears; // Multiple active years
  final String primaryAcademicYear; // Main year for operations

  SchoolProfile({
    required this.id,
    required this.schoolName,
    required this.schoolId,
    required this.district,
    required this.region,
    required this.address,
    required this.principalName,
    required this.sbfpCoordinator,
    required this.platformUrl,
    required this.contactNumber,
    // REMOVED: required this.academicYear,
    required this.totalLearners,
    required this.createdAt,
    required this.updatedAt,
    required this.lastUpdated,
    // Cloud sync fields with defaults
    this.cloudId = '',
    DateTime? lastCloudSync,
    this.cloudEnabled = false,
    this.syncFrequency = 'manual',
    this.cloudStatus = 'inactive',
    // NEW: Multi-year fields
    List<String>? activeAcademicYears,
    String? primaryAcademicYear,
  })  : lastCloudSync = lastCloudSync ?? DateTime.now(),
        activeAcademicYears =
            activeAcademicYears ?? [AcademicYearManager.getCurrentSchoolYear()],
        primaryAcademicYear =
            primaryAcademicYear ?? AcademicYearManager.getCurrentSchoolYear();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_name': schoolName,
      'school_id': schoolId,
      'district': district,
      'region': region,
      'address': address,
      'principal_name': principalName,
      'sbfp_coordinator': sbfpCoordinator,
      'platform_url': platformUrl,
      'contact_number': contactNumber,
      // REMOVED: 'academic_year': academicYear,
      'total_learners': totalLearners,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_updated': lastUpdated.toIso8601String(),
      // Cloud sync fields
      'cloud_id': cloudId,
      'last_cloud_sync': lastCloudSync.toIso8601String(),
      'cloud_enabled': cloudEnabled ? 1 : 0,
      'sync_frequency': syncFrequency,
      'cloud_status': cloudStatus,
      // NEW: Multi-year fields
      'active_academic_years': activeAcademicYears.join(','),
      'primary_academic_year': primaryAcademicYear,
    };
  }

  factory SchoolProfile.fromMap(Map<String, dynamic> map) {
    // NEW: Parse multi-year fields
    final activeYearsString = map['active_academic_years']?.toString() ?? '';
    final activeYears = activeYearsString.isNotEmpty
        ? activeYearsString.split(',')
        : [AcademicYearManager.getCurrentSchoolYear()];

    final primaryYear = map['primary_academic_year']?.toString() ??
        AcademicYearManager.getCurrentSchoolYear();

    return SchoolProfile(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      schoolName: map['school_name'] ?? '',
      schoolId: map['school_id'] ?? '',
      district: map['district'] ?? '',
      region: map['region'] ?? '',
      address: map['address'] ?? '',
      principalName: map['principal_name'] ?? '',
      sbfpCoordinator: map['sbfp_coordinator'] ?? '',
      platformUrl: map['platform_url'] ?? '',
      contactNumber: map['contact_number'] ?? '',
      // REMOVED: academicYear: map['academic_year'] ?? '2024-2025',
      totalLearners: map['total_learners'] ?? 0,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      lastUpdated: DateTime.parse(
        map['last_updated'] ?? DateTime.now().toIso8601String(),
      ),
      // Cloud sync fields
      cloudId: map['cloud_id'] ?? '',
      lastCloudSync: map['last_cloud_sync'] != null
          ? DateTime.parse(map['last_cloud_sync'])
          : DateTime.now(),
      cloudEnabled: (map['cloud_enabled'] ?? 0) == 1,
      syncFrequency: map['sync_frequency'] ?? 'manual',
      cloudStatus: map['cloud_status'] ?? 'inactive',
      // NEW: Multi-year fields
      activeAcademicYears: activeYears,
      primaryAcademicYear: primaryYear,
    );
  }

  // Create from SchoolProfileImport (Excel data) - UPDATED
  factory SchoolProfile.fromImport(SchoolProfileImport import) {
    // ignore: unused_local_variable
    final currentYear = AcademicYearManager.getCurrentSchoolYear();
    final extractedYear = import.schoolYear;

    // NEW: Resolve school year intelligently
    final resolvedYear = AcademicYearManager.resolveImportSchoolYear(
      extractedYear,
      allowPastYears: true,
      maxPastYears: 5,
    );

    return SchoolProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      schoolName: import.schoolName,
      schoolId: import.schoolId ?? '',
      district: import.district,
      region: import.region ?? '',
      address: '',
      principalName: import.schoolHead ?? '',
      sbfpCoordinator: import.coordinator ?? '',
      platformUrl: '',
      contactNumber: '',
      totalLearners: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      // NEW: Set up academic years
      activeAcademicYears: [resolvedYear],
      primaryAcademicYear: resolvedYear,
    );
  }

  // Create a copyWith method for updates - UPDATED
  SchoolProfile copyWith({
    String? schoolName,
    String? schoolId,
    String? district,
    String? region,
    String? address,
    String? principalName,
    String? sbfpCoordinator,
    String? platformUrl,
    String? contactNumber,
    int? totalLearners,
    // Cloud sync fields
    String? cloudId,
    DateTime? lastCloudSync,
    bool? cloudEnabled,
    String? syncFrequency,
    String? cloudStatus,
    // NEW: Multi-year fields
    List<String>? activeAcademicYears,
    String? primaryAcademicYear,
  }) {
    return SchoolProfile(
      id: id,
      schoolName: schoolName ?? this.schoolName,
      schoolId: schoolId ?? this.schoolId,
      district: district ?? this.district,
      region: region ?? this.region,
      address: address ?? this.address,
      principalName: principalName ?? this.principalName,
      sbfpCoordinator: sbfpCoordinator ?? this.sbfpCoordinator,
      platformUrl: platformUrl ?? this.platformUrl,
      contactNumber: contactNumber ?? this.contactNumber,
      totalLearners: totalLearners ?? this.totalLearners,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      // Cloud sync fields
      cloudId: cloudId ?? this.cloudId,
      lastCloudSync: lastCloudSync ?? this.lastCloudSync,
      cloudEnabled: cloudEnabled ?? this.cloudEnabled,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      cloudStatus: cloudStatus ?? this.cloudStatus,
      // NEW: Multi-year fields
      activeAcademicYears: activeAcademicYears ?? this.activeAcademicYears,
      primaryAcademicYear: primaryAcademicYear ?? this.primaryAcademicYear,
    );
  }

  // NEW: Academic year management methods
  bool hasAcademicYear(String schoolYear) {
    return activeAcademicYears.contains(schoolYear);
  }

  SchoolProfile addAcademicYear(String schoolYear) {
    if (hasAcademicYear(schoolYear)) return this;

    final newYears = List<String>.from(activeAcademicYears)..add(schoolYear);
    return copyWith(activeAcademicYears: newYears);
  }

  SchoolProfile setPrimaryAcademicYear(String schoolYear) {
    if (!hasAcademicYear(schoolYear)) {
      // Add the year first
      return addAcademicYear(
        schoolYear,
      ).copyWith(primaryAcademicYear: schoolYear);
    }

    return copyWith(primaryAcademicYear: schoolYear);
  }

  List<Map<String, dynamic>> getAcademicYearInfo() {
    return activeAcademicYears.map((year) {
      return AcademicYearManager.getSchoolYearInfo(year);
    }).toList();
  }

  // Cloud sync helper methods - UPDATED with academic year awareness
  bool get canSyncToCloud => cloudEnabled && cloudStatus == 'active';

  bool get needsCloudSync {
    if (!cloudEnabled) return false;
    final now = DateTime.now();
    final hoursSinceLastSync = now.difference(lastCloudSync).inHours;

    switch (syncFrequency) {
      case 'daily':
        return hoursSinceLastSync >= 24;
      case 'weekly':
        return hoursSinceLastSync >= 168;
      case 'manual':
      default:
        return false;
    }
  }

  // Validation methods for cloud sync - UPDATED
  bool get isValidForCloudSync {
    return schoolName.isNotEmpty &&
        district.isNotEmpty &&
        activeAcademicYears.isNotEmpty;
  }

  // Get sync status description
  String get syncStatusDescription {
    if (!cloudEnabled) return 'Cloud sync disabled';
    if (cloudStatus != 'active') return 'Cloud sync inactive';

    final now = DateTime.now();
    final hoursSinceLastSync = now.difference(lastCloudSync).inHours;

    if (hoursSinceLastSync < 1) return 'Synced just now';
    if (hoursSinceLastSync < 24) return 'Synced ${hoursSinceLastSync}h ago';
    if (hoursSinceLastSync < 168) {
      return 'Synced ${(hoursSinceLastSync / 24).round()}d ago';
    }

    return 'Synced ${(hoursSinceLastSync / 168).round()}w ago';
  }

  // NEW: Get display information
  String get displayInfo {
    return '$schoolName • $district • Primary: $primaryAcademicYear';
  }

  // NEW: Check if data can be modified for a specific year
  bool canModifyData(String schoolYear) {
    final yearInfo = AcademicYearManager.getSchoolYearInfo(schoolYear);
    return yearInfo['period'] != 'Archived';
  }
}
