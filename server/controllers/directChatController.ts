import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import { NotificationDispatcher } from '../services/notificationDispatcher';

// ── Direct Chat Controller ────────────────────────────────────────────────────
// Handles real-time direct messaging between tenants and landlords/partners.
// All messages stored in Supabase: direct_conversations + direct_messages.
// Includes anti-circumvention scanning on every inbound message.
// ─────────────────────────────────────────────────────────────────────────────

const PHONE_REGEX = /(?:(?:\+?234)|0)[789][01]\d{8}/g;
const BANK_ACCOUNT_REGEX = /\b\d{10}\b/g;
const BYPASS_KEYWORDS = [
  'pay directly', 'pay outside', 'call me outside', 'bypass', 'off the app',
  'pay off app', "don't pay on app", 'my personal account', 'transfer to me',
  'avoid the fee', 'save commission', 'pay me directly', 'outside rentilly',
  'whatsapp me', 'my number is', 'call me on', 'transfer direct'
];

function scanForViolations(text: string): { flagged: boolean; reason: string } {
  const lower = text.toLowerCase();
  if (PHONE_REGEX.test(text)) return { flagged: true, reason: 'Phone number shared in chat' };
  if (BANK_ACCOUNT_REGEX.test(text)) return { flagged: true, reason: 'Possible bank account number shared' };
  for (const kw of BYPASS_KEYWORDS) {
    if (lower.includes(kw)) return { flagged: true, reason: `Circumvention keyword: "${kw}"` };
  }
  return { flagged: false, reason: '' };
}

// POST /api/direct-chat/conversations — create or return existing conversation
export async function createOrGetConversation(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { tenantId, tenantEmail, tenantName, ownerId, ownerName, ownerRole, propertyId, propertyTitle, propertyAddress } = req.body;
    if (!tenantId || !ownerId || !propertyId) {
      return res.status(400).json({ error: 'tenantId, ownerId, and propertyId are required' });
    }

    // Find existing active conversation for same tenant + property
    const { data: existing } = await supabase
      .from('direct_conversations')
      .select('*')
      .eq('tenant_id', tenantId)
      .eq('property_id', propertyId)
      .neq('status', 'closed')
      .order('created_at', { ascending: false })
      .limit(1);

    if (existing && existing.length > 0) {
      return res.json({ success: true, conversation: existing[0], isNew: false });
    }

    const { data: newConv, error } = await supabase
      .from('direct_conversations')
      .insert({
        tenant_id: tenantId,
        tenant_email: (tenantEmail || '').toLowerCase().trim(),
        tenant_name: tenantName || 'Tenant',
        owner_id: ownerId,
        owner_name: ownerName || 'Property Owner',
        owner_role: ownerRole || 'landlord',
        property_id: propertyId,
        property_title: propertyTitle || 'Property Enquiry',
        property_address: propertyAddress || '',
        status: 'active',
        last_message: '',
        unread_by_tenant: 0,
        unread_by_owner: 1, // owner has 1 unread — new conversation notification
      })
      .select()
      .single();

    if (error) throw error;

    // Notify the owner that a tenant has started a conversation
    NotificationDispatcher.dispatch({
      userId: ownerId,
      email: '', // owner email not in body — push via userId
      userName: ownerName || 'Property Owner',
      title: `New Enquiry on ${propertyTitle || 'Your Property'} 🏠`,
      category: 'system',
      message: `${tenantName || 'A tenant'} has sent you a message about ${propertyTitle || 'your property'}. Log in to Rentilly to respond.`,
      metadata: { type: 'new_conversation', conversationId: newConv.id, propertyId },
    }).catch(() => {});

    return res.json({ success: true, conversation: newConv, isNew: true });
  } catch (err: any) {
    console.error('[directChat] createOrGetConversation:', err.message);
    return res.status(500).json({ error: err.message });
  }
}

// POST /api/direct-chat/conversations/:id/messages — send a message
export async function sendMessage(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { senderId, senderName, senderRole, message } = req.body;
    const conversationId = req.params.id;

    if (!conversationId || !message?.trim()) {
      return res.status(400).json({ error: 'conversationId and message are required' });
    }

    const cleanMsg = message.trim();
    const { flagged, reason } = scanForViolations(cleanMsg);

    // Insert message
    const { data: newMsg, error: msgErr } = await supabase
      .from('direct_messages')
      .insert({
        conversation_id: conversationId,
        sender_id: senderId || '',
        sender_name: senderName || 'User',
        sender_role: senderRole || 'renter',
        message: cleanMsg,
        is_flagged: flagged,
        flag_reason: reason || null,
      })
      .select()
      .single();

    if (msgErr) throw msgErr;

    // Update conversation last_message and unread counter
    const isTenant = ['renter', 'buyer', 'tenant'].includes((senderRole || '').toLowerCase());
    const updatePayload: any = {
      last_message: cleanMsg.substring(0, 120),
      last_message_at: new Date().toISOString(),
    };

    const { data: conv } = await supabase
      .from('direct_conversations')
      .select('unread_by_owner, unread_by_tenant, tenant_id, owner_id, tenant_name, owner_name, property_title')
      .eq('id', conversationId)
      .single();

    if (isTenant) {
      updatePayload.unread_by_owner = ((conv?.unread_by_owner || 0) as number) + 1;
      // Push notify the owner
      if (conv?.owner_id) {
        NotificationDispatcher.dispatch({
          userId: conv.owner_id,
          email: '',
          userName: conv.owner_name || 'Property Owner',
          title: `New message from ${senderName || 'a tenant'} 💬`,
          category: 'system',
          message: `Re: ${conv.property_title || 'your property'} — ${cleanMsg.substring(0, 80)}`,
          metadata: { type: 'direct_message', conversationId, propertyTitle: conv.property_title },
        }).catch(() => {});
      }
    } else {
      updatePayload.unread_by_tenant = ((conv?.unread_by_tenant || 0) as number) + 1;
      // Push notify the tenant
      if (conv?.tenant_id) {
        NotificationDispatcher.dispatch({
          userId: conv.tenant_id,
          email: '',
          userName: conv.tenant_name || 'Tenant',
          title: `Reply from ${senderName || 'the owner'} 🏠`,
          category: 'system',
          message: `Re: ${conv.property_title || 'your enquiry'} — ${cleanMsg.substring(0, 80)}`,
          metadata: { type: 'direct_message', conversationId, propertyTitle: conv.property_title },
        }).catch(() => {});
      }
    }

    await supabase.from('direct_conversations').update(updatePayload).eq('id', conversationId);

    return res.json({ success: true, message: newMsg, flagged, flagReason: reason || null });
  } catch (err: any) {
    console.error('[directChat] sendMessage:', err.message);
    return res.status(500).json({ error: err.message });
  }
}

// GET /api/direct-chat/conversations/:id/messages
export async function getMessages(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { data, error } = await supabase
      .from('direct_messages')
      .select('*')
      .eq('conversation_id', req.params.id)
      .order('created_at', { ascending: true });
    if (error) throw error;
    return res.json(data || []);
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// GET /api/direct-chat/conversations/tenant/:tenantId
export async function getTenantConversations(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { data, error } = await supabase
      .from('direct_conversations')
      .select('*')
      .eq('tenant_id', req.params.tenantId)
      .neq('status', 'closed')
      .order('last_message_at', { ascending: false });
    if (error) throw error;
    return res.json(data || []);
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// GET /api/direct-chat/conversations/owner/:ownerId
export async function getOwnerConversations(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { data, error } = await supabase
      .from('direct_conversations')
      .select('*')
      .eq('owner_id', req.params.ownerId)
      .neq('status', 'closed')
      .order('last_message_at', { ascending: false });
    if (error) throw error;
    return res.json(data || []);
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// PATCH /api/direct-chat/conversations/:id — mark read / update status
export async function updateConversation(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const allowed = ['status', 'unread_by_tenant', 'unread_by_owner'];
    const update: any = { updated_at: new Date().toISOString() };
    for (const key of allowed) { if (req.body[key] !== undefined) update[key] = req.body[key]; }
    const { data, error } = await supabase
      .from('direct_conversations')
      .update(update)
      .eq('id', req.params.id)
      .select()
      .single();
    if (error) throw error;
    return res.json({ success: true, conversation: data });
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// GET /api/direct-chat/oversight — flagged messages for admin (replaces broken chat_oversight table query)
export async function getFlaggedMessages(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { data, error } = await supabase
      .from('direct_messages')
      .select(`*, conversation:direct_conversations!conversation_id(tenant_name, owner_name, property_title)`)
      .eq('is_flagged', true)
      .order('created_at', { ascending: false })
      .limit(100);
    if (error) throw error;
    // Return in format expected by ChatOversightTab
    const flaggedMessages = (data || []).map(m => ({
      id: m.id,
      senderId: m.sender_id,
      senderName: m.sender_name,
      senderRole: m.sender_role,
      recipientId: '',
      propertyTitle: m.conversation?.property_title || '',
      content: m.message,
      violationType: 'circumvention_keyword',
      flaggedContent: m.flag_reason || '',
      severity: 'high',
      status: 'flagged',
      createdAt: m.created_at,
    }));
    return res.json({ flaggedMessages });
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// POST /api/direct-chat/scan — standalone scan endpoint (mobile calls this fire-and-forget)
export async function scanMessage(req: Request, res: Response) {
  const { message } = req.body;
  if (!message) return res.status(400).json({ error: 'message required' });
  return res.json(scanForViolations(message));
}
