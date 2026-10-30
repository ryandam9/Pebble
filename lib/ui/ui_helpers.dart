import 'package:flutter/material.dart';
import '../core/category_palette.dart';
import '../core/design.dart';
import '../data/pebble_database.dart';
import '../data/pebble_store.dart';

/// Icon and colours for a category name; unknown names look like "Other".
CategoryStyle categoryStyle(PebbleStore store, String name) {
  final category = store.categoryNamed(name) ?? store.categoryNamed(otherCategory);
  return category == null
      ? CategoryStyle.fallback
      : CategoryStyle.fromKeys(category.iconKey, category.colorKey);
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {required this.style, super.key, this.compact = false});
  final String category;
  final CategoryStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
        color: style.foreground, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600,
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
