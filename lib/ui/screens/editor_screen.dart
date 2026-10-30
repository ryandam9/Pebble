import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design.dart';
import '../../core/formatting.dart';
import '../../data/pebble_database.dart';
import '../../data/pebble_store.dart';
import '../pebble_root.dart';
import '../ui_helpers.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.store,
    required this.onSwitchTab,
    this.entry,
    super.key,
  });

  final PebbleStore store;
  final ExpenseEntry? entry;
  final ValueChanged<int> onSwitchTab;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _merchant;
  late final TextEditingController _notes;
  late DateTime _date;
  late String _category;
  late String _paymentMethod;
  XFile? _attachment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.entry;
    _date = item?.date ?? DateTime.now();
    _category = item?.category ?? 'Groceries';
    _paymentMethod = item?.paymentMethod ?? 'Card';
    _amount = TextEditingController(text: item == null ? '' : (item.amountCents / 100).toStringAsFixed(2));
    _description = TextEditingController(text: item?.description ?? '');
    _merchant = TextEditingController(text: item?.merchant ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _merchant.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _attach() async {
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (!mounted || photo == null) return;
      setState(() => _attachment = photo);
    } catch (error) {
      if (mounted) _message('Could not open photo library: ' + error.toString());
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final cents = parseAmount(_amount.text);
    if (cents == null) return;
    setState(() => _saving = true);
    try {
      final entry = widget.entry;
      await widget.store.save(
        id: entry?.id,
        date: _date,
        amountCents: cents,
        description: _description.text,
        category: _category,
        paymentMethod: _paymentMethod,
        merchant: _merchant.text,
        notes: _notes.text,
        image: _attachment,
        existingReceiptPath: entry?.receiptPath,
        createdAt: entry?.createdAt,
      );
      if (!mounted) return;
      _message(entry == null ? 'Expense saved' : 'Expense updated');
      Navigator.of(context).pop(1);
    } catch (error) {
      if (mounted) _message('Unable to save expense: ' + error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This removes the expense and its saved receipt photo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.store.deleteExpense(entry);
      if (mounted) Navigator.of(context).pop(1);
    } catch (error) {
      if (mounted) _message('Unable to delete: ' + error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: PebblePage(
          title: widget.entry == null ? 'Add expense' : 'Edit expense',
          subtitle: widget.entry == null ? 'Fast manual entry' : 'Update this saved expense',
          smallTitle: true,
          action: IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
          children: [
            Row(children: [
              Expanded(child: _MethodSegment(
                text: 'Manual', icon: Icons.edit_outlined, selected: true, onTap: () {},
              )),
              const SizedBox(width: 7),
              Expanded(child: _MethodSegment(
                text: 'Receipt', icon: Icons.camera_alt_outlined, selected: false,
                onTap: () => widget.onSwitchTab(2),
              )),
            ]),
            const SizedBox(height: 17),
            PebbleCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('AMOUNT (AUD)', style: TextStyle(fontSize: 12, color: PebbleColors.muted, fontWeight: FontWeight.w700)),
                TextFormField(
                  key: const Key('amountInput'),
                  controller: _amount,
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: PebbleColors.ink),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: r'$',
                    prefixStyle: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: PebbleColors.ink),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (v) => parseAmount(v ?? '') == null ? 'Enter an amount greater than zero (e.g. 12.50)' : null,
                ),
              ]),
            ),
            const SizedBox(height: 12),
            PebbleCard(
              onTap: _selectDate,
              child: Row(children: [
                const Icon(Icons.calendar_month_outlined, color: PebbleColors.muted),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('DATE', style: TextStyle(fontSize: 11, color: PebbleColors.muted)),
                  const SizedBox(height: 4),
                  Text(friendlyDate.format(_date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ])),
                const Icon(Icons.keyboard_arrow_down, color: PebbleColors.muted),
              ]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('descriptionInput'),
              controller: _description,
              maxLength: 240,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'What did you spend on?',
                prefixIcon: Icon(Icons.notes_outlined)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
            ),
            const SizedBox(height: 5),
            const Text('Category', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 24) / 4;
              return Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(categoryNames.length, (i) {
                  final category = categoryNames[i];
                  final selected = _category == category;
                  return InkWell(
                    onTap: () => setState(() => _category = category),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: tileWidth, height: 74,
                      decoration: BoxDecoration(
                        color: categoryBackgrounds[i],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? categoryForegrounds[i] : Colors.transparent, width: 2),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(categoryIcons[i], color: categoryForegrounds[i]),
                        const SizedBox(height: 5),
                        Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  );
                }),
              );
            }),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment method',
                prefixIcon: Icon(Icons.credit_card_outlined)),
              items: ['Card', 'Cash', 'Bank transfer', 'Other'].map((value) =>
                DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => _paymentMethod = value ?? 'Card'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _merchant,
              decoration: const InputDecoration(labelText: 'Merchant (optional)',
                hintText: 'e.g. Woolworths', prefixIcon: Icon(Icons.store_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Notes (optional)',
                hintText: 'Add a note...', prefixIcon: Icon(Icons.edit_note_outlined)),
            ),
            PebbleCard(
              color: const Color(0xFFF1F6FE),
              onTap: _attach,
              child: Row(children: [
                const Icon(Icons.attach_file, color: PebbleColors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _attachment == null ? 'Attach photo or receipt'
                      : 'Replace: ' + _attachment!.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PebbleColors.blue, fontWeight: FontWeight.w700),
                )),
                const Icon(Icons.chevron_right, color: PebbleColors.blue),
              ]),
            ),
            if (_attachment != null) ...[
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(14),
                child: Image.file(File(_attachment!.path), height: 130, fit: BoxFit.contain)),
            ] else if (widget.entry?.receiptPath != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<File?>(
                future: widget.store.receiptFile(widget.entry!.receiptPath),
                builder: (context, snapshot) {
                  final file = snapshot.data;
                  return file == null ? const Text('Receipt image unavailable')
                      : ClipRRect(borderRadius: BorderRadius.circular(14),
                          child: Image.file(file, height: 130, fit: BoxFit.contain));
                },
              ),
            ],
            const SizedBox(height: 18),
            PebbleButton(label: _saving ? 'Saving...' : 'Save expense',
              onPressed: _saving ? null : _save),
            if (widget.entry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline), label: const Text('Delete expense')),
            ],
            const SizedBox(height: 5),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        ),
      ),
      bottomNavigationBar: PebbleBottomNav(active: 1, onSelect: widget.onSwitchTab),
    );
  }
}

class _MethodSegment extends StatelessWidget {
  const _MethodSegment({required this.text, required this.icon, required this.selected, required this.onTap});
  final String text;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    decoration: BoxDecoration(
      color: selected ? PebbleColors.blue : const Color(0xFFE9EDF5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: selected ? Colors.white : PebbleColors.muted),
        const SizedBox(width: 9),
        Text(text, style: TextStyle(color: selected ? Colors.white : PebbleColors.muted,
          fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}
