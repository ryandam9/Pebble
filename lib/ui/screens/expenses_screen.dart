import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/formatting.dart';
import '../../data/pebble_database.dart';
import '../../data/pebble_store.dart';
import '../pebble_root.dart';
import '../ui_helpers.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    required this.store, required this.onAdd, required this.onEdit, super.key,
  });
  final PebbleStore store;
  final VoidCallback onAdd;
  final ValueChanged<ExpenseEntry> onEdit;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _search = TextEditingController();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase().trim();
    final store = widget.store;
    // A filtered category may have been renamed or deleted since it was picked.
    final filter = store.categoryNames.contains(_filter) ? _filter : 'All';
    final rows = widget.store.expenses.where((e) {
      final inMonth = e.date.year == _month.year && e.date.month == _month.month;
      final inCategory = filter == 'All' || e.category == filter;
      final inSearch = query.isEmpty ||
          e.description.toLowerCase().contains(query) ||
          (e.merchant?.toLowerCase().contains(query) ?? false) ||
          e.category.toLowerCase().contains(query);
      return inMonth && inCategory && inSearch;
    }).toList();

    return PebblePage(
      title: 'Expenses',
      subtitle: 'Search and explore your spending',
      children: [
        TextField(
          key: const Key('expenseSearch'),
          controller: _search,
          decoration: const InputDecoration(
            hintText: 'Search expenses, shops...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        PebbleCard(
          color: const Color(0xFFDFF8EB),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(children: [
            const Icon(Icons.calendar_month_outlined, size: 19),
            const SizedBox(width: 9),
            Expanded(child: Text(monthTitle.format(_month),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left, color: PebbleColors.blue),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right, color: PebbleColors.blue),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: ['All', ...store.categoryNames].map((category) {
            final selected = category == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category, style: TextStyle(fontSize: 12,
                    color: selected ? Colors.white : PebbleColors.ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                selected: selected,
                showCheckmark: false,
                backgroundColor: category == 'All' ? Colors.white : categoryStyle(store, category).background,
                selectedColor: PebbleColors.blue,
                onSelected: (_) => setState(() => _filter = category),
                side: BorderSide.none,
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          PebbleCard(child: Column(children: [
            const EmptyMessage(
              title: 'No matching expenses',
              message: 'Try another month or category, or add a new expense.',
            ),
            PebbleButton(label: 'Add expense', icon: Icons.add, onPressed: widget.onAdd),
          ]))
        else
          ...rows.map((entry) {
            final style = categoryStyle(store, entry.category);
            return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PebbleCard(
              onTap: () => widget.onEdit(entry),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: style.foreground,
                  child: Icon(style.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.merchant ?? entry.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(child: Text(friendlyDate.format(entry.date),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: PebbleColors.muted))),
                    if (entry.receiptPath != null) ...[
                      const SizedBox(width: 7),
                      const Icon(Icons.image_outlined, size: 15, color: PebbleColors.muted),
                    ],
                  ]),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('−' + formatCents(entry.amountCents),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  CategoryBadge(entry.category, style: style, compact: true),
                ]),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: PebbleColors.muted),
              ]),
            ),
          );
          }),
        const SizedBox(height: 6),
        PebbleButton(label: 'Add expense', icon: Icons.add, onPressed: widget.onAdd),
      ],
    );
  }
}
