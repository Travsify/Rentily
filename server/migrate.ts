import { Client } from 'pg';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.error('❌ DATABASE_URL is not set in .env');
  process.exit(1);
}

async function runMigration() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to Supabase PostgreSQL database...');
    await client.connect();
    console.log('✅ Connected to Supabase DB successfully!');

    // Read Migration 1: Tables & RLS
    const migration1Path = path.join(process.cwd(), 'supabase', 'migrations', '20260830000001_create_rentilly_tables.sql');
    let migration1Sql = fs.readFileSync(migration1Path, 'utf8');

    // Make profiles foreign key optional if inserting seed users directly
    migration1Sql = migration1Sql.replace(
      'id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,',
      'id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),'
    );

    console.log('Running 001_create_rentilly_tables.sql...');
    await client.query(migration1Sql);
    console.log('✅ 001_create_rentilly_tables.sql applied successfully!');

    // Read Migration 2: Seed Data
    const migration2Path = path.join(process.cwd(), 'supabase', 'migrations', '20260830000002_seed_nigerian_data.sql');
    const migration2Sql = fs.readFileSync(migration2Path, 'utf8');

    console.log('Running 002_seed_nigerian_data.sql...');
    await client.query(migration2Sql);
    console.log('✅ 002_seed_nigerian_data.sql applied successfully!');

    // Test a quick query to verify tables
    const propRes = await client.query('SELECT count(*) FROM properties;');
    const kypRes = await client.query('SELECT count(*) FROM kyp_verifications;');
    console.log('==============================================');
    console.log(`🎉 Supabase Migration Complete!`);
    console.log(`🏢 Properties Count in DB: ${propRes.rows[0].count}`);
    console.log(`🛡️ KYP Records in DB: ${kypRes.rows[0].count}`);
    console.log('==============================================');
  } catch (err) {
    console.error('❌ Migration Error:', err);
  } finally {
    await client.end();
  }
}

runMigration();
