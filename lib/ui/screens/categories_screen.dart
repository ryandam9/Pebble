import 'package:flutter/material.dart';

import '../../core/category_palette.dart';
import '../../core/design.dart';
import '../../data/pebble_database.dart';
import '../../data/pebble_store.dart';
import '../pebble_root.dart';

/// Lists categories and lets the user add, edit and delete them.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({required this.store, super.key});
  final PebbleStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => PebblePage(
          title: 'Categories',
          subtitle: 'Organise your spending your way',
          smallTitle: true,
          action: IconButton(tooltip: 'Back', onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back)),
          children: [
            PebbleCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: [
                for (final (i, category) in store.categories.indexed) ...[
                  if (i > 0) const Divider(color: PebbleColors.stroke, height: 1),
                  _CategoryRow(store: store, category: category),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            PebbleButton(
              label: 'Add category',
              icon: Icons.add,
              onPressed: () => showCategoryEditor(context, store),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.store, required this.category});
  final PebbleStore store;
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.fromKeys(category.iconKey, category.colorKey);
    final count = store.expenseCountFor(category.name);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: style.background,
        child: Icon(style.icon, color: style.foreground)),
      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(count == 1 ? '1 expense' : '$count expenses',
        style: const TextStyle(fontSize: 12, color: PebbleColors.muted)),
      trailing: const Icon(Icons.chevron_right, color: PebbleColors.muted),
      onTap: () => showCategoryEditor(context, store, category: category),
    );
  }
}

/// Opens the add/edit dialog. Returns the saved category's name, or null if
/// the user cancelled or deleted it.
Future<String?> showCategoryEditor(BuildContext context, PebbleStore store, {ExpenseCategory? category}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CategoryEditorDialog(store: store, category: category),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({required this.store, this.category});
  final PebbleStore store;
  final ExpenseCategory? category;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _iconKey;
  late String _colorKey;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.category == null;
  bool get _isOther => widget.category?.name == otherCategory;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _iconKey = widget.category?.iconKey ?? 'other';
    _colorKey = widget.category?.colorKey ?? 'teal';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final category = widget.category;
      final name = category == null
          ? await widget.store.addCategory(name: _name.text, iconKey: _iconKey, colorKey: _colorKey)
          : await widget.store.updateCategory(category, name: _name.text, iconKey: _iconKey, colorKey: _colorKey);
      if (mounted) Navigator.of(context).pop(name);
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = 'Could not save: $error'; });
    }
  }

  Future<void> _delete() async {
    final category = widget.category!;
    final count = widget.store.expenseCountFor(category.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: Text(count == 0
            ? 'No expenses use this category.'
            : '${count == 1 ? '1 expense' : '$count expenses'} will move to "$otherCategory".'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.store.deleteCategory(category);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = 'Could not delete: $error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = CategoryStyle.fromKeys(_iconKey, _colorKey);
    return AlertDialog(
      title: Text(_isNew ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                key: const Key('categoryNameInput'),
                controller: _name,
                enabled: !_isOther,
                autofocus: _isNew,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  helperText: _isOther ? 'Other is the fallback category and keeps its name.' : null,
                  prefixIcon: CircleAvatar(
                    radius: 14,
                    backgroundColor: preview.background,
                    child: Icon(preview.icon, size: 16, color: preview.foreground),
                  ),
                ),
                validator: _isOther
                    ? null
                    : (value) => widget.store.validateCategoryName(value ?? '', editingId: widget.category?.id),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              const Text('Icon', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final MapEntry(key: key, value: icon) in categoryIconOptions.entries)
                  _Choice(
                    selected: key == _iconKey,
                    color: preview.foreground,
                    onTap: () => setState(() => _iconKey = key),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: key == _iconKey ? preview.background : Colors.transparent,
                      child: Icon(icon, size: 20, color: key == _iconKey ? preview.foreground : PebbleColors.muted),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              const Text('Colour', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final MapEntry(key: key, value: (background, foreground)) in categoryColorOptions.entries)
                  _Choice(
                    selected: key == _colorKey,
                    color: foreground,
                    tooltip: key,
                    onTap: () => setState(() => _colorKey = key),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: background,
                      child: CircleAvatar(radius: 8, backgroundColor: foreground),
                    ),
                  ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        if (!_isNew && !_isOther)
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

/// A tappable swatch with a ring when selected.
class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.color, required this.onTap, required this.child, this.tooltip});
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final swatch = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: child,
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: tooltip == null ? swatch : Tooltip(message: tooltip!, child: swatch),
    );
  }
}
