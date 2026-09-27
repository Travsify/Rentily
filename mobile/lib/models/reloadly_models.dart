class ReloadlyBiller {
  final int id;
  final String name;
  final String type; // 'ELECTRICITY_BILL_PAYMENT', 'TV_BILL_PAYMENT', etc.
  final String serviceType; // 'PREPAID', 'POSTPAID'
  final String countryCode;
  final double? minLocalAmount;
  final double? maxLocalAmount;

  ReloadlyBiller({
    required this.id,
    required this.name,
    required this.type,
    required this.serviceType,
    required this.countryCode,
    this.minLocalAmount,
    this.maxLocalAmount,
  });

  factory ReloadlyBiller.fromJson(Map<String, dynamic> json) {
    return ReloadlyBiller(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Utility Provider',
      type: json['type']?.toString() ?? 'ELECTRICITY_BILL_PAYMENT',
      serviceType: json['serviceType']?.toString().toUpperCase() ?? 'PREPAID',
      countryCode: json['countryCode']?.toString() ?? 'NG',
      minLocalAmount: (json['minLocalAmount'] as num?)?.toDouble(),
      maxLocalAmount: (json['maxLocalAmount'] as num?)?.toDouble(),
    );
  }
}

class MeterValidationResult {
  final bool isValid;
  final String? customerName;
  final String? address;
  final String? meterNumber;
  final String? billerName;
  final double? minAmount;

  MeterValidationResult({
    required this.isValid,
    this.customerName,
    this.address,
    this.meterNumber,
    this.billerName,
    this.minAmount,
  });

  factory MeterValidationResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return MeterValidationResult(
      isValid: true,
      customerName: data['customerName'] ?? data['subscriberName'] ?? data['name'] ?? 'Verified Customer',
      address: data['address'] ?? data['serviceAddress'] ?? 'Property Location, Nigeria',
      meterNumber: data['accountNumber']?.toString(),
      billerName: data['billerName']?.toString(),
      minAmount: (data['minAmount'] as num?)?.toDouble(),
    );
  }
}

class ReloadlyCountry {
  final String code;
  final String name;
  final String flag;
  final String prefix;
  final String currencyCode;

  ReloadlyCountry({
    required this.code,
    required this.name,
    required this.flag,
    required this.prefix,
    required this.currencyCode,
  });

  factory ReloadlyCountry.fromJson(Map<String, dynamic> json) {
    return ReloadlyCountry(
      code: (json['code'] ?? json['isoName'] ?? '').toString().toUpperCase(),
      name: (json['name'] ?? '').toString(),
      flag: (json['flag'] ?? '🌐').toString(),
      prefix: (json['prefix'] ?? json['callingCode'] ?? '').toString(),
      currencyCode: (json['currencyCode'] ?? 'USD').toString(),
    );
  }
}

class ReloadlyProduct {
  final int productId;
  final String productName;
  final bool global;
  final String brandName;
  final String logoUrl;
  final String categoryName;
  final String countryName;
  final String countryIso;
  final String currencyCode;
  final String denominationType; // 'FIXED' or 'RANGE'
  final List<double> fixedDenominations;
  final List<double> suggestedDenominations;
  final double? minDenomination;
  final double? maxDenomination;
  final double discountPercentage;
  final String brandColorHex;
  final String redeemInstructions;

  bool get isRange => denominationType.toUpperCase() == 'RANGE' || fixedDenominations.isEmpty;

  ReloadlyProduct({
    required this.productId,
    required this.productName,
    required this.global,
    required this.brandName,
    required this.logoUrl,
    required this.categoryName,
    required this.countryName,
    required this.countryIso,
    required this.currencyCode,
    required this.denominationType,
    required this.fixedDenominations,
    required this.suggestedDenominations,
    this.minDenomination,
    this.maxDenomination,
    this.discountPercentage = 0.0,
    required this.brandColorHex,
    required this.redeemInstructions,
  });

  static String sanitizeLogoUrl(String url, String brandName, String productName) {
    final lower = '$brandName $productName'.toLowerCase();
    if (lower.contains('amazon')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Amazon_logo.svg/320px-Amazon_logo.svg.png';
    if (lower.contains('apple') || lower.contains('itunes')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/320px-Apple_logo_black.svg.png';
    if (lower.contains('google') || lower.contains('play')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Google_Play_Arrow_logo.svg/320px-Google_Play_Arrow_logo.svg.png';
    if (lower.contains('steam')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/Steam_icon_logo.svg/320px-Steam_icon_logo.svg.png';
    if (lower.contains('netflix')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Netflix_2015_logo.svg/320px-Netflix_2015_logo.svg.png';
    if (lower.contains('playstation') || lower.contains('psn')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Playstation_logo_colour.svg/320px-Playstation_logo_colour.svg.png';
    if (lower.contains('spotify')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Spotify_logo_without_text.svg/320px-Spotify_logo_without_text.svg.png';
    if (lower.contains('razer')) return 'https://upload.wikimedia.org/wikipedia/en/thumb/4/40/Razer_Snake_Logo.svg/200px-Razer_Snake_Logo.svg.png';
    if (lower.contains('binance')) return 'https://cryptologos.cc/logos/binance-coin-bnb-logo.png';
    if (lower.contains('tether') || lower.contains('usdt')) return 'https://cryptologos.cc/logos/tether-usdt-logo.png';
    if (lower.contains('crypto') || lower.contains('bitcoin') || lower.contains('bitnovo')) return 'https://cryptologos.cc/logos/bitcoin-btc-logo.png';
    if (lower.contains('airalo') || lower.contains('esim')) return 'https://cdn.reloadly.com/giftcards/062c086f-b77d-427a-92fa-a1078f31f603.png';
    if (lower.contains('xbox')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Xbox_logo_%282019%29.svg/320px-Xbox_logo_%282019%29.svg.png';
    if (lower.contains('uber')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Uber_logo_2018.png/320px-Uber_logo_2018.png';
    if (lower.contains('airbnb')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Airbnb_Logo_B%C3%A9lo.svg/320px-Airbnb_Logo_B%C3%A9lo.svg.png';
    if (lower.contains('walmart')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Walmart_Spark.svg/320px-Walmart_Spark.svg.png';
    if (lower.contains('ebay')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/EBay_logo.svg/320px-EBay_logo.svg.png';
    if (lower.contains('starbucks')) return 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d3/Starbucks_Corporation_Logo_2011.svg/320px-Starbucks_Corporation_Logo_2011.svg.png';
    if (lower.contains('nike')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Logo_NIKE.svg/320px-Logo_NIKE.svg.png';

    if (url.isEmpty) return '';
    if (url.endsWith('.svg') && url.contains('wikimedia.org')) {
      final filename = url.split('/').last;
      return '${url.replaceFirst('/commons/', '/commons/thumb/')}/320px-$filename.png';
    }
    return url;
  }

  static String getBrandColor(String brandName, String productName) {
    final lower = '$brandName $productName'.toLowerCase();
    if (lower.contains('amazon')) return '0xFFFF9900';
    if (lower.contains('apple')) return '0xFF1E293B';
    if (lower.contains('google')) return '0xFF01875F';
    if (lower.contains('steam')) return '0xFF171A21';
    if (lower.contains('netflix')) return '0xFFE50914';
    if (lower.contains('playstation') || lower.contains('psn')) return '0xFF003791';
    if (lower.contains('spotify')) return '0xFF1DB954';
    if (lower.contains('razer')) return '0xFF00E700';
    if (lower.contains('binance')) return '0xFFF3BA2F';
    if (lower.contains('bitcoin')) return '0xFFF7931A';
    if (lower.contains('tether') || lower.contains('usdt')) return '0xFF26A17B';
    if (lower.contains('crypto')) return '0xFF2563EB';
    if (lower.contains('airalo') || lower.contains('esim')) return '0xFFF59E0B';
    if (lower.contains('uber')) return '0xFF000000';
    if (lower.contains('airbnb')) return '0xFFFF5A5F';
    if (lower.contains('xbox')) return '0xFF107C10';
    return '0xFF0284C7';
  }

  factory ReloadlyProduct.fromJson(Map<String, dynamic> json) {
    final fixedList = <double>[];
    if (json['fixedRecipientDenominations'] is List) {
      for (final item in json['fixedRecipientDenominations']) {
        if (item is num) fixedList.add(item.toDouble());
      }
    } else if (json['fixedSenderDenominations'] is List) {
      for (final item in json['fixedSenderDenominations']) {
        if (item is num) fixedList.add(item.toDouble());
      }
    } else if (json['fixedDenominations'] is List) {
      for (final item in json['fixedDenominations']) {
        if (item is num) fixedList.add(item.toDouble());
      }
    }

    final brand = json['brand'] is Map ? json['brand'] : {};
    final cat = json['category'] is Map ? json['category'] : {};
    final country = json['country'] is Map ? json['country'] : {};
    final instructions = json['redeemInstruction'] is Map
        ? (json['redeemInstruction']['concise'] ?? json['redeemInstruction']['verbose'] ?? '')
        : (json['redeemInstructions']?.toString() ?? '');

    String rawLogo = '';
    if (json['logoUrls'] is List && (json['logoUrls'] as List).isNotEmpty) {
      rawLogo = json['logoUrls'][0].toString();
    } else if (brand['logoUrl'] != null) {
      rawLogo = brand['logoUrl'].toString();
    } else if (json['logoUrl'] != null) {
      rawLogo = json['logoUrl'].toString();
    }

    final brandName = brand['brandName']?.toString() ?? json['brandName']?.toString() ?? json['productName']?.toString() ?? 'Brand';
    final productName = json['productName']?.toString() ?? 'Digital Voucher';
    final cleanLogo = sanitizeLogoUrl(rawLogo, brandName, productName);
    final brandColor = json['brandColorHex']?.toString() ?? getBrandColor(brandName, productName);

    final minDenom = (json['minRecipientDenomination'] ?? json['minSenderDenomination'] ?? json['minDenomination'] as num?)?.toDouble();
    final maxDenom = (json['maxRecipientDenomination'] ?? json['maxSenderDenomination'] ?? json['maxDenomination'] as num?)?.toDouble();

    final suggested = <double>[];
    if (json['suggestedDenominations'] is List && (json['suggestedDenominations'] as List).isNotEmpty) {
      for (final item in json['suggestedDenominations']) {
        if (item is num) suggested.add(item.toDouble());
      }
    } else if (fixedList.isNotEmpty) {
      suggested.addAll(fixedList);
    } else {
      final min = minDenom ?? 5.0;
      final max = maxDenom ?? 500.0;
      final presets = [10.0, 25.0, 50.0, 100.0, 200.0, 500.0];
      for (final p in presets) {
        if (p >= min && p <= max) suggested.add(p);
      }
      if (suggested.isEmpty) {
        suggested.add(min);
        if (max > min) suggested.add(((min + max) / 2).roundToDouble());
        if (max > min) suggested.add(max);
      }
    }

    return ReloadlyProduct(
      productId: json['productId'] is int ? json['productId'] : int.tryParse(json['productId']?.toString() ?? '0') ?? 0,
      productName: productName,
      global: json['global'] == true,
      brandName: brandName,
      logoUrl: cleanLogo,
      categoryName: cat['name']?.toString() ?? json['categoryName']?.toString() ?? 'Gift Card',
      countryName: country['name']?.toString() ?? json['countryName']?.toString() ?? 'Global',
      countryIso: country['isoName']?.toString() ?? json['countryIso']?.toString() ?? 'US',
      currencyCode: json['recipientCurrencyCode']?.toString() ?? json['currencyCode']?.toString() ?? 'USD',
      denominationType: json['denominationType']?.toString().toUpperCase() ?? (fixedList.isNotEmpty ? 'FIXED' : 'RANGE'),
      fixedDenominations: fixedList,
      suggestedDenominations: suggested,
      minDenomination: minDenom,
      maxDenomination: maxDenom,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      brandColorHex: brandColor,
      redeemInstructions: instructions.toString(),
    );
  }
}

class ReloadlyVoucherRecord {
  final String id;
  final String? transactionId;
  final String productName;
  final double amountUsd;
  final double amountNgn;
  final String? cardNumber;
  final String? pinCode;
  final String? claimUrl;
  final String createdAt;

  ReloadlyVoucherRecord({
    required this.id,
    this.transactionId,
    required this.productName,
    required this.amountUsd,
    required this.amountNgn,
    this.cardNumber,
    this.pinCode,
    this.claimUrl,
    required this.createdAt,
  });

  factory ReloadlyVoucherRecord.fromJson(Map<String, dynamic> json) {
    String? cardNum = json['cardNumber']?.toString() ?? json['cardNumberText']?.toString();
    String? pin = json['pinCode']?.toString() ?? json['pin']?.toString();
    String? url = json['claimUrl']?.toString() ?? json['redemptionUrl']?.toString();

    if (json['cards'] is List && (json['cards'] as List).isNotEmpty) {
      final first = json['cards'][0];
      if (first is Map) {
        cardNum = first['cardNumber']?.toString() ?? first['cardNumberText']?.toString() ?? cardNum;
        pin = first['pinCode']?.toString() ?? first['pin']?.toString() ?? pin;
        url = first['redemptionUrl']?.toString() ?? first['claimUrl']?.toString() ?? url;
      }
    }

    return ReloadlyVoucherRecord(
      id: json['id']?.toString() ?? 'RLD_VOUCHER',
      transactionId: json['transactionId']?.toString(),
      productName: json['productName']?.toString() ?? 'Digital Card',
      amountUsd: (json['unitPriceUsd'] ?? json['totalUsd'] ?? json['amount_usd'] as num?)?.toDouble() ?? 0.0,
      amountNgn: (json['totalNgn'] ?? json['amount_ngn'] as num?)?.toDouble() ?? 0.0,
      cardNumber: cardNum,
      pinCode: pin,
      claimUrl: url,
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}
