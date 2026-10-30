import 'package:flutter/material.dart';

import 'design.dart';

/// Icons a category can use, stored in the database by key.
/// A fixed set keeps icon tree-shaking working and saved keys stable.
const categoryIconOptions = <String, IconData>{
  'grocery': Icons.local_grocery_store_outlined,
  'restaurant': Icons.restaurant_outlined,
  'coffee': Icons.local_cafe_outlined,
  'car': Icons.directions_car_outlined,
  'transit': Icons.directions_bus_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'flight': Icons.flight_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'bills': Icons.receipt_long_outlined,
  'home': Icons.home_outlined,
  'phone': Icons.phone_android_outlined,
  'health': Icons.favorite_outline,
  'fitness': Icons.fitness_center_outlined,
  'education': Icons.school_outlined,
  'child': Icons.child_friendly_outlined,
  'pets': Icons.pets_outlined,
  'entertainment': Icons.movie_outlined,
  'gift': Icons.card_giftcard_outlined,
  'work': Icons.work_outline,
  'savings': Icons.savings_outlined,
  'other': Icons.category_outlined,
};

/// Colours a category can use, as (background, foreground), stored by key.
const categoryColorOptions = <String, (Color, Color)>{
  'green': (Color(0xFFE6F7ED), PebbleColors.green),
  'coral': (Color(0xFFFFEFEB), Color(0xFFE9715C)),
  'blue': (Color(0xFFEAF2FF), PebbleColors.blue),
  'purple': (Color(0xFFF1EBFF), PebbleColors.purple),
  'amber': (Color(0xFFFFF4D8), PebbleColors.orange),
  'pink': (Color(0xFFFCEDF3), Color(0xFFE26A9B)),
  'teal': (Color(0xFFE3F6F8), Color(0xFF1E9AAE)),
  'indigo': (Color(0xFFE8EAFB), Color(0xFF4F5BD5)),
  'brown': (Color(0xFFF3ECE6), Color(0xFF8D6E63)),
  'grey': (Color(0xFFEDF0F5), PebbleColors.muted),
};

class CategoryStyle {
  const CategoryStyle({required this.icon, required this.background, required this.foreground});

  factory CategoryStyle.fromKeys(String iconKey, String colorKey) {
    final colors = categoryColorOptions[colorKey] ?? categoryColorOptions['grey']!;
    return CategoryStyle(
      icon: categoryIconOptions[iconKey] ?? Icons.category_outlined,
      background: colors.$1,
      foreground: colors.$2,
    );
  }

  static const fallback = CategoryStyle(
    icon: Icons.category_outlined,
    background: Color(0xFFEDF0F5),
    foreground: PebbleColors.muted,
  );

  final IconData icon;
  final Color background;
  final Color foreground;
}
