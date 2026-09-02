import type { Request, Response } from 'express';
import { NotificationDispatcher } from '../services/notificationDispatcher';

export interface SupportTicket {
  id: string;
  userId: string;
  userEmail: string;
  userName: string;
  businessName?: string;
  role: string;
  category: string;
  subject: string;
  message: string;
  urgency: 'normal' | 'urgent' | 'critical';
  status: 'open' | 'in_review' | 'resolved' | 'closed';
  createdAt: string;
}

const _tickets: SupportTicket[] = [];

export async function submitTicket(req: Request, res: Response) {
  try {
    const { userId, userEmail, userName, businessName, role, category, subject, message, urgency } = req.body;

    if (!userEmail || !subject || !message) {
      return res.status(400).json({ error: 'Email, subject, and message are required' });
    }

    const ticketId = `TKT-PTR-${Math.floor(10000 + Math.random() * 90000)}`;
    const newTicket: SupportTicket = {
      id: ticketId,
      userId: userId || `usr_${Date.now()}`,
      userEmail: userEmail.trim().toLowerCase(),
      userName: userName || 'Corporate Partner',
      businessName,
      role: role || 'partner',
      category: category || 'general',
      subject: subject.trim(),
      message: message.trim(),
      urgency: urgency || 'normal',
      status: 'open',
      createdAt: new Date().toISOString()
    };

    _tickets.unshift(newTicket);

    // Dispatch confirmation to user
    NotificationDispatcher.dispatch({
      userId: newTicket.userId,
      email: newTicket.userEmail,
      userName: newTicket.userName,
      title: `Support Ticket Logged: ${ticketId} 📋`,
      category: 'system',
      message: `Your inquiry regarding "${newTicket.subject}" has been logged. Rentilly Legal SLA: 24–72 hours.`,
      metadata: { ticketId, category: newTicket.category }
    });

    res.status(201).json({
      success: true,
      ticketId,
      ticket: newTicket,
      message: 'Support ticket routed to Rentilly Legal Desk successfully'
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function listTickets(_req: Request, res: Response) {
  res.json(_tickets);
}
