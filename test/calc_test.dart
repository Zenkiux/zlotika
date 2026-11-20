import 'package:flutter_test/flutter_test.dart';
import 'package:zlotika/core/app_state.dart';

void main() {
  test('shelf discount without a printed price', () {
    expect(AppState.calcLine((price: 3.59, qty: 1, pct: 20)), 2.87);
    expect(AppState.calcLine((price: 2.42, qty: 2, pct: 0)), 4.84);
    expect(AppState.calcLine((price: 9.99, qty: 3, pct: 50)), closeTo(15.0, 1e-9));
  });
}
