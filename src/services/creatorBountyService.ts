import type { CreatorSubmission, BountyStatus } from '../types/creatorBounty';

const STORAGE_KEY = 'rentilly_creator_submissions_v1';

const INITIAL_SEED_SUBMISSIONS: CreatorSubmission[] = [
  {
    id: 'sub_seed_1',
    creatorName: 'Tunde Adeleke',
    handle: '@tunde_reels',
    platform: 'tiktok',
    videoUrl: 'https://www.tiktok.com/@tunde_reels/video/7281928391029',
    claimedViews: 142500,
    verifiedViews: 142500,
    phone: '+234 803 111 2233',
    bankName: 'Access Bank',
    accountNumber: '0123456789',
    accountName: 'Tunde Adeleke',
    bountyStatus: 'qualified_100k',
    payoutAmount: 50000,
    createdAt: new Date(Date.now() - 36 * 3600 * 1000).toISOString(),
  },
  {
    id: 'sub_seed_2',
    creatorName: 'Amaka Eze',
    handle: '@amakavibes',
    platform: 'instagram',
    videoUrl: 'https://www.instagram.com/reel/C892_akj12/',
    claimedViews: 98400,
    verifiedViews: 98400,
    phone: '+234 814 222 3344',
    bankName: 'GTBank',
    accountNumber: '0987654321',
    accountName: 'Amaka Eze',
    bountyStatus: 'qualified_25k',
    payoutAmount: 15000,
    createdAt: new Date(Date.now() - 24 * 3600 * 1000).toISOString(),
  },
  {
    id: 'sub_seed_3',
    creatorName: 'Femi (Ibadan Corper)',
    handle: '@femi_nysc',
    platform: 'tiktok',
    videoUrl: 'https://www.tiktok.com/@femi_nysc/video/7281928991201',
    claimedViews: 64200,
    verifiedViews: 64200,
    phone: '+234 808 333 4455',
    bankName: 'Zenith Bank',
    accountNumber: '2109876543',
    accountName: 'Oluwafemi Johnson',
    bountyStatus: 'qualified_25k',
    payoutAmount: 15000,
    createdAt: new Date(Date.now() - 18 * 3600 * 1000).toISOString(),
  },
  {
    id: 'sub_seed_4',
    creatorName: 'Kemi Real Estate',
    handle: '@kemi_homes',
    platform: 'youtube',
    videoUrl: 'https://youtube.com/shorts/C1BWBH_5wwc',
    claimedViews: 41800,
    verifiedViews: 41800,
    phone: '+234 705 444 5566',
    bankName: 'UBA',
    accountNumber: '1098765432',
    accountName: 'Kemi Balogun',
    bountyStatus: 'qualified_25k',
    payoutAmount: 15000,
    createdAt: new Date(Date.now() - 12 * 3600 * 1000).toISOString(),
  },
  {
    id: 'sub_seed_5',
    creatorName: 'Naija Tech Bro',
    handle: '@chidi_tech',
    platform: 'tiktok',
    videoUrl: 'https://www.tiktok.com/@chidi_tech/video/7281929991234',
    claimedViews: 28900,
    verifiedViews: 28900,
    phone: '+234 802 555 6677',
    bankName: 'Kuda Bank',
    accountNumber: '2001928374',
    accountName: 'Chidi Okafor',
    bountyStatus: 'qualified_25k',
    payoutAmount: 15000,
    createdAt: new Date(Date.now() - 8 * 3600 * 1000).toISOString(),
  },
  {
    id: 'sub_seed_6',
    creatorName: 'Zainab Lifestyle',
    handle: '@zainab_creatives',
    platform: 'instagram',
    videoUrl: 'https://www.instagram.com/reel/C899_z182/',
    claimedViews: 19500,
    verifiedViews: 19500,
    phone: '+234 810 666 7788',
    bountyStatus: 'under_review',
    payoutAmount: 0,
    createdAt: new Date(Date.now() - 4 * 3600 * 1000).toISOString(),
  }
];

export const CreatorBountyService = {
  getSubmissions(): CreatorSubmission[] {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(INITIAL_SEED_SUBMISSIONS));
        return INITIAL_SEED_SUBMISSIONS;
      }
      return JSON.parse(raw);
    } catch {
      return INITIAL_SEED_SUBMISSIONS;
    }
  },

  submitVideo(
    data: Omit<CreatorSubmission, 'id' | 'createdAt' | 'bountyStatus' | 'payoutAmount' | 'verifiedViews'>
  ): CreatorSubmission {
    const all = this.getSubmissions();
    const views = Number(data.claimedViews) || 0;
    
    let initialStatus: BountyStatus = 'under_review';
    let payout = 0;
    if (views >= 500000) {
      initialStatus = 'qualified_500k';
      payout = 150000;
    } else if (views >= 100000) {
      initialStatus = 'qualified_100k';
      payout = 50000;
    } else if (views >= 25000) {
      initialStatus = 'qualified_25k';
      payout = 15000;
    }

    const newSub: CreatorSubmission = {
      ...data,
      id: 'sub_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
      claimedViews: views,
      verifiedViews: views,
      bountyStatus: initialStatus,
      payoutAmount: payout,
      createdAt: new Date().toISOString(),
    };

    all.unshift(newSub);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
    return newSub;
  },

  updateSubmission(id: string, updates: Partial<CreatorSubmission>): CreatorSubmission | null {
    const all = this.getSubmissions();
    const index = all.findIndex((s) => s.id === id);
    if (index === -1) return null;

    all[index] = { ...all[index], ...updates };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
    return all[index];
  },

  deleteSubmission(id: string): boolean {
    const all = this.getSubmissions();
    const filtered = all.filter((s) => s.id !== id);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(filtered));
    return true;
  },

  getStats() {
    const all = this.getSubmissions();
    const totalViews = all.reduce((sum, s) => sum + (s.verifiedViews || s.claimedViews || 0), 0);
    const totalPaidOut = all
      .filter((s) => s.bountyStatus === 'paid')
      .reduce((sum, s) => sum + (s.payoutAmount || 0), 0);
    const qualifiedCount = all.filter((s) => s.bountyStatus !== 'under_review').length;

    return {
      totalViews,
      totalSubmissions: all.length,
      totalPaidOut,
      qualifiedCount,
    };
  },
};
