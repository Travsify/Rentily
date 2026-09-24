import React, { useState, useEffect } from 'react';
import { 
  Copy,
  Trophy, 
  Flame, 
  Sparkles, 
  Plus, 
  Search, 
  ShieldCheck, 
  TrendingUp, 
  Users, 
  X,
  Play,
  CheckCircle2,
  DollarSign,
  Smartphone,
  Eye,
  Gift,
  ExternalLink,
  Heart
} from 'lucide-react';
import confetti from 'canvas-confetti';
import { CreatorBountyService } from '../services/creatorBountyService';
import type { CreatorSubmission, CreatorPlatform } from '../types/creatorBounty';
import { BOUNTY_TIERS } from '../types/creatorBounty';

export const CreatorLeaderboardPortal: React.FC = () => {
  const [submissions, setSubmissions] = useState<CreatorSubmission[]>([]);
  const [stats, setStats] = useState({ totalViews: 0, totalSubmissions: 0, totalPaidOut: 0, qualifiedCount: 0 });
  const [activeTab, setActiveTab] = useState<'all' | CreatorPlatform>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [isSubmitModalOpen, setIsSubmitModalOpen] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [copiedLink, setCopiedLink] = useState(false);

  // Form State
  const [formData, setFormData] = useState({
    creatorName: '',
    handle: '',
    platform: 'tiktok' as CreatorPlatform,
    videoUrl: '',
    claimedViews: '',
    phone: '',
    bankName: '',
    accountNumber: '',
    accountName: '',
  });

  const loadData = () => {
    const data = CreatorBountyService.getSubmissions();
    data.sort((a, b) => (b.verifiedViews || b.claimedViews) - (a.verifiedViews || a.claimedViews));
    setSubmissions(data);
    setStats(CreatorBountyService.getStats());
  };

  useEffect(() => {
    loadData();
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  const copyContestLink = () => {
    navigator.clipboard.writeText('https://contest.myrentilly.com');
    setCopiedLink(true);
    showToast('Copied contest.myrentilly.com to clipboard!');
    setTimeout(() => setCopiedLink(false), 3000);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.creatorName || !formData.videoUrl || !formData.handle) {
      alert('Please fill in your name, handle, and video URL.');
      return;
    }

    const views = parseInt(formData.claimedViews) || 1000;

    CreatorBountyService.submitVideo({
      creatorName: formData.creatorName,
      handle: formData.handle.startsWith('@') ? formData.handle : `@${formData.handle}`,
      platform: formData.platform,
      videoUrl: formData.videoUrl,
      claimedViews: views,
      phone: formData.phone,
      bankName: formData.bankName,
      accountNumber: formData.accountNumber,
      accountName: formData.accountName,
    });

    try {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 }
      });
    } catch {
      // Ignore if confetti is unavailable
    }

    setIsSubmitModalOpen(false);
    setFormData({
      creatorName: '',
      handle: '',
      platform: 'tiktok',
      videoUrl: '',
      claimedViews: '',
      phone: '',
      bankName: '',
      accountNumber: '',
      accountName: '',
    });

    loadData();
    showToast('Video successfully submitted to the Leaderboard! Tracking active.');
  };

  // Filtered submissions
  const filtered = submissions.filter((s) => {
    const matchesPlatform = activeTab === 'all' || s.platform === activeTab;
    const matchesSearch =
      s.creatorName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.handle.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesPlatform && matchesSearch;
  });

  const top1 = submissions[0];
  const top2 = submissions[1];
  const top3 = submissions[2];

  const getPlatformLabel = (platform: CreatorPlatform) => {
    switch (platform) {
      case 'tiktok':
        return 'TikTok';
      case 'instagram':
        return 'Reels';
      case 'youtube':
        return 'Shorts';
      case 'twitter':
        return 'X (Twitter)';
      default:
        return 'Web';
    }
  };

  const getStatusBadge = (status: CreatorSubmission['bountyStatus']) => {
    switch (status) {
      case 'qualified_500k':
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-purple-500/20 text-purple-300 border border-purple-500/40">Tier 3 (₦150k Qualified)</span>;
      case 'qualified_100k':
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/40">Tier 2 (₦50k Qualified)</span>;
      case 'qualified_25k':
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">Tier 1 (₦15k Qualified)</span>;
      case 'grand_prize':
        return <span className="px-2.5 py-1 text-xs font-black rounded-full bg-gradient-to-r from-amber-500/40 to-yellow-400/40 text-yellow-200 border border-yellow-400 shadow-md">Grand Champion (₦300k)</span>;
      case 'paid':
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-green-500/30 text-green-200 border border-green-500">PAID OUT</span>;
      default:
        return <span className="px-2.5 py-1 text-xs font-medium rounded-full bg-slate-800 text-slate-400 border border-slate-700">Tracking Views</span>;
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans selection:bg-emerald-500 selection:text-white flex flex-col justify-between">
      <div>
        {/* Toast Notification */}
        {toastMessage && (
          <div className="fixed top-5 right-5 z-50 bg-emerald-600 text-white px-5 py-3 rounded-xl shadow-2xl border border-emerald-400 flex items-center gap-3 animate-bounce">
            <CheckCircle2 className="w-5 h-5 shrink-0 text-white" />
            <span className="font-bold text-sm">{toastMessage}</span>
          </div>
        )}

        {/* Top Header - Purely Public / Clean Menu */}
        <header className="border-b border-emerald-950/40 bg-slate-900/80 backdrop-blur-md sticky top-0 z-30">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
            <div className="flex items-center gap-3.5">
              <a href="https://myrentilly.com" target="_blank" rel="noreferrer" className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-2xl bg-emerald-950 border-2 border-amber-500/80 p-2 shadow-lg shadow-emerald-900/40 flex items-center justify-center">
                  <Flame className="w-6 h-6 text-amber-400" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-xl font-extrabold tracking-wider bg-gradient-to-r from-emerald-400 to-amber-300 bg-clip-text text-transparent">
                      RENTILLY
                    </span>
                    <span className="px-2.5 py-0.5 text-[10px] font-mono font-bold uppercase tracking-wider bg-amber-500/20 text-amber-300 border border-amber-500/40 rounded-full">
                      CREATOR CONTEST
                    </span>
                  </div>
                  <p className="text-[11px] text-slate-400">Open to All Nigerian Creators &amp; Influencers</p>
                </div>
              </a>
            </div>

            <div className="flex items-center gap-2.5 sm:gap-3">
              <button
                onClick={copyContestLink}
                className="hidden sm:flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-bold text-slate-200 border border-slate-700 transition cursor-pointer"
                title="Copy shareable contest link"
              >
                <Copy className="w-3.5 h-3.5 text-emerald-400" />
                <span>{copiedLink ? 'Copied Link!' : 'contest.myrentilly.com'}</span>
              </button>

              <button
                onClick={() => setIsSubmitModalOpen(true)}
                className="px-4 sm:px-6 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-slate-950 font-extrabold text-xs sm:text-sm shadow-lg shadow-emerald-500/20 flex items-center gap-2 transition-all transform hover:scale-105 active:scale-95 cursor-pointer"
              >
                <Plus className="w-4 h-4 stroke-[3]" />
                <span>Submit Video Drop</span>
              </button>
            </div>
          </div>
        </header>

        {/* Hero Banner */}
        <section className="relative overflow-hidden pt-12 pb-16 px-4 sm:px-6 lg:px-8 border-b border-emerald-950/60 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-emerald-950/40 via-slate-950 to-slate-950">
          <div className="max-w-5xl mx-auto text-center relative z-10">
            <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-bold tracking-wide uppercase mb-6">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
              <span>🔥 Nationwide Creator Challenge • ₦500,000+ Cash Prize Pool</span>
            </div>

            <h1 className="text-3xl sm:text-5xl lg:text-6xl font-black tracking-tight text-white mb-6 leading-tight">
              Rentilly Viral Creator{' '}
              <span className="bg-gradient-to-r from-amber-300 via-emerald-400 to-teal-300 bg-clip-text text-transparent">
                Leaderboard
              </span>
            </h1>

            <p className="text-slate-300 text-base sm:text-lg max-w-2xl mx-auto mb-8 leading-relaxed">
              Post your Rentilly video on TikTok, Instagram Reels, or YouTube Shorts. Drop your link below,
              climb the ranks, unlock cash bounty tiers, and compete for the <strong>₦300,000 Grand Prize</strong>.
            </p>

            {/* Bounty Tiers Badges */}
            <div className="inline-flex flex-wrap items-center justify-center gap-3 sm:gap-6 bg-slate-900/90 border border-slate-800 rounded-2xl p-4 shadow-xl">
              <div className="flex items-center gap-2 text-xs font-semibold text-slate-300">
                <span className="text-emerald-400 font-bold">Tier 1:</span> 25k Views = <strong className="text-white">₦15,000</strong>
              </div>
              <div className="hidden sm:block text-slate-700">&bull;</div>
              <div className="flex items-center gap-2 text-xs font-semibold text-slate-300">
                <span className="text-amber-400 font-bold">Tier 2:</span> 100k Views = <strong className="text-white">₦50,000</strong>
              </div>
              <div className="hidden sm:block text-slate-700">&bull;</div>
              <div className="flex items-center gap-2 text-xs font-semibold text-slate-300">
                <span className="text-purple-400 font-bold">Tier 3:</span> 500k Views = <strong className="text-white">₦150,000</strong>
              </div>
              <div className="hidden sm:block text-slate-700">&bull;</div>
              <div className="flex items-center gap-2 text-xs font-semibold text-slate-300">
                <span className="text-yellow-400 font-bold">Grand Champion:</span> <strong className="text-white">₦300,000</strong>
              </div>
            </div>
          </div>
        </section>

        {/* Aggregate Stats Cards */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 -mt-8 relative z-20">
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-slate-900/90 border border-emerald-900/40 rounded-2xl p-5 backdrop-blur-xl shadow-xl">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Total Campaign Views</span>
                <Eye className="w-4 h-4 text-emerald-400" />
              </div>
              <div className="text-2xl sm:text-3xl font-black text-emerald-400 mt-1">
                {stats.totalViews.toLocaleString()}
              </div>
              <span className="text-[11px] text-emerald-500/80 font-medium">Across TikTok, Reels &amp; Shorts</span>
            </div>

            <div className="bg-slate-900/90 border border-slate-800 rounded-2xl p-5 backdrop-blur-xl shadow-xl">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Active Video Drops</span>
                <Users className="w-4 h-4 text-slate-400" />
              </div>
              <div className="text-2xl sm:text-3xl font-black text-white mt-1">
                {stats.totalSubmissions}
              </div>
              <span className="text-[11px] text-slate-400 font-medium">Open to All Creators &amp; Influencers</span>
            </div>

            <div className="bg-slate-900/90 border border-slate-800 rounded-2xl p-5 backdrop-blur-xl shadow-xl">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Bounties Qualified</span>
                <TrendingUp className="w-4 h-4 text-amber-400" />
              </div>
              <div className="text-2xl sm:text-3xl font-black text-amber-400 mt-1">
                {stats.qualifiedCount}
              </div>
              <span className="text-[11px] text-amber-500/80 font-medium">Hit 25k+ View Milestones</span>
            </div>

            <div className="bg-slate-900/90 border border-purple-900/40 rounded-2xl p-5 backdrop-blur-xl shadow-xl">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Cash Disbursed</span>
                <DollarSign className="w-4 h-4 text-purple-400" />
              </div>
              <div className="text-2xl sm:text-3xl font-black text-purple-400 mt-1">
                ₦{stats.totalPaidOut.toLocaleString()}
              </div>
              <span className="text-[11px] text-purple-400/80 font-medium">Direct Nigerian Bank Payouts</span>
            </div>
          </div>
        </section>

        {/* Top 3 Podium Section */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-12">
          <div className="text-center mb-8">
            <div className="inline-flex items-center gap-2 text-xs font-extrabold text-amber-400 uppercase tracking-widest">
              <Trophy className="w-4 h-4 text-amber-400" />
              <span>Current Top 3 Leaders &bull; Grand Prize Contenders</span>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 items-end max-w-4xl mx-auto">
            {/* #2 Silver */}
            {top2 && (
              <div className="order-2 md:order-1 bg-gradient-to-b from-slate-800/80 to-slate-900/90 border border-slate-700/80 rounded-2xl p-6 text-center shadow-xl relative transform md:-translate-y-2">
                <div className="w-10 h-10 rounded-full bg-slate-300 text-slate-950 font-black text-sm flex items-center justify-center mx-auto mb-3 shadow-md">
                  #2
                </div>
                <h3 className="font-extrabold text-white text-lg truncate">{top2.creatorName}</h3>
                <p className="text-xs text-emerald-400 font-semibold mb-3">{top2.handle}</p>
                <div className="text-2xl font-black text-slate-200">
                  {(top2.verifiedViews || top2.claimedViews).toLocaleString()}
                  <span className="text-xs font-normal text-slate-400 ml-1">views</span>
                </div>
                <div className="mt-3">{getStatusBadge(top2.bountyStatus)}</div>
                <a
                  href={top2.videoUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="mt-4 inline-flex items-center gap-1.5 text-xs text-emerald-400 hover:text-emerald-300 font-bold"
                >
                  <span>Watch Drop</span>
                  <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            )}

            {/* #1 Gold Champion */}
            {top1 && (
              <div className="order-1 md:order-2 bg-gradient-to-b from-amber-500/20 via-slate-900/90 to-slate-950 border-2 border-amber-500/70 rounded-2xl p-8 text-center shadow-2xl relative transform md:-translate-y-6">
                <div className="absolute -top-4 left-1/2 -translate-x-1/2 px-3 py-1 bg-amber-500 text-slate-950 font-black text-[10px] uppercase tracking-wider rounded-full shadow-lg flex items-center gap-1">
                  <Sparkles className="w-3 h-3 fill-slate-950" />
                  <span>Leader</span>
                </div>
                <div className="w-14 h-14 rounded-full bg-gradient-to-tr from-amber-400 to-yellow-300 text-slate-950 font-black text-xl flex items-center justify-center mx-auto mb-3 shadow-lg shadow-amber-500/30">
                  #1
                </div>
                <h3 className="font-black text-white text-xl truncate">{top1.creatorName}</h3>
                <p className="text-xs text-amber-400 font-bold mb-4">{top1.handle}</p>
                <div className="text-3xl font-black text-white">
                  {(top1.verifiedViews || top1.claimedViews).toLocaleString()}
                  <span className="text-sm font-normal text-amber-300/80 ml-1">views</span>
                </div>
                <div className="mt-4">{getStatusBadge(top1.bountyStatus)}</div>
                <a
                  href={top1.videoUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="mt-5 inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-amber-500/20 hover:bg-amber-500/30 text-amber-300 text-xs font-bold border border-amber-500/40 transition"
                >
                  <Play className="w-3.5 h-3.5 fill-current" />
                  <span>Watch Winning Video</span>
                </a>
              </div>
            )}

            {/* #3 Bronze */}
            {top3 && (
              <div className="order-3 bg-gradient-to-b from-amber-900/30 to-slate-900/90 border border-amber-800/40 rounded-2xl p-6 text-center shadow-xl relative">
                <div className="w-10 h-10 rounded-full bg-amber-700 text-amber-100 font-black text-sm flex items-center justify-center mx-auto mb-3 shadow-md">
                  #3
                </div>
                <h3 className="font-extrabold text-white text-lg truncate">{top3.creatorName}</h3>
                <p className="text-xs text-emerald-400 font-semibold mb-3">{top3.handle}</p>
                <div className="text-2xl font-black text-amber-200">
                  {(top3.verifiedViews || top3.claimedViews).toLocaleString()}
                  <span className="text-xs font-normal text-slate-400 ml-1">views</span>
                </div>
                <div className="mt-3">{getStatusBadge(top3.bountyStatus)}</div>
                <a
                  href={top3.videoUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="mt-4 inline-flex items-center gap-1.5 text-xs text-emerald-400 hover:text-emerald-300 font-bold"
                >
                  <span>Watch Drop</span>
                  <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            )}
          </div>
        </section>

        {/* Main Leaderboard Table Section */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-14">
          <div className="bg-slate-900/90 border border-slate-800 rounded-2xl overflow-hidden shadow-2xl backdrop-blur-xl">
            {/* Filter Bar */}
            <div className="p-4 sm:p-6 border-b border-slate-800 flex flex-col md:flex-row items-center justify-between gap-4">
              {/* Platform Tabs */}
              <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto pb-2 md:pb-0">
                {(['all', 'tiktok', 'instagram', 'youtube', 'twitter'] as const).map((tab) => (
                  <button
                    key={tab}
                    onClick={() => setActiveTab(tab)}
                    className={`px-4 py-2 rounded-xl text-xs font-bold uppercase transition ${
                      activeTab === tab
                        ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-500/20'
                        : 'bg-slate-800/80 text-slate-400 hover:text-white hover:bg-slate-800'
                    }`}
                  >
                    {tab === 'all' ? 'All Platforms' : getPlatformLabel(tab as CreatorPlatform)}
                  </button>
                ))}
              </div>

              {/* Search Input */}
              <div className="relative w-full md:w-72">
                <Search className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  placeholder="Search creator name or handle..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 bg-slate-950/80 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 transition"
                />
              </div>
            </div>

            {/* Table */}
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="bg-slate-950/80 text-slate-400 text-xs uppercase tracking-wider border-b border-slate-800">
                  <tr>
                    <th className="py-4 px-6">Rank</th>
                    <th className="py-4 px-6">Creator</th>
                    <th className="py-4 px-6">Platform</th>
                    <th className="py-4 px-6 text-right">Views Count</th>
                    <th className="py-4 px-6 text-center">Bounty Status</th>
                    <th className="py-4 px-6 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60">
                  {filtered.map((sub, idx) => (
                    <tr key={sub.id} className="hover:bg-slate-800/30 transition group">
                      <td className="py-4 px-6 font-mono font-bold">
                        {idx === 0 ? (
                          <span className="text-amber-400">#1</span>
                        ) : idx === 1 ? (
                          <span className="text-slate-300">#2</span>
                        ) : idx === 2 ? (
                          <span className="text-amber-600">#3</span>
                        ) : (
                          <span className="text-slate-500">#{idx + 1}</span>
                        )}
                      </td>
                      <td className="py-4 px-6">
                        <div className="font-bold text-white">{sub.creatorName}</div>
                        <div className="text-xs text-emerald-400 font-semibold">{sub.handle}</div>
                      </td>
                      <td className="py-4 px-6">
                        <span className="text-xs text-slate-300 font-medium">
                          {getPlatformLabel(sub.platform)}
                        </span>
                      </td>
                      <td className="py-4 px-6 text-right">
                        <div className="font-black text-white text-base">
                          {(sub.verifiedViews || sub.claimedViews).toLocaleString()}
                        </div>
                        <span className="text-[10px] text-slate-500">
                          {sub.verifiedViews ? 'Verified count' : 'Claimed'}
                        </span>
                      </td>
                      <td className="py-4 px-6 text-center">
                        {getStatusBadge(sub.bountyStatus)}
                      </td>
                      <td className="py-4 px-6 text-right">
                        <a
                          href={sub.videoUrl}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-emerald-600 hover:text-white text-slate-300 text-xs font-semibold transition"
                        >
                          <Play className="w-3 h-3 fill-current" />
                          <span>Watch</span>
                        </a>
                      </td>
                    </tr>
                  ))}

                  {filtered.length === 0 && (
                    <tr>
                      <td colSpan={6} className="py-12 text-center text-slate-500">
                        No video submissions found matching your filters. Be the first to drop a video!
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </section>

        {/* Rules & Rewards Explanation Section */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-16">
          <div className="bg-gradient-to-r from-emerald-950/60 to-slate-900/80 border border-emerald-900/40 rounded-3xl p-6 sm:p-10">
            <div className="max-w-3xl">
              <h2 className="text-xl sm:text-2xl font-black text-white mb-3">
                How the Rentilly Creator Program Works
              </h2>
              <p className="text-slate-300 text-sm leading-relaxed mb-6">
                Rentilly is Nigeria’s zero-agent rental and property verification platform by <strong>E-Homes Global Inclusive Limited</strong>.
                We invite all content creators, vloggers, comedians, students, and tenants across Nigeria to expose the agent extortion mafia,
                apartment catfishing, and showcase the seamless Rentilly mobile app.
              </p>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                {BOUNTY_TIERS.map((tier) => (
                  <div key={tier.views} className="p-4 rounded-2xl bg-slate-900/80 border border-slate-800">
                    <span className="text-xs font-bold text-amber-400 uppercase block mb-1">
                      {tier.label}
                    </span>
                    <div className="text-2xl font-black text-white mb-1">
                      ₦{tier.bonusAmount.toLocaleString()}
                    </div>
                    <p className="text-xs text-slate-400">
                      Reach {tier.views.toLocaleString()} verified views on TikTok, Reels, or Shorts.
                    </p>
                  </div>
                ))}
              </div>

              <div className="mt-6 flex flex-wrap items-center gap-4 text-xs text-slate-400">
                <div className="flex items-center gap-1.5">
                  <ShieldCheck className="w-4 h-4 text-emerald-400" />
                  <span>Instant 24hr Nigerian Bank Account payouts once milestone is verified</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <Smartphone className="w-4 h-4 text-emerald-400" />
                  <span>App live on Google Play Store (ng.rentilly.rentilly_mobile)</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <Gift className="w-4 h-4 text-amber-400" />
                  <span>₦5,000 cash bonus for every verified property listing referred</span>
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>

      {/* Corporate Comprehensive Footer */}
      <footer className="mt-20 border-t border-slate-800/80 bg-slate-950 pt-16 pb-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-10 pb-12 border-b border-slate-800/60">
            {/* Brand Col */}
            <div className="md:col-span-1 space-y-4">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-emerald-950 border border-amber-500/60 flex items-center justify-center">
                  <Flame className="w-5 h-5 text-amber-400" />
                </div>
                <span className="text-lg font-black tracking-wider text-white">RENTILLY</span>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                Empowering Nigerian tenants and property owners with direct verified listings, digital tenancy agreements, and zero middleman extortion.
              </p>
              <div className="pt-1">
                <span className="inline-block px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 rounded-lg">
                  E-Homes Global Inclusive Limited
                </span>
              </div>
            </div>

            {/* Contest Tiers Col */}
            <div>
              <h4 className="text-xs font-black uppercase tracking-wider text-white mb-4">Cash Bounties</h4>
              <ul className="space-y-2.5 text-xs text-slate-400">
                <li className="flex justify-between items-center">
                  <span>Tier 1 (25k Views)</span>
                  <strong className="text-emerald-400">₦15,000</strong>
                </li>
                <li className="flex justify-between items-center">
                  <span>Tier 2 (100k Views)</span>
                  <strong className="text-amber-400">₦50,000</strong>
                </li>
                <li className="flex justify-between items-center">
                  <span>Tier 3 (500k Views)</span>
                  <strong className="text-purple-400">₦150,000</strong>
                </li>
                <li className="flex justify-between items-center">
                  <span>Grand Champion (#1)</span>
                  <strong className="text-yellow-400">₦300,000</strong>
                </li>
                <li className="flex justify-between items-center pt-1 border-t border-slate-800">
                  <span>Direct Property Listing</span>
                  <strong className="text-emerald-400">₦5,000 / listing</strong>
                </li>
              </ul>
            </div>

            {/* App & Platform Links */}
            <div>
              <h4 className="text-xs font-black uppercase tracking-wider text-white mb-4">Platform</h4>
              <ul className="space-y-2 text-xs text-slate-400">
                <li>
                  <a href="https://myrentilly.com" target="_blank" rel="noreferrer" className="hover:text-emerald-400 transition flex items-center gap-1.5">
                    <span>Main Website</span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </li>
                <li>
                  <a href="https://play.google.com/store/apps/details?id=ng.rentilly.rentilly_mobile" target="_blank" rel="noreferrer" className="hover:text-emerald-400 transition flex items-center gap-1.5">
                    <span>Google Play Store</span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </li>
                <li>
                  <a href="https://myrentilly.com/privacy.html" target="_blank" rel="noreferrer" className="hover:text-emerald-400 transition">
                    Privacy Policy &amp; Terms
                  </a>
                </li>
                <li>
                  <a href="https://myrentilly.com" target="_blank" rel="noreferrer" className="hover:text-emerald-400 transition">
                    Verified Landlord Registration
                  </a>
                </li>
              </ul>
            </div>

            {/* Creator Support & Rules */}
            <div>
              <h4 className="text-xs font-black uppercase tracking-wider text-white mb-4">Creator Support</h4>
              <p className="text-xs text-slate-400 leading-relaxed mb-3">
                Have questions regarding view counts, payout timelines, or partnerships? Reach our creator operations desk:
              </p>
              <div className="space-y-1.5 text-xs text-slate-300">
                <div>Email: <a href="mailto:creators@myrentilly.com" className="text-emerald-400 hover:underline">creators@myrentilly.com</a></div>
                <div>Web: <span className="font-mono text-emerald-400">contest.myrentilly.com</span></div>
                <div className="text-[11px] text-slate-500 pt-1">Payouts processed directly to Nigerian bank accounts within 24 hours of verification.</div>
              </div>
            </div>
          </div>

          {/* Bottom Bar */}
          <div className="pt-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
            <p>
              &copy; 2026 <strong>E-Homes Global Inclusive Limited</strong>. All rights reserved. Rentilly&trade; is a registered real estate technology protocol.
            </p>
            <div className="flex items-center gap-2 text-[11px] text-slate-400">
              <span>Made with</span>
              <Heart className="w-3.5 h-3.5 text-red-500 fill-red-500" />
              <span>for Nigerian Content Creators</span>
            </div>
          </div>
        </div>
      </footer>

      {/* Submission Modal */}
      {isSubmitModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-lg w-full p-6 sm:p-8 shadow-2xl relative max-h-[90vh] overflow-y-auto">
            <button
              onClick={() => setIsSubmitModalOpen(false)}
              className="absolute top-5 right-5 text-slate-400 hover:text-white p-1 rounded-lg bg-slate-800"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-2 mb-1">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-400" />
              <span className="text-xs font-bold text-emerald-400 uppercase tracking-wider">
                Leaderboard Drop
              </span>
            </div>
            <h2 className="text-xl font-black text-white mb-2">Submit Your Video Link</h2>
            <p className="text-xs text-slate-400 mb-6">
              Drop your live video link so our view tracker starts counting your views for the cash bounties.
            </p>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase mb-1">Creator Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Tunde Adeyemi"
                  value={formData.creatorName}
                  onChange={(e) => setFormData({ ...formData, creatorName: e.target.value })}
                  className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-300 uppercase mb-1">Social Handle *</label>
                  <input
                    type="text"
                    required
                    placeholder="@yourhandle"
                    value={formData.handle}
                    onChange={(e) => setFormData({ ...formData, handle: e.target.value })}
                    className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-300 uppercase mb-1">Platform</label>
                  <select
                    value={formData.platform}
                    onChange={(e) => setFormData({ ...formData, platform: e.target.value as CreatorPlatform })}
                    className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-emerald-500"
                  >
                    <option value="tiktok">TikTok</option>
                    <option value="instagram">Instagram Reels</option>
                    <option value="youtube">YouTube Shorts</option>
                    <option value="twitter">X / Twitter</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase mb-1">Video Live URL *</label>
                <input
                  type="url"
                  required
                  placeholder="https://www.tiktok.com/@... or instagram.com/reel/..."
                  value={formData.videoUrl}
                  onChange={(e) => setFormData({ ...formData, videoUrl: e.target.value })}
                  className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-300 uppercase mb-1">Current View Count</label>
                  <input
                    type="number"
                    placeholder="e.g. 15400"
                    value={formData.claimedViews}
                    onChange={(e) => setFormData({ ...formData, claimedViews: e.target.value })}
                    className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-300 uppercase mb-1">WhatsApp Phone *</label>
                  <input
                    type="tel"
                    required
                    placeholder="+234 80..."
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="pt-2 border-t border-slate-800">
                <span className="block text-xs font-bold text-amber-400 uppercase mb-2">Bank Payout Info (For Cash Bonuses)</span>
                <div className="grid grid-cols-3 gap-2">
                  <input
                    type="text"
                    placeholder="Bank Name"
                    value={formData.bankName}
                    onChange={(e) => setFormData({ ...formData, bankName: e.target.value })}
                    className="px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                  />
                  <input
                    type="text"
                    placeholder="Account Number"
                    value={formData.accountNumber}
                    onChange={(e) => setFormData({ ...formData, accountNumber: e.target.value })}
                    className="px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                  />
                  <input
                    type="text"
                    placeholder="Account Name"
                    value={formData.accountName}
                    onChange={(e) => setFormData({ ...formData, accountName: e.target.value })}
                    className="px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="pt-4">
                <button
                  type="submit"
                  className="w-full py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-slate-950 font-black text-sm shadow-xl shadow-emerald-500/20 transition transform hover:scale-[1.02] active:scale-[0.98]"
                >
                  Submit Video &amp; Join Leaderboard
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
