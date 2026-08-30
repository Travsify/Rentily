class Inspection {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String propertyAddress;
  final String prospectId;
  final String prospectName;
  final String prospectPhone;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final String scheduledDate;
  final String scheduledTimeSlot;
  final String inspectionPassCode;
  final String status;
  final String? prospectNotes;
  final String? ownerNotes;
  final String createdAt;

  Inspection({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.propertyAddress,
    required this.prospectId,
    required this.prospectName,
    required this.prospectPhone,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.scheduledDate,
    required this.scheduledTimeSlot,
    required this.inspectionPassCode,
    required this.status,
    this.prospectNotes,
    this.ownerNotes,
    required this.createdAt,
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id']?.toString() ?? '',
      propertyId: json['propertyId']?.toString() ?? json['property_id']?.toString() ?? '',
      propertyTitle: json['propertyTitle']?.toString() ?? json['property_title']?.toString() ?? 'Property Inspection',
      propertyAddress: json['propertyAddress']?.toString() ?? json['property_address']?.toString() ?? 'Lagos, Nigeria',
      prospectId: json['prospectId']?.toString() ?? json['prospect_id']?.toString() ?? '',
      prospectName: json['prospectName']?.toString() ?? json['prospect_name']?.toString() ?? 'Prospective Renter',
      prospectPhone: json['prospectPhone']?.toString() ?? json['prospect_phone']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? json['owner_id']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? json['owner_name']?.toString() ?? 'Direct Owner',
      ownerPhone: json['ownerPhone']?.toString() ?? json['owner_phone']?.toString() ?? '',
      scheduledDate: json['scheduledDate']?.toString() ?? json['scheduled_date']?.toString() ?? '',
      scheduledTimeSlot: json['scheduledTimeSlot']?.toString() ?? json['scheduled_time_slot']?.toString() ?? '11:00 AM - 12:00 PM',
      inspectionPassCode: json['inspectionPassCode']?.toString() ?? json['inspection_pass_code']?.toString() ?? '749201',
      status: json['status']?.toString() ?? 'confirmed',
      prospectNotes: json['prospectNotes']?.toString() ?? json['prospect_notes']?.toString(),
      ownerNotes: json['ownerNotes']?.toString() ?? json['owner_notes']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}
