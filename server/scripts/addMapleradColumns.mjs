import pg from 'pg';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

const dbUrls = [
  'postgresql://postgres:Forgetpassword2024.@db.zuxvxuqxomsxgiljykzj.supabase.co:5432/postgres',
  'postgresql://postgres:Forgetpassword.@db.zuxvxuqxomsxgiljykzj.supabase.co:5432/postgres',
  process.env.DATABASE_URL
];

async function migrate() {
  for (const dbUrl of dbUrls) {
    if (!dbUrl) continue;
    const client = new pg.Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
    try {
      await client.connect();
      console.log('Connected to PostgreSQL database!');
      await client.query(`
        ALTER TABLE profiles 
        ADD COLUMN IF NOT EXISTS usdt_tron_address TEXT,
        ADD COLUMN IF NOT EXISTS account_provider TEXT DEFAULT 'FLUTTERWAVE';
      `);
      console.log('Successfully altered profiles table!');
      await client.end();
      return;
    } catch (e) {
      console.warn('DB URL failed:', e.message);
      try { await client.end(); } catch (_) {}
    }
  }
}
migrate();
