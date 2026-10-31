import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/formatting.dart';
import '../../core/pebble_typography.dart';
import '../../data/expense_location.dart';
import '../../data/location_service.dart';
import '../../data/pebble_database.dart';
import '../../data/pebble_store.dart';
import '../pebble_root.dart';
import '../location_field.dart';
import '../receipt_viewer.dart';
import '../ui_helpers.dart';
import '../bento.dart';
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
    _category = item == null ? (widget.store.categoryNames.isEmpty ? otherCategory : widget.store.categoryNames.first) : widget.store.categoryNameFor(item.categoryId);
    // Original selection is stored by ID; the name is only for the picker.

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
    hintStyle: const TextStyle(color: Bento.muted),
    isDense: true,
    contentPadding: EdgeInsets.zero,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    filled: false,
  );

  Widget _hero() {
    Widget amount = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        const BentoFieldLabel('Amount (AUD)'),
        const SizedBox(height: 3),
        SizedBox(
          width: 160,
          child: TextFormField(
            key: const Key('amountInput'),
            controller: _amount,
            textAlign: TextAlign.end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 29, fontWeight: FontWeight.w800,
              color: Bento.ink,
              fontFeatures: PebbleTypography.tabularFigures,
            ),
            decoration: _bare('0.00').copyWith(
              prefixText: r'$',
              prefixStyle: const TextStyle(
                color: Bento.ink, fontSize: 29, fontWeight: FontWeight.w800,
                fontFeatures: PebbleTypography.tabularFigures,
              ),
            ),
            validator: (value) => parseAmount(value ?? '') == null
              ? 'Enter a valid amount'
              : null,
          ),
        ),
      ],
    );
    final category = widget.store.categoryNames.contains(_category)
        ? _category : otherCategory;
    final style = categoryStyle(widget.store, category);
    Widget merchant = AnimatedBuilder(
      animation: Listenable.merge([_merchant, _description]),
      builder: (context, _) {
        final label = _merchant.text.trim().isNotEmpty
          ? _merchant.text.trim()
          : _description.text.trim().isNotEmpty
            ? _description.text.trim() : 'New expense';
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F0FF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(style.icon, color: Bento.blue, size: 26),
          ),
          const SizedBox(width: 10),
          Flexible(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: Bento.ink)),
              const SizedBox(height: 3),
              Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Bento.muted, fontSize: 11)),
            ],
          )),
        ]);
      },
    );
    return BentoTile(
      keyName: 'bentoAmountHero',
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 327) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              merchant,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: amount),
            ],
          );
        }
        return Row(children: [
          Expanded(child: merchant),
          const SizedBox(width: 8),
          amount,
        ]);
      }),
    );
  }

  Widget _dateTile() => BentoTile(
    onTap: _selectDate,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    child: Row(children: [
      const BentoIcon(Icons.calendar_month_outlined,
        background: Bento.mint, color: Color(0xFF129B74)),
      const SizedBox(width: 8),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BentoFieldLabel('Date'),
          const SizedBox(height: 5),
          Text(friendlyDate.format(_date),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12,
              color: Bento.ink, fontWeight: FontWeight.w700)),
        ],
      )),
      const Icon(Icons.chevron_right, size: 16, color: Bento.muted),
    ]),
  );

  Widget _paymentTile() => BentoTile(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    child: Row(children: [
      const BentoIcon(Icons.credit_card_outlined),
      const SizedBox(width: 8),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BentoFieldLabel('Payment'),
          const SizedBox(height: 3),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('paymentMethodInput'),
              isExpanded: true, isDense: true,
              value: _paymentMethod,
              hint: const Text('Not set',
                style: TextStyle(fontSize: 12, color: Bento.muted)),
              icon: const Icon(Icons.keyboard_arrow_down,
                size: 17, color: Bento.muted),
              items: ['Card', 'Cash', 'Bank transfer', 'Other']
                .map((method) => DropdownMenuItem(
                  value: method,
                  child: Text(method,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Bento.ink, fontSize: 12,
                      fontWeight: FontWeight.w700)),
                )).toList(),
              onChanged: (value) => setState(() => _paymentMethod = value),
            ),
          ),
        ],
      )),
    ]),
  );

  Widget _inputTile({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    Key? fieldKey,
    String? Function(String?)? validator,
    int? maxLength,
    int maxLines = 1,
  }) => BentoTile(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Icon(icon, color: Bento.muted, size: 19),
      ),
      const SizedBox(width: 11),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BentoFieldLabel(label),
          const SizedBox(height: 6),
          TextFormField(
            key: fieldKey,
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            maxLength: maxLength,
            maxLines: maxLines,
            style: const TextStyle(
              color: Bento.ink, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: _bare(hint),
            validator: validator,
          ),
        ],
      )),
    ]),
  );

  Widget _categories() => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final categories = widget.store.categoryNames;
      return SizedBox(
        height: 92,
        child: ListView(
          key: const Key('bentoCategories'),
          scrollDirection: Axis.horizontal,
          children: [
            for (final category in categories)
              Builder(builder: (context) {
                final style = categoryStyle(widget.store, category);
                final selected = _category == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: category,
                    child: Material(
                      color: style.background,
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        key: Key('category_' + category),
                        onTap: () => setState(() => _category = category),
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          width: 85,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected ? Bento.blue : Bento.line,
                              width: selected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(style.icon, color: style.foreground, size: 26),
                              const SizedBox(height: 7),
                              Text(category, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Bento.ink,
                                  fontWeight: selected
                                    ? FontWeight.w800 : FontWeight.w600)),
                              if (selected) const Icon(Icons.check_rounded,
                                size: 12, color: Bento.blue),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                key: const Key('newCategoryTile'),
                borderRadius: BorderRadius.circular(15),
                onTap: _newCategory,
                child: Container(
                  width: 79,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Bento.line, width: 1.3)),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 28, color: Bento.blue),
                      SizedBox(height: 7),
                      Text('New', style: TextStyle(
                        color: Bento.blue, fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _receiptPhoto(File photo) => Stack(children: [
    ReceiptThumbnail(file: photo, height: 174, fillWidth: true),
    Positioned(right: 10, top: 10, child: Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _attach,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.camera_alt_outlined, color: Bento.ink, size: 17),
            SizedBox(width: 6),
            Text('Replace', style: TextStyle(
              color: Bento.ink, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    )),
  ]);

  Widget _receipt() {
    if (_attachment != null) {
      return _receiptPhoto(File(_attachment!.path));
    }
    if (widget.entry?.receiptPath != null) {
      return FutureBuilder<File?>(
        future: _savedReceipt,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 174, child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.data == null) {
            return BentoTile(
              child: const Text('Receipt photo unavailable',
                style: TextStyle(color: Bento.muted)),
            );
          }
          return _receiptPhoto(snapshot.data!);
        },
      );
    }
    return BentoTile(
      onTap: _attach,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: const Row(children: [
        BentoIcon(Icons.add_photo_alternate_outlined),
        SizedBox(width: 12),
        Expanded(child: Text('Attach photo or receipt',
          style: TextStyle(color: Bento.blue, fontWeight: FontWeight.w700))),
        Icon(Icons.chevron_right, color: Bento.blue),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: Bento.canvas,
      resizeToAvoidBottomInset: true,
      body: Form(
        key: _formKey,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Bento.ink),
                    ),
                    const SizedBox(width: 5),
                    Expanded(child: Text(
                      widget.entry == null ? 'Add Expense' : 'Edit Expense',
                      style: const TextStyle(
                        fontFamily: PebbleTypography.editorial,
                        fontSize: 27, fontWeight: FontWeight.w700,
                        color: Bento.ink),
                    )),
                    TextButton.icon(
                      onPressed: () => widget.onSwitchTab(2),
                      icon: const Icon(Icons.document_scanner_outlined, size: 18),
                      label: const Text('Scan'),
                    ),
                    if (widget.entry != null)
                      IconButton(
                        tooltip: 'Delete expense',
                        onPressed: _saving ? null : _delete,
                        icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFD74343)),
                      ),
                  ]),
                  const SizedBox(height: 11),
                  _hero(),
                  const SizedBox(height: 10),
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth < 350) {
                      return Column(children: [
                        _dateTile(),
                        const SizedBox(height: 9),
                        _paymentTile(),
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: _dateTile()),
                      const SizedBox(width: 9),
                      Expanded(child: _paymentTile()),
                    ]);
                  }),
                  const SizedBox(height: 16),
                  BentoSectionTitle(
                    label: 'Category',
                    action: TextButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CategoriesScreen(store: widget.store)),
                        );
                      },
                      child: const Text('Manage'),
                    ),
                  ),
                  const SizedBox(height: 7),
                  _categories(),
                  const SizedBox(height: 15),
                  const BentoSectionTitle(label: 'Details'),
                  const SizedBox(height: 8),
                  _inputTile(
                    label: 'Description',
                    icon: Icons.notes_rounded,
                    controller: _description,
                    fieldKey: const Key('descriptionInput'),
                    hint: 'What did you spend on?',
                    maxLength: 240,
                    validator: (v) => v == null || v.trim().isEmpty
                      ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 9),
                  _inputTile(
                    label: 'Merchant (optional)',
                    icon: Icons.storefront_outlined,
                    controller: _merchant,
                    hint: 'Store or merchant name',
                  ),
                  const SizedBox(height: 15),
                  LocationField(
                    bento: true,
                    value: _location,
                    service: widget.locationService,
                    onChanged: (value) => setState(() => _location = value),
                  ),
                  const SizedBox(height: 15),
                  const BentoSectionTitle(label: 'Receipt'),
                  const SizedBox(height: 8),
                  _receipt(),
                  const SizedBox(height: 14),
                  _inputTile(
                    label: 'Notes (optional)',
                    icon: Icons.sticky_note_2_outlined,
                    controller: _notes,
                    hint: 'Add a note...',
                    maxLines: 2,
                    maxLength: 200,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!keyboardOpen)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Bento.canvas,
                border: Border(top: BorderSide(color: Bento.line)),
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
                    child: BentoSaveButton(
                      onPressed: _saving ? null : _save,
                      label: _saving ? 'Saving...' : widget.entry == null
                        ? 'Save expense' : 'Save changes',
                    ),
                  ),
                ),
              ),
            ),
          PebbleBottomNav(active: 1, onSelect: widget.onSwitchTab),
        ],
      ),
    );
  }
}
