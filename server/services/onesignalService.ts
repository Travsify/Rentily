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
  /** Target: 'all', specific player IDs, external user IDs, or segment filters */
  targetPlayerIds?: string[];
  targetExternalIds?: string[];
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
      // Android notification icon
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
    if (payload.targetExternalIds && payload.targetExternalIds.length > 0) {
      body.include_aliases = { external_id: payload.targetExternalIds };
      body.target_channel = 'push';
    } else if (payload.targetPlayerIds && payload.targetPlayerIds.length > 0) {
      body.include_subscription_ids = payload.targetPlayerIds;
    } else if (payload.filters && payload.filters.length > 0) {
      body.filters = payload.filters;
    } else if (payload.targetSegments && payload.targetSegments.length > 0) {
      body.included_segments = payload.targetSegments;
    } else {
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

    if (response.ok && (result.id || result.recipients > 0)) {
      console.log(`[OneSignal] Push sent successfully. ID: ${result.id}, Recipients: ${result.recipients || 0}`);
      return { success: true, id: result.id };
    } else {
      console.log('[OneSignal] Push response:', result);
      return { success: Boolean(result.id), error: JSON.stringify(result.errors || result) };
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

/** Send push to a specific user by their external User ID */
export function pushToExternalUser(userId: string, title: string, message: string, data?: Record<string, string>) {
  return sendPushNotification({ title, message, data, targetExternalIds: [userId] });
}

/** Send push to a specific user by their OneSignal player ID */
export function pushToPlayer(playerId: string, title: string, message: string, data?: Record<string, string>) {
  return sendPushNotification({ title, message, data, targetPlayerIds: [playerId] });
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
    filters: [{ field: 'tag', key: 'email', relation: '=', value: email.toLowerCase().trim() }],
  });
}
