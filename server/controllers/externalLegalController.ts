import type { Request, Response } from 'express';
import crypto from 'crypto';
import { supabase } from '../supabaseClient';
import { UserStore } from '../services/userStore';
import { TransactionStore } from '../services/transactionStore';
import { AdminDataStore } from '../services/adminDataStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';

export interface ExternalLegalOrder {
  id: string;
  userId: string;
  userEmail: string;
  userName: string;
  userPhone?: string;
  serviceType: 'single_doc_50k' | 'multi_doc_100k' | 'doc_preparation_3pct';
  serviceTitle: string;
  propertyTitle: string;
  propertyAddress: string;
  propertyState: string;
  propertyLga?: string;
  propertyValue?: number;
  feeAmount: number;
  documentType?: string; // e.g. 'Survey Plan', 'Deed of Assignment', 'C of O', 'Purchase Receipt'
  documentUrls: string[];
  additionalNotes?: string;
  status: 'pending_review' | 'in_progress' | 'completed' | 'rejected';
  assignedCounselName?: string;
  assignedCounselNba?: string;
  reportSummary?: string;
  reportPdfUrl?: string;
  certificateHash?: string;
  rejectionReason?: string;
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
}

// In-Memory fallback store
let _inMemoryOrders: ExternalLegalOrder[] = [];

// Per-user async mutex to prevent double-spend & race conditions on concurrent requests
const _userLocks = new Map<string, Promise<void>>();

async function withUserLock<T>(userKey: string, task: () => Promise<T>): Promise<T> {
  const cleanKey = (userKey || '').toLowerCase().trim();
  const currentLock = _userLocks.get(cleanKey) || Promise.resolve();
  let releaseLock: () => void;
  const nextLock = new Promise<void>((resolve) => {
    releaseLock = resolve;
  });
  _userLocks.set(cleanKey, nextLock);

  try {
    await currentLock;
    return await task();
  } finally {
    releaseLock!();
    if (_userLocks.get(cleanKey) === nextLock) {
      _userLocks.delete(cleanKey);
    }
  }
}

// Helper: load initial orders from disk or Supabase
export function initExternalLegalOrders() {
  try {
    const saved = AdminDataStore.getExternalLegalOrders();
    if (saved && saved.length > 0) {
      _inMemoryOrders = saved;
    }
  } catch (_) {}
}

/**
 * 1. Create External Legal Order (Debits User Wallet Balance with Mutex Lock)
 */
export async function createExternalLegalOrder(req: Request, res: Response) {
  try {
    const {
      userId,
      email,
      fullName,
      phoneNumber,
      serviceType,
      propertyTitle,
      propertyAddress,
      propertyState,
      propertyLga,
      propertyValue,
      documentType,
      documentUrls,
      additionalNotes,
    } = req.body;

    if (!email || !serviceType || !propertyTitle || !propertyAddress) {
      return res.status(400).json({
        status: false,
        error: 'Missing required fields: email, serviceType, propertyTitle, and propertyAddress are mandatory.',
      });
    }

    // 1. Calculate Required Fee
    let feeAmount = 0;
    let serviceTitle = '';

    if (serviceType === 'single_doc_50k') {
      feeAmount = 50000;
      serviceTitle = 'Single External Document Verification (₦50,000)';
    } else if (serviceType === 'multi_doc_100k') {
      feeAmount = 100000;
      serviceTitle = 'Comprehensive Title & Land Registry Search (₦100,000)';
    } else if (serviceType === 'doc_preparation_3pct') {
      const propVal = Number(propertyValue) || 0;
      if (propVal <= 0) {
        return res.status(400).json({
          status: false,
          error: 'Please provide a valid property valuation to calculate the 3% legal drafting fee.',
        });
      }
      // Strictly 3% of entered property worth (not pegged/floored at ₦150k)
      feeAmount = Math.round(propVal * 0.03);
      serviceTitle = `Real Estate Legal Document Preparation (3% of ₦${propVal.toLocaleString()})`;
    } else {
      return res.status(400).json({
        status: false,
        error: `Invalid serviceType '${serviceType}'. Allowed: 'single_doc_50k', 'multi_doc_100k', 'doc_preparation_3pct'.`,
      });
    }

    // Wrap wallet lookup, balance verification, and atomic debit in per-user Mutex Lock
    const result = await withUserLock(email, async () => {
      // 2. Lookup user and verify wallet balance
      const user = (await UserStore.findByEmail(email)) || (userId ? await UserStore.findById(userId) : null);
      if (!user) {
        return {
          statusCode: 404,
          payload: {
            status: false,
            error: 'User not found. Please ensure you are logged into your Rentilly account.',
          },
        };
      }

      const currentBal = Number(user.walletBalance) || 0;
      if (currentBal < feeAmount) {
        const shortfall = feeAmount - currentBal;
        return {
          statusCode: 400,
          payload: {
            status: false,
            insufficientBalance: true,
            currentBalance: currentBal,
            requiredFee: feeAmount,
            shortfall,
            accountNumber: user.accountNumber || '0123456789',
            bankName: user.bankName || 'Wema Bank / Rentilly MFB',
            error: `Insufficient wallet balance. You need ₦${feeAmount.toLocaleString()} but have ₦${currentBal.toLocaleString()}. Please fund ₦${shortfall.toLocaleString()} to your Rentilly Virtual Account.`,
          },
        };
      }

      // 3. Atomically debit user wallet balance
      const newBal = currentBal - feeAmount;
      UserStore.upsertUserForced({ ...user, walletBalance: newBal });

      // 4. Record ledger transaction with complete normalized metadata
      const txId = `tx_leg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const txRef = `RNT-LEG-${Date.now()}`;
      TransactionStore.recordTransaction({
        id: txId,
        userId: user.id || userId,
        email: user.email.toLowerCase().trim(),
        userEmail: user.email.toLowerCase().trim(),
        title: `Legal Desk: ${serviceTitle}`,
        type: 'debit',
        category: 'external_legal_service',
        amount: feeAmount,
        currency: 'NGN',
        isCredit: false,
        reference: txRef,
        status: 'SUCCESSFUL',
        description: `Payment for ${serviceTitle} - ${propertyTitle}`,
        metadata: {
          serviceType,
          propertyTitle,
          propertyAddress,
          propertyState: propertyState || 'Lagos',
        },
        createdAt: new Date().toISOString(),
        date: new Date().toISOString(),
      });

      // 5. Build and save order
      const orderId = `leg_ord_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
      const order: ExternalLegalOrder = {
        id: orderId,
        userId: user.id || userId || user.email,
        userEmail: user.email,
        userName: fullName || user.fullName || 'Valued Client',
        userPhone: phoneNumber || user.phoneNumber || '',
        serviceType,
        serviceTitle,
        propertyTitle,
        propertyAddress,
        propertyState: propertyState || 'Lagos',
        propertyLga: propertyLga || '',
        propertyValue: Number(propertyValue) || undefined,
        feeAmount,
        documentType: documentType || 'Deed / Title Instrument',
        documentUrls: Array.isArray(documentUrls) ? documentUrls : [],
        additionalNotes: additionalNotes || '',
        status: 'pending_review',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      _inMemoryOrders.unshift(order);
      AdminDataStore.saveExternalLegalOrders(_inMemoryOrders);

      // 6. Supabase Persistence
      if (supabase) {
        try {
          await supabase.from('external_legal_orders').insert([{
            id: order.id,
            user_id: order.userId,
            user_email: order.userEmail,
            user_name: order.userName,
            user_phone: order.userPhone,
            service_type: order.serviceType,
            service_title: order.serviceTitle,
            property_title: order.propertyTitle,
            property_address: order.propertyAddress,
            property_state: order.propertyState,
            property_lga: order.propertyLga,
            property_value: order.propertyValue,
            fee_amount: order.feeAmount,
            document_type: order.documentType,
            document_urls: order.documentUrls,
            additional_notes: order.additionalNotes,
            status: order.status,
            created_at: order.createdAt,
            updated_at: order.updatedAt,
          }]);
        } catch (_) {}
      }

      NotificationDispatcher.dispatch({
        email: user.email,
        title: '⚖️ Legal Service Request Received!',
        message: `Your request for ${serviceTitle} for '${propertyTitle}' has been received and assigned to Rentilly Legal Desk. Fee of ₦${feeAmount.toLocaleString()} debited from wallet.`,
        category: 'legal' as any,
      });

      return {
        statusCode: 200,
        payload: {
          status: true,
          success: true,
          message: 'Legal service request successfully submitted and debited from wallet.',
          order,
          newWalletBalance: newBal,
        },
      };
    });

    return res.status(result.statusCode).json(result.payload);
  } catch (error: any) {
    console.error('[ExternalLegalController] Error creating order:', error);
    return res.status(500).json({
      status: false,
      error: error?.message || 'Internal server error processing legal request.',
    });
  }
}

/**
 * 2. Get User's External Legal Orders
 */
export async function getUserOrders(req: Request, res: Response) {
  try {
    const email = (req.query.email || '').toString().trim().toLowerCase();
    const userId = (req.query.userId || '').toString().trim();

    if (!email && !userId) {
      return res.status(400).json({ status: false, error: 'email or userId is required.' });
    }

    let orders = _inMemoryOrders.filter((o) => 
      (email && o.userEmail.toLowerCase() === email) ||
      (userId && o.userId === userId)
    );

    // Fallback query to Supabase
    if (orders.length === 0 && supabase) {
      try {
        const { data, error } = await supabase
          .from('external_legal_orders')
          .select('*')
          .or(`user_email.eq.${email},user_id.eq.${userId}`)
          .order('created_at', { ascending: false });

        if (!error && data) {
          orders = data.map((d: any) => ({
            id: d.id,
            userId: d.user_id,
            userEmail: d.user_email,
            userName: d.user_name,
            userPhone: d.user_phone,
            serviceType: d.service_type,
            serviceTitle: d.service_title,
            propertyTitle: d.property_title,
            propertyAddress: d.property_address,
            propertyState: d.property_state,
            propertyLga: d.property_lga,
            propertyValue: d.property_value,
            feeAmount: d.fee_amount,
            documentType: d.document_type,
            documentUrls: d.document_urls || [],
            additionalNotes: d.additional_notes,
            status: d.status,
            assignedCounselName: d.assigned_counsel_name,
            assignedCounselNba: d.assigned_counsel_nba,
            reportSummary: d.report_summary,
            reportPdfUrl: d.report_pdf_url,
            certificateHash: d.certificate_hash,
            rejectionReason: d.rejection_reason,
            createdAt: d.created_at,
            updatedAt: d.updated_at,
            completedAt: d.completed_at,
          }));
        }
      } catch (_) {}
    }

    return res.json({
      status: true,
      data: orders,
      orders: orders,
      count: orders.length,
    });
  } catch (error: any) {
    console.error('[ExternalLegalController] Error fetching user orders:', error);
    return res.status(500).json({ status: false, error: 'Failed to fetch legal orders.' });
  }
}

/**
 * 3. Admin & Legal Team: Get All External Legal Orders
 */
export async function getAdminLegalOrders(req: Request, res: Response) {
  try {
    const statusFilter = (req.query.status || 'all').toString().trim().toLowerCase();
    const searchQuery = (req.query.q || '').toString().trim().toLowerCase();

    let list = [..._inMemoryOrders];

    if (statusFilter !== 'all') {
      list = list.filter((o) => o.status.toLowerCase() === statusFilter);
    }

    if (searchQuery) {
      list = list.filter((o) =>
        o.propertyTitle.toLowerCase().includes(searchQuery) ||
        o.propertyAddress.toLowerCase().includes(searchQuery) ||
        o.userName.toLowerCase().includes(searchQuery) ||
        o.userEmail.toLowerCase().includes(searchQuery) ||
        o.id.toLowerCase().includes(searchQuery)
      );
    }

    const totalRevenue = _inMemoryOrders.reduce((sum, o) => sum + (Number(o.feeAmount) || 0), 0);
    const pendingCount = _inMemoryOrders.filter((o) => o.status === 'pending_review').length;
    const inProgressCount = _inMemoryOrders.filter((o) => o.status === 'in_progress').length;
    const completedCount = _inMemoryOrders.filter((o) => o.status === 'completed').length;

    return res.json({
      status: true,
      data: list,
      stats: {
        totalOrders: _inMemoryOrders.length,
        totalRevenue,
        pendingCount,
        inProgressCount,
        completedCount,
      },
    });
  } catch (error: any) {
    console.error('[ExternalLegalController] Error fetching admin orders:', error);
    return res.status(500).json({ status: false, error: 'Failed to fetch admin legal orders.' });
  }
}

/**
 * 4. Admin & Legal Team: Update Order Status / Assign Counsel / Deliver Certificate
 */
export async function updateOrderStatus(req: Request, res: Response) {
  try {
    const orderId = req.params.id;
    const {
      status,
      assignedCounselName,
      assignedCounselNba,
      reportSummary,
      reportPdfUrl,
      rejectionReason,
    } = req.body;

    const allowedStatuses = ['pending_review', 'in_progress', 'completed', 'rejected'];
    if (status && !allowedStatuses.includes(status)) {
      return res.status(400).json({
        status: false,
        error: `Invalid status '${status}'. Must be one of: ${allowedStatuses.join(', ')}`,
      });
    }

    const orderIndex = _inMemoryOrders.findIndex((o) => o.id === orderId);
    if (orderIndex === -1) {
      return res.status(404).json({ status: false, error: 'Legal order not found.' });
    }

    const order = _inMemoryOrders[orderIndex];

    if (status) order.status = status;
    if (assignedCounselName) order.assignedCounselName = assignedCounselName;
    if (assignedCounselNba) order.assignedCounselNba = assignedCounselNba;
    if (reportSummary) order.reportSummary = reportSummary;
    if (reportPdfUrl) order.reportPdfUrl = reportPdfUrl;
    if (rejectionReason) order.rejectionReason = rejectionReason;
    order.updatedAt = new Date().toISOString();

    if (status === 'completed') {
      if (!order.completedAt) {
        order.completedAt = new Date().toISOString();
      }
      if (!order.certificateHash) {
        order.certificateHash = crypto.createHash('sha256').update(`${order.id}-${Date.now()}-rentilly-legal`).digest('hex');
      }

      // Notify user of completion
      NotificationDispatcher.dispatch({
        email: order.userEmail,
        title: '✅ Legal Due Diligence / Document Ready!',
        message: `Your legal order for '${order.propertyTitle}' has been completed by ${order.assignedCounselName || 'Rentilly Legal Desk'}. Certified report is available for download in your portal.`,
        category: 'legal' as any,
      });
    }

    _inMemoryOrders[orderIndex] = order;
    AdminDataStore.saveExternalLegalOrders(_inMemoryOrders);

    if (supabase) {
      try {
        await supabase
          .from('external_legal_orders')
          .update({
            status: order.status,
            assigned_counsel_name: order.assignedCounselName,
            assigned_counsel_nba: order.assignedCounselNba,
            report_summary: order.reportSummary,
            report_pdf_url: order.reportPdfUrl,
            certificate_hash: order.certificateHash,
            rejection_reason: order.rejectionReason,
            updated_at: order.updatedAt,
            completed_at: order.completedAt,
          })
          .eq('id', order.id);
      } catch (_) {}
    }

    return res.json({
      status: true,
      success: true,
      message: 'Legal order updated successfully.',
      order,
    });
  } catch (error: any) {
    console.error('[ExternalLegalController] Error updating order status:', error);
    return res.status(500).json({ status: false, error: 'Failed to update order status.' });
  }
}
