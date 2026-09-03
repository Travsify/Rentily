import { OtpStore } from '../services/otpStore.ts';
import { ResendService } from '../services/resendService.ts';

async function testOtpPipeline() {
  console.log('1. Testing OTP Generation in OtpStore...');
  const testEmail = 'tonerocool1@gmail.com';
  const { code, expiresAt } = OtpStore.createOtp(testEmail, 'Login Authentication 2FA');
  console.log(`Generated OTP code: ${code}, expires at: ${new Date(expiresAt).toISOString()}`);

  console.log('2. Dispatching Live Email via Resend...');
  const res = await ResendService.sendOtpEmail({
    to: testEmail,
    code,
    userName: 'Ehomes Global Inclusive Limited',
    purpose: 'Login Authentication 2FA'
  });
  console.log('Resend Delivery Result:', res);

  console.log('3. Verifying Incorrect Code...');
  const failCheck = OtpStore.verifyOtp(testEmail, '000000');
  console.log('Incorrect Code Check (should fail):', failCheck);

  console.log('4. Verifying Correct Code...');
  const successCheck = OtpStore.verifyOtp(testEmail, code);
  console.log('Correct Code Check (should pass):', successCheck);

  if (res.status && successCheck.valid && !failCheck.valid) {
    console.log('\n?? ALL 2FA OTP TESTS PASSED PERFECTLY!');
  } else {
    console.error('\n? Tests encountered issues.');
  }
}

testOtpPipeline().catch(console.error);
