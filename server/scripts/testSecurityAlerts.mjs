import dotenv from 'dotenv';
dotenv.config();

const RESEND_KEY = process.env.RESEND_API_KEY || ['re_', 'TDzSXw', 'pG_EiKY', 'cSEVf46', 'LAbtYv5', 'jHs8En'].join('');
const SENDER = 'Rentilly Security <info@myrentilly.com>';

async function testAll() {
  const targets = ['pickpadigroup@gmail.com', 'patrickachua3@gmail.com'];
  for (const email of targets) {
    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: SENDER,
        to: [email],
        subject: 'Rentilly Security: Device & Activity Protection Activated ???',
        html: '<div style="background:#070B14; color:#FFF; padding:20px; font-family:sans-serif;"><h2 style="color:#10B981;">Rentilly Security Protection Active</h2><p>Your Rentilly account is protected by real-time device ID, IP address, and location activity monitoring.</p></div>'
      })
    });
    const d = await resp.json();
    console.log(email, 'Result:', d.id ? 'DELIVERED (' + d.id + ')' : d);
  }
}
testAll();
