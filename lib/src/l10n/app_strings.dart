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
  String get noActiveInspectionTitle =>
      isChinese ? '还没有检查工作区' : 'No inspection workspace yet';
  String noActiveInspectionSubtitle(String propertyName) => isChinese
      ? '为 $propertyName 创建入住、退租或普通检查后，就可以添加照片、备注、位置、签名，并生成 PDF 证据包。'
      : 'Create a move-in, move-out, or general inspection for $propertyName to add photos, notes, location, signatures, and a PDF evidence packet.';
  String get moveIn => isChinese ? '入住检查' : 'Move-in';
  String get moveOut => isChinese ? '退租检查' : 'Move-out';
  String get generalInspection => isChinese ? '普通检查' : 'General';
  String get noProperties => isChinese
      ? '还没有房屋。先创建一个房屋，再生成证据报告。'
      : 'No properties yet. Create a property to start an evidence report.';
  String get freePlan => isChinese
      ? '内测版：最多 2 个房屋，PDF 带水印。本地保存，不上传照片。'
      : 'Beta: up to 2 properties, watermarked PDF. Local-only, no photo upload.';
  String get localOnly => isChinese ? '本地保存' : 'Local only';
  String get hashReady => isChinese ? '哈希留痕' : 'Hash trail';
  String get pdfEvidence => isChinese ? 'PDF 证据包' : 'PDF packet';
  String get mainFlowTitle => isChinese ? '推荐流程' : 'Recommended flow';
  String get homeFlowSubtitle => isChinese
      ? '先建房屋，再创建检查，最后导出证据包。'
      : 'Create a property, start an inspection, then export the packet.';
  String get stepProperty => isChinese ? '房屋' : 'Property';
  String get stepPropertyBody =>
      isChinese ? '保存地址和检查对象。' : 'Save the address and unit context.';
  String get stepInspection => isChinese ? '检查' : 'Inspection';
  String get stepInspectionBody =>
      isChinese ? '按房间采集照片和备注。' : 'Capture photos and notes by room.';
  String get stepReport => isChinese ? '报告' : 'Report';
  String get stepReportBody => isChinese
      ? '生成可分享的 PDF 和 manifest。'
      : 'Generate a shareable PDF and manifest.';
  String get propertiesMetric => isChinese ? '房屋' : 'Properties';
  String get inspectionsMetric => isChinese ? '检查' : 'Inspections';
  String get evidenceWorkbench => isChinese ? '证据工作台' : 'Evidence workbench';
  String get archiveSubtitle => isChinese
      ? '已导出的 PDF 和 manifest 会保存在本机档案中。'
      : 'Exported PDFs and manifests stay archived on this device.';
  String get captureReady => isChinese ? '采集就绪' : 'Capture ready';
  String get signatureReady => isChinese ? '签名就绪' : 'Signature ready';
  String get exportReady => isChinese ? '可导出' : 'Export ready';
  String get proLimitTitle =>
      isChinese ? '内测版房屋数量已满' : 'Beta property limit reached';
  String get proLimitMessage => isChinese
      ? 'MVP 先预留 Pro 解锁。当前内测版支持 2 个房屋，用于验证多房屋和报告归档体验。'
      : 'Pro unlock is reserved for the MVP. The beta currently supports 2 properties so we can validate multi-property reports.';
  String get addEvidence => isChinese ? '添加证据' : 'Add evidence';
  String get inspectionGuideTitle =>
      isChinese ? '当前检查要完成什么' : 'What to finish in this inspection';
  String get inspectionGuideSubtitle => isChinese
      ? '选择房间，拍照或写备注，签名后导出报告。'
      : 'Choose a room, add photos or notes, sign, then export the report.';
  String get emptyEvidenceTitle =>
      isChinese ? '这个房间还没有证据' : 'No evidence in this room yet';
  String get emptyEvidenceSubtitle => isChinese
      ? '可以拍照、从相册选择多张照片，或先添加文字备注。'
      : 'Take a photo, choose multiple gallery photos, or add a text note first.';
  String get emptySignatureTitle => isChinese ? '还没有签名' : 'No signatures yet';
  String get emptySignatureSubtitle => isChinese
      ? '退租或交接时可让租客和房东分别签名。'
      : 'For move-out or handoff, collect tenant and landlord signatures.';
  String get description => isChinese ? '问题描述或备注' : 'Description or note';
  String get saveNote => isChinese ? '保存备注' : 'Save note';
  String get saveEvidence => isChinese ? '保存证据' : 'Save evidence';
  String get takePhoto => isChinese ? '拍照' : 'Camera';
  String get choosePhoto => isChinese ? '相册' : 'Gallery';
  String get noPhotoCaptured => isChinese
      ? '没有拍到照片。请确认相机可用并已授权。'
      : 'No photo captured. Confirm camera access is available and allowed.';
  String photosAttached(int count) => isChinese
      ? '已添加 $count 张照片'
      : '$count photo${count == 1 ? '' : 's'} attached';
  String photosHashReady(int count) => isChinese
      ? '已复制到本机，并分别生成 SHA-256 哈希。'
      : 'Copied locally with SHA-256 for each photo.';
  String get photoFileMissing => isChinese
      ? '照片文件缺失，仅保留原始哈希记录。'
      : 'Photo file missing; original hash retained.';
  String photoAccessFailed(String detail) =>
      isChinese ? '无法添加照片：$detail' : 'Could not add photo: $detail';
  String photoSaveFailed(String detail) =>
      isChinese ? '照片保存失败：$detail' : 'Photo save failed: $detail';
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
  String get reports => isChinese ? '报告' : 'Reports';
  String get propertiesTab => isChinese ? '房屋' : 'Homes';
  String get inspectionTab => isChinese ? '检查' : 'Inspect';
  String get reportsTab => isChinese ? '报告' : 'Reports';
  String get moreTab => isChinese ? '更多' : 'More';
  String get moreSubtitle => isChinese
      ? '会员、隐私、支持与版本信息。'
      : 'Membership, privacy, support, and app details.';
  String get proTitle => isChinese ? 'UnitTrace Pro' : 'UnitTrace Pro';
  String get proSubtitle => isChinese
      ? '后续解锁多房屋、无水印 PDF、导出历史和对比报告。'
      : 'Unlock more properties, watermark-free PDFs, export history, and comparison reports later.';
  String get privacyPolicy => isChinese ? '隐私政策' : 'Privacy Policy';
  String get support => isChinese ? '支持与反馈' : 'Support';
  String get restorePurchases => isChinese ? '恢复购买' : 'Restore Purchases';
  String get version => isChinese ? '版本' : 'Version';
  String get comingSoon => isChinese ? '即将开放' : 'Coming soon';
  String get linkPending =>
      isChinese ? '上架前配置链接' : 'Link to be configured before release';
  String get disclaimerTitle => isChinese ? '免责声明' : 'Disclaimer';
  String get reportHistory => isChinese ? '报告历史' : 'Report history';
  String get noReports => isChinese
      ? '还没有导出的报告。生成 PDF 后会出现在这里。'
      : 'No exported reports yet. Generated PDFs will appear here.';
  String get reportsGuideTitle =>
      isChinese ? '报告从哪里来' : 'Where reports come from';
  String get reportsGuideSubtitle => isChinese
      ? '进入检查页，添加证据和签名后生成 PDF。导出的报告会保存在这里。'
      : 'Open Inspect, add evidence and signatures, then generate a PDF. Exports appear here.';
  String get goToInspection => isChinese ? '去检查页' : 'Go to Inspect';
  String get moreGuideTitle => isChinese ? '上架前配置' : 'Before release';
  String get moreGuideSubtitle => isChinese
      ? '会员、隐私政策、支持链接和恢复购买会统一放在这里。'
      : 'Membership, privacy, support, and purchase restore live here.';
  String get viewReport => isChinese ? '查看' : 'View';
  String get shareReportAction => isChinese ? '分享' : 'Share';
  String get pdfPreview => isChinese ? 'PDF 预览' : 'PDF preview';
  String get ok => isChinese ? '确定' : 'OK';
  String get cancel => isChinese ? '取消' : 'Cancel';
  String get good => isChinese ? '良好' : 'Good';
  String get note => isChinese ? '备注' : 'Note';
  String get issue => isChinese ? '问题' : 'Issue';
  String get urgent => isChinese ? '紧急' : 'Urgent';
}
