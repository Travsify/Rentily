const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zuxvxuqxomsxgiljykzj.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function seed() {
  const initialConfig = {
    fxSpreadPercent: 1.20,
    corridorFeesNgn: {
      gbpFpsNgn: 3000,
      eurSepaNgn: 5000,
      usdWireNgn: 7500,
      usdSwiftNgn: 15000,
      cadEftNgn: 5000
    },
    tuitionSemesterLimitUsd: 25000,
    supplierInvoiceLimitUsd: 100000,
    featureEnabled: true,
    supportedCurrencies: ['USD', 'GBP', 'EUR', 'CAD']
  };

  const { data, error } = await supabase.from('system_configs').upsert({
    id: 'global_pay_config',
    data: initialConfig,
    updated_at: new Date().toISOString()
  }).select();

  console.log('Seeded global_pay_config:', { data, error });
}

seed();
