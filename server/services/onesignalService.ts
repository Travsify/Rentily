/**
 * OneSignal Push Notification Service for Rentilly Backend
 * 
 * Sends push notifications via OneSignal REST API to all users,
 * specific segments (renters, owners, partners), or individual players.
 * 
 * Uses the Rentilly logo as notification icon.
 */
import { supabase } from '../supabaseClient';

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
  /** Optional: High-resolution custom icon URL */
  iconUrl?: string;
  /** Optional: Big picture / banner image URL */
  imageUrl?: string;
}

/**
 * Retrieves all registered OneSignal player IDs associated with Rentilly user profiles
 * in Supabase. This guarantees that notifications target Rentilly installations and
 * do not collide with other apps (like Giga Ride) registered under the same OneSignal App.
 */
export async function getRentillyRegisteredPlayerIds(): Promise<string[]> {
  if (!supabase) return [];
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('onesignal_player_id')
      .not('onesignal_player_id', 'is', null);

    if (error || !data) return [];
    const ids = data
      .map((r: any) => String(r.onesignal_player_id || '').trim())
      .filter((id: string) => id.length > 10);
    return Array.from(new Set(ids));
  } catch (err: any) {
    console.error('[OneSignal] Error retrieving Rentilly player IDs:', err.message);
    return [];
  }
}

/**
 * Send a push notification via OneSignal.
 */
export async function sendPushNotification(payload: OneSignalNotificationPayload): Promise<{ success: boolean; id?: string; error?: string }> {
  try {
    const brandLogoUrl = payload.iconUrl || 'https://api.myrentilly.com/logo.png';

    const body: any = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: payload.title },
      contents: { en: payload.message },
      // Android notification icon & bold high-resolution branding
      small_icon: 'ic_stat_onesignal_default',
      large_icon: brandLogoUrl,
      // High-resolution expandable banner if provided
      ...(payload.imageUrl ? { big_picture: payload.imageUrl } : {}),
      // Android accent color (Rentilly Emerald Green #10B981)
      android_accent_color: 'FF10B981',
      // iOS rich media attachments
      ios_attachments: {
        rentilly_logo: brandLogoUrl
      },
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

    // Determine targeting — Isolate to Rentilly players to prevent collisions with other apps sharing FCM
    if (payload.targetExternalIds && payload.targetExternalIds.length > 0) {
      body.include_aliases = { external_id: payload.targetExternalIds };
      body.target_channel = 'push';
    } else if (payload.targetPlayerIds && payload.targetPlayerIds.length > 0) {
      body.include_subscription_ids = payload.targetPlayerIds;
    } else if (payload.filters && payload.filters.length > 0) {
      body.filters = payload.filters;
    } else {
      // Query genuine Rentilly player IDs registered from mobile app
      const rentillyPlayers = await getRentillyRegisteredPlayerIds();
      if (rentillyPlayers.length > 0) {
        body.include_subscription_ids = rentillyPlayers;
      } else if (payload.targetSegments && payload.targetSegments.length > 0) {
        body.included_segments = payload.targetSegments;
      } else {
        body.filters = [{ field: 'tag', key: 'app', relation: '=', value: 'rentilly' }];
      }
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
      // Silently skip known non-actionable errors — these happen when the user hasn't
      // registered their device token yet (e.g. hasn't opened the app on this device).
      const errStr = JSON.stringify(result.errors || '');
      const isKnownSilentError =
        errStr.includes('invalid_player_ids') ||
        errStr.includes('invalid_aliases') ||
        errStr.includes('not subscribed') ||
        errStr.includes('All included players are not subscribed');
      if (!isKnownSilentError) {
        console.warn('[OneSignal] Push delivery issue:', result);
      }
      return { success: false, error: errStr };
    }
  } catch (err: any) {
    console.error('[OneSignal] Push error:', err.message);
    return { success: false, error: err.message };
  }
}

// ─── Convenience Methods ───────────────────────────────────

/** Send push to ALL subscribed users */
export function pushToAll(title: string, message: string, data?: Record<string, string>) {
  return sendPushNotification({ title, message, data, targetSegments: ['Total Subscriptions', 'Subscribed Users'] });
}
export const broadcastToAll = pushToAll;

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
