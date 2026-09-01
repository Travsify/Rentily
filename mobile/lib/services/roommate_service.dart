import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/roommate_post.dart';

class RoommateService {
  static const String _storageKey = 'rentilly_roommate_posts_v1';

  static List<RoommatePost> getInitialSeeds() {
    return [
      RoommatePost(
        id: 'ROOM_001',
        userId: 'USR_LEKKI_01',
        userName: 'Tunde Adeleke',
        userAvatar: 'TA',
        userOccupation: 'Senior Fintech Engineer (Remote)',
        postType: 'have_room',
        budgetShare: 1400000.0,
        totalRent: 2800000.0,
        splitPercentage: 50,
        location: 'Freedom Way, Lekki Phase 1',
        state: 'Lagos',
        bedroomType: '2-Bedroom Serviced Apartment (Ensuite)',
        moveInTimeline: 'Immediate (Nov 2026)',
        genderPreference: 'Male Only',
        lifestyleTags: ['Remote Worker', 'Non-Smoker', 'Quiet / Introvert', '24/7 Power', 'Gym Access'],
        imageUrls: [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
        ],
        aboutMe: 'Working full-time remote in software. Looking for a neat, responsible professional to take the master ensuite room. Serviced with 24/7 solar + estate gen.',
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      RoommatePost(
        id: 'ROOM_002',
        userId: 'USR_YABA_02',
        userName: 'Amina Bello',
        userAvatar: 'AB',
        userOccupation: 'Brand Strategist & UX Writer',
        postType: 'need_room',
        budgetShare: 950000.0,
        totalRent: 1900000.0,
        splitPercentage: 50,
        location: 'Alagomeji, Yaba Tech District',
        state: 'Lagos',
        bedroomType: '2-Bedroom Modern Flat',
        moveInTimeline: 'Within 30 Days',
        genderPreference: 'Female Only',
        lifestyleTags: ['Hybrid Work', 'Early Bird', 'Clean & Organized', 'Foodie / Baker', 'No Loud Parties'],
        imageUrls: [
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
          'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800',
        ],
        aboutMe: 'Seeking a female professional or founder to co-rent a 2-bedroom space in Yaba. Very clean, respect personal boundaries, and love cooking on weekends.',
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      RoommatePost(
        id: 'ROOM_003',
        userId: 'USR_ABUJA_03',
        userName: 'Emeka Nwosu',
        userAvatar: 'EN',
        userOccupation: 'Consultant & Real Estate Analyst',
        postType: 'have_room',
        budgetShare: 1750000.0,
        totalRent: 3500000.0,
        splitPercentage: 50,
        location: 'Wuse 2, Abuja (FCT)',
        state: 'Abuja',
        bedroomType: '3-Bedroom Luxury Penthouse',
        moveInTimeline: 'Flexible (Dec 2026)',
        genderPreference: 'Any',
        lifestyleTags: ['Corporate 9-to-5', 'Fitness & Running', 'Non-Smoker', 'High Security Estate', 'Fiber Internet'],
        imageUrls: [
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
          'https://images.unsplash.com/photo-1600565193348-f74bd3c7ccdf?w=800',
        ],
        aboutMe: 'Have an expansive penthouse in Wuse 2. The second bedroom is fully furnished with a private balcony. Looking for a career-focused flatmate.',
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      RoommatePost(
        id: 'ROOM_004',
        userId: 'USR_IKEJA_04',
        userName: 'Zainab Danjuma',
        userAvatar: 'ZD',
        userOccupation: 'Data Scientist & AI Researcher',
        postType: 'need_room',
        budgetShare: 1100000.0,
        totalRent: 2200000.0,
        splitPercentage: 50,
        location: 'Ikeja GRA / Maryland',
        state: 'Lagos',
        bedroomType: '2-Bedroom Gated Estate Flat',
        moveInTimeline: 'Immediate',
        genderPreference: 'Female Only',
        lifestyleTags: ['Remote Tech', 'Night Owl', 'Pet Friendly', 'Peace & Quiet', 'Zero Drama'],
        imageUrls: [
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
          'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800',
        ],
        aboutMe: 'Looking to buddy-up and split a secured 2-bedroom apartment around Ikeja GRA. Peaceful environment, good security, and reliable internet are top priorities.',
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  static Future<List<RoommatePost>> getPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    if (saved == null || saved.isEmpty) {
      final seeds = getInitialSeeds();
      await savePosts(seeds);
      return seeds;
    }

    try {
      final List<dynamic> decoded = json.decode(saved);
      final list = decoded.map((e) => RoommatePost.fromJson(Map<String, dynamic>.from(e))).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return getInitialSeeds();
    }
  }

  static Future<void> addPost(RoommatePost post) async {
    final list = await getPosts();
    list.insert(0, post);
    await savePosts(list);
  }

  static Future<void> savePosts(List<RoommatePost> list) async {
    final prefs = await SharedPreferences.getInstance();
    final str = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, str);
  }
}
