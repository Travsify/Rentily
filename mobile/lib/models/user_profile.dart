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
  final String? accountNumber;
  final String? bankName;
  final String? state;

  // Partner / Corporate Vetting Fields
  final String? businessName;
  final String? cacNumber;
  final String? officeAddress;
  final String? officeUtilityBillUrl;
  final String? officeBannerPhotoUrl;
  final String partnerStatus; // 'unverified', 'pending_review', 'verified'

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.isVerified = false,
    this.ninNumber,
    this.bvnVerified = false,
    this.avatarUrl,
    this.walletBalance = 0.00,
    this.accountNumber,
    this.bankName,
    this.state = 'Lagos',
    this.businessName,
    this.cacNumber,
    this.officeAddress,
    this.officeUtilityBillUrl,
    this.officeBannerPhotoUrl,
    this.partnerStatus = 'unverified',
  });

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

    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: rawEmail,
      fullName: rawName,
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone_number']?.toString() ?? '',
      role: json['role']?.toString() ?? 'renter',
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      ninNumber: json['ninNumber']?.toString() ?? json['nin_number']?.toString(),
      bvnVerified: json['bvnVerified'] ?? json['bvn_verified'] ?? false,
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.00,
      accountNumber: json['accountNumber']?.toString(),
      bankName: json['bankName']?.toString(),
      state: json['state']?.toString() ?? 'Lagos',
      businessName: json['businessName']?.toString() ?? json['business_name']?.toString(),
      cacNumber: json['cacNumber']?.toString() ?? json['cac_number']?.toString(),
      officeAddress: json['officeAddress']?.toString() ?? json['office_address']?.toString(),
      officeUtilityBillUrl: json['officeUtilityBillUrl']?.toString() ?? json['office_utility_bill_url']?.toString(),
      officeBannerPhotoUrl: json['officeBannerPhotoUrl']?.toString() ?? json['office_banner_photo_url']?.toString(),
      partnerStatus: json['partnerStatus']?.toString() ?? json['partner_status']?.toString() ?? 'unverified',
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
      'bvnVerified': bvnVerified,
      'avatarUrl': avatarUrl,
      'walletBalance': walletBalance,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'state': state,
      'businessName': businessName,
      'cacNumber': cacNumber,
      'officeAddress': officeAddress,
      'officeUtilityBillUrl': officeUtilityBillUrl,
      'officeBannerPhotoUrl': officeBannerPhotoUrl,
      'partnerStatus': partnerStatus,
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
    bool? bvnVerified,
    String? avatarUrl,
    double? walletBalance,
    String? accountNumber,
    String? bankName,
    String? state,
    String? businessName,
    String? cacNumber,
    String? officeAddress,
    String? officeUtilityBillUrl,
    String? officeBannerPhotoUrl,
    String? partnerStatus,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      ninNumber: ninNumber ?? this.ninNumber,
      bvnVerified: bvnVerified ?? this.bvnVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      state: state ?? this.state,
      businessName: businessName ?? this.businessName,
      cacNumber: cacNumber ?? this.cacNumber,
      officeAddress: officeAddress ?? this.officeAddress,
      officeUtilityBillUrl: officeUtilityBillUrl ?? this.officeUtilityBillUrl,
      officeBannerPhotoUrl: officeBannerPhotoUrl ?? this.officeBannerPhotoUrl,
      partnerStatus: partnerStatus ?? this.partnerStatus,
    );
  }
}
