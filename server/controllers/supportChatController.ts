import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { autoAssignConversation, decrementAgentChats } from './supportAgentController';

// ── Support Live Chat Controller ──────────────────────────────────────────────

export async function createOrGetConversation(req: Request, res: Response) {
  try {
    const { userEmail, userName, userRole, userId, subject } = req.body;
    if (!userEmail) return res.status(400).json({ error: 'userEmail is required' });
    const cleanEmail = userEmail.toLowerCase().trim();
    const cleanSubject = (subject || 'General Support').trim();
    if (!supabase) return res.status(503).json({ error: 'Database not available' });

    const { data: existing } = await supabase
      .from('support_conversations')
      .select('*')
      .eq('user_email', cleanEmail)
      .in('status', ['open', 'pending'])
      .order('created_at', { ascending: false })
      .limit(1);

    if (existing && existing.length > 0) {
      return res.json({ success: true, conversation: existing[0], isNew: false });
    }

    const { data: newConv, error } = await supabase
      .from('support_conversations')
      .insert({
        user_id: userId || `usr_${Date.now()}`,
        user_email: cleanEmail,
        user_name: userName || cleanEmail.split('@')[0],
        user_role: userRole || 'renter',
        subject: cleanSubject,
        status: 'open',
        priority: 'normal',
        last_message: '',
        unread_by_user: 0,
        unread_by_agent: 0,
      })
      .select()
      .single();

    if (error) throw error;

    const firstName = (userName || '').split(' ')[0] || 'there';
    await supabase.from('support_messages').insert({
      conversation_id: newConv.id,
      sender: 'bot',
      sender_name: 'Rentilly Support',
      message: `Hi ${firstName}! Welcome to Rentilly Support. You are chatting about: ${cleanSubject}. One of our agents will respond shortly. For urgent matters, email support@myrentilly.com`,
      message_type: 'text',
      is_read: false,
    });

    // Auto-assign to the least-busy online agent (fire-and-forget)
    autoAssignConversation(newConv.id, userName || cleanEmail.split('@')[0], cleanSubject).catch(() => {});

    return res.json({ success: true, conversation: newConv, isNew: true });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

export async function sendMessage(req: Request, res: Response) {
  try {
    const { conversationId, message, sender, senderName } = req.body;
    if (!conversationId || !message) return res.status(400).json({ error: 'conversationId and message are required' });
    if (!supabase) return res.status(503).json({ error: 'Database not available' });

    const cleanSender = sender || 'user';
    const cleanSenderName = senderName || (cleanSender === 'agent' ? 'Rentilly Support' : 'User');

    const { data: newMsg, error } = await supabase
      .from('support_messages')
      .insert({ conversation_id: conversationId, sender: cleanSender, sender_name: cleanSenderName, message: message.trim(), message_type: 'text', is_read: false })
      .select().single();

    if (error) throw error;

    const updatePayload: any = { last_message: message.trim().substring(0, 120), last_message_at: new Date().toISOString(), status: 'open' };

    if (cleanSender === 'user') {
      const { data: conv } = await supabase.from('support_conversations').select('unread_by_agent').eq('id', conversationId).single();
      updatePayload.unread_by_agent = ((conv?.unread_by_agent || 0) as number) + 1;
    } else if (cleanSender === 'agent') {
      const { data: conv } = await supabase.from('support_conversations').select('unread_by_user, user_id, user_email, user_name').eq('id', conversationId).single();
      updatePayload.unread_by_user = ((conv?.unread_by_user || 0) as number) + 1;
      updatePayload.status = 'pending';
      if (conv?.user_email) {
        NotificationDispatcher.dispatch({ userId: conv.user_id, email: conv.user_email, userName: conv.user_name || 'User', title: 'New Reply from Rentilly Support', category: 'system', message: ${cleanSenderName}: , metadata: { conversationId, type: 'support_reply' } }).catch(() => {});
      }
    }

    await supabase.from('support_conversations').update(updatePayload).eq('id', conversationId);
    return res.json({ success: true, message: newMsg });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

export async function listConversations(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const status = req.query.status as string | undefined;
    let query = supabase.from('support_conversations').select('*').order('last_message_at', { ascending: false });
    if (status && status !== 'all') query = query.eq('status', status);
    const { data, error } = await query;
    if (error) throw error;
    return res.json(data || []);
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

export async function getMessages(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { data, error } = await supabase.from('support_messages').select('*').eq('conversation_id', req.params.id).order('created_at', { ascending: true });
    if (error) throw error;
    return res.json(data || []);
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

export async function updateConversation(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const allowed = ['status', 'priority', 'assigned_to', 'assigned_agent_id', 'assigned_agent_email', 'assigned_agent_name', 'unread_by_agent', 'unread_by_user'];
    const update: any = { updated_at: new Date().toISOString() };
    for (const key of allowed) { if (req.body[key] !== undefined) update[key] = req.body[key]; }

    // If closing or resolving: decrement assigned agent's active_chats counter
    if (update.status === 'resolved' || update.status === 'closed') {
      const { data: conv } = await supabase.from('support_conversations').select('assigned_agent_email').eq('id', req.params.id).maybeSingle();
      if (conv?.assigned_agent_email) {
        decrementAgentChats(conv.assigned_agent_email).catch(() => {});
      }
    }

    const { data, error } = await supabase.from('support_conversations').update(update).eq('id', req.params.id).select().single();
    if (error) throw error;
    return res.json({ success: true, conversation: data });
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

export async function getUserConversations(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const email = decodeURIComponent(req.params.email).toLowerCase().trim();
    const { data, error } = await supabase.from('support_conversations').select('*').eq('user_email', email).order('last_message_at', { ascending: false });
    if (error) throw error;
    return res.json(data || []);
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}
