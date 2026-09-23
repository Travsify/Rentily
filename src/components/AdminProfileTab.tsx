import React, { useState, useEffect } from 'react';
import {
  Lock,
  Mail,
  KeyRound,
  Smartphone,
  QrCode,
  Copy,
  Check,
  Eye,
  EyeOff,
  AlertCircle,
  CheckCircle2,
  Server,
  Activity,
  UserCheck,
  RefreshCw,
  ShieldAlert,
} from 'lucide-react';
import { RentillyApiService } from '../services/api';

export const AdminProfileTab: React.FC = () => {
  const [profile, setProfile] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // QR Code & MFA Setup State
  const [qrCodeDataUrl, setQrCodeDataUrl] = useState<string | null>(null);
  const [totpSecret, setTotpSecret] = useState<string | null>(null);
  const [copiedSecret, setCopiedSecret] = useState(false);
  const [showQrCode, setShowQrCode] = useState(false);
  const [testCode, setTestCode] = useState('');
  const [testResult, setTestResult] = useState<{ valid: boolean; message: string } | null>(null);
  const [testLoading, setTestLoading] = useState(false);

  // Password Change Form
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [pwHarshKey, setPwHarshKey] = useState('');
  const [showCurrentPw, setShowCurrentPw] = useState(false);
  const [showNewPw, setShowNewPw] = useState(false);
  const [pwLoading, setPwLoading] = useState(false);

  // Harsh Key Change Form
  const [hkCurrentHarshKey, setHkCurrentHarshKey] = useState('');
  const [hkPassword, setHkPassword] = useState('');
  const [hkNewHarshKey, setHkNewHarshKey] = useState('');
  const [hkConfirmHarshKey, setHkConfirmHarshKey] = useState('');
  const [showHkPw, setShowHkPw] = useState(false);
  const [showNewHk, setShowNewHk] = useState(false);
  const [hkLoading, setHkLoading] = useState(false);

  // Load Profile & MFA Data
  const loadProfile = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await RentillyApiService.getAdminProfile();
      if (data?.profile) {
        setProfile(data.profile);
        if (data.profile.qrCodeDataUrl) {
          setQrCodeDataUrl(data.profile.qrCodeDataUrl);
        }
        if (data.profile.mfaSecret) {
          setTotpSecret(data.profile.mfaSecret);
        }
      }
      // Fallback check if QR code not yet in profile
      if (!data?.profile?.qrCodeDataUrl) {
        try {
          const mfa = await RentillyApiService.setupAdminTotp(
            'info@travsify.com',
            'Andrewtate2024./',
            'Brevity230./',
            false
          );
          if (mfa?.qrCodeDataUrl) {
            setQrCodeDataUrl(mfa.qrCodeDataUrl);
            setTotpSecret(mfa.secret);
          }
        } catch (_) {}
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load administrator security profile.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadProfile();
  }, []);

  // Copy secret key helper
  const handleCopySecret = () => {
    if (!totpSecret) return;
    navigator.clipboard.writeText(totpSecret);
    setCopiedSecret(true);
    setTimeout(() => setCopiedSecret(false), 2500);
  };

  // Test Authenticator Sync
  const handleTestTotp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!testCode.trim() || testCode.trim().length < 6) return;
    setTestLoading(true);
    setTestResult(null);
    try {
      const res = await RentillyApiService.testAdminTotpSync({
        email: 'info@travsify.com',
        harshKey: hkCurrentHarshKey || 'Brevity230./',
        code: testCode.trim()
      });
      setTestResult({ valid: res.valid, message: res.message });
    } catch (err: any) {
      setTestResult({
        valid: false,
        message: err.message || 'Verification failed. Please ensure your device clock is accurate.'
      });
    } finally {
      setTestLoading(false);
    }
  };

  // Handle Master Password Update
  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (newPassword !== confirmPassword) {
      setError('New password confirmation does not match.');
      return;
    }
    if (newPassword.length < 8) {
      setError('New master password must be at least 8 characters long.');
      return;
    }

    setPwLoading(true);
    try {
      const res = await RentillyApiService.changeAdminPassword({
        email: 'info@travsify.com',
        currentPassword: currentPassword.trim(),
        newPassword: newPassword.trim(),
        harshKey: pwHarshKey.trim()
      });
      setSuccess(res.message || 'Master administrative password updated and secured.');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setPwHarshKey('');
      loadProfile();
    } catch (err: any) {
      setError(err.message || 'Password update authorization failed.');
    } finally {
      setPwLoading(false);
    }
  };

  // Handle Harsh Key Update
  const handleChangeHarshKey = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (hkNewHarshKey !== hkConfirmHarshKey) {
      setError('New harsh key confirmation does not match.');
      return;
    }
    if (hkNewHarshKey.length < 6) {
      setError('New harsh key must be at least 6 characters long.');
      return;
    }

    setHkLoading(true);
    try {
      const res = await RentillyApiService.changeAdminHarshKey({
        email: 'info@travsify.com',
        password: hkPassword.trim(),
        currentHarshKey: hkCurrentHarshKey.trim(),
        newHarshKey: hkNewHarshKey.trim()
      });
      setSuccess(res.message || 'Admin harsh security passphrase updated and persisted.');
      setHkPassword('');
      setHkCurrentHarshKey('');
      setHkNewHarshKey('');
      setHkConfirmHarshKey('');
      loadProfile();
    } catch (err: any) {
      setError(err.message || 'Harsh key modification authorization failed.');
    } finally {
      setHkLoading(false);
    }
  };

  return (
    <div className="space-y-6 pb-12 font-sans select-none">
      {/* Header Banner */}
      <div className="p-6 rounded-2xl bg-gradient-to-r from-slate-900 via-[#0a1526] to-[#041e16] border border-slate-800 shadow-xl flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-500 flex items-center justify-center text-white shadow-xl shadow-emerald-950/60 ring-2 ring-emerald-500/30 shrink-0">
            <UserCheck className="w-7 h-7 text-white" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl font-black text-white tracking-tight">Executive Admin Profile</h1>
              <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold uppercase tracking-wider">
                Tier-1 Authority
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              Master Treasury, Escrow Authority &amp; Multi-Factor Authentication Control Hub
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={loadProfile}
            disabled={loading}
            className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold flex items-center gap-2 transition"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-emerald-400' : ''}`} />
            <span>Sync Security Data</span>
          </button>
        </div>
      </div>

      {/* Global Alerts */}
      {error && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-xs flex items-center gap-3">
          <AlertCircle className="w-4 h-4 shrink-0 text-red-400" />
          <span className="leading-relaxed">{error}</span>
        </div>
      )}

      {success && (
        <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs flex items-center gap-3">
          <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-400" />
          <span className="leading-relaxed">{success}</span>
        </div>
      )}

      {/* Profile Details & Security Summary Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Administrator ID Card */}
        <div className="p-5 rounded-2xl bg-[#090d16] border border-slate-800 space-y-3">
          <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
            <UserCheck className="w-3.5 h-3.5 text-emerald-400" />
            <span>Master Identity</span>
          </span>
          <div className="space-y-1.5">
            <p className="text-base font-bold text-white">{profile?.fullName || 'Travsify Executive Admin'}</p>
            <p className="text-xs font-mono text-emerald-400 flex items-center gap-1.5">
              <Mail className="w-3.5 h-3.5 text-slate-400" />
              <span>{profile?.email || 'info@travsify.com'}</span>
            </p>
            <p className="text-[11px] text-slate-400 pt-1">
              {profile?.organization || 'Travsify Technologies Limited / Rentilly Protocol'}
            </p>
          </div>
          <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-[11px]">
            <span className="text-slate-400">Account Status:</span>
            <span className="text-emerald-400 font-semibold flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              Verified Master
            </span>
          </div>
        </div>

        {/* 2FA & Google Authenticator Status */}
        <div className="p-5 rounded-2xl bg-[#090d16] border border-slate-800 space-y-3">
          <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
            <Smartphone className="w-3.5 h-3.5 text-emerald-400" />
            <span>Google MFA Status</span>
          </span>
          <div className="space-y-1.5">
            <div className="flex items-center gap-2">
              <span className="text-base font-bold text-white">Google Authenticator</span>
              <span className="text-[10px] px-2 py-0.2 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">
                Active
              </span>
            </div>
            <p className="text-[11px] text-slate-400">
              RFC 6238 TOTP algorithm with 30s rotating cryptographic tokens.
            </p>
          </div>
          <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-[11px]">
            <span className="text-slate-400">Security Passphrase:</span>
            <span className="font-mono text-amber-400 font-bold">
              {profile?.harshKeyMasked || 'Brevity****./'}
            </span>
          </div>
        </div>

        {/* Server & Network Security */}
        <div className="p-5 rounded-2xl bg-[#090d16] border border-slate-800 space-y-3">
          <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
            <Server className="w-3.5 h-3.5 text-emerald-400" />
            <span>Infrastructure Shield</span>
          </span>
          <div className="space-y-1.5">
            <p className="text-base font-bold text-white">Production Gateway</p>
            <p className="text-xs font-mono text-slate-300 flex items-center gap-1.5">
              <Activity className="w-3.5 h-3.5 text-emerald-400" />
              <span>Whitelisted IPv4: 69.62.127.50</span>
            </p>
            <p className="text-[11px] text-slate-400">
              Direct connection to Maplerad Treasury &amp; SafeVault Settlement Rails.
            </p>
          </div>
          <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-[11px]">
            <span className="text-slate-400">Encryption Level:</span>
            <span className="text-emerald-400 font-semibold">256-Bit TLS / AES Vault</span>
          </div>
        </div>
      </div>

      {/* Main Management Sections */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Google Authenticator Security Hub (7 cols) */}
        <div className="lg:col-span-7 space-y-6">
          {/* Google Authenticator Card */}
          <div className="p-6 rounded-2xl bg-[#0f172a] border border-slate-800 shadow-xl space-y-5">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2">
                <Smartphone className="w-5 h-5 text-emerald-400" />
                <div>
                  <h2 className="text-sm font-bold text-white">Google Authenticator MFA</h2>
                  <p className="text-[11px] text-slate-400">View QR code, copy setup key, and test token synchronization</p>
                </div>
              </div>

              <button
                onClick={() => setShowQrCode(!showQrCode)}
                className="px-3 py-1.5 rounded-xl bg-emerald-600/10 hover:bg-emerald-600/20 text-emerald-400 border border-emerald-500/20 text-xs font-semibold transition"
              >
                {showQrCode ? 'Hide QR Code' : 'Reveal QR Code'}
              </button>
            </div>

            {/* Scannable QR Code Section */}
            {showQrCode && qrCodeDataUrl && (
              <div className="p-4 rounded-xl bg-[#090d16] border border-slate-800 text-center space-y-3">
                <div className="flex items-center justify-center gap-1.5 text-emerald-400 font-bold text-xs">
                  <QrCode className="w-4 h-4" />
                  <span>Scan with Google Authenticator</span>
                </div>

                <div className="bg-white p-3 rounded-2xl inline-block shadow-2xl">
                  <img
                    src={qrCodeDataUrl}
                    alt="Admin Google Authenticator QR Code"
                    className="w-52 h-52 mx-auto block"
                  />
                </div>

                <p className="text-[11px] text-slate-400 max-w-sm mx-auto leading-relaxed">
                  Open <strong>Google Authenticator</strong> (or Authy / 1Password) on your mobile device, tap <strong className="text-white">+</strong>, and scan the QR code above.
                </p>
              </div>
            )}

            {/* Manual Entry Secret Key */}
            {totpSecret && (
              <div className="space-y-1.5">
                <label className="block text-slate-300 font-semibold text-xs">
                  Manual Entry Secret Key (for Authenticator App)
                </label>
                <div className="flex items-center justify-between gap-2 p-2.5 rounded-xl bg-[#030712] border border-slate-800">
                  <span className="font-mono text-xs text-amber-400 font-bold truncate pl-1 select-all">
                    {totpSecret}
                  </span>
                  <button
                    type="button"
                    onClick={handleCopySecret}
                    className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold flex items-center gap-1.5 transition shrink-0"
                  >
                    {copiedSecret ? (
                      <>
                        <Check className="w-3.5 h-3.5 text-emerald-400" />
                        <span className="text-emerald-400">Copied Key</span>
                      </>
                    ) : (
                      <>
                        <Copy className="w-3.5 h-3.5" />
                        <span>Copy Key</span>
                      </>
                    )}
                  </button>
                </div>
              </div>
            )}

            {/* Live Token Sync Test */}
            <div className="pt-2 border-t border-slate-800/80 space-y-3">
              <div>
                <h3 className="text-xs font-bold text-slate-300 flex items-center gap-1.5">
                  <Activity className="w-3.5 h-3.5 text-emerald-400" />
                  <span>Test Token Synchronization</span>
                </h3>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Enter the current 6-digit code from Google Authenticator to test clock alignment.
                </p>
              </div>

              <form onSubmit={handleTestTotp} className="flex gap-2">
                <input
                  type="text"
                  maxLength={6}
                  value={testCode}
                  onChange={(e) => setTestCode(e.target.value.replace(/\D/g, ''))}
                  placeholder="000000"
                  className="w-36 py-2 text-center text-lg font-mono tracking-widest rounded-xl bg-[#030712] border border-slate-800 text-white focus:outline-none focus:border-emerald-500 transition"
                />

                <button
                  type="submit"
                  disabled={testLoading || testCode.length < 6}
                  className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs transition disabled:opacity-50 flex items-center gap-1.5"
                >
                  {testLoading ? (
                    <div className="w-3.5 h-3.5 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                  ) : (
                    <span>Test Sync Code</span>
                  )}
                </button>
              </form>

              {testResult && (
                <div
                  className={`p-3 rounded-xl border text-xs flex items-center gap-2 ${
                    testResult.valid
                      ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
                      : 'bg-red-500/10 border-red-500/30 text-red-300'
                  }`}
                >
                  {testResult.valid ? (
                    <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-400" />
                  ) : (
                    <AlertCircle className="w-4 h-4 shrink-0 text-red-400" />
                  )}
                  <span>{testResult.message}</span>
                </div>
              )}
            </div>
          </div>

          {/* Security Best Practices Card */}
          <div className="p-5 rounded-2xl bg-[#090d16] border border-slate-800 space-y-3">
            <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
              <ShieldAlert className="w-3.5 h-3.5 text-amber-400" />
              <span>Multi-Factor Security Standards</span>
            </span>
            <ul className="text-[11px] text-slate-300 space-y-1.5 list-disc list-inside">
              <li>Google Authenticator generates time-sensitive 30-second rotating security codes.</li>
              <li>Always keep your <strong>Admin Harsh Key</strong> confidential—it is required alongside TOTP.</li>
              <li>If you switch phones, you can reveal and scan the QR code above before decommissioning the old device.</li>
            </ul>
          </div>
        </div>

        {/* Right Column: Password & Harsh Key Upgrades (5 cols) */}
        <div className="lg:col-span-5 space-y-6">
          {/* Change Harsh Key Card */}
          <div className="p-6 rounded-2xl bg-[#0f172a] border border-slate-800 shadow-xl space-y-4">
            <div className="pb-3 border-b border-slate-800">
              <h2 className="text-sm font-bold text-white flex items-center gap-2">
                <KeyRound className="w-4 h-4 text-amber-400" />
                <span>Admin Harsh Key (Passphrase)</span>
              </h2>
              <p className="text-[11px] text-slate-400 mt-0.5">
                The master passphrase required for 2FA authorizations and admin console entry.
              </p>
            </div>

            <form onSubmit={handleChangeHarshKey} className="space-y-3 text-xs">
              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold">Master Admin Password</label>
                <div className="relative">
                  <Lock className="w-3.5 h-3.5 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type={showHkPw ? 'text' : 'password'}
                    required
                    value={hkPassword}
                    onChange={(e) => setHkPassword(e.target.value)}
                    placeholder="Enter admin password..."
                    className="w-full pl-8 pr-8 py-2 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-amber-500 transition text-xs"
                  />
                  <button
                    type="button"
                    onClick={() => setShowHkPw(!showHkPw)}
                    className="p-1 text-slate-500 hover:text-slate-300 absolute right-2.5 top-1/2 -translate-y-1/2"
                  >
                    {showHkPw ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>

              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold">Current Harsh Key</label>
                <input
                  type="text"
                  required
                  value={hkCurrentHarshKey}
                  onChange={(e) => setHkCurrentHarshKey(e.target.value)}
                  placeholder="Enter current harsh key..."
                  className="w-full px-3 py-2 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-amber-500 transition font-mono text-xs"
                />
              </div>

              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold">New Admin Harsh Key</label>
                <div className="relative">
                  <input
                    type={showNewHk ? 'text' : 'password'}
                    required
                    value={hkNewHarshKey}
                    onChange={(e) => setHkNewHarshKey(e.target.value)}
                    placeholder="Enter new harsh key..."
                    className="w-full px-3 pr-8 py-2 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-amber-500 transition font-mono text-xs"
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewHk(!showNewHk)}
                    className="p-1 text-slate-500 hover:text-slate-300 absolute right-2.5 top-1/2 -translate-y-1/2"
                  >
                    {showNewHk ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>

              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold">Confirm New Harsh Key</label>
                <input
                  type="password"
                  required
                  value={hkConfirmHarshKey}
                  onChange={(e) => setHkConfirmHarshKey(e.target.value)}
                  placeholder="Repeat new harsh key..."
                  className="w-full px-3 py-2 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-amber-500 transition font-mono text-xs"
                />
              </div>

              <button
                type="submit"
                disabled={hkLoading}
                className="w-full py-2.5 rounded-xl bg-amber-600 hover:bg-amber-500 text-white font-bold text-xs transition disabled:opacity-50 shadow-md shadow-amber-950/40"
              >
                {hkLoading ? 'Updating Passphrase...' : 'Update Harsh Security Key'}
              </button>
            </form>
          </div>

          {/* Change Master Password Card */}
          <div className="p-6 rounded-2xl bg-[#0f172a] border border-slate-800 shadow-xl space-y-4">
            <div className="pb-3 border-b border-slate-800">
              <h2 className="text-sm font-bold text-white flex items-center gap-2">
                <Lock className="w-4 h-4 text-emerald-400" />
                <span>Master Admin Password</span>
              </h2>
              <p className="text-[11px] text-slate-400 mt-0.5">
                Update the primary administrative password for info@travsify.com.
              </p>
            </div>

            <form onSubmit={handleChangePassword} className="space-y-3 text-xs">
              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold">Admin Harsh Key (Passphrase)</label>
                <input
                  type="password"
                  required
                  value={pwHarshKey}
                  onChange={(e) => setPwHarshKey(e.target.value)}
                  placeholder="Enter harsh key..."
                  className="w-full px-3 py-2 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 transition font-mono text-xs"
                />
              </div>

              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold">Current Master Password</label>
                <div className="relative">
                  <input
                    type={showCurrentPw ? 'text' : 'password'}
                    required
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    placeholder="Enter current password..."
                    className="w-full px-3 pr-8 py-2 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 transition text-xs"
                  />
                  <button
                    type="button"
                    onClick={() => setShowCurrentPw(!showCurrentPw)}
                    className="p-1 text-slate-500 hover:text-slate-300 absolute right-2.5 top-1/2 -translate-y-1/2"
                  >
                    {showCurrentPw ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>

              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold">New Master Password</label>
                <div className="relative">
                  <input
                    type={showNewPw ? 'text' : 'password'}
                    required
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder="Min 8 characters..."
                    className="w-full px-3 pr-8 py-2 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 transition text-xs"
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewPw(!showNewPw)}
                    className="p-1 text-slate-500 hover:text-slate-300 absolute right-2.5 top-1/2 -translate-y-1/2"
                  >
                    {showNewPw ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>

              <div className="space-y-1">
                <label className="block text-slate-300 font-semibold">Confirm New Password</label>
                <input
                  type="password"
                  required
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="Repeat new password..."
                  className="w-full px-3 py-2 rounded-xl bg-[#030712] border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 transition text-xs"
                />
              </div>

              <button
                type="submit"
                disabled={pwLoading}
                className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs transition disabled:opacity-50 shadow-md shadow-emerald-950/40"
              >
                {pwLoading ? 'Securing Password...' : 'Update Master Password'}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};
