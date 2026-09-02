import type { Request, Response } from 'express';
import { UserStore } from '../services/userStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';

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

    const logEntry: BroadcastLog = {
      id: `BC-${Date.now()}`,
      targetGroup,
      title,
      message,
      category: 'broadcast',
      channel,
      recipientCount: targets.length,
      sentBy: 'Super Admin',
      createdAt: new Date().toISOString()
    };
    _broadcastHistory.unshift(logEntry);

    res.json({
      success: true,
      message: `Broadcast successfully dispatched to ${targets.length} recipients.`,
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
