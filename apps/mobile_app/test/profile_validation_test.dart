import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/config/profile_validation.dart';

void main() {
  for (final value in [
    '',
    'abc',
    '-1',
    '0',
    'NaN',
    'Infinity',
    '-Infinity',
    '1e999',
  ]) {
    test('invalid body metric "$value" is rejected', () {
      expect(isValidBodyMetric(value), isFalse);
    });
  }
  for (final value in ['170', '65.5', ' 165.5 ']) {
    test('valid body metric "$value" is accepted', () {
      expect(isValidBodyMetric(value), isTrue);
    });
  }
}
