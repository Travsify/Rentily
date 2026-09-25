class ExternalLegalOrder {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String? userPhone;
  final String serviceType;
  final String serviceTitle;
  final String propertyTitle;
  final String propertyAddress;
  final String propertyState;
  final String? propertyLga;
  final double? propertyValue;
  final double feeAmount;
  final String? documentType;
  final List<String> documentUrls;
  final String? additionalNotes;
  final String status;
  final String? assignedCounselName;
  final String? assignedCounselNba;
  final String? reportSummary;
  final String? reportPdfUrl;
  final String? certificateHash;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  ExternalLegalOrder({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.userPhone,
    required this.serviceType,
    required this.serviceTitle,
    required this.propertyTitle,
    required this.propertyAddress,
    required this.propertyState,
    this.propertyLga,
    this.propertyValue,
    required this.feeAmount,
    this.documentType,
    this.documentUrls = const [],
    this.additionalNotes,
    required this.status,
    this.assignedCounselName,
    this.assignedCounselNba,
    this.reportSummary,
    this.reportPdfUrl,
    this.certificateHash,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory ExternalLegalOrder.fromJson(Map<String, dynamic> json) {
    return ExternalLegalOrder(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userEmail: json['userEmail']?.toString() ?? json['user_email']?.toString() ?? '',
      userName: json['userName']?.toString() ?? json['user_name']?.toString() ?? 'Valued Client',
      userPhone: json['userPhone']?.toString() ?? json['user_phone']?.toString(),
      serviceType: json['serviceType']?.toString() ?? json['service_type']?.toString() ?? 'single_doc_50k',
      serviceTitle: json['serviceTitle']?.toString() ?? json['service_title']?.toString() ?? 'Legal Document Verification',
      propertyTitle: json['propertyTitle']?.toString() ?? json['property_title']?.toString() ?? 'External Property',
      propertyAddress: json['propertyAddress']?.toString() ?? json['property_address']?.toString() ?? 'Nigeria',
      propertyState: json['propertyState']?.toString() ?? json['property_state']?.toString() ?? 'Lagos',
      propertyLga: json['propertyLga']?.toString() ?? json['property_lga']?.toString(),
      propertyValue: (json['propertyValue'] as num?)?.toDouble() ?? (json['property_value'] as num?)?.toDouble(),
      feeAmount: (json['feeAmount'] as num?)?.toDouble() ?? (json['fee_amount'] as num?)?.toDouble() ?? 50000.0,
      documentType: json['documentType']?.toString() ?? json['document_type']?.toString(),
      documentUrls: json['documentUrls'] != null 
          ? List<String>.from(json['documentUrls']) 
          : (json['document_urls'] != null ? List<String>.from(json['document_urls']) : []),
      additionalNotes: json['additionalNotes']?.toString() ?? json['additional_notes']?.toString(),
      status: json['status']?.toString() ?? 'pending_review',
      assignedCounselName: json['assignedCounselName']?.toString() ?? json['assigned_counsel_name']?.toString(),
      assignedCounselNba: json['assignedCounselNba']?.toString() ?? json['assigned_counsel_nba']?.toString(),
      reportSummary: json['reportSummary']?.toString() ?? json['report_summary']?.toString(),
      reportPdfUrl: json['reportPdfUrl']?.toString() ?? json['report_pdf_url']?.toString(),
      certificateHash: json['certificateHash']?.toString() ?? json['certificate_hash']?.toString(),
      rejectionReason: json['rejectionReason']?.toString() ?? json['rejection_reason']?.toString(),
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() 
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now()),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now() 
          : (json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) ?? DateTime.now() : DateTime.now()),
      completedAt: json['completedAt'] != null 
          ? DateTime.tryParse(json['completedAt']) 
          : (json['completed_at'] != null ? DateTime.tryParse(json['completed_at']) : null),
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending_review';
  bool get isInProgress => status == 'in_progress';
  bool get isRejected => status == 'rejected';
}
