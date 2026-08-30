import React, { useState } from 'react';
import { 
  ShieldCheck, 
  Lock, 
  Mail, 
  ArrowRight, 
  Eye, 
  EyeOff, 
  Building2, 
  Scale, 
  AlertCircle
} from 'lucide-react';
import { RentillyApiService } from '../services/api';
import type { UserProfile } from '../types';

interface AdminLoginPageProps {
  onLoginSuccess: (user: UserProfile, token: string) => void;
}

export const AdminLoginPage: React.FC<AdminLoginPageProps> = ({ onLoginSuccess }) => {
  const [email, setEmail] = useState('legal@rentilly.ng');
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
      setError(err.message || 'Login failed. Please check your admin credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleQuickDemoLogin = (demoEmail: string, demoPass: string) => {
    setEmail(demoEmail);
    setPassword(demoPass);
  };

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col justify-center items-center p-4 relative overflow-hidden">
      {/* Background Decorative Gradients */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-10 right-10 w-80 h-80 bg-teal-500/5 rounded-full blur-2xl pointer-events-none" />

      {/* Main Login Card Container */}
      <div className="w-full max-w-md relative z-10 space-y-6">
        {/* Brand Header */}
        <div className="text-center space-y-2">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-400 shadow-xl shadow-emerald-950/50 mb-1 border border-emerald-400/30">
            <ShieldCheck className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">Rentilly Admin Portal</h1>
          <p className="text-xs text-slate-400 max-w-xs mx-auto">
            Nigerian Real Estate Operations Hub • KYP Title Verification & Legal Escrow Vault
          </p>
        </div>

        {/* Login Form Box */}
        <div className="p-7 rounded-3xl bg-slate-900/90 border border-slate-800 backdrop-blur-xl shadow-2xl space-y-5">
          <div className="flex items-center justify-between pb-3 border-b border-slate-800">
            <span className="text-xs font-bold text-slate-300 flex items-center gap-1.5">
              <Lock className="w-4 h-4 text-emerald-400" />
              <span>Authorized Personnel Only</span>
            </span>
            <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono">
              v1.0 Secure
            </span>
          </div>

          {error && (
            <div className="p-3.5 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 text-red-400" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4 text-xs">
            {/* Email Field */}
            <div className="space-y-1">
              <label className="block text-slate-300 font-semibold">Admin / Legal Email</label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="legal@rentilly.ng"
                  className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 text-xs transition font-sans"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-1">
              <div className="flex justify-between items-center">
                <label className="block text-slate-300 font-semibold">Security Password</label>
              </div>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full pl-10 pr-10 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 text-xs transition font-mono"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 p-1"
                >
                  {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                </button>
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center justify-center gap-2 transform active:scale-98 disabled:opacity-50"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <span>Authenticate & Open Backoffice</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          {/* Quick Demo Credentials Switcher */}
          <div className="pt-3 border-t border-slate-800/80 space-y-2">
            <span className="text-[10px] uppercase font-bold text-slate-500 tracking-wider block text-center">
              Quick One-Click Demo Access
            </span>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => handleQuickDemoLogin('legal@rentilly.ng', 'AdminRentilly2026!')}
                className="p-2 rounded-xl bg-slate-950 hover:bg-slate-850 border border-slate-800 text-[11px] text-slate-300 text-left transition space-y-0.5"
              >
                <div className="flex items-center gap-1 font-semibold text-emerald-400">
                  <Scale className="w-3 h-3" />
                  <span>Legal Lead</span>
                </div>
                <p className="text-[10px] text-slate-400 truncate">Barr. Chijioke</p>
              </button>

              <button
                type="button"
                onClick={() => handleQuickDemoLogin('travsify@rentilly.ng', 'Forgetpassword.')}
                className="p-2 rounded-xl bg-slate-950 hover:bg-slate-850 border border-slate-800 text-[11px] text-slate-300 text-left transition space-y-0.5"
              >
                <div className="flex items-center gap-1 font-semibold text-teal-400">
                  <Building2 className="w-3 h-3" />
                  <span>Admin Chief</span>
                </div>
                <p className="text-[10px] text-slate-400 truncate">Travsify Lead</p>
              </button>
            </div>
          </div>
        </div>

        {/* Live Backend Connection Indicator */}
        <div className="p-3 rounded-2xl bg-slate-900/60 border border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
          <span className="flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span>Live Render Server:</span>
          </span>
          <span className="font-mono text-[11px] text-emerald-400">rentilly-admin-api.onrender.com</span>
        </div>
      </div>
    </div>
  );
};
