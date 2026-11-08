import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calc.dart';
import 'db.dart';

late SharedPreferences prefs;
final tick = ValueNotifier<int>(0);
final dark = ValueNotifier<bool>(false);
void bump() => tick.value++;
const green = Color(0xFF16A34A), red = Color(0xFFDC2626), amber = Color(0xFFD97706);
const methods = ['নগদ', 'ব্যাংক', 'মোবাইল ব্যাংকিং', 'অন্যান্য'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Db.init();
  prefs = await SharedPreferences.getInstance();
  dark.value = prefs.getBool('dark') ?? false;
  runApp(const App());
}

class App extends StatefulWidget { const App({super.key}); @override State<App> createState() => _AppS(); }
class _AppS extends State<App> {
  bool ok = prefs.getString('pin') == null;
  @override Widget build(BuildContext c) => ValueListenableBuilder<bool>(valueListenable: dark, builder: (_, d, __) => MaterialApp(
    title: 'আমার হিসাব', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: d ? Brightness.dark : Brightness.light),
    home: ok ? const Shell() : Lock(onOk: () => setState(() => ok = true))));
}
String hashPin(String p) => sha256.convert(utf8.encode('amar$p')).toString();
class Lock extends StatefulWidget { final VoidCallback onOk; const Lock({super.key, required this.onOk}); @override State<Lock> createState() => _LockS(); }
class _LockS extends State<Lock> {
  final t = TextEditingController(); String err = '';
  @override Widget build(BuildContext c) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.lock, size: 56), const SizedBox(height: 12), const Text('পিন দিন', style: TextStyle(fontSize: 22)),
    TextField(controller: t, obscureText: true, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, letterSpacing: 12),
      onChanged: (v) { if (v.length == 4) { if (hashPin(en(v)) == prefs.getString('pin')) { widget.onOk(); } else { setState(() { err = 'ভুল পিন'; t.clear(); }); } } }),
    Text(err, style: const TextStyle(color: red))]))));
}

// ---------- helpers ----------
class Live<T> extends StatelessWidget {
  final Future<T> Function() load; final Widget Function(BuildContext, T) builder;
  const Live(this.load, this.builder, {super.key});
  @override Widget build(BuildContext c) => ValueListenableBuilder<int>(valueListenable: tick, builder: (_, __, ___) => FutureBuilder<T>(future: load(),
    builder: (c, s) => s.hasData ? builder(c, s.data as T) : s.hasError ? Center(child: Text('ত্রুটি: ${s.error}')) : const Center(child: CircularProgressIndicator())));
}
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
Future<bool> sure(BuildContext c, String m) async => await showDialog<bool>(context: c, builder: (_) => AlertDialog(content: Text(m), actions: [
  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('হ্যাঁ'))])) ?? false;
class F { final String label, kind, init; final List<String> opts; const F(this.label, this.kind, [this.init = '', this.opts = const []]); }
Future<List<String>?> ask(BuildContext c, String title, List<F> fs) => showDialog<List<String>>(context: c, builder: (_) => _Ask(title, fs));
class _Ask extends StatefulWidget { final String title; final List<F> fs; const _Ask(this.title, this.fs); @override State<_Ask> createState() => _AskS(); }
class _AskS extends State<_Ask> {
  late final cs = widget.fs.map((f) => TextEditingController(text: f.kind == 'date' ? dmyA(f.init) : f.kind == 'drop' && f.init.isEmpty ? f.opts.first : f.init)).toList();
  String err = '';
  void submit() {
    final out = <String>[];
    for (var i = 0; i < cs.length; i++) {
      final f = widget.fs[i]; final v = cs[i].text.trim();
      if (f.kind == 'num') { try { if (toPaisa(v) <= 0) throw 0; } catch (_) { setState(() => err = '${f.label}: সঠিক সংখ্যা দিন'); return; } out.add(toPaisa(v).toString()); }
      else if (f.kind == 'num0') { try { toPaisa(v); } catch (_) { setState(() => err = '${f.label}: সঠিক সংখ্যা দিন'); return; } out.add(toPaisa(v).toString()); }
      else if (f.kind == 'text' && v.isEmpty) { setState(() => err = '${f.label} লিখুন'); return; }
      else if (f.kind == 'date') { out.add(isoFromDmy(v)); }
      else { out.add(v); }
    }
    Navigator.pop(context, out);
  }
  @override Widget build(BuildContext c) => AlertDialog(title: Text(widget.title), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    for (var i = 0; i < cs.length; i++) Padding(padding: const EdgeInsets.only(top: 8), child: _field(i)),
    if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(color: red)))])),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('বাতিল')), FilledButton(onPressed: submit, child: const Text('সংরক্ষণ'))]);
  Widget _field(int i) { final f = widget.fs[i];
    if (f.kind == 'drop') return DropdownButtonFormField<String>(value: f.opts.contains(cs[i].text) ? cs[i].text : f.opts.first, isExpanded: true, decoration: InputDecoration(labelText: f.label), items: [for (final o in f.opts) DropdownMenuItem(value: o, child: Text(o))], onChanged: (v) => cs[i].text = v ?? '');
    if (f.kind == 'date') return TextField(controller: cs[i], readOnly: true, decoration: InputDecoration(labelText: f.label, suffixIcon: const Icon(Icons.calendar_today)), onTap: () async {
      final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(isoFromDmy(cs[i].text)) ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) cs[i].text = dmyA(iso(d)); });
    final num = f.kind.startsWith('num');
    return TextField(controller: cs[i], keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: f.label, prefixText: num ? '৳ ' : null), maxLines: f.kind == 'note' ? 2 : 1);
  }
}
Future<void> saveBytes(BuildContext c, String name, List<int> bytes) async {
  try { final p = await FilePicker.platform.saveFile(fileName: name, bytes: Uint8List.fromList(bytes)); if (c.mounted) toast(c, p == null ? 'বাতিল করা হয়েছে' : '✓ সফলভাবে সংরক্ষিত হয়েছে'); }
  catch (e) { if (c.mounted) toast(c, 'ত্রুটি: $e'); }
}
String csvOf(List<R> rows) { String q(Object? x) => '"${'${x ?? ''}'.replaceAll('"', '""')}"';
  return ['তারিখ,ধরন,ক্যাটাগরি,টাকা,মাধ্যম,বিবরণ', for (final r in rows) [dmyA(r['date'] as String), r['type'] == 'income' ? 'আয়' : 'খরচ', r['cname'], plain(r['amount'] as int), r['method'], r['note']].map(q).join(',')].join('\n'); }
List<int> withBom(String s) => [0xEF, 0xBB, 0xBF, ...utf8.encode(s)];
Widget bars(List<BarChartGroupData> g, String Function(int) lab) => SizedBox(height: 190, child: BarChart(BarChartData(barGroups: g, gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
  titlesData: FlTitlesData(leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(lab(v.toInt()), style: const TextStyle(fontSize: 10)))))))));
BarChartGroupData grp(int x, List<(double, Color)> rods) => BarChartGroupData(x: x, barRods: [for (final r in rods) BarChartRodData(toY: r.$1, color: r.$2, width: rods.length > 1 ? 8 : 6)]);
class Sum extends StatelessWidget { final String l; final int v; final Color? col; const Sum(this.l, this.v, {super.key, this.col});
  @override Widget build(BuildContext c) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 12)), const SizedBox(height: 4), FittedBox(child: Text(taka(v), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: col)))]))); }

// ---------- forms ----------
Future<void> txForm(BuildContext c, String type, {R? tx}) async {
  final cats = await Db.cats(type); final names = [for (final x in cats) x['name'] as String];
  final cur = tx == null ? names.first : '${tx['cname']}';
  final isExp = type == 'expense';
  if (!c.mounted) return;
  final r = await ask(c, tx != null ? 'সম্পাদনা' : isExp ? 'খরচ যোগ করুন' : 'আয় যোগ করুন', [
    F('টাকার পরিমাণ', 'num', tx == null ? '' : plain(tx['amount'] as int)), F('ক্যাটাগরি', 'drop', cur, names), F('তারিখ', 'date', tx == null ? iso(DateTime.now()) : '${tx['date']}'),
    if (isExp) F('পেমেন্ট মাধ্যম', 'drop', tx == null ? 'নগদ' : '${tx['method'] ?? 'নগদ'}', methods), F('বিবরণ (ঐচ্ছিক)', 'note', tx == null ? '' : '${tx['note'] ?? ''}')]);
  if (r == null) return;
  final cid = cats.firstWhere((x) => x['name'] == r[1])['id'] as int;
  await Db.saveTx(tx == null ? null : tx['id'] as int, {'type': type, 'amount': int.parse(r[0]), 'category_id': cid, 'date': r[2], 'method': isExp ? r[3] : null, 'note': r.last});
  bump();
}
Future<void> debtForm(BuildContext c, String kind) async {
  final r = await ask(c, kind == 'lent' ? 'টাকা ধার দিয়েছি' : 'টাকা ধার নিয়েছি', [const F('ব্যক্তির নাম', 'text'), const F('টাকার পরিমাণ', 'num'), F('তারিখ', 'date', iso(DateTime.now())), const F('বিবরণ (ঐচ্ছিক)', 'note')]);
  if (r == null) return; await Db.addDebt({'kind': kind, 'person': r[0], 'amount': int.parse(r[1]), 'date': r[2], 'note': r[3]}); bump();
}

// ---------- shell ----------
class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellS(); }
class _ShellS extends State<Shell> {
  int i = 0;
  @override Widget build(BuildContext c) {
    const pages = [HomePage(), TxPage(), BudgetPage(), ReportPage(), SettingsPage()];
    return Scaffold(body: SafeArea(child: pages[i]), bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.home), label: 'হোম'), NavigationDestination(icon: Icon(Icons.list_alt), label: 'লেনদেন'),
      NavigationDestination(icon: Icon(Icons.pie_chart), label: 'বাজেট'), NavigationDestination(icon: Icon(Icons.bar_chart), label: 'রিপোর্ট'), NavigationDestination(icon: Icon(Icons.settings), label: 'সেটিংস')]));
  }
}
Widget txTile(BuildContext c, R t) { final inc = t['type'] == 'income'; return ListTile(
  leading: CircleAvatar(backgroundColor: (inc ? green : red).withOpacity(.15), child: Icon(inc ? Icons.arrow_downward : Icons.arrow_upward, color: inc ? green : red)),
  title: Text('${t['cname']}'), subtitle: Text('${dmy(t['date'] as String)}${t['note'] != null && '${t['note']}'.isNotEmpty ? ' • ${t['note']}' : ''}'),
  trailing: Text('${inc ? '+' : '-'}${taka(t['amount'] as int)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: inc ? green : red)), onTap: () => txDetail(c, t)); }
void txDetail(BuildContext c, R t) => showDialog(context: c, builder: (d) => AlertDialog(title: Text('${t['cname']} • ${taka(t['amount'] as int)}'),
  content: Text('ধরন: ${t['type'] == 'income' ? 'আয়' : 'খরচ'}\nতারিখ: ${dmy(t['date'] as String)}${t['method'] != null ? '\nমাধ্যম: ${t['method']}' : ''}\nবিবরণ: ${t['note'] ?? ''}'),
  actions: [TextButton(onPressed: () async { Navigator.pop(d); if (await sure(c, 'এই লেনদেন মুছে ফেলবেন?')) { await Db.delTx(t['id'] as int); bump(); } }, child: const Text('মুছুন', style: TextStyle(color: red))),
    TextButton(onPressed: () { Navigator.pop(d); txForm(c, '${t['type']}', tx: t); }, child: const Text('সম্পাদনা')), TextButton(onPressed: () => Navigator.pop(d), child: const Text('বন্ধ'))]));

// ---------- home ----------
class HomePage extends StatelessWidget { const HomePage({super.key});
  @override Widget build(BuildContext c) => Live<Map<String, dynamic>>(() async {
    final n = DateTime.now(); String ym(DateTime x) => iso(DateTime(x.year, x.month)).substring(0, 7);
    final months = [for (var k = 5; k >= 0; k--) DateTime(n.year, n.month - k)];
    return {'inc': await Db.sum('income', '${ym(n)}-01', '${ym(n)}-31'), 'exp': await Db.sum('expense', '${ym(n)}-01', '${ym(n)}-31'),
      'allInc': await Db.sumAll('income'), 'allExp': await Db.sumAll('expense'), 'sav': await Db.totalSaved(), 'recv': await Db.outstanding('lent'), 'pay': await Db.outstanding('borrowed'),
      'chart': [for (final m in months) [m.month, await Db.sum('income', '${ym(m)}-01', '${ym(m)}-31'), await Db.sum('expense', '${ym(m)}-01', '${ym(m)}-31')]], 'recent': await Db.txs(limit: 5)};
  }, (c, d) { final bal = netBalance(prefs.getInt('opening') ?? 0, d['allInc'], d['allExp']); final ch = d['chart'] as List;
    return ListView(padding: const EdgeInsets.all(12), children: [
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 2.2, children: [
        Sum('এই মাসের আয়', d['inc'], col: green), Sum('এই মাসের খরচ', d['exp'], col: red), Sum('বর্তমান ব্যালেন্স', bal, col: bal < 0 ? red : null), Sum('মোট সঞ্চয়', d['sav'])]),
      Row(children: [Expanded(child: InkWell(onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const DebtPage())), child: SizedBox(height: 70, child: Sum('মোট পাওনা', d['recv'], col: green)))),
        Expanded(child: InkWell(onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const DebtPage())), child: SizedBox(height: 70, child: Sum('মোট দেনা', d['pay'], col: red))))]),
      Wrap(spacing: 8, children: [FilledButton.icon(onPressed: () => txForm(c, 'income'), icon: const Icon(Icons.add), label: const Text('আয় যোগ করুন')), FilledButton.tonalIcon(onPressed: () => txForm(c, 'expense'), icon: const Icon(Icons.remove), label: const Text('খরচ যোগ করুন')),
        OutlinedButton(onPressed: () => debtForm(c, 'lent'), child: const Text('টাকা ধার দিয়েছি')), OutlinedButton(onPressed: () => debtForm(c, 'borrowed'), child: const Text('টাকা ধার নিয়েছি'))]),
      const Padding(padding: EdgeInsets.only(top: 16, bottom: 8), child: Text('মাসিক ওভারভিউ (সবুজ আয়, লাল খরচ)', style: TextStyle(fontWeight: FontWeight.bold))),
      bars([for (var k = 0; k < ch.length; k++) grp(k, [((ch[k][1] as int) / 100, green), ((ch[k][2] as int) / 100, red)])], (k) => bn('${ch[k][0]}')),
      const Padding(padding: EdgeInsets.only(top: 16), child: Text('সাম্প্রতিক ৫টি লেনদেন', style: TextStyle(fontWeight: FontWeight.bold))),
      if ((d['recent'] as List).isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('এখনো কোনো লেনদেন নেই')),
      for (final t in d['recent'] as List<R>) txTile(c, t)]); });
}

// ---------- transactions ----------
class TxPage extends StatefulWidget { const TxPage({super.key}); @override State<TxPage> createState() => _TxS(); }
class _TxS extends State<TxPage> {
  String q = '', type = ''; int? cat; DateTimeRange? range; List<R> allCats = [];
  @override void initState() { super.initState(); Future.wait([Db.cats('income'), Db.cats('expense')]).then((v) => setState(() => allCats = [...v[0], ...v[1]])); }
  @override Widget build(BuildContext c) => Scaffold(floatingActionButton: FloatingActionButton(onPressed: () => txForm(c, 'expense'), child: const Icon(Icons.add)), body: Column(children: [
    Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'খুঁজুন…', border: OutlineInputBorder()), onChanged: (v) => setState(() => q = v))),
    SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
      for (final e in [['', 'সব'], ['income', 'আয়'], ['expense', 'খরচ']]) Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(e[1]), selected: type == e[0], onSelected: (_) => setState(() => type = e[0]))),
      DropdownButton<int?>(value: cat, hint: const Text('ক্যাটাগরি'), items: [const DropdownMenuItem(value: null, child: Text('সব ক্যাটাগরি')), for (final x in allCats) DropdownMenuItem(value: x['id'] as int, child: Text('${x['name']}'))], onChanged: (v) => setState(() => cat = v)),
      TextButton.icon(icon: const Icon(Icons.date_range), label: Text(range == null ? 'তারিখ' : '${dmy(iso(range!.start))} - ${dmy(iso(range!.end))}'), onPressed: () async { final r = await showDateRangePicker(context: c, firstDate: DateTime(2000), lastDate: DateTime(2100)); setState(() => range = r); }),
      if (range != null) IconButton(onPressed: () => setState(() => range = null), icon: const Icon(Icons.close))])),
    Expanded(child: Live<List<R>>(() => Db.txs(q: q, type: type.isEmpty ? null : type, cat: cat, f: range == null ? null : iso(range!.start), t: range == null ? null : iso(range!.end)), (c, l) => l.isEmpty ? const Center(child: Text('কোনো লেনদেন পাওয়া যায়নি')) : ListView(children: [
      for (var i = 0; i < l.length; i++) ...[if (i == 0 || l[i]['date'] != l[i - 1]['date']) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(dmy('${l[i]['date']}'), style: const TextStyle(fontWeight: FontWeight.bold))), txTile(c, l[i])]])))]));
}

// ---------- budget ----------
class BudgetPage extends StatelessWidget { const BudgetPage({super.key});
  @override Widget build(BuildContext c) => Live<List>(() async { final n = DateTime.now(); final m = iso(DateTime(n.year, n.month)).substring(0, 7); final b = await Db.budgets();
    return [await Db.cats('expense'), b, {for (final r in await Db.byCat('$m-01', '$m-31')) r['id'] as int: r['s'] as int}]; }, (c, d) { final cats = d[0] as List<R>; final b = d[1] as Map<int, int>; final sp = d[2] as Map<int, int>;
    return ListView(padding: const EdgeInsets.all(12), children: [const Text('এই মাসের বাজেট (সীমা বদলাতে ট্যাপ করুন)', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      for (final x in cats) Builder(builder: (_) { final id = x['id'] as int; final lim = b[id] ?? 0; final s = sp[id] ?? 0; final p = budgetPct(s, lim); final col = p > 100 ? red : p >= 80 ? amber : green;
        return Card(child: ListTile(onTap: () async { final r = await ask(c, '${x['name']} - মাসিক সীমা', [F('সীমা (০ দিলে মুছে যাবে)', 'num0', lim == 0 ? '' : plain(lim))]); if (r != null) { await Db.setBudget(id, int.parse(r[0])); bump(); } },
          title: Text('${x['name']}'), subtitle: lim == 0 ? Text('খরচ ${taka(s)} • সীমা নেই') : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 4), LinearProgressIndicator(value: (p / 100).clamp(0, 1), color: col, minHeight: 8),
            Text('বাজেট ${taka(lim)} • খরচ ${taka(s)} • বাকি ${taka(lim - s)} • ${bn(p.toStringAsFixed(0))}%'), if (p > 100) Text('⚠ বাজেট ছাড়িয়ে গেছে!', style: TextStyle(color: col, fontWeight: FontWeight.bold)) else if (p >= 80) Text('⚠ বাজেটের ৮০% ছুঁয়েছে', style: TextStyle(color: col, fontWeight: FontWeight.bold))]))); })]); });
}

// ---------- reports ----------
class ReportPage extends StatefulWidget { const ReportPage({super.key}); @override State<ReportPage> createState() => _RepS(); }
class _RepS extends State<ReportPage> {
  DateTime m = DateTime(DateTime.now().year, DateTime.now().month); final key = GlobalKey();
  String get ym => iso(m).substring(0, 7);
  Future<void> pdf() async { final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary; final im = await b.toImage(pixelRatio: 2); final bd = await im.toByteData(format: ui.ImageByteFormat.png);
    final img = pw.MemoryImage(bd!.buffer.asUint8List()); final doc = pw.Document(); doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)))); await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'report_$ym.pdf'); }
  @override Widget build(BuildContext c) => Live<Map<String, dynamic>>(() async => {'inc': await Db.sum('income', '$ym-01', '$ym-31'), 'exp': await Db.sum('expense', '$ym-01', '$ym-31'), 'cats': await Db.byCat('$ym-01', '$ym-31'), 'daily': await Db.daily('$ym-01', '$ym-31')}, (c, d) {
    final days = DateTime(m.year, m.month + 1, 0).day; final dm = {for (final r in d['daily'] as List<R>) int.parse((r['date'] as String).substring(8)): (r['s'] as int) / 100}; final cats = d['cats'] as List<R>;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: () => setState(() => m = DateTime(m.year, m.month - 1)), icon: const Icon(Icons.chevron_left)), Text(bn('${m.month}/${m.year}'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(onPressed: () => setState(() => m = DateTime(m.year, m.month + 1)), icon: const Icon(Icons.chevron_right))]),
      Row(children: [Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.table_chart), label: const Text('CSV'), onPressed: () async => saveBytes(c, 'amar_hishab_$ym.csv', withBom(csvOf(await Db.txs(f: '$ym-01', t: '$ym-31')))))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF'), onPressed: pdf))]),
      RepaintBoundary(key: key, child: Container(color: Theme.of(c).scaffoldBackgroundColor, padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('আমার হিসাব - মাসিক রিপোর্ট ${bn('${m.month}/${m.year}')}', style: const TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 70, child: Row(children: [Expanded(child: Sum('মোট আয়', d['inc'], col: green)), Expanded(child: Sum('মোট খরচ', d['exp'], col: red)), Expanded(child: Sum('নেট', d['inc'] - d['exp'] as int))])),
        if (cats.isNotEmpty) Text('সবচেয়ে বেশি খরচ: ${cats.first['name']} (${taka(cats.first['s'] as int)})', style: const TextStyle(fontWeight: FontWeight.bold)),
        for (final r in cats) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${r['name']}'), Text(taka(r['s'] as int))])),
        const SizedBox(height: 12), const Text('দৈনিক খরচ'), bars([for (var k = 1; k <= days; k++) grp(k, [(dm[k] ?? 0, red)])], (k) => k % 5 == 0 ? bn('$k') : ''),
        const SizedBox(height: 12), const Text('আয় বনাম খরচ'), bars([grp(0, [((d['inc'] as int) / 100, green)]), grp(1, [((d['exp'] as int) / 100, red)])], (k) => k == 0 ? 'আয়' : 'খরচ')])))]); });
}

// ---------- debts ----------
class DebtPage extends StatelessWidget { const DebtPage({super.key});
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('ধার ও দেনা')), body: Live<List<List<R>>>(() async => [await Db.debts('lent'), await Db.debts('borrowed')], (c, d) => ListView(children: [
    for (final k in [0, 1]) ...[Padding(padding: const EdgeInsets.all(12), child: Text(k == 0 ? 'আমি ধার দিয়েছি (পাওনা)' : 'আমি ধার নিয়েছি (দেনা)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      if (d[k].isEmpty) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('কিছু নেই')),
      for (final x in d[k]) ListTile(title: Text('${x['person']}'), subtitle: Text('${dmy('${x['date']}')} • মোট ${taka(x['amount'] as int)} • ${{'unpaid': 'অপরিশোধিত', 'partial': 'আংশিক পরিশোধ', 'paid': 'পরিশোধিত'}[debtStatus(x['amount'] as int, x['paid'] as int)]}'),
        trailing: Text(taka(debtRemaining(x['amount'] as int, x['paid'] as int)), style: TextStyle(fontWeight: FontWeight.bold, color: k == 0 ? green : red)), onTap: () => debtDetail(c, x))]])));
}
void debtDetail(BuildContext c, R x) async { final reps = await Db.repayments(x['id'] as int); if (!c.mounted) return; final rem = debtRemaining(x['amount'] as int, x['paid'] as int);
  showDialog(context: c, builder: (d) => AlertDialog(title: Text('${x['person']}'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('মোট: ${taka(x['amount'] as int)}\nপরিশোধ: ${taka(x['paid'] as int)}\nবাকি: ${taka(rem)}\n${x['note'] ?? ''}'), const Divider(), const Text('পরিশোধের ইতিহাস'), if (reps.isEmpty) const Text('নেই'),
    for (final r in reps) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${dmy('${r['date']}')} - ${taka(r['amount'] as int)}'), IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () async { Navigator.pop(d); await Db.delRepay(r['id'] as int); bump(); })])])),
    actions: [TextButton(onPressed: () async { Navigator.pop(d); if (await sure(c, 'এই রেকর্ড ও তার সব পরিশোধ মুছে ফেলবেন?')) { await Db.delDebt(x['id'] as int); bump(); } }, child: const Text('মুছুন', style: TextStyle(color: red))),
      if (rem > 0) TextButton(onPressed: () async { Navigator.pop(d); final r = await ask(c, 'পরিশোধ যোগ করুন', [F('টাকা (বাকি ${taka(rem)})', 'num'), F('তারিখ', 'date', iso(DateTime.now()))]); if (r == null) return;
        if (int.parse(r[0]) > rem) { if (c.mounted) toast(c, 'বাকি টাকার চেয়ে বেশি দেওয়া যাবে না'); return; } await Db.addRepay(x['id'] as int, int.parse(r[0]), r[1]); bump(); }, child: const Text('পরিশোধ যোগ')), TextButton(onPressed: () => Navigator.pop(d), child: const Text('বন্ধ'))])); }

// ---------- savings ----------
class SavingsPage extends StatelessWidget { const SavingsPage({super.key});
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('সঞ্চয়')), floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () async {
    final r = await ask(c, 'নতুন লক্ষ্য', [const F('লক্ষ্যের নাম', 'text'), const F('লক্ষ্য (৳)', 'num'), const F('এখন পর্যন্ত জমা', 'num0', '0')]); if (r != null) { await Db.addGoal(r[0], int.parse(r[1]), int.parse(r[2])); bump(); } }),
    body: Live<List<R>>(Db.goals, (c, l) => l.isEmpty ? const Center(child: Text('কোনো সঞ্চয় লক্ষ্য নেই। + চাপুন')) : ListView(children: [for (final g in l) Card(child: ListTile(title: Text('${g['name']}'), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LinearProgressIndicator(value: ((g['saved'] as int) / (g['target'] as int)).clamp(0, 1).toDouble(), minHeight: 8), Text('জমা ${taka(g['saved'] as int)} / ${taka(g['target'] as int)} • ${bn(((g['saved'] as int) * 100 / (g['target'] as int)).toStringAsFixed(0))}% • বাকি ${taka((g['target'] as int) - (g['saved'] as int))}')]),
      trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () async { if (await sure(c, 'লক্ষ্য মুছবেন?')) { await Db.delGoal(g['id'] as int); bump(); } }),
      onTap: () async { final r = await ask(c, 'জমা (ঋণাত্মক দিলে তোলা)', [const F('টাকা', 'num0')]); if (r != null) { await Db.setSaved(g['id'] as int, (g['saved'] as int) + int.parse(r[0])); bump(); } }))])));
}

// ---------- settings ----------
class SettingsPage extends StatelessWidget { const SettingsPage({super.key});
  @override Widget build(BuildContext c) { return ListView(children: [
    ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('প্রারম্ভিক ব্যালেন্স'), subtitle: Text(taka(prefs.getInt('opening') ?? 0)), onTap: () async { final r = await ask(c, 'প্রারম্ভিক ব্যালেন্স', [F('টাকা', 'num0', plain(prefs.getInt('opening') ?? 0))]); if (r != null) { await prefs.setInt('opening', int.parse(r[0])); bump(); } }),
    ValueListenableBuilder<bool>(valueListenable: dark, builder: (_, d, __) => SwitchListTile(secondary: const Icon(Icons.dark_mode), title: const Text('ডার্ক থিম'), value: d, onChanged: (v) { dark.value = v; prefs.setBool('dark', v); })),
    ListTile(leading: const Icon(Icons.category), title: const Text('ক্যাটাগরি ব্যবস্থাপনা'), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const CatPage()))),
    ListTile(leading: const Icon(Icons.handshake), title: const Text('ধার ও দেনা'), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const DebtPage()))),
    ListTile(leading: const Icon(Icons.savings), title: const Text('সঞ্চয় লক্ষ্য'), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SavingsPage()))),
    const Divider(),
    ListTile(leading: const Icon(Icons.backup), title: const Text('ব্যাকআপ (JSON) সংরক্ষণ'), onTap: () async { final j = await Db.dump(); j['opening'] = prefs.getInt('opening') ?? 0; if (c.mounted) saveBytes(c, 'amar_hishab_backup_${iso(DateTime.now())}.json', utf8.encode(jsonEncode(j))); }),
    ListTile(leading: const Icon(Icons.restore), title: const Text('ব্যাকআপ থেকে পুনরুদ্ধার'), onTap: () async { final r = await FilePicker.platform.pickFiles(withData: true); if (r == null || r.files.single.bytes == null) return;
      try { final j = jsonDecode(utf8.decode(r.files.single.bytes!)); Db.validate(j); if (!c.mounted || !await sure(c, 'বর্তমান সব তথ্য এই ব্যাকআপ দিয়ে প্রতিস্থাপিত হবে। চালিয়ে যাবেন?')) return; await Db.restore(j); await prefs.setInt('opening', (j['opening'] as int?) ?? 0); bump(); if (c.mounted) toast(c, '✓ পুনরুদ্ধার সফল'); } catch (e) { if (c.mounted) toast(c, 'ব্যাকআপ ফাইল সঠিক নয়: $e'); } }),
    ListTile(leading: const Icon(Icons.table_chart), title: const Text('সব লেনদেন CSV'), onTap: () async => saveBytes(c, 'amar_hishab_all.csv', withBom(csvOf(await Db.txs())))),
    const Divider(),
    ListTile(leading: const Icon(Icons.lock), title: Text(prefs.getString('pin') == null ? '৪ সংখ্যার পিন চালু করুন' : 'পিন বন্ধ করুন'), onTap: () async {
      if (prefs.getString('pin') != null) { if (await sure(c, 'পিন বন্ধ করবেন?')) { await prefs.remove('pin'); bump(); } return; }
      final r = await ask(c, 'নতুন পিন', [const F('৪ সংখ্যা', 'text')]); if (r == null) return; final p = en(r[0]); if (!RegExp(r'^\d{4}$').hasMatch(p)) { if (c.mounted) toast(c, 'ঠিক ৪টি সংখ্যা দিন'); return; } await prefs.setString('pin', hashPin(p)); bump(); if (c.mounted) toast(c, 'পিন চালু হয়েছে'); }),
    const ListTile(leading: Icon(Icons.info), title: Text('আমার হিসাব v1.0.0'), subtitle: Text('সম্পূর্ণ অফলাইন • কোনো ডেটা বাইরে যায় না'))]); }
}
class CatPage extends StatelessWidget { const CatPage({super.key});
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('ক্যাটাগরি')), body: Live<List<List<R>>>(() async => [await Db.cats('income'), await Db.cats('expense')], (c, d) => ListView(children: [
    for (final k in [0, 1]) ...[ListTile(title: Text(k == 0 ? 'আয়ের ক্যাটাগরি' : 'খরচের ক্যাটাগরি', style: const TextStyle(fontWeight: FontWeight.bold)), trailing: IconButton(icon: const Icon(Icons.add), onPressed: () async { final r = await ask(c, 'নতুন ক্যাটাগরি', [const F('নাম', 'text')]); if (r != null) { await Db.addCat(r[0], k == 0 ? 'income' : 'expense'); bump(); } })),
      for (final x in d[k]) ListTile(title: Text('${x['name']}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () async { final r = await ask(c, 'নাম বদলান', [F('নাম', 'text', '${x['name']}')]); if (r != null) { await Db.renameCat(x['id'] as int, r[0]); bump(); } }),
        IconButton(icon: const Icon(Icons.delete), onPressed: () async { if (!await sure(c, 'ক্যাটাগরি মুছবেন?')) return; final ok = await Db.delCat(x['id'] as int); if (!ok && c.mounted) toast(c, 'এই ক্যাটাগরিতে লেনদেন আছে, মোছা যাবে না'); bump(); })]))]])));
}
