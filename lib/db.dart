import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
typedef R = Map<String, Object?>;
const incomeCats = ['বেতন', 'ব্যবসার আয়', 'ফ্রিল্যান্সিং', 'অন্যান্য আয়'];
const expenseCats = ['বাসা ভাড়া', 'বাজার', 'খাবার', 'বিদ্যুৎ বিল', 'গ্যাস বিল', 'পানি বিল', 'ইন্টারনেট', 'মোবাইল রিচার্জ', 'যাতায়াত', 'চিকিৎসা', 'শিক্ষা', 'পরিবারের খরচ', 'ব্যক্তিগত খরচ', 'কেনাকাটা', 'অন্যান্য'];
const tableOrder = ['categories', 'transactions', 'budgets', 'debts', 'repayments', 'goals'];
class Db {
  static late Database d;
  static Future<void> init() async {
    d = await openDatabase(p.join(await getDatabasesPath(), 'amar_hishab.db'), version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, v) async {
        await db.execute('CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,type TEXT NOT NULL)');
        await db.execute('CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT,type TEXT NOT NULL,amount INTEGER NOT NULL,category_id INTEGER NOT NULL REFERENCES categories(id),date TEXT NOT NULL,method TEXT,note TEXT,created_at TEXT)');
        await db.execute('CREATE INDEX tx_date ON transactions(date)');
        await db.execute('CREATE TABLE budgets(category_id INTEGER PRIMARY KEY REFERENCES categories(id) ON DELETE CASCADE,limit_amt INTEGER NOT NULL)');
        await db.execute('CREATE TABLE debts(id INTEGER PRIMARY KEY AUTOINCREMENT,kind TEXT NOT NULL,person TEXT NOT NULL,amount INTEGER NOT NULL,date TEXT NOT NULL,note TEXT)');
        await db.execute('CREATE TABLE repayments(id INTEGER PRIMARY KEY AUTOINCREMENT,debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,amount INTEGER NOT NULL,date TEXT NOT NULL)');
        await db.execute('CREATE TABLE goals(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,target INTEGER NOT NULL,saved INTEGER NOT NULL DEFAULT 0)');
        for (final n in incomeCats) { await db.insert('categories', {'name': n, 'type': 'income'}); }
        for (final n in expenseCats) { await db.insert('categories', {'name': n, 'type': 'expense'}); }
      });
  }
  static Future<List<R>> cats(String type) => d.query('categories', where: 'type=?', whereArgs: [type], orderBy: 'id');
  static Future<void> addCat(String n, String t) => d.insert('categories', {'name': n, 'type': t});
  static Future<void> renameCat(int id, String n) => d.update('categories', {'name': n}, where: 'id=?', whereArgs: [id]);
  static Future<bool> delCat(int id) async {
    final c = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM transactions WHERE category_id=?', [id])) ?? 0;
    if (c > 0) return false;
    await d.delete('categories', where: 'id=?', whereArgs: [id]); return true;
  }
  static Future<void> saveTx(int? id, R v) => id == null ? d.insert('transactions', {...v, 'created_at': DateTime.now().toIso8601String()}) : d.update('transactions', v, where: 'id=?', whereArgs: [id]);
  static Future<void> delTx(int id) => d.delete('transactions', where: 'id=?', whereArgs: [id]);
  static Future<int> sum(String type, String f, String t, {int? cat}) async {
    final r = await d.rawQuery('SELECT COALESCE(SUM(amount),0) s FROM transactions WHERE type=? AND date BETWEEN ? AND ?${cat == null ? '' : ' AND category_id=$cat'}', [type, f, t]);
    return r.first['s'] as int;
  }
  static Future<int> sumAll(String type) => sum(type, '0000-00-00', '9999-99-99');
  static Future<List<R>> txs({String q = '', String? type, int? cat, String? f, String? t, int? limit}) {
    final w = <String>[]; final a = <Object>[];
    if (type != null) { w.add('t.type=?'); a.add(type); }
    if (cat != null) { w.add('t.category_id=?'); a.add(cat); }
    if (f != null) { w.add('t.date>=?'); a.add(f); }
    if (t != null) { w.add('t.date<=?'); a.add(t); }
    if (q.isNotEmpty) { w.add('(c.name LIKE ? OR t.note LIKE ?)'); a.addAll(['%$q%', '%$q%']); }
    return d.rawQuery('SELECT t.*,c.name cname FROM transactions t JOIN categories c ON c.id=t.category_id ${w.isEmpty ? '' : 'WHERE ${w.join(' AND ')}'} ORDER BY t.date DESC,t.id DESC${limit == null ? '' : ' LIMIT $limit'}', a);
  }
  static Future<List<R>> byCat(String f, String t) => d.rawQuery("SELECT c.id,c.name,SUM(t.amount) s FROM transactions t JOIN categories c ON c.id=t.category_id WHERE t.type='expense' AND t.date BETWEEN ? AND ? GROUP BY c.id ORDER BY s DESC", [f, t]);
  static Future<List<R>> daily(String f, String t) => d.rawQuery("SELECT date,SUM(amount) s FROM transactions WHERE type='expense' AND date BETWEEN ? AND ? GROUP BY date", [f, t]);
  static Future<Map<int, int>> budgets() async => {for (final r in await d.query('budgets')) r['category_id'] as int: r['limit_amt'] as int};
  static Future<void> setBudget(int cat, int? limit) => limit == null || limit <= 0 ? d.delete('budgets', where: 'category_id=?', whereArgs: [cat]) : d.insert('budgets', {'category_id': cat, 'limit_amt': limit}, conflictAlgorithm: ConflictAlgorithm.replace);
  static Future<List<R>> debts(String kind) => d.rawQuery('SELECT x.*,COALESCE((SELECT SUM(amount) FROM repayments r WHERE r.debt_id=x.id),0) paid FROM debts x WHERE kind=? ORDER BY date DESC,id DESC', [kind]);
  static Future<int> outstanding(String kind) async {
    final r = await d.rawQuery('SELECT COALESCE(SUM(amount),0)-COALESCE((SELECT SUM(r.amount) FROM repayments r JOIN debts y ON y.id=r.debt_id WHERE y.kind=?),0) s FROM debts WHERE kind=?', [kind, kind]);
    return r.first['s'] as int;
  }
  static Future<void> addDebt(R v) => d.insert('debts', v);
  static Future<void> delDebt(int id) => d.delete('debts', where: 'id=?', whereArgs: [id]);
  static Future<List<R>> repayments(int debt) => d.query('repayments', where: 'debt_id=?', whereArgs: [debt], orderBy: 'date DESC,id DESC');
  static Future<void> addRepay(int debt, int amt, String date) => d.insert('repayments', {'debt_id': debt, 'amount': amt, 'date': date});
  static Future<void> delRepay(int id) => d.delete('repayments', where: 'id=?', whereArgs: [id]);
  static Future<List<R>> goals() => d.query('goals', orderBy: 'id');
  static Future<void> addGoal(String n, int target, int saved) => d.insert('goals', {'name': n, 'target': target, 'saved': saved});
  static Future<void> setSaved(int id, int saved) => d.update('goals', {'saved': saved < 0 ? 0 : saved}, where: 'id=?', whereArgs: [id]);
  static Future<void> delGoal(int id) => d.delete('goals', where: 'id=?', whereArgs: [id]);
  static Future<int> totalSaved() async => (await d.rawQuery('SELECT COALESCE(SUM(saved),0) s FROM goals')).first['s'] as int;
  static Future<Map<String, Object?>> dump() async => {'app': 'amar_hishab', 'version': 1, 'tables': {for (final t in tableOrder) t: await d.query(t)}};
  static void validate(dynamic j) {
    if (j is! Map || j['app'] != 'amar_hishab' || j['tables'] is! Map) throw 'এটি আমার হিসাব ব্যাকআপ নয়';
    for (final t in tableOrder) { if (j['tables'][t] is! List) throw 'টেবিল পাওয়া যায়নি: $t'; }
  }
  static Future<void> restore(Map j) => d.transaction((tx) async {
    for (final t in tableOrder.reversed) { await tx.delete(t); }
    for (final t in tableOrder) { for (final r in j['tables'][t] as List) { await tx.insert(t, Map<String, Object?>.from(r as Map)); } }
  });
}
