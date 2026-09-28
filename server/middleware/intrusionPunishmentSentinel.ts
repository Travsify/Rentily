import type { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { supabase } from '../supabaseClient';
import { BotSentinelService } from '../services/botSentinelService';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { ExecutiveActivityAlertService } from '../services/executiveActivityAlertService';

// ============================================================================
// AGENT 8: In-Memory Quarantine & Subnet Sentinel Cache
// ============================================================================
const _blacklistedIps = new Set<string>();
const _blacklistedSubnets = new Set<string>(); // e.g., '192.168.1'
const _subnetHitCounter = new Map<string, { count: number; firstHit: number }>();
const _canaryTokens = new Set<string>([
  'sk_canary_honeytoken_trap_90192837498172',
  'rtly_live_canary_trap_sec_77819203948571'
]);

// Whitelist internal loopbacks
const WHITELISTED_IPS = new Set<string>(['127.0.0.1', '::1', '::ffff:127.0.0.1', 'localhost']);

// Hydrate banned IPs from Supabase on startup
(async () => {
  if (supabase) {
    try {
      const { data } = await supabase
        .from('system_configs')
        .select('id, data')
        .like('id', 'ban_ip_%');
      if (Array.isArray(data)) {
        for (const row of data) {
          const ip = row.id.replace('ban_ip_', '').trim();
          if (ip) _blacklistedIps.add(ip);
        }
        console.log(`🛡️ [IntrusionSentinel] Hydrated ${_blacklistedIps.size} blacklisted IPs from database.`);
      }
    } catch (_) {}
  }
})();

// Helper: Extract clean IPv4/IPv6 address
export function extractClientIp(req: Request): string {
  const forwarded = (req.headers['x-forwarded-for'] as string) || '';
  const firstForwarded = forwarded.split(',')[0].trim();
  const rawIp = firstForwarded || (req.socket?.remoteAddress || req.ip || '127.0.0.1');
  return rawIp.replace(/^::ffff:/, '').trim();
}

function getSubnet24(ip: string): string {
  const parts = ip.split('.');
  if (parts.length === 4) {
    return `${parts[0]}.${parts[1]}.${parts[2]}`;
  }
  return ip;
}

// ============================================================================
// AGENT 1: Attack Vector & Exploit Probe Detector
// ============================================================================
const MALICIOUS_PATH_PATTERNS = [
  /\.env(\.|$|\/)/i,
  /\.git(\.|$|\/)/i,
  /\.aws(\.|$|\/)/i,
  /\.svn(\.|$|\/)/i,
  /wp-admin/i,
  /wp-login/i,
  /xmlrpc\.php/i,
  /phpmyadmin/i,
  /pma/i,
  /adminer/i,
  /actuator(\/|$)/i,
  /swagger-ui/i,
  /v2\/api-docs/i,
  /eval-stdin/i,
  /cgi-bin/i,
  /shell\.php/i,
  /\.sql$/i,
  /database\.sql/i,
  /dump\.sql/i,
  /backup/i,
  /etc\/passwd/i,
  /etc\/shadow/i,
  /boot\.ini/i,
  /win\.ini/i,
  /proc\/self/i
];

const SCANNER_USER_AGENTS = [
  'sqlmap', 'nikto', 'gobuster', 'dirbuster', 'nuclei',
  'wpscan', 'masscan', 'zgrab', 'acunetix', 'nessus',
  'openvas', 'arachni', 'nmap', 'havij'
];

const INJECTION_PAYLOAD_REGEX = /(\bunion\s+all\s+select\b|\bunion\s+select\b|\bselect\s+.*\s+from\s+information_schema\b|\bwaitfor\s+delay\b|\bbenchmark\s*\(\s*\d+|\bsleep\s*\(\s*\d+|\bexec\s*\(\s*xp_cmdshell\b|--\s*$|\/\*.*\*\/)/i;

const PATH_TRAVERSAL_REGEX = /(\.\.[\/\\]|%2e%2e[\/\\]|%252e%252e)/i;

// ============================================================================
// AGENT 3: Cybercrime Legal Dossier Terminal UI Renderer
// ============================================================================
function renderCybercrimeDossier(res: Response, info: {
  ip: string;
  userAgent: string;
  path: string;
  trigger: string;
  payloadSnippet: string;
  timestamp: string;
}) {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>CRITICAL SECURITY INTERCEPTION | RENTILLY ESCROW GATEWAY</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: #030712;
      color: #ef4444;
      font-family: 'Courier New', Courier, monospace;
      padding: 24px;
      line-height: 1.5;
    }
    .container {
      max-width: 860px;
      margin: 40px auto;
      border: 2px solid #dc2626;
      border-radius: 8px;
      background: #090d16;
      box-shadow: 0 0 30px rgba(220, 38, 38, 0.4);
      overflow: hidden;
    }
    .header {
      background: #dc2626;
      color: #ffffff;
      padding: 16px 20px;
      font-weight: 900;
      letter-spacing: 2px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .content { padding: 24px; color: #f87171; }
    .telemetry-box {
      background: #000000;
      border: 1px dashed #ef4444;
      padding: 16px;
      margin: 18px 0;
      border-radius: 4px;
      font-size: 13px;
    }
    .telemetry-row { margin-bottom: 8px; display: flex; flex-wrap: wrap; }
    .telemetry-label { color: #9ca3af; width: 180px; font-weight: bold; }
    .telemetry-val { color: #fca5a5; font-weight: bold; word-break: break-all; }
    .legal-box {
      background: rgba(220, 38, 38, 0.1);
      border-left: 4px solid #dc2626;
      padding: 16px;
      margin: 20px 0;
      color: #fecaca;
      font-size: 12px;
    }
    .badge {
      display: inline-block;
      padding: 4px 8px;
      background: #dc2626;
      color: #fff;
      font-size: 11px;
      font-weight: bold;
      border-radius: 3px;
      margin-top: 10px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <span>🚨 CRITICAL SECURITY INTERCEPTION</span>
      <span>CODE: 403_MALICIOUS_PROBE</span>
    </div>
    <div class="content">
      <h2 style="color:#ffffff; margin-bottom: 12px;">UNAUTHORIZED INTRUSION PROBE INTERCEPTED & QUARANTINED</h2>
      <p>Your incoming network connection has triggered the <strong>Rentilly Real-Time Intrusion Sentinel & Anti-Syndicate Gateway</strong>. Your access to this platform has been terminated immediately.</p>

      <div class="telemetry-box">
        <div class="telemetry-row">
          <span class="telemetry-label">INTRUDER IP:</span>
          <span class="telemetry-val" style="color: #4ade80;">${info.ip}</span>
        </div>
        <div class="telemetry-row">
          <span class="telemetry-label">INTERCEPT TIMESTAMP:</span>
          <span class="telemetry-val">${info.timestamp}</span>
        </div>
        <div class="telemetry-row">
          <span class="telemetry-label">DETECTED VECTOR:</span>
          <span class="telemetry-val">${info.trigger}</span>
        </div>
        <div class="telemetry-row">
          <span class="telemetry-label">PROBED URI:</span>
          <span class="telemetry-val">${info.path}</span>
        </div>
        <div class="telemetry-row">
          <span class="telemetry-label">SIGNATURE SNIPPET:</span>
          <span class="telemetry-val">${info.payloadSnippet}</span>
        </div>
        <div class="telemetry-row">
          <span class="telemetry-label">CLIENT USER-AGENT:</span>
          <span class="telemetry-val">${info.userAgent}</span>
        </div>
      </div>

      <div class="legal-box">
        <strong>FEDERAL CYBERCRIMES STATUTE NOTICE:</strong><br>
        Unauthorized penetration testing, vulnerability scanning, path injection, or exploitation attempts against regulated financial infrastructure are severe federal felonies under <strong>Section 6 & 14 of the Cybercrimes (Prohibition, Prevention, etc.) Act 2015</strong>, punishable by up to <strong>10 YEARS IMPRISONMENT WITHOUT OPTION OF FINE</strong>.<br><br>
        Your connection routing records, raw payload packets, and device fingerprints have been cryptographically sealed and queued for submission to the <strong>EFCC Cyber Crime Operations Unit</strong> and the <strong>National Financial Intelligence Unit (NFIU)</strong>.
      </div>

      <div class="badge">AUDIT LEDGER REF: RNT_SEC_${Date.now().toString(36).toUpperCase()}</div>
      <p style="margin-top: 15px; font-size: 11px; color: #6b7280;">If you believe this interception was in error, disconnect all proxy/VPN tunnels and contact compliance@myrentilly.com.</p>
    </div>
  </div>
</body>
</html>`;
  res.status(403).setHeader('Content-Type', 'text/html; charset=utf-8').send(html);
}

// ============================================================================
// AGENT 2: Reverse Slowloris Tarpit Engine
// ============================================================================
function runTarpit(res: Response, clientIp: string, reason: string) {
  console.warn(`🪤 [Tarpit] Trapping scanner/bot from IP: ${clientIp} | Reason: ${reason}`);
  res.status(200);
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Transfer-Encoding', 'chunked');
  res.setHeader('X-Tarpit', 'active');

  // Drip 1 byte every 12 seconds to hold their scanner thread captive
  let drips = 0;
  const timer = setInterval(() => {
    try {
      if (res.writableEnded || res.destroyed) {
        clearInterval(timer);
        return;
      }
      res.write(`\n# [TAR_PIT_ACTIVE] Drip ${++drips} | Processing forensic scan packet...`);
      if (drips >= 30) { // Max 6 minutes hold
        clearInterval(timer);
        res.end('\n[TERMINATED_BY_SECURITY_SENTINEL]');
      }
    } catch (_) {
      clearInterval(timer);
    }
  }, 12000);

  res.on('close', () => clearInterval(timer));
}

// ============================================================================
// AGENT 4 & 5: Immediate Wallet, Session, and BVN/NIN Syndicate Cascader
// ============================================================================
async function executeAccountPunishment(emailOrId: string, clientIp: string, reason: string) {
  if (!emailOrId) return;
  console.warn(`🚨 [AccountPunishment] Freezing assets & blacklisting account: ${emailOrId} from IP: ${clientIp}`);

  try {
    // 1. Mark user banned in Supabase profiles
    if (supabase) {
      const isEmail = emailOrId.includes('@');
      const query = supabase.from('profiles').update({
        status: 'banned',
        is_banned: true,
        is_suspended: true,
        red_flagged: true
      });
      if (isEmail) query.eq('email', emailOrId.toLowerCase().trim());
      else query.eq('id', emailOrId);
      await query;

      // 2. Fetch BVN/NIN to cascade blacklist
      const { data: prof } = await supabase
        .from('profiles')
        .select('email, bvn_number, nin_number')
        .eq(isEmail ? 'email' : 'id', emailOrId)
        .maybeSingle();

      if (prof) {
        // Blacklist BVN & NIN so they can NEVER register on Rentilly again
        if (prof.bvn_number || prof.nin_number) {
          await supabase.from('system_configs').upsert({
            id: `banned_syndicate_id_${prof.email}`,
            data: {
              email: prof.email,
              bvn: prof.bvn_number || null,
              nin: prof.nin_number || null,
              reason: `Malicious intrusion probe: ${reason}`,
              bannedAt: new Date().toISOString()
            }
          });
        }
      }
    }

    // 3. Trigger BotSentinel global ban
    await BotSentinelService.flagAndBanAccount({
      email: emailOrId.includes('@') ? emailOrId : undefined,
      userId: !emailOrId.includes('@') ? emailOrId : undefined,
      ipAddress: clientIp,
      reason,
      trigger: 'malicious_web_probe'
    });
  } catch (err: any) {
    console.error('[AccountPunishment] Failed to execute full account freeze:', err?.message);
  }
}

// ============================================================================
// AGENT 9: Security Audit Ledger & Notification Dispatcher
// ============================================================================
async function logSecurityThreat(clientIp: string, details: any) {
  if (supabase) {
    try {
      await supabase.from('system_configs').upsert({
        id: `threat_log_${Date.now()}_${clientIp.replace(/[^a-zA-Z0-9]/g, '_')}`,
        data: details,
        updated_at: new Date().toISOString()
      });
    } catch (_) {}
  }

  // Dispatch real-time threat alert directly to info@myrentilly.com
  ExecutiveActivityAlertService.sendRealTimeActivityAlert({
    type: 'security_alert',
    title: `🚨 CRITICAL: Malicious Probe Intercepted from ${clientIp}`,
    summary: `Intrusion Sentinel intercepted malicious attempt:\nIP: ${clientIp}\nVector: ${details.trigger}\nURI: ${details.path}\nPayload: ${details.payloadSnippet || 'N/A'}\nAction Taken: ${details.actionTaken}`,
    ipAddress: clientIp,
    userAgent: details.userAgent,
    details: {
      'IP Address': clientIp,
      'Attack Vector': details.trigger,
      'Probed URI': details.path,
      'Raw Payload': details.payloadSnippet || 'N/A',
      'Action Executed': details.actionTaken,
      'Timestamp': details.timestamp || new Date().toISOString()
    }
  }).catch(() => {});

  // Dispatch emergency alert to Admin Operations
  NotificationDispatcher.dispatch({
    userId: 'admin_security_ops',
    email: 'info@myrentilly.com',
    userName: 'Security Operations',
    category: 'security',
    title: `🚨 CRITICAL: Malicious Probe Intercepted from ${clientIp}`,
    message: `Intrusion Sentinel intercepted malicious attempt:\nIP: ${clientIp}\nVector: ${details.trigger}\nURI: ${details.path}\nPayload: ${details.payloadSnippet || 'N/A'}\nAction Taken: ${details.actionTaken}`,
    metadata: {
      'IP': clientIp,
      'Trigger': details.trigger,
      'URI': details.path
    }
  });
}

// ============================================================================
// THE UNIFIED 10-AGENT INTRUSION PUNISHMENT SENTINEL MIDDLEWARE
// ============================================================================
export async function intrusionPunishmentSentinel(req: Request, res: Response, next: NextFunction): Promise<any> {
  const clientIp = extractClientIp(req);

  // Allow internal loopbacks
  if (WHITELISTED_IPS.has(clientIp)) {
    return next();
  }

  // --------------------------------------------------------------------------
  // AGENT 6: Digital Siberia (Instant Socket Drop for Already Blacklisted IPs)
  // --------------------------------------------------------------------------
  const subnet = getSubnet24(clientIp);
  if (_blacklistedIps.has(clientIp) || _blacklistedSubnets.has(subnet)) {
    console.warn(`🛑 [DigitalSiberia] Dropping socket for blacklisted entity: ${clientIp} (Subnet: ${subnet})`);
    if (req.socket && !req.socket.destroyed) {
      req.socket.destroy();
    }
    return;
  }

  const rawPath = req.path || req.url || '';
  const decodedPath = decodeURIComponent(rawPath).toLowerCase();
  const userAgent = (req.headers['user-agent'] || '').toString().toLowerCase();
  const authHeader = (req.headers['authorization'] || '').toString();

  // --------------------------------------------------------------------------
  // AGENT 7: Honeytoken Canary Check
  // --------------------------------------------------------------------------
  for (const token of _canaryTokens) {
    if (authHeader.includes(token) || rawPath.includes(token)) {
      console.warn(`🚨 [CanaryTriggered] HONEYTOKEN BREACHED by IP: ${clientIp}`);
      _blacklistedIps.add(clientIp);
      await logSecurityThreat(clientIp, {
        trigger: 'CANARY_HONEYTOKEN_ACTIVATED',
        path: rawPath,
        actionTaken: 'PERMANENT_IP_BLACK_LIST',
        timestamp: new Date().toISOString()
      });
      return renderCybercrimeDossier(res, {
        ip: clientIp,
        userAgent,
        path: rawPath,
        trigger: 'CANARY HONEYTOKEN TRAP ACTIVATED',
        payloadSnippet: 'Canary key deployed to entrap malicious reconnaissance.',
        timestamp: new Date().toISOString()
      });
    }
  }

  // Decoy Canary Endpoints
  if (rawPath === '/api/v1/system/master-secret' || rawPath === '/backup/db_credentials.json' || rawPath === '/config/admin_keys.env') {
    console.warn(`🪤 [CanaryDecoy] Attacker probe lured to honeypot decoy: ${rawPath} from ${clientIp}`);
    return res.status(200).json({
      status: true,
      message: 'Internal System Vault (Confidential)',
      PAYSTACK_SECRET_KEY: 'sk_canary_honeytoken_trap_90192837498172',
      DB_HOST: '10.0.0.12',
      CANARY_REF: 'HONEYTOKEN_CANARY_ACTIVE'
    });
  }

  // --------------------------------------------------------------------------
  // AGENT 1 & AGENT 8: Malicious Path, Exploit File, Scanner UA, & Injection Checks
  // --------------------------------------------------------------------------
  let isMalicious = false;
  let triggerReason = '';
  let payloadSnippet = '';

  // Check 1: Malicious paths (.env, .git, wp-admin, etc.)
  for (const pattern of MALICIOUS_PATH_PATTERNS) {
    if (pattern.test(decodedPath)) {
      isMalicious = true;
      triggerReason = `Exploit file/admin path probe [${pattern.source}]`;
      payloadSnippet = rawPath;
      break;
    }
  }

  // Check 2: Path Traversal (../)
  if (!isMalicious && PATH_TRAVERSAL_REGEX.test(decodedPath)) {
    isMalicious = true;
    triggerReason = 'Directory path traversal attempt (../)';
    payloadSnippet = rawPath;
  }

  // Check 3: Scanner User-Agents
  if (!isMalicious) {
    for (const scanner of SCANNER_USER_AGENTS) {
      if (userAgent.includes(scanner)) {
        isMalicious = true;
        triggerReason = `Automated vulnerability scanner signature [${scanner}]`;
        payloadSnippet = userAgent;
        break;
      }
    }
  }

  // Check 4: Query and Body Injection Payloads (SQLi, Command Injection)
  if (!isMalicious) {
    const rawQuery = JSON.stringify(req.query || {});
    const rawBody = typeof req.body === 'object' ? JSON.stringify(req.body) : String(req.body || '');
    if (INJECTION_PAYLOAD_REGEX.test(rawQuery) || INJECTION_PAYLOAD_REGEX.test(rawBody)) {
      isMalicious = true;
      triggerReason = 'SQL/Command injection signature detected';
      payloadSnippet = (rawQuery.length > 200 ? rawQuery.slice(0, 200) : rawQuery) || (rawBody.length > 200 ? rawBody.slice(0, 200) : rawBody);
    }
  }

  // If clean, proceed to normal application routes
  if (!isMalicious) {
    return next();
  }

  // ==========================================================================
  // PUNISHMENT EXECUTION PIPELINE
  // ==========================================================================
  console.warn(`🚨 [IntrusionIntercepted] ${triggerReason} from IP: ${clientIp} | Path: ${rawPath}`);

  // 1. Blacklist the IP permanently
  _blacklistedIps.add(clientIp);

  // 2. Track subnet frequency (Agent 8)
  const subData = _subnetHitCounter.get(subnet) || { count: 0, firstHit: Date.now() };
  subData.count++;
  if (subData.count >= 3 && Date.now() - subData.firstHit < 300000) {
    _blacklistedSubnets.add(subnet);
    console.warn(`🛡️ [SubnetQuarantine] Subnet ${subnet}.0/24 auto-quarantined due to repeat attacks!`);
  }
  _subnetHitCounter.set(subnet, subData);

  // 3. Persist IP ban in Supabase
  if (supabase) {
    supabase.from('system_configs').upsert({
      id: `ban_ip_${clientIp}`,
      data: {
        ip: clientIp,
        subnet,
        trigger: triggerReason,
        bannedAt: new Date().toISOString()
      }
    }).then(() => {}).catch(() => {});
  }

  // 4. Freeze Account if caller has user context (Agent 4 & 5)
  const callerUser = (req as any).user?.email || req.body?.email || req.query?.email || req.body?.userId;
  if (callerUser) {
    executeAccountPunishment(callerUser, clientIp, triggerReason);
  }

  // 5. Log Security Threat Ledger (Agent 9)
  logSecurityThreat(clientIp, {
    trigger: triggerReason,
    path: rawPath,
    userAgent,
    payloadSnippet,
    actionTaken: 'IP_BANNED_DOSSIER_SERVED',
    timestamp: new Date().toISOString()
  });

  // 6. Deliver Punishment: Tarpit for automated tools OR Dossier for browsers
  const isAutomatedTool = (
    userAgent.includes('curl') ||
    userAgent.includes('python') ||
    userAgent.includes('wget') ||
    userAgent.includes('scanner') ||
    userAgent.includes('sqlmap') ||
    userAgent.includes('go-http-client') ||
    userAgent.includes('java') ||
    !userAgent.includes('mozilla')
  );

  if (isAutomatedTool) {
    return runTarpit(res, clientIp, triggerReason);
  }

  // Browser-based intruder: Render the Cybercrime Dossier screen
  return renderCybercrimeDossier(res, {
    ip: clientIp,
    userAgent,
    path: rawPath,
    trigger: triggerReason,
    payloadSnippet: payloadSnippet || rawPath,
    timestamp: new Date().toISOString()
  });
}
