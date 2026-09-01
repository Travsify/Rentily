import dotenv from 'dotenv';
dotenv.config();

const PAYSTACK_SECRET = process.env.PAYSTACK_SECRET_KEY || '';

async function verifyTransferById() {
  const id = '1028202500';
  console.log(`Verifying transfer ID ${id} directly on Paystack API...`);

  try {
    const res = await fetch(`https://api.paystack.co/transfer/${id}`, {
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
    });
    const data: any = await res.json();
    console.log('Paystack Transfer Details:', JSON.stringify(data, null, 2));
  } catch (err: any) {
    console.error('Error verifying transfer by ID:', err.message);
  }
}

verifyTransferById();
