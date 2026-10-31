import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/formatting.dart';
import '../data/pebble_store.dart';

/// Settings editor for the single monthly budget shared by every month.
/// All amounts are parsed as integer AUD cents (not floating-point values).
class MonthlyBudgetDialog extends StatefulWidget {
  const MonthlyBudgetDialog({required this.store, super.key});

  final PebbleStore store;

  @override
  State<MonthlyBudgetDialog> createState() => _MonthlyBudgetDialogState();
}

class _MonthlyBudgetDialogState extends State<MonthlyBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final cents = widget.store.monthlyBudgetCents;
    _amount = TextEditingController(
      text: (cents ~/ 100).toString() + '.' + (cents % 100).toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? _validate(String? text) {
    if (parseAmount(text ?? '') == null) {
      return 'Enter an amount greater than zero, e.g. 2500.00';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final cents = parseAmount(_amount.text);
    if (cents == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.store.setMonthlyBudgetCents(cents);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _saveError = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('monthlyBudgetDialog'),
      titlePadding: const EdgeInsets.fromLTRB(24, 23, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      title: const Row(children: [
        Icon(Icons.account_balance_wallet_outlined, color: PebbleColors.blue),
        SizedBox(width: 10),
        Expanded(child: Text('Monthly budget',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose how much you plan to spend each month. '
                  'Your Home dashboard will use this amount immediately.',
                  style: TextStyle(color: PebbleColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('monthlyBudgetInput'),
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Budget amount',
                    prefixText: r'$ ',
                    suffixText: 'AUD',
                    hintText: '2500.00',
                    helperText: 'Applies to every month until you change it.',
                  ),
                  validator: _validate,
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 10),
                  Text(_saveError!,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveMonthlyBudget'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save budget'),
        ),
      ],
    );
  }
}
