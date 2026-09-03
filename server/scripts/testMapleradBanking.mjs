const key = 'mpr_sk_35d197e6-3f6b-437c-995b-a0dff522b3dc';
const baseUrl = 'https://api.maplerad.com/v1';

async function testAll() {
  console.log('--- 1. Testing Customer Lookup / Enrollment ---');
  const email = 'tonerocool1@gmail.com';
  let custRes = await fetch(`${baseUrl}/customers?email=${encodeURIComponent(email)}`, {
    headers: { 'Authorization': 'Bearer ' + key }
  });
  let custData = await custRes.json();
  console.log('Lookup customer:', custData.data?.[0]?.id || 'Not found');

  let customerId = custData.data?.[0]?.id;

  if (!customerId) {
    console.log('Enrolling customer...');
    const enrollRes = await fetch(`${baseUrl}/customers/enroll`, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + key,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        first_name: 'Tonero',
        last_name: 'Ehomes',
        email: email,
        phone_number: {
          phone_country_code: '234',
          phone_number: '8033246811'
        },
        dob: '15-05-1992',
        identification_number: '22145896321',
        address: {
          street: 'Admiralty Way, Lekki Phase 1',
          city: 'Lagos',
          state: 'Lagos',
          postal_code: '105102',
          country: 'NG'
        }
      })
    });
    const enrollData = await enrollRes.json();
    console.log('Enroll status:', enrollRes.status, enrollData.message);
    customerId = enrollData.data?.id;
  }

  console.log('\n--- 2. Testing NGN Virtual Account Generation ---');
  const vaRes = await fetch(`${baseUrl}/collections/virtual-account`, {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + key,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      customer_id: customerId || '844eb2ca-edd3-425d-9276-39db9788dff8',
      currency: 'NGN'
    })
  });
  const vaData = await vaRes.json();
  console.log('Virtual Account:', vaRes.status, JSON.stringify(vaData));

  console.log('\n--- 3. Testing USDT TRON Generation ---');
  const cryptoRes = await fetch(`${baseUrl}/crypto`, {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + key,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      customer_id: customerId || '844eb2ca-edd3-425d-9276-39db9788dff8',
      coin: 'USDT',
      chain: 'tron',
      offramp: false
    })
  });
  const cryptoData = await cryptoRes.json();
  console.log('USDT TRON:', cryptoRes.status, JSON.stringify(cryptoData));

  console.log('\n--- 4. Testing Bank List ---');
  const bankRes = await fetch(`${baseUrl}/institutions?country=NG`, {
    headers: { 'Authorization': 'Bearer ' + key }
  });
  const bankData = await bankRes.json();
  console.log(`Fetched ${bankData.data?.length} Nigerian banking institutions.`);
}

testAll();
