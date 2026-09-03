const appId = 'b754a092-fafa-4180-b097-bb38f3530b1f';
const secretKey = 'sk_live_VTJGc2RHVmtYMTg1eXdGekZaVytDNXpkR0JNUGJha040bTJYcnpYUkZ5amZFTG0zZkZhR1ZjaFBiY1djakV6Y3I3ZE9wY3lMK3pPV0ZadUQvMWVBQmZoWjYvY1RrMEdUbmQ3UTJzdWQ0ZG9pWW0rcndKS1pSTHdxcGYwdmNPRjVvUmhTU0lBUWxQTXZ3QVN3NDE5akxReFh3aGljUXVDTy9nSWYycjlSZzNRWW1iK01sN2JPVkN3a2ZncWE5dnVIalc1c3dnLzFLNWtnRlZuWDZNQnNDYlJNQVBTT2loL25iZWliTFdscmhJRzBHOGZjOXBqL09aUzE5a1ZYdDNjYkJNTWMvZk5UUDNIcU5kTmxLZHg0U1BUUDYwQmp0Z0lFMDNQQnJaU1BqUWlvTHJ2Y2NLd213MnhMYkhCOG9DWjcwZDl3M2t4ZEtYTDZFekFQMlpodFI5THJJU0ZhajdmdnB2UVJocTB1QmVvZ3NRNXU1aVB1d2hwR3J3UXNRQ0lOcHduNm5vN0F0OWNiYW1HTUwwRnFUUk03QXk2cFVTc1F2bHcvSTN0T2ZhY3JmbWNCTnlZSnVnWlpGdzd1cFRkaGdYUGhhaGVTMVI3OGJ2MWI4RTZKOXN0eEhQZFJvMmRKa0xkUVB5V0I1eFE9';

async function testBridgecard() {
  const variations = [
    { 'token': 'Bearer ' + secretKey, 'issue_app_id': appId },
    { 'token': secretKey, 'issue_app_id': appId },
    { 'Authorization': 'Bearer ' + secretKey, 'issue_app_id': appId },
    { 'token': 'Bearer ' + secretKey, 'issuing_app_id': appId },
    { 'x-api-key': secretKey, 'issue_app_id': appId }
  ];

  const endpoints = [
    'https://issuecards.api.bridgecard.co/v1/issuing/wallet/balance',
    'https://issuecards.api.bridgecard.co/v1/issuing/cardholder/register_cardholder_synchronously',
    'https://issuecards.api.bridgecard.co/v1/issuing/cards/create_card'
  ];

  for (const ep of endpoints) {
    console.log('\n--- Testing Endpoint:', ep);
    for (let i = 0; i < variations.length; i++) {
      try {
        const res = await fetch(ep, {
          method: ep.includes('balance') ? 'GET' : 'POST',
          headers: {
            ...variations[i],
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: ep.includes('balance') ? undefined : JSON.stringify({ test: true })
        });
        const text = await res.text();
        console.log(`Variation ${i} [Status: ${res.status}] ->`, text.slice(0, 200));
      } catch (e) {
        console.error(`Variation ${i} Error:`, e.message);
      }
    }
  }
}

testBridgecard();
