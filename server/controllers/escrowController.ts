import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Transaction } from '../types';
import { TransactionStore } from '../services/transactionStore';
import { AdminDataStore } from '../services/adminDataStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { UserStore } from '../services/userStore';

export async function getTransactions(_req: Request, res: Response) {
  try {
    // Primary source: live wallet ledger (TransactionStore)
    const walletTxs = TransactionStore.getAllTransactions();
    const escrowFromWallet = AdminDataStore.buildEscrowTransactions(walletTxs);

    // Secondary source: Supabase (if connected and has data)
    let supabaseTxns: Transaction[] = [];
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('transactions')
          .select('*, properties(*)')
          .order('created_at', { ascending: false });

        if (!error && data && data.length > 0) {
          supabaseTxns = data.map((row: any) => ({
            id: row.id,
            propertyId: row.property_id || 'wallet_inbound',
            propertyTitle: row.properties?.title || 'Property Transaction',
            payerId: row.payer_id || row.user_id,
            payerName: row.payer_name || 'Buyer / Renter',
            ownerId: row.recipient_owner_id || row.user_id,
            ownerName: row.recipient_owner_name || 'Property Owner',
            transactionType: row.transaction_type || 'rent',
            paymentReference: row.payment_reference,
            paymentGateway: row.payment_gateway || 'flutterwave',
            baseAmount: Number(row.base_price || row.total_amount || 0),
            rentillyLegalFee: Number(row.rentilly_legal_fee || 0),
            cautionFee: Number(row.caution_deposit || 0),
            serviceCharge: Number(row.service_charge || 0),
            totalAmount: Number(row.total_amount || 0),
            escrowStatus: row.escrow_status || 'held_in_escrow',
            ownerPayoutReference: row.owner_payout_reference,
            payoutReleasedAt: row.payout_released_at,
            createdAt: row.created_at
          }));
        }
      } catch (_) {}
    }

    // Merge: prefer Supabase records for IDs that overlap, then wallet-sourced
    const supabaseIds = new Set(supabaseTxns.map(t => t.id));
    const dedupedWallet = escrowFromWallet.filter(t => !supabaseIds.has(t.id));
    const allTxns = [...supabaseTxns, ...dedupedWallet].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );

    res.json(allTxns);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function releaseEscrowPayout(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const payoutReference = `PAYOUT-RENTILLY-${Date.now()}`;
    const payoutReleasedAt = new Date().toISOString();

    // 1. Always update in local/in-memory TransactionStore
    TransactionStore.updateTransactionStatus(id, 'released_to_owner', payoutReference);

    // 2. Also update Supabase if available
    let txn: any = null;
    if (supabase) {
      try {
        const { data } = await supabase
          .from('transactions')
          .update({
            escrow_status: 'released_to_owner',
            owner_payout_reference: payoutReference,
            payout_released_at: payoutReleasedAt
          })
          .eq('id', id)
          .select()
          .maybeSingle();

        txn = data;

        if (txn && txn.property_id) {
          await supabase
            .from('properties')
            .update({
              status: txn.transaction_type === 'rent' ? 'rented' : 'sold',
              delisted_at: payoutReleasedAt,
              updated_at: payoutReleasedAt
            })
            .eq('id', txn.property_id);
        }
      } catch (_) {}
    }

    // Dispatch payout release alert to landlord
    const targetOwnerEmail = txn?.owner_name || `${id}@myrentilly.com`;
    NotificationDispatcher.dispatch({
      userId: txn?.owner_id || id,
      email: targetOwnerEmail.includes('@') ? targetOwnerEmail : 'owner@myrentilly.com',
      userName: txn?.owner_name || 'Property Owner',
      title: `Move-In Escrow Payout Released 💰`,
      category: 'escrow',
      message: `Your property funds have been released from Rentilly escrow to your settlement bank account. Payout Reference: ${payoutReference}.`,
      metadata: {
        payoutReference,
        transactionId: id,
        amount: txn?.total_amount
      }
    });

    // 3. Automated Accredited Partner Commission Payout Credit
    const propertyId = txn?.property_id;
    const property = propertyId ? AdminDataStore.getProperties().find(p => p.id === propertyId) : null;
    let partnerCommissionAmount = 0;
    let creditedPartner: any = null;

    if (property && (property as any).listedByRole === 'verified_partner') {
      const partnerId = (property as any).partnerId || property.ownerId;
      const allUsers = await UserStore.getAllUsers();
      const partnerUser = (await UserStore.findById(partnerId)) || 
        allUsers.find(u => u.id === partnerId || (property.ownerPhone && u.phoneNumber === property.ownerPhone) || u.email === property.ownerEmail);

      if (partnerUser) {
        const isRent = (txn?.transaction_type === 'rent') || (property.purpose === 'rent');
        const rate = isRent ? 0.025 : 0.020;
        const baseAmount = Number(txn?.base_price || txn?.total_amount || property.basePrice || 0);
        partnerCommissionAmount = Math.round(baseAmount * rate);

        if (partnerCommissionAmount > 0) {
          // A. Credit the partner's wallet balance
          const updatedBal = (partnerUser.walletBalance || 0) + partnerCommissionAmount;
          await UserStore.upsertUser({
            ...partnerUser,
            walletBalance: updatedBal,
            updatedAt: payoutReleasedAt
          });

          // B. Record credit transaction in live ledger
          const commTxId = `TX-COMM-${Date.now()}`;
          TransactionStore.recordTransaction({
            id: commTxId,
            userId: partnerUser.id,
            userEmail: partnerUser.email,
            amount: partnerCommissionAmount,
            type: 'credit',
            status: 'SUCCESSFUL',
            category: 'commission',
            title: `Brokerage Commission: ${property.title}`,
            description: `${isRent ? '2.5%' : '2.0%'} mandate commission for ${property.title}. Released from escrow payout ${payoutReference}.`,
            reference: `COMM-${payoutReference}`,
            date: payoutReleasedAt,
            isCredit: true,
            escrowStatus: 'released_to_owner'
          });

          creditedPartner = {
            id: partnerUser.id,
            name: partnerUser.businessName || partnerUser.fullName,
            email: partnerUser.email,
            commissionAmount: partnerCommissionAmount,
            rate: isRent ? '2.5%' : '2.0%'
          };

          // C. Dispatch instant notification alert to Accredited Partner
          NotificationDispatcher.dispatch({
            userId: partnerUser.id,
            email: partnerUser.email,
            userName: partnerUser.businessName || partnerUser.fullName,
            title: `🎉 Brokerage Commission Unlocked: ₦${partnerCommissionAmount.toLocaleString()}`,
            category: 'escrow',
            message: `Your ${isRent ? '2.5%' : '2.0%'} commission for "${property.title}" has been released and credited to your settlement vault. Current Balance: ₦${updatedBal.toLocaleString()}.`,
            metadata: {
              propertyId: property.id,
              propertyTitle: property.title,
              commissionAmount: partnerCommissionAmount,
              payoutReference
            }
          });
        }
      }
    }

    res.json({ 
      success: true, 
      transaction: txn, 
      payoutReference, 
      payoutReleasedAt,
      partnerCommissionCredited: partnerCommissionAmount > 0,
      creditedPartner
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getPartnerCommissions(req: Request, res: Response) {
  try {
    const { partnerId, email } = req.query;
    const cleanEmail = email ? String(email).toLowerCase().trim() : '';
    const cleanId = partnerId ? String(partnerId).trim() : '';

    // 1. Get properties listed by this partner from AdminDataStore
    const allProperties = AdminDataStore.getProperties();
    const partnerProps = allProperties.filter(p => 
      (cleanId && ((p as any).partnerId === cleanId || (p as any).ownerId === cleanId)) ||
      (cleanEmail && ((p as any).ownerEmail && (p as any).ownerEmail.toLowerCase() === cleanEmail))
    );
    const partnerPropIds = new Set(partnerProps.map(p => p.id));

    // 2. Get direct commission credits in wallet
    const walletTxs = cleanEmail ? await TransactionStore.getTransactionsByEmail(cleanEmail) : [];
    const directCommissions = walletTxs.filter(t => 
      t.isCredit && (t.category === 'commission' || (t.title && t.title.toLowerCase().includes('commission')))
    );

    // 3. Get all platform escrow transactions
    const allEscrowTxs = AdminDataStore.buildEscrowTransactions(TransactionStore.getAllTransactions());
    const propertyTxns = allEscrowTxs.filter(t => partnerPropIds.has(t.propertyId));

    let escrowBalance = 0;
    let settledCommissions = 0;
    const formattedTxns: any[] = [];

    // Include direct credited commissions
    for (const d of directCommissions) {
      settledCommissions += d.amount;
      formattedTxns.push({
        id: d.id,
        propertyTitle: d.title || 'Corporate Brokerage Commission',
        commissionAmount: d.amount,
        commissionRate: '2.5%',
        escrowStatus: 'released_to_owner',
        createdAt: d.date
      });
    }

    // Include property transactions on partner's mandates
    for (const pt of propertyTxns) {
      const isRent = pt.transactionType === 'rent';
      const rate = isRent ? 0.025 : 0.020;
      const commAmount = Math.round(pt.baseAmount * rate);

      if (pt.escrowStatus === 'held_in_escrow') {
        escrowBalance += commAmount;
      } else {
        settledCommissions += commAmount;
      }

      formattedTxns.push({
        id: pt.id,
        propertyTitle: pt.propertyTitle || 'Mandate Listing',
        commissionAmount: commAmount,
        commissionRate: isRent ? '2.5%' : '2.0%',
        escrowStatus: pt.escrowStatus,
        createdAt: pt.createdAt
      });
    }

    return res.json({
      status: true,
      escrowBalance,
      settledCommissions,
      transactions: formattedTxns
    });
  } catch (err: any) {
    return res.json({ status: true, escrowBalance: 0, settledCommissions: 0, transactions: [] });
  }
}

/**
 * Initiates Rent / Sale Escrow Locking from Tenant Wallet Balance or Direct Settlement Rail.
 * Automatically handles:
 * 1. Balance verification
 * 2. Instant ledger debit in TransactionStore + Supabase wallet_transactions
 * 3. Recording escrow transaction in Supabase transactions (with exact 10%/5% legal fee calculation)
 * 4. Creating digital lease / tenancy agreement record in Supabase
 * 5. Firing in-app and push notifications to tenant & landlord
 */
export async function payRentEscrow(req: Request, res: Response) {
  try {
    const {
      propertyId,
      tenantEmail,
      tenantName,
      tenantPhone,
      basePrice,
      cautionFee,
      serviceCharge,
      tenancyDurationMonths,
      notes
    } = req.body;

    const cleanEmail = (tenantEmail || '').toString().toLowerCase().trim();
    if (!cleanEmail) {
      return res.status(400).json({ error: 'Tenant email is required to initiate escrow.' });
    }

    const numBase = Number(basePrice || 0);
    if (numBase <= 0) {
      return res.status(400).json({ error: 'Valid property price is required.' });
    }

    // 1. Fetch Property Details (from Supabase or AdminDataStore)
    let property: any = null;
    if (supabase) {
      const { data } = await supabase.from('properties').select('*').eq('id', propertyId).maybeSingle();
      if (data) property = data;
    }
    if (!property) {
      const storeProps = AdminDataStore.getProperties();
      property = storeProps.find(p => p.id === propertyId);
    }

    const propTitle = property?.title || 'Rentilly Verified Property';
    const propAddress = property ? `${property.address}, ${property.neighborhood}, ${property.state}` : 'Lagos, Nigeria';
    const isRent = (property?.purpose || 'rent') === 'rent';
    const ownerId = property?.owner_id || property?.ownerId || 'owner_direct';
    const ownerName = property?.owner_name || property?.ownerName || 'Direct Landlord';

    // Calculate official transparent legal fee (10% on rent, 5% on sale)
    const legalFeeRate = isRent ? 0.10 : 0.05;
    const rentillyLegalFee = Math.round(numBase * legalFeeRate);
    const numCaution = Number(cautionFee || property?.caution_fee || 0);
    const numServiceCharge = Number(serviceCharge || property?.service_charge || 0);
    const totalPayable = numBase + numCaution + numServiceCharge + rentillyLegalFee;

    // 2. Check user's available wallet balance
    const currentBal = TransactionStore.computeNetBalance(cleanEmail);
    if (currentBal < totalPayable) {
      return res.status(400).json({
        error: `Insufficient wallet balance. Total required for escrow is ₦${totalPayable.toLocaleString()} (Rent: ₦${numBase.toLocaleString()}, Caution: ₦${numCaution.toLocaleString()}, Service: ₦${numServiceCharge.toLocaleString()}, Legal: ₦${rentillyLegalFee.toLocaleString()}). Your available balance is ₦${currentBal.toLocaleString()}. Please top up your wallet.`,
        requiredAmount: totalPayable,
        currentBalance: currentBal,
        shortfall: totalPayable - currentBal
      });
    }

    const escrowRef = `ESCROW_${isRent ? 'RENT' : 'SALE'}_${Date.now()}`;
    const now = new Date().toISOString();

    // 3. Debit Tenant Wallet in TransactionStore
    TransactionStore.recordTransaction({
      id: escrowRef,
      user_email: cleanEmail,
      type: 'debit',
      amount: totalPayable,
      title: `Escrow Lock: ${propTitle}`,
      description: `Rent payment locked in Rentilly Escrow pending key handover. Caution: ₦${numCaution.toLocaleString()} | Legal Fee: ₦${rentillyLegalFee.toLocaleString()}`,
      status: 'SUCCESS',
      date: now,
      reference: escrowRef
    });

    // 4. Save in Supabase `transactions` table
    let savedTxId = escrowRef;
    if (supabase) {
      try {
        const { data: txRow } = await supabase.from('transactions').insert({
          property_id: propertyId,
          payer_id: cleanEmail,
          owner_id: ownerId,
          transaction_type: isRent ? 'rent' : 'sale',
          payment_reference: escrowRef,
          payment_gateway: 'wallet_escrow',
          base_amount: numBase,
          rentilly_legal_fee: rentillyLegalFee,
          caution_fee: numCaution,
          service_charge: numServiceCharge,
          total_amount: totalPayable,
          escrow_status: 'held_in_escrow',
          created_at: now
        }).select().maybeSingle();

        if (txRow) savedTxId = txRow.id;

        // Also record debit in wallet_transactions for user statement export
        await supabase.from('wallet_transactions').insert({
          user_email: cleanEmail,
          amount: totalPayable,
          type: 'DEBIT',
          category: 'escrow',
          title: `Escrow Locked: ${propTitle}`,
          reference: escrowRef,
          flw_ref: escrowRef,
          created_at: now
        });

        // 5. Create active digital tenancy agreement in legal_agreements
        await supabase.from('legal_agreements').insert({
          property_id: propertyId,
          tenant_email: cleanEmail,
          tenant_name: tenantName || 'Tenant',
          landlord_name: ownerName,
          property_title: propTitle,
          property_address: propAddress,
          annual_rent: numBase,
          caution_deposit: numCaution,
          tenancy_duration: `${tenancyDurationMonths || 12} Months`,
          status: 'fully_executed',
          escrow_reference: escrowRef,
          commencement_date: now.split('T')[0],
          created_at: now
        }).catch(() => {});

        // 6. Notify tenant in-app
        await supabase.from('notifications').insert({
          user_email: cleanEmail,
          type: 'escrow_locked',
          title: '🔐 Rent Safely Locked in Escrow',
          message: `Your payment of ₦${totalPayable.toLocaleString()} for "${propTitle}" is now secured in Rentilly Escrow. Funds will only be released to the landlord after physical key handover.`,
          read: false,
          created_at: now
        });
      } catch (sbErr: any) {
        console.warn('[payRentEscrow] Supabase save warning:', sbErr.message);
      }
    }

    // 7. Dispatch Push / Real-time Alert
    NotificationDispatcher.dispatch({
      userId: cleanEmail,
      email: cleanEmail,
      userName: tenantName || 'Tenant',
      title: '🔐 Rent Locked in Escrow',
      category: 'escrow',
      message: `₦${totalPayable.toLocaleString()} locked for ${propTitle}. Physical handover pending.`,
      metadata: {
        escrowReference: escrowRef,
        propertyTitle: propTitle,
        totalAmount: totalPayable
      }
    });

    return res.json({
      success: true,
      message: 'Rent payment locked in escrow successfully. Your tenancy agreement is now active.',
      escrowReference: escrowRef,
      transactionId: savedTxId,
      totalAmount: totalPayable,
      rentillyLegalFee: rentillyLegalFee,
      cautionDeposit: numCaution,
      status: 'held_in_escrow'
    });
  } catch (err: any) {
    console.error('[payRentEscrow] Error:', err.message);
    return res.status(500).json({ error: err.message || 'Escrow payment failed' });
  }
}

export async function getLandlordEscrowSummary(req: Request, res: Response) {
  try {
    const email = String(req.query.email || '').toLowerCase().trim();
    const ownerId = String(req.query.ownerId || '').trim();

    let activeEscrowBalance = 0;
    let cautionDepositsHeld = 0;
    let activeLeasesCount = 0;

    // 1. Check Supabase
    if (supabase) {
      try {
        // Query legal agreements
        let agreementsQuery = supabase
          .from('legal_agreements')
          .select('*')
          .eq('status', 'fully_executed');

        if (email) {
          agreementsQuery = agreementsQuery.or(`landlord_email.eq.${email},owner_email.eq.${email}`);
        }

        const { data: agreements } = await agreementsQuery;
        if (agreements && agreements.length > 0) {
          activeLeasesCount = agreements.length;
          for (const a of agreements) {
            cautionDepositsHeld += Number(a.caution_deposit || 0);
            if (a.escrow_status === 'held_in_escrow' || !a.payout_released_at) {
              activeEscrowBalance += Number(a.annual_rent || 0);
            }
          }
        }

        // Also query pending escrow transactions
        let txQuery = supabase
          .from('transactions')
          .select('*')
          .in('escrow_status', ['held_in_escrow', 'pending_handover', 'held']);

        if (ownerId) {
          txQuery = txQuery.or(`recipient_owner_id.eq.${ownerId},owner_id.eq.${ownerId}`);
        }

        const { data: txs } = await txQuery;
        if (txs && txs.length > 0) {
          for (const t of txs) {
            const amt = Number(t.base_price || t.total_amount || 0);
            if (!activeEscrowBalance || activeEscrowBalance < amt) {
              activeEscrowBalance += amt;
            }
          }
        }
      } catch (sbErr: any) {
        console.warn('[getLandlordEscrowSummary] Supabase query notice:', sbErr.message);
      }
    }

    return res.json({
      success: true,
      activeEscrowBalance,
      cautionDepositsHeld,
      totalEscrowVolume: activeEscrowBalance + cautionDepositsHeld,
      activeLeasesCount
    });
  } catch (err: any) {
    console.error('[getLandlordEscrowSummary] Error:', err.message);
    return res.status(500).json({ error: err.message });
  }
}

export async function submitEscrowClaim(req: Request, res: Response) {
  try {
    const { email, ownerName, tenantName, propertyAddress, damageCategory, estimatedCost, description } = req.body;
    const cleanEmail = String(email || '').toLowerCase().trim();
    const claimRef = `CLM-${Date.now().toString().slice(-6)}`;
    const now = new Date().toISOString();

    if (supabase) {
      try {
        // Create a support conversation / dispute ticket
        await supabase.from('support_conversations').insert({
          user_email: cleanEmail,
          user_name: ownerName || 'Landlord',
          user_role: 'owner',
          subject: `Escrow Damage Claim: ${claimRef} (${damageCategory})`,
          status: 'open',
          priority: 'high',
          last_message: `Damage claim of ₦${Number(estimatedCost || 0).toLocaleString()} filed for ${propertyAddress}: ${description}`,
          last_message_at: now,
          unread_by_agent: 1,
          created_at: now
        });

        // Insert notification
        await supabase.from('notifications').insert({
          user_email: cleanEmail,
          type: 'escrow_claim',
          title: `🛡️ Claim ${claimRef} Registered`,
          message: `Your damage claim of ₦${Number(estimatedCost || 0).toLocaleString()} for ${propertyAddress} has been submitted to Rentilly Legal Desk.`,
          read: false,
          created_at: now
        });
      } catch (err: any) {
        console.warn('[submitEscrowClaim] Supabase notice:', err.message);
      }
    }

    return res.status(201).json({
      success: true,
      claimReference: claimRef,
      message: `Damage claim ${claimRef} submitted successfully! Rentilly Legal Desk is arbitrating.`
    });
  } catch (err: any) {
    console.error('[submitEscrowClaim] Error:', err.message);
    return res.status(500).json({ error: err.message });
  }
}
