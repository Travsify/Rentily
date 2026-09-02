import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';

export interface FlaggedChatMessage {
  id: string;
  senderId: string;
  senderName: string;
  senderRole: string;
  recipientId: string;
  propertyId?: string;
  propertyTitle?: string;
  content: string;
  violationType: 'phone_number' | 'bank_account' | 'circumvention_keyword';
  flaggedContent: string;
  severity: 'medium' | 'high' | 'critical';
  status: 'flagged' | 'reviewed' | 'dismissed';
  createdAt: string;
}

const PHONE_REGEX = /(?:(?:\+?234)|0)[789][01]\d{8}/g;
const BANK_ACCOUNT_REGEX = /\b\d{10}\b/g;
const CIRCUMVENTION_KEYWORDS = [
  'pay directly',
  'pay outside',
  'call me outside',
  'bypass',
  'off the app',
  'don\'t pay on app',
  'my personal account',
  'transfer to me',
  'avoid the fee',
  'save commission'
];

export async function getChatOversight(req: Request, res: Response) {
  try {
    const flaggedList: FlaggedChatMessage[] = [];

    if (supabase) {
      try {
        const { data: messages } = await supabase
          .from('chat_messages')
          .select('*, sender:profiles!sender_id(full_name, role)')
          .order('created_at', { ascending: false })
          .limit(200);

        if (messages && messages.length > 0) {
          for (const msg of messages) {
            const text = String(msg.message || msg.content || '');
            let violation: FlaggedChatMessage['violationType'] | null = null;
            let flaggedPiece = '';
            let severity: FlaggedChatMessage['severity'] = 'medium';

            // Check phone number
            const phoneMatches = text.match(PHONE_REGEX);
            if (phoneMatches) {
              violation = 'phone_number';
              flaggedPiece = phoneMatches.join(', ');
              severity = 'high';
            }

            // Check bank account
            const bankMatches = text.match(BANK_ACCOUNT_REGEX);
            if (!violation && bankMatches) {
              violation = 'bank_account';
              flaggedPiece = bankMatches.join(', ');
              severity = 'critical';
            }

            // Check keywords
            if (!violation) {
              const lower = text.toLowerCase();
              for (const kw of CIRCUMVENTION_KEYWORDS) {
                if (lower.includes(kw)) {
                  violation = 'circumvention_keyword';
                  flaggedPiece = kw;
                  severity = 'critical';
                  break;
                }
              }
            }

            if (violation) {
              flaggedList.push({
                id: msg.id,
                senderId: msg.sender_id,
                senderName: msg.sender?.full_name || 'Stakeholder',
                senderRole: msg.sender?.role || 'user',
                recipientId: msg.recipient_id || 'landlord',
                propertyId: msg.property_id,
                propertyTitle: msg.property_title || 'Platform Listing',
                content: text,
                violationType: violation,
                flaggedContent: flaggedPiece,
                severity,
                status: 'flagged',
                createdAt: msg.created_at || new Date().toISOString()
              });
            }
          }
        }
      } catch (_) {}
    }

    res.json({
      success: true,
      totalFlagged: flaggedList.length,
      flaggedMessages: flaggedList
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
