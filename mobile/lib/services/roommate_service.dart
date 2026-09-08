import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/roommate_post.dart';

class RoommateService {
  static const String _storageKey = 'rentilly_roommate_posts_v2';
  static const String _configId = 'global_roommate_posts';

  static Map<String, String> get _headers => {
        'apikey': AppConstants.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  static Future<List<RoommatePost>> getPosts() async {
    // 1. Try to fetch live posts from Supabase cloud store
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/system_configs?id=eq.$_configId&select=data'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List<dynamic> rows = json.decode(res.body);
        if (rows.isNotEmpty && rows.first['data'] is List) {
          final List<dynamic> list = rows.first['data'];
          final posts = list.map((e) => RoommatePost.fromJson(Map<String, dynamic>.from(e))).toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          // Cache locally for offline speed
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_storageKey, json.encode(list));
          return posts;
        }
      }
    } catch (_) {}

    // 2. Fallback to local cache
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    if (saved == null || saved.isEmpty) {
      return [];
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
    list.removeWhere((p) => p.id == post.id);
    list.insert(0, post);
    await savePosts(list);
  }

  static Future<void> savePosts(List<RoommatePost> list) async {
    final rawList = list.map((e) => e.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(rawList));

    // Persist to Supabase cloud store so all users see it
    try {
      await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/system_configs'),
        headers: {
          ..._headers,
          'Prefer': 'resolution=merge-duplicates',
        },
        body: json.encode({
          'id': _configId,
          'data': rawList,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}

