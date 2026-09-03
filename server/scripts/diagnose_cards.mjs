import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

console.log('=== DIAGNOSING BRIDGECARD AND MAPLERAD CARDS ===\n');

async function testBridgecard() {
  console.log('--- 1. Testing Bridgecard API ---');
  const appId = process.env.BRIDGECARD_ISSUING_APP_ID;
  const secretKey = process.env.BRIDGECARD_SECRET_KEY;
  console.log('App ID:', appId);
  console.log('Secret Key starts with:', secretKey ? secretKey.substring(0, 15) : 'MISSING');

  const testEndpoints = [
    { name: 'Live Balance', url: 'https://issuecards.api.bridgecard.co/v1/issuing/wallet/balance', method: 'GET' },
    { name: 'Live Cards', url: 'https://issuecards.api.bridgecard.co/v1/issuing/cards', method: 'GET' },
    { name: 'Sandbox Balance', url: 'https://issuecards.api.bridgecard.co/v1/issuing/sandbox/wallet/balance', method: 'GET' },
    { name: 'Cardholders', url: 'https://issuecards.api.bridgecard.co/v1/issuing/cardholder', method: 'GET' }
  ];

  for (const ep of testEndpoints) {
    try {
      const res = await fetch(ep.url, {
        method: ep.method,
        headers: {
          'token': 'Bearer ' + secretKey,
          'issue_app_id': appId || '',
          'Content-Type': 'application/json'
        }
      });
      const data = await res.text();
      console.log(`[Bridgecard ${ep.name}] Status: ${res.status}`);
      console.log(`Response:`, data.slice(0, 300), '\n');
    } catch (e) {
      console.error(`[Bridgecard ${ep.name}] Error:`, e.message);
    }
  }
}

async function testMaplerad() {
  console.log('--- 2. Testing Maplerad API ---');
  const secretKey = process.env.MAPLERAD_SECRET_KEY;
  const baseUrl = process.env.MAPLERAD_BASE_URL || 'https://api.maplerad.com/v1';
  console.log('Base URL:', baseUrl);
  console.log('Secret Key starts with:', secretKey ? secretKey.substring(0, 15) : 'MISSING');

  const testEndpoints = [
    { name: 'Wallets / Balance', url: `${baseUrl}/wallets`, method: 'GET' },
    { name: 'Customers', url: `${baseUrl}/customers`, method: 'GET' },
    { name: 'Issuing', url: `${baseUrl}/issuing`, method: 'GET' },
    { name: 'Cards', url: `${baseUrl}/issuing/cards`, method: 'GET' }
  ];

  for (const ep of testEndpoints) {
    try {
      const res = await fetch(ep.url, {
        method: ep.method,
        headers: {
          'Authorization': 'Bearer ' + secretKey,
          'Content-Type': 'application/json'
        }
      });
      const data = await res.text();
      console.log(`[Maplerad ${ep.name}] Status: ${res.status}`);
      console.log(`Response:`, data.slice(0, 300), '\n');
    } catch (e) {
      console.error(`[Maplerad ${ep.name}] Error:`, e.message);
    }
  }
}

async function run() {
  await testBridgecard();
  await testMaplerad();
}

run();
