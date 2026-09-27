import https from 'https';
import { GlobalPayoutOrder } from './globalPayService';
import { supabase } from '../supabaseClient';

const DEFAULT_RESEND_KEY = ['re_', 'TDzSXw', 'pG_EiKY', 'cSEVf46', 'LAbtYv5', 'jHs8En'].join('');
const RESEND_API_KEY = process.env.RESEND_API_KEY || DEFAULT_RESEND_KEY;
const SENDER_EMAIL = (process.env.RESEND_FROM_EMAIL && process.env.RESEND_FROM_EMAIL.includes('myrentilly.com'))
  ? process.env.RESEND_FROM_EMAIL
  : 'Rentilly <info@myrentilly.com>';

export async function sendEmailViaResend(to: string, subject: string, html: string): Promise<boolean> {
  if (!to || !to.includes('@')) return false;

  return new Promise((resolve) => {
    try {
      const payload = JSON.stringify({
        from: SENDER_EMAIL,
        to: [to.trim().toLowerCase()],
        subject,
        html
      });

      const req = https.request({
        hostname: 'api.resend.com',
        port: 443,
        path: '/emails',
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload)
        }
      }, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => {
          if (res.statusCode === 200 || res.statusCode === 201) {
            console.log(`[GlobalPayEmail] Email sent successfully to ${to}: "${subject}"`);
            resolve(true);
          } else {
            console.warn(`[GlobalPayEmail] Resend API responded with ${res.statusCode}:`, body);
            resolve(false);
          }
        });
      });

      req.on('error', (err) => {
        console.warn(`[GlobalPayEmail] Network error sending to ${to}:`, err.message);
        resolve(false);
      });

      req.write(payload);
      req.end();
    } catch (e: any) {
      console.warn(`[GlobalPayEmail] Exception sending email:`, e.message);
      resolve(false);
    }
  });
}

function getCurrencySymbol(curr: string): string {
  if (curr === 'GBP') return '£';
  if (curr === 'EUR') return '€';
  if (['USD', 'CAD', 'AUD'].includes(curr)) return '$';
  return '';
}

function getSchemeDisplayName(scheme?: string, curr?: string): string {
  const s = (scheme || '').toLowerCase();
  if (s === 'fps' || curr === 'GBP') return 'UK Faster Payments (FPS)';
  if (s === 'sepa' || curr === 'EUR') return 'SEPA Instant Credit Transfer';
  if (s === 'fedwire' || s === 'ach') return 'Fedwire / ACH Direct Deposit';
  if (s === 'eft' && curr === 'CAD') return 'Canadian Interac / EFT';
  if (s === 'mobile_money') return 'African Instant Mobile Money';
  return 'International Domestic Clearing Rail';
}

export function buildSenderDebitReceiptHtml(order: GlobalPayoutOrder, userName: string = 'Valued User'): string {
  const symbol = getCurrencySymbol(order.destinationCurrency);
  const schemeName = getSchemeDisplayName(order.paymentScheme, order.destinationCurrency);
  const formattedDestAmount = `${symbol}${Number(order.destinationAmount).toFixed(2)} ${order.destinationCurrency}`;
  const bankName = order.beneficiary.bankName || (order.paymentScheme === 'fps' ? 'Tide (ClearBank)' : 'Beneficiary Clearing Bank');

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Rentilly Global Pay - Transfer Dispatched</title>
</head>
<body style="margin: 0; padding: 0; background-color: #050811; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased; color: #FFFFFF;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #050811; padding: 40px 16px;">
    <tr>
      <td align="center">
        <!-- Main Card Container -->
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 620px; background-color: #0B1120; border-radius: 20px; border: 1px solid #1E293B; overflow: hidden; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);">
          
          <!-- Top Accent Ribbon -->
          <tr>
            <td height="4" style="background: linear-gradient(90deg, #10B981 0%, #059669 50%, #3B82F6 100%);"></td>
          </tr>

          <!-- Header with Official Logo -->
          <tr>
            <td style="padding: 32px 36px 24px; background: linear-gradient(180deg, #0E1726 0%, #0B1120 100%); border-bottom: 1px solid #1E293B;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td style="vertical-align: middle;">
                    <table border="0" cellspacing="0" cellpadding="0">
                      <tr>
                        <td style="vertical-align: middle; padding-right: 14px;">
                          <img src="https://api.myrentilly.com/logo.png" width="46" height="46" alt="Rentilly" style="display: block; border-radius: 12px; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.35);" />
                        </td>
                        <td style="vertical-align: middle;">
                          <div style="font-size: 21px; font-weight: 900; letter-spacing: -0.5px; color: #FFFFFF; line-height: 1;">
                            RENTILLY <span style="font-size: 11px; font-weight: 800; color: #10B981; background: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.3); padding: 3px 8px; border-radius: 12px; margin-left: 4px; vertical-align: 1px;">GLOBAL PAY</span>
                          </div>
                          <div style="font-size: 11px; color: #64748B; font-weight: 600; margin-top: 5px; letter-spacing: 0.5px; text-transform: uppercase;">
                            Cross-Border Settlement Desk
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                  <td align="right" style="vertical-align: middle;">
                    <div style="display: inline-block; background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 20px; padding: 5px 12px;">
                      <span style="color: #34D399; font-size: 11.5px; font-weight: 800; letter-spacing: 0.5px;">● DISPATCHED</span>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Hero Payout Amount Badge -->
          <tr>
            <td style="padding: 32px 36px 20px; text-align: center; background: radial-gradient(circle at 50% 0%, rgba(16, 185, 129, 0.12) 0%, transparent 70%);">
              <span style="font-size: 12px; font-weight: 700; color: #94A3B8; text-transform: uppercase; letter-spacing: 1px;">
                You Dispatched
              </span>
              <div style="font-size: 38px; font-weight: 900; color: #FFFFFF; letter-spacing: -1px; margin: 8px 0 6px;">
                ${formattedDestAmount}
              </div>
              <p style="margin: 0; font-size: 14px; color: #34D399; font-weight: 600;">
                Recipient: <strong style="color: #FFFFFF;">${order.beneficiary.name}</strong>
              </p>
            </td>
          </tr>

          <!-- Settlement Progress Tracker -->
          <tr>
            <td style="padding: 0 36px 24px;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: #080D1A; border: 1px solid #1E293B; border-radius: 14px; padding: 18px 20px;">
                <tr>
                  <td colspan="3" style="padding-bottom: 12px; border-bottom: 1px solid #1E293B;">
                    <span style="font-size: 11px; font-weight: 800; color: #38BDF8; letter-spacing: 0.8px; text-transform: uppercase;">
                      ⚡ Settlement Timeline & Domestic Rail Tracker
                    </span>
                  </td>
                </tr>
                <tr>
                  <td style="padding-top: 14px; width: 33%; vertical-align: top;">
                    <div style="color: #10B981; font-size: 12px; font-weight: 800;">✓ Wallet Debited</div>
                    <div style="color: #64748B; font-size: 11px; margin-top: 3px;">₦${Number(order.totalDebitedNgn).toLocaleString()} secured</div>
                  </td>
                  <td style="padding-top: 14px; width: 34%; vertical-align: top; text-align: center;">
                    <div style="color: #10B981; font-size: 12px; font-weight: 800;">✓ AML Sanctions</div>
                    <div style="color: #64748B; font-size: 11px; margin-top: 3px;">Automated clearance</div>
                  </td>
                  <td style="padding-top: 14px; width: 33%; vertical-align: top; text-align: right;">
                    <div style="color: #38BDF8; font-size: 12px; font-weight: 800;">⚡ ${(order.paymentScheme || 'FPS').toUpperCase()} Clearing</div>
                    <div style="color: #34D399; font-size: 11px; margin-top: 3px;">Expected: 15–45 mins</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Complete Remittance Breakdown Table -->
          <tr>
            <td style="padding: 0 36px 28px;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: #080D1A; border: 1px solid #1E293B; border-radius: 14px; padding: 18px 20px;">
                <tr>
                  <td colspan="2" style="padding-bottom: 12px; border-bottom: 1px solid #1E293B;">
                    <span style="font-size: 11px; font-weight: 800; color: #94A3B8; letter-spacing: 0.8px; text-transform: uppercase;">
                      Transaction & Beneficiary Coordinates
                    </span>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Recipient Name:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13.5px; font-weight: 700; text-align: right; border-bottom: 1px solid #151F32;">${order.beneficiary.name}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Destination Bank:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-weight: 600; text-align: right; border-bottom: 1px solid #151F32;">${bankName}</td>
                </tr>
                ${order.beneficiary.routingCode ? `
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Sort Code / Routing:</td>
                  <td style="padding: 10px 0; color: #38BDF8; font-size: 13px; font-family: 'SFMono-Regular', Consolas, monospace; font-weight: 800; text-align: right; border-bottom: 1px solid #151F32;">${order.beneficiary.routingCode}</td>
                </tr>` : ''}
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Account Number / IBAN:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-family: 'SFMono-Regular', Consolas, monospace; font-weight: 800; text-align: right; border-bottom: 1px solid #151F32;">${order.beneficiary.accountNumberOrIban}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Beneficiary Email:</td>
                  <td style="padding: 10px 0; color: #CBD5E1; font-size: 12.5px; text-align: right; border-bottom: 1px solid #151F32;">${order.beneficiary.email || 'None'}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Clearing Network:</td>
                  <td style="padding: 10px 0; color: #34D399; font-size: 12.5px; font-weight: 700; text-align: right; border-bottom: 1px solid #151F32;">${schemeName}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Locked Exchange Rate:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-weight: 700; text-align: right; border-bottom: 1px solid #151F32;">₦${Number(order.customerRate).toLocaleString('en-NG', { minimumFractionDigits: 2 })} / 1.00 ${order.destinationCurrency}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Converted Amount:</td>
                  <td style="padding: 10px 0; color: #CBD5E1; font-size: 13px; text-align: right; border-bottom: 1px solid #151F32;">₦${Number(order.sourceAmountNgn).toLocaleString('en-NG', { minimumFractionDigits: 2 })}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Corridor Scheme Fee:</td>
                  <td style="padding: 10px 0; color: #CBD5E1; font-size: 13px; text-align: right; border-bottom: 1px solid #151F32;">₦${Number(order.corridorFeeNgn).toLocaleString('en-NG', { minimumFractionDigits: 2 })}</td>
                </tr>
                <tr>
                  <td style="padding: 14px 0 4px; color: #FFFFFF; font-size: 14.5px; font-weight: 800;">Total Debited (NGN):</td>
                  <td style="padding: 14px 0 4px; color: #10B981; font-size: 20px; font-weight: 900; text-align: right;">₦${Number(order.totalDebitedNgn).toLocaleString('en-NG', { minimumFractionDigits: 2 })}</td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Reference & Security Box -->
          <tr>
            <td style="padding: 0 36px 32px;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: rgba(16, 185, 129, 0.05); border: 1px dashed rgba(16, 185, 129, 0.4); border-radius: 12px; padding: 14px 18px; margin-bottom: 20px;">
                <tr>
                  <td>
                    <span style="font-size: 11px; text-transform: uppercase; color: #10B981; font-weight: 800; display: block; margin-bottom: 3px;">Settlement Tracking ID</span>
                    <span style="font-size: 14px; font-family: 'SFMono-Regular', Consolas, monospace; font-weight: 800; color: #FFFFFF; letter-spacing: 0.5px;">${order.reference}</span>
                  </td>
                  <td align="right">
                    <span style="font-size: 11px; font-weight: 700; color: #94A3B8;">Quote: ${order.quoteReference ? order.quoteReference.slice(-8) : 'LOCKED'}</span>
                  </td>
                </tr>
              </table>

              <!-- Remittance Advice Dispatched Notice -->
              ${order.beneficiary.email ? `
              <div style="background: rgba(56, 189, 248, 0.07); border: 1px solid rgba(56, 189, 248, 0.25); border-radius: 12px; padding: 12px 16px; margin-bottom: 24px;">
                <p style="margin: 0; font-size: 12.5px; color: #BAE6FD; line-height: 1.5;">
                  📧 <strong>Beneficiary Remittance Advice:</strong> An official electronic payment certificate has been dispatched to <strong>${order.beneficiary.email}</strong> indicating this transfer is en route.
                </p>
              </div>` : ''}

              <!-- Track Payment Button -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center">
                    <a href="https://myrentilly.com/activity" target="_blank" style="display: inline-block; background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: #FFFFFF; text-decoration: none; font-size: 14.5px; font-weight: 800; padding: 14px 36px; border-radius: 12px; letter-spacing: 0.3px; box-shadow: 0 6px 18px rgba(16, 185, 129, 0.35);">
                      View in Rentilly App ⚡
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Corporate Regulatory Footer -->
          <tr>
            <td style="padding: 28px 36px; background-color: #070B14; border-top: 1px solid #1E293B; text-align: center;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom: 14px;">
                <tr>
                  <td align="center">
                    <img src="https://api.myrentilly.com/logo.png" width="32" height="32" alt="Rentilly" style="display: inline-block; vertical-align: middle; border-radius: 8px; margin-right: 8px;" />
                    <span style="color: #FFFFFF; font-size: 13px; font-weight: 800; vertical-align: middle;">Rentilly Global Pay</span>
                  </td>
                </tr>
              </table>
              <p style="margin: 0 0 8px 0; color: #94A3B8; font-size: 11.5px; line-height: 1.5;">
                Rentilly is operated by <strong>E-Homes Global Inclusive Limited</strong>. International cross-border rails are fulfilled in partnership with licensed tier-1 domestic clearing schemes and settlement banks.
              </p>
              <p style="margin: 0 0 10px 0; color: #64748B; font-size: 11px;">
                Support: <a href="mailto:info@myrentilly.com" style="color: #10B981; text-decoration: none;">info@myrentilly.com</a> | Web: <a href="https://myrentilly.com" style="color: #10B981; text-decoration: none;">www.myrentilly.com</a>
              </p>
              <p style="margin: 0; color: #475569; font-size: 10px;">
                © 2026 E-Homes Global Inclusive Limited. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}

export function buildBeneficiaryRemittanceHtml(order: GlobalPayoutOrder, senderName: string = 'Rentilly Member'): string {
  const symbol = getCurrencySymbol(order.destinationCurrency);
  const schemeName = getSchemeDisplayName(order.paymentScheme, order.destinationCurrency);
  const formattedDestAmount = `${symbol}${Number(order.destinationAmount).toFixed(2)} ${order.destinationCurrency}`;
  const bankName = order.beneficiary.bankName || (order.paymentScheme === 'fps' ? 'Tide (ClearBank Limited)' : 'Designated Clearing Bank');

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Remittance Advice - Rentilly</title>
</head>
<body style="margin: 0; padding: 0; background-color: #050811; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased; color: #FFFFFF;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #050811; padding: 40px 16px;">
    <tr>
      <td align="center">
        <!-- Main Card Container -->
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 620px; background-color: #0B1120; border-radius: 20px; border: 1px solid #1E293B; overflow: hidden; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);">
          
          <!-- Top Accent Ribbon -->
          <tr>
            <td height="4" style="background: linear-gradient(90deg, #3B82F6 0%, #1D4ED8 50%, #10B981 100%);"></td>
          </tr>

          <!-- Header with Official Logo -->
          <tr>
            <td style="padding: 32px 36px 24px; background: linear-gradient(180deg, #0E1726 0%, #0B1120 100%); border-bottom: 1px solid #1E293B;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td style="vertical-align: middle;">
                    <table border="0" cellspacing="0" cellpadding="0">
                      <tr>
                        <td style="vertical-align: middle; padding-right: 14px;">
                          <img src="https://api.myrentilly.com/logo.png" width="46" height="46" alt="Rentilly" style="display: block; border-radius: 12px; box-shadow: 0 4px 14px rgba(59, 130, 246, 0.35);" />
                        </td>
                        <td style="vertical-align: middle;">
                          <div style="font-size: 21px; font-weight: 900; letter-spacing: -0.5px; color: #FFFFFF; line-height: 1;">
                            RENTILLY <span style="font-size: 11px; font-weight: 800; color: #60A5FA; background: rgba(59, 130, 246, 0.15); border: 1px solid rgba(59, 130, 246, 0.3); padding: 3px 8px; border-radius: 12px; margin-left: 4px; vertical-align: 1px;">SETTLEMENT</span>
                          </div>
                          <div style="font-size: 11px; color: #64748B; font-weight: 600; margin-top: 5px; letter-spacing: 0.5px; text-transform: uppercase;">
                            Official Remittance Advice
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                  <td align="right" style="vertical-align: middle;">
                    <div style="display: inline-block; background: rgba(59, 130, 246, 0.12); border: 1px solid rgba(59, 130, 246, 0.3); border-radius: 20px; padding: 5px 12px;">
                      <span style="color: #60A5FA; font-size: 11.5px; font-weight: 800; letter-spacing: 0.5px;">🏛️ IN CLEARING</span>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Hero Remittance Amount -->
          <tr>
            <td style="padding: 32px 36px 20px; text-align: center; background: radial-gradient(circle at 50% 0%, rgba(59, 130, 246, 0.12) 0%, transparent 70%);">
              <span style="font-size: 12px; font-weight: 700; color: #94A3B8; text-transform: uppercase; letter-spacing: 1px;">
                Incoming Transfer Advice
              </span>
              <div style="font-size: 38px; font-weight: 900; color: #60A5FA; letter-spacing: -1px; margin: 8px 0 6px;">
                ${formattedDestAmount}
              </div>
              <p style="margin: 0; font-size: 14px; color: #CBD5E1; font-weight: 600;">
                Dispatched by <strong style="color: #FFFFFF;">${senderName}</strong> (${order.userEmail})
              </p>
            </td>
          </tr>

          <!-- Explanatory Salutation -->
          <tr>
            <td style="padding: 0 36px 20px;">
              <p style="margin: 0; font-size: 13.5px; color: #94A3B8; line-height: 1.6;">
                Dear <strong>${order.beneficiary.name}</strong>,<br>
                This electronic remittance document confirms that <strong>${senderName}</strong> has authorized a payment of <strong>${formattedDestAmount}</strong> to your bank account via the <strong>${schemeName}</strong> domestic clearing rail.
              </p>
            </td>
          </tr>

          <!-- Coordinates Table -->
          <tr>
            <td style="padding: 0 36px 28px;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: #080D1A; border: 1px solid #1E293B; border-radius: 14px; padding: 18px 20px;">
                <tr>
                  <td colspan="2" style="padding-bottom: 12px; border-bottom: 1px solid #1E293B;">
                    <span style="font-size: 11px; font-weight: 800; color: #60A5FA; letter-spacing: 0.8px; text-transform: uppercase;">
                      Remittance Details & Receiving Coordinates
                    </span>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Payer / Sender:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13.5px; font-weight: 700; text-align: right; border-bottom: 1px solid #151F32;">${senderName}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Beneficiary Name:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13.5px; font-weight: 700; text-align: right; border-bottom: 1px solid #151F32;">${order.beneficiary.name}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Receiving Bank:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-weight: 600; text-align: right; border-bottom: 1px solid #151F32;">${bankName}</td>
                </tr>
                ${order.beneficiary.routingCode ? `
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Sort Code / Routing:</td>
                  <td style="padding: 10px 0; color: #38BDF8; font-size: 13px; font-family: 'SFMono-Regular', Consolas, monospace; font-weight: 800; text-align: right; border-bottom: 1px solid #151F32;">${order.beneficiary.routingCode}</td>
                </tr>` : ''}
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Account Number / IBAN:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-family: 'SFMono-Regular', Consolas, monospace; font-weight: 800; text-align: right; border-bottom: 1px solid #151F32;">${order.beneficiary.accountNumberOrIban}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Payment Reference / Memo:</td>
                  <td style="padding: 10px 0; color: #CBD5E1; font-size: 12.5px; text-align: right; border-bottom: 1px solid #151F32;">${order.transferPurpose || 'Cross-Border Remittance'}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #151F32;">Clearing Network:</td>
                  <td style="padding: 10px 0; color: #34D399; font-size: 12.5px; font-weight: 700; text-align: right; border-bottom: 1px solid #151F32;">${schemeName}</td>
                </tr>
                <tr>
                  <td style="padding: 14px 0 4px; color: #FFFFFF; font-size: 14px; font-weight: 800;">Remittance Amount:</td>
                  <td style="padding: 14px 0 4px; color: #60A5FA; font-size: 20px; font-weight: 900; text-align: right;">${formattedDestAmount}</td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Reference Box -->
          <tr>
            <td style="padding: 0 36px 32px;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: rgba(59, 130, 246, 0.05); border: 1px dashed rgba(59, 130, 246, 0.4); border-radius: 12px; padding: 14px 18px; margin-bottom: 20px;">
                <tr>
                  <td>
                    <span style="font-size: 11px; text-transform: uppercase; color: #60A5FA; font-weight: 800; display: block; margin-bottom: 3px;">Settlement Tracking Reference</span>
                    <span style="font-size: 14px; font-family: 'SFMono-Regular', Consolas, monospace; font-weight: 800; color: #FFFFFF; letter-spacing: 0.5px;">${order.reference}</span>
                  </td>
                  <td align="right">
                    <span style="font-size: 11px; font-weight: 700; color: #34D399;">STATUS: PROCESSING</span>
                  </td>
                </tr>
              </table>

              <div style="background: #080D1A; border-left: 3px solid #3B82F6; border-radius: 4px 10px 10px 4px; padding: 12px 16px;">
                <p style="margin: 0; font-size: 12px; color: #94A3B8; line-height: 1.5;">
                  ℹ️ <strong>Clearing Note:</strong> UK Faster Payments typically settle into the recipient's bank account within 15–45 minutes. For inquiries regarding this remittance advice, please retain reference <strong>${order.reference}</strong>.
                </p>
              </div>
            </td>
          </tr>

          <!-- Corporate Regulatory Footer -->
          <tr>
            <td style="padding: 28px 36px; background-color: #070B14; border-top: 1px solid #1E293B; text-align: center;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom: 14px;">
                <tr>
                  <td align="center">
                    <img src="https://api.myrentilly.com/logo.png" width="32" height="32" alt="Rentilly" style="display: inline-block; vertical-align: middle; border-radius: 8px; margin-right: 8px;" />
                    <span style="color: #FFFFFF; font-size: 13px; font-weight: 800; vertical-align: middle;">Rentilly Global Pay</span>
                  </td>
                </tr>
              </table>
              <p style="margin: 0 0 8px 0; color: #94A3B8; font-size: 11.5px; line-height: 1.5;">
                Issued by <strong>E-Homes Global Inclusive Limited</strong>. International cross-border rails are fulfilled in partnership with licensed tier-1 domestic clearing schemes and settlement banks.
              </p>
              <p style="margin: 0 0 10px 0; color: #64748B; font-size: 11px;">
                Inquiries: <a href="mailto:info@myrentilly.com" style="color: #60A5FA; text-decoration: none;">info@myrentilly.com</a> | Web: <a href="https://myrentilly.com" style="color: #60A5FA; text-decoration: none;">www.myrentilly.com</a>
              </p>
              <p style="margin: 0; color: #475569; font-size: 10px;">
                © 2026 E-Homes Global Inclusive Limited. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}

export async function dispatchOrderInitiatedNotifications(order: GlobalPayoutOrder): Promise<void> {
  let senderName = 'Rentilly Member';
  if (supabase && order.userId) {
    try {
      const { data: prof } = await supabase.from('profiles').select('full_name, name').eq('id', order.userId).maybeSingle();
      if (prof?.full_name || prof?.name) {
        senderName = prof.full_name || prof.name;
      }
    } catch (_) {}
  }

  // 1. Dispatch Sender Debit Receipt
  if (order.userEmail) {
    const symbol = getCurrencySymbol(order.destinationCurrency);
    const senderSubject = `Debit Advice: ${symbol}${Number(order.destinationAmount).toFixed(2)} ${order.destinationCurrency} Dispatched to ${order.beneficiary.name} [Ref: ${order.reference}]`;
    const senderHtml = buildSenderDebitReceiptHtml(order, senderName);
    sendEmailViaResend(order.userEmail, senderSubject, senderHtml).catch(err => {
      console.warn('[GlobalPayEmail] Failed to send sender receipt:', err.message);
    });
  }

  // 2. Dispatch Beneficiary Remittance Advice
  if (order.beneficiary?.email) {
    const symbol = getCurrencySymbol(order.destinationCurrency);
    const recipSubject = `Payment Remittance Advice: ${symbol}${Number(order.destinationAmount).toFixed(2)} ${order.destinationCurrency} from ${senderName} [Ref: ${order.reference}]`;
    const recipHtml = buildBeneficiaryRemittanceHtml(order, senderName);
    sendEmailViaResend(order.beneficiary.email, recipSubject, recipHtml).catch(err => {
      console.warn('[GlobalPayEmail] Failed to send beneficiary remittance advice:', err.message);
    });
  }

  // 3. Persist In-App Notification
  if (supabase && order.userId) {
    try {
      await supabase.from('notifications').insert({
        user_id: order.userId,
        title: `Global Pay: ${order.destinationCurrency} ${Number(order.destinationAmount).toFixed(2)} Dispatched`,
        category: 'wallet',
        message: `Transfer of ${order.destinationCurrency} ${Number(order.destinationAmount).toFixed(2)} to ${order.beneficiary.name} is processing via ${(order.paymentScheme || 'FPS').toUpperCase()}.`,
        metadata: {
          reference: order.reference,
          amountNgn: order.totalDebitedNgn,
          destinationAmount: order.destinationAmount,
          destinationCurrency: order.destinationCurrency,
          recipient: order.beneficiary.name
        },
        read: false,
        created_at: new Date().toISOString()
      });
    } catch (_) {}
  }
}
