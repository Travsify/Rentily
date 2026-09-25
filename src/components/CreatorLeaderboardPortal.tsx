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
  Share2,
  Copy,
  Download,
  Rocket,
  Palette,
  Check,
  ShieldCheck,
  Volume2,
  Video,
  Clock,
  ArrowRight,
  XCircle
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

  // Tier-1 Global Standards States
  const [isKitModalOpen, setIsKitModalOpen] = useState(false);
  const [isBadgeModalOpen, setIsBadgeModalOpen] = useState(false);
  const [badgeCreator, setBadgeCreator] = useState<CreatorSubmission | null>(null);
  const [activeCaptionTopic, setActiveCaptionTopic] = useState<'renters' | 'property_purchase'>('renters');
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

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
    ugcRightsGranted: false,
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

  const copyToClipboard = (text: string, key: string, label: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    showToast(`✅ Copied: ${label}`);
    setTimeout(() => setCopiedKey(null), 2500);
  };

  const handleBoost = (id: string, e?: React.MouseEvent) => {
    e?.stopPropagation();
    const res = CreatorBountyService.boostSubmission(id);
    if (res.success) {
      try {
        confetti({
          particleCount: 60,
          spread: 70,
          origin: { y: 0.7 }
        });
      } catch {}
      setSubmissions((prev) =>
        prev.map((s) => (s.id === id ? { ...s, boostsCount: res.newCount } : s))
      );
      showToast(res.message);
    } else {
      showToast(res.message);
    }
  };

  const openBadgeModal = (creator: CreatorSubmission, e?: React.MouseEvent) => {
    e?.stopPropagation();
    setBadgeCreator(creator);
    setIsBadgeModalOpen(true);
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

    if (!formData.ugcRightsGranted) {
      alert('Please accept the Commercial UGC Rights License to qualify for prize payouts.');
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
        ugcRightsGranted: formData.ugcRightsGranted,
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

    // Prepare contestant badge
    const createdEntry: CreatorSubmission = {
      id: 'sub-' + Date.now(),
      creatorName: formData.creatorName,
      handle: formData.handle.startsWith('@') ? formData.handle : `@${formData.handle}`,
      platform: formData.platform,
      videoUrl: formData.videoUrl,
      claimedViews: views,
      verifiedViews: views,
      phone: formData.phone,
      bountyStatus: 'under_review',
      payoutAmount: 0,
      boostsCount: 0,
      ugcRightsGranted: true,
      createdAt: new Date().toISOString()
    };
    setBadgeCreator(createdEntry);
    setIsBadgeModalOpen(true);

    showToast(`🎉 Video drop submitted! You're now live on the Leaderboard as ${formData.handle}!`);

    setFormData({
      topicCategory: 'renters',
      creatorName: '',
      handle: '',
      referralCode: '',
      followHandle: '',
      hasFollowed: false,
      hasTaggedRentilly: false,
      ugcRightsGranted: false,
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
    if (pageView !== 'landing') {
      navigateTo('landing');
      setTimeout(() => {
        const el = document.getElementById(id);
        if (el) el.scrollIntoView({ behavior: 'smooth' });
      }, 150);
      return;
    }
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans selection:bg-emerald-500 selection:text-white flex flex-col justify-between pb-28 md:pb-12">
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
          <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 h-16 sm:h-20 flex items-center justify-between">
            <div className="flex items-center gap-2 sm:gap-3.5">
              <a href="https://myrentilly.com" target="_blank" rel="noreferrer" className="flex items-center gap-2 sm:gap-3">
                <div className="w-9 h-9 sm:w-11 sm:h-11 rounded-xl sm:rounded-2xl bg-slate-900 border-2 border-emerald-400/40 p-1 sm:p-1.5 shadow-lg shadow-emerald-900/30 flex items-center justify-center overflow-hidden shrink-0">
                  <img src="/logo.png" alt="Rentilly" className="w-full h-full object-contain" />
                </div>
                <div>
                  <div className="flex items-center gap-1.5 sm:gap-2">
                    <span className="text-base sm:text-xl font-extrabold tracking-wider bg-gradient-to-r from-emerald-400 to-amber-300 bg-clip-text text-transparent">
                      RENTILLY
                    </span>
                    <span className="hidden xs:inline-block px-2 py-0.5 text-[9px] sm:text-[10px] font-mono font-bold uppercase tracking-wider bg-amber-500/20 text-amber-300 border border-amber-500/40 rounded-full">
                      CREATOR CONTEST
                    </span>
                  </div>
                  <p className="hidden md:block text-[11px] text-slate-400">Open to All Nigerian Creators &amp; Influencers</p>
                </div>
              </a>
            </div>

            <div className="flex items-center gap-1.5 sm:gap-3">
              {pageView === 'landing' ? (
                <>
                  <button
                    onClick={() => navigateTo('leaderboard')}
                    className="flex items-center gap-1 sm:gap-1.5 px-2.5 sm:px-4 py-2 sm:py-2.5 rounded-xl bg-gradient-to-r from-amber-500/20 to-emerald-500/20 hover:from-amber-500/30 hover:to-emerald-500/30 text-amber-300 border border-amber-500/40 text-xs font-extrabold tracking-wide transition cursor-pointer shadow-lg shadow-amber-950/40"
                    title="Open Dedicated Leaderboard Page"
                  >
                    <Trophy className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-amber-400" />
                    <span className="hidden sm:inline">Leaderboard</span>
                    <span className="sm:hidden text-xs">Board</span>
                    <span className="w-1.5 h-1.5 sm:w-2 sm:h-2 rounded-full bg-emerald-400 animate-ping ml-0.5" />
                  </button>

                  <button
                    onClick={() => setIsKitModalOpen(true)}
                    className="hidden md:flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-800/80 hover:bg-slate-800 text-xs font-bold text-emerald-300 border border-emerald-500/30 transition cursor-pointer"
                    title="Download Official Logos, Colors & Creator Kit"
                  >
                    <Palette className="w-3.5 h-3.5 text-emerald-400" />
                    <span>Media Kit</span>
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
                    className="flex items-center gap-1 sm:gap-1.5 px-2.5 sm:px-4 py-2 sm:py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 text-xs font-bold transition cursor-pointer"
                  >
                    <span className="hidden sm:inline">← Back to Contest Rules</span>
                    <span className="sm:hidden text-xs">← Rules</span>
                  </button>
                  <button
                    onClick={handleManualRefresh}
                    disabled={isRefreshing}
                    className="flex items-center gap-1 sm:gap-1.5 px-2 sm:px-3.5 py-2 sm:py-2.5 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-bold transition cursor-pointer"
                    title="Refresh Live Leaderboard Views"
                  >
                    <RotateCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
                    <span className="hidden sm:inline">Refresh</span>
                  </button>
                </>
              )}

              <button
                onClick={() => setIsSubmitModalOpen(true)}
                className="px-3 sm:px-6 py-2 sm:py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-slate-950 font-extrabold text-xs sm:text-sm shadow-lg shadow-emerald-500/20 flex items-center gap-1.5 sm:gap-2 transition-all transform hover:scale-105 active:scale-95 cursor-pointer shrink-0"
              >
                <Plus className="w-3.5 h-3.5 sm:w-4 sm:h-4 stroke-[3]" />
                <span className="hidden sm:inline">Submit Video Drop</span>
                <span className="sm:hidden text-xs">Submit</span>
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

                {/* 48-Hour Disbursal SLA Badge */}
                <div className="mt-6 inline-flex items-center gap-2 px-4 py-2.5 rounded-2xl bg-slate-900/90 border border-emerald-500/40 text-xs text-slate-300 shadow-xl max-w-2xl mx-auto">
                  <Clock className="w-4 h-4 text-emerald-400 shrink-0" />
                  <span>⚡ <strong>Guaranteed 48-Hour Disbursals:</strong> All 20 cash prizes are paid straight to winners' Nigerian bank accounts (GTBank, Zenith, Access, Kuda, OPay, PalmPay) within 48 hours of season close.</span>
                </div>
              </div>
            </section>

            {/* 3-WEEK CONTEST COUNTDOWN & APPROVED TOPIC ANNOUNCEMENT BANNER */}
            <section className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 -mt-6 mb-8 relative z-25">
              <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-emerald-950 via-slate-900 to-teal-950 border-2 border-emerald-500/50 p-4 sm:p-8 shadow-2xl shadow-emerald-950/60 backdrop-blur-xl">
                <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
                  <div className="space-y-2.5">
                    <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/20 border border-emerald-400/40 text-emerald-300 text-xs font-black uppercase tracking-wider">
                      <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                      Season {cycleConfig.season || 1} • 3-Week Creator Sprint
                    </div>
                    <h2 className="text-xl sm:text-3xl font-black text-white">
                      {cycleConfig.isActive ? 'Contest Sprint Closes In:' : 'Season Review In Progress'}
                    </h2>
                    <div className="flex flex-wrap items-center gap-2 text-xs sm:text-sm text-amber-300 font-extrabold bg-amber-500/15 border border-amber-500/40 px-3 py-1.5 rounded-xl w-fit">
                      <span>🎯 Mandatory Video Scope:</span>
                      <span className="text-white underline decoration-amber-400">Renters &amp; Property Purchase Only</span>
                    </div>
                    <p className="text-xs text-slate-300 max-w-xl leading-relaxed">
                      The contest runs in <strong>3-week recurring seasons</strong>! Your video must center exclusively on either <strong>Renters</strong> (finding, renting, leasing verified homes) or <strong>Property Purchase</strong> (buying houses, land, title verification &amp; escrow sales).
                    </p>
                  </div>

                  {/* Countdown Digital Blocks (Visible if Active) */}
                  {cycleConfig.isActive ? (
                    <div className="flex flex-col items-center gap-2 w-full sm:w-auto">
                      <div className="grid grid-cols-4 gap-1.5 sm:gap-3 text-center w-full sm:w-auto">
                        <div className="bg-slate-950/90 border border-emerald-500/40 rounded-xl sm:rounded-2xl p-2 sm:p-4 min-w-[58px] sm:min-w-[85px] shadow-lg">
                          <div className="text-xl sm:text-4xl font-black text-white font-mono">{timeLeft.days}</div>
                          <div className="text-[9px] sm:text-xs font-bold text-emerald-400 uppercase tracking-wider mt-0.5 sm:mt-1">Days</div>
                        </div>
                        <div className="bg-slate-950/90 border border-emerald-500/40 rounded-xl sm:rounded-2xl p-2 sm:p-4 min-w-[58px] sm:min-w-[85px] shadow-lg">
                          <div className="text-xl sm:text-4xl font-black text-white font-mono">{timeLeft.hours}</div>
                          <div className="text-[9px] sm:text-xs font-bold text-emerald-400 uppercase tracking-wider mt-0.5 sm:mt-1">Hours</div>
                        </div>
                        <div className="bg-slate-950/90 border border-emerald-500/40 rounded-xl sm:rounded-2xl p-2 sm:p-4 min-w-[58px] sm:min-w-[85px] shadow-lg">
                          <div className="text-xl sm:text-4xl font-black text-white font-mono">{timeLeft.minutes}</div>
                          <div className="text-[9px] sm:text-xs font-bold text-emerald-400 uppercase tracking-wider mt-0.5 sm:mt-1">Mins</div>
                        </div>
                        <div className="bg-slate-950/90 border border-emerald-500/40 rounded-xl sm:rounded-2xl p-2 sm:p-4 min-w-[58px] sm:min-w-[85px] shadow-lg">
                          <div className="text-xl sm:text-4xl font-black text-emerald-300 font-mono animate-pulse">{timeLeft.seconds}</div>
                          <div className="text-[9px] sm:text-xs font-bold text-emerald-400 uppercase tracking-wider mt-0.5 sm:mt-1">Secs</div>
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
                    className="w-full sm:w-auto px-6 py-4 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-400 hover:from-emerald-400 hover:to-teal-300 text-slate-950 font-black text-xs uppercase tracking-wider shadow-lg shadow-emerald-500/30 transition transform hover:-translate-y-0.5 active:scale-95 flex items-center justify-center gap-2 cursor-pointer shrink-0"
                  >
                    <Plus className="w-4 h-4 stroke-[3]" />
                    <span>Submit Video Drop</span>
                  </button>
                </div>
              </div>
            </section>

            {/* 4-STEP ACTION ROADMAP: SHOOT -> POST & TAG -> SUBMIT -> WIN (30-SECOND CLARITY) */}
            <section id="how-it-works" className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 mb-12 relative z-20">
              <div className="bg-gradient-to-br from-slate-900 via-slate-900 to-emerald-950/70 border-2 border-emerald-500/40 rounded-3xl p-6 sm:p-10 shadow-2xl backdrop-blur-xl">
                <div className="text-center max-w-2xl mx-auto mb-8 sm:mb-10">
                  <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/20 border border-emerald-400/40 text-emerald-300 text-xs font-black uppercase tracking-wider mb-2">
                    <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                    How It Works in 30 Seconds
                  </div>
                  <h2 className="text-2xl sm:text-4xl font-black text-white">
                    4 Steps to Win Cash
                  </h2>
                  <p className="text-xs sm:text-sm text-slate-300 mt-2">
                    Zero complicated legal jargon. From video creation to cash in your bank account in 4 simple moves.
                  </p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
                  {/* Step 1: Shoot */}
                  <div className="bg-slate-950/90 border border-slate-800 hover:border-emerald-500/50 rounded-2xl p-5 sm:p-6 transition group flex flex-col justify-between relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-20 h-20 bg-emerald-500/5 rounded-bl-full pointer-events-none" />
                    <div>
                      <div className="flex items-center justify-between mb-4">
                        <span className="w-10 h-10 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 font-mono font-black text-sm flex items-center justify-center">
                          01
                        </span>
                        <Video className="w-5 h-5 text-emerald-400" />
                      </div>
                      <h3 className="text-base font-black text-white mb-2 group-hover:text-emerald-400 transition">
                        Shoot 🎬
                      </h3>
                      <p className="text-xs text-slate-400 leading-relaxed">
                        Film a 15–60s video centered exclusively on <strong>Renters</strong> (verified homes, zero agent fees) or <strong>Property Purchase</strong> (verified titles, escrow protection).
                      </p>
                    </div>
                    <div className="mt-4 pt-3 border-t border-slate-800/80 text-[11px] font-bold text-emerald-400 flex items-center gap-1">
                      <span>Renters or Property</span>
                      <ArrowRight className="w-3 h-3" />
                    </div>
                  </div>

                  {/* Step 2: Post & Tag */}
                  <div className="bg-slate-950/90 border border-slate-800 hover:border-pink-500/50 rounded-2xl p-5 sm:p-6 transition group flex flex-col justify-between relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-20 h-20 bg-pink-500/5 rounded-bl-full pointer-events-none" />
                    <div>
                      <div className="flex items-center justify-between mb-4">
                        <span className="w-10 h-10 rounded-xl bg-pink-500/20 border border-pink-500/40 text-pink-300 font-mono font-black text-sm flex items-center justify-center">
                          02
                        </span>
                        <Share2 className="w-5 h-5 text-pink-400" />
                      </div>
                      <h3 className="text-base font-black text-white mb-2 group-hover:text-pink-400 transition">
                        Post &amp; Tag 🏷️
                      </h3>
                      <p className="text-xs text-slate-400 leading-relaxed">
                        Publish to <strong>TikTok, Reels, or Shorts</strong>. Tag <strong>@renti_lly</strong> (IG) or <strong>@rentilly</strong> (TikTok/X) in your video &amp; caption so fans can find us.
                      </p>
                    </div>
                    <div className="mt-4 pt-3 border-t border-slate-800/80 text-[11px] font-bold text-pink-400 flex items-center gap-1">
                      <span>Follow &amp; Tag Rentilly</span>
                      <ArrowRight className="w-3 h-3" />
                    </div>
                  </div>

                  {/* Step 3: Submit */}
                  <div className="bg-slate-950/90 border border-slate-800 hover:border-amber-500/50 rounded-2xl p-5 sm:p-6 transition group flex flex-col justify-between relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-20 h-20 bg-amber-500/5 rounded-bl-full pointer-events-none" />
                    <div>
                      <div className="flex items-center justify-between mb-4">
                        <span className="w-10 h-10 rounded-xl bg-amber-500/20 border border-amber-500/40 text-amber-300 font-mono font-black text-sm flex items-center justify-center">
                          03
                        </span>
                        <Rocket className="w-5 h-5 text-amber-400" />
                      </div>
                      <h3 className="text-base font-black text-white mb-2 group-hover:text-amber-400 transition">
                        Submit Drop 🚀
                      </h3>
                      <p className="text-xs text-slate-400 leading-relaxed">
                        Paste your live video link into the submission modal. Enter your Nigerian bank details so you are pre-cleared for cash prizes.
                      </p>
                    </div>
                    <div className="mt-4 pt-3 border-t border-slate-800/80 text-[11px] font-bold text-amber-400 flex items-center gap-1">
                      <span>Live View Tracking</span>
                      <ArrowRight className="w-3 h-3" />
                    </div>
                  </div>

                  {/* Step 4: Win & Disburse */}
                  <div className="bg-slate-950/90 border border-slate-800 hover:border-yellow-400/60 rounded-2xl p-5 sm:p-6 transition group flex flex-col justify-between relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-20 h-20 bg-yellow-500/5 rounded-bl-full pointer-events-none" />
                    <div>
                      <div className="flex items-center justify-between mb-4">
                        <span className="w-10 h-10 rounded-xl bg-yellow-500/20 border border-yellow-400/50 text-yellow-300 font-mono font-black text-sm flex items-center justify-center">
                          04
                        </span>
                        <Trophy className="w-5 h-5 text-yellow-400" />
                      </div>
                      <h3 className="text-base font-black text-white mb-2 group-hover:text-yellow-300 transition">
                        Win &amp; Get Paid 💰
                      </h3>
                      <p className="text-xs text-slate-400 leading-relaxed">
                        Top 20 creators by verified views split the cash pool. Payouts sent via direct bank transfer (NIP) within <strong>48 hours</strong> of sprint close!
                      </p>
                    </div>
                    <div className="mt-4 pt-3 border-t border-slate-800/80 text-[11px] font-bold text-yellow-400 flex items-center gap-1">
                      <span>48-Hr Bank Transfer</span>
                      <Check className="w-3 h-3 stroke-[3]" />
                    </div>
                  </div>
                </div>
              </div>
            </section>

            {/* DEDICATED LEADERBOARD GATEWAY CARD (SEPARATE PAGE PROMPT) */}
            <section className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 mb-12">
              <div className="bg-gradient-to-r from-slate-900 via-slate-900 to-emerald-950/80 border-2 border-amber-500/60 rounded-3xl p-5 sm:p-8 shadow-2xl flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
                <div className="flex flex-col sm:flex-row sm:items-center gap-4 sm:gap-5 w-full md:w-auto">
                  <div className="w-14 h-14 sm:w-16 sm:h-16 rounded-2xl bg-amber-500/20 border-2 border-amber-400 flex items-center justify-center text-2xl sm:text-3xl shrink-0 shadow-xl shadow-amber-950/60">
                    🏆
                  </div>
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-xs font-black uppercase text-amber-400 tracking-wider">
                        Dedicated Leaderboard Page
                      </span>
                      <span className="px-2 py-0.5 rounded-full text-[9px] sm:text-[10px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
                        Live Auto-Refresh
                      </span>
                    </div>
                    <h3 className="text-lg sm:text-2xl font-black text-white">
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
                  className="w-full md:w-auto px-6 py-4 rounded-2xl bg-gradient-to-r from-amber-400 via-amber-500 to-yellow-400 hover:from-amber-300 hover:to-yellow-300 text-slate-950 font-black text-xs sm:text-sm uppercase tracking-wider shadow-xl shadow-amber-500/30 transition transform hover:scale-105 active:scale-95 flex items-center justify-center gap-2 shrink-0 cursor-pointer"
                >
                  <Trophy className="w-4 h-4 text-slate-950" />
                  <span>Open Full Leaderboard Page ↗</span>
                </button>
              </div>
            </section>

            {/* THE 2 APPROVED TOPICS SHOWCASE (CRYSTAL CLEAR DISCIPLINE) */}
            <section id="approved-topics" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-12 relative z-20">
              <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 sm:p-8 shadow-2xl backdrop-blur-xl">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-800">
                  <div>
                    <div className="flex items-center gap-2 mb-1.5">
                      <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider bg-amber-500/20 text-amber-300 border border-amber-500/40">
                        Strict Topic Policy
                      </span>
                      <span className="text-xs font-bold text-emerald-400">2 Official Categories Only</span>
                    </div>
                    <h2 className="text-2xl sm:text-3xl font-black text-white">
                      The 2 Approved Contest Content Topics
                    </h2>
                    <p className="text-xs sm:text-sm text-slate-300 mt-1 max-w-2xl leading-relaxed">
                      To qualify for the ₦200k prize pool, your video must focus strictly on one of these two real estate solutions. Generic or off-topic videos are disqualified.
                    </p>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
                  {/* Topic A: Renters */}
                  <div className="bg-gradient-to-br from-emerald-950/40 via-slate-950 to-slate-950 border-2 border-emerald-500/40 rounded-2xl p-6 space-y-4">
                    <div className="flex items-center gap-3">
                      <div className="w-12 h-12 rounded-xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-2xl shrink-0">
                        🏠
                      </div>
                      <div>
                        <span className="text-[10px] font-mono font-black uppercase text-emerald-400 tracking-wider">Topic Option A</span>
                        <h3 className="text-lg font-black text-white">Renters &amp; Tenants in Nigeria</h3>
                      </div>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed">
                      Highlight the pain of apartment hunting in Nigeria and how Rentilly solves it completely.
                    </p>
                    <div className="space-y-2 text-xs">
                      <div className="font-bold text-white text-xs">Suggested Angles &amp; Hooks:</div>
                      <ul className="space-y-1.5 text-slate-300">
                        <li className="flex items-start gap-2">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                          <span><strong>Zero Inspection Fees:</strong> Never pay ₦5,000–₦10,000 to agents just to see a dirty house.</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                          <span><strong>Verified 3D Virtual Tours:</strong> Tour genuine Lagos &amp; Abuja flats right from your phone.</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                          <span><strong>Direct Landlord Deals:</strong> Chat directly with verified landlords and sign digital leases.</span>
                        </li>
                      </ul>
                    </div>
                  </div>

                  {/* Topic B: Property Purchase */}
                  <div className="bg-gradient-to-br from-amber-950/30 via-slate-950 to-slate-950 border-2 border-amber-500/40 rounded-2xl p-6 space-y-4">
                    <div className="flex items-center gap-3">
                      <div className="w-12 h-12 rounded-xl bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-2xl shrink-0">
                        🏢
                      </div>
                      <div>
                        <span className="text-[10px] font-mono font-black uppercase text-amber-400 tracking-wider">Topic Option B</span>
                        <h3 className="text-lg font-black text-white">Property Purchase &amp; Investors</h3>
                      </div>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed">
                      Highlight safety in real estate investments, buying land, or acquiring homes without fear of fraud.
                    </p>
                    <div className="space-y-2 text-xs">
                      <div className="font-bold text-white text-xs">Suggested Angles &amp; Hooks:</div>
                      <ul className="space-y-1.5 text-slate-300">
                        <li className="flex items-start gap-2">
                          <CheckCircle2 className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                          <span><strong>Title Document Audits:</strong> Verified Governor's Consent, C of O, and Gazette audits.</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <CheckCircle2 className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                          <span><strong>Zero 'Omo-Onile' Scams:</strong> No violent land disputes or double-allocation heartbreak.</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <CheckCircle2 className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                          <span><strong>Escrow Milestone Sales:</strong> Buyer funds are safely held until all deed conditions are met.</span>
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>
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

            {/* VIRAL CREATOR TOOLKIT & 1-CLICK CAPTION COPIER (GLOBAL STANDARD) */}
            <section id="creator-toolkit" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-16 relative z-20">
              <div className="bg-gradient-to-br from-slate-900 via-slate-900 to-emerald-950/70 border-2 border-emerald-500/40 rounded-3xl p-6 sm:p-10 shadow-2xl backdrop-blur-xl">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-800">
                  <div>
                    <div className="flex items-center gap-2 mb-1.5">
                      <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
                        ⚡ Global Tier-1 Creator Tools
                      </span>
                      <span className="text-xs font-bold text-amber-400">100% Free Resources</span>
                    </div>
                    <h2 className="text-2xl sm:text-3xl font-black text-white">
                      Creator Toolkit: 1-Click Viral Captions &amp; Assets
                    </h2>
                    <p className="text-xs sm:text-sm text-slate-300 mt-1 max-w-2xl leading-relaxed">
                      Copy high-performing compliant captions with official tags in 1 click, or access the official Rentilly brand kit with transparent logos and hex codes.
                    </p>
                  </div>

                  <button
                    type="button"
                    onClick={() => setIsKitModalOpen(true)}
                    className="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-emerald-300 border border-emerald-500/40 text-xs font-black uppercase tracking-wider shadow-lg transition active:scale-95 cursor-pointer shrink-0"
                  >
                    <Palette className="w-4 h-4 text-emerald-400" />
                    <span>Open Media Kit &amp; Logos</span>
                  </button>
                </div>

                {/* 1-Click Caption Copier Box */}
                <div className="mt-8 space-y-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-bold uppercase tracking-wider text-slate-400">Select Topic:</span>
                      <div className="inline-flex p-1 bg-slate-950 border border-slate-800 rounded-xl">
                        <button
                          type="button"
                          onClick={() => setActiveCaptionTopic('renters')}
                          className={`px-3 py-1.5 rounded-lg text-xs font-black transition cursor-pointer ${
                            activeCaptionTopic === 'renters'
                              ? 'bg-emerald-500 text-slate-950 shadow-md'
                              : 'text-slate-400 hover:text-white'
                          }`}
                        >
                          🏠 Renters Topic
                        </button>
                        <button
                          type="button"
                          onClick={() => setActiveCaptionTopic('property_purchase')}
                          className={`px-3 py-1.5 rounded-lg text-xs font-black transition cursor-pointer ${
                            activeCaptionTopic === 'property_purchase'
                              ? 'bg-emerald-500 text-slate-950 shadow-md'
                              : 'text-slate-400 hover:text-white'
                          }`}
                        >
                          🏢 Property Purchase Topic
                        </button>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() =>
                        copyToClipboard(
                          '@renti_lly @rentilly #Rentilly #RentillyChallenge #NigeriaRealEstate #Renters #PropertySales',
                          'tags',
                          'Official Handles & Hashtags'
                        )
                      }
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 text-xs font-bold transition active:scale-95 cursor-pointer"
                    >
                      <Copy className="w-3.5 h-3.5 text-amber-400" />
                      <span>{copiedKey === 'tags' ? 'Copied Tags!' : 'Copy Tags Only'}</span>
                    </button>
                  </div>

                  {/* Caption Preview and Copy Container */}
                  <div className="bg-slate-950/90 border border-slate-800 rounded-2xl p-4 sm:p-5 relative group">
                    <div className="text-xs sm:text-sm text-slate-200 leading-relaxed font-mono whitespace-pre-wrap">
                      {activeCaptionTopic === 'renters'
                        ? `Tired of fake agents and inspection fee scams? 🏠 Real verified apartments with 3D tours and direct landlord leases are on @renti_lly! Download the Rentilly app now 📲 https://myrentilly.com\n\n#Rentilly #RentillyChallenge #NigeriaRealEstate #Renters #ApartmentHunting`
                        : `Stop buying land with 'family issues' or paying fake agents! 🏢 Verified title documents & property sales with escrow security on @renti_lly! Verified properties only on https://myrentilly.com\n\n#Rentilly #PropertySales #InvestNigeria #RentillyChallenge #RealEstateNigeria`}
                    </div>

                    <div className="mt-4 pt-3 border-t border-slate-800/80 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                      <div className="text-[11px] text-slate-400">
                        ⚡ Tip: Paste this directly into your TikTok or Instagram caption to guarantee you meet the tagging qualification rule!
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          const text =
                            activeCaptionTopic === 'renters'
                              ? `Tired of fake agents and inspection fee scams? 🏠 Real verified apartments with 3D tours and direct landlord leases are on @renti_lly! Download the Rentilly app now 📲 https://myrentilly.com\n\n#Rentilly #RentillyChallenge #NigeriaRealEstate #Renters #ApartmentHunting`
                              : `Stop buying land with 'family issues' or paying fake agents! 🏢 Verified title documents & property sales with escrow security on @renti_lly! Verified properties only on https://myrentilly.com\n\n#Rentilly #PropertySales #InvestNigeria #RentillyChallenge #RealEstateNigeria`;
                          copyToClipboard(text, activeCaptionTopic, `${activeCaptionTopic === 'renters' ? 'Renters' : 'Property Purchase'} Caption`);
                        }}
                        className="inline-flex items-center justify-center gap-2 px-4 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs uppercase tracking-wider shadow-lg shadow-emerald-500/20 transition active:scale-95 cursor-pointer shrink-0"
                      >
                        {copiedKey === activeCaptionTopic ? (
                          <>
                            <Check className="w-4 h-4 stroke-[3]" />
                            <span>Caption Copied!</span>
                          </>
                        ) : (
                          <>
                            <Copy className="w-4 h-4" />
                            <span>1-Click Copy Caption</span>
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </section>

            {/* ========================================================= */}
            {/* OFFICIAL CREATOR RULES, PLAYBOOK & FAQ (id="rules")       */}
            {/* ========================================================= */}
            <section id="rules" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-20 space-y-12">
              {/* Header Title & Subtitle */}
              <div className="text-center max-w-3xl mx-auto space-y-3">
                <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-black uppercase tracking-wider shadow-sm">
                  <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                  <span>Official Creator Blueprint &amp; Guidelines</span>
                </div>
                <h2 className="text-2xl sm:text-4xl font-black text-white tracking-tight">
                  How to Win, Rules of Engagement &amp; Creator Guide
                </h2>
                <p className="text-sm sm:text-base text-slate-300 leading-relaxed">
                  Everything you need to shoot, post, rank, and cash out your share of the{' '}
                  <strong className="text-emerald-400">₦600,000 season bounty pool</strong> in Nigeria.
                  Zero follower requirement — open to every creator!
                </p>
              </div>

              {/* 1. VISUAL 3 SIMPLE STEPS TO WIN (QUICK START ROADMAP) */}
              <div className="bg-gradient-to-br from-slate-900/90 via-slate-900 to-slate-950 border border-emerald-500/30 rounded-3xl p-6 sm:p-10 shadow-2xl relative overflow-hidden">
                <div className="absolute top-0 right-0 w-96 h-96 bg-emerald-500/5 rounded-full blur-3xl -z-10 pointer-events-none" />

                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8 pb-6 border-b border-slate-800">
                  <div>
                    <span className="text-xs font-black uppercase tracking-wider text-emerald-400 flex items-center gap-1.5">
                      <Rocket className="w-4 h-4 text-emerald-400" />
                      Quick Start Roadmap
                    </span>
                    <h3 className="text-xl sm:text-2xl font-black text-white mt-1">
                      3 Simple Steps to Win
                    </h3>
                  </div>
                  <div className="text-xs text-slate-400 bg-slate-950/90 border border-slate-800 px-4 py-2 rounded-xl flex items-center gap-2 w-fit">
                    <span>Sprint: <strong className="text-amber-400 font-black">21 Days</strong></span>
                    <span className="text-slate-600">•</span>
                    <span>Payout: <strong className="text-emerald-400 font-black">Within 48h</strong></span>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6 relative">
                  {/* Step 1 */}
                  <div className="relative flex flex-col justify-between bg-slate-950/80 border border-slate-800 hover:border-emerald-500/50 rounded-2xl p-6 transition duration-300 group">
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <span className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 font-black text-sm flex items-center justify-center group-hover:scale-110 transition shadow-inner">
                          01
                        </span>
                        <span className="text-[11px] font-bold uppercase tracking-wider text-emerald-400 bg-emerald-500/10 px-2.5 py-1 rounded-full border border-emerald-500/20">
                          30–60s Max
                        </span>
                      </div>
                      <h4 className="text-lg font-black text-white">Shoot &amp; Edit Your Video</h4>
                      <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
                        Pick either <strong className="text-emerald-300">🏠 Renters</strong> (avoiding fake inspection fees, 3D tours) or <strong className="text-amber-300">🏢 Property Purchase</strong> (verified title deeds, zero omo onile). Shoot a punchy 30–60s vertical video on TikTok, Reels, or X.
                      </p>
                    </div>
                    <div className="mt-5 pt-4 border-t border-slate-800/80 text-xs text-slate-400 flex items-start gap-2">
                      <span className="text-amber-400 font-bold shrink-0">💡 Tip:</span>
                      <span>Hook viewers in the first 3 seconds with a relatable Nigerian scenario.</span>
                    </div>
                  </div>

                  {/* Step 2 */}
                  <div className="relative flex flex-col justify-between bg-slate-950/80 border border-amber-500/40 hover:border-amber-400/70 rounded-2xl p-6 transition duration-300 group shadow-lg shadow-amber-950/20">
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <span className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-400 font-black text-sm flex items-center justify-center group-hover:scale-110 transition shadow-inner">
                          02
                        </span>
                        <span className="text-[11px] font-bold uppercase tracking-wider text-amber-400 bg-amber-500/10 px-2.5 py-1 rounded-full border border-amber-500/20">
                          Mandatory Tags
                        </span>
                      </div>
                      <h4 className="text-lg font-black text-white">Post &amp; Tag Correctly</h4>
                      <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
                        Tag <strong className="text-amber-300">@renti_lly</strong> on Instagram, <strong className="text-amber-300">@rentilly</strong> on TikTok &amp; X. Include <strong className="text-white">#RentillyChallenge</strong> and <strong className="text-white">myrentilly.com</strong> in your caption so our scanner links your view counter.
                      </p>
                    </div>
                    <div className="mt-5 pt-4 border-t border-slate-800/80">
                      <button
                        type="button"
                        onClick={() => scrollToSection('creator-toolkit')}
                        className="w-full inline-flex items-center justify-center gap-2 py-2 px-3 rounded-xl bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 text-xs font-bold transition active:scale-95 cursor-pointer"
                      >
                        <Copy className="w-3.5 h-3.5 text-amber-400" />
                        <span>Use 1-Click Caption Copier ↑</span>
                      </button>
                    </div>
                  </div>

                  {/* Step 3 */}
                  <div className="relative flex flex-col justify-between bg-slate-950/80 border border-slate-800 hover:border-emerald-500/50 rounded-2xl p-6 transition duration-300 group">
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <span className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 font-black text-sm flex items-center justify-center group-hover:scale-110 transition shadow-inner">
                          03
                        </span>
                        <span className="text-[11px] font-bold uppercase tracking-wider text-emerald-400 bg-emerald-500/10 px-2.5 py-1 rounded-full border border-emerald-500/20">
                          Direct Bank Payout
                        </span>
                      </div>
                      <h4 className="text-lg font-black text-white">Submit Link &amp; Get Paid</h4>
                      <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
                        Drop your video link on this portal and track your rank live. Top 20 creators are paid <strong className="text-emerald-400">directly to your Nigerian bank (GTB, Access, Zenith, OPay, PalmPay, Kuda)</strong> within 48 hours of season close!
                      </p>
                    </div>
                    <div className="mt-5 pt-4 border-t border-slate-800/80">
                      <button
                        type="button"
                        onClick={() => setIsSubmitModalOpen(true)}
                        className="w-full inline-flex items-center justify-center gap-2 py-2 px-3 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 text-xs font-black transition active:scale-95 cursor-pointer shadow-md"
                      >
                        <Rocket className="w-3.5 h-3.5" />
                        <span>Submit Video Link Now</span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              {/* 2. APPROVED TOPICS & VIDEO IDEAS WITH SAMPLE HOOKS */}
              <div className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-3">
                  <div>
                    <div className="inline-flex items-center gap-2 text-xs font-black uppercase tracking-wider text-amber-400 mb-1">
                      <Sparkles className="w-3.5 h-3.5" />
                      <span>Content Creation Goldmine</span>
                    </div>
                    <h3 className="text-2xl sm:text-3xl font-black text-white">
                      Approved Topics &amp; Video Ideas with Sample Hooks
                    </h3>
                  </div>
                  <p className="text-xs text-slate-400 max-w-md">
                    To qualify for the leaderboard and cash prizes, your video must focus on one of these two Nigerian real estate challenges:
                  </p>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  {/* Topic 1: Renters */}
                  <div className="bg-gradient-to-br from-slate-900 via-slate-950 to-slate-900 border border-emerald-500/40 rounded-3xl p-6 sm:p-8 space-y-6 flex flex-col justify-between shadow-xl">
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-black uppercase tracking-wider text-emerald-400 bg-emerald-500/10 px-3 py-1 rounded-full border border-emerald-500/20">
                          🏠 Topic 01 • Renters &amp; Tenants
                        </span>
                        <span className="text-xs text-slate-400 font-medium">High viral potential</span>
                      </div>

                      <h4 className="text-xl sm:text-2xl font-black text-white">
                        Finding Verified Apartments &amp; Avoiding Fake Agent Fees
                      </h4>

                      <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
                        Highlight the daily house-hunting struggles in Nigerian cities (Lagos, Abuja, Port Harcourt, Ibadan) and demonstrate how Rentilly makes renting effortless:
                      </p>

                      <ul className="space-y-3 text-xs sm:text-sm text-slate-300">
                        <li className="flex items-start gap-2.5">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                          <span><strong>Avoiding Fake Agent Fees:</strong> No paying ₦10,000–₦20,000 inspection fees to agents for occupied, non-existent, or fake flats.</span>
                        </li>
                        <li className="flex items-start gap-2.5">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                          <span><strong>Verified Apartments Only:</strong> Every rental listing on Rentilly is physically inspected and verified with accurate photos.</span>
                        </li>
                        <li className="flex items-start gap-2.5">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                          <span><strong>3D Virtual Tours:</strong> Inspect every room, parlor, and kitchen directly from your smartphone before leaving your house.</span>
                        </li>
                        <li className="flex items-start gap-2.5">
                          <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                          <span><strong>Direct Landlord Tenancy:</strong> Transparent digital agreements with direct landlord contact and zero middleman extortion.</span>
                        </li>
                      </ul>
                    </div>

                    {/* Viral Hook Box */}
                    <div className="bg-slate-950 border border-emerald-500/30 rounded-2xl p-4 sm:p-5 space-y-3">
                      <div className="flex items-center justify-between">
                        <span className="text-[11px] font-black uppercase tracking-wider text-emerald-400 flex items-center gap-1.5">
                          🔥 Sample Viral Hook (1-Click Copy):
                        </span>
                        <span className="text-[10px] text-slate-400">Ready to record</span>
                      </div>
                      <blockquote className="text-xs sm:text-sm text-emerald-200 font-mono italic bg-emerald-950/30 p-3.5 rounded-xl border border-emerald-800/40">
                        &ldquo;POV: Agent collected ₦10k inspection fee to show me a room that doesn't exist...&rdquo;
                      </blockquote>
                      <button
                        type="button"
                        onClick={() =>
                          copyToClipboard(
                            "POV: Agent collected ₦10k inspection fee to show me a room that doesn't exist...",
                            'hook_renters',
                            'Renters Sample Hook'
                          )
                        }
                        className="w-full inline-flex items-center justify-center gap-2 py-2 px-3 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 text-xs font-black transition active:scale-95 cursor-pointer shadow-md"
                      >
                        {copiedKey === 'hook_renters' ? (
                          <>
                            <Check className="w-3.5 h-3.5 stroke-[3]" />
                            <span>Hook Copied to Clipboard!</span>
                          </>
                        ) : (
                          <>
                            <Copy className="w-3.5 h-3.5" />
                            <span>1-Click Copy This Hook</span>
                          </>
                        )}
                      </button>
                    </div>
                  </div>

                  {/* Topic 2: Property Purchase */}
                  <div className="bg-gradient-to-br from-slate-900 via-slate-950 to-slate-900 border border-amber-500/40 rounded-3xl p-6 sm:p-8 space-y-6 flex flex-col justify-between shadow-xl">
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-black uppercase tracking-wider text-amber-400 bg-amber-500/10 px-3 py-1 rounded-full border border-amber-500/20">
                          🏢 Topic 02 • Property Purchase
                        </span>
                        <span className="text-xs text-slate-400 font-medium">High conversion value</span>
                      </div>

                      <h4 className="text-xl sm:text-2xl font-black text-white">
                        Buying Land &amp; Houses with Zero 'Omo Onile' Drama
                      </h4>

                      <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
                        Address the biggest fears of Nigerian property buyers at home and in the Diaspora, and show why Rentilly is the trusted platform for real estate:
                      </p>

                      <ul className="space-y-3 text-xs sm:text-sm text-slate-300">
                        <li className="flex items-start gap-2.5">
                          <CheckCircle2 className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                          <span><strong>Verified Title Deeds:</strong> Rigorous title auditing (C of O, Governor's Consent, Gazette) before buyer commits ₦1.</span>
                        </li>
                        <li className="flex items-start gap-2.5">
                          <CheckCircle2 className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                          <span><strong>Zero 'Omo Onile' Interference:</strong> Buy legitimate land with peace of mind — free from community grabbers or family disputes.</span>
                        </li>
                        <li className="flex items-start gap-2.5">
                          <CheckCircle2 className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                          <span><strong>Escrow Protection:</strong> Funds stay safely held in institutional legal escrow until verified title documents are handed over.</span>
                        </li>
                        <li className="flex items-start gap-2.5">
                          <CheckCircle2 className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                          <span><strong>Diaspora Friendly:</strong> Secure property and land acquisition in Nigeria without relatives diverting your hard-earned funds.</span>
                        </li>
                      </ul>
                    </div>

                    {/* Viral Hook Box */}
                    <div className="bg-slate-950 border border-amber-500/30 rounded-2xl p-4 sm:p-5 space-y-3">
                      <div className="flex items-center justify-between">
                        <span className="text-[11px] font-black uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
                          🔥 Sample Viral Hook (1-Click Copy):
                        </span>
                        <span className="text-[10px] text-slate-400">Ready to record</span>
                      </div>
                      <blockquote className="text-xs sm:text-sm text-amber-200 font-mono italic bg-amber-950/30 p-3.5 rounded-xl border border-amber-800/40">
                        &ldquo;How to buy property in Nigeria without land grabbers stealing your money...&rdquo;
                      </blockquote>
                      <button
                        type="button"
                        onClick={() =>
                          copyToClipboard(
                            "How to buy property in Nigeria without land grabbers stealing your money...",
                            'hook_property',
                            'Property Purchase Sample Hook'
                          )
                        }
                        className="w-full inline-flex items-center justify-center gap-2 py-2 px-3 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 text-xs font-black transition active:scale-95 cursor-pointer shadow-md"
                      >
                        {copiedKey === 'hook_property' ? (
                          <>
                            <Check className="w-3.5 h-3.5 stroke-[3]" />
                            <span>Hook Copied to Clipboard!</span>
                          </>
                        ) : (
                          <>
                            <Copy className="w-3.5 h-3.5" />
                            <span>1-Click Copy This Hook</span>
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              {/* 3. DO'S AND DON'TS SIDE-BY-SIDE */}
              <div id="dos-and-donts" className="space-y-6">
                <div className="text-center max-w-2xl mx-auto space-y-2">
                  <span className="text-xs font-black uppercase tracking-wider text-emerald-400">
                    Contest Integrity Standards
                  </span>
                  <h3 className="text-2xl sm:text-3xl font-black text-white">
                    Creator Do's &amp; Don'ts
                  </h3>
                  <p className="text-xs sm:text-sm text-slate-400">
                    Follow these guidelines to keep your submission eligible and maximize your leaderboard ranking.
                  </p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {/* DO'S CARD */}
                  <div className="bg-slate-950/90 border border-emerald-500/50 rounded-3xl p-6 sm:p-8 space-y-5 shadow-xl relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-500/10 rounded-full blur-2xl -z-10 pointer-events-none" />
                    <div className="flex items-center gap-3 pb-4 border-b border-emerald-900/50">
                      <div className="w-10 h-10 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 flex items-center justify-center shrink-0">
                        <CheckCircle className="w-6 h-6" />
                      </div>
                      <div>
                        <h4 className="text-lg font-black text-emerald-400 uppercase tracking-wide">
                          What To Do (Winning Path)
                        </h4>
                        <p className="text-xs text-slate-400">Guarantees quick audit approval &amp; ranking</p>
                      </div>
                    </div>

                    <ul className="space-y-3.5 text-xs sm:text-sm">
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✓</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Focus on Renters or Property Purchase:</strong> Address authentic Nigerian real estate scenarios (avoiding fake agent fees or secure land titles).
                        </div>
                      </li>
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✓</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Tag Official Accounts:</strong> Follow &amp; tag <strong>@renti_lly</strong> on Instagram, <strong>@rentilly</strong> on TikTok/X, and add <strong>#RentillyChallenge</strong> &amp; <strong>myrentilly.com</strong>.
                        </div>
                      </li>
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✓</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Share with Friends to Boost:</strong> Send your video link to WhatsApp groups, status, and Twitter to spark organic algorithmic momentum early.
                        </div>
                      </li>
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✓</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Keep it 30–60 Seconds:</strong> Snappy vertical videos with strong first-3-second retention perform best on Nigerian algorithms.
                        </div>
                      </li>
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✓</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Submit Multiple Entries:</strong> Submit as many videos as you like. Your single best-performing video claims your prize rank!
                        </div>
                      </li>
                    </ul>
                  </div>

                  {/* DON'TS CARD */}
                  <div className="bg-slate-950/90 border border-red-500/50 rounded-3xl p-6 sm:p-8 space-y-5 shadow-xl relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-red-500/10 rounded-full blur-2xl -z-10 pointer-events-none" />
                    <div className="flex items-center gap-3 pb-4 border-b border-red-900/50">
                      <div className="w-10 h-10 rounded-xl bg-red-500/20 border border-red-500/40 text-red-400 flex items-center justify-center shrink-0">
                        <XCircle className="w-6 h-6" />
                      </div>
                      <div>
                        <h4 className="text-lg font-black text-red-400 uppercase tracking-wide">
                          What NOT To Do (Instant DQ)
                        </h4>
                        <p className="text-xs text-slate-400">Strictly prohibited by automated crawlers</p>
                      </div>
                    </div>

                    <ul className="space-y-3.5 text-xs sm:text-sm">
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✕</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Don't Buy Fake Bot Views:</strong> Our anti-cheat crawler tracks watch-time velocity and flags artificial bot spikes. Bot views result in instant, permanent disqualification.
                        </div>
                      </li>
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✕</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Don't Post Off-Topic Content:</strong> Generic dance challenges, political commentary, or videos that don't discuss Rentilly, renting, or buying property will not be counted.
                        </div>
                      </li>
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✕</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Don't Forget to Follow Before Submitting:</strong> You must follow our official account on the platform where you post. Unfollowed entries cannot be paid out.
                        </div>
                      </li>
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✕</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Don't Set Account to Private:</strong> Private accounts or private videos cannot be verified by our automated scraper. Keep videos publicly visible.
                        </div>
                      </li>
                      <li className="flex items-start gap-3">
                        <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center shrink-0 mt-0.5 text-xs font-black">✕</span>
                        <div className="text-slate-300">
                          <strong className="text-white">Don't Delete Before Payout:</strong> Posts must remain live throughout the 3-week season and 48-hour post-sprint disbursal audit.
                        </div>
                      </li>
                    </ul>
                  </div>
                </div>
              </div>

              {/* 4. REFINED 6 GROUND RULES */}
              <div className="bg-gradient-to-br from-slate-900 via-slate-900 to-emerald-950/60 border border-emerald-900/50 rounded-3xl p-6 sm:p-10 shadow-2xl">
                <div className="flex items-center gap-2 mb-2">
                  <BookOpen className="w-5 h-5 text-amber-400" />
                  <span className="text-xs font-black uppercase tracking-wider text-amber-400">
                    Official Contest Rules
                  </span>
                </div>
                <h3 className="text-2xl sm:text-3xl font-black text-white mb-3">
                  6 Ground Rules for Fair Play &amp; Fast Payouts
                </h3>
                <p className="text-slate-300 text-xs sm:text-sm leading-relaxed mb-8 max-w-3xl">
                  Rentilly by <strong>E-Homes Global Inclusive Limited</strong> operates an open, merit-based creator contest. Zero jargon, 100% transparency. Every participant must abide by these 6 rules:
                </p>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                  {/* Rule 1 */}
                  <div className="p-5 rounded-2xl bg-slate-950/90 border border-amber-500/40 space-y-2.5 hover:border-amber-400 transition">
                    <div className="flex items-center justify-between">
                      <span className="w-8 h-8 rounded-lg bg-amber-500 text-slate-950 font-black text-xs flex items-center justify-center shadow">
                        01
                      </span>
                      <span className="text-[10px] font-bold text-amber-400 uppercase bg-amber-500/10 px-2 py-0.5 rounded border border-amber-500/20">
                        Mandatory
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Tag &amp; Follow First</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Follow <strong>@renti_lly on Instagram, @rentilly on TikTok/X</strong> AND tag us in your video &amp; caption. This connects your video to our scanner for live view tracking.
                    </p>
                  </div>

                  {/* Rule 2 */}
                  <div className="p-5 rounded-2xl bg-slate-950/90 border border-emerald-500/40 space-y-2.5 hover:border-emerald-400 transition">
                    <div className="flex items-center justify-between">
                      <span className="w-8 h-8 rounded-lg bg-emerald-500 text-slate-950 font-black text-xs flex items-center justify-center shadow">
                        02
                      </span>
                      <span className="text-[10px] font-bold text-emerald-400 uppercase bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                        Scope
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Stick to the 2 Topics</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Videos must center strictly on <strong>Renters</strong> (avoiding fake inspection fees, 3D tours) or <strong>Property Purchase</strong> (buying houses/land with verified title deeds, zero omo onile).
                    </p>
                  </div>

                  {/* Rule 3 */}
                  <div className="p-5 rounded-2xl bg-slate-950/90 border border-red-500/40 space-y-2.5 hover:border-red-400 transition">
                    <div className="flex items-center justify-between">
                      <span className="w-8 h-8 rounded-lg bg-red-500/20 text-red-400 font-black text-xs flex items-center justify-center border border-red-500/30">
                        03
                      </span>
                      <span className="text-[10px] font-bold text-red-400 uppercase bg-red-500/10 px-2 py-0.5 rounded border border-red-500/20">
                        Anti-Cheat
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">100% Real Organic Views</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Our automated crawler verifies engagement metrics. Purchasing bot views, click farming, or artificial spikes triggers an instant ban and removal.
                    </p>
                  </div>

                  {/* Rule 4 */}
                  <div className="p-5 rounded-2xl bg-slate-950/90 border border-slate-800 space-y-2.5 hover:border-emerald-500/30 transition">
                    <div className="flex items-center justify-between">
                      <span className="w-8 h-8 rounded-lg bg-slate-800 text-slate-200 font-black text-xs flex items-center justify-center">
                        04
                      </span>
                      <span className="text-[10px] font-bold text-slate-400 uppercase bg-slate-800 px-2 py-0.5 rounded">
                        Multi-Entry
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Top Video Takes Your Prize</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      You may submit multiple videos! Your single highest-viewed entry will represent you on the leaderboard (maximum of one prize per creator per season).
                    </p>
                  </div>

                  {/* Rule 5 */}
                  <div className="p-5 rounded-2xl bg-slate-950/90 border border-emerald-500/40 space-y-2.5 hover:border-emerald-400 transition">
                    <div className="flex items-center justify-between">
                      <span className="w-8 h-8 rounded-lg bg-emerald-500 text-slate-950 font-black text-xs flex items-center justify-center shadow">
                        05
                      </span>
                      <span className="text-[10px] font-bold text-emerald-400 uppercase bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                        Fast Cash
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">Direct 48-Hour Bank Payouts</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      All 20 winning creators receive direct NUBAN bank transfers (GTBank, Access, Zenith, OPay, PalmPay, Kuda) within 48 hours of season close with zero fees.
                    </p>
                  </div>

                  {/* Rule 6 */}
                  <div className="p-5 rounded-2xl bg-slate-950/90 border border-slate-800 space-y-2.5 hover:border-amber-500/30 transition">
                    <div className="flex items-center justify-between">
                      <span className="w-8 h-8 rounded-lg bg-slate-800 text-slate-200 font-black text-xs flex items-center justify-center">
                        06
                      </span>
                      <span className="text-[10px] font-bold text-slate-400 uppercase bg-slate-800 px-2 py-0.5 rounded">
                        Continuous
                      </span>
                    </div>
                    <h4 className="text-sm font-black text-white">New Sprint Every 3 Weeks</h4>
                    <p className="text-xs text-slate-400 leading-relaxed">
                      Every contest runs on a strict 21-day timer. Once prizes are disbursed, a brand-new 3-week season with a fresh ₦600k bounty pool launches immediately!
                    </p>
                  </div>
                </div>
              </div>

              {/* 5. CREATOR FAQ (EVERYTHING CREATORS ASK) */}
              <div className="space-y-6">
                <div className="text-center max-w-2xl mx-auto space-y-2">
                  <span className="text-xs font-black uppercase tracking-wider text-amber-400">
                    Got Questions? We've Got Answers
                  </span>
                  <h3 className="text-2xl sm:text-3xl font-black text-white">
                    Creator FAQ (Everything Creators Ask)
                  </h3>
                  <p className="text-xs sm:text-sm text-slate-400">
                    Transparent answers so you can focus on creating winning content.
                  </p>
                </div>

                <div className="max-w-4xl mx-auto space-y-3">
                  {[
                    {
                      q: "Can I submit multiple videos?",
                      a: "Yes, absolutely! You can submit as many videos as you like across Instagram Reels, TikTok, and X. You are never limited to one entry. Your single highest-performing video with the most verified views will take your slot on the prize leaderboard (maximum 1 prize payout per creator per season, so your best video wins you cash!)."
                    },
                    {
                      q: "How and when do I get paid?",
                      a: "Direct NUBAN bank transfer within 48 hours of cycle end! When the 21-day countdown concludes and the audit finalizes, we transfer your cash prize directly to your Nigerian bank account or fintech wallet (GTBank, Access Bank, Zenith Bank, First Bank, OPay, PalmPay, Kuda, etc.) with zero transaction deductions."
                    },
                    {
                      q: "Do I need millions of followers to win?",
                      a: "No! Zero follower count required. Algorithms on TikTok and Instagram Reels distribute content based on viewer retention, watch time, and relatable hooks — not your follower count. New accounts with under 100 followers regularly generate 50k+ views when the video hook is strong. Ranking is 100% merit-based!"
                    },
                    {
                      q: "What happens when 3 weeks end?",
                      a: "A new 3-week season begins immediately with a fresh cash pool! As soon as a 21-day sprint closes, leaderboard winners are paid within 48 hours, and season reset opens a brand-new 21-day competition with another ₦600,000 cash pool up for grabs."
                    },
                    {
                      q: "Can I shoot content in Nigerian Pidgin or native languages?",
                      a: "100% Yes! Authentic Nigerian storytelling in Pidgin, Yoruba, Igbo, Hausa, or English is welcomed and encouraged. In fact, funny and relatable Pidgin skits about house-hunting wahala often achieve the highest viewer retention and share rates."
                    },
                    {
                      q: "How does the anti-fraud crawler verify views?",
                      a: "Our automated crawler checks video URLs for valid platform metrics, engagement ratios (likes and comments vs views), and unnatural view spikes. Organic traffic from genuine viewers ranks naturally, while automated click farms are disqualified to protect legitimate creators."
                    }
                  ].map((faq, index) => {
                    const isOpen = openFaqIndex === index;
                    return (
                      <div
                        key={index}
                        className={`rounded-2xl border transition duration-200 overflow-hidden ${
                          isOpen
                            ? 'bg-slate-900/90 border-emerald-500/50 shadow-lg shadow-emerald-950/40'
                            : 'bg-slate-950/70 border-slate-800 hover:border-slate-700'
                        }`}
                      >
                        <button
                          type="button"
                          onClick={() => setOpenFaqIndex(isOpen ? null : index)}
                          className="w-full flex items-center justify-between gap-4 p-5 text-left cursor-pointer transition"
                        >
                          <div className="flex items-center gap-3">
                            <span className={`w-7 h-7 rounded-lg text-xs font-black flex items-center justify-center shrink-0 ${
                              isOpen ? 'bg-emerald-500 text-slate-950' : 'bg-slate-800 text-slate-300'
                            }`}>
                              Q{index + 1}
                            </span>
                            <span className="text-sm sm:text-base font-bold text-white">
                              {faq.q}
                            </span>
                          </div>
                          <span className={`w-6 h-6 rounded-full flex items-center justify-center text-xs shrink-0 transition-transform duration-200 ${
                            isOpen ? 'rotate-180 text-emerald-400 bg-emerald-500/10' : 'text-slate-400 bg-slate-800'
                          }`}>
                            <ChevronDown className="w-3.5 h-3.5" />
                          </span>
                        </button>
                        {isOpen && (
                          <div className="px-5 pb-5 pt-1 text-xs sm:text-sm text-slate-300 leading-relaxed border-t border-slate-800/60 animate-fadeIn">
                            {faq.a}
                          </div>
                        )}
                      </div>
                    );
                  })}
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

            {/* LEADERBOARD CARDS & TABLE (100% RESPONSIVE) */}
            <div className="bg-slate-900/90 border border-slate-800 rounded-3xl overflow-hidden shadow-2xl backdrop-blur-xl">
              {/* MOBILE CARDS FEED (< md screens) */}
              <div className="md:hidden divide-y divide-slate-800/80">
                {filtered.length === 0 ? (
                  <div className="p-8 text-center">
                    <div className="w-14 h-14 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-2xl mx-auto mb-3 shadow-lg shadow-emerald-950/50">
                      🏆
                    </div>
                    <h3 className="text-base font-black text-white mb-1.5">
                      Season {cycleConfig.season || 1} Leaderboard Live!
                    </h3>
                    <p className="text-xs text-slate-300 mb-5 leading-relaxed">
                      Zero dummy data. All 20 prize slots are vacant! Post on <strong>Renters</strong> or <strong>Property Purchase</strong> and win <strong>₦200,000</strong>!
                    </p>
                    <button
                      type="button"
                      onClick={() => setIsSubmitModalOpen(true)}
                      className="inline-flex items-center gap-1.5 px-5 py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-400 text-slate-950 font-black text-xs uppercase tracking-wider shadow-lg shadow-emerald-500/25 active:scale-95 cursor-pointer"
                    >
                      <Plus className="w-4 h-4 stroke-[3]" />
                      <span>Submit Video Drop</span>
                    </button>
                  </div>
                ) : (
                  filtered.map((sub, idx) => {
                    const isTop3 = idx < 3;
                    return (
                      <div key={sub.id} className="p-4 space-y-3 bg-slate-900/40 hover:bg-slate-800/40 transition">
                        <div className="flex items-center justify-between gap-2">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span
                              className={`font-mono font-black text-xs px-2.5 py-0.5 rounded-lg border ${
                                idx === 0
                                  ? 'bg-yellow-500/10 text-yellow-400 border-yellow-500/40'
                                  : idx === 1
                                  ? 'bg-slate-300/10 text-slate-200 border-slate-300/40'
                                  : idx === 2
                                  ? 'bg-amber-600/10 text-amber-400 border-amber-600/40'
                                  : idx < 20
                                  ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                                  : 'bg-slate-800 text-slate-400 border-slate-700'
                              }`}
                            >
                              #{idx + 1}
                            </span>
                            <span className="uppercase font-bold text-[10px] px-2 py-0.5 rounded bg-slate-800 text-slate-300">
                              {getPlatformLabel(sub.platform)}
                            </span>
                            {sub.hasTaggedRentilly && (
                              <span className="text-[10px] font-bold text-emerald-400 bg-emerald-500/10 px-1.5 py-0.5 rounded border border-emerald-500/30">
                                🏷️ Tagged
                              </span>
                            )}
                          </div>
                          <div>{getRankBadge(idx)}</div>
                        </div>

                        <div>
                          <div className="font-extrabold text-white text-base flex items-center gap-1.5">
                            <span className="truncate">{sub.creatorName}</span>
                            {isTop3 && <Sparkles className="w-4 h-4 text-amber-400 shrink-0" />}
                          </div>
                          <div className="text-xs text-emerald-400 font-semibold">{sub.handle}</div>
                          {sub.referralCode && (
                            <div className="text-[10px] text-amber-300 font-mono mt-0.5">
                              Ref: {sub.referralCode}
                            </div>
                          )}
                        </div>

                        <div className="flex items-center justify-between pt-2 border-t border-slate-800/80">
                          <div>
                            <span className="text-[10px] uppercase font-bold text-slate-400 block">Verified Views</span>
                            <span className="font-mono font-black text-white text-base">
                              {(sub.verifiedViews || sub.claimedViews).toLocaleString()}
                            </span>
                          </div>

                          <div className="flex items-center gap-1.5">
                            <button
                              type="button"
                              onClick={(e) => handleBoost(sub.id, e)}
                              className="inline-flex items-center gap-1 px-2.5 py-2 rounded-xl bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 font-black text-xs transition active:scale-95 cursor-pointer"
                              title="Fan Boost / Vote"
                            >
                              <Rocket className="w-3.5 h-3.5 text-amber-400" />
                              <span>{sub.boostsCount || 0}</span>
                            </button>
                            <button
                              type="button"
                              onClick={(e) => openBadgeModal(sub, e)}
                              className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white border border-slate-700 transition active:scale-95 cursor-pointer"
                              title="Share Entry Badge"
                            >
                              <Share2 className="w-3.5 h-3.5 text-cyan-400" />
                            </button>
                            <a
                              href={sub.videoUrl}
                              target="_blank"
                              rel="noreferrer"
                              className="inline-flex items-center gap-1 px-3 py-2 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 font-bold text-xs transition active:scale-95 cursor-pointer shrink-0"
                            >
                              <Play className="w-3.5 h-3.5 fill-emerald-400 text-emerald-400" />
                              <span>Watch</span>
                            </a>
                          </div>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>

              {/* DESKTOP TABLE (>= md screens) */}
              <div className="hidden md:block overflow-x-auto">
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
                              <div className="flex items-center justify-end gap-2">
                                <button
                                  type="button"
                                  onClick={(e) => handleBoost(sub.id, e)}
                                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 text-xs font-black transition active:scale-95 cursor-pointer"
                                  title="Fan Boost / Vote for this creator"
                                >
                                  <Rocket className="w-3.5 h-3.5 text-amber-400" />
                                  <span>{sub.boostsCount || 0}</span>
                                </button>
                                <button
                                  type="button"
                                  onClick={(e) => openBadgeModal(sub, e)}
                                  className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white border border-slate-700 text-xs font-bold transition cursor-pointer"
                                  title="View & Share Contestant Badge"
                                >
                                  <Share2 className="w-3 h-3 text-cyan-400" />
                                  <span className="hidden lg:inline">Badge</span>
                                </button>
                                <a
                                  href={sub.videoUrl}
                                  target="_blank"
                                  rel="noreferrer"
                                  className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-bold transition cursor-pointer"
                                >
                                  <Play className="w-3 h-3 text-emerald-400" />
                                  <span>Watch</span>
                                </a>
                              </div>
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

            {/* Regulatory Compliance & Fair Play Protocol */}
            <div className="my-6 p-4 rounded-2xl bg-slate-900/60 border border-slate-800 text-[11px] text-slate-400 leading-relaxed space-y-1.5">
              <div className="flex items-center gap-2 text-slate-200 font-bold">
                <ShieldCheck className="w-4 h-4 text-emerald-400" />
                <span>Official Contest Terms &amp; Compliance Protocol</span>
              </div>
              <p>
                The Rentilly Creator Challenge is organized and disbursed by <strong>E-Homes Global Inclusive Limited</strong>. Participation is open to all content creators resident in Nigeria. Ranks are determined strictly by verified video view metrics. Automated view-botting, fake engagement farms, or click pools trigger immediate disqualification. Cash prizes are disbursed within 48 hours following the official 3-week sprint close directly to Nigerian commercial bank accounts via NIP.
              </p>
            </div>

            {/* Bottom Bar */}
            <div className="pt-4 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
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

        {/* MOBILE STICKY BOTTOM NAVIGATION BAR WITH ICONS (100% RESPONSIVE) */}
        <div className="md:hidden fixed bottom-0 left-0 right-0 z-50 bg-slate-950/95 backdrop-blur-xl border-t border-slate-800/80 px-2 sm:px-4 py-2 flex items-center justify-around shadow-[0_-8px_30px_rgba(0,0,0,0.7)] pb-[calc(0.5rem+env(safe-area-inset-bottom,0px))]">
          <button
            type="button"
            onClick={() => {
              if (pageView !== 'landing') navigateTo('landing');
              else window.scrollTo({ top: 0, behavior: 'smooth' });
            }}
            className={`flex flex-col items-center gap-1 text-[10px] font-bold transition cursor-pointer ${
              pageView === 'landing' ? 'text-emerald-400 font-extrabold' : 'text-slate-400 hover:text-white'
            }`}
          >
            <Sparkles className="w-4 h-4" />
            <span>Contest</span>
          </button>

          <button
            type="button"
            onClick={() => navigateTo('leaderboard')}
            className={`flex flex-col items-center gap-1 text-[10px] font-bold transition cursor-pointer relative ${
              pageView === 'leaderboard' ? 'text-amber-400 font-extrabold' : 'text-slate-400 hover:text-white'
            }`}
          >
            <Trophy className="w-4 h-4 text-amber-400" />
            <span>Leaderboard</span>
            {pageView === 'leaderboard' && (
              <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-ping absolute -top-0.5 right-1.5" />
            )}
          </button>

          {/* Central Pulsing Submit Button */}
          <button
            type="button"
            onClick={() => setIsSubmitModalOpen(true)}
            className="flex items-center justify-center -mt-6 bg-gradient-to-r from-emerald-500 to-teal-400 text-slate-950 font-black p-3.5 rounded-full shadow-xl shadow-emerald-500/50 border-4 border-slate-950 active:scale-95 transition cursor-pointer"
            title="Submit Video Drop"
          >
            <Plus className="w-5 h-5 stroke-[3]" />
          </button>

          <button
            type="button"
            onClick={() => scrollToSection('prizes')}
            className="flex flex-col items-center gap-1 text-[10px] font-bold text-slate-400 hover:text-emerald-400 transition cursor-pointer"
          >
            <Gift className="w-4 h-4 text-emerald-400" />
            <span>Prizes</span>
          </button>

          <button
            type="button"
            onClick={() => scrollToSection('rules')}
            className="flex flex-col items-center gap-1 text-[10px] font-bold text-slate-400 hover:text-cyan-400 transition cursor-pointer"
          >
            <BookOpen className="w-4 h-4 text-cyan-400" />
            <span>Rules</span>
          </button>
        </div>

        {/* Submission Modal */}
        {isSubmitModalOpen && (
          <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
            <div className="bg-slate-900 border border-slate-800 rounded-2xl sm:rounded-3xl max-w-lg w-full p-4 sm:p-8 shadow-2xl relative max-h-[92vh] overflow-y-auto m-2">
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

                {/* MANDATORY COMMERCIAL UGC RIGHTS RELEASE CHECKBOX */}
                <div className="p-3.5 bg-slate-950 border border-slate-800 hover:border-slate-700 rounded-2xl space-y-2 transition">
                  <label className="flex items-start gap-2.5 cursor-pointer">
                    <input
                      type="checkbox"
                      required
                      checked={(formData as any).ugcRightsGranted}
                      onChange={(e) => setFormData({ ...formData, ugcRightsGranted: e.target.checked } as any)}
                      className="mt-0.5 w-4 h-4 rounded text-emerald-500 focus:ring-emerald-400 bg-slate-900 border-slate-700 cursor-pointer"
                    />
                    <span className="text-xs text-slate-300 leading-snug">
                      <strong className="text-white">Commercial UGC Rights License:</strong> I grant <strong>Rentilly / E-Homes Global Inclusive Limited</strong> a non-exclusive, royalty-free license to feature, repost, and run marketing with this video drop across official social channels and web properties.
                    </span>
                  </label>
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

        {/* CREATOR MEDIA KIT MODAL (GLOBAL STANDARD ASSETS) */}
        {isKitModalOpen && (
          <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
            <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-xl w-full p-5 sm:p-8 shadow-2xl relative max-h-[90vh] overflow-y-auto m-2">
              <button
                type="button"
                onClick={() => setIsKitModalOpen(false)}
                className="absolute top-5 right-5 text-slate-400 hover:text-white p-1 rounded-lg bg-slate-800 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>

              <div className="flex items-center gap-3 mb-4">
                <div className="w-12 h-12 rounded-2xl bg-slate-950 border border-emerald-500/40 p-1.5 flex items-center justify-center shrink-0">
                  <img src="/logo.png" alt="Rentilly" className="w-full h-full object-contain" />
                </div>
                <div>
                  <div className="flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                    <span className="text-[10px] font-black uppercase text-emerald-400 tracking-wider">
                      Official Brand Kit
                    </span>
                  </div>
                  <h3 className="text-xl font-black text-white">Creator Media Kit &amp; Assets</h3>
                </div>
              </div>

              <div className="space-y-6 text-xs text-slate-300">
                {/* Logo Assets */}
                <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 space-y-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="font-bold text-white text-sm">Official Transparent Logo</h4>
                      <p className="text-[11px] text-slate-400">High-resolution PNG for video overlays and watermarks</p>
                    </div>
                    <a
                      href="/logo.png"
                      download="rentilly-logo.png"
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs transition active:scale-95 cursor-pointer"
                    >
                      <Download className="w-3.5 h-3.5" />
                      <span>Download</span>
                    </a>
                  </div>
                  <div className="h-16 rounded-xl bg-slate-900 border border-slate-800/80 flex items-center justify-center p-2">
                    <img src="/logo.png" alt="Rentilly Logo" className="h-full object-contain" />
                  </div>
                </div>

                {/* Brand Colors */}
                <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 space-y-3">
                  <h4 className="font-bold text-white text-sm">Official Brand Hex Colors</h4>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                    {[
                      { name: 'Emerald', hex: '#10B981', bg: 'bg-[#10B981]' },
                      { name: 'Amber Gold', hex: '#F59E0B', bg: 'bg-[#F59E0B]' },
                      { name: 'Dark Slate', hex: '#020617', bg: 'bg-[#020617]' },
                      { name: 'Deep Green', hex: '#064E3B', bg: 'bg-[#064E3B]' },
                    ].map((col) => (
                      <button
                        key={col.hex}
                        type="button"
                        onClick={() => copyToClipboard(col.hex, col.hex, `${col.name} (${col.hex})`)}
                        className="p-2.5 rounded-xl bg-slate-900 border border-slate-800 hover:border-slate-700 text-left transition active:scale-95 cursor-pointer group"
                      >
                        <div className={`w-full h-6 rounded-lg ${col.bg} mb-1.5 border border-white/20`} />
                        <div className="text-[11px] font-bold text-white group-hover:text-emerald-400 truncate">{col.name}</div>
                        <div className="text-[10px] font-mono text-slate-400">{col.hex}</div>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Talking Points & Hooks */}
                <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 space-y-2.5">
                  <h4 className="font-bold text-white text-sm">Key Talking Points for Creators</h4>
                  <ul className="space-y-2 text-[11px] text-slate-300">
                    <li className="flex items-start gap-2">
                      <span className="text-emerald-400 font-bold shrink-0">✓</span>
                      <span><strong>For Renters:</strong> No more "inspection fee" scams, verified 3D virtual tours, direct landlord lease agreements on the app.</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-amber-400 font-bold shrink-0">✓</span>
                      <span><strong>For Buyers:</strong> Title verification, zero 'omo onile' land disputes, secure escrow disbursement for property purchases.</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-cyan-400 font-bold shrink-0">✓</span>
                      <span><strong>Call to Action:</strong> "Download the Rentilly App on Google Play / Apple App Store or visit myrentilly.com!"</span>
                    </li>
                  </ul>
                </div>

                {/* Sound Recommendation */}
                <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 flex items-center justify-between gap-4">
                  <div className="flex items-center gap-2.5">
                    <Volume2 className="w-5 h-5 text-pink-400 shrink-0" />
                    <div>
                      <h4 className="font-bold text-white text-xs">Audio Recommendation</h4>
                      <p className="text-[11px] text-slate-400">Pair your video with trending upbeat Nigerian Afrobeats or storytelling acoustic audio</p>
                    </div>
                  </div>
                </div>
              </div>

              <div className="mt-6 pt-4 border-t border-slate-800 flex justify-end">
                <button
                  type="button"
                  onClick={() => setIsKitModalOpen(false)}
                  className="px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs cursor-pointer"
                >
                  Close Media Kit
                </button>
              </div>
            </div>
          </div>
        )}

        {/* SHAREABLE CONTESTANT ENTRY BADGE MODAL */}
        {isBadgeModalOpen && badgeCreator && (
          <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4">
            <div className="bg-slate-900 border-2 border-emerald-500/50 rounded-3xl max-w-md w-full p-6 sm:p-8 shadow-2xl relative text-center">
              <button
                type="button"
                onClick={() => setIsBadgeModalOpen(false)}
                className="absolute top-4 right-4 text-slate-400 hover:text-white p-1 rounded-lg bg-slate-800 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>

              {/* Digital Badge Card */}
              <div className="p-6 rounded-2xl bg-gradient-to-b from-slate-950 via-slate-900 to-emerald-950/80 border-2 border-amber-400/60 shadow-xl mb-6 relative overflow-hidden">
                <div className="absolute top-2 right-2 px-2 py-0.5 rounded-full text-[9px] font-mono font-bold uppercase bg-amber-500/20 text-amber-300 border border-amber-500/40">
                  Season {cycleConfig.season || 1}
                </div>

                <div className="w-14 h-14 rounded-2xl bg-slate-900 border border-emerald-400/40 p-2 mx-auto mb-3 shadow-lg">
                  <img src="/logo.png" alt="Rentilly" className="w-full h-full object-contain" />
                </div>

                <span className="text-[10px] font-black uppercase tracking-widest text-emerald-400 block mb-1">
                  OFFICIAL CONTESTANT CREDENTIAL
                </span>
                <h3 className="text-xl font-black text-white">{badgeCreator.creatorName}</h3>
                <div className="text-xs font-mono font-bold text-amber-300 mb-3">{badgeCreator.handle}</div>

                <div className="grid grid-cols-2 gap-2 text-center py-2.5 px-3 rounded-xl bg-slate-950/80 border border-slate-800 mb-3">
                  <div>
                    <span className="text-[9px] uppercase font-bold text-slate-400 block">Platform</span>
                    <span className="text-xs font-black text-white uppercase">{badgeCreator.platform}</span>
                  </div>
                  <div>
                    <span className="text-[9px] uppercase font-bold text-slate-400 block">Verified Views</span>
                    <span className="text-xs font-black text-emerald-400 font-mono">
                      {(badgeCreator.verifiedViews || badgeCreator.claimedViews || 0).toLocaleString()}
                    </span>
                  </div>
                </div>

                <div className="text-[10px] text-slate-400 italic">
                  Compete for the ₦200,000 Grand Prize • Renters &amp; Property Purchase Only
                </div>
              </div>

              {/* Action Buttons */}
              <div className="space-y-2.5">
                <button
                  type="button"
                  onClick={() => {
                    const url = `${window.location.origin}/leaderboard?q=${encodeURIComponent(badgeCreator.handle)}`;
                    copyToClipboard(url, 'badge_url', 'Contestant Share Link');
                  }}
                  className="w-full py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-400 hover:from-emerald-400 hover:to-teal-300 text-slate-950 font-black text-xs uppercase tracking-wider shadow-lg shadow-emerald-500/25 transition active:scale-95 flex items-center justify-center gap-2 cursor-pointer"
                >
                  <Copy className="w-4 h-4" />
                  <span>{copiedKey === 'badge_url' ? 'Link Copied!' : 'Copy Contestant Link'}</span>
                </button>

                <div className="grid grid-cols-2 gap-2">
                  <a
                    href={`https://api.whatsapp.com/send?text=${encodeURIComponent(
                      `Vote and check out my Rentilly Creator Contest entry! Support my video drop: ${window.location.origin}/leaderboard?q=${encodeURIComponent(badgeCreator.handle)}`
                    )}`}
                    target="_blank"
                    rel="noreferrer"
                    className="py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs flex items-center justify-center gap-1.5 transition active:scale-95 cursor-pointer"
                  >
                    <span>Share WhatsApp</span>
                  </a>
                  <a
                    href={`https://twitter.com/intent/tweet?text=${encodeURIComponent(
                      `I just entered the @rentilly Creator Contest for ₦200,000! Check out my video drop and boost me: ${window.location.origin}/leaderboard?q=${encodeURIComponent(badgeCreator.handle)} #RentillyChallenge`
                    )}`}
                    target="_blank"
                    rel="noreferrer"
                    className="py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs flex items-center justify-center gap-1.5 transition active:scale-95 cursor-pointer"
                  >
                    <span>Share on X</span>
                  </a>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
