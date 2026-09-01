class Property {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final String title;
  final String description;
  final String purpose; // 'rent' | 'sale'
  final String propertyType;
  final double basePrice;
  final double cautionFee;
  final double serviceCharge;
  final double rentillyFee;
  final double totalInitialPayment;
  final String paymentFrequency;
  final String address;
  final String state;
  final String lga;
  final String neighborhood;
  final int bedrooms;
  final int bathrooms;
  final int toilets;
  final String furnishing;
  final List<String> amenities;
  final List<String> images;
  final String? videoWalkthroughUrl;
  final String status; // 'active', 'under_escrow', 'leased', 'sold'
  final String? verifiedAt;

  // Partner Governance & Anti-Ghost Verification (Admin-Only)
  final String listedByRole; // 'direct_landlord' | 'verified_partner'
  final String? partnerId;
  final String? partnerName;
  final double partnerCommissionRate; // 0.025 (2.5%) for rent, 0.01 (1.0%) for sale
  final String? partnerPresencePhotoUrl; // Partner selfie inside property (Admin-only)
  final String? powerOfAttorneyUrl; // Mandate document from landlord (Admin-only)
  final double inspectionFee; // System max: ₦5,000
  final Map<String, double>? serviceChargeBreakdown;
  final bool serviceChargeConfirmedByTenant;
  final String? propertyAddressHash;

  Property({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.title,
    required this.description,
    required this.purpose,
    required this.propertyType,
    required this.basePrice,
    required this.cautionFee,
    required this.serviceCharge,
    required this.rentillyFee,
    required this.totalInitialPayment,
    required this.paymentFrequency,
    required this.address,
    required this.state,
    required this.lga,
    required this.neighborhood,
    required this.bedrooms,
    required this.bathrooms,
    required this.toilets,
    required this.furnishing,
    required this.amenities,
    required this.images,
    this.videoWalkthroughUrl,
    required this.status,
    this.verifiedAt,
    this.listedByRole = 'direct_landlord',
    this.partnerId,
    this.partnerName,
    this.partnerCommissionRate = 0.025,
    this.partnerPresencePhotoUrl,
    this.powerOfAttorneyUrl,
    this.inspectionFee = 3000.0,
    this.serviceChargeBreakdown,
    this.serviceChargeConfirmedByTenant = false,
    this.propertyAddressHash,
  });

  // Calculate traditional agent fee that Nigerians usually get charged (20% on rent, 10% on sales)
  double get traditionalAgentCommission {
    return purpose == 'rent' ? basePrice * 0.20 : basePrice * 0.10;
  }

  // Calculate net money saved by the user on Rentilly
  double get totalNairaSavedOnRentilly {
    return traditionalAgentCommission - rentillyFee;
  }

  // Partner commission payout amount
  double get partnerCommissionPayout {
    if (listedByRole != 'verified_partner') return 0.0;
    return purpose == 'rent' ? basePrice * 0.025 : basePrice * 0.02; // 2.5% for rent, 2.0% for sale
  }

  // Seller / Landlord commission fee on sales (5% total)
  double get sellerSalesCommission {
    return purpose == 'sale' ? basePrice * 0.05 : 0.0;
  }

  // Buyer legal & title documentation fee on sales (5% total to legal)
  double get buyerSalesLegalFee {
    return purpose == 'sale' ? basePrice * 0.05 : 0.0;
  }

  // Platform net commission share
  double get platformCommissionPayout {
    if (purpose == 'sale') {
      return listedByRole == 'verified_partner' ? basePrice * 0.03 : basePrice * 0.05; // 3% if partner, 5% if landlord
    } else {
      return listedByRole == 'verified_partner' ? basePrice * 0.025 : basePrice * 0.05; // 2.5% if partner, 5% if landlord
    }
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    final purpose = json['purpose']?.toString() ?? 'rent';
    final basePrice = (json['basePrice'] ?? json['base_price'] ?? 0).toDouble();
    final inspection = (json['inspectionFee'] ?? json['inspection_fee'] ?? 3000.0).toDouble();

    return Property(
      id: json['id']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? json['owner_id']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? json['owner_name']?.toString() ?? 'Direct Property Owner',
      ownerPhone: json['ownerPhone']?.toString() ?? json['owner_phone']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Property Listing',
      description: json['description']?.toString() ?? '',
      purpose: purpose,
      propertyType: json['propertyType']?.toString() ?? json['property_type']?.toString() ?? 'flat_apartment',
      basePrice: basePrice,
      cautionFee: (json['cautionFee'] ?? json['caution_fee'] ?? 0).toDouble(),
      serviceCharge: (json['serviceCharge'] ?? json['service_charge'] ?? 0).toDouble(),
      rentillyFee: (json['rentillyFee'] ?? json['rentilly_fee'] ?? (basePrice * 0.10)).toDouble(),
      totalInitialPayment: (json['totalInitialPayment'] ?? json['total_initial_payment'] ?? (basePrice * 1.10)).toDouble(),
      paymentFrequency: json['paymentFrequency']?.toString() ?? json['payment_frequency']?.toString() ?? 'yearly',
      address: json['address']?.toString() ?? '',
      state: json['state']?.toString() ?? 'Lagos',
      lga: json['lga']?.toString() ?? '',
      neighborhood: json['neighborhood']?.toString() ?? '',
      bedrooms: (json['bedrooms'] ?? 1).toInt(),
      bathrooms: (json['bathrooms'] ?? 1).toInt(),
      toilets: (json['toilets'] ?? 1).toInt(),
      furnishing: json['furnishing']?.toString() ?? 'unfurnished',
      amenities: (json['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      videoWalkthroughUrl: json['videoWalkthroughUrl']?.toString() ?? json['video_walkthrough_url']?.toString(),
      status: json['status']?.toString() ?? 'active',
      verifiedAt: json['verifiedAt']?.toString() ?? json['verified_at']?.toString(),
      listedByRole: json['listedByRole']?.toString() ?? json['listed_by_role']?.toString() ?? 'direct_landlord',
      partnerId: json['partnerId']?.toString() ?? json['partner_id']?.toString(),
      partnerName: json['partnerName']?.toString() ?? json['partner_name']?.toString(),
      partnerCommissionRate: (json['partnerCommissionRate'] ?? (purpose == 'rent' ? 0.025 : 0.01)).toDouble(),
      partnerPresencePhotoUrl: json['partnerPresencePhotoUrl']?.toString() ?? json['partner_presence_photo_url']?.toString(),
      powerOfAttorneyUrl: json['powerOfAttorneyUrl']?.toString() ?? json['power_of_attorney_url']?.toString(),
      inspectionFee: inspection > 5000.0 ? 5000.0 : inspection, // Capped strictly at ₦5,000
      serviceChargeConfirmedByTenant: json['serviceChargeConfirmedByTenant'] ?? false,
      propertyAddressHash: json['propertyAddressHash']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'title': title,
      'description': description,
      'purpose': purpose,
      'propertyType': propertyType,
      'basePrice': basePrice,
      'cautionFee': cautionFee,
      'serviceCharge': serviceCharge,
      'rentillyFee': rentillyFee,
      'totalInitialPayment': totalInitialPayment,
      'paymentFrequency': paymentFrequency,
      'address': address,
      'state': state,
      'lga': lga,
      'neighborhood': neighborhood,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'toilets': toilets,
      'furnishing': furnishing,
      'amenities': amenities,
      'images': images,
      'videoWalkthroughUrl': videoWalkthroughUrl,
      'status': status,
      'verifiedAt': verifiedAt,
      'listedByRole': listedByRole,
      'partnerId': partnerId,
      'partnerName': partnerName,
      'partnerCommissionRate': partnerCommissionRate,
      'partnerPresencePhotoUrl': partnerPresencePhotoUrl,
      'powerOfAttorneyUrl': powerOfAttorneyUrl,
      'inspectionFee': inspectionFee,
      'serviceChargeConfirmedByTenant': serviceChargeConfirmedByTenant,
      'propertyAddressHash': propertyAddressHash,
    };
  }
}
