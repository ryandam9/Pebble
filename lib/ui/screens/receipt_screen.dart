import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design.dart';
import '../../core/formatting.dart';
import '../../data/pebble_database.dart';
import '../../data/pebble_store.dart';
import '../../data/receipt_scanner.dart';
import '../pebble_root.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({required this.store, required this.onSaved, super.key});
  final PebbleStore store;
  final VoidCallback onSaved;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _scanner = ReceiptScanner();
  final _form = GlobalKey<FormState>();
  final _merchant = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _tax = TextEditingController();

  ReceiptDraft? _draft;
  DateTime _date = DateTime.now();
  String? _category;

  /// The picked category if it still exists, otherwise the first one.
  String get _effectiveCategory {
    final names = widget.store.categoryNames;
    if (_category != null && names.contains(_category)) return _category!;
    return names.isEmpty ? otherCategory : names.first;
  }
  bool _busy = false;

  @override
  void dispose() {
    _merchant.dispose();
    _description.dispose();
    _amount.dispose();
    _tax.dispose();
    super.dispose();
  }

  Future<void> _capture(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final draft = await _scanner.pickAndRecognize(source);
      if (!mounted || draft == null) return;
      _merchant.text = draft.merchant ?? '';
      _description.text = draft.merchant ?? '';
      _amount.text = draft.totalCents == null ? '' : (draft.totalCents! / 100).toStringAsFixed(2);
      _tax.text = draft.taxCents == null ? '' : (draft.taxCents! / 100).toStringAsFixed(2);
      setState(() {
        _draft = draft;
        _date = draft.date ?? DateTime.now();
      });
    } catch (error) {
      if (mounted) _snack('Unable to scan receipt: ' + error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _textLineSummary(String rawText) {
    final lines = rawText.split('\n').where((line) => line.trim().isNotEmpty).length;
    return switch (lines) {
      0 => 'no text detected',
      1 => '1 text line detected',
      _ => '$lines text lines detected',
    };
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _selectDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_draft == null || !_form.currentState!.validate() || _busy) return;
    final amount = parseAmount(_amount.text);
    if (amount == null) return;
    setState(() => _busy = true);
    try {
      await widget.store.save(
        date: _date,
        amountCents: amount,
        description: _description.text,
        category: _effectiveCategory,
        merchant: _merchant.text,
        notes: _tax.text.trim().isEmpty ? null : 'Receipt GST (AUD): ' + _tax.text.trim(),
        image: _draft!.image,
      );
      if (!mounted) return;
      setState(() => _draft = null);
      _snack('Receipt expense saved');
      widget.onSaved();
    } catch (error) {
      if (mounted) _snack('Could not save receipt: ' + error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return PebblePage(
      title: 'Scan receipt',
      subtitle: 'Review the OCR result before saving',
      smallTitle: true,
      children: [
        if (draft == null) ...[
          PebbleCard(
            child: Column(children: [
              const SizedBox(height: 22),
              const CircleAvatar(
                radius: 46,
                backgroundColor: Color(0xFFEDE6FF),
                child: Icon(Icons.document_scanner_outlined, color: PebbleColors.purple, size: 45),
              ),
              const SizedBox(height: 16),
              const Text('Capture your receipt', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                ReceiptScanner.supportsOcr
                    ? 'Pebble recognises printed text on your device. Check the detected amount and date before saving.'
                    : 'Text recognition is not available on this platform. Attach the receipt image and enter the details yourself.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: PebbleColors.muted, height: 1.5),
              ),
              const SizedBox(height: 22),
              if (ReceiptScanner.supportsCamera) ...[
                PebbleButton(
                  label: _busy ? 'Scanning...' : 'Take a photo',
                  icon: Icons.camera_alt_outlined,
                  onPressed: _busy ? null : () => _capture(ImageSource.camera),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _capture(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                ),
              ] else
                PebbleButton(
                  label: _busy ? 'Opening...' : 'Choose receipt image',
                  icon: Icons.folder_open_outlined,
                  onPressed: _busy ? null : () => _capture(ImageSource.gallery),
                ),
              const SizedBox(height: 14),
            ]),
          ),
          const SizedBox(height: 14),
          const PebbleCard(
            color: Color(0xFFECF8F1),
            child: Row(children: [
              Icon(Icons.lock_outline, color: PebbleColors.green),
              SizedBox(width: 12),
              Expanded(child: Text('Receipt OCR runs locally. Nothing is uploaded to a server.',
                style: TextStyle(fontSize: 13, color: PebbleColors.ink))),
            ]),
          ),
        ] else ...[
          PebbleCard(
            padding: EdgeInsets.zero,
            child: Image.file(File(draft.image.path), fit: BoxFit.contain, height: 300, width: double.infinity),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Text('Recognised fields', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            TextButton.icon(onPressed: _busy ? null : () => _capture(
                ReceiptScanner.supportsCamera ? ImageSource.camera : ImageSource.gallery),
              icon: const Icon(Icons.refresh), label: const Text('Retake')),
          ]),
          const SizedBox(height: 8),
          Form(
            key: _form,
            child: PebbleCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Every field is editable. Verify the total against the photo.',
                  style: TextStyle(fontSize: 12, color: PebbleColors.muted)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _merchant,
                  decoration: const InputDecoration(labelText: 'Merchant', prefixIcon: Icon(Icons.store_outlined)),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  maxLength: 240,
                  decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_outlined)),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Description required' : null,
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_month_outlined)),
                    child: Text(friendlyDate.format(_date)),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('ocrAmountInput'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Total amount (AUD)',
                    prefixIcon: Icon(Icons.attach_money)),
                  validator: (v) => parseAmount(v ?? '') == null ? 'Confirm a positive amount' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tax,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'GST (optional)', prefixIcon: Icon(Icons.receipt_outlined)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _effectiveCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.store.categoryNames.map((category) =>
                    DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: (value) => setState(() => _category = value),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          PebbleCard(
            color: const Color(0xFFECF8F1),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, color: PebbleColors.green),
              const SizedBox(width: 10),
              Expanded(child: Text('Receipt attached · ${_textLineSummary(draft.rawText)}. '
                'Nothing is saved until you confirm.',
                style: const TextStyle(fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 14),
          PebbleButton(label: _busy ? 'Saving...' : 'Confirm & save',
            onPressed: _busy ? null : _save),
          const SizedBox(height: 10),
          TextButton(onPressed: _busy ? null : () => setState(() => _draft = null),
            child: const Text('Discard scan')),
        ],
      ],
    );
  }
}
