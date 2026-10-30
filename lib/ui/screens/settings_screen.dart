import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../data/pebble_store.dart';
import '../pebble_root.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.store, super.key});
  final PebbleStore store;

  @override
  Widget build(BuildContext context) {
    return PebblePage(
      title: 'Settings',
      subtitle: 'Your data stays yours',
      children: [
        PebbleCard(color: const Color(0xFFDFF8EB), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined, size: 30, color: PebbleColors.green),
            const SizedBox(height: 12),
            const Text('Private, offline-first storage',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
            const SizedBox(height: 8),
            const Text('Expense records are stored in local SQLite. Receipt photos are kept in Pebble’s private app folder.',
              style: TextStyle(color: PebbleColors.ink, height: 1.45)),
          ],
        )),
        const SizedBox(height: 16),
        PebbleCard(child: Column(children: [
          _SettingRow(icon: Icons.storage_outlined, title: 'Local database',
            detail: store.expenses.length.toString() + ' expenses recorded'),
          const Divider(color: PebbleColors.stroke),
          _SettingRow(icon: Icons.receipt_long_outlined, title: 'Receipt photos',
            detail: store.expenses.where((e) => e.receiptPath != null).length.toString() + ' attached'),
          const Divider(color: PebbleColors.stroke),
          const _SettingRow(icon: Icons.payments_outlined, title: 'Currency',
            detail: 'Australian dollars (AUD)'),
          const Divider(color: PebbleColors.stroke),
          const _SettingRow(icon: Icons.account_balance_wallet_outlined, title: 'Reference budget',
            detail: r'$2,000 per month (visual baseline for this milestone)'),
        ])),
        const SizedBox(height: 16),
        const PebbleCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Upcoming milestones',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          SizedBox(height: 9),
          Text('Configurable budgets, CSV export, full ZIP backup/restore, and an Android/iOS release build are specified but not yet implemented.',
            style: TextStyle(height: 1.5, color: PebbleColors.muted)),
        ])),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, color: PebbleColors.blue),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 12, color: PebbleColors.muted)),
        ])),
      ]),
    );
  }
}
