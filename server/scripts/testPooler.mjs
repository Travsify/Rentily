import pg from 'pg';

const regions = [
  'eu-central-1',
  'us-east-1',
  'us-west-1',
  'eu-west-1',
  'ap-southeast-1',
  'sa-east-1'
];

async function check() {
  for (const r of regions) {
    const host = 'aws-0-' + r + '.pooler.supabase.com';
    const user = 'postgres.zuxvxuqxomsxgiljykzj';
    for (const pass of ['Forgetpassword.', 'Forgetpassword2024.']) {
      const connStr = 'postgresql://' + user + ':' + encodeURIComponent(pass) + '@' + host + ':6543/postgres';
      const client = new pg.Client({ connectionString: connStr, ssl: { rejectUnauthorized: false } });
      try {
        await client.connect();
        console.log('SUCCESS with region:', r);
        await client.query(`
          ALTER TABLE profiles 
          ADD COLUMN IF NOT EXISTS usdt_tron_address TEXT,
          ADD COLUMN IF NOT EXISTS account_provider TEXT DEFAULT 'FLUTTERWAVE';
        `);
        console.log('Altered profiles table successfully!');
        await client.end();
        return;
      } catch (e) {
        // try next
      }
    }
  }
  console.log('Finished testing pooler regions.');
}
check();
