import 'package:flutter/material.dart';
import '../core/design.dart';

const categoryNames = <String>['Groceries', 'Food', 'Transport', 'Shopping', 'Bills', 'Health', 'Other'];
const categoryIcons = <IconData>[
  Icons.local_grocery_store_outlined,
  Icons.restaurant_outlined,
  Icons.directions_car_outlined,
  Icons.shopping_bag_outlined,
  Icons.receipt_long_outlined,
  Icons.favorite_outline,
  Icons.category_outlined,
];
const categoryBackgrounds = <Color>[
  Color(0xFFE6F7ED), Color(0xFFFFEFEB), Color(0xFFEAF2FF),
  Color(0xFFF1EBFF), Color(0xFFFFF4D8), Color(0xFFFCEDF3),
  Color(0xFFEDF0F5),
];
const categoryForegrounds = <Color>[
  PebbleColors.green, Color(0xFFE9715C), PebbleColors.blue,
  PebbleColors.purple, PebbleColors.orange, Color(0xFFE26A9B),
  PebbleColors.muted,
];

int categoryIndex(String category) {
  final index = categoryNames.indexOf(category);
  return index < 0 ? categoryNames.length - 1 : index;
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key, this.compact = false});
  final String category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final index = categoryIndex(category);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: categoryBackgrounds[index],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
        color: categoryForegrounds[index], fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600,
      )),
    );
  }
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({required this.title, required this.message, this.icon = Icons.receipt_long, super.key});
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Icon(icon, color: PebbleColors.blue, size: 42),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
