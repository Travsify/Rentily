import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

import { CardIssuingService } from '../services/cardIssuingService.ts';
import { MapleradCardService } from '../services/mapleradCardService.ts';

async function run() {
  console.log('--- 1. TESTING MAPLERAD DIRECT CARD ISSUANCE ---');
  const mRes = await MapleradCardService.issueCard({
    email: 'tonerocool1@gmail.com',
    cardholderName: 'Ehomes Global Inclusive Limited',
    currency: 'USD',
    brand: 'VISA',
    initialFunding: 5.00
  });
  console.log('Maplerad Result:', mRes);

  console.log('\n--- 2. TESTING BRIDGECARD / CARDSVC DIRECT ISSUANCE ---');
  const cRes = await CardIssuingService.issueCard({
    email: 'tonerocool1@gmail.com',
    cardholderName: 'Ehomes Global Inclusive Limited',
    currency: 'USD',
    brand: 'VISA',
    initialFunding: 5.00
  });
  console.log('CardIssuingService Result:', cRes);
}

run().catch(console.error);
