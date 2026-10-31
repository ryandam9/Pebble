import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../core/category_palette.dart';
import '../../core/design.dart';
import '../../core/formatting.dart';
import '../../core/pebble_typography.dart';
import '../../data/pebble_database.dart';
import '../../data/pebble_store.dart';
import '../pebble_root.dart';
import '../ui_helpers.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.store,
    required this.onAdd,
    required this.onScan,
    required this.onExpenses,
    super.key,
  });

  final PebbleStore store;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final VoidCallback onExpenses;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final thisMonth = store.expenses.where(
      (e) => e.date.year == today.year && e.date.month == today.month,
    ).toList();
    final total = thisMonth.fold<int>(0, (sum, e) => sum + e.amountCents);
    final budgetCents = store.monthlyBudgetCents;
    final ratio = total / budgetCents;
    final difference = (budgetCents - total).abs();
    final exceededBudget = total > budgetCents;
    final budgetStatus = (ratio * 100).round().toString() + '% of ' +
      formatCents(budgetCents) + ' monthly budget · ' +
      formatCents(difference) + (exceededBudget ? ' over budget' : ' remaining');
    final grouped = <String, int>{};
    for (final item in thisMonth) {
      grouped.update(item.category, (value) => value + item.amountCents, ifAbsent: () => item.amountCents);
    }
    final top = grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final categories = top.take(4).toList();
    final recent = store.expenses.take(3).toList();
    return PebblePage(
      title: 'Pebble',
      subtitle: 'Small records. Clear picture.',
      children: [
        PebbleCard(
          color: const Color(0xFFDFF8EB),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.calendar_month_outlined, size: 19, color: PebbleColors.ink),
              const SizedBox(width: 8),
              Text(monthTitle.format(today), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: PebbleTypography.tabularFigures)),
            ]),
            const SizedBox(height: 18),
            const Text('Spent this month', style: TextStyle(fontSize: 14, color: PebbleColors.muted)),
            const SizedBox(height: 4),
            FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
              child: Text(formatCents(total), style: const TextStyle(fontSize: 35, fontWeight: FontWeight.w800, fontFeatures: PebbleTypography.tabularFigures, color: PebbleColors.ink))),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), minHeight: 10,
                backgroundColor: const Color(0xFFBFECD7),
                valueColor: AlwaysStoppedAnimation(exceededBudget
                  ? const Color(0xFFE05252) : PebbleColors.green)),
            ),
            const SizedBox(height: 8),
            Text(
              budgetStatus,
              key: const Key('monthlyBudgetSummary'),
              style: TextStyle(fontSize: 12,
                color: exceededBudget ? const Color(0xFFBB3F42) : const Color(0xFF388269),
                fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (categories.isEmpty)
          const PebbleCard(
            child: EmptyMessage(title: 'No expenses this month', message: 'Add your first expense to see the breakdown.'),
          )
        else
          Row(
            children: List.generate(categories.length, (i) {
              final entry = categories[i];
              final style = categoryStyle(store, entry.key);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == categories.length - 1 ? 0 : 8),
                  child: PebbleCard(
                    color: style.background,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(style.icon, color: style.foreground, size: 23),
                      const SizedBox(height: 10),
                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(formatCents(entry.value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFeatures: PebbleTypography.tabularFigures)),
                      ),
                      const SizedBox(height: 3),
                      Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: PebbleColors.muted, fontSize: 12)),
                    ]),
                  ),
                ),
              );
            }),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _QuickAction(
            icon: Icons.add, title: 'Add expense', subtitle: 'Quick entry', onTap: onAdd,
            colors: const [Color(0xFF2387F6), Color(0xFF3DA1FF)],
          )),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(
            icon: Icons.document_scanner_outlined, title: 'Scan receipt',
            subtitle: 'Take a photo', onTap: onScan,
            colors: const [Color(0xFF6B4CE4), Color(0xFF9781F5)],
          )),
        ]),
        const SizedBox(height: 18),
        PebbleCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Spending by category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),
            if (total == 0)
              const EmptyMessage(title: 'Nothing to chart yet', message: 'Your spending mix appears here.')
            else
              Row(children: [
                SizedBox(
                  width: 145, height: 145,
                  child: CustomPaint(
                    painter: SpendingRingPainter(entries: top, total: total,
                      colors: [for (final e in top) categoryStyle(store, e.key).foreground]),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        FittedBox(child: Text(formatCents(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                        const Text('Total', style: TextStyle(fontSize: 12, color: PebbleColors.muted)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(child: Column(
                  children: top.take(5).map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        CircleAvatar(radius: 5, backgroundColor: categoryStyle(store, e.key).foreground),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                        Text(((e.value / total) * 100).round().toString() + '%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    );
                  }).toList(),
                )),
              ]),
          ]),
        ),
        const SizedBox(height: 18),
        PebbleCard(
          onTap: onExpenses,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Recent expenses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
              TextButton(onPressed: onExpenses, child: const Text('See all →')),
            ]),
            if (recent.isEmpty)
              const EmptyMessage(title: 'No expenses yet', message: 'Record one to start your history.')
            else
              ...recent.map((item) => _RecentLine(entry: item, style: categoryStyle(store, item.category))),
          ]),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.subtitle, required this.onTap, required this.colors});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(16), boxShadow: pebbleShadow),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 74,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              CircleAvatar(radius: 16, backgroundColor: Colors.white24,
                child: Icon(icon, size: 22, color: Colors.white)),
              const SizedBox(width: 9),
              Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFE9F1FF), fontSize: 11)),
                ],
              )),
            ]),
          ),
        ),
      ),
    ),
  );
}

class _RecentLine extends StatelessWidget {
  const _RecentLine({required this.entry, required this.style});
  final ExpenseEntry entry;
  final CategoryStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: style.background,
          child: Icon(style.icon, color: style.foreground, size: 19)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.merchant ?? entry.description, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(friendlyDate.format(entry.date), style: const TextStyle(color: PebbleColors.muted, fontSize: 11)),
        ])),
        Text('−' + formatCents(entry.amountCents),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

class SpendingRingPainter extends CustomPainter {
  SpendingRingPainter({required this.entries, required this.total, required this.colors});
  final List<MapEntry<String, int>> entries;
  final int total;

  /// One colour per entry, in the same order.
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final base = Paint()..color = PebbleColors.stroke..strokeWidth = 16..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, base);
    var startAngle = -math.pi / 2;
    for (var i = 0; i < entries.length; i++) {
      final item = entries[i];
      final sweep = (item.value / total) * 2 * math.pi;
      final pen = Paint()
        ..color = colors[i]
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, pen);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant SpendingRingPainter oldDelegate) =>
      total != oldDelegate.total ||
      entries.toString() != oldDelegate.entries.toString() ||
      !listEquals(colors, oldDelegate.colors);
}
