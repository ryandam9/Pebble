import 'dart:io';
import 'dart:math' as math;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'data/demo_expenses.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'core/formatters.dart';
import 'data/expense_repository.dart';
import 'theme/pebble_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final store = SqliteExpenseStore();
  if (const bool.fromEnvironment('PEBBLE_DEMO')) {
    await seedDemoExpenses(store);
  }
  runApp(PebbleApp(store: store));
}

const categories = ['Groceries', 'Food', 'Travel', 'Bills', 'Shopping', 'Health', 'Other'];
const categoryIcons = [
  Icons.local_grocery_store_rounded, Icons.restaurant_rounded,
  Icons.directions_car_rounded, Icons.receipt_long_rounded,
  Icons.shopping_bag_rounded, Icons.medical_services_rounded,
  Icons.more_horiz_rounded,
];
const categoryColors = [
  PebbleColors.green, PebbleColors.coral, PebbleColors.blue,
  PebbleColors.orange, PebbleColors.purple, Color(0xFF4BA3AD),
  PebbleColors.muted,
];

Color categoryColor(String category) {
  final index = categories.indexOf(category);
  return categoryColors[index < 0 ? categoryColors.length - 1 : index];
}

class PebbleApp extends StatelessWidget {
  const PebbleApp({super.key, required this.store});
  final ExpenseStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pebble',
    debugShowCheckedModeBanner: false,
    theme: pebbleTheme(),
    home: PebbleHome(store: store),
  );
}

class PebbleHome extends StatefulWidget {
  const PebbleHome({super.key, required this.store});
  final ExpenseStore store;

  @override
  State<PebbleHome> createState() => _PebbleHomeState();
}

class _PebbleHomeState extends State<PebbleHome> {
  List<Expense> expenses = [];
  bool loading = true;
  String? error;
  int tab = 0;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final rows = await widget.store.all();
      if (mounted) setState(() { expenses = rows; loading = false; error = null; });
    } catch (e) {
      if (mounted) setState(() { error = 'Unable to load expenses: $e'; loading = false; });
    }
  }

  List<Expense> get visible => expenses.where((e) =>
      e.date.year == selectedMonth.year && e.date.month == selectedMonth.month).toList();

  Future<void> add({bool scan = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) =>
        ExpenseForm(store: widget.store, startWithCamera: scan)),
    );
    if (saved == true) await refresh();
  }

  void monthShift(int offset) {
    setState(() => selectedMonth =
      DateTime(selectedMonth.year, selectedMonth.month + offset));
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Pebble', 'Expenses', 'Scan receipt', 'Insights', 'Settings'];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PebbleColors.background,
        titleSpacing: 22,
        toolbarHeight: 76,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titles[tab], style: Theme.of(context).textTheme.headlineMedium),
          Text(tab == 0 ? 'Small records. Clear picture.'
              : tab == 1 ? 'Search and explore your spending'
              : tab == 3 ? 'Understand where your money goes'
              : tab == 4 ? 'Your data stays yours'
              : 'Capture a receipt to begin',
              style: const TextStyle(fontSize: 13, color: PebbleColors.muted)),
        ]),
        actions: [
          if (tab < 2) IconButton(
            tooltip: 'Add expense',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: add,
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: SafeArea(child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: refresh, child: const Text('Retry')),
              ]),
            ))
          : switch (tab) {
            0 => _dashboard(),
            1 => _expenses(),
            2 => _scanIntro(),
            3 => _insights(),
            _ => _settings(),
          }),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE2EEFF),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt_rounded), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.document_scanner_outlined), selectedIcon: Icon(Icons.document_scanner_rounded), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _scroll(List<Widget> children) => RefreshIndicator(
    onRefresh: refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: children,
    ),
  );

  Widget _dashboard() {
    final sum = visible.fold<int>(0, (total, item) => total + item.amountCents);
    const budget = 200000;
    final remaining = budget - sum;
    return _scroll([
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFDDF9EC), Color(0xFFF0FCF4)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('MMMM yyyy').format(selectedMonth).toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PebbleColors.green)),
          const SizedBox(height: 16),
          const Text('Spent this month', style: TextStyle(color: PebbleColors.muted)),
          const SizedBox(height: 3),
          Text(money(sum), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: PebbleColors.ink)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 11, value: (sum / budget).clamp(0.0, 1.0),
              color: PebbleColors.green, backgroundColor: const Color(0xFFBFECD7),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(sum * 100 / budget).round()}% of ${money(budget)} budget · ${money(remaining)} remaining',
            style: const TextStyle(fontSize: 12, color: PebbleColors.green, fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(height: 120, child: Row(children: [
        _summaryTile('Food', const Color(0xFFFFEEE9), PebbleColors.coral, Icons.restaurant, 'Food'),
        _summaryTile('Travel', const Color(0xFFEAF2FF), PebbleColors.blue, Icons.directions_car, 'Travel'),
        _summaryTile('Shopping', const Color(0xFFF1EBFF), PebbleColors.purple, Icons.shopping_bag, 'Shopping'),
        _summaryTile('Bills', const Color(0xFFFFF3D9), PebbleColors.orange, Icons.receipt_long, 'Bills'),
      ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _actionButton('Add expense', 'Quick entry', Icons.add_rounded,
          PebbleColors.blue, () => add())),
        const SizedBox(width: 12),
        Expanded(child: _actionButton('Scan receipt', 'Take a photo', Icons.document_scanner,
          PebbleColors.purple, () => add(scan: true))),
      ]),
      const SizedBox(height: 16),
      _section('Spending by category', _categoryBreakdown()),
      const SizedBox(height: 16),
      _section('Recent expenses', visible.isEmpty ? _empty()
        : Column(children: visible.take(4).map(_expenseRow).toList())),
    ]);
  }

  Widget _summaryTile(String label, Color background, Color foreground,
      IconData icon, String category) {
    final sum = visible.where((e) => e.category == category)
        .fold<int>(0, (total, item) => total + item.amountCents);
    return Expanded(child: Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 11, 4, 10),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(17)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: foreground, size: 21),
          const Spacer(),
          FittedBox(child: Text(money(sum), style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800))),
          const SizedBox(height: 4),
          FittedBox(child: Text(label, style: const TextStyle(color: PebbleColors.muted, fontSize: 12))),
        ]),
      ),
    ));
  }

  Widget _actionButton(String label, String subtitle, IconData icon, Color color,
      VoidCallback action) => Material(
    color: color, borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(child: Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
            Text(subtitle, style: const TextStyle(color: Color(0xFFDFE9FF), fontSize: 11)),
          ])),
        ]),
      ),
    ),
  );

  Widget _section(String title, Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      boxShadow: const [BoxShadow(color: Color(0x0A334A68), blurRadius: 15, offset: Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14), child,
    ]),
  );

  Widget _categoryBreakdown() {
    final totals = <String, int>{
      for (final category in categories)
        category: visible.where((e) => e.category == category)
            .fold<int>(0, (sum, e) => sum + e.amountCents),
    };
    final total = totals.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return _empty();
    final order = ['Food', 'Travel', 'Shopping', 'Bills', 'Groceries', 'Health', 'Other'];
    final active = order.where((c) => totals[c]! > 0).toList();

    return Row(children: [
      SizedBox(
        width: 134,
        height: 142,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: const Size.square(120),
            painter: SpendingDonut(
              fractions: active.map((c) => totals[c]! / total).toList(),
              colors: active.map(categoryColor).toList(),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(child: Text(money(total), style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 18))),
            const Text('Total', style: TextStyle(
              fontSize: 11, color: PebbleColors.muted)),
          ]),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(children: [
        for (final c in active)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              CircleAvatar(radius: 5, backgroundColor: categoryColor(c)),
              const SizedBox(width: 7),
              Expanded(child: Text(c, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12))),
              Text(money(totals[c]!), style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
      ])),
    ]);
  }

  Widget _empty() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 15),
    child: Center(child: Text('No expenses yet. Add your first one!',
      style: TextStyle(color: PebbleColors.muted))),
  );

  Widget _expenseRow(Expense item) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: categoryColor(item.category).withValues(alpha: 0.15),
      child: Icon(categoryIcons[categories.indexOf(item.category)], color: categoryColor(item.category)),
    ),
    title: Text(item.merchant.isNotEmpty ? item.merchant : item.description,
      maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text('${DateFormat('d MMM yyyy').format(item.date)} · ${item.category}',
      style: const TextStyle(color: PebbleColors.muted, fontSize: 12)),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('-${money(item.amountCents)}',
          style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(item.category, style: TextStyle(
          fontSize: 11, color: categoryColor(item.category),
          fontWeight: FontWeight.w700)),
      ],
    ),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.description, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(money(item.amountCents), style: const TextStyle(fontSize: 30,
            fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('${DateFormat.yMMMd().format(item.date)} · ${item.category}'),
          if (item.notes.isNotEmpty) Text(item.notes),
          if (item.receiptPath != null) TextButton.icon(
            icon: const Icon(Icons.image_outlined),
            label: const Text('View attached receipt'),
            onPressed: () {
              Navigator.pop(ctx);
              showDialog<void>(context: context, builder: (dialogContext) => Dialog(
                child: Image.file(File(item.receiptPath!), errorBuilder: (context, error, stackTrace) =>
                  const Padding(padding: EdgeInsets.all(32),
                    child: Text('Receipt image is unavailable.'))),
              ));
            },
          ),
          const SizedBox(height: 15),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete expense', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(ctx);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Delete this expense?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true && item.id != null) {
                try {
                  await widget.store.delete(item.id!);
                  await refresh();
                } catch (e) {
                  if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not delete expense: $e'))); }
                }
              }
            },
          ),
        ]),
      ),
    ),
  );

  Widget _expenses() => _scroll([
    TextField(
      decoration: const InputDecoration(
        hintText: 'Search expenses, shops...',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (_) => setState(() {}),
      controller: _searchController,
    ),
    const SizedBox(height: 15),
    _monthSelector(),
    const SizedBox(height: 14),
    SizedBox(height: 40, child: ListView(
      scrollDirection: Axis.horizontal,
      children: ['All', ...categories].map((c) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          label: Text(c),
          selected: _filter == c,
          onSelected: (_) => setState(() => _filter = c),
        ),
      )).toList(),
    )),
    const SizedBox(height: 12),
    ...visible.where((e) => (_filter == 'All' || e.category == _filter) &&
        ('${e.description} ${e.merchant} ${e.category}'.toLowerCase()
          .contains(_searchController.text.toLowerCase()))).map((e) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(
              color: Color(0x0A334A68), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: _expenseRow(e),
        ),
      )),
    if (visible.where((e) => (_filter == 'All' || e.category == _filter) &&
        ('${e.description} ${e.merchant} ${e.category}'.toLowerCase()
            .contains(_searchController.text.toLowerCase()))).isEmpty) _empty(),
  ]);

  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';

  Widget _monthSelector() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: const Color(0xFFE2F9ED), borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      const Icon(Icons.calendar_month_outlined),
      const SizedBox(width: 10),
      Expanded(child: Text(DateFormat('MMMM yyyy').format(selectedMonth),
        style: const TextStyle(fontWeight: FontWeight.w700))),
      IconButton(tooltip: 'Previous month', onPressed: () => monthShift(-1),
        icon: const Icon(Icons.chevron_left)),
      IconButton(tooltip: 'Next month', onPressed: () => monthShift(1),
        icon: const Icon(Icons.chevron_right)),
    ]),
  );

  Widget _scanIntro() => _scroll([
    _section('Scan your receipt', Column(children: [
      const Icon(Icons.document_scanner_outlined,
        color: PebbleColors.purple, size: 74),
      const SizedBox(height: 14),
      const Text('Capture a receipt and attach it to a new expense.'),
      const SizedBox(height: 10),
      const Text('Automatic OCR field extraction is planned for the next milestone. Enter the amount and description manually for now.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PebbleColors.muted)),
      const SizedBox(height: 25),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Take receipt photo'),
        onPressed: () => add(scan: true),
      )),
    ])),
  ]);

  Widget _insights() {
    final sum = visible.fold<int>(0, (s, e) => s + e.amountCents);
    final months = List.generate(6, (i) =>
      DateTime(selectedMonth.year, selectedMonth.month - 5 + i));
    final values = months.map((m) => expenses.where((e) =>
      e.date.month == m.month && e.date.year == m.year)
      .fold<int>(0, (s, e) => s + e.amountCents)).toList();
    final max = values.fold<int>(1, (a, b) => a > b ? a : b);
    return _scroll([
      _section('Monthly spending', SizedBox(
        height: 192,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < months.length; i++)
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(values[i] == 0 ? '' : money(values[i]),
                maxLines: 1, style: const TextStyle(fontSize: 9)),
              const SizedBox(height: 5),
              Container(height: 135 * (values[i] / max).clamp(0.02, 1.0),
                width: 29,
                decoration: BoxDecoration(
                  color: i == 5 ? PebbleColors.blue : const Color(0xFFC5DDFB),
                  borderRadius: BorderRadius.circular(7))),
              const SizedBox(height: 7),
              Text(DateFormat.MMM().format(months[i]),
                style: const TextStyle(fontSize: 11, color: PebbleColors.muted)),
            ])),
        ]),
      )),
      const SizedBox(height: 16),
      _section('By category', _categoryBreakdown()),
      const SizedBox(height: 16),
      _section('Budget insight', Text(
        '${money(200000 - sum)} remaining of a ${money(200000)} monthly reference budget.',
        style: const TextStyle(color: PebbleColors.green, fontWeight: FontWeight.w600))),
      const SizedBox(height: 16),
      _section('Storage & privacy', const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.storage),
            title: Text('Local SQLite'), subtitle: Text('Expenses stay on your phone')),
          ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.photo_library_outlined),
            title: Text('Receipt photos'), subtitle: Text('Stored in the app’s private folder')),
          ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.cloud_off_outlined),
            title: Text('No cloud account'), subtitle: Text('Backup and export are future features')),
        ],
      )),
    ]);
  }

  Widget _settings() => _scroll([
    _section('About Pebble', const Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pebble v0.1.0'),
        SizedBox(height: 10),
        Text('Currency: AUD · Language: English (Australia)'),
        SizedBox(height: 10),
        Text('Offline-first. Your expenses are saved locally to SQLite.'),
      ])),
  ]);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, required this.store, this.startWithCamera = false});
  final ExpenseStore store;
  final bool startWithCamera;

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController();
  final description = TextEditingController();
  final merchant = TextEditingController();
  final notes = TextEditingController();
  DateTime date = DateTime.now();
  String category = 'Groceries';
  String payment = 'Card';
  String? imagePath;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => capture(ImageSource.camera));
    }
  }

  Future<void> capture(ImageSource source) async {
    try {
      final selected = await ImagePicker().pickImage(
        source: source, imageQuality: 85, maxWidth: 1800);
      if (selected == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final receipts = Directory(p.join(directory.path, 'receipts'));
      await receipts.create(recursive: true);
      final target = p.join(receipts.path,
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(selected.path)}');
      await File(selected.path).copy(target);
      if (mounted) setState(() => imagePath = target);
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not attach receipt: $e'))); }
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || saving) return;
    final cents = amountToCents(amount.text);
    if (cents == null) return;
    setState(() => saving = true);
    try {
      await widget.store.add(Expense(
        date: date,
        amountCents: cents,
        description: description.text.trim(),
        category: category,
        merchant: merchant.text.trim(),
        paymentMethod: payment,
        notes: notes.text.trim(),
        receiptPath: imagePath,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save expense: $e'))); }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget fieldTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 14),
    child: Text(value.toUpperCase(), style: const TextStyle(
      fontWeight: FontWeight.w700, fontSize: 12, color: PebbleColors.muted)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Add expense'),
      centerTitle: true,
      backgroundColor: PebbleColors.background,
    ),
    body: SafeArea(child: Form(key: formKey, child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Manual'),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => capture(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Receipt'),
          )),
        ]),
        fieldTitle('Amount (AUD)'),
        TextFormField(
          controller: amount,
          autofocus: !widget.startWithCamera,
          decoration: const InputDecoration(prefixText: r'$ ', hintText: '0.00'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          validator: (v) => amountToCents(v ?? '') == null
            ? 'Enter an amount greater than zero (up to 2 decimals)' : null,
        ),
        fieldTitle('Date'),
        OutlinedButton.icon(
          onPressed: () async {
            final selected = await showDatePicker(context: context,
              initialDate: date, firstDate: DateTime(2000),
              lastDate: DateTime(2100));
            if (selected != null) setState(() => date = selected);
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(DateFormat('d MMMM yyyy').format(date)),
        ),
        fieldTitle('Description'),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(hintText: 'What did you spend on?'),
          validator: (v) => (v ?? '').trim().isEmpty
            ? 'Please enter a description' : null,
          maxLength: 160,
        ),
        fieldTitle('Category'),
        SizedBox(height: 77, child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < categories.length; i++)
              Padding(padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => category = categories[i]),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 91,
                    decoration: BoxDecoration(
                      color: category == categories[i]
                        ? categoryColors[i].withValues(alpha: 0.17) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: category == categories[i] ? categoryColors[i]
                          : const Color(0xFFE5EBF3),
                        width: category == categories[i] ? 2 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(categoryIcons[i], color: categoryColors[i]),
                      const SizedBox(height: 5),
                      Text(categories[i], style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                )),
          ],
        )),
        fieldTitle('Payment method'),
        DropdownButtonFormField<String>(
          initialValue: payment,
          items: ['Card', 'Cash', 'Bank transfer', 'Other'].map((v) =>
            DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => payment = v ?? payment),
        ),
        fieldTitle('Merchant (optional)'),
        TextFormField(controller: merchant,
          decoration: const InputDecoration(hintText: 'e.g. Woolworths')),
        fieldTitle('Notes (optional)'),
        TextFormField(controller: notes, maxLines: 2,
          decoration: const InputDecoration(hintText: 'Add a note...')),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => capture(ImageSource.gallery),
          icon: const Icon(Icons.attach_file_rounded),
          label: Text(imagePath == null ? 'Attach photo or receipt' : 'Replace attached receipt'),
        ),
        if (imagePath != null) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(children: [
            ClipRRect(borderRadius: BorderRadius.circular(13),
              child: Image.file(File(imagePath!), height: 155,
                fit: BoxFit.cover)),
            TextButton.icon(
              onPressed: () => setState(() => imagePath = null),
              icon: const Icon(Icons.close), label: const Text('Remove image')),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: saving ? null : save,
          style: FilledButton.styleFrom(
            backgroundColor: PebbleColors.blue,
            minimumSize: const Size(double.infinity, 52)),
          child: Text(saving ? 'Saving...' : 'Save expense'),
        ),
      ],
    ))),
  );

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    merchant.dispose();
    notes.dispose();
    super.dispose();
  }
}

class SpendingDonut extends CustomPainter {
  const SpendingDonut({required this.fractions, required this.colors});

  final List<double> fractions;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.39;
    final oval = Rect.fromCircle(center: centre, radius: radius);
    var angle = -math.pi / 2;
    for (var index = 0; index < fractions.length; index++) {
      final sweep = fractions[index] * 2 * math.pi;
      final paint = Paint()
        ..color = colors[index]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17;
      canvas.drawArc(oval, angle, sweep, false, paint);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant SpendingDonut oldDelegate) =>
      oldDelegate.fractions.toString() != fractions.toString() ||
      oldDelegate.colors.toString() != colors.toString();
}
