import React, { useState, useEffect } from 'react';
import {
  ShieldCheck,
  Lock,
  Mail,
  ArrowRight,
  Eye,
  EyeOff,
  AlertCircle,
  KeyRound,
  CheckCircle2,
  Headphones,
  RotateCcw,
  ShieldAlert,
  Smartphone,
  QrCode,
  Copy,
  Check,
} from 'lucide-react';
import { RentillyApiService } from '../services/api';
import type { UserProfile } from '../types';

interface AdminLoginPageProps {
  onLoginSuccess: (user: UserProfile, token: string) => void;
}

export const AdminLoginPage: React.FC<AdminLoginPageProps> = ({ onLoginSuccess }) => {
  const [loginMode, setLoginMode] = useState<'admin' | 'agent'>('admin');
  const [adminStep, setAdminStep] = useState<'credentials' | 'totp' | 'email_otp'>('credentials');
  const [mfaMethod, setMfaMethod] = useState<'totp' | 'email'>('totp');

  // Form Fields (Wiped clean - zero demo or hardcoded credentials visible)
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [harshKey, setHarshKey] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [totpCode, setTotpCode] = useState('');

  // Google Authenticator MFA State
  const [qrCodeDataUrl, setQrCodeDataUrl] = useState<string | null>(null);
  const [totpSecret, setTotpSecret] = useState<string | null>(null);
  const [totpConfigured, setTotpConfigured] = useState(false);
  const [showQrCode, setShowQrCode] = useState(false);
  const [copiedSecret, setCopiedSecret] = useState(false);

  // Visibility Toggles
  const [showPassword, setShowPassword] = useState(false);
  const [showHarshKey, setShowHarshKey] = useState(false);

  // Status & Feedback
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [resendCooldown, setResendCooldown] = useState(0);

  // Resend Countdown Timer
  useEffect(() => {
    if (resendCooldown <= 0) return;
    const interval = setInterval(() => {
      setResendCooldown((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(interval);
  }, [resendCooldown]);

  const handleModeSwitch = (mode: 'admin' | 'agent') => {
    setLoginMode(mode);
    setAdminStep('credentials');
    setError(null);
    setSuccessMessage(null);
    setEmail('');
    setPassword('');
    setHarshKey('');
    setOtpCode('');
    setTotpCode('');
    setQrCodeDataUrl(null);
    setTotpSecret(null);
    setShowQrCode(false);
  };

  // Copy secret key helper
  const handleCopySecret = () => {
    if (!totpSecret) return;
    navigator.clipboard.writeText(totpSecret);
    setCopiedSecret(true);
    setTimeout(() => setCopiedSecret(false), 2500);
  };

  // Step 1: Proceed to 2FA (Google Authenticator or Email OTP)
  const handleProceedTo2fa = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccessMessage(null);

    const cleanEmail = email.trim();
    const cleanPassword = password.trim();
    const cleanHarshKey = harshKey.trim();

    if (!cleanEmail) {
      setError('Administrative email address is required.');
      return;
    }
    if (!cleanPassword) {
      setError('Master administrative password is required.');
      return;
    }
    if (!cleanHarshKey) {
      setError('Admin Harsh Key is required to authorize authentication.');
      return;
    }

    setLoading(true);

    if (mfaMethod === 'totp') {
      try {
        // Fetch or initialize Google Authenticator QR setup
        const setup = await RentillyApiService.setupAdminTotp(cleanEmail, cleanPassword, cleanHarshKey);
        setQrCodeDataUrl(setup.qrCodeDataUrl);
        setTotpSecret(setup.secret);
        setTotpConfigured(setup.configured);
        // If not yet configured, automatically show QR code for easy first-time scanning
        setShowQrCode(!setup.configured);
        setAdminStep('totp');
        if (!setup.configured) {
          setSuccessMessage('Scan this QR code in Google Authenticator or enter the manual key below.');
        } else {
          setSuccessMessage('Enter the current 6-digit code from Google Authenticator.');
        }
      } catch (err: any) {
        setError(err.message || 'Authorization failed. Please check your credentials and harsh key.');
      } finally {
        setLoading(false);
      }
    } else {
      // Email OTP Mode
      try {
        const res = await RentillyApiService.requestAdminOtp(cleanEmail, cleanPassword, cleanHarshKey);
        setSuccessMessage(res.message || '2FA verification code dispatched to your registered inbox.');
        setAdminStep('email_otp');
        setResendCooldown(60);
      } catch (err: any) {
        setError(err.message || 'Authorization failed. Please check your credentials and harsh key.');
      } finally {
        setLoading(false);
      }
    }
  };

  // Step 2A: Verify Google Authenticator Code
  const handleVerifyTotp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccessMessage(null);

    const cleanCode = totpCode.trim().replace(/\D/g, '');
    if (!cleanCode || cleanCode.length < 6) {
      setError('Please enter the 6-digit code shown in Google Authenticator.');
      return;
    }

    setLoading(true);
    try {
      const res = await RentillyApiService.verifyAdminTotp(email.trim(), cleanCode, harshKey.trim());
      if (res.user && res.token) {
        onLoginSuccess(res.user, res.token);
      } else {
        throw new Error('Missing session payload from authentication response.');
      }
    } catch (err: any) {
      setError(err.message || 'Invalid Google Authenticator code. Please check your app and try again.');
    } finally {
      setLoading(false);
    }
  };

  // Step 2B: Verify Email OTP Code
  const handleVerifyEmailOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccessMessage(null);

    const cleanCode = otpCode.trim().replace(/\D/g, '');
    if (!cleanCode || cleanCode.length < 6) {
      setError('Please enter the complete 6-digit email verification code.');
      return;
    }

    setLoading(true);
    try {
      const res = await RentillyApiService.verifyAdmin2fa(email.trim(), cleanCode, harshKey.trim());
      if (res.user && res.token) {
        onLoginSuccess(res.user, res.token);
      } else {
        throw new Error('Missing session payload from authentication response.');
      }
    } catch (err: any) {
      setError(err.message || 'Invalid or expired 2FA code. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  // Resend Email OTP
  const handleResendEmailOtp = async () => {
    if (resendCooldown > 0 || loading) return;
    setLoading(true);
    setError(null);
    try {
      const res = await RentillyApiService.requestAdminOtp(email.trim(), password.trim(), harshKey.trim());
      setSuccessMessage(res.message || 'New 2FA code dispatched to your inbox.');
      setResendCooldown(60);
    } catch (err: any) {
      setError(err.message || 'Failed to resend 2FA code.');
    } finally {
      setLoading(false);
    }
  };

  // Switch to Email OTP from TOTP step
  const handleSwitchToEmailOtp = async () => {
    setError(null);
    setSuccessMessage(null);
    setLoading(true);
    try {
      const res = await RentillyApiService.requestAdminOtp(email.trim(), password.trim(), harshKey.trim());
      setSuccessMessage(res.message || '2FA code dispatched to your registered inbox.');
      setAdminStep('email_otp');
      setMfaMethod('email');
      setResendCooldown(60);
    } catch (err: any) {
      setError(err.message || 'Failed to dispatch email code.');
    } finally {
      setLoading(false);
    }
  };

  // Switch to TOTP from Email OTP step
  const handleSwitchToTotp = async () => {
    setError(null);
    setSuccessMessage(null);
    setLoading(true);
    try {
      const setup = await RentillyApiService.setupAdminTotp(email.trim(), password.trim(), harshKey.trim());
      setQrCodeDataUrl(setup.qrCodeDataUrl);
      setTotpSecret(setup.secret);
      setTotpConfigured(setup.configured);
      setShowQrCode(!setup.configured);
      setAdminStep('totp');
      setMfaMethod('totp');
      setSuccessMessage('Switched to Google Authenticator. Enter the 6-digit code from your app.');
    } catch (err: any) {
      setError(err.message || 'Failed to initialize Google Authenticator.');
    } finally {
      setLoading(false);
    }
  };

  // Agent Login Handler (Direct Support Agent Portal)
  const handleAgentLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccessMessage(null);

    if (!email.trim() || !password.trim()) {
      setError('Agent email and password are required.');
      return;
    }

    setLoading(true);
    try {
      const agentRes = await fetch('/api/support/agents/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email.trim(), password: password.trim() }),
      });

      if (!agentRes.ok) {
        const errData = await agentRes.json().catch(() => ({}));
        throw new Error(errData.message || 'Invalid agent credentials.');
      }

      const { token, agent } = await agentRes.json();

      // Store agent session
      localStorage.setItem('rentilly_agent_token', token);
      localStorage.setItem(
        'rentilly_agent_session',
        JSON.stringify({
          id: agent.id,
          name: agent.name,
          email: agent.email,
          role: agent.role,
        })
      );

      const agentUser = {
        id: agent.id,
        email: agent.email,
        fullName: agent.name,
        phoneNumber: '',
        role: 'customer_support' as const,
        isVerified: true,
        createdAt: agent.created_at || new Date().toISOString(),
        isAgent: true,
      } as unknown as UserProfile;

      onLoginSuccess(agentUser, token);
    } catch (agentErr: any) {
      setError(agentErr.message || 'Authentication failed. Please verify your agent credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#030712] flex flex-col justify-center items-center p-4 relative overflow-hidden font-sans select-none">
      {/* Ambient Glow */}
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[450px] h-[450px] bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-sm relative z-10 space-y-4">
        {/* Brand Header */}
        <div className="text-center space-y-1.5">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-emerald-600 shadow-xl shadow-emerald-950/60 mb-1 border border-emerald-400/30">
            {loginMode === 'admin' ? (
              <ShieldCheck className="w-6 h-6 text-white" />
            ) : (
              <Headphones className="w-6 h-6 text-white" />
            )}
          </div>
          <h1 className="text-xl font-extrabold text-white tracking-tight">Rentilly Operations Hub</h1>
          <p className="text-xs text-slate-400 max-w-xs mx-auto">
            {loginMode === 'admin'
              ? 'Multi-Factor Operations & Treasury Access Gateway'
              : 'Zero-Agent Real Estate Support Desk'}
          </p>
        </div>

        {/* Mode Toggle */}
        <div className="flex rounded-xl overflow-hidden border border-slate-800 bg-slate-900">
          <button
            type="button"
            onClick={() => handleModeSwitch('admin')}
            className={`flex-1 py-2 text-xs font-bold transition ${
              loginMode === 'admin' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Admin 2FA Gateway
          </button>
          <button
            type="button"
            onClick={() => handleModeSwitch('agent')}
            className={`flex-1 py-2 text-xs font-bold transition ${
              loginMode === 'agent' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Support Agent
          </button>
        </div>

        {/* Form Container */}
        <div className="p-6 rounded-2xl bg-[#0f172a] border border-slate-800 shadow-2xl space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-800">
            <span className="text-xs font-bold text-slate-300 flex items-center gap-1.5">
              <Lock className="w-3.5 h-3.5 text-emerald-400" />
              <span>
                {loginMode === 'admin'
                  ? adminStep === 'credentials'
                    ? 'Step 1: Admin Credentials & Harsh Key'
                    : adminStep === 'totp'
                    ? 'Step 2: Google Authenticator MFA'
                    : 'Step 2: Email 2FA Verification'
                  : 'Support Agent Gateway'}
              </span>
            </span>
            <span className="text-[10px] px-2.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">
              {loginMode === 'admin' ? 'MFA Enforced' : 'Support Team'}
            </span>
          </div>

          {/* Feedback Messages */}
          {error && (
            <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 text-red-400" />
              <span className="leading-tight">{error}</span>
            </div>
          )}

          {successMessage && (
            <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-400" />
              <span className="leading-tight">{successMessage}</span>
            </div>
          )}

          {/* ADMIN MODE - STEP 1: CREDENTIALS, HARSH KEY & MFA CHOICE */}
          {loginMode === 'admin' && adminStep === 'credentials' && (
            <form onSubmit={handleProceedTo2fa} className="space-y-3.5 text-xs">
              {/* Email */}
              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold text-xs">Admin Email Address</label>
                <div className="relative">
                  <Mail className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="Enter administrative email..."
                    className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 text-xs transition"
                  />
                </div>
              </div>

              {/* Password */}
              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold text-xs">Master Admin Password</label>
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

              {/* Admin Harsh Key */}
              <div className="space-y-1">
                <div className="flex items-center justify-between">
                  <label className="block text-slate-300 font-semibold text-xs flex items-center gap-1">
                    <KeyRound className="w-3.5 h-3.5 text-amber-400" />
                    <span>Admin Harsh Key</span>
                  </label>
                  <span className="text-[10px] text-amber-400/80 font-mono">Security Passphrase</span>
                </div>
                <div className="relative">
                  <ShieldAlert className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type={showHarshKey ? 'text' : 'password'}
                    required
                    value={harshKey}
                    onChange={(e) => setHarshKey(e.target.value)}
                    placeholder="Enter admin harsh key..."
                    className="w-full pl-9 pr-9 py-2.5 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-amber-500 text-xs transition font-mono"
                  />
                  <button
                    type="button"
                    onClick={() => setShowHarshKey(!showHarshKey)}
                    className="p-1 text-slate-500 hover:text-slate-300 absolute right-2.5 top-1/2 -translate-y-1/2"
                  >
                    {showHarshKey ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {/* 2FA Method Selector */}
              <div className="space-y-1.5 pt-1">
                <label className="block text-slate-300 font-semibold text-xs">Preferred MFA Method</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setMfaMethod('totp')}
                    className={`p-2.5 rounded-xl border text-left flex flex-col gap-1 transition ${
                      mfaMethod === 'totp'
                        ? 'bg-emerald-500/10 border-emerald-500/50 text-emerald-300'
                        : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:border-slate-700'
                    }`}
                  >
                    <div className="flex items-center gap-1.5 font-bold text-[11px]">
                      <Smartphone className="w-3.5 h-3.5 text-emerald-400" />
                      <span>Google Authenticator</span>
                    </div>
                    <span className="text-[9px] text-slate-400 leading-tight">Instant TOTP App Code</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setMfaMethod('email')}
                    className={`p-2.5 rounded-xl border text-left flex flex-col gap-1 transition ${
                      mfaMethod === 'email'
                        ? 'bg-emerald-500/10 border-emerald-500/50 text-emerald-300'
                        : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:border-slate-700'
                    }`}
                  >
                    <div className="flex items-center gap-1.5 font-bold text-[11px]">
                      <Mail className="w-3.5 h-3.5 text-blue-400" />
                      <span>Email Security OTP</span>
                    </div>
                    <span className="text-[9px] text-slate-400 leading-tight">One-time code to inbox</span>
                  </button>
                </div>
              </div>

              {/* Submit Button */}
              <button
                type="submit"
                disabled={loading}
                className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center justify-center gap-2 transform active:scale-98 disabled:opacity-50 mt-3"
              >
                {loading ? (
                  <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                ) : (
                  <>
                    <span>
                      {mfaMethod === 'totp' ? 'Proceed with Google Authenticator' : 'Request Email OTP Code'}
                    </span>
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
            </form>
          )}

          {/* ADMIN MODE - STEP 2A: GOOGLE AUTHENTICATOR (TOTP) */}
          {loginMode === 'admin' && adminStep === 'totp' && (
            <form onSubmit={handleVerifyTotp} className="space-y-4 text-xs">
              {/* QR Code & Setup Section (Shown when requested or for new setup) */}
              {showQrCode && qrCodeDataUrl && (
                <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800 space-y-3 text-center">
                  <div className="flex items-center justify-center gap-1.5 text-emerald-400 font-bold text-xs">
                    <QrCode className="w-4 h-4" />
                    <span>Scan with Google Authenticator</span>
                  </div>

                  <div className="bg-white p-2.5 rounded-xl inline-block shadow-lg">
                    <img
                      src={qrCodeDataUrl}
                      alt="Google Authenticator QR Code"
                      className="w-44 h-44 mx-auto block"
                    />
                  </div>

                  <p className="text-[10px] text-slate-400 leading-tight max-w-xs mx-auto">
                    Open Google Authenticator (or Authy / 1Password), tap <span className="text-white font-bold">+</span> and scan the QR code above.
                  </p>

                  {/* Manual Key Display */}
                  {totpSecret && (
                    <div className="pt-2 border-t border-slate-800 space-y-1">
                      <span className="text-[10px] text-slate-400 block">Can't scan? Enter key manually:</span>
                      <div className="flex items-center justify-between gap-1 p-1.5 rounded-lg bg-[#030712] border border-slate-800">
                        <span className="font-mono text-[10px] text-amber-400 truncate pl-1 select-all">
                          {totpSecret}
                        </span>
                        <button
                          type="button"
                          onClick={handleCopySecret}
                          className="px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 text-[10px] flex items-center gap-1 transition shrink-0"
                        >
                          {copiedSecret ? (
                            <>
                              <Check className="w-3 h-3 text-emerald-400" />
                              <span className="text-emerald-400">Copied</span>
                            </>
                          ) : (
                            <>
                              <Copy className="w-3 h-3" />
                              <span>Copy</span>
                            </>
                          )}
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* TOTP 6-Digit Code Input */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <label className="block text-slate-300 font-semibold text-xs flex items-center gap-1.5">
                    <Smartphone className="w-3.5 h-3.5 text-emerald-400" />
                    <span>Google Authenticator 6-Digit Code</span>
                    {totpConfigured && (
                      <span className="text-[9px] px-1.5 py-0.2 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono">
                        Active
                      </span>
                    )}
                  </label>
                  <button
                    type="button"
                    onClick={() => setShowQrCode(!showQrCode)}
                    className="text-[10px] text-emerald-400 hover:text-emerald-300 font-semibold transition"
                  >
                    {showQrCode ? 'Hide QR Code' : 'Show / Scan QR Code'}
                  </button>
                </div>

                <input
                  type="text"
                  maxLength={6}
                  autoFocus
                  required
                  value={totpCode}
                  onChange={(e) => setTotpCode(e.target.value.replace(/\D/g, ''))}
                  placeholder="000000"
                  className="w-full py-3 text-center text-2xl font-mono tracking-widest rounded-xl bg-[#030712] border border-slate-800 text-white focus:outline-none focus:border-emerald-500 transition"
                />
              </div>

              {/* Submit Button */}
              <button
                type="submit"
                disabled={loading || totpCode.length < 6}
                className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center justify-center gap-2 transform active:scale-98 disabled:opacity-50"
              >
                {loading ? (
                  <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                ) : (
                  <>
                    <span>Verify MFA &amp; Enter Console</span>
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>

              {/* Switch to Email OTP or Change Credentials */}
              <div className="flex items-center justify-between pt-2 border-t border-slate-800 text-[11px]">
                <button
                  type="button"
                  disabled={loading}
                  onClick={handleSwitchToEmailOtp}
                  className="text-slate-400 hover:text-blue-400 flex items-center gap-1 transition"
                >
                  <Mail className="w-3 h-3" />
                  <span>Use Email OTP instead</span>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setAdminStep('credentials');
                    setTotpCode('');
                    setError(null);
                  }}
                  className="text-slate-400 hover:text-slate-200 transition"
                >
                  Change Credentials
                </button>
              </div>
            </form>
          )}

          {/* ADMIN MODE - STEP 2B: EMAIL OTP VERIFICATION */}
          {loginMode === 'admin' && adminStep === 'email_otp' && (
            <form onSubmit={handleVerifyEmailOtp} className="space-y-4 text-xs">
              <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 text-center space-y-1">
                <p className="text-[11px] text-slate-400">Authorization code dispatched to:</p>
                <p className="font-mono text-xs font-bold text-emerald-400">{email}</p>
              </div>

              <div className="space-y-1.5">
                <label className="block text-slate-300 font-semibold text-xs text-center">
                  Enter 6-Digit Email Code
                </label>
                <input
                  type="text"
                  maxLength={6}
                  autoFocus
                  required
                  value={otpCode}
                  onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
                  placeholder="000000"
                  className="w-full py-3 text-center text-xl font-mono tracking-widest rounded-xl bg-[#030712] border border-slate-800 text-white focus:outline-none focus:border-emerald-500 transition"
                />
              </div>

              <button
                type="submit"
                disabled={loading || otpCode.length < 6}
                className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center justify-center gap-2 transform active:scale-98 disabled:opacity-50"
              >
                {loading ? (
                  <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                ) : (
                  <>
                    <span>Verify Code &amp; Enter Console</span>
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>

              <div className="flex items-center justify-between pt-2 border-t border-slate-800 text-[11px]">
                <button
                  type="button"
                  disabled={loading || resendCooldown > 0}
                  onClick={handleResendEmailOtp}
                  className="text-slate-400 hover:text-emerald-400 flex items-center gap-1 transition disabled:opacity-40"
                >
                  <RotateCcw className="w-3 h-3" />
                  <span>{resendCooldown > 0 ? `Resend code in ${resendCooldown}s` : 'Resend Code'}</span>
                </button>

                <button
                  type="button"
                  disabled={loading}
                  onClick={handleSwitchToTotp}
                  className="text-slate-400 hover:text-emerald-400 flex items-center gap-1 transition"
                >
                  <Smartphone className="w-3 h-3" />
                  <span>Use Google Authenticator</span>
                </button>
              </div>

              <div className="text-center pt-1">
                <button
                  type="button"
                  onClick={() => {
                    setAdminStep('credentials');
                    setOtpCode('');
                    setError(null);
                  }}
                  className="text-slate-500 hover:text-slate-300 text-[10px] transition"
                >
                  Back to Credentials
                </button>
              </div>
            </form>
          )}

          {/* AGENT MODE */}
          {loginMode === 'agent' && (
            <form onSubmit={handleAgentLogin} className="space-y-3.5 text-xs">
              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold text-xs">Agent Email Address</label>
                <div className="relative">
                  <Mail className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="agent@myrentilly.com"
                    className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 text-xs transition"
                  />
                </div>
              </div>

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

              <button
                type="submit"
                disabled={loading}
                className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center justify-center gap-2 transform active:scale-98 disabled:opacity-50 mt-2"
              >
                {loading ? (
                  <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                ) : (
                  <>
                    <span>Enter Support Portal</span>
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
            </form>
          )}
        </div>

        {/* Security Notice */}
        <div className="text-center text-[11px] text-slate-500 space-y-1">
          <p className="flex items-center justify-center gap-1.5 text-slate-400">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
            <span>Encrypted Multi-Tier Authorization Protocol</span>
          </p>
          <p>Restricted to verified executive administrators and support personnel.</p>
        </div>
      </div>
    </div>
  );
};
