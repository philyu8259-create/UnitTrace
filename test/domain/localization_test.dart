import 'package:flutter_test/flutter_test.dart';
import 'package:unittrace/src/l10n/app_strings.dart';

void main() {
  test('uses Simplified Chinese strings for zh locales', () {
    final strings = AppStrings.forLanguageCode('zh_Hans');

    expect(strings.appTitle, '房况留证');
    expect(strings.createProperty, '创建房屋');
  });

  test('falls back to English for unsupported locales', () {
    final strings = AppStrings.forLanguageCode('fr');

    expect(strings.appTitle, 'UnitTrace');
    expect(strings.createProperty, 'Create property');
  });
}
