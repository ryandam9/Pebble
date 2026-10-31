import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design.dart';
import '../../core/formatting.dart';
import '../../core/pebble_typography.dart';
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
    final receiptCount = store.expenses.where((e) => e.receiptPath != null).length;

    return PebblePage(
      title: 'Insights',
      subtitle: 'Understand where your money goes',
      children: [
        _MonthlySpendingCard(store: store),
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
                  painter: SpendingRingPainter(entries: entries, total: total,
                    colors: [for (final e in entries) categoryStyle(store, e.key).foreground]),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(formatCents(total), textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: PebbleTypography.tabularFigures)),
                    const Text('Total spent', style: TextStyle(fontSize: 11, color: PebbleColors.muted)),
                  ])),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(children: entries.take(5).map((e) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    CircleAvatar(radius: 5, backgroundColor: categoryStyle(store, e.key).foreground),
                    const SizedBox(width: 7),
                    Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12))),
                    Text(((e.value / total) * 100).round().toString() + '%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFeatures: PebbleTypography.tabularFigures)),
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
              Flexible(child: Text('Spending insight', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
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
        PebbleCard(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.cloud_off_outlined, color: PebbleColors.purple),
              SizedBox(width: 10),
              Flexible(child: Text('Storage & privacy',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 15),
            Row(
              key: const Key('insightsStorageTiles'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _StorageTile(
                  tileKey: const Key('insightsStorageDatabase'),
                  icon: Icons.storage_outlined,
                  color: const Color(0xFFEAF2FF),
                  foreground: PebbleColors.blue,
                  value: store.expenses.length.toString(),
                  label: 'Local SQLite',
                  detail: 'Expense entries',
                )),
                const SizedBox(width: 7),
                Expanded(child: _StorageTile(
                  tileKey: const Key('insightsStorageReceipts'),
                  icon: Icons.image_outlined,
                  color: const Color(0xFFFFF0E6),
                  foreground: Color(0xFFBE714A),
                  value: receiptCount.toString(),
                  label: 'Receipt photos',
                  detail: 'Attachments',
                )),
                const SizedBox(width: 7),
                const Expanded(child: _StorageTile(
                  tileKey: Key('insightsStoragePrivate'),
                  icon: Icons.lock_outline_rounded,
                  color: Color(0xFFF0EAFE),
                  foreground: PebbleColors.purple,
                  value: 'On device',
                  label: 'Private by default',
                  detail: 'No cloud account',
                )),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}

class _MonthlySpendingCard extends StatefulWidget {
  const _MonthlySpendingCard({required this.store});
  final PebbleStore store;

  @override
  State<_MonthlySpendingCard> createState() => _MonthlySpendingCardState();
}

class _MonthlySpendingCardState extends State<_MonthlySpendingCard> {
  static const _ranges = [3, 6, 12];
  int _monthCount = 6;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(_monthCount, (index) {
      final month = DateTime(now.year, now.month - (_monthCount - 1 - index));
      final amount = widget.store.expenses.where((e) =>
          e.date.year == month.year && e.date.month == month.month)
          .fold<int>(0, (sum, e) => sum + e.amountCents);
      return (month, amount);
    });
    final maxValue = math.max(1, months.fold<int>(0, (max, e) => math.max(max, e.$2)));
    // Twelve bars are too narrow for amount labels; show them on hover/long-press instead.
    final compact = _monthCount > 6;

    return PebbleCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Monthly spending',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19))),
        PopupMenuButton<int>(
          tooltip: 'Choose period',
          initialValue: _monthCount,
          onSelected: (value) => setState(() => _monthCount = value),
          itemBuilder: (context) => [
            for (final range in _ranges)
              PopupMenuItem(value: range, child: Text('Last $range months')),
          ],
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Last $_monthCount months',
              style: const TextStyle(color: PebbleColors.muted, fontSize: 12)),
            const Icon(Icons.keyboard_arrow_down, color: PebbleColors.muted),
          ]),
        ),
      ]),
      const SizedBox(height: 26),
      SizedBox(key: const Key('monthlySpendingChart'), height: 238, child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: months.map((item) {
          final heightFactor = item.$2 / maxValue;
          final currentMonth = item.$1.month == now.month && item.$1.year == now.year;
          final amountText = item.$2 == 0 ? '—' : formatCents(item.$2);
          final bar = Container(
            width: compact ? 14 : (_monthCount == 3 ? 50 : 32),
            decoration: BoxDecoration(
              color: currentMonth ? PebbleColors.blue : const Color(0xFFC5DDFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(compact ? 4 : 7)),
            ),
          );
          return Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!compact) ...[
                FittedBox(fit: BoxFit.scaleDown, child: Text(amountText,
                  style: const TextStyle(fontSize: 10, color: PebbleColors.muted))),
                const SizedBox(height: 5),
              ],
              Flexible(child: FractionallySizedBox(
                heightFactor: math.max(.035, heightFactor),
                alignment: Alignment.bottomCenter,
                child: compact ? Tooltip(message: amountText, child: bar) : bar,
              )),
              const SizedBox(height: 8),
              FittedBox(fit: BoxFit.scaleDown, child: Text(DateFormat('MMM').format(item.$1),
                style: TextStyle(color: currentMonth ? PebbleColors.blue : PebbleColors.muted,
                  fontSize: 11, fontWeight: currentMonth ? FontWeight.w800 : FontWeight.w500))),
            ],
          ));
        }).toList(),
      )),
    ]));
  }
}

/// Three equal-width summary tiles use the full card width, including on
/// compact phones. Values stay prominent without wasting the right-hand side.
class _StorageTile extends StatelessWidget {
  const _StorageTile({
    required this.tileKey,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.value,
    required this.label,
    required this.detail,
  });

  final Key tileKey;
  final IconData icon;
  final Color color;
  final Color foreground;
  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    key: tileKey,
    constraints: const BoxConstraints(minHeight: 145),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: foreground, size: 23),
        const Spacer(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: PebbleColors.ink,
            fontFeatures: PebbleTypography.tabularFigures,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: PebbleColors.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            color: PebbleColors.muted,
          ),
        ),
      ],
    ),
  );
}
