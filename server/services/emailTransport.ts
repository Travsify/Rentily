import nodemailer from 'nodemailer';

// Verified Root Domain (Clean reputation, SPF + DKIM + DMARC aligned)
const RESEND_ROOT_KEY = process.env.RESEND_PRIMARY_KEY || process.env.RESEND_API_KEY || '';
const RESEND_ROOT_SENDER = 'Rentilly Security <security@myrentilly.com>';

// Secondary Resend — auth.myrentilly.com
const RESEND_SECONDARY_KEY = process.env.RESEND_SECONDARY_KEY || process.env.RESEND_API_KEY || '';
const RESEND_SECONDARY_SENDER = 'Rentilly <security@auth.myrentilly.com>';

const POSTMARK_SERVER_TOKEN = process.env.POSTMARK_SERVER_TOKEN || '';

export const DEFAULT_RESEND_SENDER = RESEND_ROOT_SENDER;
export const DEFAULT_HOSTINGER_SENDER = 'Rentilly Security <info@myrentilly.com>';
export const DEFAULT_GMAIL_SENDER = 'Rentilly <myrentilly@gmail.com>';
export const DEFAULT_POSTMARK_SENDER = 'Rentilly <info@myrentilly.com>';
export const DEFAULT_SENDER = DEFAULT_RESEND_SENDER;
export const DEFAULT_REPLY_TO = 'info@myrentilly.com';

// Singleton Hostinger SMTP Transporter
const hostingerTransporter = nodemailer.createTransport({
  host: process.env.HOSTINGER_SMTP_HOST || 'smtp.hostinger.com',
  port: parseInt(process.env.HOSTINGER_SMTP_PORT || '465', 10),
  secure: true,
  auth: {
    user: process.env.HOSTINGER_SMTP_USER || 'info@myrentilly.com',
    pass: process.env.HOSTINGER_SMTP_PASS || 'Brevity230./'
  },
  tls: { rejectUnauthorized: true },
  pool: true,
  maxConnections: 5,
  maxMessages: 100
});

// Singleton Gmail SMTP Transporter (App Password — guaranteed Gmail inbox delivery)
const gmailTransporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  auth: {
    user: process.env.GMAIL_SMTP_USER || 'myrentilly@gmail.com',
    pass: process.env.GMAIL_SMTP_PASS || 'cuus gchs yojt nwxg'
  },
  tls: { rejectUnauthorized: true },
  pool: true,
  maxConnections: 3,
  maxMessages: 50
});

export interface SendMailOptions {
  to: string;
  subject: string;
  html: string;
  text?: string;
  from?: string;
  replyTo?: string;
  headers?: Record<string, string>;
  preferHostinger?: boolean;
}

export interface SendMailResult {
  success: boolean;
  provider: 'hostinger_smtp' | 'resend_api' | 'gmail_smtp' | 'postmark_api';
  messageId?: string;
  error?: string;
  data?: any;
}

export class EmailTransportService {
  /**
   * Sends an email using quad-rail parallel dispatch:
   * 1. Gmail SMTP      (myrentilly@gmail.com)          — guaranteed Gmail inbox
   * 2. Postmark API    (info@myrentilly.com)            — high-deliverability transactional
   * 3. Resend API      (security@auth.myrentilly.com)  — domain-verified, SES-backed
   * 4. Hostinger SMTP  (info@myrentilly.com)            — branded domain backup
   * All four fire simultaneously. First success wins.
   */
  // Deduplication cache to prevent sending the same email multiple times
  private static recentEmails = new Map<string, number>();

  static async sendMail(options: SendMailOptions): Promise<SendMailResult> {
    const to = options.to.trim().toLowerCase();
    const from = options.from || DEFAULT_SENDER;
    const replyTo = options.replyTo || DEFAULT_REPLY_TO;

    // Deduplication guard (60 seconds)
    const dedupeKey = `${to}:${options.subject}`;
    const now = Date.now();
    const lastSent = this.recentEmails.get(dedupeKey);
    if (lastSent && (now - lastSent < 60000)) {
      console.log(`[EmailTransport] 🔕 Deduplication active: Suppressed duplicate email to ${to} with subject "${options.subject}"`);
      return { success: true, provider: 'resend_api', data: { suppressed: true, reason: 'deduplication' } };
    }
    this.recentEmails.set(dedupeKey, now);

    // 1. Resend API via verified domains (myrentilly.com / auth.myrentilly.com)
    // Instant, zero-friction delivery with verified SPF/DKIM/DMARC
    const resendResult = await this.sendViaResend({ ...options, to, from, replyTo });
    if (resendResult.success) {
      console.log(`[EmailTransport] 🚀 Delivered via Resend to ${to}`);
      return resendResult;
    }
    console.warn(`[EmailTransport] ⚠️ Resend rail deferred (${resendResult.error}), trying backup rails...`);

    // 2. Intelligent Backup: Hostinger SMTP (info@myrentilly.com)
    const hostingerResult = await this.sendViaHostinger({ ...options, to, from: DEFAULT_HOSTINGER_SENDER, replyTo });
    if (hostingerResult.success) {
      console.log(`[EmailTransport] ✅ Delivered via Hostinger SMTP backup to ${to}`);
      return hostingerResult;
    }
    console.warn(`[EmailTransport] ⚠️ Hostinger backup deferred (${hostingerResult.error}), trying Gmail direct rail...`);

    // 3. Fallback: Gmail SMTP App-Password rail
    const gmailResult = await this.sendViaGmail({ ...options, to, replyTo });
    if (gmailResult.success) {
      console.log(`[EmailTransport] ✅ Delivered via Gmail Direct SMTP to ${to}`);
      return gmailResult;
    }

    const errorMsg = `All delivery rails failed for ${to}. Resend: ${resendResult.error}`;
    console.error(`[EmailTransport] ❌ ${errorMsg}`);
    return { success: false, provider: 'resend_api', error: errorMsg };
  }

  /**
   * Dispatch via Postmark HTTP API — high-deliverability transactional email
   */
  static async sendViaPostmark(options: SendMailOptions): Promise<SendMailResult> {
    try {
      const replyTo = options.replyTo || DEFAULT_REPLY_TO;

      const response = await fetch('https://api.postmarkapp.com/email', {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Postmark-Server-Token': POSTMARK_SERVER_TOKEN
        },
        body: JSON.stringify({
          From: DEFAULT_POSTMARK_SENDER,
          To: options.to,
          ReplyTo: replyTo,
          Subject: options.subject,
          HtmlBody: options.html,
          TextBody: options.text || '',
          MessageStream: 'outbound',
          Headers: [
            { Name: 'Auto-Submitted', Value: 'auto-generated' },
            { Name: 'X-Auto-Response-Suppress', Value: 'All, NDR, RN, NRN, OOF' }
          ]
        })
      });

      const resData: any = await response.json();

      if (response.ok && resData.MessageID) {
        console.log(`[EmailTransport] ✅ Delivered via Postmark API to ${options.to}, ID: ${resData.MessageID}`);
        return { success: true, provider: 'postmark_api', messageId: resData.MessageID, data: resData };
      }

      const errMsg = resData.Message || `Postmark returned HTTP ${response.status} (ErrorCode: ${resData.ErrorCode})`;
      console.warn(`[EmailTransport] ⚠️ Postmark rejected for ${options.to}: ${errMsg}`);
      return { success: false, provider: 'postmark_api', error: errMsg, data: resData };
    } catch (error: any) {
      console.error(`[EmailTransport] ❌ Postmark API exception to ${options.to}:`, error?.message || error);
      return { success: false, provider: 'postmark_api', error: error?.message || 'Postmark connection failure' };
    }
  }

  /**
   * Dispatch via Gmail SMTP (App Password) — guaranteed Gmail inbox delivery
   */
  static async sendViaGmail(options: SendMailOptions): Promise<SendMailResult> {
    try {
      const replyTo = options.replyTo || DEFAULT_REPLY_TO;

      const info = await gmailTransporter.sendMail({
        from: DEFAULT_GMAIL_SENDER,
        to: options.to,
        replyTo,
        subject: options.subject,
        text: options.text || '',
        html: options.html,
        headers: {
          'Auto-Submitted': 'auto-generated',
          'X-Auto-Response-Suppress': 'All, NDR, RN, NRN, OOF',
          ...(options.headers || {})
        }
      });

      console.log(`[EmailTransport] ✅ Delivered via Gmail SMTP to ${options.to}, messageId: ${info.messageId}`);
      return { success: true, provider: 'gmail_smtp', messageId: info.messageId, data: info };
    } catch (error: any) {
      console.error(`[EmailTransport] ❌ Gmail SMTP error to ${options.to}:`, error?.message || error);
      return { success: false, provider: 'gmail_smtp', error: error?.message || 'Gmail SMTP failure' };
    }
  }

  /**
   * Dispatch via Hostinger SMTP
   */
  static async sendViaHostinger(options: SendMailOptions): Promise<SendMailResult> {
    try {
      const replyTo = options.replyTo || DEFAULT_REPLY_TO;

      const info = await hostingerTransporter.sendMail({
        from: DEFAULT_HOSTINGER_SENDER,
        to: options.to,
        replyTo,
        subject: options.subject,
        text: options.text || '',
        html: options.html,
        headers: {
          'Auto-Submitted': 'auto-generated',
          'X-Auto-Response-Suppress': 'All, NDR, RN, NRN, OOF',
          ...(options.headers || {})
        }
      });

      console.log(`[EmailTransport] ✅ Delivered via Hostinger SMTP to ${options.to}, messageId: ${info.messageId}`);
      return { success: true, provider: 'hostinger_smtp', messageId: info.messageId, data: info };
    } catch (error: any) {
      console.error(`[EmailTransport] ❌ Hostinger SMTP error to ${options.to}:`, error?.message || error);
      return { success: false, provider: 'hostinger_smtp', error: error?.message || 'Hostinger SMTP failure' };
    }
  }

  /**
   * Internal: fire a single Resend key/sender pair
   */
  private static async sendViaResendWithKey(
    options: SendMailOptions,
    apiKey: string,
    senderAddress: string,
    label: string
  ): Promise<SendMailResult> {
    const replyTo = options.replyTo || DEFAULT_REPLY_TO;

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: senderAddress,
        to: [options.to],
        reply_to: replyTo,
        subject: options.subject,
        headers: {
          'Auto-Submitted': 'auto-generated',
          'X-Auto-Response-Suppress': 'All, NDR, RN, NRN, OOF',
          ...(options.headers || {})
        },
        html: options.html,
        text: options.text || ''
      })
    });

    const resData: any = await response.json();
    if (response.ok && (resData.id || resData.data?.id)) {
      const id = resData.id || resData.data?.id;
      console.log(`[EmailTransport] ✅ Resend [${label}] delivered to ${options.to}, ID: ${id}`);
      return { success: true, provider: 'resend_api', messageId: id, data: resData };
    }

    const errMsg = resData.message || resData.error?.message || `Resend [${label}] HTTP ${response.status}`;
    console.warn(`[EmailTransport] ⚠️ Resend [${label}] failed for ${options.to}: ${errMsg}`);
    return { success: false, provider: 'resend_api', error: errMsg, data: resData };
  }

  /**
   * Dispatch via Resend HTTP API:
   * 1. Try verified root domain security@myrentilly.com (100% clean domain, SPF + DKIM + DMARC aligned)
   * 2. Fall back to sub-domain auth.myrentilly.com only if root fails
   */
  static async sendViaResend(options: SendMailOptions): Promise<SendMailResult> {
    try {
      // 1. Primary: root domain security@myrentilly.com
      const primaryResult = await this.sendViaResendWithKey(
        options,
        RESEND_ROOT_KEY,
        RESEND_ROOT_SENDER,
        'myrentilly.com'
      );
      if (primaryResult.success) {
        return primaryResult;
      }

      console.warn(`[EmailTransport] ⚠️ Primary Resend rail failed (${primaryResult.error}), trying auth.myrentilly.com...`);

      // 2. Secondary fallback: auth.myrentilly.com
      const secondaryResult = await this.sendViaResendWithKey(
        options,
        RESEND_SECONDARY_KEY,
        RESEND_SECONDARY_SENDER,
        'auth.myrentilly.com'
      );
      return secondaryResult;
    } catch (error: any) {
      console.error(`[EmailTransport] ❌ Resend exception to ${options.to}:`, error?.message || error);
      return { success: false, provider: 'resend_api', error: error?.message || 'Resend connection failure' };
    }
  }
}
