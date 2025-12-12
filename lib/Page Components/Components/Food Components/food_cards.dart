// food_card.dart
import 'package:district_dev/Services/Data%20Model/food_datamodel.dart';
import 'package:flutter/material.dart';

class FoodCard extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isSelected;

  const FoodCard({
    super.key,
    required this.food,
    required this.onEdit,
    required this.onDelete,
    this.isSelected = false,
  });

  // Color themes for each food type
  static final Map<String, Color> _foodTypeColors = {
    'Bakery': const Color(0xFFD4A574),
    'Dairy': const Color(0xFF87CEEB),
    'Grains': const Color(0xFFDEB887),
    'Protein': const Color(0xFFF08080),
    'Fruits': const Color(0xFF90EE90),
    'Vegetables': const Color(0xFF32CD32),
    'Beverages': const Color(0xFF87CEFA),
  };

  static IconData _getFoodTypeIcon(String foodType) {
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

  @override
  Widget build(BuildContext context) {
    final themeColor =
        _foodTypeColors[food.foodType] ?? const Color(0xFF39D2C0);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: isSelected ? themeColor.withOpacity(0.1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? themeColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with food name and type
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food Type Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getFoodTypeIcon(food.foodType),
                      color: themeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Food Name and Type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            food.foodType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: themeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Serving Size
              _buildDetailRow('Serving Size:', food.servingSize),
              const SizedBox(height: 8),

              // Nutritional Information
              Row(
                children: [
                  Expanded(
                    child: _buildNutritionChip(
                      '${food.averageCalories} cal',
                      Icons.local_fire_department_rounded,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNutritionChip(
                      '${food.minProtein}g protein',
                      Icons.fitness_center_rounded,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Dietary Information
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (food.minVitaminA != null)
                    _buildInfoChip('${food.minVitaminA}μg Vit A', Colors.green),
                  _buildInfoChip(food.dietaryFocus, Colors.purple),
                  _buildInfoChip(food.targetStatus, Colors.teal),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Chip(
      label: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
