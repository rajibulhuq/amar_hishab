import 'package:flutter_test/flutter_test.dart';
import 'package:amar_hishab/calc.dart';
void main() {
  test('balance', () => expect(netBalance(100000, 500000, 200000), 400000));
  test('debt', () { expect(debtRemaining(100000, 40000), 60000); expect(debtStatus(100000, 0), 'unpaid'); expect(debtStatus(100000, 40000), 'partial'); expect(debtStatus(100000, 100000), 'paid'); });
  test('budget', () { expect(budgetPct(800, 1000), 80); expect(budgetPct(5, 0), 0); });
  test('format', () { expect(taka(1250000), '৳১২,৫০০'); expect(taka(12345678900), '৳১২,৩৪,৫৬,৭৮৯'); expect(toPaisa('১২.৫'), 1250); expect(dmy('2025-03-09'), '০৯-০৩-২০২৫'); });
}
