import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings._(this.languageCode);

  final String languageCode;

  static AppStrings of(BuildContext context) {
    return forLanguageCode(Localizations.localeOf(context).toLanguageTag());
  }

  static AppStrings forLanguageCode(String languageCode) {
    final normalized = languageCode.toLowerCase();
    if (normalized.startsWith('zh')) {
      return const AppStrings._('zh_Hans');
    }
    return const AppStrings._('en');
  }

  bool get isChinese => languageCode == 'zh_Hans';

  String get appTitle => isChinese ? '房况留证' : 'UnitTrace';
  String get appSubtitle => isChinese ? '租房交接拍照报告' : 'Rental Evidence Reports';
  String get createProperty => isChinese ? '创建房屋' : 'Create property';
  String get saveProperty => isChinese ? '保存房屋' : 'Save property';
  String get propertyName => isChinese ? '房屋名称' : 'Property name';
  String get address => isChinese ? '地址' : 'Address';
  String get startInspection => isChinese ? '开始检查' : 'Start inspection';
  String get moveIn => isChinese ? '入住检查' : 'Move-in';
  String get moveOut => isChinese ? '退租检查' : 'Move-out';
  String get generalInspection => isChinese ? '普通检查' : 'General';
  String get noProperties => isChinese
      ? '还没有房屋。先创建一个房屋，再生成证据报告。'
      : 'No properties yet. Create a property to start an evidence report.';
  String get freePlan => isChinese
      ? '免费版：1 个房屋，PDF 带水印。本地保存，不上传照片。'
      : 'Free: 1 property, watermarked PDF. Local-only, no photo upload.';
  String get addEvidence => isChinese ? '添加证据' : 'Add evidence';
  String get description => isChinese ? '问题描述或备注' : 'Description or note';
  String get saveNote => isChinese ? '保存备注' : 'Save note';
  String get takePhoto => isChinese ? '拍照' : 'Camera';
  String get choosePhoto => isChinese ? '相册' : 'Gallery';
  String get signatures => isChinese ? '签名' : 'Signatures';
  String get addSignature => isChinese ? '添加签名' : 'Add signature';
  String get signerName => isChinese ? '签名人姓名' : 'Signer name';
  String get tenant => isChinese ? '租客' : 'Tenant';
  String get landlord => isChinese ? '房东' : 'Landlord';
  String get clear => isChinese ? '清除' : 'Clear';
  String get saveSignature => isChinese ? '保存签名' : 'Save signature';
  String get generateReport => isChinese ? '生成 PDF 证据包' : 'Generate PDF report';
  String get shareReport => isChinese ? '分享报告' : 'Share report';
  String get evidence => isChinese ? '证据' : 'Evidence';
  String get rooms => isChinese ? '房间' : 'Rooms';
  String get trustedOffline => isChinese ? '离线可信证据包' : 'Trusted offline report';
  String get disclaimer => isChinese
      ? '本报告用于整理房况记录，不构成法律建议。请根据所在地法规和正式租赁文件核验。'
      : 'This report organizes property-condition records and is not legal advice. Verify requirements with local law and lease documents.';
  String get reportReady => isChinese ? '报告已生成' : 'Report ready';
  String get ok => isChinese ? '确定' : 'OK';
  String get cancel => isChinese ? '取消' : 'Cancel';
  String get good => isChinese ? '良好' : 'Good';
  String get note => isChinese ? '备注' : 'Note';
  String get issue => isChinese ? '问题' : 'Issue';
  String get urgent => isChinese ? '紧急' : 'Urgent';
}
