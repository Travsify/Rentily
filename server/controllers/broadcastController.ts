import type { Request, Response } from 'express';
import { UserStore } from '../services/userStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import * as OneSignal from '../services/onesignalService';

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

const _broadcastHistory: BroadcastLog[] = [];

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

    // Dispatch in-app notifications (existing flow)
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

    // ── OneSignal Real Push Notifications ──────────────────────
    let pushResult: { success: boolean; id?: string; error?: string } = { success: false };

    if (channel === 'push' || channel === 'both') {
      if (targetGroup === 'specific' && specificEmail) {
        // Send to specific user by email tag
        pushResult = await OneSignal.pushToEmail(specificEmail, `📢 ${title}`, message, { action: 'open_notifications' });
      } else if (targetGroup === 'renters') {
        pushResult = await OneSignal.pushToRole('renter', `📢 ${title}`, message, { action: 'open_notifications' });
      } else if (targetGroup === 'owners') {
        pushResult = await OneSignal.pushToRole('owner', `📢 ${title}`, message, { action: 'open_notifications' });
      } else if (targetGroup === 'partners') {
        pushResult = await OneSignal.pushToRole('partner', `📢 ${title}`, message, { action: 'open_notifications' });
      } else {
        // Broadcast to ALL subscribed users
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
    _broadcastHistory.unshift(logEntry);

    res.json({
      success: true,
      message: `Broadcast dispatched to ${targets.length} recipients.${pushResult.success ? ' Push notification sent ✓' : ''}`,
      broadcast: logEntry
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export function getBroadcastHistory(_req: Request, res: Response) {
  res.json({
    success: true,
    history: _broadcastHistory
  });
}
