import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/roommate_post.dart';

class RoommateService {
  static const String _storageKey = 'rentilly_roommate_posts_v2';

  static Future<List<RoommatePost>> getPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    if (saved == null || saved.isEmpty) {
      return []; // No dummy data!
    }

    try {
      final List<dynamic> decoded = json.decode(saved);
      final list = decoded.map((e) => RoommatePost.fromJson(Map<String, dynamic>.from(e))).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
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
