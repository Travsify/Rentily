import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';

function escapeHtml(unsafe: string): string {
  if (!unsafe) return '';
  return String(unsafe)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function formatNaira(amount: number): string {
  return Number(amount || 0).toLocaleString('en-NG');
}

export async function renderPublicRoommatePost(req: Request, res: Response) {
  const rawId = String(req.params.id || req.query.id || '').trim();

  let post: any = null;

  if (supabase) {
    try {
      const { data, error } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', 'global_roommate_posts')
        .single();

      if (!error && data?.data && Array.isArray(data.data) && data.data.length > 0) {
        const posts = data.data;
        if (rawId) {
          post = posts.find((p: any) => {
            const pId = String(p.id || '').trim().toLowerCase();
            const qId = rawId.toLowerCase();
            return pId === qId || pId === `room_${qId}` || pId.replace(/^room_/i, '') === qId.replace(/^room_/i, '');
          });
        }
        // If visiting /roommates without an ID or if exact post was fulfilled, feature the latest verified post
        if (!post && posts.length > 0) {
          post = posts[0];
        }
      }
    } catch (e: any) {
      console.error('[PublicRoommates] Supabase fetch error:', e.message);
    }
  }

  if (!post) {
    return res.status(200).send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Co-Living Request Not Found — Rentilly</title>
        <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { background: #090d16; color: #f8fafc; font-family: 'Plus Jakarta Sans', sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 24px; text-align: center; }
          .card { background: #0f172a; border: 1px solid #1e293b; border-radius: 20px; padding: 40px 24px; max-width: 480px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.4); }
          .badge { display: inline-block; background: rgba(239, 68, 68, 0.15); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 30px; font-size: 12px; font-weight: 700; padding: 6px 14px; margin-bottom: 20px; }
          h1 { font-size: 22px; font-weight: 800; margin-bottom: 12px; color: #ffffff; }
          p { color: #94a3b8; font-size: 14px; line-height: 1.6; margin-bottom: 28px; }
          .btn { display: inline-block; background: #10b981; color: #022c22; font-weight: 700; text-decoration: none; padding: 14px 28px; border-radius: 12px; font-size: 15px; transition: transform 0.2s, background 0.2s; }
          .btn:hover { background: #059669; transform: translateY(-2px); }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="badge">Listing Closed or Expired</div>
          <h1>Co-Living Request Not Found</h1>
          <p>This roommate post may have already been matched or fulfilled through Rentilly Escrow. Download Rentilly to explore hundreds of verified roommates and serviced flats across Nigeria.</p>
          <a href="https://api.myrentilly.com/Rentily.apk" class="btn">Download Rentilly App (APK)</a>
        </div>
      </body>
      </html>
    `);
  }

  const userName = escapeHtml(post.userName || 'Verified Rentilly User');
  const bedroomType = escapeHtml(post.bedroomType || 'Serviced Apartment');
  const location = escapeHtml(post.location || post.state || 'Nigeria');
  const budgetShare = Number(post.budgetShare || 0);
  const totalRent = Number(post.totalRent || 0);
  const splitCount = Number(post.splitCount || 2);
  const splitPercentage = Number(post.splitPercentage || Math.round(100 / (splitCount || 2)));
  const aboutMe = escapeHtml(post.aboutMe || 'Looking for a responsible, verified flatmate to split our lease through Rentilly Escrow.');
  const moveIn = escapeHtml(post.moveInTimeline || 'Immediate');
  const genderPref = escapeHtml(post.genderPreference || 'Any Gender');
  const occupation = escapeHtml(post.userOccupation || 'Professional');
  const lifestyleTags: string[] = Array.isArray(post.lifestyleTags) ? post.lifestyleTags : [];
  const imageUrl = (post.imageUrls && post.imageUrls.length > 0) ? post.imageUrls[0] : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800';

  const pageTitle = `${userName} is looking for a Flatmate in ${location} — Rentilly`;
  const pageDescription = `${bedroomType} in ${location} • ₦${formatNaira(budgetShare)}/yr per share (${splitCount}-person split). 0% Caution Fee with Rentilly Escrow Protection.`;
  const deepLink = `rentilly://roommates/${post.id}`;
  const directApkLink = 'https://api.myrentilly.com/Rentily.apk';

  const tagsHtml = lifestyleTags.map((tag: string) => `
    <span class="tag"># ${escapeHtml(tag)}</span>
  `).join('');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${pageTitle}</title>

  <!-- OpenGraph Metadata for WhatsApp, Facebook, LinkedIn, iMessage -->
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Rentilly Nigeria">
  <meta property="og:title" content="${pageTitle}">
  <meta property="og:description" content="${pageDescription}">
  <meta property="og:image" content="${imageUrl}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:url" content="https://api.myrentilly.com/roommates/${post.id}">

  <!-- Twitter Card Metadata -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${pageTitle}">
  <meta name="twitter:description" content="${pageDescription}">
  <meta name="twitter:image" content="${imageUrl}">

  <!-- Web & Mobile Identity -->
  <meta name="theme-color" content="#090d16">
  <link rel="icon" type="image/png" href="https://api.myrentilly.com/logo.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">

  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
    body {
      background: #090d16;
      color: #f8fafc;
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 16px;
    }
    .header-bar {
      width: 100%;
      max-width: 540px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 4px 20px 4px;
    }
    .logo-container {
      display: flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
    }
    .brand-icon {
      width: 38px;
      height: 38px;
      background: linear-gradient(135deg, #10b981, #059669);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 900;
      color: #ffffff;
      font-size: 20px;
      box-shadow: 0 4px 12px rgba(16, 185, 129, 0.35);
    }
    .brand-name {
      font-size: 20px;
      font-weight: 800;
      color: #ffffff;
      letter-spacing: -0.5px;
    }
    .brand-name span { color: #10b981; }
    .badge-escrow {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(16, 185, 129, 0.12);
      border: 1px solid rgba(16, 185, 129, 0.3);
      color: #10b981;
      padding: 6px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.3px;
    }
    .card {
      width: 100%;
      max-width: 540px;
      background: #0f172a;
      border: 1px solid #1e293b;
      border-radius: 24px;
      overflow: hidden;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
    }
    .image-wrapper {
      position: relative;
      width: 100%;
      height: 250px;
      background: #1e293b;
      overflow: hidden;
    }
    .image-wrapper img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .split-badge {
      position: absolute;
      top: 14px;
      left: 14px;
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(8px);
      padding: 6px 14px;
      border-radius: 12px;
      border: 1px solid rgba(255, 255, 255, 0.15);
      font-size: 12px;
      font-weight: 800;
      color: #f59e0b;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .verified-pill {
      position: absolute;
      bottom: 14px;
      right: 14px;
      background: #10b981;
      color: #022c22;
      padding: 4px 10px;
      border-radius: 8px;
      font-size: 11px;
      font-weight: 800;
      display: flex;
      align-items: center;
      gap: 4px;
      box-shadow: 0 4px 10px rgba(0,0,0,0.3);
    }
    .content-body {
      padding: 24px;
    }
    .author-row {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 18px;
    }
    .avatar {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      color: #ffffff;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      font-size: 17px;
      border: 2px solid #334155;
    }
    .author-info h3 {
      font-size: 16px;
      font-weight: 800;
      color: #ffffff;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .author-info p {
      font-size: 12px;
      color: #94a3b8;
      font-weight: 500;
    }
    .headline {
      font-size: 20px;
      font-weight: 800;
      color: #ffffff;
      line-height: 1.35;
      margin-bottom: 8px;
    }
    .location-text {
      display: flex;
      align-items: center;
      gap: 6px;
      color: #94a3b8;
      font-size: 14px;
      margin-bottom: 20px;
    }
    .price-box {
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 16px;
      padding: 16px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 20px;
    }
    .price-col small {
      display: block;
      color: #94a3b8;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
    }
    .price-col .amount {
      font-size: 22px;
      font-weight: 800;
      color: #10b981;
    }
    .price-col .sub {
      font-size: 12px;
      color: #64748b;
    }
    .total-col {
      text-align: right;
      border-left: 1px solid #334155;
      padding-left: 16px;
    }
    .total-col small {
      display: block;
      color: #94a3b8;
      font-size: 11px;
      font-weight: 600;
      margin-bottom: 4px;
    }
    .total-col .amount {
      font-size: 16px;
      font-weight: 700;
      color: #cbd5e1;
    }
    .details-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
      margin-bottom: 20px;
    }
    .detail-card {
      background: #182234;
      border: 1px solid #233148;
      border-radius: 12px;
      padding: 12px;
    }
    .detail-card .label {
      font-size: 11px;
      color: #64748b;
      font-weight: 600;
      margin-bottom: 3px;
    }
    .detail-card .val {
      font-size: 13px;
      color: #e2e8f0;
      font-weight: 700;
    }
    .about-box {
      background: #182234;
      border: 1px solid #233148;
      border-radius: 14px;
      padding: 16px;
      margin-bottom: 20px;
    }
    .about-box h4 {
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #94a3b8;
      font-weight: 700;
      margin-bottom: 8px;
    }
    .about-box p {
      font-size: 13px;
      line-height: 1.6;
      color: #cbd5e1;
    }
    .tags-container {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-bottom: 24px;
    }
    .tag {
      background: rgba(59, 130, 246, 0.12);
      border: 1px solid rgba(59, 130, 246, 0.25);
      color: #93c5fd;
      padding: 5px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 600;
    }
    .cta-stack {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .btn-primary {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      background: #10b981;
      color: #022c22;
      font-size: 15px;
      font-weight: 800;
      text-decoration: none;
      padding: 15px;
      border-radius: 14px;
      box-shadow: 0 10px 20px rgba(16, 185, 129, 0.25);
      transition: transform 0.15s, background 0.15s;
    }
    .btn-primary:active { transform: scale(0.98); }
    .btn-secondary {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      background: #1e293b;
      color: #f8fafc;
      font-size: 13px;
      font-weight: 700;
      text-decoration: none;
      padding: 13px;
      border-radius: 14px;
      border: 1px solid #334155;
    }
    .trust-footer {
      margin-top: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 16px;
      font-size: 11px;
      color: #64748b;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="header-bar">
    <div class="logo-container">
      <div class="brand-icon">R</div>
      <div class="brand-name">Rent<span>illy</span></div>
    </div>
    <div class="badge-escrow">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-3zm-2 16l-4-4 1.41-1.41L10 15.17l6.59-6.59L18 10l-8 8z"/></svg>
      0% Caution Fee
    </div>
  </div>

  <div class="card">
    <div class="image-wrapper">
      <img src="${imageUrl}" alt="${bedroomType}">
      <div class="split-badge">
        ⚡ ${splitCount}-Person Split (${splitPercentage}%)
      </div>
      <div class="verified-pill">
        ✓ Verified Post
      </div>
    </div>

    <div class="content-body">
      <div class="author-row">
        <div class="avatar">${post.userAvatar || userName.slice(0, 2).toUpperCase()}</div>
        <div class="author-info">
          <h3>${userName}</h3>
          <p>${occupation} • Verified Member</p>
        </div>
      </div>

      <div class="headline">${bedroomType} in ${location}</div>
      <div class="location-text">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="#94a3b8"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>
        ${location}
      </div>

      <div class="price-box">
        <div class="price-col">
          <small>Your Share (Annual)</small>
          <div class="amount">₦${formatNaira(budgetShare)}</div>
          <div class="sub">Per roommate / yr</div>
        </div>
        <div class="total-col">
          <small>Total Rent</small>
          <div class="amount">₦${formatNaira(totalRent)}</div>
        </div>
      </div>

      <div class="details-grid">
        <div class="detail-card">
          <div class="label">Move-In Timeline</div>
          <div class="val">${moveIn}</div>
        </div>
        <div class="detail-card">
          <div class="label">Roommate Preference</div>
          <div class="val">${genderPref}</div>
        </div>
      </div>

      <div class="about-box">
        <h4>About Flatmate & Apartment</h4>
        <p>${aboutMe}</p>
      </div>

      ${tagsHtml ? `<div class="tags-container">${tagsHtml}</div>` : ''}

      <div class="cta-stack">
        <a href="${deepLink}" class="btn-primary" id="openAppBtn">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.8 10-10S17.52 2 12 2zm-2 14.5v-9l6 4.5-6 4.5z"/></svg>
          Connect on Rentilly App
        </a>

        <a href="${directApkLink}" class="btn-secondary">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/></svg>
          Download Rentilly (Direct APK Update)
        </a>
      </div>

      <div class="trust-footer">
        <span>🔒 Escrow Protected</span>
        <span>•</span>
        <span>🛡️ 0% Caution Fee</span>
        <span>•</span>
        <span>⚡ Verified ID</span>
      </div>
    </div>
  </div>

  <script>
    document.getElementById('openAppBtn').addEventListener('click', function(e) {
      var now = Date.now();
      setTimeout(function() {
        if (Date.now() - now < 1500) {
          window.location.href = '${directApkLink}';
        }
      }, 800);
    });
  </script>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=60');
  return res.send(html);
}
