// food_creator.dart - Create-only version
import 'package:district_dev/Services/Data%20Model/food_datamodel.dart';
import 'package:flutter/material.dart';

class FoodCreator extends StatefulWidget {
  final Function(FoodItem) onSave;
  final Function() onCancel;

  const FoodCreator({super.key, required this.onSave, required this.onCancel});

  @override
  State<FoodCreator> createState() => _FoodCreatorState();
}

class _FoodCreatorState extends State<FoodCreator> {
  final _formKey = GlobalKey<FormState>();

  // Form fields - empty for creation
  String _foodName = '';
  String _servingSize = '';
  int _minCalories = 0;
  int _maxCalories = 0;
  double _minProtein = 0.0;
  double? _minVitaminA;
  String _dietaryFocus = '';
  String _targetStatus = '';
  String _foodType = 'Bakery';

  // Available options
  final List<String> _foodTypes = [
    'Bakery',
    'Dairy',
    'Grains',
    'Protein',
    'Fruits',
    'Vegetables',
    'Beverages',
  ];

  final List<String> _targetStatuses = [
    'Severely Malnourished',
    'Underweight',
    'Stunted',
    'Normal',
    'Overweight',
    'Obese',
  ];

  final List<String> _dietaryFocuses = [
    'High-Calorie',
    'High-Protein',
    'Balanced',
    'Energy Source',
    'Protein & Calcium',
    'High-Calorie & Protein',
    'High-Protein & Fiber',
  ];

  // Color themes for each food type
  final Map<String, Color> _foodTypeColors = {
    'Bakery': const Color(0xFFD4A574),
    'Dairy': const Color(0xFF87CEEB),
    'Grains': const Color(0xFFDEB887),
    'Protein': const Color(0xFFF08080),
    'Fruits': const Color(0xFF90EE90),
    'Vegetables': const Color(0xFF32CD32),
    'Beverages': const Color(0xFF87CEFA),
  };

  void _saveFood() {
    if (_formKey.currentState!.validate()) {
      final foodItem = FoodItem(
        name: _foodName,
        servingSize: _servingSize,
        minCalories: _minCalories,
        maxCalories: _maxCalories,
        minProtein: _minProtein,
        minVitaminA: _minVitaminA,
        dietaryFocus: _dietaryFocus,
        targetStatus: _targetStatus,
        foodType: _foodType,
      );

      widget.onSave(foodItem);
    }
  }

  Color get _currentColorTheme =>
      _foodTypeColors[_foodType] ?? const Color(0xFF39D2C0);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Create-specific styling
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _currentColorTheme.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getFoodTypeIcon(_foodType),
                        color: _currentColorTheme,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create New Food Item',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _currentColorTheme,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Basic Information Section
                    _buildBasicInfoSection(),
                    const SizedBox(height: 20),

                    // Nutritional Information Section
                    _buildNutritionalSection(),
                    const SizedBox(height: 20),

                    // Dietary Information Section
                    _buildDietarySection(),
                    const SizedBox(height: 20),

                    // Action Buttons with Create focus
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

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentColorTheme,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              initialValue: _foodName,
              label: 'Food Name',
              icon: Icons.fastfood_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Food name is required';
                }
                return null;
              },
              onChanged: (value) => _foodName = value,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDropdown(
                    value: _foodType,
                    label: 'Food Type',
                    icon: Icons.category_rounded,
                    items: _foodTypes,
                    onChanged: (value) => setState(() => _foodType = value!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    initialValue: _servingSize,
                    label: 'Serving Size',
                    icon: Icons
                        .square_foot_rounded, // FIXED: Changed from measurement_rounded
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Serving size is required';
                      }
                      return null;
                    },
                    onChanged: (value) => _servingSize = value,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionalSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutritional Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentColorTheme,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    initialValue: _minCalories.toString(),
                    label: 'Min Calories',
                    icon: Icons.local_fire_department_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Minimum calories required';
                      }
                      final val = int.tryParse(value);
                      if (val == null || val < 0) {
                        return 'Enter valid number';
                      }
                      return null;
                    },
                    onChanged: (value) =>
                        _minCalories = int.tryParse(value) ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    initialValue: _maxCalories.toString(),
                    label: 'Max Calories',
                    icon: Icons.local_fire_department_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Maximum calories required';
                      }
                      final val = int.tryParse(value);
                      if (val == null || val < _minCalories) {
                        return 'Must be ≥ min calories';
                      }
                      return null;
                    },
                    onChanged: (value) =>
                        _maxCalories = int.tryParse(value) ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    initialValue: _minProtein.toString(),
                    label: 'Min Protein (g)',
                    icon: Icons.fitness_center_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Protein amount required';
                      }
                      final val = double.tryParse(value);
                      if (val == null || val < 0) {
                        return 'Enter valid number';
                      }
                      return null;
                    },
                    onChanged: (value) =>
                        _minProtein = double.tryParse(value) ?? 0.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    initialValue: _minVitaminA?.toString() ?? '',
                    label: 'Min Vitamin A (μg)',
                    icon: Icons.visibility_rounded,
                    isOptional: true,
                    onChanged: (value) => _minVitaminA = double.tryParse(value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietarySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dietary Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentColorTheme,
              ),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _dietaryFocus,
              label: 'Dietary Focus',
              icon: Icons.health_and_safety_rounded,
              items: _dietaryFocuses,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Dietary focus is required';
                }
                return null;
              },
              onChanged: (value) => _dietaryFocus = value!,
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              value: _targetStatus,
              label: 'Target Status',
              icon: Icons.people_alt_rounded,
              items: _targetStatuses,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Target status is required';
                }
                return null;
              },
              onChanged: (value) => _targetStatus = value!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String initialValue,
    required String label,
    required IconData icon,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    bool isOptional = false,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: '$label${isOptional ? ' (Optional)' : ''}',
        prefixIcon: Icon(icon, color: _currentColorTheme),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _currentColorTheme),
        ),
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildNumberField({
    required String initialValue,
    required String label,
    required IconData icon,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    bool isOptional = false,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '$label${isOptional ? ' (Optional)' : ''}',
        prefixIcon: Icon(icon, color: _currentColorTheme),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _currentColorTheme),
        ),
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isNotEmpty ? value : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _currentColorTheme),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _currentColorTheme),
        ),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
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
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _saveFood,
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentColorTheme,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Create Food'),
        ),
      ],
    );
  }

  IconData _getFoodTypeIcon(String foodType) {
    switch (foodType) {
      case 'Bakery':
        return Icons.bakery_dining_rounded;
      case 'Dairy':
        return Icons.local_drink_rounded;
      case 'Grains':
        return Icons.grain_rounded;
      case 'Protein':
        return Icons.egg_alt_rounded;
      case 'Fruits':
        return Icons.apple_rounded;
      case 'Vegetables':
        return Icons.eco_rounded;
      case 'Beverages':
        return Icons.coffee_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }
}
