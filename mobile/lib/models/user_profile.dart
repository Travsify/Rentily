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
  final String buyerType; // 'personal' or 'corporate'
  final String? businessName;
  final String? cacNumber;
  final String? taxId;
  final String? tinNumber;
  final String? officeAddress;
  final String? officeUtilityBillUrl;
  final String? officeBannerPhotoUrl;
  final String? signatoryName;
  final String? signatoryRole;
  final String? signatoryPhone;
  final String partnerStatus; // 'unverified', 'pending_review', 'verified'
  final bool rekycRequired;
  final String? dob;
  final String? bvn;
  final String? kycFailureReason;
  final int mapleradTier;
  final String? lasreraNumber;
  final String? cryptoId;
  final String? referralCode;
  final bool enableSmsNotifications;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.buyerType = 'personal',
    this.isVerified = false,
    this.enableSmsNotifications = false,
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
    this.tinNumber,
    this.officeAddress,
    this.officeUtilityBillUrl,
    this.officeBannerPhotoUrl,
    this.signatoryName,
    this.signatoryRole,
    this.signatoryPhone,
    this.partnerStatus = 'unverified',
    this.rekycRequired = false,
    this.dob,
    this.kycFailureReason,
    this.mapleradTier = 0,
    this.lasreraNumber,
    this.cryptoId,
    this.referralCode,
  });

  /// Auto-linked deterministic or assigned Referral Code
  String get displayReferralCode {
    if (referralCode != null && referralCode!.trim().isNotEmpty) {
      return referralCode!.trim().toUpperCase();
    }
    final raw = (email.isNotEmpty ? email : fullName).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final prefix = raw.length >= 4 ? raw.substring(0, 4) : 'RENT';
    int hash = 5381;
    final str = '${email}_rentilly_ref';
    for (int i = 0; i < str.length; i++) {
      hash = ((hash << 5) + hash) + str.codeUnitAt(i);
      hash &= 0xFFFFFFFF;
    }
    final suffix = hash.abs().toRadixString(36).toUpperCase().padLeft(4, '0');
    final cleanSuffix = suffix.length >= 4 ? suffix.substring(suffix.length - 4) : suffix;
    return '$prefix$cleanSuffix';
  }

  /// Auto-linked deterministic or assigned Crypto ID
  String get displayCryptoId {
    if (cryptoId != null && cryptoId!.trim().isNotEmpty) return cryptoId!;
    final clean = email.toLowerCase().trim();
    int hash = 5381;
    for (int i = 0; i < clean.length; i++) {
      hash = ((hash << 5) + hash) + clean.codeUnitAt(i);
      hash &= 0xFFFFFFFF;
    }
    final positive = hash.abs().toString().padLeft(8, '0').substring(0, 8);
    return 'RT-$positive';
  }

  // Role detection getters — role is the sole source of truth.
  // businessName/cacNumber do NOT promote a user to partner; role must be
  // explicitly 'partner'. This prevents corporate renters/buyers or landlords
  // from being routed to the partner UI.
  bool get isPartner => role.toLowerCase() == 'partner';

  bool get isLandlord =>
      role.toLowerCase() == 'owner' || role.toLowerCase() == 'landlord';

  bool get isConsumer => !isPartner && !isLandlord;

  bool get isCorporateBuyer => buyerType.toLowerCase() == 'corporate' || (businessName != null && businessName!.trim().isNotEmpty && isConsumer);

  // Extract real first name or corporate business name
  String get firstName {
    if (isPartner || isCorporateBuyer) {
      if (businessName != null && businessName!.isNotEmpty) return businessName!;
      if (fullName.isNotEmpty && fullName.toLowerCase() != 'info' && fullName.toLowerCase() != 'user') return fullName;
      return isPartner ? 'Corporate Partner' : 'Corporate Buyer';
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
    final businessName = json['businessName']?.toString() ?? json['business_name']?.toString() ?? json['companyName']?.toString() ?? json['company_name']?.toString();
    final buyerType = json['buyerType']?.toString() ?? json['buyer_type']?.toString() ?? ((businessName != null && businessName.trim().isNotEmpty && rawRole == 'renter') ? 'corporate' : 'personal');

    final bool isPartnerRole = rawRole.toLowerCase() == 'partner';
    final effectiveRole = isPartnerRole ? 'partner' : rawRole;

    final tinVal = json['tinNumber']?.toString() ?? json['tin_number']?.toString() ?? json['taxId']?.toString() ?? json['tax_id']?.toString();

    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: rawEmail,
      fullName: rawName,
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone_number']?.toString() ?? '',
      role: effectiveRole,
      buyerType: buyerType,
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
      taxId: tinVal,
      tinNumber: tinVal,
      officeAddress: json['officeAddress']?.toString() ?? json['office_address']?.toString(),
      officeUtilityBillUrl: json['officeUtilityBillUrl']?.toString() ?? json['office_utility_bill_url']?.toString(),
      officeBannerPhotoUrl: json['officeBannerPhotoUrl']?.toString() ?? json['office_banner_photo_url']?.toString(),
      signatoryName: json['signatoryName']?.toString() ?? json['signatory_name']?.toString() ?? json['authorized_signatory_name']?.toString(),
      signatoryRole: json['signatoryRole']?.toString() ?? json['signatory_role']?.toString() ?? json['authorized_signatory_role']?.toString(),
      signatoryPhone: json['signatoryPhone']?.toString() ?? json['signatory_phone']?.toString() ?? json['authorized_signatory_phone']?.toString(),
      partnerStatus: isPartnerRole ? 'verified' : (json['partnerStatus']?.toString() ?? json['partner_status']?.toString() ?? 'unverified'),
      rekycRequired: json['rekycRequired'] ?? json['rekyc_required'] ?? false,
      dob: json['dob']?.toString(),
      bvn: json['bvn']?.toString() ?? json['bvn_number']?.toString(),
      kycFailureReason: json['kycFailureReason']?.toString() ?? json['kyc_failure_reason']?.toString() ?? json['reason']?.toString(),
      mapleradTier: (json['mapleradTier'] as num?)?.toInt() ?? 0,
      lasreraNumber: json['lasreraNumber']?.toString() ?? json['lasrera_number']?.toString(),
      cryptoId: json['cryptoId']?.toString() ?? json['crypto_id']?.toString(),
      referralCode: json['referralCode']?.toString() ?? json['referral_code']?.toString(),
      enableSmsNotifications: json['enableSmsNotifications'] == true || json['enable_sms_notifications'] == true || json['sms_notifications_enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
      'buyerType': buyerType,
      'isVerified': isVerified,
      'enableSmsNotifications': enableSmsNotifications,
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
      'tinNumber': tinNumber,
      'officeAddress': officeAddress,
      'officeUtilityBillUrl': officeUtilityBillUrl,
      'officeBannerPhotoUrl': officeBannerPhotoUrl,
      'signatoryName': signatoryName,
      'signatoryRole': signatoryRole,
      'signatoryPhone': signatoryPhone,
      'partnerStatus': partnerStatus,
      'rekycRequired': rekycRequired,
      'dob': dob,
      'kycFailureReason': kycFailureReason,
      'mapleradTier': mapleradTier,
      'lasreraNumber': lasreraNumber,
      'cryptoId': cryptoId,
      'referralCode': referralCode,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? role,
    String? buyerType,
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
    String? tinNumber,
    String? officeAddress,
    String? officeUtilityBillUrl,
    String? officeBannerPhotoUrl,
    String? signatoryName,
    String? signatoryRole,
    String? signatoryPhone,
    String? partnerStatus,
    bool? rekycRequired,
    String? dob,
    String? kycFailureReason,
    int? mapleradTier,
    String? lasreraNumber,
    String? cryptoId,
    String? referralCode,
    bool? enableSmsNotifications,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      buyerType: buyerType ?? this.buyerType,
      isVerified: isVerified ?? this.isVerified,
      enableSmsNotifications: enableSmsNotifications ?? this.enableSmsNotifications,
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
      tinNumber: tinNumber ?? this.tinNumber,
      officeAddress: officeAddress ?? this.officeAddress,
      officeUtilityBillUrl: officeUtilityBillUrl ?? this.officeUtilityBillUrl,
      officeBannerPhotoUrl: officeBannerPhotoUrl ?? this.officeBannerPhotoUrl,
      signatoryName: signatoryName ?? this.signatoryName,
      signatoryRole: signatoryRole ?? this.signatoryRole,
      signatoryPhone: signatoryPhone ?? this.signatoryPhone,
      partnerStatus: partnerStatus ?? this.partnerStatus,
      rekycRequired: rekycRequired ?? this.rekycRequired,
      dob: dob ?? this.dob,
      kycFailureReason: kycFailureReason ?? this.kycFailureReason,
      mapleradTier: mapleradTier ?? this.mapleradTier,
      lasreraNumber: lasreraNumber ?? this.lasreraNumber,
      cryptoId: cryptoId ?? this.cryptoId,
      referralCode: referralCode ?? this.referralCode,
    );
  }
}
