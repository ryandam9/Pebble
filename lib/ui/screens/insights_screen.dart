import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design.dart';
import '../../core/formatting.dart';
import '../../data/pebble_store.dart';
import '../pebble_root.dart';
import '../ui_helpers.dart';
import 'home_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({required this.store, super.key});
  final PebbleStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = store.expenses.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    ).toList();
    final total = thisMonth.fold<int>(0, (sum, e) => sum + e.amountCents);
    final grouped = <String, int>{};
    for (final expense in thisMonth) {
      grouped.update(expense.category, (sum) => sum + expense.amountCents,
        ifAbsent: () => expense.amountCents);
    }
    final entries = grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final months = List.generate(6, (index) {
      final month = DateTime(now.year, now.month - (5 - index));
      final amount = store.expenses.where((e) =>
          e.date.year == month.year && e.date.month == month.month)
          .fold<int>(0, (sum, e) => sum + e.amountCents);
      return (month, amount);
    });
    final maxValue = math.max(1, months.fold<int>(0, (max, e) => math.max(max, e.$2)));
    final receiptCount = store.expenses.where((e) => e.receiptPath != null).length;

    return PebblePage(
      title: 'Insights',
      subtitle: 'Understand where your money goes',
      children: [
        PebbleCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Expanded(child: Text('Monthly spending', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19))),
            Text('Last 6 months', style: TextStyle(color: PebbleColors.muted, fontSize: 12)),
            Icon(Icons.keyboard_arrow_down, color: PebbleColors.muted),
          ]),
          const SizedBox(height: 26),
          SizedBox(height: 142, child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: months.map((item) {
              final heightFactor = item.$2 / maxValue;
              final currentMonth = item.$1.month == now.month && item.$1.year == now.year;
              return Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(
                    item.$2 == 0 ? '—' : formatCents(item.$2),
                    style: const TextStyle(fontSize: 10, color: PebbleColors.muted),
                  )),
                  const SizedBox(height: 5),
                  Flexible(child: FractionallySizedBox(
                    heightFactor: math.max(.035, heightFactor),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 32,
                      decoration: BoxDecoration(
                        color: currentMonth ? PebbleColors.blue : const Color(0xFFC5DDFB),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      ),
                    ),
                  )),
                  const SizedBox(height: 8),
                  Text(DateFormat('MMM').format(item.$1),
                    style: TextStyle(color: currentMonth ? PebbleColors.blue : PebbleColors.muted,
                      fontSize: 11, fontWeight: currentMonth ? FontWeight.w800 : FontWeight.w500)),
                ],
              ));
            }).toList(),
          )),
        ])),
        const SizedBox(height: 16),
        PebbleCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('By category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          const SizedBox(height: 16),
          if (total == 0)
            const EmptyMessage(title: 'No spending to analyse', message: 'Save an expense to see your category breakdown.')
          else
            Row(children: [
              SizedBox(
                width: 140, height: 140,
                child: CustomPaint(
                  painter: SpendingRingPainter(entries: entries, total: total),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(formatCents(total), textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const Text('Total spent', style: TextStyle(fontSize: 11, color: PebbleColors.muted)),
                  ])),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(children: entries.take(5).map((e) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    CircleAvatar(radius: 5, backgroundColor: categoryForegrounds[categoryIndex(e.key)]),
                    const SizedBox(width: 7),
                    Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12))),
                    Text(((e.value / total) * 100).round().toString() + '%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
                )).toList())),
            ]),
        ])),
        const SizedBox(height: 16),
        PebbleCard(color: const Color(0xFFDFF8EB), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.lightbulb_outline, color: PebbleColors.green),
              SizedBox(width: 10),
              Text('Spending insight', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Text(total == 0 ? 'Make your first entry to unlock trends.'
                  : 'You have recorded ' + thisMonth.length.toString() + ' expenses this month.',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Text('Total: ' + formatCents(total),
              style: const TextStyle(fontSize: 13, color: PebbleColors.green)),
          ],
        )),
        const SizedBox(height: 16),
        PebbleCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.cloud_off_outlined, color: PebbleColors.purple),
            SizedBox(width: 10),
            Text('Storage & privacy', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          _StorageRow(Icons.storage_outlined, 'Local SQLite',
            store.expenses.length.toString() + ' expense entries'),
          const Divider(color: PebbleColors.stroke),
          _StorageRow(Icons.image_outlined, 'Receipt photos',
            receiptCount.toString() + ' saved attachments'),
          const Divider(color: PebbleColors.stroke),
          const _StorageRow(Icons.lock_outline, 'Private by default',
            'Stored on this device; no cloud account'),
        ])),
      ],
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow(this.icon, this.label, this.detail);
  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      CircleAvatar(backgroundColor: const Color(0xFFEAF2FF), radius: 20,
        child: Icon(icon, color: PebbleColors.blue, size: 21)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(detail, style: const TextStyle(fontSize: 12, color: PebbleColors.muted)),
      ])),
    ]);
  }
}
