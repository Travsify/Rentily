import type { Request, Response } from 'express';
import { UserStore } from '../services/userStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import * as OneSignal from '../services/onesignalService';
import { supabase } from '../supabaseClient';

export interface BroadcastLog {
  id: string;
  targetGroup: 'all' | 'renters' | 'owners' | 'partners' | 'specific';
  title: string;
  message: string;
  category: string;
  channel: 'push' | 'sms' | 'both';
  recipientCount: number;
  sentBy: string;
  createdAt: string;
  pushResult?: { success: boolean; id?: string; error?: string };
}

let _broadcastHistory: BroadcastLog[] = [];

/**
 * Hydrates broadcasts from Supabase on server boot
 */
export async function initBroadcastsFromSupabase(): Promise<void> {
  if (!supabase) return;
  try {
    const { data, error } = await supabase
      .from('system_configs')
      .select('data')
      .eq('id', 'broadcast_history')
      .single();

    if (!error && data && Array.isArray(data.data)) {
      _broadcastHistory = data.data;
      console.log(`[BroadcastController] Hydrated ${_broadcastHistory.length} broadcasts from Supabase.`);
    }
  } catch (err: any) {
    console.warn('[BroadcastController] Notice on broadcast hydration:', err.message);
  }
}

async function saveBroadcasts(history: BroadcastLog[]): Promise<void> {
  _broadcastHistory = history;
  if (supabase) {
    try {
      await supabase.from('system_configs').upsert({
        id: 'broadcast_history',
        data: history,
        updated_at: new Date().toISOString()
      }, { onConflict: 'id' });
    } catch (e) {
      console.error('[BroadcastController] Error saving broadcasts to Supabase:', e);
    }
  }
}

export async function sendBroadcast(req: Request, res: Response) {
  try {
    const { targetGroup, title, message, channel = 'push', specificEmail } = req.body;

    if (!title || !message) {
      return res.status(400).json({ error: 'Title and message are required for a broadcast.' });
    }

    const allUsers = await UserStore.getAllUsers();
    let targets = allUsers;

    if (targetGroup === 'renters') {
      targets = allUsers.filter(u => u.role === 'renter');
    } else if (targetGroup === 'owners') {
      targets = allUsers.filter(u => u.role === 'owner');
    } else if (targetGroup === 'partners') {
      targets = allUsers.filter(u => u.role === 'partner' || (u as any).partnerStatus);
    } else if (targetGroup === 'specific' && specificEmail) {
      targets = allUsers.filter(u => u.email.toLowerCase() === specificEmail.toLowerCase());
    }

    // Dispatch in-app notifications
    for (const user of targets) {
      NotificationDispatcher.dispatch({
        userId: user.id,
        email: user.email,
        userName: user.fullName,
        title: `📢 ${title}`,
        category: 'broadcast',
        message: message,
        metadata: {
          channel,
          targetGroup
        }
      });
    }

    // OneSignal Push Notification
    let pushResult: { success: boolean; id?: string; error?: string } = { success: false };

    if (channel === 'push' || channel === 'both') {
      if (targetGroup === 'specific' && specificEmail) {
        pushResult = await OneSignal.pushToEmail(specificEmail, `📢 ${title}`, message, { action: 'open_notifications' });
      } else if (targetGroup === 'renters') {
        pushResult = await OneSignal.pushToRole('renter', `📢 ${title}`, message, { action: 'open_notifications' });
      } else if (targetGroup === 'owners') {
        pushResult = await OneSignal.pushToRole('owner', `📢 ${title}`, message, { action: 'open_notifications' });
      } else if (targetGroup === 'partners') {
        pushResult = await OneSignal.pushToRole('partner', `📢 ${title}`, message, { action: 'open_notifications' });
      } else {
        pushResult = await OneSignal.broadcastToAll(`📢 ${title}`, message);
      }
    }

    const logEntry: BroadcastLog = {
      id: `BC-${Date.now()}`,
      targetGroup,
      title,
      message,
      category: 'broadcast',
      channel,
      recipientCount: targets.length,
      sentBy: 'Super Admin',
      createdAt: new Date().toISOString(),
      pushResult,
    };

    const current = [..._broadcastHistory];
    current.unshift(logEntry);
    await saveBroadcasts(current);

    res.json({
      success: true,
      message: `Broadcast dispatched to ${targets.length} recipients.${pushResult.success ? ' Push notification sent ✓' : ''}`,
      broadcast: logEntry
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getBroadcastHistory(_req: Request, res: Response) {
  if (supabase) {
    try {
      const { data } = await supabase.from('system_configs').select('data').eq('id', 'broadcast_history').single();
      if (data && Array.isArray(data.data)) {
        _broadcastHistory = data.data;
      }
    } catch (_) {}
  }
  res.json({
    success: true,
    history: _broadcastHistory
  });
}
