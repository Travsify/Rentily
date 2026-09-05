import type { Request, Response } from 'express';
import { createHash, createHmac, randomBytes } from 'crypto';
import { supabase } from '../supabaseClient';
import { NotificationDispatcher } from '../services/notificationDispatcher';

// ── Support Agent Controller ─────────────────────────────────────────────────
// Manages customer support agents: create, list, login, heartbeat, deactivate.
// Uses Node crypto (sha256) for passwords — no external deps needed.
// Token format: HMAC-SHA256 signed, base64url encoded.
// ─────────────────────────────────────────────────────────────────────────────

const TOKEN_SECRET = process.env.SUPPORT_AGENT_SECRET || 'rentilly_support_agent_secret_2026';
const OFFLINE_AFTER_MS = 2 * 60 * 1000; // 2 minutes no heartbeat → offline

function hashPassword(password: string): string {
  return createHash('sha256').update(password + TOKEN_SECRET).digest('hex');
}

function verifyPassword(password: string, hash: string): boolean {
  return hashPassword(password) === hash;
}

function createAgentToken(agent: { id: string; email: string; name: string; role: string }): string {
  const payload = Buffer.from(JSON.stringify({
    id: agent.id,
    email: agent.email,
    name: agent.name,
    role: agent.role,
    iat: Date.now(),
    type: 'support_agent',
  })).toString('base64url');
  const sig = createHmac('sha256', TOKEN_SECRET).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

function verifyAgentToken(token: string): { id: string; email: string; name: string; role: string } | null {
  try {
    const [payload, sig] = token.split('.');
    const expectedSig = createHmac('sha256', TOKEN_SECRET).update(payload).digest('base64url');
    if (sig !== expectedSig) return null;
    return JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch { return null; }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/support/agents — admin creates a new support agent
// ─────────────────────────────────────────────────────────────────────────────
export async function createAgent(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { name, email, password, role, createdBy } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'name, email and password are required' });
    }
    const cleanEmail = email.toLowerCase().trim();
    const agentRole = role === 'senior_agent' ? 'senior_agent' : 'customer_support';

    // Check duplicate
    const { data: existing } = await supabase
      .from('support_agents').select('id').eq('email', cleanEmail).maybeSingle();
    if (existing) return res.status(409).json({ error: 'An agent with this email already exists' });

    const passwordHash = hashPassword(password);
    const { data: agent, error } = await supabase
      .from('support_agents')
      .insert({ name: name.trim(), email: cleanEmail, password_hash: passwordHash, role: agentRole, created_by: createdBy || 'admin', is_active: true, is_online: false, active_chats: 0 })
      .select('id, name, email, role, is_active, is_online, active_chats, created_at')
      .single();
    if (error) throw error;

    // Email welcome to agent
    NotificationDispatcher.dispatch({
      userId: agent.id,
      email: cleanEmail,
      userName: name.trim(),
      title: 'Welcome to Rentilly Support Team',
      category: 'system',
      message: `Hi ${name.split(' ')[0]}! Your Rentilly Support Agent account has been created.\n\nLogin at: https://api.myrentilly.com\nEmail: ${cleanEmail}\nPassword: ${password}\n\nPlease change your password after first login.`,
      metadata: { type: 'agent_welcome', agentId: agent.id },
    }).catch(() => {});

    return res.status(201).json({ success: true, agent });
  } catch (err: any) {
    console.error('[supportAgent] createAgent:', err.message);
    return res.status(500).json({ error: err.message });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/support/agents — list all agents (admin view)
// ─────────────────────────────────────────────────────────────────────────────
export async function listAgents(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });

    // Auto-mark agents offline if last_seen > 2 minutes ago
    const cutoff = new Date(Date.now() - OFFLINE_AFTER_MS).toISOString();
    await supabase
      .from('support_agents')
      .update({ is_online: false })
      .eq('is_online', true)
      .lt('last_seen', cutoff);

    const { data, error } = await supabase
      .from('support_agents')
      .select('id, name, email, role, is_active, is_online, active_chats, last_seen, created_by, created_at')
      .order('created_at', { ascending: true });
    if (error) throw error;
    return res.json(data || []);
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/support/agents/login — agent authenticates
// ─────────────────────────────────────────────────────────────────────────────
export async function loginAgent(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'email and password required' });
    const cleanEmail = email.toLowerCase().trim();

    const { data: agent, error } = await supabase
      .from('support_agents')
      .select('id, name, email, role, password_hash, is_active, is_online, active_chats')
      .eq('email', cleanEmail)
      .maybeSingle();

    if (error || !agent) return res.status(401).json({ error: 'Invalid agent credentials' });
    if (!agent.is_active) return res.status(403).json({ error: 'This agent account has been deactivated' });
    if (!verifyPassword(password, agent.password_hash)) {
      return res.status(401).json({ error: 'Invalid agent credentials' });
    }

    // Mark online
    await supabase.from('support_agents')
      .update({ is_online: true, last_seen: new Date().toISOString() })
      .eq('id', agent.id);

    const token = createAgentToken({ id: agent.id, email: agent.email, name: agent.name, role: agent.role });

    // Auto-assign any unassigned open conversations to this agent (up to 3)
    autoAssignPending(agent.id, agent.email, agent.name).catch(() => {});

    return res.json({
      success: true,
      token,
      agent: { id: agent.id, name: agent.name, email: agent.email, role: agent.role, active_chats: agent.active_chats }
    });
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/support/agents/:id/heartbeat — keep agent online
// ─────────────────────────────────────────────────────────────────────────────
export async function heartbeat(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    await supabase.from('support_agents')
      .update({ is_online: true, last_seen: new Date().toISOString() })
      .eq('id', req.params.id);
    return res.json({ ok: true });
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/support/agents/:id — update agent (deactivate, role change, etc)
// ─────────────────────────────────────────────────────────────────────────────
export async function updateAgent(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const allowed = ['is_active', 'role', 'name', 'onesignal_player_id'];
    const update: any = { updated_at: new Date().toISOString() };
    for (const key of allowed) { if (req.body[key] !== undefined) update[key] = req.body[key]; }

    // If deactivating: mark offline and reassign their chats
    if (req.body.is_active === false) {
      update.is_online = false;
      const { data: agent } = await supabase.from('support_agents').select('email').eq('id', req.params.id).maybeSingle();
      if (agent?.email) {
        reassignChats(agent.email).catch(() => {});
      }
    }

    const { data, error } = await supabase.from('support_agents').update(update).eq('id', req.params.id).select().single();
    if (error) throw error;
    return res.json({ success: true, agent: data });
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/support/conversations/agent/:agentEmail — agent's assigned conversations
// ─────────────────────────────────────────────────────────────────────────────
export async function getAgentConversations(req: Request, res: Response) {
  try {
    if (!supabase) return res.status(503).json({ error: 'Database not available' });
    const email = decodeURIComponent(req.params.agentEmail).toLowerCase().trim();
    const { data, error } = await supabase
      .from('support_conversations')
      .select('*')
      .eq('assigned_agent_email', email)
      .not('status', 'in', '("closed")')
      .order('last_message_at', { ascending: false });
    if (error) throw error;
    return res.json(data || []);
  } catch (err: any) { return res.status(500).json({ error: err.message }); }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL: autoAssign — find the least-busy online agent and assign a conversation
// Called from supportChatController when a new conversation is created.
// ─────────────────────────────────────────────────────────────────────────────
export async function autoAssignConversation(conversationId: string, userName: string, subject: string): Promise<void> {
  if (!supabase) return;
  try {
    // Find the online active agent with fewest active chats
    const { data: agents } = await supabase
      .from('support_agents')
      .select('id, name, email, active_chats')
      .eq('is_active', true)
      .eq('is_online', true)
      .order('active_chats', { ascending: true })
      .limit(1);

    if (!agents || agents.length === 0) return; // No one online — stays unassigned

    const agent = agents[0];

    // Assign conversation
    await supabase.from('support_conversations').update({
      assigned_agent_id: agent.id,
      assigned_agent_email: agent.email,
      assigned_agent_name: agent.name,
      updated_at: new Date().toISOString(),
    }).eq('id', conversationId);

    // Increment agent's active_chats
    await supabase.from('support_agents').update({ active_chats: agent.active_chats + 1 }).eq('id', agent.id);

    // Notify agent by email
    NotificationDispatcher.dispatch({
      userId: agent.id,
      email: agent.email,
      userName: agent.name,
      title: `New Chat Assigned: ${subject} 💬`,
      category: 'system',
      message: `Hi ${agent.name.split(' ')[0]}! A new support conversation has been assigned to you.\n\nUser: ${userName}\nTopic: ${subject}\n\nLog in to the admin dashboard to respond.`,
      metadata: { type: 'chat_assigned', conversationId, subject },
    }).catch(() => {});

  } catch (err: any) {
    console.error('[supportAgent] autoAssignConversation error:', err.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL: autoAssignPending — when agent logs in, assign up to 3 oldest
// unassigned open conversations to them
// ─────────────────────────────────────────────────────────────────────────────
async function autoAssignPending(agentId: string, agentEmail: string, agentName: string): Promise<void> {
  if (!supabase) return;
  try {
    const { data: unassigned } = await supabase
      .from('support_conversations')
      .select('id, user_name, subject')
      .is('assigned_agent_id', null)
      .eq('status', 'open')
      .order('created_at', { ascending: true })
      .limit(3);

    if (!unassigned || unassigned.length === 0) return;

    for (const conv of unassigned) {
      await supabase.from('support_conversations').update({
        assigned_agent_id: agentId,
        assigned_agent_email: agentEmail,
        assigned_agent_name: agentName,
        updated_at: new Date().toISOString(),
      }).eq('id', conv.id);
    }

    const { data: currentAgent } = await supabase.from('support_agents').select('active_chats').eq('id', agentId).maybeSingle();
    if (currentAgent) {
      await supabase.from('support_agents').update({ active_chats: (currentAgent.active_chats || 0) + unassigned.length }).eq('id', agentId);
    }
  } catch (err: any) {
    console.error('[supportAgent] autoAssignPending error:', err.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL: reassignChats — when an agent is deactivated, move their open chats
// to the unassigned queue so another agent can pick them up
// ─────────────────────────────────────────────────────────────────────────────
async function reassignChats(agentEmail: string): Promise<void> {
  if (!supabase) return;
  try {
    await supabase.from('support_conversations').update({
      assigned_agent_id: null,
      assigned_agent_email: null,
      assigned_agent_name: null,
      updated_at: new Date().toISOString(),
    }).eq('assigned_agent_email', agentEmail).in('status', ['open', 'pending']);
  } catch {}
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL: decrementAgentChats — call when a conversation is resolved/closed
// ─────────────────────────────────────────────────────────────────────────────
export async function decrementAgentChats(agentEmail: string): Promise<void> {
  if (!supabase || !agentEmail) return;
  try {
    const { data: agent } = await supabase.from('support_agents').select('id, active_chats').eq('email', agentEmail).maybeSingle();
    if (agent && agent.active_chats > 0) {
      await supabase.from('support_agents').update({ active_chats: agent.active_chats - 1 }).eq('id', agent.id);
    }
  } catch {}
}
