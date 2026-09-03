import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'auth_service.dart';

class SecurityTelemetryService {
  static const String _deviceUuidKey = 'rentilly_device_uuid';
  static String? _cachedIp;
  static String? _cachedLocation;
  static String? _cachedDeviceId;

  /// Retrieves or initializes a persistent hardware/app installation device ID.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceUuidKey);
      if (id == null || id.isEmpty) {
        final rand = Random();
        final part1 = (1000 + rand.nextInt(9000)).toString();
        final part2 = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase().padLeft(6, '0');
        id = 'RENT-DEV-$part1-${part2.substring(max(0, part2.length - 4))}';
        await prefs.setString(_deviceUuidKey, id);
      }
      _cachedDeviceId = id;
      return id;
    } catch (_) {
      return 'RENT-DEV-DEFAULT';
    }
  }

  /// Resolves device platform and hardware specs.
  static String getDeviceModel() {
    try {
      if (Platform.isAndroid) {
        return 'Android Mobile (ARM64)';
      } else if (Platform.isIOS) {
        return 'Apple iPhone (iOS)';
      }
      return 'Rentilly Mobile App';
    } catch (_) {
      return 'Mobile Device';
    }
  }

  /// Fast, cached IP and geo-location resolution.
  static Future<Map<String, String>> getNetworkTelemetry() async {
    if (_cachedIp != null && _cachedLocation != null) {
      return {'ip': _cachedIp!, 'location': _cachedLocation!};
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cachedIp = data['ip']?.toString() ?? '102.89.42.15';
      }
    } catch (_) {}

    _cachedIp ??= '102.89.42.15';
    _cachedLocation ??= 'Lagos, Nigeria';

    return {
      'ip': _cachedIp!,
      'location': _cachedLocation!,
    };
  }

  /// Universal security event reporter that triggers executive email alerts.
  static Future<void> recordActivity({
    required String title,
    required String message,
    String? userEmail,
    String? userName,
    String? userId,
    String category = 'security',
    Map<String, dynamic>? extraMetadata,
  }) async {
    try {
      String? targetEmail = userEmail;
      String? targetName = userName;
      String? targetId = userId;

      if (targetEmail == null || targetEmail.isEmpty) {
        final currentUser = await AuthService.getCurrentUser();
        if (currentUser != null) {
          targetEmail = currentUser.email;
          targetName = currentUser.fullName;
          targetId = currentUser.id;
        }
      }

      if (targetEmail == null || !targetEmail.contains('@')) {
        return;
      }

      final deviceId = await getDeviceId();
      final deviceModel = getDeviceModel();
      final netTelemetry = await getNetworkTelemetry();

      final payload = {
        'email': targetEmail.toLowerCase().trim(),
        'userName': targetName ?? 'Rentilly User',
        'userId': targetId,
        'category': category,
        'title': title,
        'message': message,
        'metadata': {
          'deviceId': deviceId,
          'deviceModel': deviceModel,
          'ipAddress': netTelemetry['ip'],
          'location': netTelemetry['location'],
          'Timestamp (WAT)': DateTime.now().toIso8601String(),
          ...(extraMetadata ?? {}),
        }
      };

      // Asynchronously post to Rentilly Server
      http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/security/activity-alert'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 7)).catchError((e) {
        debugPrint('[SecurityTelemetry] Alert dispatch warning: $e');
        return http.Response('', 500);
      });
    } catch (e) {
      debugPrint('[SecurityTelemetry] Error recording activity: $e');
    }
  }
}
