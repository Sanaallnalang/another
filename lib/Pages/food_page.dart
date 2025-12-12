// food_page.dart - FIXED VERSION WITH AUTO-REFRESH
import 'package:district_dev/Page%20Components/Components/Food%20Components/food_cards.dart';
import 'package:district_dev/Page%20Components/Components/Food%20Components/food_create.dart';
import 'package:district_dev/Page%20Components/Components/Food%20Components/food_edit.dart';
import 'package:district_dev/Page%20Components/sidebar.dart';
import 'package:district_dev/Services/Data%20Model/food_datamodel.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

// Enhanced debug logging
void debugLog(String message, {String category = 'FoodPage'}) {
  if (kDebugMode) {
    developer.log(message, name: category);
    print('🍔 [$category]: $message');
  }
}

const bool kDebugMode = true;

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  final FoodDataRepository _foodRepository = FoodDataRepository();

  List<FoodItem> _foodItems = [];
  List<FoodItem> _filteredFoodItems = [];
  String _selectedFilter = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  // Sidebar state
  bool _isSidebarCollapsed = false;
  int _currentPageIndex = 16; // Food Diet page index from sidebar

  final List<String> _filterOptions = [
    'All',
    'Bakery',
    'Dairy',
    'Grains',
    'Protein',
    'Fruits',
    'Vegetables',
    'Beverages',
  ];

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  Future<void> _loadFoodItems() async {
    debugLog('🔄 Loading food items from repository...');
    setState(() => _isLoading = true);

    try {
      final items = await _foodRepository.getAllFoodItems();
      debugLog('📊 Retrieved ${items.length} food items from database');

      if (mounted) {
        setState(() {
          _foodItems = items;
          _applyFilters();
          _isLoading = false;
        });
        debugLog('✅ Food list updated in UI');
      }
    } catch (e, stackTrace) {
      debugLog('❌ CRITICAL ERROR loading food items: $e');
      debugLog('📋 Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showError('Failed to load food items: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredFoodItems = _foodItems.where((food) {
        final matchesFilter =
            _selectedFilter == 'All' || food.foodType == _selectedFilter;
        final matchesSearch =
            food.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                food.dietaryFocus.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                food.targetStatus.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  // FIXED: Enhanced add food item with immediate refresh
  Future<void> _addFoodItem(FoodItem foodItem) async {
    debugLog('➕ Adding new food item: ${foodItem.name}');

    try {
      await _foodRepository.addFoodItem(foodItem);
      debugLog('💾 Food item saved to database successfully');

      // Immediately refresh the list after adding
      await _loadFoodItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${foodItem.name} added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        debugLog('✅ UI refreshed and snackbar shown');
      }
    } catch (e, stackTrace) {
      debugLog('❌ FAILED to add food item: $e');
      debugLog('📋 Error details: $stackTrace');
      _showError('Failed to add food item: $e');
    }
  }

  // FIXED: Enhanced update food item with immediate refresh
  Future<void> _updateFoodItem(
    String originalName,
    FoodItem updatedItem,
  ) async {
    try {
      await _foodRepository.updateFoodItem(originalName, updatedItem);
      // Immediately refresh the list after updating
      await _loadFoodItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedItem.name} updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update food item: $e');
    }
  }

  // FIXED: Enhanced delete food item with immediate refresh
  Future<void> _deleteFoodItem(FoodItem foodItem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Food Item'),
        content: Text('Are you sure you want to delete "${foodItem.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _foodRepository.removeFoodItem(foodItem.name);
        // Immediately refresh the list after deleting
        await _loadFoodItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${foodItem.name} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _showError('Failed to delete food item: $e');
      }
    }
  }

  // FIXED: Enhanced create food dialog with proper refresh handling
  void _showCreateFoodDialog() {
    debugLog('🔄 Opening food creation dialog...');

    showDialog(
      context: context,
      builder: (context) => FoodCreator(
        onSave: (foodItem) async {
          debugLog('💾 Food creation - saving item: ${foodItem.name}');
          try {
            // Save the food item and refresh immediately
            await _addFoodItem(foodItem);
            debugLog('✅ Food item saved successfully');
            Navigator.pop(context); // Close dialog after successful save
          } catch (e) {
            debugLog('❌ Error saving food item: $e');
            // Don't close dialog on error - let user retry
            rethrow;
          }
        },
        onCancel: () {
          debugLog('❌ Food creation cancelled by user');
          Navigator.pop(context);
        },
      ),
    ).then((_) {
      // This runs after the dialog is closed
      debugLog('🔍 Food creation dialog closed, checking if refresh needed...');
      // Force refresh to ensure latest data
      _loadFoodItems();
    });
  }

  // FIXED: Enhanced edit food dialog with proper refresh handling
  void _showEditFoodDialog(FoodItem foodItem) {
    showDialog(
      context: context,
      builder: (context) => FoodEditor(
        onUpdate: (updatedItem) {
          // Update the food item and close the dialog
          _updateFoodItem(foodItem.name, updatedItem);
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
        existingFood: foodItem,
      ),
    ).then((_) {
      // This runs after the dialog is closed
      // The _updateFoodItem method already calls _loadFoodItems()
      // so we don't need to call it again here
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _handlePageChanged(int pageIndex) {
    setState(() {
      _currentPageIndex = pageIndex;
    });
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleProfileEdit() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile edit functionality')));
  }

  // Refresh button functionality
  void _handleRefresh() {
    _loadFoodItems();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing food data...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Debug panel functionality
  void _showDebugPanel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Food Database Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Items: ${_foodItems.length}'),
              Text('Filtered Items: ${_filteredFoodItems.length}'),
              Text('Current Filter: $_selectedFilter'),
              Text('Search Query: $_searchQuery'),
              Text('Loading State: $_isLoading'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _loadFoodItems();
                  Navigator.pop(context);
                },
                child: Text('Force Refresh'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final stats =
                      await _foodRepository.getNutritionalStatistics();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Database Stats'),
                      content: Text(stats.toString()),
                    ),
                  );
                },
                child: Text('Show DB Stats'),
              ),
            ],
          ),
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

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      leading: IconButton(
        icon: Icon(
          _isSidebarCollapsed ? Icons.menu : Icons.menu_open,
          color: const Color(0xFF1A4D7A),
        ),
        onPressed: _toggleSidebar,
      ),
      title: const Text(
        'Food Database',
        style: TextStyle(color: Color(0xFF1A4D7A), fontWeight: FontWeight.bold),
      ),
      actions: [
        // Debug button
        IconButton(
          icon: Icon(Icons.bug_report, color: Color(0xFF1A4D7A)),
          onPressed: _showDebugPanel,
          tooltip: 'Debug Info',
        ),
        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF1A4D7A)),
          onPressed: _handleRefresh,
          tooltip: 'Refresh Data',
        ),
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
          onPressed: _handleProfileEdit,
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Sidebar(
      isCollapsed: _isSidebarCollapsed,
      onToggle: _toggleSidebar,
      currentPageIndex: _currentPageIndex,
      onPageChanged: _handlePageChanged,
    );
  }

  Widget _buildContentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.restaurant_menu_rounded,
            color: Color(0xFF39D2C0),
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'Food Database',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const Spacer(),

          // Stats display
          _buildStatsDisplay(),
          const SizedBox(width: 20),

          // Search Bar
          Container(
            width: 300,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search food items...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Filter Dropdown
          Container(
            width: 150,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                isExpanded: true,
                icon: const Icon(Icons.filter_list_rounded, size: 18),
                style: const TextStyle(fontSize: 14, color: Colors.black),
                items: _filterOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedFilter = value!);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Add Food Button
          ElevatedButton.icon(
            onPressed: _showCreateFoodDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Food'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF39D2C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF39D2C0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF39D2C0).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fastfood_rounded,
            size: 16,
            color: Color(0xFF39D2C0),
          ),
          const SizedBox(width: 8),
          Text(
            '${_foodItems.length} items',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF39D2C0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading food database...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_filteredFoodItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'All'
                  ? 'No food items match your search'
                  : 'No food items found',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'All'
                  ? 'Try adjusting your search or filter'
                  : 'Add your first food item to get started',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreateFoodDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add First Food Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF39D2C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFoodItems,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: _filteredFoodItems.length,
          itemBuilder: (context, index) {
            final food = _filteredFoodItems[index];
            return FoodCard(
              food: food,
              onEdit: () => _showEditFoodDialog(food),
              onDelete: () => _deleteFoodItem(food),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildTopBar(),
      body: _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFoodDialog,
        backgroundColor: const Color(0xFF39D2C0),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return _buildMobileView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(),

                // Content Header (Search, Filter, Add Button)
                _buildContentHeader(),

                // Main Content
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Food Dashboard for integration with sidebar
class FoodDashboard extends StatelessWidget {
  const FoodDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const FoodPage();
  }
}
