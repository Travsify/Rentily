import { useState, useEffect } from 'react';
import { Navbar } from './components/Navbar';
import { Sidebar } from './components/Sidebar';
import { OverviewTab } from './components/OverviewTab';
import { UsersTab } from './components/UsersTab';
import { KYPVerificationTab } from './components/KYPVerificationTab';
import { KYPModal } from './components/KYPModal';
import { PropertiesTab } from './components/PropertiesTab';
import { PropertyModal } from './components/PropertyModal';
import { InspectionsTab } from './components/InspectionsTab';
import { EscrowTab } from './components/EscrowTab';
import { LegalAgreementsTab } from './components/LegalAgreementsTab';
import { FraudBlacklistTab } from './components/FraudBlacklistTab';
import { SupportDeskTab } from './components/SupportDeskTab';
import { MasterLedgerTab } from './components/MasterLedgerTab';
import { FeeSettingsTab } from './components/FeeSettingsTab';
import { BillsDeskTab } from './components/BillsDeskTab';
import { ChatOversightTab } from './components/ChatOversightTab';
import { BroadcastTab } from './components/BroadcastTab';
import { CautionClaimsTab } from './components/CautionClaimsTab';
import { StatutoryNoticesTab } from './components/StatutoryNoticesTab';
import { LeaseRenewalsTab } from './components/LeaseRenewalsTab';
import { ReconciliationTab } from './components/ReconciliationTab';
import { GlobalCardsDeskTab } from './components/GlobalCardsDeskTab';
import { IntegrationsTab } from './components/IntegrationsTab';
import { FeatureFlagsTab } from './components/FeatureFlagsTab';
import { SupabaseConfigTab } from './components/SupabaseConfigTab';
import { FlutterApiDocsTab } from './components/FlutterApiDocsTab';
import { AdminLoginPage } from './components/AdminLoginPage';
import { RentillyApiService, checkServerHealth } from './services/api';
import type { AdminTab, Property, KYPRecord, Inspection, Transaction, LegalAgreement, UserProfile } from './types';

export default function App() {
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(null);
  const [currentTab, setCurrentTab] = useState<AdminTab>('overview');
  
  // Data State
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [properties, setProperties] = useState<Property[]>([]);
  const [kypRecords, setKypRecords] = useState<KYPRecord[]>([]);
  const [inspections, setInspections] = useState<Inspection[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [legalAgreements, setLegalAgreements] = useState<LegalAgreement[]>([]);
  
  // Modals
  const [isAddPropertyModalOpen, setIsAddPropertyModalOpen] = useState(false);
  const [selectedKYP, setSelectedKYP] = useState<KYPRecord | null>(null);

  // Server & Supabase connection status
  const [serverStatus, setServerStatus] = useState({ connected: false, supabase: false });
  const [loading, setLoading] = useState(true);

  // Check existing login session & server status on mount
  useEffect(() => {
    const existingUser = RentillyApiService.getCurrentUser();
    if (existingUser) {
      setCurrentUser(existingUser);
    }
    loadData();

    // Auto-polling interval: refreshes data every 25 seconds for real-time responsiveness
    const pollTimer = setInterval(() => {
      loadData();
    }, 25000);

    return () => clearInterval(pollTimer);
  }, []);

  // Load all initial data
  const loadData = async () => {
    try {
      const [props, kyps, insps, txns, legals, allUsers] = await Promise.all([
        RentillyApiService.getProperties(),
        RentillyApiService.getKYPRecords(),
        RentillyApiService.getInspections(),
        RentillyApiService.getTransactions(),
        RentillyApiService.getLegalAgreements(),
        RentillyApiService.getUsers()
      ]);

      setProperties(props);
      setKypRecords(kyps);
      setInspections(insps);
      setTransactions(txns);
      setLegalAgreements(legals);
      setUsers(allUsers);

      // Check health against live Render / local API
      const health = await checkServerHealth();
      if (health) {
        setServerStatus({ connected: true, supabase: health.supabaseConnected });
      }
    } catch (e) {
      console.error('Failed loading Rentilly data', e);
    } finally {
      setLoading(false);
    }
  };

  // Auth Handlers
  const handleLoginSuccess = (user: UserProfile) => {
    setCurrentUser(user);
    loadData();
  };

  const handleLogout = () => {
    RentillyApiService.logout();
    setCurrentUser(null);
  };

  // Property & Verification Handlers
  const handleSaveProperty = async (propertyData: any) => {
    await RentillyApiService.createProperty(propertyData);
    await loadData();
    setCurrentTab('properties');
  };

  const handleReviewKYP = async (
    kypId: string, 
    status: 'approved' | 'rejected' | 'more_info_required',
    notes?: string,
    rejectionReason?: string
  ) => {
    await RentillyApiService.reviewKYP(kypId, status, notes, rejectionReason);
    await loadData();
  };

  const handleBookInspection = async (data: any) => {
    await RentillyApiService.bookInspection(data);
    await loadData();
  };

  const handleUpdateInspectionStatus = async (id: string, status: Inspection['status'], notes?: string) => {
    await RentillyApiService.updateInspectionStatus(id, status, notes);
    await loadData();
  };

  const handleReleaseEscrowPayout = async (transactionId: string) => {
    await RentillyApiService.releaseEscrowPayout(transactionId);
    await loadData();
  };

  const pendingKypCount = kypRecords.filter(k => k.status === 'pending').length;
  const activeInspectionsCount = inspections.filter(i => i.status === 'confirmed').length;
  const escrowTotalAmount = transactions
    .filter(t => t.escrowStatus === 'held_in_escrow')
    .reduce((sum, t) => sum + t.totalAmount, 0);

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center text-slate-400 space-y-3">
        <div className="w-10 h-10 border-4 border-emerald-500/20 border-t-emerald-500 rounded-full animate-spin"></div>
        <p className="text-sm font-medium">Connecting to Rentilly Operations Hub...</p>
      </div>
    );
  }

  // If not logged in, render the Admin Login Page
  if (!currentUser) {
    return <AdminLoginPage onLoginSuccess={handleLoginSuccess} />;
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans">
      {/* Top Navigation */}
      <Navbar
        currentTab={currentTab}
        setCurrentTab={setCurrentTab}
        pendingKypCount={pendingKypCount}
        serverStatus={serverStatus}
        currentUser={currentUser}
        onOpenAddProperty={() => setIsAddPropertyModalOpen(true)}
        onRefreshData={loadData}
        onLogout={handleLogout}
      />

      {/* Main Layout */}
      <div className="flex-1 flex">
        {/* Sidebar */}
        <Sidebar
          currentTab={currentTab}
          setCurrentTab={setCurrentTab}
          pendingKypCount={pendingKypCount}
          activeInspectionsCount={activeInspectionsCount}
          escrowTotalAmount={escrowTotalAmount}
        />

        {/* Dynamic Content Viewport */}
        <main className="flex-1 p-5 lg:p-6 overflow-y-auto max-h-[calc(100vh-57px)] bg-slate-950">
          {currentTab === 'overview' && (
            <OverviewTab
              properties={properties}
              kypRecords={kypRecords}
              inspections={inspections}
              transactions={transactions}
              setCurrentTab={setCurrentTab}
              onOpenKYPModal={(kyp) => setSelectedKYP(kyp)}
            />
          )}

          {currentTab === 'users' && (
            <UsersTab users={users} />
          )}

          {currentTab === 'kyp' && (
            <KYPVerificationTab
              kypRecords={kypRecords}
              onOpenKYPModal={(kyp) => setSelectedKYP(kyp)}
            />
          )}

          {currentTab === 'properties' && (
            <PropertiesTab
              properties={properties}
              onOpenAddModal={() => setIsAddPropertyModalOpen(true)}
              setCurrentTab={setCurrentTab}
            />
          )}

          {currentTab === 'inspections' && (
            <InspectionsTab
              inspections={inspections}
              properties={properties}
              onBookInspection={handleBookInspection}
              onUpdateStatus={handleUpdateInspectionStatus}
            />
          )}

          {currentTab === 'escrow' && (
            <EscrowTab
              transactions={transactions}
              onReleasePayout={handleReleaseEscrowPayout}
            />
          )}

          {currentTab === 'legal' && (
            <LegalAgreementsTab
              agreements={legalAgreements}
            />
          )}

          {currentTab === 'master_ledger' && (
            <MasterLedgerTab />
          )}

          {currentTab === 'caution_claims' && (
            <CautionClaimsTab />
          )}

          {currentTab === 'reconciliation' && (
            <ReconciliationTab />
          )}

          {currentTab === 'global_cards' && (
            <GlobalCardsDeskTab />
          )}

          {currentTab === 'statutory_notices' && (
            <StatutoryNoticesTab />
          )}

          {currentTab === 'lease_renewals' && (
            <LeaseRenewalsTab />
          )}

          {currentTab === 'fee_settings' && (
            <FeeSettingsTab />
          )}

          {currentTab === 'bills_operations' && (
            <BillsDeskTab />
          )}

          {currentTab === 'chat_oversight' && (
            <ChatOversightTab />
          )}

          {currentTab === 'broadcast' && (
            <BroadcastTab />
          )}

          {currentTab === 'fraud_blacklist' && (
            <FraudBlacklistTab />
          )}

          {currentTab === 'support_tickets' && (
            <SupportDeskTab />
          )}

          {currentTab === 'integrations' && (
            <IntegrationsTab />
          )}

          {currentTab === 'feature_flags' && (
            <FeatureFlagsTab />
          )}

          {currentTab === 'supabase_config' && (
            <SupabaseConfigTab />
          )}

          {currentTab === 'flutter_api' && (
            <FlutterApiDocsTab />
          )}
        </main>
      </div>

      {/* Modals */}
      <PropertyModal
        isOpen={isAddPropertyModalOpen}
        onClose={() => setIsAddPropertyModalOpen(false)}
        onSave={handleSaveProperty}
      />

      <KYPModal
        kyp={selectedKYP}
        onClose={() => setSelectedKYP(null)}
        onReview={handleReviewKYP}
      />
    </div>
  );
}
