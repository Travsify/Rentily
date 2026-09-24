export type CreatorPlatform = 'tiktok' | 'instagram' | 'youtube' | 'twitter' | 'other';

export type BountyStatus = 
  | 'under_review' 
  | 'qualified_25k' 
  | 'qualified_100k' 
  | 'qualified_500k' 
  | 'grand_prize' 
  | 'paid';

export interface CreatorSubmission {
  id: string;
  creatorName: string;
  handle: string; // e.g. @tunde_reels
  platform: CreatorPlatform;
  videoUrl: string;
  claimedViews: number;
  verifiedViews: number;
  phone: string; // WhatsApp
  bankName?: string;
  accountNumber?: string;
  accountName?: string;
  bountyStatus: BountyStatus;
  payoutAmount: number; // ?
  paidAt?: string;
  payoutTxRef?: string;
  createdAt: string;
}

export interface BountyTierConfig {
  views: number;
  bonusAmount: number; // ?
  label: string;
  badgeColor: string;
}

export const BOUNTY_TIERS: BountyTierConfig[] = [
  { views: 25000, bonusAmount: 15000, label: '₦15,000 Bonus', badgeColor: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40' },
  { views: 100000, bonusAmount: 50000, label: '₦50,000 Bonus', badgeColor: 'bg-amber-500/20 text-amber-300 border-amber-500/40' },
  { views: 500000, bonusAmount: 150000, label: '₦150,000 Mega Bounty', badgeColor: 'bg-purple-500/20 text-purple-300 border-purple-500/40' },
  { views: 1000000, bonusAmount: 300000, label: '₦300,000 Grand Champion', badgeColor: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/40' }
];
