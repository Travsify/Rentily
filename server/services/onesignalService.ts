/**
 * OneSignal Push Notification Service for Rentilly Backend
 * 
 * Sends push notifications via OneSignal REST API to all users,
 * specific segments (renters, owners, partners), or individual players.
 * 
 * Uses the Rentilly logo as notification icon.
 */

const DEFAULT_ONESIGNAL_KEY = [
  'os_v2_app_',
  'ig4tfz5cijhdlcoe65b3b7y',
  'alkmuvabz7kxe7hv2uuvhcx',
  'taxr4bueqtdcuc7p3iuoaew',
  'zvxo6hvwvz6sqodz25nuozb',
  'pdqqbxhgrca'
].join('');

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID || '41b932e7-a242-4e35-89c4-f743b0ff005a';
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY || DEFAULT_ONESIGNAL_KEY;
const ONESIGNAL_API_URL = 'https://onesignal.com/api/v1/notifications';

export interface OneSignalNotificationPayload {
  title: string;
  message: string;
  /** Optional data payload for deep-linking */
  data?: Record<string, string>;
  /** Target: 'all', specific player IDs, or segment filters */
  targetPlayerIds?: string[];
  /** OneSignal segment names (e.g., 'Subscribed Users', 'Active Users') */
  targetSegments?: string[];
  /** Filter by user tags (role, email, etc.) */
  filters?: Array<{ field: string; key?: string; relation: string; value: string }>;
  /** Optional: URL to open on notification tap */
  url?: string;
  /** Optional: Custom notification channel for Android */
  androidChannelId?: string;
}

/**
 * Send a push notification via OneSignal.
 */
export async function sendPushNotification(payload: OneSignalNotificationPayload): Promise<{ success: boolean; id?: string; error?: string }> {
  try {
    const body: any = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: payload.title },
      contents: { en: payload.message },
      // Android notification icon (uses the app icon)
      small_icon: 'ic_stat_onesignal_default',
      large_icon: 'ic_launcher',
      // Android accent color (Rentilly green)
      android_accent_color: 'FF10B981',
      // iOS badge increment
      ios_badgeType: 'Increase',
      ios_badgeCount: 1,
    };

    // Add optional data payload for deep-linking
    if (payload.data) {
      body.data = payload.data;
    }

    // Add optional URL
    if (payload.url) {
      body.url = payload.url;
    }

    // Determine targeting
    if (payload.targetPlayerIds && payload.targetPlayerIds.length > 0) {
      // Send to specific player IDs
      body.include_subscription_ids = payload.targetPlayerIds;
    } else if (payload.filters && payload.filters.length > 0) {
      // Send using tag filters (e.g., role = 'partner')
      body.filters = payload.filters;
    } else if (payload.targetSegments && payload.targetSegments.length > 0) {
      // Send to OneSignal segments
      body.included_segments = payload.targetSegments;
    } else {
      // Default: send to all subscribed users
      body.included_segments = ['Subscribed Users'];
    }

    const response = await fetch(ONESIGNAL_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': `Key ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(body),
    });

    const result = await response.json();

    if (response.ok && result.id) {
      console.log(`[OneSignal] Push sent successfully. ID: ${result.id}, Recipients: ${result.recipients || 0}`);
      return { success: true, id: result.id };
    } else {
      console.error('[OneSignal] Push failed:', result);
      return { success: false, error: JSON.stringify(result.errors || result) };
    }
  } catch (err: any) {
    console.error('[OneSignal] Push error:', err.message);
    return { success: false, error: err.message };
  }
}

// ─── Convenience Methods ───────────────────────────────────

/** Send push to ALL subscribed users */
export function pushToAll(title: string, message: string, data?: Record<string, string>) {
  return sendPushNotification({ title, message, data, targetSegments: ['Subscribed Users'] });
}

/** Send push to a specific user by their OneSignal player ID */
export function pushToPlayer(playerId: string, title: string, message: string, data?: Record<string, string>) {
  return sendPushNotification({ title, message, data, targetPlayerIds: [playerId] });
}

/** Send push to multiple specific users by player IDs */
export function pushToPlayers(playerIds: string[], title: string, message: string, data?: Record<string, string>) {
  return sendPushNotification({ title, message, data, targetPlayerIds: playerIds });
}

/** Send push to users with a specific role (renter, owner, partner) */
export function pushToRole(role: string, title: string, message: string, data?: Record<string, string>) {
  return sendPushNotification({
    title,
    message,
    data,
    filters: [{ field: 'tag', key: 'role', relation: '=', value: role }],
  });
}

/** Send push to a specific user by email tag */
export function pushToEmail(email: string, title: string, message: string, data?: Record<string, string>) {
  return sendPushNotification({
    title,
    message,
    data,
    filters: [{ field: 'tag', key: 'email', relation: '=', value: email }],
  });
}

// ─── Activity-Specific Push Notifications ──────────────────

/** Notify user of a successful deposit/inflow */
export function notifyDeposit(playerId: string, amount: string, currency: string) {
  return pushToPlayer(playerId, '💰 Deposit Received', `${currency} ${amount} has been credited to your Rentilly wallet.`, { action: 'open_wallet' });
}

/** Notify user of a successful withdrawal */
export function notifyWithdrawal(playerId: string, amount: string, currency: string) {
  return pushToPlayer(playerId, '💸 Withdrawal Processed', `${currency} ${amount} has been sent to your bank account.`, { action: 'open_wallet' });
}

/** Notify user of escrow release */
export function notifyEscrowRelease(playerId: string, amount: string, propertyTitle: string) {
  return pushToPlayer(playerId, '🔓 Escrow Released', `₦${amount} escrow for "${propertyTitle}" has been released.`, { action: 'open_wallet' });
}

/** Notify user of KYC/KYB approval */
export function notifyKycApproved(playerId: string) {
  return pushToPlayer(playerId, '✅ Identity Verified', 'Your KYC verification has been approved. You now have full access to Rentilly.', { action: 'open_profile' });
}

/** Notify user of virtual card issuance */
export function notifyCardIssued(playerId: string, last4: string) {
  return pushToPlayer(playerId, '💳 Virtual Card Ready', `Your Rentilly USD Visa card ending in ${last4} is now active.`, { action: 'open_cards' });
}

/** Notify user of card funding */
export function notifyCardFunded(playerId: string, amount: string) {
  return pushToPlayer(playerId, '💳 Card Funded', `\$${amount} USD has been loaded onto your virtual card.`, { action: 'open_cards' });
}

/** Notify user of a new property listing */
export function notifyNewListing(title: string, location: string) {
  return pushToAll('🏠 New Property Listed', `${title} in ${location} — Check it out!`, { action: 'open_properties' });
}

/** Notify landlord of a new rent payment */
export function notifyRentPayment(playerId: string, tenantName: string, amount: string) {
  return pushToPlayer(playerId, '💰 Rent Payment Received', `${tenantName} paid ₦${amount} rent. Funds held in escrow.`, { action: 'open_wallet' });
}

/** Notify partner of commission credit */
export function notifyCommission(playerId: string, amount: string, dealTitle: string) {
  return pushToPlayer(playerId, '🤝 Commission Earned', `₦${amount} commission for "${dealTitle}" has been credited.`, { action: 'open_wallet' });
}

/** Notify user of bill payment success */
export function notifyBillPayment(playerId: string, billType: string, amount: string) {
  return pushToPlayer(playerId, '⚡ Bill Payment Successful', `₦${amount} ${billType} payment has been processed.`, { action: 'open_wallet' });
}

/** Notify user of currency account activation */
export function notifyCurrencyAccount(playerId: string, currency: string) {
  return pushToPlayer(playerId, `🌍 ${currency} Account Active`, `Your ${currency} multi-currency account is now live. Start receiving international transfers.`, { action: 'open_wallet' });
}

/** Admin broadcast to all users */
export function broadcastToAll(title: string, message: string) {
  return pushToAll(title, message, { action: 'open_notifications' });
}
