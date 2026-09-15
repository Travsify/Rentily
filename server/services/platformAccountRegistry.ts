import { supabase } from '../supabaseClient';

export type EcosystemApp = 'rentilly' | 'gigaride' | 'kartlily' | 'pickpadi' | 'hometrust';

export interface VirtualAccountRecord {
  app: EcosystemApp;
  platform: string;
  accountNumber: string;
  virtualAccountId: string;
  bankName: string;
  bankCode: string;
  userId?: string;
  userEmail?: string;
  accountName?: string;
  rentillyId?: string;
  createdAt: string;
}

export class PlatformAccountRegistry {
  private static memoryCache = new Map<string, VirtualAccountRecord>();

  /**
   * Register a Virtual Account into the central deterministic registry
   */
  static async registerAccount(record: {
    app: EcosystemApp;
    accountNumber: string;
    virtualAccountId: string;
    bankName?: string;
    bankCode?: string;
    userId?: string;
    userEmail?: string;
    accountName?: string;
    rentillyId?: string;
  }): Promise<boolean> {
    const cleanAcc = (record.accountNumber || '').trim();
    const cleanVaId = (record.virtualAccountId || '').trim();

    if (!cleanAcc && !cleanVaId) return false;

    const fullRecord: VirtualAccountRecord = {
      app: record.app,
      platform: record.app.toUpperCase(),
      accountNumber: cleanAcc,
      virtualAccountId: cleanVaId,
      bankName: record.bankName || 'Wema Bank',
      bankCode: record.bankCode || '035',
      userId: record.userId,
      userEmail: (record.userEmail || '').toLowerCase().trim(),
      accountName: record.accountName,
      rentillyId: record.rentillyId,
      createdAt: new Date().toISOString()
    };

    if (cleanAcc) this.memoryCache.set(cleanAcc, fullRecord);
    if (cleanVaId) this.memoryCache.set(cleanVaId, fullRecord);

    if (supabase) {
      const writes: Promise<any>[] = [];
      if (cleanAcc) {
        writes.push(
          supabase.from('system_configs').upsert({
            id: `va_registry_${cleanAcc}`,
            data: fullRecord,
            updated_at: new Date().toISOString()
          }, { onConflict: 'id' })
        );
      }
      if (cleanVaId) {
        writes.push(
          supabase.from('system_configs').upsert({
            id: `va_registry_id_${cleanVaId}`,
            data: fullRecord,
            updated_at: new Date().toISOString()
          }, { onConflict: 'id' })
        );
      }
      await Promise.allSettled(writes);
    }

    console.log(`[PlatformRegistry] 🏷️ Registered ${fullRecord.app.toUpperCase()} VA: Acc=${cleanAcc}, VA=${cleanVaId}, Email=${fullRecord.userEmail}`);
    return true;
  }

  /**
   * Deterministically resolve which application and user an account belongs to
   * Returns null if not registered anywhere
   */
  static async resolveAccount(identifier: string): Promise<VirtualAccountRecord | null> {
    const clean = (identifier || '').trim();
    if (!clean) return null;

    if (this.memoryCache.has(clean)) {
      return this.memoryCache.get(clean)!;
    }

    // Known static hardcoded ecosystem mappings
    if (clean === '7941121155' || clean === '6aa3a161afaadc31df84a941' || clean === '5003504921') {
      const gigaRec: VirtualAccountRecord = {
        app: 'gigaride',
        platform: 'GIGA_RIDE',
        accountNumber: clean === '6aa3a161afaadc31df84a941' ? '7941121155' : clean,
        virtualAccountId: clean === '7941121155' ? '6aa3a161afaadc31df84a941' : clean,
        bankName: 'Wema Bank',
        bankCode: '035',
        accountName: 'Patrick Achua (Giga Ride)',
        createdAt: new Date().toISOString()
      };
      this.memoryCache.set(clean, gigaRec);
      return gigaRec;
    }

    if (clean === '7943388851' || clean === '6a0976da1b7b5b797990bf38') {
      const rentillyRec: VirtualAccountRecord = {
        app: 'rentilly',
        platform: 'RENTILLY',
        accountNumber: '7943388851',
        virtualAccountId: '6a0976da1b7b5b797990bf38',
        bankName: 'Wema Bank (Rentilly Escrow)',
        bankCode: '035',
        userEmail: 'patrickachua3@gmail.com',
        accountName: 'Patrick Achua',
        rentillyId: 'RT-12116521',
        createdAt: new Date().toISOString()
      };
      this.memoryCache.set(clean, rentillyRec);
      return rentillyRec;
    }

    if (supabase) {
      try {
        const queryId = clean.length === 10 && /^\d+$/.test(clean)
          ? `va_registry_${clean}`
          : `va_registry_id_${clean}`;

        const { data } = await supabase
          .from('system_configs')
          .select('data')
          .eq('id', queryId)
          .maybeSingle();

        if (data?.data && data.data.app) {
          const rec = data.data as VirtualAccountRecord;
          this.memoryCache.set(clean, rec);
          return rec;
        }

        // Fallback: check fincra_va_* configs
        const { data: vaCfgs } = await supabase
          .from('system_configs')
          .select('id, data')
          .like('id', 'fincra_va_%');

        if (vaCfgs) {
          for (const c of vaCfgs) {
            if (
              c.data?.accountNumber === clean ||
              c.data?.virtualAccountId === clean ||
              c.data?._id === clean
            ) {
              const email = c.id.replace('fincra_va_', '').toLowerCase().trim();
              const inferred: VirtualAccountRecord = {
                app: 'rentilly',
                platform: 'RENTILLY',
                accountNumber: c.data.accountNumber || clean,
                virtualAccountId: c.data.virtualAccountId || c.data._id || clean,
                bankName: c.data.bankName || 'Wema Bank',
                bankCode: c.data.bankCode || '035',
                userEmail: email,
                accountName: c.data.accountName,
                createdAt: new Date().toISOString()
              };
              this.memoryCache.set(clean, inferred);
              return inferred;
            }
          }
        }
      } catch (err: any) {
        console.warn('[PlatformRegistry] Supabase lookup warning:', err.message);
      }
    }

    return null;
  }

  /**
   * Backfill all active Rentilly profiles and virtual accounts into the registry
   */
  static async backfillAllRentillyAccounts(): Promise<{ registeredCount: number }> {
    let count = 0;
    if (!supabase) return { registeredCount: 0 };

    try {
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, email, full_name, account_number, bank_name');

      const { data: vaConfigs } = await supabase
        .from('system_configs')
        .select('id, data')
        .like('id', 'fincra_va_%');

      const configMap = new Map<string, any>();
      (vaConfigs || []).forEach(c => {
        const email = c.id.replace('fincra_va_', '').toLowerCase().trim();
        configMap.set(email, c.data);
      });

      for (const p of profiles || []) {
        const email = (p.email || '').toLowerCase().trim();
        const acc = (p.account_number || '').trim();
        const cfg = configMap.get(email);
        const vaId = (cfg?.virtualAccountId || cfg?._id || '').trim();

        if (acc || vaId) {
          let assignedApp: EcosystemApp = 'rentilly';
          if (email.includes('pickpadi') || acc === '1100092831') {
            assignedApp = 'pickpadi';
          } else if (acc === '7941121155' || vaId === '6aa3a161afaadc31df84a941') {
            assignedApp = 'gigaride';
          }

          await this.registerAccount({
            app: assignedApp,
            accountNumber: acc || cfg?.accountNumber || '',
            virtualAccountId: vaId,
            bankName: p.bank_name || cfg?.bankName || 'Wema Bank',
            bankCode: cfg?.bankCode || '035',
            userId: p.id,
            userEmail: email,
            accountName: p.full_name || cfg?.accountName,
          });
          count++;
        }
      }

      // Explicitly register known Giga accounts
      await this.registerAccount({
        app: 'gigaride',
        accountNumber: '7941121155',
        virtualAccountId: '6aa3a161afaadc31df84a941',
        bankName: 'Wema Bank',
        bankCode: '035',
        accountName: 'Patrick Achua (Giga Ride)',
      });

      // Explicitly register Patrick Rentilly Escrow
      await this.registerAccount({
        app: 'rentilly',
        accountNumber: '7943388851',
        virtualAccountId: '6a0976da1b7b5b797990bf38',
        bankName: 'Wema Bank (Rentilly Escrow)',
        bankCode: '035',
        userEmail: 'patrickachua3@gmail.com',
        accountName: 'Patrick Achua',
        rentillyId: 'RT-12116521'
      });

      console.log(`[PlatformRegistry] ✅ Backfill complete: ${count} accounts indexed.`);
    } catch (e: any) {
      console.error('[PlatformRegistry] Backfill error:', e.message);
    }

    return { registeredCount: count };
  }
}
