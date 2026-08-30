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
  final String status;
  final String? verifiedAt;

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
  });

  // Calculate traditional agent fee that Nigerians usually get charged (20% on rent, 10% on sales)
  double get traditionalAgentCommission {
    return purpose == 'rent' ? basePrice * 0.20 : basePrice * 0.10;
  }

  // Calculate net money saved by the user on Rentilly
  double get totalNairaSavedOnRentilly {
    return traditionalAgentCommission - rentillyFee;
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? json['owner_id']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? json['owner_name']?.toString() ?? 'Direct Property Owner',
      ownerPhone: json['ownerPhone']?.toString() ?? json['owner_phone']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Property Listing',
      description: json['description']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'rent',
      propertyType: json['propertyType']?.toString() ?? json['property_type']?.toString() ?? 'flat_apartment',
      basePrice: (json['basePrice'] ?? json['base_price'] ?? 0).toDouble(),
      cautionFee: (json['cautionFee'] ?? json['caution_fee'] ?? 0).toDouble(),
      serviceCharge: (json['serviceCharge'] ?? json['service_charge'] ?? 0).toDouble(),
      rentillyFee: (json['rentillyFee'] ?? json['rentilly_legal_fee'] ?? 0).toDouble(),
      totalInitialPayment: (json['totalInitialPayment'] ?? json['total_initial_payment'] ?? 0).toDouble(),
      paymentFrequency: json['paymentFrequency']?.toString() ?? json['payment_frequency']?.toString() ?? 'annually',
      address: json['address']?.toString() ?? '',
      state: json['state']?.toString() ?? 'Lagos',
      lga: json['lga']?.toString() ?? 'Eti-Osa',
      neighborhood: json['neighborhood']?.toString() ?? 'Lekki Phase 1',
      bedrooms: json['bedrooms'] is int ? json['bedrooms'] : int.tryParse(json['bedrooms']?.toString() ?? '1') ?? 1,
      bathrooms: json['bathrooms'] is int ? json['bathrooms'] : int.tryParse(json['bathrooms']?.toString() ?? '1') ?? 1,
      toilets: json['toilets'] is int ? json['toilets'] : int.tryParse(json['toilets']?.toString() ?? '1') ?? 1,
      furnishing: json['furnishing']?.toString() ?? 'unfurnished',
      amenities: json['amenities'] != null ? List<String>.from(json['amenities']) : ['24/7 Security', 'Prepaid Meter'],
      images: json['images'] != null && (json['images'] as List).isNotEmpty 
          ? List<String>.from(json['images']) 
          : ['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=1000&q=80'],
      videoWalkthroughUrl: json['videoWalkthroughUrl']?.toString() ?? json['video_walkthrough_url']?.toString(),
      status: json['status']?.toString() ?? 'verified',
      verifiedAt: json['verifiedAt']?.toString() ?? json['verified_at']?.toString(),
    );
  }
}
