import type { CreatorSubmission, BountyStatus } from '../types/creatorBounty';

const STORAGE_KEY = 'rentilly_creator_submissions_v1';

export const CreatorBountyService = {
  getSubmissions(): CreatorSubmission[] {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return [];
      const items: CreatorSubmission[] = JSON.parse(raw);
      // Cleanse any old dummy/mock accounts permanently
      const cleaned = items.filter(
        (s) =>
          !s.id.startsWith('sub_seed_') &&
          !s.id.startsWith('csub_') &&
          !s.id.startsWith('sub_1') &&
          !s.id.startsWith('sub_2') &&
          !s.id.startsWith('sub_3') &&
          !s.id.startsWith('sub_4') &&
          !s.id.startsWith('sub_5') &&
          !s.id.startsWith('sub_6') &&
          s.handle !== '@bigdave_realty' &&
          s.handle !== '@tunde_reels' &&
          s.handle !== '@ada_lagosliving'
      );
      if (cleaned.length !== items.length) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(cleaned));
      }
      return cleaned;
    } catch {
      return [];
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
