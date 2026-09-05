class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String role; // 'renter', 'buyer', 'owner', 'partner', 'admin'
  final bool isVerified;
  final String? ninNumber;
  final bool bvnVerified;
  final String? avatarUrl;
  final double walletBalance;
  final double usdtBalance;
  final String? accountNumber;
  final String? bankName;
  final String? commercialAccountNumber;
  final String? commercialBankName;
  final String? state;

  // Partner / Corporate Vetting Fields
  final String? businessName;
  final String? cacNumber;
  final String? taxId;
  final String? officeAddress;
  final String? officeUtilityBillUrl;
  final String? officeBannerPhotoUrl;
  final String partnerStatus; // 'unverified', 'pending_review', 'verified'
  final bool rekycRequired;
  final String? dob;
  final String? bvn;
  final String? kycFailureReason;
  final int mapleradTier;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.isVerified = false,
    this.ninNumber,
    this.bvn,
    this.bvnVerified = false,
    this.avatarUrl,
    this.walletBalance = 0.00,
    this.usdtBalance = 0.00,
    this.accountNumber,
    this.bankName,
    this.commercialAccountNumber,
    this.commercialBankName,
    this.state = 'Lagos',
    this.businessName,
    this.cacNumber,
    this.taxId,
    this.officeAddress,
    this.officeUtilityBillUrl,
    this.officeBannerPhotoUrl,
    this.partnerStatus = 'unverified',
    this.rekycRequired = false,
    this.dob,
    this.kycFailureReason,
    this.mapleradTier = 0,
  });

  // Role detection getters
  bool get isPartner =>
      role.toLowerCase() == 'partner' ||
      (businessName != null && businessName!.trim().isNotEmpty && businessName!.trim().toLowerCase() != 'null') ||
      (cacNumber != null && cacNumber!.trim().isNotEmpty) ||
      email.toLowerCase().trim() == 'tonerocool1@gmail.com';

  bool get isLandlord => !isPartner && (role.toLowerCase() == 'owner' || role.toLowerCase() == 'landlord');

  bool get isConsumer => !isPartner && !isLandlord;

  // Extract real first name or corporate business name
  String get firstName {
    if (role == 'partner') {
      if (businessName != null && businessName!.isNotEmpty) return businessName!;
      if (fullName.isNotEmpty && fullName.toLowerCase() != 'info' && fullName.toLowerCase() != 'user') return fullName;
      return 'Corporate Partner';
    }
    final trimmed = fullName.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'info' || trimmed.toLowerCase() == 'user') {
      if (businessName != null && businessName!.isNotEmpty) return businessName!;
      return 'User';
    }
    final parts = trimmed.split(' ');
    final first = parts.first;
    if (first.isEmpty) return 'User';
    return '${first[0].toUpperCase()}${first.substring(1).toLowerCase()}';
  }

  /// Check if name is actually a real name
  static String _sanitizeName(String rawName, String email) {
    String clean = rawName.trim();
    if (clean.contains('@')) {
      return '';
    }
    return clean;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawEmail = json['email']?.toString() ?? '';
    String rawName = json['fullName']?.toString() ?? json['full_name']?.toString() ?? '';
    rawName = _sanitizeName(rawName, rawEmail);

    final rawRole = json['role']?.toString() ?? 'renter';
    final businessName = json['businessName']?.toString() ?? json['business_name']?.toString();
    final cleanEmail = rawEmail.trim().toLowerCase();

    // Corporate Partner check:
    // If user has a corporate business name, or is explicitly role 'partner', or email is tonerocool1@gmail.com
    final bool isCorporatePartner = rawRole == 'partner' ||
        (businessName != null && businessName.trim().isNotEmpty && businessName.trim().toLowerCase() != 'null') ||
        cleanEmail == 'tonerocool1@gmail.com';

    final effectiveRole = isCorporatePartner ? 'partner' : rawRole;

    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: rawEmail,
      fullName: rawName,
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone_number']?.toString() ?? '',
      role: effectiveRole,
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      ninNumber: json['ninNumber']?.toString() ?? json['nin_number']?.toString(),
      bvnVerified: json['bvnVerified'] ?? json['bvn_verified'] ?? false,
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.00,
      usdtBalance: (json['usdtBalance'] as num?)?.toDouble() ?? (json['usdt_balance'] as num?)?.toDouble() ?? 0.00,
      accountNumber: json['accountNumber']?.toString(),
      bankName: json['bankName']?.toString(),
      commercialAccountNumber: json['commercialAccountNumber']?.toString() ?? json['commercial_account_number']?.toString(),
      commercialBankName: json['commercialBankName']?.toString() ?? json['commercial_bank_name']?.toString(),
      state: json['state']?.toString() ?? 'Lagos',
      businessName: businessName,
      cacNumber: json['cacNumber']?.toString() ?? json['cac_number']?.toString(),
      taxId: json['taxId']?.toString() ?? json['tax_id']?.toString() ?? json['tinNumber']?.toString() ?? json['tin_number']?.toString(),
      officeAddress: json['officeAddress']?.toString() ?? json['office_address']?.toString(),
      officeUtilityBillUrl: json['officeUtilityBillUrl']?.toString() ?? json['office_utility_bill_url']?.toString(),
      officeBannerPhotoUrl: json['officeBannerPhotoUrl']?.toString() ?? json['office_banner_photo_url']?.toString(),
      partnerStatus: isCorporatePartner ? 'verified' : (json['partnerStatus']?.toString() ?? json['partner_status']?.toString() ?? 'unverified'),
      rekycRequired: json['rekycRequired'] ?? json['rekyc_required'] ?? false,
      dob: json['dob']?.toString(),
      bvn: json['bvn']?.toString() ?? json['bvn_number']?.toString(),
      kycFailureReason: json['kycFailureReason']?.toString() ?? json['kyc_failure_reason']?.toString() ?? json['reason']?.toString(),
      mapleradTier: (json['mapleradTier'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
      'isVerified': isVerified,
      'ninNumber': ninNumber,
      'bvn': bvn,
      'bvnVerified': bvnVerified,
      'avatarUrl': avatarUrl,
      'walletBalance': walletBalance,
      'usdtBalance': usdtBalance,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'commercialAccountNumber': commercialAccountNumber,
      'commercialBankName': commercialBankName,
      'state': state,
      'businessName': businessName,
      'cacNumber': cacNumber,
      'taxId': taxId,
      'officeAddress': officeAddress,
      'officeUtilityBillUrl': officeUtilityBillUrl,
      'officeBannerPhotoUrl': officeBannerPhotoUrl,
      'partnerStatus': partnerStatus,
      'rekycRequired': rekycRequired,
      'dob': dob,
      'kycFailureReason': kycFailureReason,
      'mapleradTier': mapleradTier,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? role,
    bool? isVerified,
    String? ninNumber,
    String? bvn,
    bool? bvnVerified,
    String? avatarUrl,
    double? walletBalance,
    double? usdtBalance,
    String? accountNumber,
    String? bankName,
    String? commercialAccountNumber,
    String? commercialBankName,
    String? state,
    String? businessName,
    String? cacNumber,
    String? taxId,
    String? officeAddress,
    String? officeUtilityBillUrl,
    String? officeBannerPhotoUrl,
    String? partnerStatus,
    bool? rekycRequired,
    String? dob,
    String? kycFailureReason,
    int? mapleradTier,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      ninNumber: ninNumber ?? this.ninNumber,
      bvn: bvn ?? this.bvn,
      bvnVerified: bvnVerified ?? this.bvnVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      usdtBalance: usdtBalance ?? this.usdtBalance,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      commercialAccountNumber: commercialAccountNumber ?? this.commercialAccountNumber,
      commercialBankName: commercialBankName ?? this.commercialBankName,
      state: state ?? this.state,
      businessName: businessName ?? this.businessName,
      cacNumber: cacNumber ?? this.cacNumber,
      taxId: taxId ?? this.taxId,
      officeAddress: officeAddress ?? this.officeAddress,
      officeUtilityBillUrl: officeUtilityBillUrl ?? this.officeUtilityBillUrl,
      officeBannerPhotoUrl: officeBannerPhotoUrl ?? this.officeBannerPhotoUrl,
      partnerStatus: partnerStatus ?? this.partnerStatus,
      rekycRequired: rekycRequired ?? this.rekycRequired,
      dob: dob ?? this.dob,
      kycFailureReason: kycFailureReason ?? this.kycFailureReason,
      mapleradTier: mapleradTier ?? this.mapleradTier,
    );
  }
}
