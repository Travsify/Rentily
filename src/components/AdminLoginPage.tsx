import React, { useState } from 'react';
import { 
  ShieldCheck, 
  Lock, 
  Mail, 
  ArrowRight, 
  Eye, 
  EyeOff, 
  AlertCircle,
  KeyRound,
  CheckCircle2
} from 'lucide-react';
import { RentillyApiService } from '../services/api';
import type { UserProfile } from '../types';

interface AdminLoginPageProps {
  onLoginSuccess: (user: UserProfile, token: string) => void;
}

export const AdminLoginPage: React.FC<AdminLoginPageProps> = ({ onLoginSuccess }) => {
  const [email, setEmail] = useState('admin@myrentilly.com');
  const [password, setPassword] = useState('AdminRentilly2026!');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await RentillyApiService.login(email.trim(), password.trim());
      if (res.user && res.token) {
        onLoginSuccess(res.user, res.token);
      } else {
        throw new Error('Invalid server response');
      }
    } catch (err: any) {
      setError(err.message || 'Authentication failed. Please verify your admin credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleFillCredentials = () => {
    setEmail('admin@myrentilly.com');
    setPassword('AdminRentilly2026!');
    setError(null);
  };

  return (
    <div className="min-h-screen bg-[#030712] flex flex-col justify-center items-center p-4 relative overflow-hidden font-sans select-none">
      {/* Subtle Ambient Glow */}
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[450px] h-[450px] bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />

      {/* Main Login Card */}
      <div className="w-full max-w-sm relative z-10 space-y-4">
        {/* Brand Header */}
        <div className="text-center space-y-1.5">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-emerald-600 shadow-xl shadow-emerald-950/60 mb-1 border border-emerald-400/30">
            <ShieldCheck className="w-6 h-6 text-white" />
          </div>
          <h1 className="text-xl font-extrabold text-white tracking-tight">Rentilly Admin Console</h1>
          <p className="text-xs text-slate-400 max-w-xs mx-auto">
            Zero-Agent Real Estate & Escrow Operations Hub
          </p>
        </div>

        {/* Form Container */}
        <div className="p-6 rounded-2xl bg-[#0f172a] border border-slate-800 shadow-2xl space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-800">
            <span className="text-xs font-bold text-slate-300 flex items-center gap-1.5">
              <Lock className="w-3.5 h-3.5 text-emerald-400" />
              <span>Admin Authentication</span>
            </span>
            <span className="text-[10px] px-2.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">
              Secure Gateway
            </span>
          </div>

          {error && (
            <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 text-red-400" />
              <span className="leading-tight">{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-3.5 text-xs">
            {/* Email Field */}
            <div className="space-y-1">
              <label className="block text-slate-300 font-semibold text-xs">Admin Email</label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@myrentilly.com"
                  className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 text-xs transition"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-1">
              <label className="block text-slate-300 font-semibold text-xs">Password</label>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full pl-9 pr-9 py-2.5 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 text-xs transition"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="p-1 text-slate-500 hover:text-slate-300 absolute right-2.5 top-1/2 -translate-y-1/2"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center justify-center gap-2 transform active:scale-98 disabled:opacity-50 mt-2"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <span>Enter Operations Console</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          {/* Quick Fill Credentials Banner */}
          <div className="pt-3 border-t border-slate-800 text-center">
            <button
              type="button"
              onClick={handleFillCredentials}
              className="w-full py-2 px-3 rounded-xl bg-[#030712] hover:bg-slate-800 border border-slate-800 text-slate-300 text-xs flex items-center justify-between transition"
            >
              <span className="flex items-center gap-1.5 font-semibold text-emerald-400">
                <KeyRound className="w-3.5 h-3.5" />
                <span>Auto-Fill Admin Credentials</span>
              </span>
              <span className="text-[10px] text-slate-500">Click to load</span>
            </button>
          </div>
        </div>

        {/* Credentials Reference Box */}
        <div className="p-3.5 rounded-xl bg-[#0f172a] border border-slate-800/80 text-[11px] text-slate-400 space-y-1.5">
          <div className="flex items-center justify-between text-white font-bold text-xs">
            <span className="flex items-center gap-1 text-emerald-400">
              <CheckCircle2 className="w-3.5 h-3.5" />
              <span>Production Admin Access</span>
            </span>
            <span className="text-[10px] uppercase font-mono px-1.5 py-0.5 rounded bg-emerald-950 text-emerald-300 border border-emerald-800">
              Tier-3 Master
            </span>
          </div>
          <div className="font-mono text-slate-300 text-[11px]">
            Email: <span className="text-white font-bold">admin@myrentilly.com</span><br/>
            Password: <span className="text-white font-bold">AdminRentilly2026!</span>
          </div>
        </div>
      </div>
    </div>
  );
};
