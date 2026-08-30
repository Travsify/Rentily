import React, { useState } from 'react';
import { 
  ShieldCheck, 
  Lock, 
  Mail, 
  ArrowRight, 
  Eye, 
  EyeOff, 
  Building2, 
  AlertCircle,
  Shield
} from 'lucide-react';
import { RentillyApiService } from '../services/api';
import type { UserProfile } from '../types';

interface AdminLoginPageProps {
  onLoginSuccess: (user: UserProfile, token: string) => void;
}

export const AdminLoginPage: React.FC<AdminLoginPageProps> = ({ onLoginSuccess }) => {
  const [email, setEmail] = useState('admin@rentilly.ng');
  const [password, setPassword] = useState('AdminRentilly2026!');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await RentillyApiService.login(email, password);
      if (res.user && res.token) {
        onLoginSuccess(res.user, res.token);
      }
    } catch (err: any) {
      setError(err.message || 'Authentication failed. Please verify your admin credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleQuickDemoLogin = (adminEmail: string, adminPass: string) => {
    setEmail(adminEmail);
    setPassword(adminPass);
  };

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col justify-center items-center p-4 relative overflow-hidden font-sans select-none">
      {/* Background Decorative Gradients */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-10 right-10 w-64 h-64 bg-teal-500/5 rounded-full blur-2xl pointer-events-none" />

      {/* Main Login Card Container */}
      <div className="w-full max-w-sm relative z-10 space-y-4">
        {/* Brand Header */}
        <div className="text-center space-y-1.5">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-400 shadow-lg shadow-emerald-950/50 mb-0.5 border border-emerald-400/30">
            <ShieldCheck className="w-6 h-6 text-white" />
          </div>
          <h1 className="text-lg font-bold text-white tracking-tight">Rentilly Administrator Portal</h1>
          <p className="text-[11px] text-slate-400 max-w-xs mx-auto leading-relaxed">
            Centralized Real Estate Operations • Strict Admin Access Only
          </p>
        </div>

        {/* Login Form Box */}
        <div className="p-6 rounded-2xl bg-slate-900/95 border border-slate-800 backdrop-blur-xl shadow-2xl space-y-4">
          <div className="flex items-center justify-between pb-2.5 border-b border-slate-800">
            <span className="text-[11px] font-bold text-slate-300 flex items-center gap-1.5">
              <Lock className="w-3.5 h-3.5 text-emerald-400" />
              <span>Admin Authentication</span>
            </span>
            <span className="text-[9px] px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono font-medium">
              Admin Gateway
            </span>
          </div>

          {error && (
            <div className="p-2.5 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-[11px] flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 text-red-400" />
              <span className="leading-tight">{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-3 text-[11px]">
            {/* Email Field */}
            <div className="space-y-1">
              <label className="block text-slate-300 font-semibold text-[11px]">Admin Email</label>
              <div className="relative">
                <Mail className="w-3.5 h-3.5 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@rentilly.ng"
                  className="w-full pl-9 pr-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 text-[11px] transition"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-1">
              <div className="flex justify-between items-center">
                <label className="block text-slate-300 font-semibold text-[11px]">Password</label>
              </div>
              <div className="relative">
                <Lock className="w-3.5 h-3.5 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full pl-9 pr-9 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 text-[11px] transition font-mono"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 p-1"
                >
                  {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                </button>
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-[11px] shadow-lg shadow-emerald-950/60 transition flex items-center justify-center gap-1.5 transform active:scale-98 disabled:opacity-50 mt-1"
            >
              {loading ? (
                <div className="w-3.5 h-3.5 border-2 border-white/20 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <span>Sign In as Admin</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </>
              )}
            </button>
          </form>

          {/* Quick One-Click Admin Access */}
          <div className="pt-2.5 border-t border-slate-800/80 space-y-1.5">
            <span className="text-[9px] uppercase font-bold text-slate-500 tracking-wider block text-center">
              Quick Admin Credentials
            </span>
            <div className="grid grid-cols-2 gap-1.5">
              <button
                type="button"
                onClick={() => handleQuickDemoLogin('admin@rentilly.ng', 'AdminRentilly2026!')}
                className="p-2 rounded-xl bg-slate-950 hover:bg-slate-850 border border-slate-800 text-[10px] text-slate-300 text-left transition space-y-0.5"
              >
                <div className="flex items-center gap-1 font-semibold text-emerald-400">
                  <Shield className="w-2.5 h-2.5" />
                  <span>Super Admin</span>
                </div>
                <p className="text-[9px] text-slate-400 truncate">admin@rentilly.ng</p>
              </button>

              <button
                type="button"
                onClick={() => handleQuickDemoLogin('travsify@rentilly.ng', 'Forgetpassword.')}
                className="p-2 rounded-xl bg-slate-950 hover:bg-slate-850 border border-slate-800 text-[10px] text-slate-300 text-left transition space-y-0.5"
              >
                <div className="flex items-center gap-1 font-semibold text-teal-400">
                  <Building2 className="w-2.5 h-2.5" />
                  <span>Travsify Lead</span>
                </div>
                <p className="text-[9px] text-slate-400 truncate">travsify@rentilly.ng</p>
              </button>
            </div>
          </div>
        </div>

        {/* Live Backend Connection Indicator */}
        <div className="p-2.5 rounded-xl bg-slate-900/60 border border-slate-800/80 flex items-center justify-between text-[10px] text-slate-400">
          <span className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
            <span>Live Server:</span>
          </span>
          <span className="font-mono text-[10px] text-emerald-400">rentilly-admin-api.onrender.com</span>
        </div>
      </div>
    </div>
  );
};
