import 'dart:convert';

class RoommatePost {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String userOccupation;
  final String postType; // 'have_room' | 'need_room'
  final double budgetShare; // e.g. 1200000 (individual annual share)
  final double totalRent; // e.g. 2400000 (total annual apartment rent)
  final int splitCount; // 2 or 3 persons
  final int splitPercentage; // e.g. 50 or 33
  final String location; // e.g. 'Lekki Phase 1, Lagos'
  final String state; // e.g. 'Lagos'
  final String bedroomType; // e.g. '2 Bedroom Flat' or '3 Bedroom Flat'
  final String moveInTimeline; // e.g. 'Immediate'
  final String genderPreference; // 'Any' | 'Female Only' | 'Male Only'
  final List<String> lifestyleTags; // e.g. ['Remote Tech Worker', 'Non-Smoker']
  final List<String> imageUrls;
  final String aboutMe;
  final bool isVerified;
  final DateTime createdAt;

  RoommatePost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.userOccupation,
    required this.postType,
    required this.budgetShare,
    required this.totalRent,
    this.splitCount = 2,
    required this.splitPercentage,
    required this.location,
    required this.state,
    required this.bedroomType,
    required this.moveInTimeline,
    required this.genderPreference,
    required this.lifestyleTags,
    required this.imageUrls,
    required this.aboutMe,
    this.isVerified = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'userAvatar': userAvatar,
    'userOccupation': userOccupation,
    'postType': postType,
    'budgetShare': budgetShare,
    'totalRent': totalRent,
    'splitCount': splitCount,
    'splitPercentage': splitPercentage,
    'location': location,
    'state': state,
    'bedroomType': bedroomType,
    'moveInTimeline': moveInTimeline,
    'genderPreference': genderPreference,
    'lifestyleTags': lifestyleTags,
    'imageUrls': imageUrls,
    'aboutMe': aboutMe,
    'isVerified': isVerified,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RoommatePost.fromJson(Map<String, dynamic> json) => RoommatePost(
    id: json['id'] ?? 'ROOM_${DateTime.now().millisecondsSinceEpoch}',
    userId: json['userId'] ?? 'USER_GUEST',
    userName: json['userName'] ?? 'Verified Renter',
    userAvatar: json['userAvatar'] ?? 'VR',
    userOccupation: json['userOccupation'] ?? 'Professional',
    postType: json['postType'] ?? 'have_room',
    budgetShare: (json['budgetShare'] as num?)?.toDouble() ?? 1200000.0,
    totalRent: (json['totalRent'] as num?)?.toDouble() ?? 2400000.0,
    splitCount: (json['splitCount'] as num?)?.toInt() ?? 2,
    splitPercentage: (json['splitPercentage'] as num?)?.toInt() ?? 50,
    location: json['location'] ?? 'Lagos, Nigeria',
    state: json['state'] ?? 'Lagos',
    bedroomType: json['bedroomType'] ?? '2 Bedroom Flat',
    moveInTimeline: json['moveInTimeline'] ?? 'Immediate',
    genderPreference: json['genderPreference'] ?? 'Any',
    lifestyleTags: (json['lifestyleTags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    imageUrls: (json['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    aboutMe: json['aboutMe'] ?? '',
    isVerified: json['isVerified'] != false,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
  );
}
