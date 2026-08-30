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
  });

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
    };
  }
}
