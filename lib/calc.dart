const _bd = '০১২৩৪৫৬৭৮৯';
String bn(String s) => s.replaceAllMapped(RegExp(r'\d'), (m) => _bd[int.parse(m[0]!)]);
String en(String s) { var r = s; for (var i = 0; i < 10; i++) { r = r.replaceAll(_bd[i], '$i'); } return r; }
String taka(int paisa) {
  final neg = paisa < 0; final v = paisa.abs(); var s = (v ~/ 100).toString(); final frac = v % 100;
  if (s.length > 3) {
    final last = s.substring(s.length - 3); var rest = s.substring(0, s.length - 3); final parts = <String>[];
    while (rest.length > 2) { parts.insert(0, rest.substring(rest.length - 2)); rest = rest.substring(0, rest.length - 2); }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last';
  }
  return bn('${neg ? '-' : ''}৳$s${frac > 0 ? '.${frac.toString().padLeft(2, '0')}' : ''}');
}
int toPaisa(String s) => (double.parse(en(s).replaceAll(',', '').trim()) * 100).round();
String plain(int p) => p % 100 == 0 ? '${p ~/ 100}' : (p / 100).toStringAsFixed(2);
String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String dmyA(String i) { final p = i.split('-'); return '${p[2]}-${p[1]}-${p[0]}'; }
String dmy(String i) => bn(dmyA(i));
String isoFromDmy(String s) { final p = s.split('-'); return '${p[2]}-${p[1]}-${p[0]}'; }
int netBalance(int opening, int income, int expense) => opening + income - expense;
int debtRemaining(int amount, int paid) => amount - paid;
String debtStatus(int amount, int paid) => paid <= 0 ? 'unpaid' : paid >= amount ? 'paid' : 'partial';
double budgetPct(int spent, int limit) => limit <= 0 ? 0 : spent * 100 / limit;
