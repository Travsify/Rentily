import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

import { MapleradBankingService } from '../services/mapleradBankingService.ts';

async function testService() {
  console.log('Testing MapleradBankingService...');
  const addr = await MapleradBankingService.getOrCreateUsdtTronAddress({
    email: 'finplify9@gmail.com',
    fullName: 'Patrick Achua'
  });
  console.log('USDT TRON result:', addr);

  const banks = await MapleradBankingService.getInstitutions();
  console.log('Institutions count:', banks.length);
}
testService().catch(console.error);
