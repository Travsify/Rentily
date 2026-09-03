import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const pg = require('pg');
const dotenv = require('dotenv');
dotenv.config();

const conn = process.env.DATABASE_URL || 'postgresql://postgres.zuxvxuqxomsxgiljykzj:RentillySupabase2026!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres';
const client = new pg.Client({ connectionString: conn });

async function fix() {
  await client.connect();
  console.log('Connected to PG');
  
  const enumRes = await client.query("SELECT enumlabel FROM pg_enum JOIN pg_type ON pg_enum.enumtypid = pg_type.oid WHERE pg_type.typname = 'user_role'");
  console.log('Current labels:', enumRes.rows.map(r => r.enumlabel));

  try {
    await client.query("ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'partner'");
    console.log("Added partner to user_role enum!");
  } catch (err) {
    console.log('Enum alter note:', err.message);
  }

  const upd = await client.query("UPDATE profiles SET role = 'partner' WHERE email = 'tonerocool1@gmail.com' RETURNING email, role, full_name, business_name");
  console.log('Updated profile:', upd.rows);
  await client.end();
}

fix().catch(console.error);
