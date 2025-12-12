// ignore_for_file: deprecated_member_use
import 'package:district_dev/Pages/archieve_page.dart';
import 'package:district_dev/Pages/final_report.dart';

import '../Pages/nutri_records.dart';
import 'package:flutter/material.dart';
import '../Pages/dashboard.dart';
import '/Pages/school_manager.dart'; // Your school management page

import '../Pages/kill_switch.dart';
import '../Pages/food_page.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
    required this.currentPageIndex,
    required this.onPageChanged,
  });

  final bool isCollapsed;
  final VoidCallback onToggle;
  final int currentPageIndex;
  final Function(int) onPageChanged;

  // Easy-to-manage page configuration
  static final List<SidebarPage> _pages = [
    SidebarPage(
      index: 0,
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      builder: (context) => const Dashboard(),
    ),
  ];

  // Sub-section pages configuration
  static final List<SidebarPage> _subPages = [
    SidebarPage(
      index: 10,
      title: 'Schools',
      icon: Icons.grade_outlined,
      builder: (context) => const SchoolManagement(),
    ),
    SidebarPage(
      index: 12,
      title: 'Nutritional Records',
      icon: Icons.flag_outlined,
      builder: (context) => const NutritionalRecordsPage(),
    ),
    SidebarPage(
      index: 13,
      title: 'Final Priority Report',
      icon: Icons.flag_outlined,
      builder: (context) => const SeverelyWastedReportPage(),
    ),
    SidebarPage(
      index: 14,
      title: 'Archives',
      icon: Icons.file_upload_outlined,
      builder: (context) => const ArchivesPage(),
    ),
    SidebarPage(
      index: 15,
      title: 'Cloud Storage',
      icon: Icons.cloud_outlined,
      builder: (context) => const KillSwitchPage(),
    ),
    SidebarPage(
      index: 17,
      title: 'Kill Switch',
      icon: Icons.search_outlined,
      builder: (context) => const KillSwitchPage(),
    ),
    SidebarPage(
      index: 16,
      title: 'Food Diet',
      icon: Icons.edit_outlined,
      builder: (context) => const FoodDashboard(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 70 : 270,
      decoration: BoxDecoration(
        color: const Color(0xFF0A518F), // Updated background color
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: _buildSidebarContent(context),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Column(
      children: [
        // Toggle button
        _buildToggleButton(),
        const Divider(height: 1, color: Color(0x33FFFFFF)),

        // Menu items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Main navigation items
              ..._pages.map(
                (page) => _buildSidebarItem(
                  icon: page.icon,
                  label: page.title,
                  isCollapsed: isCollapsed,
                  isSelected: currentPageIndex == page.index,
                  onTap: () {
                    onPageChanged(page.index);
                    _navigateToPage(context, page.index);
                  },
                ),
              ),

              // Records expandable submenu
              _buildMenuSection(
                context: context,
                icon: Icons.folder_open,
                label: "Records",
                isCollapsed: isCollapsed,
                subItems: [
                  _buildSubItem("Schools", () {
                    _navigateToSubPage(context, 10); // School
                  }),
                  _buildSubItem("Nutritional Records", () {
                    _navigateToSubPage(context, 12); // Priorities
                  }),
                  _buildSubItem("Final Priority Report", () {
                    _navigateToSubPage(context, 13); // Final Priority Report
                  }),
                ],
              ),

              // Files expandable submenu
              _buildMenuSection(
                context: context,
                icon: Icons.folder_outlined,
                label: "Files",
                isCollapsed: isCollapsed,
                subItems: [
                  _buildSubItem("Archives", () {
                    _navigateToSubPage(context, 14);
                    // Import Data
                  }),
                  _buildSubItem("Kill Switch", () {
                    _navigateToSubPage(context, 17);
                    // Import Data
                  }),
                  _buildSubItem("Food Diet", () {
                    _navigateToSubPage(context, 16);
                    // Import Data
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          IconButton(
            icon: Icon(
              isCollapsed ? Icons.menu_open : Icons.menu,
              color: Colors.white,
              size: 24,
            ),
            onPressed: onToggle,
          ),
          if (!isCollapsed) const SizedBox(width: 8),
          if (!isCollapsed)
            Flexible(
              child: Text(
                'Menu',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isCollapsed,
    required List<Widget> subItems,
  }) {
    if (isCollapsed) {
      return Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(icon, color: Colors.white, size: 22),
              onTap: () {
                _showExpandedMenu(context, label, subItems);
              },
              dense: true,
              minLeadingWidth: 0,
            ),
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ExpansionTile(
            key: Key(label),
            leading: Icon(icon, color: Colors.white, size: 22),
            title: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
            children: subItems,
          ),
        ),
      );
    }
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isCollapsed,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final backgroundColor =
        isSelected ? const Color(0x44FFFFFF) : Colors.transparent;
    final iconColor = Colors.white;
    final textColor = Colors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onHover: (hovering) {
              // Hover effect handled by InkWell
            },
            borderRadius: BorderRadius.circular(8),
            child: isCollapsed
                ? Tooltip(
                    message: label,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: Icon(icon, color: iconColor, size: 22),
                      onTap: onTap,
                      dense: true,
                      minLeadingWidth: 0,
                    ),
                  )
                : ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(icon, color: iconColor, size: 22),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    onTap: onTap,
                    dense: true,
                    minLeadingWidth: 0,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubItem(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              onTap: onTap,
              dense: true,
              minLeadingWidth: 0,
            ),
          ),
        ),
      ),
    );
  }

  void _showExpandedMenu(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        alignment: Alignment.centerLeft,
        insetPadding: const EdgeInsets.only(left: 70),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A518F),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0x33FFFFFF)),
              const SizedBox(height: 8),
              ...items,
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, int pageIndex) {
    // Don't navigate if we're already on the same page
    if (currentPageIndex == pageIndex) {
      return;
    }

    final page = _pages.firstWhere(
      (p) => p.index == pageIndex,
      orElse: () => _pages[0], // fallback to dashboard
    );

    // Use pushReplacement to avoid building up navigation stack
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: page.builder),
    );
  }

  void _navigateToSubPage(BuildContext context, int subPageIndex) {
    final subPage = _subPages.firstWhere(
      (p) => p.index == subPageIndex,
      orElse: () => _subPages[0], // fallback to first sub page
    );

    // Use push to allow back navigation from sub-pages
    Navigator.push(context, MaterialPageRoute(builder: subPage.builder));
  }

  // Helper method to get page title by index
  static String getPageTitle(int index) {
    // Check main pages first
    final mainPage = _pages.firstWhere(
      (p) => p.index == index,
      orElse: () => _pages[0],
    );

    if (mainPage.index == index) {
      return mainPage.title;
    }

    // Check sub pages
    final subPage = _subPages.firstWhere(
      (p) => p.index == index,
      orElse: () => _subPages[0],
    );

    return subPage.title;
  }

  // Easy method to add new main pages
  static void addPage(SidebarPage newPage) {
    _pages.add(newPage);
    // Sort by index to maintain order
    _pages.sort((a, b) => a.index.compareTo(b.index));
  }

  // Easy method to add new sub pages
  static void addSubPage(SidebarPage newSubPage) {
    _subPages.add(newSubPage);
    // Sort by index to maintain order
    _subPages.sort((a, b) => a.index.compareTo(b.index));
  }
}

// Data class for sidebar pages - makes it easy to add new pages
class SidebarPage {
  final int index;
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  const SidebarPage({
    required this.index,
    required this.title,
    required this.icon,
    required this.builder,
  });
}

// Create placeholder pages for all sub-sections
class SchoolGradePage extends StatelessWidget {
  const SchoolGradePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Grade Management'),
        backgroundColor: const Color(0xFF0A518F),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grade, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'School Grade Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Manage school grades and classifications',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentRecordsPage extends StatelessWidget {
  const StudentRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Records'),
        backgroundColor: const Color(0xFF0A518F),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Student Records Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'View and manage student records and information',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class PrioritiesPage extends StatelessWidget {
  const PrioritiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Priorities Management'),
        backgroundColor: const Color(0xFF0A518F),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'School Priorities',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Manage school priorities and focus areas',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class ImportDataPage extends StatelessWidget {
  const ImportDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Data'),
        backgroundColor: const Color(0xFF0A518F),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_upload, size: 64, color: Colors.purple),
            SizedBox(height: 16),
            Text(
              'Data Import',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Import student data from various sources',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchRecordsPage extends StatelessWidget {
  const SearchRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Records'),
        backgroundColor: const Color(0xFF0A518F),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.teal),
            SizedBox(height: 16),
            Text(
              'Search Records',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Search through student and school records',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class EditSchoolProfilePage extends StatelessWidget {
  const EditSchoolProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit School Profile'),
        backgroundColor: const Color(0xFF0A518F),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 64, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Edit School Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Modify school profile information and settings',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodDocumentationPage extends StatelessWidget {
  const FoodDocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Documentation'),
        backgroundColor: const Color(0xFF0A518F),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Food Documentation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Manage food program documentation and records',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
