import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class BeneficiaryService {
  static const String _storagePrefix = 'rentilly_beneficiaries_';

  /// Returns normalized storage key for a user
  static String _getKey(String email) {
    return '$_storagePrefix${email.trim().toLowerCase()}';
  }

  /// Get all saved beneficiaries for a user, automatically merged with past transaction recipients
  static Future<List<Map<String, dynamic>>> getBeneficiaries({String? userEmail}) async {
    try {
      final email = userEmail?.trim().toLowerCase() ?? 
          (await AuthService.getCurrentUser())?.email.trim().toLowerCase() ?? '';

      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(email);
      final rawJson = prefs.getString(key);

      List<Map<String, dynamic>> savedList = [];
      if (rawJson != null && rawJson.isNotEmpty) {
        try {
          final decoded = json.decode(rawJson);
          if (decoded is List) {
            savedList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        } catch (e) {
          debugPrint('[BeneficiaryService] Error decoding saved beneficiaries: $e');
        }
      }

      // Also scan cached transactions to mine any past recipients that were not yet in the list
      final cachedTxJson = prefs.getString('rentilly_cached_tx_$email');
      if (cachedTxJson != null && cachedTxJson.isNotEmpty) {
        try {
          final decodedTx = json.decode(cachedTxJson);
          if (decodedTx is List) {
            for (final tx in decodedTx) {
              final bName = tx['beneficiary'] ?? tx['recipient'];
              final accNum = tx['accountNumber'];
              final bBank = tx['bankName'];
              final isWithdrawal = tx['category'] == 'withdrawal' || 
                  (tx['title'] != null && tx['title'].toString().toLowerCase().contains('withdrawal')) ||
                  (tx['subtitle'] != null && tx['subtitle'].toString().toLowerCase().contains('to:'));

              if (isWithdrawal && bName != null && bName.toString().trim().isNotEmpty && 
                  accNum != null && accNum.toString().trim().length == 10) {
                final cleanName = bName.toString().trim();
                final cleanAcc = accNum.toString().trim();
                final cleanBank = (bBank != null && bBank.toString().trim().isNotEmpty) 
                    ? bBank.toString().trim() 
                    : 'Nigerian Bank';

                // Check if already in savedList
                final existingIndex = savedList.indexWhere((b) => 
                    b['accountNumber'] == cleanAcc && 
                    (b['bankName'] == cleanBank || b['bankCode'] != null));

                if (existingIndex == -1) {
                  savedList.add({
                    'accountName': cleanName,
                    'accountNumber': cleanAcc,
                    'bankName': cleanBank,
                    'bankCode': tx['bankCode'] ?? _guessBankCode(cleanBank),
                    'type': 'bank',
                    'lastUsed': tx['createdAt'] ?? tx['date'] ?? DateTime.now().toIso8601String(),
                    'useCount': 1,
                  });
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[BeneficiaryService] Error mining cached transactions: $e');
        }
      }

      // Sort by lastUsed descending
      savedList.sort((a, b) {
        final dateA = DateTime.tryParse(a['lastUsed']?.toString() ?? '') ?? DateTime(2020);
        final dateB = DateTime.tryParse(b['lastUsed']?.toString() ?? '') ?? DateTime(2020);
        return dateB.compareTo(dateA);
      });

      return savedList;
    } catch (e) {
      debugPrint('[BeneficiaryService] getBeneficiaries error: $e');
      return [];
    }
  }

  /// Saves or updates a beneficiary
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

      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(cleanEmail);
      final list = await getBeneficiaries(userEmail: cleanEmail);

      final cleanAcc = accountNumber.trim();
      final cleanBankCode = bankCode.trim();
      final cleanCrypto = cryptoAddress?.trim() ?? '';

      int existingIdx = -1;
      if (type == 'crypto') {
        existingIdx = list.indexWhere((b) => 
            b['type'] == 'crypto' && b['cryptoAddress'] == cleanCrypto);
      } else {
        existingIdx = list.indexWhere((b) => 
            b['accountNumber'] == cleanAcc && b['bankCode'] == cleanBankCode);
      }

      final nowIso = DateTime.now().toIso8601String();

      if (existingIdx >= 0) {
        // Update existing beneficiary
        final current = list[existingIdx];
        final currentCount = (current['useCount'] as num?)?.toInt() ?? 1;
        list[existingIdx] = {
          ...current,
          'accountName': accountName.trim(),
          'bankName': bankName.trim(),
          'bankCode': cleanBankCode,
          'lastUsed': nowIso,
          'useCount': currentCount + 1,
          if (cryptoAddress != null) 'cryptoAddress': cleanCrypto,
        };
      } else {
        // Add new beneficiary at top
        list.insert(0, {
          'accountName': accountName.trim(),
          'accountNumber': cleanAcc,
          'bankName': bankName.trim(),
          'bankCode': cleanBankCode,
          'type': type,
          'lastUsed': nowIso,
          'useCount': 1,
          if (cryptoAddress != null) 'cryptoAddress': cleanCrypto,
        });
      }

      // Limit to 50 saved beneficiaries
      final trimmed = list.take(50).toList();
      await prefs.setString(key, json.encode(trimmed));
      return true;
    } catch (e) {
      debugPrint('[BeneficiaryService] saveBeneficiary error: $e');
      return false;
    }
  }

  /// Deletes a saved beneficiary
  static Future<bool> deleteBeneficiary({
    required String userEmail,
    required String accountNumber,
    required String bankCode,
  }) async {
    try {
      final cleanEmail = userEmail.trim().toLowerCase();
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(cleanEmail);
      final list = await getBeneficiaries(userEmail: cleanEmail);

      list.removeWhere((b) => 
          b['accountNumber'] == accountNumber.trim() && 
          b['bankCode'] == bankCode.trim());

      await prefs.setString(key, json.encode(list));
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

  /// Helper to guess bank code from standard Nigerian bank names
  static String _guessBankCode(String bankName) {
    final bn = bankName.toLowerCase();
    if (bn.contains('guaranty') || bn.contains('gtb')) return '058';
    if (bn.contains('zenith')) return '057';
    if (bn.contains('access')) return '044';
    if (bn.contains('first bank')) return '011';
    if (bn.contains('uba') || bn.contains('united bank')) return '033';
    if (bn.contains('kuda')) return '50211';
    if (bn.contains('opay')) return '999992';
    if (bn.contains('palmpay')) return '999991';
    if (bn.contains('wema')) return '035';
    if (bn.contains('providus')) return '101';
    if (bn.contains('fidelity')) return '070';
    if (bn.contains('stanbic')) return '221';
    if (bn.contains('moniepoint')) return '50515';
    if (bn.contains('sterling')) return '232';
    if (bn.contains('union')) return '032';
    if (bn.contains('ecobank')) return '050';
    if (bn.contains('fcmb')) return '214';
    if (bn.contains('polaris')) return '076';
    if (bn.contains('vfd')) return '566';
    if (bn.contains('jaiz')) return '301';
    if (bn.contains('taj')) return '302';
    return '058'; // Default
  }
}
