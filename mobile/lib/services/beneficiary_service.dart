import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';

class BeneficiaryService {
  static const String _storagePrefix = 'rentilly_beneficiaries_v2_';

  /// Returns normalized storage key for a user
  static String _getKey(String email) {
    return '$_storagePrefix${email.trim().toLowerCase()}';
  }

  /// Sanitizes a beneficiary object to ensure it is valid and verified
  static bool _isValidBeneficiary(Map<String, dynamic> b) {
    final type = (b['type'] ?? 'bank').toString();
    if (type == 'crypto') {
      final cryptoAddr = (b['cryptoAddress'] ?? '').toString().trim();
      return cryptoAddr.length >= 20;
    }

    final acc = (b['accountNumber'] ?? '').toString().trim();
    final bankName = (b['bankName'] ?? '').toString().trim();
    final bankCode = (b['bankCode'] ?? '').toString().trim();

    // Must have 10-digit Nigerian NUBAN account
    if (acc.length != 10 || !RegExp(r'^\d{10}$').hasMatch(acc)) return false;

    // Must have actual verified bank name and valid bank code
    if (bankName.isEmpty || bankName.toLowerCase() == 'nigerian bank') return false;
    if (bankCode.isEmpty || bankCode == 'undefined' || bankCode == 'null') return false;

    return true;
  }

  /// Get all verified saved beneficiaries for a user
  static Future<List<Map<String, dynamic>>> getBeneficiaries({String? userEmail}) async {
    try {
      final email = userEmail?.trim().toLowerCase() ?? 
          (await AuthService.getCurrentUser())?.email.trim().toLowerCase() ?? '';

      if (email.isEmpty) return [];

      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(email);

      // Also clean up any legacy corrupted v1 storage
      final legacyKey = 'rentilly_beneficiaries_$email';
      if (prefs.containsKey(legacyKey)) {
        await prefs.remove(legacyKey);
      }

      final rawJson = prefs.getString(key);
      Map<String, Map<String, dynamic>> deduped = {};

      // 1. Ingest locally saved beneficiaries (strictly validated)
      if (rawJson != null && rawJson.isNotEmpty) {
        try {
          final decoded = json.decode(rawJson);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                if (_isValidBeneficiary(m)) {
                  final isCrypto = m['type'] == 'crypto';
                  final dedupeKey = isCrypto 
                      ? 'crypto_${(m['cryptoAddress'] ?? '').toString().toLowerCase()}'
                      : '${m['accountNumber']}_${m['bankCode']}';
                  deduped[dedupeKey] = m;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[BeneficiaryService] Error decoding saved beneficiaries: $e');
        }
      }

      // 2. Fetch authoritative beneficiaries from Server
      try {
        final benUrl = Uri.parse('${AppConstants.apiBaseUrl}/payments/beneficiaries?email=${Uri.encodeComponent(email)}');
        final benRes = await http.get(benUrl).timeout(const Duration(seconds: 5));
        if (benRes.statusCode == 200) {
          final benJson = json.decode(benRes.body);
          if (benJson['status'] == true && benJson['data'] is List) {
            for (final item in benJson['data']) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                if (_isValidBeneficiary(m)) {
                  final isCrypto = m['type'] == 'crypto';
                  final dedupeKey = isCrypto 
                      ? 'crypto_${(m['cryptoAddress'] ?? '').toString().toLowerCase()}'
                      : '${m['accountNumber']}_${m['bankCode']}';
                  
                  if (deduped.containsKey(dedupeKey)) {
                    final existing = deduped[dedupeKey]!;
                    deduped[dedupeKey] = {
                      ...existing,
                      ...m,
                      'useCount': ((existing['useCount'] as num?)?.toInt() ?? 1) + 
                                  ((m['useCount'] as num?)?.toInt() ?? 1),
                    };
                  } else {
                    deduped[dedupeKey] = m;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[BeneficiaryService] Remote beneficiaries sync warning: $e');
      }

      final result = deduped.values.toList();

      // Sort by lastUsed descending
      result.sort((a, b) {
        final dateA = DateTime.tryParse(a['lastUsed']?.toString() ?? '') ?? DateTime(2020);
        final dateB = DateTime.tryParse(b['lastUsed']?.toString() ?? '') ?? DateTime(2020);
        return dateB.compareTo(dateA);
      });

      // Persist clean beneficiaries locally
      await prefs.setString(key, json.encode(result.take(50).toList()));

      return result;
    } catch (e) {
      debugPrint('[BeneficiaryService] getBeneficiaries error: $e');
      return [];
    }
  }

  /// Saves or updates a verified beneficiary locally and to server
  static Future<bool> saveBeneficiary({
    required String userEmail,
    required String accountName,
    required String accountNumber,
    required String bankName,
    required String bankCode,
    String type = 'bank',
    String? cryptoAddress,
  }) async {
    try {
      final cleanEmail = userEmail.trim().toLowerCase();
      if (cleanEmail.isEmpty) return false;

      final cleanAcc = accountNumber.trim();
      final cleanBankName = bankName.trim();
      final cleanBankCode = bankCode.trim();
      final cleanCrypto = cryptoAddress?.trim() ?? '';
      final isCrypto = type == 'crypto';

      // Strict validation: never save unverified, guessed, or fallback banks
      if (!isCrypto) {
        if (cleanAcc.length != 10 || !RegExp(r'^\d{10}$').hasMatch(cleanAcc)) return false;
        if (cleanBankName.isEmpty || cleanBankName.toLowerCase() == 'nigerian bank') return false;
        if (cleanBankCode.isEmpty || cleanBankCode == 'undefined' || cleanBankCode == 'null') return false;
      } else {
        if (cleanCrypto.length < 20) return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(cleanEmail);
      final list = await getBeneficiaries(userEmail: cleanEmail);

      int existingIdx = -1;
      if (isCrypto) {
        existingIdx = list.indexWhere((b) => 
            b['type'] == 'crypto' && (b['cryptoAddress'] ?? '').toString().toLowerCase() == cleanCrypto.toLowerCase());
      } else {
        existingIdx = list.indexWhere((b) => 
            b['accountNumber'] == cleanAcc && b['bankCode'] == cleanBankCode);
      }

      final nowIso = DateTime.now().toIso8601String();

      final updatedEntry = {
        'accountName': accountName.trim(),
        'accountNumber': cleanAcc,
        'bankName': cleanBankName,
        'bankCode': cleanBankCode,
        'type': isCrypto ? 'crypto' : 'bank',
        'lastUsed': nowIso,
        'useCount': existingIdx >= 0 ? ((list[existingIdx]['useCount'] as num?)?.toInt() ?? 1) + 1 : 1,
        if (isCrypto) 'cryptoAddress': cleanCrypto,
      };

      if (existingIdx >= 0) {
        list[existingIdx] = updatedEntry;
      } else {
        list.insert(0, updatedEntry);
      }

      final trimmed = list.take(50).toList();
      await prefs.setString(key, json.encode(trimmed));

      // Push to server
      try {
        final url = Uri.parse('${AppConstants.apiBaseUrl}/payments/beneficiaries');
        http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': cleanEmail,
            'accountName': accountName.trim(),
            'accountNumber': cleanAcc,
            'bankName': cleanBankName,
            'bankCode': cleanBankCode,
            'type': isCrypto ? 'crypto' : 'bank',
            if (isCrypto) 'cryptoAddress': cleanCrypto,
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[BeneficiaryService] saveBeneficiary error: $e');
      return false;
    }
  }

  /// Deletes a saved beneficiary locally and on the server
  static Future<bool> deleteBeneficiary({
    required String userEmail,
    required String accountNumber,
    required String bankCode,
    String? cryptoAddress,
  }) async {
    try {
      final cleanEmail = userEmail.trim().toLowerCase();
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(cleanEmail);
      final list = await getBeneficiaries(userEmail: cleanEmail);

      final cleanAcc = accountNumber.trim();
      final cleanBankCode = bankCode.trim();
      final cleanCrypto = cryptoAddress?.trim().toLowerCase() ?? '';

      list.removeWhere((b) {
        if (b['type'] == 'crypto' && cleanCrypto.isNotEmpty) {
          return (b['cryptoAddress'] ?? '').toString().toLowerCase() == cleanCrypto;
        }
        return b['accountNumber'] == cleanAcc && b['bankCode'] == cleanBankCode;
      });

      await prefs.setString(key, json.encode(list));

      // Call server DELETE
      try {
        final uri = Uri.parse('${AppConstants.apiBaseUrl}/payments/beneficiaries').replace(queryParameters: {
          'email': cleanEmail,
          'accountNumber': cleanAcc,
          'bankCode': cleanBankCode,
          if (cleanCrypto.isNotEmpty) 'cryptoAddress': cleanCrypto,
        });
        await http.delete(uri).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[BeneficiaryService] Remote delete warning: $e');
      }

      return true;
    } catch (e) {
      debugPrint('[BeneficiaryService] deleteBeneficiary error: $e');
      return false;
    }
  }

  /// Search beneficiaries by name, bank name, or account number
  static List<Map<String, dynamic>> search(String query, List<Map<String, dynamic>> all) {
    if (query.trim().isEmpty) return all;
    final q = query.trim().toLowerCase();
    return all.where((b) {
      final name = (b['accountName'] ?? '').toString().toLowerCase();
      final bank = (b['bankName'] ?? '').toString().toLowerCase();
      final acc = (b['accountNumber'] ?? '').toString().toLowerCase();
      final crypto = (b['cryptoAddress'] ?? '').toString().toLowerCase();
      return name.contains(q) || bank.contains(q) || acc.contains(q) || crypto.contains(q);
    }).toList();
  }
}
