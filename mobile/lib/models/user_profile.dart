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
  final String? state;

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
  });

  // Extract real first name (e.g. "Patrick Atua" -> "Patrick")
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'User';
    // Reject if name looks like email prefix
    if (trimmed.contains('@')) return 'User';
    if (email.contains('@')) {
      final emailPrefix = email.split('@')[0].toLowerCase();
      if (trimmed.toLowerCase() == emailPrefix) return 'User';
    }
    final parts = trimmed.split(' ');
    final first = parts.first;
    if (first.isEmpty) return 'User';
    return '${first[0].toUpperCase()}${first.substring(1).toLowerCase()}';
  }

  /// Check if name is actually a real name (not email prefix or empty)
  static String _sanitizeName(String rawName, String email) {
    if (rawName.isEmpty || rawName.contains('@')) return '';

    // Check if name matches the email prefix (case-insensitive)
    if (email.contains('@')) {
      final emailPrefix = email.split('@')[0].toLowerCase();
      if (rawName.toLowerCase() == emailPrefix ||
          rawName.toUpperCase() == emailPrefix.toUpperCase()) {
        return ''; // Name is corrupted — it's just the email prefix
      }
    }

    return rawName;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawEmail = json['email']?.toString() ?? '';
    // Get name from JSON, try both camelCase and snake_case keys
    String rawName = json['fullName']?.toString() ?? json['full_name']?.toString() ?? '';

    // Sanitize: reject if name is the email prefix (e.g. "INFO" from "info@travsify.com")
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
    );
  }
}
