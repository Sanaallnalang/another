import 'package:flutter/material.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuToggle;
  final bool isSidebarCollapsed;
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final VoidCallback? onProfileEdit;

  const TopBar({
    super.key,
    required this.onMenuToggle,
    required this.isSidebarCollapsed,
    required this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.onProfileEdit,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A4D7A)),
              onPressed: onBackPressed,
            )
          : IconButton(
              icon: Icon(
                isSidebarCollapsed ? Icons.menu : Icons.menu_open,
                color: const Color(0xFF1A4D7A),
              ),
              onPressed: onMenuToggle,
            ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1A4D7A),
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF1A4D7A),
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(
            Icons.account_circle_outlined,
            color: Color(0xFF1A4D7A),
          ),
          onPressed: onProfileEdit,
        ),
      ],
    );
  }
}
