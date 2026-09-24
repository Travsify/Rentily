/**
 * End-to-End Integration Test Suite for Termii SMS Engine & Notification Rails
 * 
 * Tests:
 * 1. Gateway Connectivity & Balance Check (TermiiService.getBalance, normalizePhoneForTermii)
 * 2. Scenario A: New User / Yet-to-Install Onboarding (Phone OTP generation & verification)
 * 3. Scenario B: Installed / Existing User (SMS Notification Toggle & ₦20 Fee Deduction)
 * 4. Scenario C: User with SMS Disabled (No Fee Deduction & Balance Invariance)
 */

const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../.env') });

async function runTests() {
  console.log('='.repeat(70));
  console.log('🚀 STARTING TERMII SMS & NOTIFICATION RAILS E2E INTEGRATION TEST');
  console.log('='.repeat(70));

  let results = {
    total: 0,
    passed: 0,
    failed: 0,
    details: []
  };

  function recordAssertion(suite, name, passed, details = '') {
    results.total++;
    if (passed) {
      results.passed++;
      console.log(`  ✅ [PASS] ${suite} -> ${name} ${details ? `(${details})` : ''}`);
      results.details.push({ suite, name, status: 'PASS', details });
    } else {
      results.failed++;
      console.error(`  ❌ [FAIL] ${suite} -> ${name} ${details ? `(${details})` : ''}`);
      results.details.push({ suite, name, status: 'FAIL', details });
    }
  }

  try {
    // Dynamically import TS modules using tsx/native dynamic import
    const { TermiiService } = await import('../server/services/termiiService.ts');
    const { OtpStore } = await import('../server/services/otpStore.ts');
    const { UserStore } = await import('../server/services/userStore.ts');
    const { TransactionStore } = await import('../server/services/transactionStore.ts');
    const { NotificationDispatcher } = await import('../server/services/notificationDispatcher.ts');

    // =========================================================================
    // 1. Gateway Connectivity & Balance Check
    // =========================================================================
    console.log('\n--- 1. Testing Gateway Connectivity & Balance Check ---');
    
    // 1a. Normalize phone number tests
    const phoneTestCases = [
      { input: '08026990956', expected: '2348026990956' },
      { input: '+2348026990956', expected: '2348026990956' },
      { input: '2348026990956', expected: '2348026990956' },
      { input: '08123456789', expected: '2348123456789' },
      { input: '+234 802 699 0956', expected: '2348026990956' }
    ];

    for (const { input, expected } of phoneTestCases) {
      const normalized = TermiiService.normalizePhoneForTermii(input);
      const passed = normalized === expected;
      recordAssertion('TermiiService Phone Normalization', `Format: "${input}"`, passed, `got "${normalized}", expected "${expected}"`);
    }

    // 1b. Real Gateway Balance Check
    console.log('  📡 Querying live Termii balance endpoint...');
    const balanceRes = await TermiiService.getBalance();
    console.log(`  📊 Termii Balance Response:`, JSON.stringify(balanceRes));

    recordAssertion(
      'Gateway Connectivity',
      'Termii balance query status',
      balanceRes.status === true,
      `status: ${balanceRes.status}`
    );
    recordAssertion(
      'Gateway Balance Check',
      'Termii balance is positive and currency is NGN',
      balanceRes.balance > 0 && balanceRes.currency === 'NGN',
      `Balance: ₦${balanceRes.balance?.toLocaleString()} ${balanceRes.currency}`
    );

    // =========================================================================
    // 2. Scenario A: New User / Yet-to-Install Onboarding (Phone OTP)
    // =========================================================================
    console.log('\n--- 2. Scenario A: New User / Yet-to-Install Onboarding (Phone OTP) ---');
    
    const testPhone = '2348026990956';
    const otpCreation = OtpStore.createOtp(testPhone, 'Account Verification');
    
    recordAssertion(
      'Scenario A: OTP Generation',
      'OTP code is a 6-digit numeric string',
      typeof otpCreation.code === 'string' && /^\d{6}$/.test(otpCreation.code),
      `Generated Code: ${otpCreation.code}, ExpiresAt: ${new Date(otpCreation.expiresAt).toISOString()}`
    );

    // Verify with incorrect code first
    const wrongCodeRes = OtpStore.verifyOtp(testPhone, '999999');
    recordAssertion(
      'Scenario A: Wrong OTP Rejection',
      'Incorrect OTP code must return valid: false',
      wrongCodeRes.valid === false,
      `Message: "${wrongCodeRes.message}"`
    );

    // Verify with correct code
    const validCodeRes = OtpStore.verifyOtp(testPhone, otpCreation.code);
    recordAssertion(
      'Scenario A: Valid OTP Verification',
      'Correct OTP code must return valid: true',
      validCodeRes.valid === true,
      `Message: "${validCodeRes.message}"`
    );

    // Replay attack prevention: same code used twice should fail
    const replayRes = OtpStore.verifyOtp(testPhone, otpCreation.code);
    recordAssertion(
      'Scenario A: Replay Prevention',
      'Reusing already-verified OTP must return valid: false',
      replayRes.valid === false,
      `Message: "${replayRes.message}"`
    );

    // =========================================================================
    // 3. Scenario B: Installed / Existing User (SMS Notification Toggle & ₦20 Fee Deduction)
    // =========================================================================
    console.log('\n--- 3. Scenario B: Installed User (SMS Enabled & ₦20 Fee Deduction) ---');

    const testUserBEmail = `test_sms_user_${Date.now()}@rentilly.ng`;
    const initialBalanceB = 1000;
    
    const userB = UserStore.upsertUser({
      id: `usr_${Date.now()}_b`,
      email: testUserBEmail,
      fullName: 'Test SMS User B',
      phoneNumber: '+2348026990956',
      role: 'renter',
      isVerified: true,
      walletBalance: initialBalanceB,
      enableSmsNotifications: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });

    console.log(`  👤 Created test user ${testUserBEmail} with balance ₦${initialBalanceB} and enableSmsNotifications: true`);

    // Dispatch transactional notification
    const dispatchBRes = await NotificationDispatcher.dispatch({
      email: testUserBEmail,
      title: 'Escrow Payout Credited',
      category: 'escrow',
      message: 'Your rent payout of ₦500,000 has been credited.'
    });

    console.log(`  📨 Dispatch Result:`, JSON.stringify(dispatchBRes));

    // Fetch updated user
    const updatedUserB = await UserStore.findByEmail(testUserBEmail);
    const expectedBalanceB = initialBalanceB - 20; // 980

    recordAssertion(
      'Scenario B: Wallet Fee Deduction',
      'Wallet balance debited by exactly ₦20',
      updatedUserB?.walletBalance === expectedBalanceB,
      `Old: ₦${initialBalanceB}, Expected: ₦${expectedBalanceB}, Actual: ₦${updatedUserB?.walletBalance}`
    );

    // Check TransactionStore records
    const allTxs = TransactionStore.getAllTransactions();
    const smsFeeTx = allTxs.find(t => 
      t.email.toLowerCase() === testUserBEmail.toLowerCase() &&
      t.type === 'SMS Notification Fee' &&
      t.amount === 20
    );

    recordAssertion(
      'Scenario B: Transaction Recording',
      'Transaction record with type "SMS Notification Fee" and amount 20 exists',
      Boolean(smsFeeTx),
      smsFeeTx ? `Tx Ref: ${smsFeeTx.reference}, Title: "${smsFeeTx.title}", Status: ${smsFeeTx.status}` : 'Tx not found'
    );

    // =========================================================================
    // 4. Scenario C: User with SMS Disabled (No Deduction)
    // =========================================================================
    console.log('\n--- 4. Scenario C: User with SMS Disabled (No Deduction) ---');

    const testUserCEmail = `test_sms_disabled_${Date.now()}@rentilly.ng`;
    const initialBalanceC = 1000;

    const userC = UserStore.upsertUser({
      id: `usr_${Date.now()}_c`,
      email: testUserCEmail,
      fullName: 'Test SMS User C (Disabled)',
      phoneNumber: '+2348026990956',
      role: 'renter',
      isVerified: true,
      walletBalance: initialBalanceC,
      enableSmsNotifications: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });

    console.log(`  👤 Created test user ${testUserCEmail} with balance ₦${initialBalanceC} and enableSmsNotifications: false`);

    // Dispatch notification
    const dispatchCRes = await NotificationDispatcher.dispatch({
      email: testUserCEmail,
      title: 'Escrow Payout Credited',
      category: 'escrow',
      message: 'Your rent payout of ₦500,000 has been credited.'
    });

    console.log(`  📨 Dispatch Result:`, JSON.stringify(dispatchCRes));

    // Fetch updated user
    const updatedUserC = await UserStore.findByEmail(testUserCEmail);

    recordAssertion(
      'Scenario C: Fee Exemption',
      'Wallet balance remains unchanged at ₦1000 when SMS is disabled',
      updatedUserC?.walletBalance === initialBalanceC,
      `Expected: ₦${initialBalanceC}, Actual: ₦${updatedUserC?.walletBalance}`
    );

    // Verify no SMS fee tx was recorded for user C
    const smsFeeTxC = TransactionStore.getAllTransactions().find(t => 
      t.email.toLowerCase() === testUserCEmail.toLowerCase() &&
      t.type === 'SMS Notification Fee'
    );

    recordAssertion(
      'Scenario C: No Transaction Record',
      'No SMS Notification Fee transaction recorded for opted-out user',
      smsFeeTxC === undefined,
      smsFeeTxC ? `Unexpected Tx Found: ${smsFeeTxC.id}` : 'No unwanted fee transaction recorded'
    );

    // =========================================================================
    // Cleanup Test Users
    // =========================================================================
    console.log('\n--- Cleanup Test Artifacts ---');
    await UserStore.deleteUser(testUserBEmail);
    await UserStore.deleteUser(testUserCEmail);
    console.log('  🧹 Cleaned up temporary test users from store.');

  } catch (error) {
    console.error('❌ Critical error during test execution:', error);
    recordAssertion('Global Test Runner', 'Unhandled Exception', false, error.message);
  }

  // =========================================================================
  // Final Test Summary
  // =========================================================================
  console.log('\n' + '='.repeat(70));
  console.log(`🏁 TEST SUMMARY: Total: ${results.total} | Passed: ${results.passed} | Failed: ${results.failed}`);
  console.log('='.repeat(70));

  if (results.failed > 0) {
    console.error(`💥 ${results.failed} test(s) failed.`);
    process.exit(1);
  } else {
    console.log('🎉 ALL INTEGRATION TESTS PASSED SUCCESSFULLY!');
    process.exit(0);
  }
}

runTests();
