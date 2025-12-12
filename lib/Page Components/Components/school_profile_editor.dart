// school_profile_editor.dart
import 'package:district_dev/Services/Data%20Model/school_profile.dart';
import 'package:flutter/material.dart';

class SchoolProfileEditor extends StatefulWidget {
  final Function(SchoolProfile) onUpdate;
  final Function() onCancel;
  final SchoolProfile schoolProfile;

  const SchoolProfileEditor({
    super.key,
    required this.onUpdate,
    required this.onCancel,
    required this.schoolProfile,
  });

  @override
  State<SchoolProfileEditor> createState() => _SchoolProfileEditorState();
}

class _SchoolProfileEditorState extends State<SchoolProfileEditor> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String _schoolName = '';
  String _schoolId = '';
  String _schoolDistrict = 'Department Of Education';
  String _schoolRegion = '';
  String _schoolAddress = '';
  String _principalName = '';
  String _sbfpCoordinator = '';
  String _viewingPlatformUrl = '';
  String _contactNumber = '';

  // Available regions
  final List<String> _regions = [
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

  @override
  void initState() {
    super.initState();
    // Initialize form with existing profile data
    _schoolName = widget.schoolProfile.schoolName;
    _schoolId = widget.schoolProfile.schoolId;
    _schoolDistrict = widget.schoolProfile.district;
    _schoolRegion = widget.schoolProfile.region.isNotEmpty
        ? widget.schoolProfile.region
        : _regions.first; // Default to first region if empty
    _schoolAddress = widget.schoolProfile.address;
    _principalName = widget.schoolProfile.principalName;
    _sbfpCoordinator = widget.schoolProfile.sbfpCoordinator;
    _viewingPlatformUrl = widget.schoolProfile.platformUrl;
    _contactNumber = widget.schoolProfile.contactNumber;
  }

  void _updateProfile() {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = widget.schoolProfile.copyWith(
        schoolName: _schoolName,
        schoolId: _schoolId,
        district: _schoolDistrict,
        region: _schoolRegion,
        address: _schoolAddress,
        principalName: _principalName,
        sbfpCoordinator: _sbfpCoordinator,
        platformUrl: _viewingPlatformUrl,
        contactNumber: _contactNumber,
      );

      widget.onUpdate(updatedProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact Header - Updated to match creator style
              Row(
                children: [
                  const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF39D2C0),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Edit School Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.black,
                    ),
                    onPressed: widget.onCancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // School Information - Compact
                    _buildSchoolInfoSection(),

                    const SizedBox(height: 16),

                    // School Personnel - Compact
                    _buildPersonnelSection(),

                    const SizedBox(height: 20),

                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'School Information',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        _buildCompactTextField(
          initialValue: _schoolName,
          label: 'School Name',
          icon: Icons.school_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'School name is required';
            }
            return null;
          },
          onChanged: (value) => _schoolName = value,
        ),
        const SizedBox(height: 12),
        _buildCompactTextField(
          initialValue: _schoolId,
          label: 'School ID',
          icon: Icons.numbers_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'School ID is required';
            }
            return null;
          },
          onChanged: (value) => _schoolId = value,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCompactTextField(
                initialValue: _schoolDistrict,
                label: 'District',
                icon: Icons.location_city_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'District is required';
                  }
                  return null;
                },
                onChanged: (value) => _schoolDistrict = value,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactDropdown(
                value: _schoolRegion.isNotEmpty ? _schoolRegion : null,
                label: 'Region',
                icon: Icons.map_outlined,
                items: _regions,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Region is required';
                  }
                  return null;
                },
                onChanged: (value) => _schoolRegion = value ?? '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCompactTextField(
          initialValue: _schoolAddress,
          label: 'Address',
          icon: Icons.location_on_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Address is required';
            }
            return null;
          },
          onChanged: (value) => _schoolAddress = value,
        ),
      ],
    );
  }

  Widget _buildPersonnelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'School Personnel',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCompactTextField(
                initialValue: _principalName,
                label: 'Principal',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Principal name is required';
                  }
                  return null;
                },
                onChanged: (value) => _principalName = value,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactTextField(
                initialValue: _sbfpCoordinator,
                label: 'SBFP Coordinator',
                icon: Icons.medical_services_outlined,
                onChanged: (value) => _sbfpCoordinator = value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCompactTextField(
          initialValue: _contactNumber,
          label: 'Contact Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          onChanged: (value) => _contactNumber = value,
        ),
        const SizedBox(height: 12),
        _buildCompactTextField(
          initialValue: _viewingPlatformUrl,
          label: 'Platform URL',
          icon: Icons.link_rounded,
          keyboardType: TextInputType.url,
          hintText: 'https://your-school-platform.com',
          onChanged: (value) => _viewingPlatformUrl = value,
        ),
      ],
    );
  }

  Widget _buildCompactTextField({
    required String initialValue,
    required String label,
    required IconData icon,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return TextFormField(
      initialValue: initialValue,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, size: 18, color: Colors.black54),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black54),
        alignLabelWithHint: true,
      ),
      style: const TextStyle(fontSize: 13, color: Colors.black),
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildCompactDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: Colors.white,
      style: const TextStyle(fontSize: 13, color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, size: 18, color: Colors.black54),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
        alignLabelWithHint: true,
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: const TextStyle(fontSize: 13, color: Colors.black),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onCancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 13, color: Colors.black),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _updateProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF39D2C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Update Profile', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
