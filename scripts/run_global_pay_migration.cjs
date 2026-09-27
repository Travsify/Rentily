const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function run() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('DATABASE_URL not found in .env');
    process.exit(1);
  }

  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('Connected to Supabase PostgreSQL database.');

    const sqlPath = path.join(__dirname, '..', 'supabase', 'migrations', '20260927000001_rentilly_global_pay.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Executing migration 20260927000001_rentilly_global_pay.sql...');
    await client.query(sql);
    console.log('Migration executed successfully!');

    // Verify tables and procedures
    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name IN ('system_configs', 'wallet_holds', 'global_beneficiaries', 'global_payout_orders');
    `);
    console.log('Verified tables in DB:', tablesRes.rows.map(r => r.table_name));

    const configRes = await client.query(`SELECT key, value FROM system_configs WHERE key = 'global_pay_config';`);
    console.log('Verified Global Pay Config seeded:', configRes.rows[0]);

    const procsRes = await client.query(`
      SELECT routine_name 
      FROM information_schema.routines 
      WHERE routine_schema = 'public' 
      AND routine_name LIKE 'fn_%_wallet_hold%';
    `);
    console.log('Verified Stored Procedures:', procsRes.rows.map(r => r.routine_name));

  } catch (err) {
    console.error('Migration error:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
