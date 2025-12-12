// multi_page_stats_header.dart - NEW FILE

import 'package:flutter/material.dart';

class MultiPageStatsHeader extends StatelessWidget {
  final String pageTitle;
  final Map<String, String> stats;
  final bool showPrevious;
  final bool showNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final List<Widget>? quickActions;

  const MultiPageStatsHeader({
    super.key,
    required this.pageTitle,
    required this.stats,
    this.showPrevious = false,
    this.showNext = false,
    this.onPrevious,
    this.onNext,
    this.quickActions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Navigation Header
          _buildNavigationHeader(),
          // Stats Row
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildNavigationHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          // Previous Button
          if (showPrevious && onPrevious != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: onPrevious,
              tooltip: 'Previous Page',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),

          if (showPrevious && onPrevious != null) const SizedBox(width: 8),

          // Page Title
          Expanded(
            child: Text(
              pageTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // Quick Actions
          if (quickActions != null) ...quickActions!,

          if (quickActions != null && showNext) const SizedBox(width: 8),

          // Next Button
          if (showNext && onNext != null)
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 20),
              onPressed: onNext,
              tooltip: 'Next Page',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final statEntries = stats.entries.toList();

    return Expanded(
      child: Row(
        children: [
          for (int i = 0; i < statEntries.length; i++) ...[
            Expanded(
              child: _buildStatItem(statEntries[i].key, statEntries[i].value),
            ),
            if (i < statEntries.length - 1) _buildVerticalDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value) {
    Color getColorForTitle(String title) {
      switch (title.toLowerCase()) {
        case 'male':
          return Colors.blue;
        case 'female':
          return Colors.pink;
        case 'at risk':
        case 'risk reduction':
          return Colors.orange;
        case 'improvement':
          return Colors.green;
        default:
          return const Color(0xFF1A4D7A);
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: value.length > 10 ? 14 : 18,
            fontWeight: FontWeight.bold,
            color: getColorForTitle(title),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 40, color: Colors.grey[300]);
  }
}
