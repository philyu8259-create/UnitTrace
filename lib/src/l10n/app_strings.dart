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
  String get continueInspection => isChinese ? '继续检查' : 'Continue inspection';
  String get startFirstInspection =>
      isChinese ? '开始第一份检查' : 'Start first inspection';
  String get dashboardTitle => isChinese ? '今日证据工作台' : 'Evidence dashboard';
  String get dashboardSubtitle => isChinese
      ? '按房源、检查类型、房间清单完成证据包。'
      : 'Move from property to inspection type, room checklist, signatures, and export.';
  String get activeProperty => isChinese ? '当前房源' : 'Active property';
  String get home => isChinese ? '首页' : 'Home';
  String get backToHome => isChinese ? '返回首页' : 'Back to Home';
  String get evidenceDesk => isChinese ? '证据工坊' : 'Evidence Desk';
  String get brandKicker => isChinese ? '房况留证' : 'UNITTRACE';
  String get localEvidenceVault =>
      isChinese ? '本地证据保险箱' : 'Local Evidence Vault';
  String get evidenceDeskTagline =>
      isChinese ? '时间戳 · 哈希 · 签名' : 'Timestamp · Hash · Signature';
  String get evidenceDeskTraits => isChinese
      ? '资产级封存 • 时间戳 • 位置与签名闭环'
      : 'Evidence vault feel · timestamp chain · signed integrity loop';
  String get recentInspection => isChinese ? '最近检查' : 'Recent inspection';
  String get noRecentInspection => isChinese ? '暂无检查' : 'No inspections yet';
  String get inspectionProgress => isChinese ? '检查进度' : 'Inspection progress';
  String get evidenceCompleteness =>
      isChinese ? '证据完整度' : 'Evidence completeness';
  String get roomsComplete => isChinese ? '房间完成' : 'Rooms complete';
  String get readyToExport => isChinese ? '可以生成报告' : 'Ready to export';
  String get generatedReports => isChinese ? '已生成报告' : 'Reports generated';
  String get needSignatureLabel => isChinese ? '缺少签名' : 'Signature needed';
  String get caseIdLabel => isChinese ? '档案号' : 'Case ID';
  String get progressLabel => isChinese ? '进度' : 'Progress';
  String get needsEvidence => isChinese ? '还缺证据' : 'Needs evidence';
  String get needsSignature => isChinese ? '建议补签名' : 'Signature recommended';
  String get noActiveInspectionTitle =>
      isChinese ? '还没有检查工作区' : 'No inspection workspace yet';
  String noActiveInspectionSubtitle(String propertyName) => isChinese
      ? '为 $propertyName 创建入住、退租或普通检查后，就可以添加照片、备注、位置、签名，并生成 PDF 证据包。'
      : 'Create a move-in, move-out, or general inspection for $propertyName to add photos, notes, location, signatures, and a PDF evidence packet.';
  String get homeInspectionGuideTitle =>
      isChinese ? '选择检查进入详情页' : 'Open inspections in a focused page';
  String homeInspectionGuideSubtitle(String propertyName) => isChinese
      ? '首页只保留 $propertyName 的房屋、检查类型和最近状态。选择检查后进入独立页面完成房间、证据、签名和报告。'
      : 'The dashboard keeps $propertyName, inspection types, and recent status only. Open an inspection to finish rooms, evidence, signatures, and reports.';
  String get moveIn => isChinese ? '入住检查' : 'Move-in';
  String get moveOut => isChinese ? '退租检查' : 'Move-out';
  String get generalInspection => isChinese ? '普通检查' : 'General';
  String get moveInCardBody => isChinese
      ? '入住前逐房间记录墙面、地板、电器和钥匙交接状态。'
      : 'Document walls, floors, appliances, and handoff condition before move-in.';
  String get moveOutCardBody => isChinese
      ? '退租时整理扣押金争议需要的照片、备注和签名。'
      : 'Collect photos, notes, and signatures for move-out deposit disputes.';
  String get generalCardBody => isChinese
      ? '用于维修、短租周转或临时房况记录。'
      : 'Use for maintenance, short-stay turnover, or routine condition records.';
  String get noProperties => isChinese
      ? '还没有房屋。先创建一个房屋，再生成证据报告。'
      : 'No properties yet. Create a property to start an evidence report.';
  String get freePlan => isChinese
      ? '内测版：最多 2 个房屋，PDF 带水印。本地保存，不上传照片。'
      : 'Beta: up to 2 properties, watermarked PDF. Local-only, no photo upload.';
  String get localOnly => isChinese ? '本地保存' : 'Local only';
  String get verified => isChinese ? '已验证' : 'Verified';
  String get ready => isChinese ? '就绪' : 'Ready';
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
      ? '生成可分享的 PDF 和证据清单。'
      : 'Generate a shareable PDF and manifest.';
  String get propertiesMetric => isChinese ? '房屋' : 'Properties';
  String get inspectionsMetric => isChinese ? '检查' : 'Inspections';
  String get evidenceWorkbench => isChinese ? '证据工作台' : 'Evidence workbench';
  String get archiveSubtitle => isChinese
      ? '已导出的 PDF 和证据清单会保存在本机档案中。'
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
  String get addNote => isChinese ? '添加备注' : 'Add note';
  String get noteEvidenceSubtitle => isChinese
      ? '文字备注也会进入证据清单。'
      : 'Text notes are saved in the evidence manifest.';
  String get inspectionGuideTitle =>
      isChinese ? '当前检查要完成什么' : 'What to finish in this inspection';
  String get inspectionGuideSubtitle => isChinese
      ? '选择房间，拍照或写备注，签名后导出报告。'
      : 'Choose a room, add photos or notes, sign, then export the report.';
  String get nextStep => isChinese ? '下一步' : 'Next step';
  String get roomChecklist => isChinese ? '房间清单' : 'Room checklist';
  String get roomChecklistSubtitle => isChinese
      ? '每个房间都能看到照片、问题、哈希和位置状态。'
      : 'See photo, issue, hash, and location status for every room.';
  String get roomDetail => isChinese ? '当前房间' : 'Current room';
  String get evidenceIntegrity => isChinese ? '证据完整性' : 'Evidence Integrity';
  String get selectedRoomEvidence =>
      isChinese ? '当前房间证据' : 'Selected room evidence';
  String get completed => isChinese ? '已完成' : 'Complete';
  String get notStarted => isChinese ? '未开始' : 'Not started';
  String get inProgress => isChinese ? '进行中' : 'In progress';
  String get hashStatus => isChinese ? '哈希状态' : 'Hash status';
  String get hashBadgeLabel => isChinese ? '哈希' : 'HASH';
  String get photo => isChinese ? '照片' : 'Photo';
  String get photos => isChinese ? '照片' : 'Photos';
  String photoMetric(int count) =>
      isChinese ? '$count 张' : '$count photo${count == 1 ? '' : 's'}';
  String photoCountLabel(int count) =>
      isChinese ? '$count 张照片' : '$count photo${count == 1 ? '' : 's'}';
  String hashMetric(int count) =>
      isChinese ? '$count 个' : '$count hash${count == 1 ? '' : 'es'}';
  String locationMetric(int count) =>
      isChinese ? '$count 个' : '$count location${count == 1 ? '' : 's'}';
  String get locationStatus => isChinese ? '位置状态' : 'Location status';
  String get timestamp => isChinese ? '时间' : 'Timestamp';
  String get locationCaptured => isChinese ? '已记录位置' : 'Location captured';
  String get locationMissing => isChinese ? '未记录位置' : 'No location';
  String get hashCaptured => isChinese ? '哈希已生成' : 'Hash ready';
  String get hashMissing => isChinese ? '无照片哈希' : 'No photo hash';
  String get photoAvailable => isChinese ? '照片可用' : 'Photo available';
  String get photoMissing => isChinese ? '照片缺失' : 'Photo missing';
  String get nextStepEvidence => isChinese
      ? '先在下方选择房间，再拍照、相册多选或添加文字备注。'
      : 'Choose a room below, then take photos, pick gallery photos, or add notes.';
  String get nextStepSignature => isChinese
      ? '证据已开始采集，下一步添加租客或房东签名。'
      : 'Evidence capture has started. Next, add tenant or landlord signatures.';
  String get nextStepReport => isChinese
      ? '证据和签名已就绪，最后生成 PDF 证据包。'
      : 'Evidence and signatures are ready. Generate the PDF packet as the final step.';
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
  String evidenceSaved(int count) => isChinese
      ? '已保存 $count 条证据'
      : 'Saved $count evidence item${count == 1 ? '' : 's'}';
  String get takePhoto => isChinese ? '拍照' : 'Camera';
  String get choosePhoto => isChinese ? '相册' : 'Gallery';
  String get cameraPermissionTitle =>
      isChinese ? '允许相机用于证据拍照' : 'Allow camera for evidence photos';
  String get cameraPermissionBody => isChinese
      ? '照片会复制到本机并生成哈希，不会上传。系统稍后可能询问相机权限。'
      : 'Photos are copied locally and hashed. Nothing uploads. The system may ask for camera access next.';
  String get galleryPermissionTitle =>
      isChinese ? '从相册选择多张证据照片' : 'Choose evidence photos from gallery';
  String get galleryPermissionBody => isChinese
      ? '可以一次选择多张照片，每张都会单独生成 SHA-256。'
      : 'You can choose multiple photos; each receives its own SHA-256 hash.';
  String get locationPermissionTitle =>
      isChinese ? '记录证据位置' : 'Record evidence location';
  String get locationPermissionBody => isChinese
      ? '如果授权，报告会显示经纬度；拒绝后仍可保存照片和备注。'
      : 'If allowed, coordinates appear in the report. If denied, photos and notes still save.';
  String get continueAction => isChinese ? '继续' : 'Continue';
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
  String get signatureSaved => isChinese ? '签名已保存' : 'Signature saved';
  String get generateReport => isChinese ? '生成 PDF 证据包' : 'Generate PDF report';
  String get shareReport => isChinese ? '分享报告' : 'Share report';
  String get reportShareReady =>
      isChinese ? 'PDF 已生成，分享面板已打开' : 'PDF generated and share sheet opened';
  String get evidence => isChinese ? '证据' : 'Evidence';
  String get rooms => isChinese ? '房间' : 'Rooms';
  String get trustedOffline => isChinese ? '离线可信证据包' : 'Trusted offline report';
  String get disclaimer => isChinese
      ? '本报告用于整理房况记录，不构成法律建议。请根据所在地法规和正式租赁文件核验。'
      : 'This report organizes property-condition records and is not legal advice. Verify requirements with local law and lease documents.';
  String get reportReady => isChinese ? '报告已生成' : 'Report ready';
  String get finalReportTitle => isChinese ? '最终报告' : 'Final report';
  String get finalReportSubtitle => isChinese
      ? '检查证据和签名后，生成带检查类型、时间、哈希和免责声明的 PDF 证据包。'
      : 'After reviewing evidence and signatures, generate a PDF packet with type, time, hashes, and disclaimer.';
  String get finalReportNeedsEvidence => isChinese
      ? '建议至少添加一条证据后再生成 PDF，避免报告内容过空。'
      : 'Add at least one evidence item before generating a PDF so the report is useful.';
  String get reports => isChinese ? '报告' : 'Reports';
  String get propertiesTab => isChinese ? '房屋' : 'Homes';
  String get inspectionTab => isChinese ? '检查' : 'Inspect';
  String get reportsTab => isChinese ? '报告' : 'Reports';
  String get moreTab => isChinese ? '更多' : 'More';
  String get moreSubtitle => isChinese
      ? '会员、隐私、支持与版本信息。'
      : 'Membership, privacy, support, and app details.';
  String get proTitle => isChinese ? '房况留证高级版' : 'UnitTrace Pro';
  String get proSubtitle => isChinese
      ? '后续解锁多房屋、无水印 PDF、导出历史和对比报告。'
      : 'Unlock more properties, watermark-free PDFs, export history, and comparison reports later.';
  String get privacyPolicy => isChinese ? '隐私政策' : 'Privacy Policy';
  String get support => isChinese ? '支持与反馈' : 'Support';
  String get privacySubtitle => isChinese
      ? '查看本地优先、无账号、照片不上传的隐私说明。'
      : 'Review the local-first privacy policy. No account and no photo upload.';
  String get supportSubtitle => isChinese
      ? '查看联系方式、反馈渠道和常见支持说明。'
      : 'View contact, feedback, and support information.';
  String get restorePurchases => isChinese ? '恢复购买' : 'Restore Purchases';
  String get version => isChinese ? '版本' : 'Version';
  String get comingSoon => isChinese ? '即将开放' : 'Coming soon';
  String get loading => isChinese ? '加载中' : 'Loading';
  String linkOpenFailed(String url) =>
      isChinese ? '无法打开链接：$url' : 'Could not open link: $url';
  String get disclaimerTitle => isChinese ? '免责声明' : 'Disclaimer';
  String get reportHistory => isChinese ? '报告历史' : 'Report history';
  String get reportArchiveBadge =>
      isChinese ? 'PDF 报告 · 证据清单' : 'PDF REPORT · MANIFEST';
  String get evidenceWatermarkBrand => isChinese ? '房况留证' : 'UNITTRACE';
  String get reportFilterAll => isChinese ? '全部' : 'All';
  String get reportFilterMoveIn => isChinese ? '入住' : 'Move-in';
  String get reportFilterMoveOut => isChinese ? '退租' : 'Move-out';
  String get reportFilterGeneral => isChinese ? '普通' : 'General';
  String get noReportsForFilter =>
      isChinese ? '当前筛选下没有报告。' : 'No reports match this filter.';
  String get noReports => isChinese
      ? '还没有导出的报告。生成 PDF 后会出现在这里。'
      : 'No exported reports yet. Generated PDFs will appear here.';
  String get reportsGuideTitle =>
      isChinese ? '报告从哪里来' : 'Where reports come from';
  String get reportsGuideSubtitle => isChinese
      ? '进入检查页，添加证据和签名后生成 PDF。导出的报告会保存在这里。'
      : 'Open a Home inspection, add evidence and signatures, then generate a PDF. Exports appear here.';
  String get goToInspection => isChinese ? '回到首页' : 'Go to Home';
  String get moreGuideTitle => isChinese ? '上架前配置' : 'Before release';
  String get moreGuideSubtitle => isChinese
      ? '会员、隐私政策、支持链接和恢复购买会统一放在这里。'
      : 'Membership, privacy, support, and purchase restore live here.';
  String get viewReport => isChinese ? '查看' : 'View';
  String get shareReportAction => isChinese ? '分享' : 'Share';
  String get pdfPreview => isChinese ? 'PDF 预览' : 'PDF preview';
  String get ok => isChinese ? '确定' : 'OK';
  String get cancel => isChinese ? '取消' : 'Cancel';
  String get delete => isChinese ? '删除' : 'Delete';
  String get deleteProperty => isChinese ? '删除房屋' : 'Delete property';
  String get deleteInspection => isChinese ? '删除检查' : 'Delete inspection';
  String get deleteEvidence => isChinese ? '删除证据' : 'Delete evidence';
  String get deleteReport => isChinese ? '删除报告' : 'Delete report';
  String get deleteSignature => isChinese ? '删除签名' : 'Delete signature';
  String get deletePropertyMessage => isChinese
      ? '这会删除该房屋下的所有检查、房间、证据和签名。本机已导出的报告不会自动删除。'
      : 'This deletes every inspection, room, evidence item, and signature under this property. Exported local reports are not deleted automatically.';
  String get deleteInspectionMessage => isChinese
      ? '这会删除这次检查下的房间、证据和签名。本机已导出的报告不会自动删除。'
      : 'This deletes rooms, evidence, and signatures for this inspection. Exported local reports are not deleted automatically.';
  String get deleteEvidenceMessage =>
      isChinese ? '这会删除这条证据记录。' : 'This deletes this evidence record.';
  String get deleteReportMessage => isChinese
      ? '这会删除本机保存的 PDF 和 JSON 证据清单，不会删除原检查数据。'
      : 'This deletes the local PDF and JSON manifest. The original inspection data stays intact.';
  String get deleteSignatureMessage =>
      isChinese ? '这会删除这条签名记录。' : 'This deletes this signature record.';
  String get propertyDeleted => isChinese ? '房屋已删除' : 'Property deleted';
  String get inspectionDeleted => isChinese ? '检查已删除' : 'Inspection deleted';
  String get evidenceDeleted => isChinese ? '证据已删除' : 'Evidence deleted';
  String get reportDeleted => isChinese ? '报告已删除' : 'Report deleted';
  String get signatureDeleted => isChinese ? '签名已删除' : 'Signature deleted';
  String get good => isChinese ? '良好' : 'Good';
  String get reportIdLabel => isChinese ? '报告ID' : 'Report ID';
  String get note => isChinese ? '备注' : 'Note';
  String get issue => isChinese ? '问题' : 'Issue';
  String get urgent => isChinese ? '紧急' : 'Urgent';
}
