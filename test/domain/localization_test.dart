import 'package:flutter_test/flutter_test.dart';
import 'package:unittrace/src/domain/room_templates.dart';
import 'package:unittrace/src/l10n/app_strings.dart';

void main() {
  test('uses Simplified Chinese strings for zh locales', () {
    final strings = AppStrings.forLanguageCode('zh_Hans');

    expect(strings.appTitle, '房况留证');
    expect(strings.createProperty, '创建房屋');
    expect(strings.brandKicker, '房况留证');
    expect(strings.localEvidenceVault, '本地证据保险箱');
    expect(strings.evidenceDeskTagline, '时间戳 · 哈希 · 签名');
    expect(strings.reportArchiveBadge, 'PDF 报告 · 证据清单');
  });

  test('falls back to English for unsupported locales', () {
    final strings = AppStrings.forLanguageCode('fr');

    expect(strings.appTitle, 'UnitTrace');
    expect(strings.createProperty, 'Create property');
  });

  test('localizes default inspection room templates', () {
    expect(RoomTemplates.forLanguageCode('en').take(3), [
      'Entry',
      'Living room',
      'Kitchen',
    ]);
    expect(RoomTemplates.forLanguageCode('zh_Hans').take(3), [
      '玄关',
      '客厅',
      '厨房',
    ]);
  });
}
