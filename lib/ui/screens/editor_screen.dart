import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/formatting.dart';
import '../../data/expense_location.dart';
import '../../data/location_service.dart';
import '../../data/pebble_database.dart';
import '../../data/pebble_store.dart';
import '../pebble_root.dart';
import '../location_field.dart';
import '../receipt_viewer.dart';
import '../ui_helpers.dart';
import '../watercolor.dart';
import 'categories_screen.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.store,
    required this.onSwitchTab,
    this.entry,
    this.locationService = const DeviceLocationService(),
    super.key,
  });

  final PebbleStore store;
  final ExpenseEntry? entry;
  final ValueChanged<int> onSwitchTab;
  final LocationService locationService;

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
  /// Null when an existing expense has no payment method (e.g. saved from a receipt).
  String? _paymentMethod;
  Future<File?>? _savedReceipt;
  XFile? _attachment;
  ExpenseLocation? _location;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.entry;
    _date = item?.date ?? DateTime.now();
    _location = item == null ? null : ExpenseLocation.of(item);
    _category = item?.category ??
        (widget.store.categoryNames.isEmpty ? otherCategory : widget.store.categoryNames.first);
    _paymentMethod = item == null ? 'Card' : item.paymentMethod;
    // Load the saved photo once, not on every rebuild.
    _savedReceipt = widget.store.receiptFile(item?.receiptPath);
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

  Future<void> _newCategory() async {
    final name = await showCategoryEditor(context, widget.store);
    if (mounted && name != null) setState(() => _category = name);
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
        // The category may have been deleted elsewhere while this screen was open.
        category: widget.store.categoryNames.contains(_category) ? _category : otherCategory,
        paymentMethod: _paymentMethod,
        merchant: _merchant.text,
        notes: _notes.text,
        image: _attachment,
        existingReceiptPath: entry?.receiptPath,
        location: _location,
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

  InputDecoration _bare(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Watercolor.muted),
    isDense: true,
    contentPadding: EdgeInsets.zero,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    filled: false,
  );

  Widget _smallLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(label, style: const TextStyle(
      fontSize: 12, color: Watercolor.muted, fontWeight: FontWeight.w600)),
  );

  Widget _dateCard() => WatercolorPanel(
    tint: const Color(0xFFFFFBF5),
    onTap: _selectDate,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    child: Row(children: [
      const WatercolorIcon(Icons.calendar_month_outlined),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _smallLabel('Date'),
        Text(friendlyDate.format(_date), maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Watercolor.ink)),
      ])),
      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Watercolor.muted),
    ]),
  );

  Widget _paymentCard() => WatercolorPanel(
    tint: const Color(0xFFFFFBF5),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Row(children: [
      const WatercolorIcon(Icons.credit_card_outlined),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _smallLabel('Payment method'),
        DropdownButtonHideUnderline(child: DropdownButton<String>(
          key: const Key('paymentMethodInput'),
          isDense: true,
          isExpanded: true,
          value: _paymentMethod,
          hint: const Text('Not set', style: TextStyle(fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: ['Card', 'Cash', 'Bank transfer', 'Other'].map((value) =>
            DropdownMenuItem<String>(
              value: value,
              child: Text(value, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Watercolor.ink)),
            )).toList(),
          onChanged: (value) => setState(() => _paymentMethod = value),
        )),
      ])),
    ]),
  );

  Widget _inputRow({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? Function(String?)? validator,
    int? maxLength,
    Key? fieldKey,
    int maxLines = 1,
  }) => WatercolorPanel(
    tint: const Color(0xFFFFFBF5),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 9),
        child: WatercolorIcon(icon, tint: Watercolor.lilac)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _smallLabel(label),
        TextFormField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: _bare(hint),
          style: const TextStyle(fontSize: 14, color: Watercolor.ink,
            fontWeight: FontWeight.w600),
          validator: validator,
        ),
      ])),
    ]),
  );

  Widget _categoryTiles() => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
      final tileWidth = (constraints.maxWidth - 24) / 4;
      final names = widget.store.categoryNames;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final category in names)
          Builder(builder: (context) {
            final selected = _category == category;
            final style = categoryStyle(widget.store, category);
            return Semantics(
              button: true, selected: selected, label: category,
              child: InkWell(
                key: Key('category_' + category),
                onTap: () => setState(() => _category = category),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: tileWidth, height: 74,
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: selected ? style.foreground : Watercolor.stroke,
                      width: selected ? 2 : 0.7),
                  ),
                  child: Stack(children: [
                    const Positioned.fill(child: IgnorePointer(
                      child: CustomPaint(painter: _TilePigment()))),
                    Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 26, color: style.foreground),
                        const SizedBox(height: 4),
                        Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Watercolor.ink,
                            fontSize: 11, fontWeight: selected
                              ? FontWeight.w800 : FontWeight.w600)),
                      ],
                    )),
                    if (selected) Positioned(right: 4, top: 4,
                      child: CircleAvatar(radius: 9,
                        backgroundColor: style.foreground,
                        child: const Icon(Icons.check, size: 11, color: Colors.white))),
                  ]),
                ),
              ),
            );
          }),
        InkWell(
          key: const Key('newCategoryTile'),
          onTap: _newCategory,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: tileWidth, height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF5),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Watercolor.stroke, width: 1.5)),
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, size: 27, color: Watercolor.cobalt),
              SizedBox(height: 4),
              Text('New', style: TextStyle(color: Watercolor.cobalt,
                fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]);
    }),
  );

  Widget _receiptSection() => Column(
    children: [
      WatercolorPanel(
        tint: const Color(0xFFEDF3FF),
        padding: EdgeInsets.zero,
        onTap: _attach,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            const Icon(Icons.attach_file_rounded, color: Watercolor.cobalt),
            const SizedBox(width: 10),
            Expanded(child: Text(_attachment == null
                ? 'Attach photo or receipt' : 'Replace receipt photo',
              style: const TextStyle(fontWeight: FontWeight.w700,
                color: Watercolor.cobalt))),
            const Icon(Icons.chevron_right_rounded, color: Watercolor.cobalt),
          ]),
        ),
      ),
      if (_attachment != null) ...[
        const SizedBox(height: 10),
        ReceiptThumbnail(file: File(_attachment!.path), height: 295, fillWidth: true),
      ] else if (widget.entry?.receiptPath != null) ...[
        const SizedBox(height: 10),
        FutureBuilder<File?>(
          future: _savedReceipt,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 180,
                child: Center(child: CircularProgressIndicator()));
            }
            final file = snapshot.data;
            return file == null
              ? const Text('Receipt photo unavailable',
                  style: TextStyle(color: Watercolor.muted))
              : ReceiptThumbnail(file: file, height: 295, fillWidth: true);
          },
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Watercolor.paper,
      body: WatercolorCanvas(
        child: Form(
          key: _formKey,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(17, 12, 17, 28),
                  children: [
                    Row(children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                          color: Watercolor.ink)),
                      const SizedBox(width: 3),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.entry == null ? 'Add expense' : 'Edit expense',
                            style: const TextStyle(
                              color: Watercolor.ink, fontFamily: 'serif',
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700, fontSize: 29)),
                          Text(widget.entry == null ? 'A new little moment' : 'Update this saved expense',
                            style: const TextStyle(
                              fontSize: 12, color: Watercolor.muted)),
                        ],
                      )),
                      if (widget.entry != null)
                        IconButton(tooltip: 'Delete expense',
                          onPressed: _saving ? null : _delete,
                          icon: const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFD74542))),
                      IconButton(tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                          color: Watercolor.ink)),
                    ]),
                    const SizedBox(height: 17),
                    Row(children: [
                      WatercolorSegment(label: 'Manual', icon: Icons.edit_outlined,
                        selected: true, onTap: () {}),
                      const SizedBox(width: 8),
                      WatercolorSegment(label: 'Receipt', icon: Icons.camera_alt_outlined,
                        selected: false,
                        onTap: () => widget.onSwitchTab(2)),
                    ]),
                    const SizedBox(height: 14),
                    WatercolorPanel(
                      tint: const Color(0xFFE9F6FE),
                      padding: const EdgeInsets.fromLTRB(17, 14, 18, 14),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _smallLabel('Amount (AUD)'),
                            TextFormField(
                              key: const Key('amountInput'),
                              controller: _amount,
                              style: const TextStyle(
                                fontSize: 40, fontWeight: FontWeight.w800,
                                color: Watercolor.ink),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                              decoration: _bare('0.00').copyWith(
                                prefixText: r'$',
                                prefixStyle: const TextStyle(
                                  fontSize: 40, fontWeight: FontWeight.w800,
                                  color: Watercolor.ink)),
                              validator: (v) => parseAmount(v ?? '') == null
                                ? 'Enter an amount greater than zero (e.g. 12.50)'
                                : null,
                            ),
                          ],
                        )),
                        const WatercolorIcon(Icons.calculate_outlined,
                          tint: Color(0xFFD5EAFB)),
                      ]),
                    ),
                    const SizedBox(height: 11),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _dateCard()),
                      const SizedBox(width: 9),
                      Expanded(child: _paymentCard()),
                    ]),
                    const SizedBox(height: 11),
                    _inputRow(
                      label: 'Description', icon: Icons.notes_outlined,
                      controller: _description,
                      fieldKey: const Key('descriptionInput'),
                      hint: 'What did you spend on?',
                      maxLength: 240,
                      validator: (v) => v == null || v.trim().isEmpty
                        ? 'Description is required' : null,
                    ),
                    const SizedBox(height: 17),
                    WatercolorSection(
                      title: 'Category',
                      trailing: TextButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) =>
                              CategoriesScreen(store: widget.store)),
                          );
                        },
                        child: const Text('Manage ›',
                          style: TextStyle(color: Watercolor.cobalt)),
                      ),
                    ),
                    const SizedBox(height: 7),
                    _categoryTiles(),
                    const SizedBox(height: 12),
                    _inputRow(
                      label: 'Merchant (optional)', icon: Icons.storefront_outlined,
                      controller: _merchant, hint: 'Merchant name',
                    ),
                    const SizedBox(height: 13),
                    LocationField(
                      value: _location,
                      service: widget.locationService,
                      onChanged: (value) => setState(() => _location = value),
                    ),
                    const SizedBox(height: 12),
                    _inputRow(
                      label: 'Notes (optional)', icon: Icons.note_alt_outlined,
                      controller: _notes, hint: 'Add a note...',
                      maxLines: 2, maxLength: 200,
                    ),
                    const SizedBox(height: 12),
                    _receiptSection(),
                    const SizedBox(height: 18),
                    WatercolorSave(
                      label: _saving ? 'Saving...' : 'Save expense',
                      onPressed: _saving ? null : _save,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: PebbleBottomNav(
        active: 1, onSelect: widget.onSwitchTab),
    );
  }
}

/// Gentle painted highlight on category squares; never blocks interactions.
class _TilePigment extends CustomPainter {
  const _TilePigment();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .16);
    canvas.drawOval(Rect.fromLTWH(-9, -14, size.width * .86,
      size.height * .83), paint);
    paint.color = const Color(0xFFFFF0DF).withValues(alpha: .28);
    canvas.drawOval(Rect.fromLTWH(size.width * .50, size.height * .45,
      size.width * .65, size.height * .7), paint);
  }

  @override
  bool shouldRepaint(covariant _TilePigment oldDelegate) => false;
}
