class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String role; // 'renter', 'buyer', 'owner', 'admin'
  final bool isVerified;
  final String? ninNumber;
  final bool bvnVerified;
  final String? avatarUrl;
  final double walletBalance;
  final String? accountNumber;
  final String? bankName;

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
  });

  // Extract real first name (e.g. "Patrick Atua" -> "Patrick")
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'User';
    final parts = trimmed.split(' ');
    return parts.first;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? 'Rentilly User',
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone_number']?.toString() ?? '',
      role: json['role']?.toString() ?? 'renter',
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      ninNumber: json['ninNumber']?.toString() ?? json['nin_number']?.toString(),
      bvnVerified: json['bvnVerified'] ?? json['bvn_verified'] ?? false,
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.00,
      accountNumber: json['accountNumber']?.toString(),
      bankName: json['bankName']?.toString(),
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
    };
  }
}
