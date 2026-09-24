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
  enableSmsNotifications?: boolean;
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

// ==========================================
// LEGAL OPERATIONS SUITE TYPES (GLOBAL STANDARD)
// ==========================================

export type AgreementType = 'tenancy_agreement' | 'contract_of_sale' | 'deed_of_assignment' | 'power_of_attorney' | 'residential_lease';

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
  agreementType: AgreementType | string;
  agreementTitle?: string;
  governingLaw?: string;
  jurisdiction?: string;
  tenancyCommencementDate?: string;
  tenancyExpirationDate?: string;
  annualRent?: number;
  cautionDeposit?: number;
  considerationAmount?: number;
  landlordSigned?: boolean;
  landlordSignedAt?: string;
  tenantSigned?: boolean;
  tenantSignedAt?: string;
  legalOfficerStamp?: boolean;
  legalOfficerId?: string;
  legalOfficerName?: string;
  stampedAt?: string;
  pdfContractUrl?: string;
  status: 'drafting' | 'pending_signatures' | 'fully_executed' | 'active' | 'draft' | 'cancelled' | string;
  notes?: string;
  legalHash?: string;
  canonicalMetadata?: any;
  stampSerial?: string;
  digitalSignature?: string;
  signatureAlgorithm?: string;
  sealedAt?: string;
  qrVerificationUrl?: string;
  evidenceActCompliance?: boolean;
  custodyTransferredAt?: string;
  custodyHolderId?: string;
  createdAt: string;
  updatedAt?: string;
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
}

export type TitleAuditVerdict = 'pending' | 'approved' | 'conditional' | 'flagged' | 'rejected';

export interface SurveyBeacon {
  id: string;
  beaconNumber: string;
  northing?: number;
  easting?: number;
  lat?: number;
  lng?: number;
}

export interface LegalTitleAudit {
  id: string;
  propertyId: string;
  kypId?: string;
  propertyTitle?: string;
  propertyLocation?: string;
  titleDocumentType: string;
  titleDocumentNumber: string;
  landRegistry: string;
  cadastralSurveyNo?: string;
  surveyBeacons?: SurveyBeacon[];
  encumbranceStatus: 'unencumbered' | 'mortgaged' | 'lis_pendens' | 'under_investigation' | string;
  lisPendensDetails?: string;
  gazettePageRef?: string;
  titleHealthScore: number; // 0 - 100
  findings: string;
  recommendations?: string;
  verdict: TitleAuditVerdict;
  legalOfficerId: string;
  legalOfficerName: string;
  auditDate: string;
  createdAt: string;
  updatedAt: string;
}

export type DisputeCategory = 
  | 'breach_of_covenant' 
  | 'unlawful_eviction' 
  | 'caution_deposit_retention' 
  | 'title_defect' 
  | 'rent_default' 
  | 'damage_claim' 
  | 'misrepresentation' 
  | 'other';

export type DisputeStatus = 
  | 'filed' 
  | 'under_review' 
  | 'mediation' 
  | 'arbitration' 
  | 'resolved' 
  | 'dismissed' 
  | 'escalated_to_court';

export interface LegalDispute {
  id: string;
  agreementId?: string;
  propertyId?: string;
  propertyTitle?: string;
  complainantId: string;
  complainantName: string;
  complainantEmail: string;
  complainantRole: string;
  respondentId: string;
  respondentName: string;
  respondentEmail: string;
  respondentRole: string;
  disputeCategory: DisputeCategory;
  disputeTitle: string;
  claimAmount: number;
  description: string;
  evidenceUrls: string[];
  status: DisputeStatus;
  statutoryNoticeType?: string;
  statutoryNoticeDate?: string;
  emergencyInterventionActive?: boolean;
  mediationNotes?: string;
  arbitrationAwardSummary?: string;
  msaSettlementUrl?: string;
  assignedLegalOfficerId?: string;
  assignedLegalOfficerName?: string;
  resolvedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export type MilestoneStatus = 
  | 'pending_clearance' 
  | 'legal_cleared' 
  | 'rejected' 
  | 'executed' 
  | 'disbursed';

export interface LegalEscrowMilestone {
  id: string;
  agreementId?: string;
  propertyId: string;
  transactionId: string;
  milestoneNumber: number; // 1 (30%), 2 (40%), 3 (30%)
  title: string;
  description?: string;
  releasePercentage: number;
  releaseAmountNgn: number;
  status: MilestoneStatus;
  conditions: string[];
  clearedByOfficerId?: string;
  clearedByOfficerName?: string;
  clearedAt?: string;
  executedByOfficerId?: string;
  executedByOfficerName?: string;
  payoutTxReference?: string;
  executedAt?: string;
  executionNotes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface LegalDispatch {
  id: string;
  agreementId: string;
  propertyId?: string;
  propertyTitle: string;
  propertyAddress: string;
  recipientId?: string;
  recipientName: string;
  recipientEmail: string;
  recipientPhone: string;
  deliveryAddress: string;
  deliveryCity: string;
  deliveryState: string;
  deliveryCountry: string;
  isDiaspora: boolean;
  docusignStatus?: 'not_applicable' | 'sent' | 'signed' | 'completed';
  docusignEnvelopeUrl?: string;
  courierPartner: 'DHL Express' | 'FedEx' | 'GIG Logistics' | 'Red Star Express' | 'UPS' | 'Internal Dispatch' | string;
  waybillNumber: string;
  trackingUrl: string;
  securityPouchSerial?: string;
  packagePhotoUrls?: string[];
  packagePhotoHash?: string;
  deliveryOtpHash?: string;
  deliveryOtpPlain?: string;
  deliveryOtpExpiresAt?: string;
  deliveryOtpAttempts?: number;
  deliveryOtpVerifiedAt?: string;
  status: 'drafting' | 'prepared' | 'sealed' | 'in_transit' | 'out_for_delivery' | 'delivered' | 'failed' | string;
  estimatedDeliveryDate: string;
  dispatchedAt?: string;
  deliveredAt?: string;
  recipientConfirmed: boolean;
  recipientConfirmedAt?: string;
  custodyCertificateUrl?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface LegalOfficerCertificate {
  id: string;
  userId: string;
  fullLegalName: string;
  nbaEnrolmentNumber: string;
  barCallYear: number;
  lawFirmName?: string;
  sealSerialPrefix?: string;
  publicKeyPem?: string;
  certificateFingerprint?: string;
  isActive: boolean;
  issuedAt: string;
  expiresAt?: string;
  createdAt: string;
}

export interface LegalAuditLog {
  id: string;
  entityType: 'agreement' | 'title_audit' | 'dispatch' | 'dispute' | 'milestone' | 'deed_seal';
  entityId: string;
  action: 'create' | 'update' | 'stamp' | 'sign' | 'clear' | 'execute' | 'resolve' | 'verdict' | 'otp_generate' | 'otp_verify' | 'delete';
  actorId: string;
  actorEmail: string;
  actorRole: string;
  ipAddress?: string;
  userAgent?: string;
  changes?: any;
  createdAt: string;
}
