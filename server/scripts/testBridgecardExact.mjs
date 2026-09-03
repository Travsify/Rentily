import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

const appId = process.env.BRIDGECARD_ISSUING_APP_ID;
const secretKey = process.env.BRIDGECARD_SECRET_KEY;

console.log('App ID:', appId);
console.log('Secret key length:', secretKey?.length);

async function testExact() {
  const endpoints = [
    { name: 'Check Cardholder Register Endpt (Sandbox)', url: 'https://issuecards.api.bridgecard.co/v1/issuing/sandbox/cardholder/register_cardholder_synchronously' },
    { name: 'Check Cardholder Register Endpt (Live)', url: 'https://issuecards.api.bridgecard.co/v1/issuing/cardholder/register_cardholder_synchronously' },
    { name: 'Check Create Card (Sandbox)', url: 'https://issuecards.api.bridgecard.co/v1/issuing/sandbox/cards/create_card' },
    { name: 'Check Create Card (Live)', url: 'https://issuecards.api.bridgecard.co/v1/issuing/cards/create_card' },
  ];

  for (const ep of endpoints) {
    try {
      const res = await fetch(ep.url, {
        method: 'POST',
        headers: {
          'token': 'Bearer ' + secretKey,
          'issue_app_id': appId || '',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ test: true })
      });
      const data = await res.text();
      console.log(`[${res.status}] ${ep.name} ->`, data);
    } catch (e) {
      console.error(ep.name, e.message);
    }
  }
}

testExact();
