export type UserRole = 'renter' | 'buyer' | 'owner' | 'admin' | 'legal_officer';

export interface UserProfile {
  id: string;
  email: string;
  fullName: string;
  phoneNumber: string;
  role: UserRole;
  isVerified: boolean;
  ninNumber?: string;
  bvnVerified?: boolean;
  avatarUrl?: string;
  createdAt: string;
}

export type PropertyPurpose = 'rent' | 'sale';
export type PropertyType = 'flat_apartment' | 'duplex' | 'terrace' | 'semi_detached' | 'fully_detached' | 'commercial' | 'land';
export type PropertyStatus = 'draft' | 'pending_kyp' | 'verified' | 'rejected' | 'rented' | 'sold' | 'unlisted';

export interface Property {
  id: string;
  ownerId: string;
  ownerName: string;
  ownerPhone: string;
  title: string;
  description: string;
  purpose: PropertyPurpose;
  propertyType: PropertyType;
  basePrice: number; // ₦
  cautionFee: number;
  serviceCharge: number;
  rentillyFee: number; // 10% rent, 5% sale
  totalInitialPayment: number;
  paymentFrequency: 'annually' | 'biannually' | 'outright';
  address: string;
  state: string;
  lga: string;
  neighborhood: string;
  bedrooms: number;
  bathrooms: number;
  toilets: number;
  furnishing: 'unfurnished' | 'semi-furnished' | 'fully-furnished';
  amenities: string[];
  images: string[];
  videoWalkthroughUrl?: string;
  status: PropertyStatus;
  listedByRole?: 'direct_landlord' | 'verified_partner' | string;
  partnerId?: string;
  partnerName?: string;
  partnerBusinessName?: string;
  partnerCacNumber?: string;
  ownerEmail?: string;
  partnerPresencePhotoUrl?: string;
  powerOfAttorneyUrl?: string;
  verifiedAt?: string;
  verifiedBy?: string;
  createdAt: string;
  updatedAt: string;
}

export type TitleDocumentType = 'c_of_o' | 'governors_consent' | 'deed_of_assignment' | 'gazette_excision' | 'letter_of_administration';
export type KYPStatus = 'pending' | 'under_review' | 'approved' | 'rejected' | 'more_info_required';

export interface KYPRecord {
  id: string;
  propertyId: string;
  propertyTitle: string;
  propertyPurpose: PropertyPurpose;
  propertyPrice: number;
  propertyNeighborhood: string;
  ownerId: string;
  ownerName: string;
  ownerEmail: string;
  ownerPhone: string;
  
  titleDocumentType: TitleDocumentType;
  titleDocumentNumber: string;
  titleDocumentUrls: string[];
  
  ownerIdType: 'NIN' | 'International Passport' | 'Drivers License' | 'Voters Card';
  ownerIdNumber: string;
  ownerIdUrl: string;
  
  discoProvider: 'EKEDC' | 'IKEDC' | 'AEDC' | 'PHED' | 'IBEDC' | 'EEDC';
  discoMeterNumber: string;
  utilityBillUrl: string;
  videoKycUrl?: string;
  partnerPresencePhotoUrl?: string;
  powerOfAttorneyUrl?: string;
  
  landRegistrySearchStatus: 'verified_alausa' | 'verified_agis' | 'pending' | 'flagged';
  landRegistrySearchNotes?: string;
  status: KYPStatus;
  rejectionReason?: string;
  reviewedBy?: string;
  reviewedAt?: string;
  listedByRole?: 'direct_landlord' | 'verified_partner' | string;
  partnerId?: string;
  partnerName?: string;
  partnerBusinessName?: string;
  partnerCacNumber?: string;
  submittedAt: string;
}

export type InspectionStatus = 'pending_owner' | 'confirmed' | 'rescheduled' | 'completed' | 'cancelled';

export interface Inspection {
  id: string;
  propertyId: string;
  propertyTitle: string;
  propertyAddress: string;
  prospectId?: string;
  prospectName?: string;
  prospectEmail?: string;
  prospectPhone?: string;
  ownerId?: string;
  ownerName?: string;
  ownerEmail?: string;
  ownerPhone?: string;
  scheduledDate?: string;
  scheduledTimeSlot?: string;
  inspectionPassCode?: string;
  status: InspectionStatus | string;
  prospectNotes?: string;
  ownerNotes?: string;
  createdAt: string;
  // Database fields
  renterId?: string;
  date?: string;
  timeSlot?: string;
  type?: string;
  renterName?: string;
  renterPhone?: string;
  renterEmail?: string;
  feedback?: string;
  rating?: number;
  updatedAt?: string;
}

export type EscrowStatus = 'held_in_escrow' | 'released_to_owner' | 'refunded' | 'disputed';

export interface Transaction {
  id: string;
  propertyId: string;
  propertyTitle: string;
  payerId: string;
  payerName: string;
  ownerId: string;
  ownerName: string;
  transactionType: PropertyPurpose;
  paymentReference: string;
  paymentGateway: 'paystack' | 'flutterwave' | 'bank_transfer';
  baseAmount: number;
  rentillyLegalFee: number;
  cautionFee: number;
  serviceCharge: number;
  totalAmount: number;
  escrowStatus: EscrowStatus;
  ownerPayoutReference?: string;
  payoutReleasedAt?: string;
  createdAt: string;
}

export interface LegalAgreement {
  id: string;
  propertyId: string;
  propertyTitle?: string;
  propertyAddress?: string;
  propertyState?: string;
  transactionId?: string;
  landlordId?: string;
  landlordName?: string;
  tenantId?: string;
  tenantName?: string;
  agreementType: 'tenancy_agreement' | 'contract_of_sale' | string;
  agreementTitle?: string;
  governingLaw?: string;
  tenancyCommencementDate?: string;
  tenancyExpirationDate?: string;
  annualRent?: number;
  cautionDeposit?: number;
  landlordSigned?: boolean;
  landlordSignedAt?: string;
  tenantSigned?: boolean;
  tenantSignedAt?: string;
  legalOfficerStamp?: boolean;
  status: 'drafting' | 'pending_signatures' | 'fully_executed' | 'active' | 'draft' | string;
  pdfContractUrl?: string;
  createdAt: string;
  // Database fields
  renterId?: string;
  ownerId?: string;
  agreementText?: string;
  rentAmount?: number;
  tenancyPeriodMonths?: number;
  startDate?: string;
  endDate?: string;
  signedByRenterAt?: string;
  signedByOwnerAt?: string;
  updatedAt?: string;
}
