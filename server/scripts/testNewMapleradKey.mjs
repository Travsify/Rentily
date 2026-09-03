const key = 'mpr_sk_35d197e6-3f6b-437c-995b-a0dff522b3dc';

async function testKey() {
  const baseUrls = [
    'https://api.maplerad.com/v1',
    'https://sandbox.api.maplerad.com/v1'
  ];

  const endpoints = [
    '/wallets',
    '/institutions',
    '/customers',
    '/issuing',
    '/issuing/cards',
    '/issuing/card-products'
  ];

  for (const base of baseUrls) {
    console.log('\n=== Testing Base URL: ' + base + ' ===');
    for (const ep of endpoints) {
      try {
        const res = await fetch(base + ep, {
          headers: {
            'Authorization': 'Bearer ' + key,
            'accept': 'application/json',
            'Content-Type': 'application/json'
          }
        });
        const text = await res.text();
        console.log(`[${res.status}] ${ep} ->`, text.slice(0, 300));
      } catch (e) {
        console.error('Error on ' + base + ep + ':', e.message);
      }
    }
  }
}

testKey();
