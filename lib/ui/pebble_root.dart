import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/pebble_database.dart';
import '../data/pebble_store.dart';
import 'screens/editor_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/receipt_screen.dart';
import 'screens/settings_screen.dart';

class PebbleRoot extends StatefulWidget {
  const PebbleRoot({required this.store, super.key});
  final PebbleStore store;

  @override
  State<PebbleRoot> createState() => _PebbleRootState();
}

class _PebbleRootState extends State<PebbleRoot> {
  int _index = 0;

  Future<void> _add({ExpenseEntry? entry}) async {
    final tab = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (ctx) => EditorScreen(
          store: widget.store,
          entry: entry,
          onSwitchTab: (index) => Navigator.of(ctx).pop(index),
        ),
      ),
    );
    if (mounted && tab != null) setState(() => _index = tab);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        if (!widget.store.isReady) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final error = widget.store.loadError;
        if (error != null) {
          return Scaffold(
            body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Cannot open local expenses database:\n' + error),
            )),
          );
        }
        final pages = [
          HomeScreen(store: widget.store, onAdd: () => _add(), onScan: () => setState(() => _index = 2), onExpenses: () => setState(() => _index = 1)),
          ExpensesScreen(store: widget.store, onAdd: () => _add(), onEdit: (entry) => _add(entry: entry)),
          ReceiptScreen(store: widget.store, onSaved: () => setState(() => _index = 1)),
          InsightsScreen(store: widget.store),
          SettingsScreen(store: widget.store),
        ];
        return Scaffold(
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: PebbleBottomNav(
            active: _index,
            onSelect: (index) => setState(() => _index = index),
          ),
        );
      },
    );
  }
}

class PebbleBottomNav extends StatelessWidget {
  const PebbleBottomNav({required this.active, required this.onSelect, super.key});
  final int active;
  final ValueChanged<int> onSelect;

  static const _items = <(String, IconData)>[
    ('Home', Icons.home_outlined),
    ('Expenses', Icons.receipt_long_outlined),
    ('Scan', Icons.center_focus_strong_outlined),
    ('Insights', Icons.bar_chart_outlined),
    ('Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: PebbleColors.stroke)),
      ),
      padding: const EdgeInsets.only(top: 7),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 61,
          child: Row(
            children: List.generate(_items.length, (i) {
              final isSelected = active == i;
              final foreground = isSelected ? PebbleColors.blue : PebbleColors.muted;
              return Expanded(
                child: Semantics(
                  selected: isSelected,
                  button: true,
                  label: _items[i].$1,
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        i == 2
                            ? Container(
                                height: 36, width: 48,
                                decoration: BoxDecoration(
                                  color: PebbleColors.blue,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Icon(Icons.center_focus_strong, color: Colors.white, size: 24),
                              )
                            : Icon(_items[i].$2, color: foreground, size: 26),
                        const SizedBox(height: 3),
                        Text(
                          _items[i].$1,
                          style: TextStyle(fontSize: 11, color: foreground, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class PebblePage extends StatelessWidget {
  const PebblePage({required this.title, required this.children, this.subtitle, this.smallTitle = false, this.action, super.key});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool smallTitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: smallTitle
                      ? Theme.of(context).textTheme.headlineSmall
                      : Theme.of(context).textTheme.headlineLarge)),
                  if (action != null) action!,
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
