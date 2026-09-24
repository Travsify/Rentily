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
  referralCode?: string; // Rentilly app referral code
  platform: CreatorPlatform;
  videoUrl: string;
  claimedViews: number;
  verifiedViews: number;
  phone: string; // WhatsApp
  bankName?: string;
  accountNumber?: string;
  accountName?: string;
  bountyStatus: BountyStatus;
  payoutAmount: number;
  paidAt?: string;
  payoutTxRef?: string;
  createdAt: string;
}

export interface ContestPrizeConfig {
  rank: string;
  prizeAmount: number;
  label: string;
  badgeColor: string;
}

export const CONTEST_PRIZES: ContestPrizeConfig[] = [
  { rank: '1st Place', prizeAmount: 200000, label: '₦200,000 Grand Champion', badgeColor: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/40' },
  { rank: '2nd Place', prizeAmount: 150000, label: '₦150,000 2nd Place', badgeColor: 'bg-slate-300/20 text-slate-200 border-slate-300/40' },
  { rank: '3rd Place', prizeAmount: 100000, label: '₦100,000 3rd Place', badgeColor: 'bg-amber-600/20 text-amber-400 border-amber-600/40' },
  { rank: 'Top 20 (4th–20th)', prizeAmount: 10000, label: '₦10,000 Each for Top 20', badgeColor: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40' },
];

export const BOUNTY_TIERS = [
  { views: 25000, bonusAmount: 10000, label: 'Top 20 (₦10k Prize)', badgeColor: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40' },
  { views: 100000, bonusAmount: 100000, label: '3rd Place (₦100k)', badgeColor: 'bg-amber-600/20 text-amber-400 border-amber-600/40' },
  { views: 500000, bonusAmount: 150000, label: '2nd Place (₦150k)', badgeColor: 'bg-slate-300/20 text-slate-200 border-slate-300/40' },
  { views: 1000000, bonusAmount: 200000, label: '1st Place (₦200k)', badgeColor: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/40' }
];
