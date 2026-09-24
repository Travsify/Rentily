import React, { useState, useEffect } from 'react';
import { 
  RotateCw,
  Trophy, 
  Sparkles, 
  Plus, 
  Search, 
  X, 
  Play, 
  CheckCircle2, 
  Gift, 
  ExternalLink, 
  Heart, 
  BookOpen, 
  Share2 
} from 'lucide-react';
import confetti from 'canvas-confetti';
import { CreatorBountyService } from '../services/creatorBountyService';
import type { CreatorSubmission, CreatorPlatform } from '../types/creatorBounty';

export const CreatorLeaderboardPortal: React.FC = () => {
  const [submissions, setSubmissions] = useState<CreatorSubmission[]>([]);
  const [activeTab, setActiveTab] = useState<'all' | CreatorPlatform>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [myTrackedHandle, setMyTrackedHandle] = useState<string>(() => {
    return localStorage.getItem('rentilly_my_creator_handle') || '';
  });
  // Separate Page Routing: 'landing' | 'leaderboard'
  const [pageView, setPageView] = useState<'landing' | 'leaderboard'>(() => {
    if (
      window.location.pathname.startsWith('/leaderboard') ||
      window.location.search.includes('view=leaderboard') ||
      window.location.hash === '#leaderboard'
    ) {
      return 'leaderboard';
    }
    return 'landing';
  });

  // Auto-refresh & Manual Refresh State
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [autoRefreshEnabled, setAutoRefreshEnabled] = useState(true);
  const [lastRefreshedAt, setLastRefreshedAt] = useState<string>(new Date().toLocaleTimeString());
  const [topicFilter, setTopicFilter] = useState<'all' | 'renters' | 'property_purchase'>('all');

  // Handle URL history navigation
  useEffect(() => {
    const handlePopState = () => {
      if (
        window.location.pathname.startsWith('/leaderboard') ||
        window.location.search.includes('view=leaderboard') ||
        window.location.hash === '#leaderboard'
      ) {
        setPageView('leaderboard');
      } else {
        setPageView('landing');
      }
    };
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  const navigateTo = (view: 'landing' | 'leaderboard') => {
    setPageView(view);
    if (view === 'leaderboard') {
      window.history.pushState(null, '', '/leaderboard');
    } else {
      window.history.pushState(null, '', '/');
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  // Dedicated Refresh Handler
  const handleManualRefresh = async () => {
    setIsRefreshing(true);
    await loadData();
    setLastRefreshedAt(new Date().toLocaleTimeString());
    setTimeout(() => {
      setIsRefreshing(false);
      showToast('Leaderboard refreshed with latest live verified views!');
    }, 400);
  };

  // 30-Second Auto-Refresh Interval when on Leaderboard page
  useEffect(() => {
    if (pageView !== 'leaderboard' || !autoRefreshEnabled) return;
    const interval = setInterval(() => {
      loadData();
      setLastRefreshedAt(new Date().toLocaleTimeString());
    }, 30000);
    return () => clearInterval(interval);
  }, [pageView, autoRefreshEnabled]);

  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [isSubmitModalOpen, setIsSubmitModalOpen] = useState(false);

  // Form State
  // 3-Week Contest Season & Live Countdown State
  const [cycleConfig, setCycleConfig] = useState<{
    isActive: boolean;
    season: number;
    cycleDays: number;
    startedAt: string;
    endsAt: string;
  }>(() => {
    try {
      const raw = localStorage.getItem('rentilly_contest_cycle');
      if (raw) return JSON.parse(raw);
    } catch {}
    const now = Date.now();
    return {
      isActive: true,
      season: 1,
      cycleDays: 21,
      startedAt: new Date(now).toISOString(),
      endsAt: new Date(now + 21 * 24 * 60 * 60 * 1000).toISOString()
    };
  });

  const [timeLeft, setTimeLeft] = useState<{ days: number; hours: number; minutes: number; seconds: number }>({
    days: 21,
    hours: 0,
    minutes: 0,
    seconds: 0
  });

  // Sync cycle from API & storage
  useEffect(() => {
    const fetchCycle = async () => {
      try {
        const res = await fetch('/api/contest/cycle');
        const data = await res.json();
        if (data.status && data.cycle) {
          setCycleConfig(data.cycle);
          localStorage.setItem('rentilly_contest_cycle', JSON.stringify(data.cycle));
        }
      } catch {}
    };
    fetchCycle();

    const handleStorage = () => {
      try {
        const raw = localStorage.getItem('rentilly_contest_cycle');
        if (raw) setCycleConfig(JSON.parse(raw));
      } catch {}
    };
    window.addEventListener('rentilly_cycle_updated', handleStorage);
    window.addEventListener('storage', handleStorage);
    return () => {
      window.removeEventListener('rentilly_cycle_updated', handleStorage);
      window.removeEventListener('storage', handleStorage);
    };
  }, []);

  // Timer ticker
  useEffect(() => {
    const calculateTime = () => {
      const target = new Date(cycleConfig.endsAt).getTime();
      const now = Date.now();
      const diff = Math.max(0, target - now);

      const days = Math.floor(diff / (1000 * 60 * 60 * 24));
      const hours = Math.floor((diff / (1000 * 60 * 60)) % 24);
      const minutes = Math.floor((diff / 1000 / 60) % 60);
      const seconds = Math.floor((diff / 1000) % 60);

      setTimeLeft({ days, hours, minutes, seconds });
    };

    calculateTime();
    const interval = setInterval(calculateTime, 1000);
    return () => clearInterval(interval);
  }, [cycleConfig.endsAt]);

  const [formData, setFormData] = useState({
    topicCategory: 'renters',
    creatorName: '',
    handle: '',
    referralCode: '',
    followHandle: '',
    hasFollowed: false,
    hasTaggedRentilly: false,
    platform: 'tiktok' as CreatorPlatform,
    videoUrl: '',
    claimedViews: '',
    phone: '',
    bankName: '',
    accountNumber: '',
    accountName: '',
  });

  const loadData = async () => {
    try {
      const res = await fetch('/api/contest/submissions');
      const json = await res.json();
      if (json.status && json.submissions && json.submissions.length > 0) {
        setSubmissions(json.submissions);
        return;
      }
    } catch {
      // Fallback to local
    }
    const data = CreatorBountyService.getSubmissions();
    data.sort((a, b) => (b.verifiedViews || b.claimedViews) - (a.verifiedViews || a.claimedViews));
    setSubmissions(data);
  };

  useEffect(() => {
    loadData();
    // Auto-fill ref if present in URL
    const urlParams = new URLSearchParams(window.location.search);
    const ref = urlParams.get('ref');
    if (ref) {
      setFormData((prev) => ({ ...prev, referralCode: ref.toUpperCase() }));
    }
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.creatorName || !formData.videoUrl || !formData.handle) {
      alert('Please fill in your name, handle, and video URL.');
      return;
    }

    if (!formData.hasFollowed) {
      alert('Please confirm that you have followed our official social media accounts to qualify for payouts.');
      return;
    }

    if (!formData.hasTaggedRentilly) {
      alert('Please confirm that you have tagged Rentilly (@renti_lly on Instagram, @rentilly on TikTok/X) in your video and caption so viewers can visit our pages.');
      return;
    }

    const views = parseInt(formData.claimedViews) || 1000;

    CreatorBountyService.submitVideo({
      creatorName: formData.creatorName,
      handle: formData.handle.startsWith('@') ? formData.handle : `@${formData.handle}`,
      platform: formData.platform,
      videoUrl: formData.videoUrl,
      claimedViews: views,
      hasTaggedRentilly: formData.hasTaggedRentilly,
      phone: formData.phone,
      bankName: formData.bankName,
      accountNumber: formData.accountNumber,
      accountName: formData.accountName,
    });

    fetch('/api/contest/submissions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorName: formData.creatorName,
        handle: formData.handle.startsWith('@') ? formData.handle : `@${formData.handle}`,
        platform: formData.platform,
        videoUrl: formData.videoUrl,
        referralCode: formData.referralCode,
        claimedViews: views,
        phone: formData.phone,
        followHandle: formData.followHandle,
        hasTaggedRentilly: formData.hasTaggedRentilly,
        taggedHandleProof: formData.platform === 'instagram' ? '@renti_lly' : '@rentilly',
        bankName: formData.bankName,
        accountNumber: formData.accountNumber,
        accountName: formData.accountName,
      })
    }).catch(() => {});

    try {
      confetti({
        particleCount: 120,
        spread: 80,
        origin: { y: 0.6 }
      });
    } catch {
      // Ignore if confetti is unavailable
    }

    setIsSubmitModalOpen(false);
    localStorage.setItem('rentilly_my_creator_handle', formData.handle);
    setMyTrackedHandle(formData.handle);
    setSearchQuery(formData.handle);
    showToast(`🎉 Video drop submitted! You're now live on the Leaderboard as ${formData.handle}!`);
    setTimeout(() => navigateTo('leaderboard'), 400);

    setFormData({
      topicCategory: 'renters',
      creatorName: '',
      handle: '',
      referralCode: '',
      followHandle: '',
      hasFollowed: false,
      hasTaggedRentilly: false,
      platform: 'tiktok',
      videoUrl: '',
      claimedViews: '',
      phone: '',
      bankName: '',
      accountNumber: '',
      accountName: '',
    });

    loadData();
    showToast('Video successfully submitted to the Leaderboard! You are now in the running.');
  };

  // Filtered submissions
  const filtered = submissions.filter((s) => {
    const matchesPlatform = activeTab === 'all' || s.platform === activeTab;
    const matchesSearch =
      s.creatorName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.handle.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesPlatform && matchesSearch;
  });

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

  const getRankBadge = (rankIdx: number) => {
    if (rankIdx === 0) {
      return (
        <span className="px-2.5 py-1 text-xs font-black rounded-full bg-gradient-to-r from-amber-500/30 to-yellow-400/30 text-yellow-300 border border-yellow-400/60 shadow-md">
          🥇 1st Place (₦200,000)
        </span>
      );
    }
    if (rankIdx === 1) {
      return (
        <span className="px-2.5 py-1 text-xs font-black rounded-full bg-slate-700/40 text-slate-200 border border-slate-400/60">
          🥈 2nd Place (₦150,000)
        </span>
      );
    }
    if (rankIdx === 2) {
      return (
        <span className="px-2.5 py-1 text-xs font-black rounded-full bg-amber-800/30 text-amber-300 border border-amber-600/60">
          🥉 3rd Place (₦100,000)
        </span>
      );
    }
    if (rankIdx < 20) {
      return (
        <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
          🎁 Top 20 Winner (₦10,000)
        </span>
      );
    }
    return (
      <span className="px-2.5 py-0.5 text-[11px] font-semibold rounded-full bg-slate-800 text-slate-400">
        Chasing Top 20
      </span>
    );
  };

  const scrollToSection = (id: string) => {
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans selection:bg-emerald-500 selection:text-white flex flex-col justify-between pb-24 md:pb-12">
      <div>
        {/* Toast Notification */}
        {toastMessage && (
          <div className="fixed top-5 right-5 z-50 bg-emerald-600 text-white px-5 py-3 rounded-xl shadow-2xl border border-emerald-400 flex items-center gap-3 animate-bounce">
            <CheckCircle2 className="w-5 h-5 shrink-0 text-white" />
            <span className="font-bold text-sm">{toastMessage}</span>
          </div>
        )}

        {/* Top Header - Public Only */}
        <header className="border-b border-emerald-950/40 bg-slate-900/80 backdrop-blur-md sticky top-0 z-30">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
            <div className="flex items-center gap-3.5">
              <a href="https://myrentilly.com" target="_blank" rel="noreferrer" className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-2xl bg-slate-900 border-2 border-emerald-400/40 p-1.5 shadow-lg shadow-emerald-900/30 flex items-center justify-center overflow-hidden shrink-0">
                  <img src="/logo.png" alt="Rentilly" className="w-full h-full object-contain" />
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

            <div className="flex items-center gap-2 sm:gap-3">
              {pageView === 'landing' ? (
                <>
                  <button
                    onClick={() => navigateTo('leaderboard')}
                    className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-gradient-to-r from-amber-500/20 to-emerald-500/20 hover:from-amber-500/30 hover:to-emerald-500/30 text-amber-300 border border-amber-500/40 text-xs font-extrabold tracking-wide transition cursor-pointer shadow-lg shadow-amber-950/40"
                    title="Open Dedicated Leaderboard Page"
                  >
                    <Trophy className="w-4 h-4 text-amber-400" />
                    <span>Leaderboard</span>
                    <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping ml-0.5" />
                  </button>

                  <button
                    onClick={() => scrollToSection('rules')}
                    className="hidden lg:flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-slate-300 hover:text-white transition cursor-pointer"
                  >
                    <BookOpen className="w-3.5 h-3.5 text-amber-400" />
                    <span>Rules</span>
                  </button>

                  <button
                    onClick={() => scrollToSection('socials')}
                    className="hidden lg:flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-slate-300 hover:text-white transition cursor-pointer"
                  >
                    <Share2 className="w-3.5 h-3.5 text-pink-400" />
                    <span>Follow Us</span>
                  </button>
                </>
              ) : (
                <>
                  <button
                    onClick={() => navigateTo('landing')}
                    className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 text-xs font-bold transition cursor-pointer"
                  >
                    <span>← Back to Contest Rules</span>
                  </button>
                  <button
                    onClick={handleManualRefresh}
                    disabled={isRefreshing}
                    className="flex items-center gap-1.5 px-3.5 py-2.5 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-bold transition cursor-pointer"
                    title="Refresh Live Leaderboard Views"
                  >
                    <RotateCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
                    <span className="hidden sm:inline">Refresh</span>
                  </button>
                </>
              )}

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

        {pageView === 'landing' ? (
          /* ========================================================= */
          /* PAGE 1: CONTEST LANDING & CAMPAIGN INFORMATION PAGE       */
          /* ========================================================= */
          <div>
            {/* Hero Banner */}
            <section className="relative overflow-hidden pt-10 pb-14 px-4 sm:px-6 lg:px-8 border-b border-emerald-950/60 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-emerald-950/40 via-slate-950 to-slate-950">
              <div className="max-w-5xl mx-auto text-center relative z-10">
                <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-bold tracking-wide uppercase mb-6">
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                  <span>🔥 Top 20 Creators Win Cash • Total Cash Prize Pool!</span>
                </div>

                <h1 className="text-3xl sm:text-5xl lg:text-6xl font-black tracking-tight text-white mb-5 leading-tight">
                  Rentilly Viral Creator <br/>
                  <span className="bg-gradient-to-r from-amber-300 via-emerald-400 to-teal-300 bg-clip-text text-transparent">
                    Challenge &amp; Cash Pool
                  </span>
                </h1>

                <p className="text-slate-300 text-sm sm:text-base lg:text-lg max-w-2xl mx-auto mb-8 leading-relaxed">
                  Post your Rentilly video on TikTok, Instagram Reels, or YouTube Shorts centering on <strong>Renters</strong> or <strong>Property Purchase</strong>. 
                  Top 20 performers win cash: <strong>1st Place ₦200,000, 2nd Place ₦150,000, 3rd Place ₦100,000, and Ranks 4–20 win ₦10,000 each!</strong>
                </p>

                {/* Official Prize Pool Cards (id="prizes") */}
                <div id="prizes" className="grid grid-cols-2 md:grid-cols-4 gap-3 max-w-4xl mx-auto">
                  <div className="bg-gradient-to-b from-yellow-500/20 to-slate-900 border-2 border-yellow-500/60 rounded-2xl p-4 text-center">
                    <span className="text-xs font-extrabold text-yellow-300 uppercase block mb-1">🥇 1st Place</span>
                    <div className="text-2xl sm:text-3xl font-black text-white">₦200,000</div>
                    <span className="text-[11px] text-yellow-400/80">Grand Champion</span>
                  </div>
                  <div className="bg-gradient-to-b from-slate-400/20 to-slate-900 border border-slate-400/50 rounded-2xl p-4 text-center">
                    <span className="text-xs font-extrabold text-slate-300 uppercase block mb-1">🥈 2nd Place</span>
                    <div className="text-2xl sm:text-3xl font-black text-white">₦150,000</div>
                    <span className="text-[11px] text-slate-400">Runner Up</span>
                  </div>
                  <div className="bg-gradient-to-b from-amber-600/20 to-slate-900 border border-amber-600/50 rounded-2xl p-4 text-center">
                    <span className="text-xs font-extrabold text-amber-400 uppercase block mb-1">🥉 3rd Place</span>
                    <div className="text-2xl sm:text-3xl font-black text-white">₦100,000</div>
                    <span className="text-[11px] text-amber-500/80">3rd Position</span>
                  </div>
                  <div className="bg-gradient-to-b from-emerald-500/20 to-slate-900 border border-emerald-500/50 rounded-2xl p-4 text-center">
                    <span className="text-xs font-extrabold text-emerald-400 uppercase block mb-1">🎁 Top 20 Videos</span>
                    <div className="text-2xl sm:text-3xl font-black text-white">₦10,000 <span className="text-xs font-normal text-slate-300">ea.</span></div>
                    <span className="text-[11px] text-emerald-400/80">Ranks 4th – 20th</span>
                  </div>
                </div>
              </div>
            </section>

            {/* 3-WEEK CONTEST COUNTDOWN & APPROVED TOPIC ANNOUNCEMENT BANNER */}
            <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 -mt-6 mb-8 relative z-25">
              <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-emerald-950 via-slate-900 to-teal-950 border-2 border-emerald-500/50 p-6 sm:p-8 shadow-2xl shadow-emerald-950/60 backdrop-blur-xl">
                <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
                  <div className="space-y-2.5">
                    <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/20 border border-emerald-400/40 text-emerald-300 text-xs font-black uppercase tracking-wider">
                      <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                      Season {cycleConfig.season || 1} • 3-Week Creator Sprint
                    </div>
                    <h2 className="text-2xl sm:text-3xl font-black text-white">
                      {cycleConfig.isActive ? 'Contest Sprint Closes In:' : 'Season Review In Progress'}
                    </h2>
                    <div className="flex flex-wrap items-center gap-2 text-xs sm:text-sm text-amber-300 font-extrabold bg-amber-500/15 border border-amber-500/40 px-3.5 py-1.5 rounded-xl w-fit">
                      <span>🎯 Mandatory Video Scope:</span>
                      <span className="text-white underline decoration-amber-400">Renters &amp; Property Purchase Only</span>
                    </div>
                    <p className="text-xs text-slate-300 max-w-xl leading-relaxed">
                      The contest runs in <strong>3-week recurring seasons</strong>! Your video must center exclusively on either <strong>Renters</strong> (finding, renting, leasing verified homes) or <strong>Property Purchase</strong> (buying houses, land, title verification &amp; escrow sales).
                    </p>
                  </div>

                  {/* Countdown Digital Blocks (Visible if Active) */}
                  {cycleConfig.isActive ? (
                    <div className="flex flex-col items-center gap-2">
                      <div className="grid grid-cols-4 gap-2 sm:gap-3 text-center">
                        <div className="bg-slate-950/90 border border-emerald-500/40 rounded-2xl p-3 sm:p-4 min-w-[70px] sm:min-w-[85px] shadow-lg">
                          <div className="text-2xl sm:text-4xl font-black text-white font-mono">{timeLeft.days}</div>
                          <div className="text-[10px] sm:text-xs font-bold text-emerald-400 uppercase tracking-wider mt-1">Days</div>
                        </div>
                        <div className="bg-slate-950/90 border border-emerald-500/40 rounded-2xl p-3 sm:p-4 min-w-[70px] sm:min-w-[85px] shadow-lg">
                          <div className="text-2xl sm:text-4xl font-black text-white font-mono">{timeLeft.hours}</div>
                          <div className="text-[10px] sm:text-xs font-bold text-emerald-400 uppercase tracking-wider mt-1">Hours</div>
                        </div>
                        <div className="bg-slate-950/90 border border-emerald-500/40 rounded-2xl p-3 sm:p-4 min-w-[70px] sm:min-w-[85px] shadow-lg">
                          <div className="text-2xl sm:text-4xl font-black text-white font-mono">{timeLeft.minutes}</div>
                          <div className="text-[10px] sm:text-xs font-bold text-emerald-400 uppercase tracking-wider mt-1">Mins</div>
                        </div>
                        <div className="bg-slate-950/90 border border-emerald-500/40 rounded-2xl p-3 sm:p-4 min-w-[70px] sm:min-w-[85px] shadow-lg">
                          <div className="text-2xl sm:text-4xl font-black text-emerald-300 font-mono animate-pulse">{timeLeft.seconds}</div>
                          <div className="text-[10px] sm:text-xs font-bold text-emerald-400 uppercase tracking-wider mt-1">Secs</div>
                        </div>
                      </div>
                      <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-400">
                        🟢 Real-time Official Sprint Clock
                      </span>
                    </div>
                  ) : (
                    <div className="bg-slate-950/90 border border-slate-700 rounded-2xl p-5 text-center min-w-[240px]">
                      <div className="text-sm font-bold text-slate-200">Next 3-Week Sprint Opening Soon</div>
                      <div className="text-xs text-slate-400 mt-1">Contest countdown paused during admin verification</div>
                    </div>
                  )}

                  {/* Action Button */}
                  <button
                    type="button"
                    onClick={() => setIsSubmitModalOpen(true)}
                    className="px-6 py-4 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-400 hover:from-emerald-400 hover:to-teal-300 text-slate-950 font-black text-xs uppercase tracking-wider shadow-lg shadow-emerald-500/30 transition transform hover:-translate-y-0.5 active:scale-95 flex items-center justify-center gap-2 cursor-pointer shrink-0"
                  >
                    <Plus className="w-4 h-4 stroke-[3]" />
                    <span>Submit Video Drop</span>
                  </button>
                </div>
              </div>
            </section>

            {/* DEDICATED LEADERBOARD GATEWAY CARD (SEPARATE PAGE PROMPT) */}
            <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-12">
              <div className="bg-gradient-to-r from-slate-900 via-slate-900 to-emerald-950/80 border-2 border-amber-500/60 rounded-3xl p-6 sm:p-8 shadow-2xl flex flex-col md:flex-row items-center justify-between gap-6">
                <div className="flex items-center gap-5">
                  <div className="w-16 h-16 rounded-2xl bg-amber-500/20 border-2 border-amber-400 flex items-center justify-center text-3xl shrink-0 shadow-xl shadow-amber-950/60">
                    🏆
                  </div>
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-xs font-black uppercase text-amber-400 tracking-wider">
                        Dedicated Leaderboard Page
                      </span>
                      <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
                        Live Auto-Refresh
                      </span>
                    </div>
                    <h3 className="text-xl sm:text-2xl font-black text-white">
                      Official Creator Leaderboard &amp; Position Checker
                    </h3>
                    <p className="text-xs sm:text-sm text-slate-300 mt-1 max-w-xl leading-relaxed">
                      To keep this page fast and uncluttered, the full leaderboard is hosted on its own dedicated page. Track your video drop, view verified view counts, and see current rank positions.
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => navigateTo('leaderboard')}
                  className="px-6 py-4 rounded-2xl bg-gradient-to-r from-amber-400 via-amber-500 to-yellow-400 hover:from-amber-300 hover:to-yellow-300 text-slate-950 font-black text-xs sm:text-sm uppercase tracking-wider shadow-xl shadow-amber-500/30 transition transform hover:scale-105 active:scale-95 flex items-center gap-2 shrink-0 cursor-pointer"
                >
                  <Trophy className="w-4 h-4 text-slate-950" />
                  <span>Open Full Leaderboard Page ↗</span>
                </button>
              </div>
            </section>

            {/* STEP 1: FOLLOW US SOCIAL HUB (CRITICAL FOR FOLLOWER GROWTH) */}
            <section id="socials" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-12 relative z-20">
              <div className="bg-gradient-to-r from-slate-900 via-slate-900 to-emerald-950/80 border-2 border-amber-500/50 rounded-3xl p-6 sm:p-8 shadow-2xl backdrop-blur-xl">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-800">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider bg-amber-500/20 text-amber-300 border border-amber-500/40">
                        Mandatory Qualification Conditions
                      </span>
                      <span className="text-xs font-bold text-emerald-400">Step 1 of 2</span>
                    </div>
                    <h2 className="text-2xl sm:text-3xl font-black text-white">
                      Follow &amp; Tag Rentilly on Official Social Pages
                    </h2>
                    <p className="text-slate-300 text-xs sm:text-sm mt-1 max-w-2xl leading-relaxed">
                      To qualify for cash prizes, creators <strong>must follow our official pages</strong> and <strong>tag us in your video &amp; caption</strong> (@renti_lly on Instagram, @rentilly on TikTok/X). All winners are verified prior to payout.
                    </p>
                  </div>
                </div>

                {/* 5 Social Media Channels Cards Grid */}
                <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3.5 mt-6">
                  {/* Instagram */}
                  <a
                    href="https://www.instagram.com/renti_lly"
                    target="_blank"
                    rel="noreferrer"
                    className="group p-4 bg-slate-950/90 hover:bg-slate-900 border border-slate-800 hover:border-pink-500/60 rounded-2xl transition-all transform hover:-translate-y-1 shadow-lg flex flex-col justify-between"
                  >
                    <div>
                      <div className="w-10 h-10 rounded-xl bg-pink-500/20 border border-pink-500/40 flex items-center justify-center mb-3 shadow-md">
                        <svg className="w-5 h-5 text-pink-400 fill-current" viewBox="0 0 24 24">
                          <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/>
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-slate-400 uppercase">Instagram</span>
                      <div className="text-sm font-extrabold text-white mt-0.5 group-hover:text-pink-400 transition truncate">@renti_lly</div>
                    </div>
                    <div className="mt-3 flex items-center justify-between text-[11px] font-bold text-pink-400 group-hover:underline">
                      <span>Follow &amp; Tag</span>
                      <ExternalLink className="w-3.5 h-3.5" />
                    </div>
                  </a>

                  {/* TikTok */}
                  <a
                    href="https://www.tiktok.com/@rentilly"
                    target="_blank"
                    rel="noreferrer"
                    className="group p-4 bg-slate-950/90 hover:bg-slate-900 border border-slate-800 hover:border-emerald-500/60 rounded-2xl transition-all transform hover:-translate-y-1 shadow-lg flex flex-col justify-between"
                  >
                    <div>
                      <div className="w-10 h-10 rounded-xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center mb-3 shadow-md">
                        <svg className="w-5 h-5 text-emerald-400 fill-current" viewBox="0 0 24 24">
                          <path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.24 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/>
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-slate-400 uppercase">TikTok</span>
                      <div className="text-sm font-extrabold text-white mt-0.5 group-hover:text-emerald-400 transition truncate">@rentilly</div>
                    </div>
                    <div className="mt-3 flex items-center justify-between text-[11px] font-bold text-emerald-400 group-hover:underline">
                      <span>Follow &amp; Tag</span>
                      <ExternalLink className="w-3.5 h-3.5" />
                    </div>
                  </a>

                  {/* X / Twitter */}
                  <a
                    href="https://x.com/rentilly?s=11"
                    target="_blank"
                    rel="noreferrer"
                    className="group p-4 bg-slate-950/90 hover:bg-slate-900 border border-slate-800 hover:border-slate-400 rounded-2xl transition-all transform hover:-translate-y-1 shadow-lg flex flex-col justify-between"
                  >
                    <div>
                      <div className="w-10 h-10 rounded-xl bg-slate-900 border border-slate-700 flex items-center justify-center mb-3 shadow-md">
                        <svg className="w-5 h-5 text-white fill-current" viewBox="0 0 24 24">
                          <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-slate-400 uppercase">X (Twitter)</span>
                      <div className="text-sm font-extrabold text-white mt-0.5 group-hover:text-slate-200 transition truncate">@rentilly</div>
                    </div>
                    <div className="mt-3 flex items-center justify-between text-[11px] font-bold text-slate-300 group-hover:underline">
                      <span>Follow &amp; Tag</span>
                      <ExternalLink className="w-3.5 h-3.5" />
                    </div>
                  </a>

                  {/* Facebook */}
                  <a
                    href="https://www.facebook.com/profile.php"
                    target="_blank"
                    rel="noreferrer"
                    className="group p-4 bg-slate-950/90 hover:bg-slate-900 border border-slate-800 hover:border-blue-500/60 rounded-2xl transition-all transform hover:-translate-y-1 shadow-lg flex flex-col justify-between"
                  >
                    <div>
                      <div className="w-10 h-10 rounded-xl bg-blue-600/20 border border-blue-500/40 flex items-center justify-center mb-3 shadow-md">
                        <svg className="w-5 h-5 text-blue-500 fill-current" viewBox="0 0 24 24">
                          <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-slate-400 uppercase">Facebook</span>
                      <div className="text-sm font-extrabold text-white mt-0.5 group-hover:text-blue-400 transition truncate">Rentilly</div>
                    </div>
                    <div className="mt-3 flex items-center justify-between text-[11px] font-bold text-blue-400 group-hover:underline">
                      <span>Connect</span>
                      <ExternalLink className="w-3.5 h-3.5" />
                    </div>
                  </a>

                  {/* LinkedIn */}
                  <a
                    href="https://www.linkedin.com/company/rentilly/"
                    target="_blank"
                    rel="noreferrer"
                    className="group p-4 bg-slate-950/90 hover:bg-slate-900 border border-slate-800 hover:border-sky-500/60 rounded-2xl transition-all transform hover:-translate-y-1 shadow-lg flex flex-col justify-between"
                  >
                    <div>
                      <div className="w-10 h-10 rounded-xl bg-sky-600/20 border border-sky-500/40 flex items-center justify-center mb-3 shadow-md">
                        <svg className="w-5 h-5 text-sky-400 fill-current" viewBox="0 0 24 24">
                          <path d="M19 3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h14m-.5 15.5v-5.3a3.26 3.26 0 0 0-3.26-3.26c-.85 0-1.84.52-2.28 1.3v-1.11h-2.79v8.37h2.79v-4.93c0-.77.62-1.4 1.39-1.4a1.4 1.4 0 0 1 1.4 1.4v4.93h2.75M6.46 10.9v8.37H9.2V10.9H6.46M7.83 6.64a1.64 1.64 0 0 0-1.66 1.65 1.65 1.65 0 0 0 1.66 1.65 1.65 1.65 0 0 0 1.66-1.65 1.64 1.64 0 0 0-1.66-1.65z"/>
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-slate-400 uppercase">LinkedIn</span>
                      <div className="text-sm font-extrabold text-white mt-0.5 group-hover:text-sky-300 transition truncate">Rentilly</div>
                    </div>
                    <div className="mt-3 flex items-center justify-between text-[11px] font-bold text-sky-400 group-hover:underline">
                      <span>Follow Company</span>
                      <ExternalLink className="w-3.5 h-3.5" />
                    </div>
                  </a>
                </div>
              </div>
            </section>

            {/* OFFICIAL RULES OF ENGAGEMENT & PARTICIPATION GUIDELINES (id="rules") */}
            <section id="rules" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-16">
              <div className="bg-gradient-to-br from-slate-900 via-slate-900 to-emerald-950/60 border border-emerald-900/50 rounded-3xl p-6 sm:p-10 shadow-2xl">
                <div className="flex items-center gap-2 mb-2">
                  <BookOpen className="w-5 h-5 text-amber-400" />
                  <span className="text-xs font-black uppercase tracking-wider text-amber-400">
                    Official Contest Guidelines
                  </span>
                </div>
                <h2 className="text-2xl sm:text-3xl font-black text-white mb-3">
                  Rules of Engagement &amp; Eligibility Criteria
                </h2>
                <p className="text-slate-300 text-xs sm:text-sm leading-relaxed mb-8 max-w-3xl">
                  Rentilly by <strong>E-Homes Global Inclusive Limited</strong> operates an open, merit-based creator contest. 
                  To guarantee fairness, transparency, and immediate prize disbursals, all participants must strictly adhere to the following 6 rules:
                </p>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                  {/* Rule 1 */}
                  <div className="p-5 rounded-2xl bg-slate-950/80 border border-amber-500/40 space-y-2.5">
                    <div className="flex items-center justify-between">
                      <span className="w-7 h-7 rounded-lg bg-amber-500 text-slate-950 font-black text-xs flex items-center justify-center">
                        01
                      </span>
                      <span className="text-[10px] font-bold text-amber-400 uppercase bg-amber-500/10 px-2 py-0.5 rounded">
                        Mandatory
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Follow &amp; Tag Rentilly</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Must follow <strong>@renti_lly on Instagram, @rentilly on TikTok/X</strong> AND tag us in your video and caption so viewers can click directly to our pages.
                    </p>
                  </div>

                  {/* Rule 2 */}
                  <div className="p-5 rounded-2xl bg-slate-950/80 border border-emerald-500/40 space-y-2.5">
                    <div className="flex items-center justify-between">
                      <span className="w-7 h-7 rounded-lg bg-emerald-500 text-slate-950 font-black text-xs flex items-center justify-center">
                        02
                      </span>
                      <span className="text-[10px] font-bold text-emerald-400 uppercase bg-emerald-500/10 px-2 py-0.5 rounded">
                        Approved Scope
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Renters &amp; Property Purchase Only</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Videos must center strictly on <strong>Renters</strong> (finding/renting homes, inspection relief, zero extortion) or <strong>Property Purchase</strong> (buying houses, land, title audits, secure sales escrow).
                    </p>
                  </div>

                  {/* Rule 3 */}
                  <div className="p-5 rounded-2xl bg-slate-950/80 border border-slate-800 space-y-2.5">
                    <div className="flex items-center justify-between">
                      <span className="w-7 h-7 rounded-lg bg-slate-800 text-slate-300 font-black text-xs flex items-center justify-center">
                        03
                      </span>
                      <span className="text-[10px] font-bold text-slate-400 uppercase bg-slate-800 px-2 py-0.5 rounded">
                        Ranking Metric
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Verified View Velocity</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Ranks are determined by verified views. 1st: ₦200,000 • 2nd: ₦150,000 • 3rd: ₦100,000 • Ranks 4–20: ₦10,000 each.
                    </p>
                  </div>

                  {/* Rule 4 */}
                  <div className="p-5 rounded-2xl bg-slate-950/80 border border-slate-800 space-y-2.5">
                    <div className="flex items-center justify-between">
                      <span className="w-7 h-7 rounded-lg bg-slate-800 text-slate-300 font-black text-xs flex items-center justify-center">
                        04
                      </span>
                      <span className="text-[10px] font-bold text-slate-400 uppercase bg-slate-800 px-2 py-0.5 rounded">
                        Payouts
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Direct Bank Disbursals</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      All prize money is disbursed directly via NUBAN Nigerian bank transfer (GTBank, Access, Zenith, Kuda, OPay, PalmPay) at the end of the 3-week season.
                    </p>
                  </div>

                  {/* Rule 5 */}
                  <div className="p-5 rounded-2xl bg-slate-950/80 border border-red-500/40 space-y-2.5">
                    <div className="flex items-center justify-between">
                      <span className="w-7 h-7 rounded-lg bg-red-500/20 text-red-400 font-black text-xs flex items-center justify-center">
                        05
                      </span>
                      <span className="text-[10px] font-bold text-red-400 uppercase bg-red-500/10 px-2 py-0.5 rounded">
                        Anti-Bot Fraud
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Zero Bot Views Allowed</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Artificial views or click-farms violate Rule 05. The automated crawler scores engagement ratios and disqualifies fraudulent views immediately.
                    </p>
                  </div>

                  {/* Rule 6 */}
                  <div className="p-5 rounded-2xl bg-slate-950/80 border border-slate-800 space-y-2.5">
                    <div className="flex items-center justify-between">
                      <span className="w-7 h-7 rounded-lg bg-slate-800 text-slate-300 font-black text-xs flex items-center justify-center">
                        06
                      </span>
                      <span className="text-[10px] font-bold text-slate-400 uppercase bg-slate-800 px-2 py-0.5 rounded">
                        Recurrence
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Recurring Every 3 Weeks</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Contests run on a continuous 3-week sprint cycle. After each season closes and prizes are paid, a new 3-week sprint opens immediately!
                    </p>
                  </div>
                </div>
              </div>
            </section>
          </div>
        ) : (
          /* ========================================================= */
          /* PAGE 2: DEDICATED STANDALONE LEADERBOARD PAGE             */
          /* ========================================================= */
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8 animate-fadeIn">
            {/* Top Bar with Back Navigation & Live Refresh Controls */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800">
              <button
                type="button"
                onClick={() => navigateTo('landing')}
                className="inline-flex items-center gap-2 text-xs font-bold text-slate-400 hover:text-white transition w-fit cursor-pointer"
              >
                <span>← Back to Contest Rules &amp; Info</span>
              </button>

              {/* Refresh Controls: Auto-Refresh Toggle + Manual Refresh */}
              <div className="flex items-center gap-3">
                {/* Auto-Refresh Toggle */}
                <div className="flex items-center gap-2.5 bg-slate-900 border border-slate-800 px-3.5 py-2 rounded-xl text-xs">
                  <span className="text-slate-400 font-medium">Auto-Refresh:</span>
                  <button
                    type="button"
                    onClick={() => setAutoRefreshEnabled(!autoRefreshEnabled)}
                    className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors cursor-pointer ${
                      autoRefreshEnabled ? 'bg-emerald-500' : 'bg-slate-700'
                    }`}
                  >
                    <span
                      className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                        autoRefreshEnabled ? 'translate-x-4' : 'translate-x-1'
                      }`}
                    />
                  </button>
                  <span className={`text-[10px] font-black uppercase ${autoRefreshEnabled ? 'text-emerald-400' : 'text-slate-500'}`}>
                    {autoRefreshEnabled ? 'ON (30s)' : 'OFF'}
                  </span>
                </div>

                {/* Manual Refresh Button */}
                <button
                  type="button"
                  onClick={handleManualRefresh}
                  disabled={isRefreshing}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-400 hover:to-teal-400 text-slate-950 font-black text-xs uppercase tracking-wider shadow-lg shadow-emerald-500/20 transition active:scale-95 cursor-pointer disabled:opacity-50"
                >
                  <RotateCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
                  <span>{isRefreshing ? 'Syncing Views...' : 'Refresh Board'}</span>
                </button>
              </div>
            </div>

            {/* Header Title & Scope */}
            <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <Trophy className="w-5 h-5 text-amber-400" />
                  <span className="text-xs font-black uppercase tracking-wider text-amber-400">
                    Official Creator Leaderboard
                  </span>
                  <span className="px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
                    Season {cycleConfig.season || 1} • 3-Week Sprint
                  </span>
                </div>
                <h1 className="text-3xl sm:text-4xl font-black text-white">
                  Live Rankings &amp; Verified Views
                </h1>
                <div className="flex items-center gap-2 mt-2 text-xs font-bold text-amber-300">
                  <span>🎯 Mandatory Scope:</span>
                  <span className="text-white underline decoration-amber-400">Renters &amp; Property Purchase Only</span>
                </div>
              </div>

              <div className="text-xs text-slate-400">
                Last updated: <span className="font-mono text-emerald-400 font-bold">{lastRefreshedAt}</span>
              </div>
            </div>

            {/* PERSONAL POSITION TRACKER TOOL */}
            <div className="bg-gradient-to-r from-slate-900 via-slate-900 to-emerald-950/40 border border-emerald-500/30 rounded-3xl p-5 sm:p-6 shadow-xl space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div>
                  <h3 className="text-base font-black text-white flex items-center gap-2">
                    <span>📍 Find Your Video Drop &amp; Position</span>
                  </h3>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Enter your social handle (@your_handle) or referral code to inspect your live rank and prize tier.
                  </p>
                </div>

                <div className="relative">
                  <Search className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="Search your @handle or Ref Code..."
                    value={myTrackedHandle}
                    onChange={(e) => {
                      setMyTrackedHandle(e.target.value);
                      setSearchQuery(e.target.value);
                    }}
                    className="pl-9 pr-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-400 w-full sm:w-64"
                  />
                </div>
              </div>

              {/* Personal Standing Card (If user handle matches) */}
              {(() => {
                if (!myTrackedHandle.trim()) return null;
                const query = myTrackedHandle.toLowerCase().trim().replace(/^@/, '');
                const myRankIdx = submissions.findIndex(s => 
                  s.handle.toLowerCase().includes(query) || 
                  s.creatorName.toLowerCase().includes(query) ||
                  (s.referralCode && s.referralCode.toLowerCase() === query)
                );

                if (myRankIdx !== -1) {
                  const mySub = submissions[myRankIdx];
                  return (
                    <div className="p-4 sm:p-5 rounded-2xl bg-slate-950 border-2 border-emerald-400/60 shadow-xl flex flex-col sm:flex-row sm:items-center justify-between gap-4 animate-fadeIn">
                      <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-2xl bg-emerald-500/20 border-2 border-emerald-400 flex items-center justify-center text-xl shrink-0 font-mono font-black text-emerald-300">
                          #{myRankIdx + 1}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-xs font-black uppercase text-emerald-400 tracking-wider">Your Position</span>
                            <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-slate-800 text-white uppercase">{getPlatformLabel(mySub.platform)}</span>
                          </div>
                          <div className="text-base sm:text-lg font-black text-white">{mySub.creatorName} ({mySub.handle})</div>
                          <div className="text-xs text-slate-300 mt-0.5 flex flex-wrap items-center gap-3">
                            <span>Verified Views: <strong className="text-white font-mono">{(mySub.verifiedViews || mySub.claimedViews).toLocaleString()}</strong></span>
                            <span>•</span>
                            <span>Prize: {getRankBadge(myRankIdx)}</span>
                          </div>
                        </div>
                      </div>

                      <a
                        href={mySub.videoUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="px-4 py-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs uppercase tracking-wider transition text-center shrink-0 cursor-pointer"
                      >
                        Watch Live Drop ↗
                      </a>
                    </div>
                  );
                }

                return (
                  <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between text-xs text-slate-400">
                    <span>No submission found under <strong className="text-white">{myTrackedHandle}</strong> yet.</span>
                    <button
                      type="button"
                      onClick={() => setIsSubmitModalOpen(true)}
                      className="text-emerald-400 font-bold hover:underline cursor-pointer"
                    >
                      Submit Video Drop ↗
                    </button>
                  </div>
                );
              })()}
            </div>

            {/* Platform & Topic Filter Tabs */}
            <div className="flex flex-col md:flex-row items-center justify-between gap-4">
              {/* Platform Tabs */}
              <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto pb-2 md:pb-0">
                {(['all', 'tiktok', 'instagram', 'youtube'] as const).map((tab) => (
                  <button
                    key={tab}
                    type="button"
                    onClick={() => setActiveTab(tab)}
                    className={`px-4 py-2 rounded-xl text-xs font-bold uppercase transition cursor-pointer ${
                      activeTab === tab
                        ? 'bg-emerald-500 text-slate-950 shadow-md'
                        : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
                    }`}
                  >
                    {tab === 'all' ? 'All Platforms' : tab === 'instagram' ? 'Reels' : tab === 'youtube' ? 'Shorts' : 'TikTok'}
                  </button>
                ))}
              </div>

              {/* Topic Filter Tabs */}
              <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto">
                {(['all', 'renters', 'property_purchase'] as const).map((t) => (
                  <button
                    key={t}
                    type="button"
                    onClick={() => setTopicFilter(t)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer ${
                      topicFilter === t
                        ? 'bg-amber-500/20 text-amber-300 border border-amber-500/50'
                        : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
                    }`}
                  >
                    {t === 'all' ? 'All Topics' : t === 'renters' ? '🏠 Renters' : '🏢 Property Purchase'}
                  </button>
                ))}
              </div>
            </div>

            {/* LEADERBOARD TABLE */}
            <div className="bg-slate-900/90 border border-slate-800 rounded-3xl overflow-hidden shadow-2xl backdrop-blur-xl">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead className="bg-slate-950/90 text-slate-400 text-xs uppercase tracking-wider border-b border-slate-800">
                    <tr>
                      <th className="py-4 px-6">Rank</th>
                      <th className="py-4 px-6">Creator &amp; Handle</th>
                      <th className="py-4 px-6">Platform</th>
                      <th className="py-4 px-6 text-right">Verified Views</th>
                      <th className="py-4 px-6 text-center">Prize Status</th>
                      <th className="py-4 px-6 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60">
                    {filtered.length === 0 ? (
                      <tr>
                        <td colSpan={6} className="py-16 text-center">
                          <div className="max-w-md mx-auto flex flex-col items-center">
                            <div className="w-16 h-16 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-3xl mb-4 shadow-lg shadow-emerald-950/50">
                              🏆
                            </div>
                            <h3 className="text-lg font-black text-white mb-2">
                              Season {cycleConfig.season || 1} Leaderboard is Officially Live!
                            </h3>
                            <p className="text-xs text-slate-300 mb-6 leading-relaxed">
                              Zero dummy data. All 20 prize slots are vacant! Post your video on TikTok, Reels, or Shorts centering on <strong>Renters</strong> or <strong>Property Purchase</strong> and claim the <strong>#1 Spot (₦200,000)</strong>!
                            </p>
                            <button
                              type="button"
                              onClick={() => setIsSubmitModalOpen(true)}
                              className="inline-flex items-center gap-2 px-6 py-3.5 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-400 hover:from-emerald-400 hover:to-teal-300 text-slate-950 font-black text-xs uppercase tracking-wider shadow-lg shadow-emerald-500/25 transition active:scale-95 cursor-pointer"
                            >
                              <Plus className="w-4 h-4 stroke-[3]" />
                              <span>Submit First Video Drop</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                    ) : (
                      filtered.map((sub, idx) => {
                        const isTop3 = idx < 3;
                        return (
                          <tr key={sub.id} className="hover:bg-slate-800/40 transition">
                            <td className="py-4 px-6">
                              <span
                                className={`font-mono font-black text-sm ${
                                  idx === 0
                                    ? 'text-yellow-400'
                                    : idx === 1
                                    ? 'text-slate-300'
                                    : idx === 2
                                    ? 'text-amber-500'
                                    : idx < 20
                                    ? 'text-emerald-400'
                                    : 'text-slate-500'
                                }`}
                              >
                                #{idx + 1}
                              </span>
                            </td>
                            <td className="py-4 px-6">
                              <div className="font-bold text-white flex items-center gap-1.5">
                                <span>{sub.creatorName}</span>
                                {isTop3 && <Sparkles className="w-3.5 h-3.5 text-amber-400" />}
                              </div>
                              <div className="text-xs text-emerald-400 font-semibold flex items-center gap-1.5 mt-0.5">
                                <span>{sub.handle}</span>
                                <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                                  🏷️ Tagged
                                </span>
                              </div>
                              {sub.referralCode && (
                                <div className="text-[10px] text-amber-300 font-mono mt-0.5">
                                  Ref: {sub.referralCode}
                                </div>
                              )}
                            </td>
                            <td className="py-4 px-6">
                              <span className="uppercase font-bold text-[10px] px-2 py-0.5 rounded bg-slate-800 text-slate-300">
                                {getPlatformLabel(sub.platform)}
                              </span>
                            </td>
                            <td className="py-4 px-6 text-right">
                              <span className="font-black text-white text-base">
                                {(sub.verifiedViews || sub.claimedViews).toLocaleString()}
                              </span>
                            </td>
                            <td className="py-4 px-6 text-center">
                              {getRankBadge(idx)}
                            </td>
                            <td className="py-4 px-6 text-right">
                              <a
                                href={sub.videoUrl}
                                target="_blank"
                                rel="noreferrer"
                                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-xs font-bold text-slate-300 hover:text-white transition cursor-pointer"
                              >
                                <Play className="w-3 h-3 text-emerald-400" />
                                <span>Watch</span>
                              </a>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}
        {/* Corporate Comprehensive Footer */}
        <footer className="mt-20 border-t border-slate-800/80 bg-slate-950 pt-16 pb-12">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-10 pb-12 border-b border-slate-800/60">
              {/* Brand Col */}
              <div className="md:col-span-1 space-y-4">
                <div className="flex items-center gap-2.5">
                  <div className="w-10 h-10 rounded-xl bg-slate-900 border border-emerald-400/30 p-1 flex items-center justify-center overflow-hidden shrink-0">
                    <img src="/logo.png" alt="Rentilly" className="w-full h-full object-contain" />
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

              {/* Contest Prizes Col */}
              <div>
                <h4 className="text-xs font-black uppercase tracking-wider text-white mb-4">Official Prizes</h4>
                <ul className="space-y-2.5 text-xs text-slate-400">
                  <li className="flex justify-between items-center">
                    <span>🥇 1st Place Champion</span>
                    <strong className="text-yellow-400">₦200,000</strong>
                  </li>
                  <li className="flex justify-between items-center">
                    <span>🥈 2nd Place</span>
                    <strong className="text-slate-200">₦150,000</strong>
                  </li>
                  <li className="flex justify-between items-center">
                    <span>🥉 3rd Place</span>
                    <strong className="text-amber-400">₦100,000</strong>
                  </li>
                  <li className="flex justify-between items-center">
                    <span>🎁 Ranks 4th – 20th</span>
                    <strong className="text-emerald-400">₦10,000 each</strong>
                  </li>
                  <li className="flex justify-between items-center pt-1 border-t border-slate-800">
                    <span>App Referrals</span>
                    <strong className="text-amber-300">Earn per sign-up</strong>
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

              {/* Creator Support & Follow Links */}
              <div>
                                <h4 className="text-xs font-black uppercase tracking-wider text-white mb-4">Official Channels</h4>
                <p className="text-xs text-slate-400 leading-relaxed mb-3">
                  Follow our official channels for winner broadcasts and payouts:
                </p>
                <div className="space-y-1.5 text-xs text-slate-300">
                  <div>Instagram: <a href="https://www.instagram.com/renti_lly" target="_blank" rel="noreferrer" className="text-emerald-400 hover:underline">@renti_lly</a></div>
                  <div>TikTok: <a href="https://www.tiktok.com/@rentilly" target="_blank" rel="noreferrer" className="text-emerald-400 hover:underline">@rentilly</a></div>
                  <div>X: <a href="https://x.com/rentilly?s=11" target="_blank" rel="noreferrer" className="text-emerald-400 hover:underline">@rentilly</a></div>
                  <div>Facebook: <a href="https://www.facebook.com/profile.php" target="_blank" rel="noreferrer" className="text-emerald-400 hover:underline">Rentilly Page</a></div>
                  <div>LinkedIn: <a href="https://www.linkedin.com/company/rentilly/" target="_blank" rel="noreferrer" className="text-emerald-400 hover:underline">Rentilly Global</a></div>
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

        {/* MOBILE STICKY BOTTOM NAVIGATION BAR WITH ICONS */}
        <div className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-slate-900/95 backdrop-blur-md border-t border-slate-800 px-2 py-2 flex items-center justify-around shadow-2xl">
          <button
            onClick={() => navigateTo('leaderboard')}
            className="flex flex-col items-center gap-1 text-[10px] font-bold text-slate-400 hover:text-emerald-400 transition"
          >
            <Trophy className="w-4 h-4 text-amber-400" />
            <span>Ranks</span>
          </button>

          <button
            onClick={() => scrollToSection('prizes')}
            className="flex flex-col items-center gap-1 text-[10px] font-bold text-slate-400 hover:text-emerald-400 transition"
          >
            <Gift className="w-4 h-4 text-emerald-400" />
            <span>Prizes</span>
          </button>

          {/* Central Pulsing Submit Button */}
          <button
            onClick={() => setIsSubmitModalOpen(true)}
            className="flex flex-col items-center -mt-5 bg-gradient-to-r from-emerald-500 to-emerald-600 text-slate-950 font-black p-3 rounded-full shadow-lg shadow-emerald-500/40 border-2 border-slate-950 active:scale-95 transition"
          >
            <Plus className="w-5 h-5 stroke-[3]" />
          </button>

          <button
            onClick={() => scrollToSection('socials')}
            className="flex flex-col items-center gap-1 text-[10px] font-bold text-slate-400 hover:text-emerald-400 transition"
          >
            <Share2 className="w-4 h-4 text-pink-400" />
            <span>Follow</span>
          </button>

          <button
            onClick={() => scrollToSection('rules')}
            className="flex flex-col items-center gap-1 text-[10px] font-bold text-slate-400 hover:text-emerald-400 transition"
          >
            <BookOpen className="w-4 h-4 text-cyan-400" />
            <span>Rules</span>
          </button>
        </div>

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

              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 rounded-xl bg-slate-950 border border-emerald-500/30 p-1 shrink-0 overflow-hidden flex items-center justify-center">
                  <img src="/logo.png" alt="Rentilly" className="w-full h-full object-contain" />
                </div>
                <div>
                  <div className="flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                    <span className="text-[11px] font-bold text-emerald-400 uppercase tracking-wider">
                      Leaderboard Drop
                    </span>
                  </div>
                  <h2 className="text-xl font-black text-white">Submit Your Video Link</h2>
                </div>
              </div>
              <p className="text-xs text-slate-400 mb-6">
                Drop your live video link so our view tracker starts ranking your video on the leaderboard.
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
                    className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-emerald-500"
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
                      className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-emerald-500"
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
                      <option value="twitter">X (Twitter)</option>
                    </select>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-bold text-slate-300 uppercase mb-1">Rentilly Referral Code</label>
                    <input
                      type="text"
                      placeholder="e.g. TUNDE10"
                      value={formData.referralCode}
                      onChange={(e) => setFormData({ ...formData, referralCode: e.target.value.toUpperCase() })}
                      className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white uppercase font-mono focus:outline-none focus:border-emerald-500"
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
                      className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-emerald-500"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-300 uppercase mb-1">
                    Contest Topic Category * (Renters &amp; Property Purchase Only)
                  </label>
                  <select
                    required
                    value={(formData as any).topicCategory || 'renters'}
                    onChange={(e) => setFormData({ ...formData, topicCategory: e.target.value } as any)}
                    className="w-full px-4 py-2.5 bg-slate-950 border border-emerald-500/40 rounded-xl text-xs sm:text-sm text-white focus:outline-none focus:border-emerald-400 cursor-pointer"
                  >
                    <option value="renters">🏠 Renters — Finding, Renting &amp; Leasing Verified Apartments on Rentilly</option>
                    <option value="property_purchase">🏢 Property Purchase — Buying Verified Houses, Land &amp; Escrow Sales</option>
                  </select>
                  <p className="text-[10px] text-amber-300 font-medium mt-1">
                    ⚠️ Videos must center exclusively on Renters or Property Purchase to qualify for prizes.
                  </p>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-300 uppercase mb-1">Video Live URL *</label>
                  <input
                    type="url"
                    required
                    placeholder="https://www.tiktok.com/@... or instagram.com/reel/..."
                    value={formData.videoUrl}
                    onChange={(e) => setFormData({ ...formData, videoUrl: e.target.value })}
                    className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-300 uppercase mb-1">Current Views</label>
                  <input
                    type="number"
                    placeholder="e.g. 15000"
                    value={formData.claimedViews}
                    onChange={(e) => setFormData({ ...formData, claimedViews: e.target.value })}
                    className="w-full px-4 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>

                {/* MANDATORY SOCIAL FOLLOW & TAG VERIFICATION CHECKBOXES */}
                <div className="p-3.5 bg-slate-950 border border-amber-500/40 rounded-2xl space-y-2">
                  <label className="flex items-start gap-2.5 cursor-pointer">
                    <input
                      type="checkbox"
                      required
                      checked={formData.hasFollowed}
                      onChange={(e) => setFormData({ ...formData, hasFollowed: e.target.checked })}
                      className="mt-0.5 w-4 h-4 rounded text-emerald-500 focus:ring-emerald-400 bg-slate-900 border-slate-700 cursor-pointer"
                    />
                    <span className="text-xs text-slate-200 leading-snug">
                      <strong className="text-amber-300">Mandatory Condition #1:</strong> I confirm that I follow <strong>@renti_lly</strong> on Instagram and/or <strong>@rentilly</strong> on TikTok/X to be eligible for cash prizes.
                    </span>
                  </label>
                  <input
                    type="text"
                    placeholder="Your handle used to follow us (e.g. @your_account)"
                    value={formData.followHandle}
                    onChange={(e) => setFormData({ ...formData, followHandle: e.target.value })}
                    className="w-full px-3 py-1.5 bg-slate-900 border border-slate-800 rounded-lg text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-400"
                  />
                </div>

                {/* MANDATORY TAG RENTILLY IN VIDEO & CAPTION CHECKBOX */}
                <div className="p-3.5 bg-slate-950 border-2 border-emerald-500/60 rounded-2xl space-y-2.5 shadow-lg shadow-emerald-950/40">
                  <label className="flex items-start gap-2.5 cursor-pointer">
                    <input
                      type="checkbox"
                      required
                      checked={(formData as any).hasTaggedRentilly}
                      onChange={(e) => setFormData({ ...formData, hasTaggedRentilly: e.target.checked } as any)}
                      className="mt-0.5 w-4 h-4 rounded text-emerald-500 focus:ring-emerald-400 bg-slate-900 border-slate-700 cursor-pointer"
                    />
                    <span className="text-xs text-white leading-snug">
                      <strong className="text-emerald-400">Mandatory Condition #2:</strong> I have <strong>tagged Rentilly in my video &amp; caption</strong> ({formData.platform === 'instagram' ? '@renti_lly' : '@rentilly'}) so viewers can tap directly to your pages.
                    </span>
                  </label>
                  <div className="flex items-center justify-between text-xs bg-slate-900 px-3 py-2 rounded-xl border border-slate-800">
                    <span className="text-slate-400">Required Tag:</span>
                    <span className="font-mono font-black text-emerald-300 bg-emerald-950/60 border border-emerald-500/40 px-2 py-0.5 rounded">
                      {formData.platform === 'instagram' ? '@renti_lly' : '@rentilly'}
                    </span>
                  </div>
                </div>

                {/* Bank Payout Info */}
                <div className="pt-2 border-t border-slate-800">
                  <span className="block text-xs font-bold text-amber-400 uppercase mb-2">
                    Bank Payout Details (For Cash Disbursal)
                  </span>
                  <div className="grid grid-cols-3 gap-2">
                    <input
                      type="text"
                      placeholder="Bank Name"
                      value={formData.bankName}
                      onChange={(e) => setFormData({ ...formData, bankName: e.target.value })}
                      className="px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white"
                    />
                    <input
                      type="text"
                      placeholder="Account No"
                      value={formData.accountNumber}
                      onChange={(e) => setFormData({ ...formData, accountNumber: e.target.value })}
                      className="px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white"
                    />
                    <input
                      type="text"
                      placeholder="Account Name"
                      value={formData.accountName}
                      onChange={(e) => setFormData({ ...formData, accountName: e.target.value })}
                      className="px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  className="w-full py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-slate-950 font-black text-sm shadow-xl shadow-emerald-500/20 transition transform hover:scale-[1.02] cursor-pointer"
                >
                  🚀 Submit Video &amp; Join Leaderboard
                </button>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
