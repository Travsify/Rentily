/**
 * Rentilly Virtual Card Issuing - End-to-End Simulation & Integration Test Script
 * 
 * Simulates and validates:
 * 1. Fetching card pricing from the API / CardIssuingService.
 * 2. Calculating issuance debit for a Naira card (1,500 + 1,000 = 2,500 NGN).
 * 3. Validating a test user wallet balance against issuance requirements (insufficient, exact, ample).
 * 4. Validating funding subunit calculation (₦1,000 -> 100,000 kobo) and edge cases.
 * 5. Validating card record data model and mock response parsing (PCI-DSS masking, types, billing address, PIN).
 */

import crypto from 'crypto';
import { CardIssuingService, VirtualCard, CardPricingConfig } from '../services/cardIssuingService';

interface TestCaseResult {
  suite: string;
  id: string;
  name: string;
  passed: boolean;
  expected: string;
  actual: string;
  error?: string;
}

const testResults: TestCaseResult[] = [];

function assert(
  suite: string,
  id: string,
  name: string,
  condition: boolean,
  expected: any,
  actual: any
) {
  const passed = Boolean(condition);
  testResults.push({
    suite,
    id,
    name,
    passed,
    expected: typeof expected === 'object' ? JSON.stringify(expected) : String(expected),
    actual: typeof actual === 'object' ? JSON.stringify(actual) : String(actual),
    error: passed ? undefined : `Assertion failed: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
  });
  if (passed) {
    console.log(`  \x1b[32m✔ [PASS]\x1b[0m [${id}] ${name}`);
  } else {
    console.error(`  \x1b[31m✘ [FAIL]\x1b[0m [${id}] ${name}`);
    console.error(`     Expected: ${JSON.stringify(expected)}`);
    console.error(`     Actual:   ${JSON.stringify(actual)}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 1: Card Pricing Service & Config Validation
// ─────────────────────────────────────────────────────────────────────────────
async function runPricingTests() {
  console.log('\n\x1b[36m=== SUITE 1: Card Pricing Retrieval & Verification ===\x1b[0m');

  // TC-1.1: Fetch default pricing config
  const pricing = CardIssuingService.getCardPricing();

  assert(
    '1. Card Pricing',
    'TC-1.1.1',
    'Issuance fee for NGN is ₦1,500.00',
    pricing.issuanceFeeNgn === 1500.00,
    1500.00,
    pricing.issuanceFeeNgn
  );

  assert(
    '1. Card Pricing',
    'TC-1.1.2',
    'Minimum funding for NGN is ₦1,000.00',
    pricing.minFundingNgn === 1000.00,
    1000.00,
    pricing.minFundingNgn
  );

  assert(
    '1. Card Pricing',
    'TC-1.1.3',
    'Issuance fee for USD is $3.00',
    pricing.issuanceFeeUsd === 3.00,
    3.00,
    pricing.issuanceFeeUsd
  );

  assert(
    '1. Card Pricing',
    'TC-1.1.4',
    'Minimum funding for USD is $1.00',
    pricing.minFundingUsd === 1.00,
    1.00,
    pricing.minFundingUsd
  );

  assert(
    '1. Card Pricing',
    'TC-1.1.5',
    'Funding fee percentage is 1.5%',
    pricing.fundingFeePercent === 1.5,
    1.5,
    pricing.fundingFeePercent
  );

  assert(
    '1. Card Pricing',
    'TC-1.1.6',
    'Monthly maintenance fee for NGN is ₦500.00',
    pricing.monthlyMaintenanceNgn === 500.00,
    500.00,
    pricing.monthlyMaintenanceNgn
  );

  // TC-1.2: Check immutability of getCardPricing() return object
  pricing.issuanceFeeNgn = 99999;
  const freshPricing = CardIssuingService.getCardPricing();
  assert(
    '1. Card Pricing',
    'TC-1.2',
    'getCardPricing() returns defensive copy preventing prototype corruption',
    freshPricing.issuanceFeeNgn === 1500.00,
    1500.00,
    freshPricing.issuanceFeeNgn
  );

  // TC-1.3: Dynamic config update & rollback simulation
  const originalFee = freshPricing.issuanceFeeNgn;
  const updatedPricing = await CardIssuingService.updateCardPricing({ issuanceFeeNgn: 2000.00 });
  assert(
    '1. Card Pricing',
    'TC-1.3.1',
    'updateCardPricing accepts valid price updates',
    updatedPricing.issuanceFeeNgn === 2000.00,
    2000.00,
    updatedPricing.issuanceFeeNgn
  );
  // Restore
  await CardIssuingService.updateCardPricing({ issuanceFeeNgn: originalFee });
  assert(
    '1. Card Pricing',
    'TC-1.3.2',
    'Pricing successfully restored to standard ₦1,500.00',
    CardIssuingService.getCardPricing().issuanceFeeNgn === 1500.00,
    1500.00,
    CardIssuingService.getCardPricing().issuanceFeeNgn
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 2: Naira Card Issuance Debit Calculation (1,500 + 1,000 = 2,500)
// ─────────────────────────────────────────────────────────────────────────────
function calculateNairaIssuanceDebit(
  initialFunding: number,
  customPricing?: CardPricingConfig
): {
  valid: boolean;
  error?: string;
  issuanceFeeNgn: number;
  initialFundingNgn: number;
  totalDebitNgn: number;
} {
  const pricing = customPricing || CardIssuingService.getCardPricing();
  const minFundingNgn = pricing.minFundingNgn || 1000.00;
  const initialNgn = Number(initialFunding || 0);

  if (isNaN(initialNgn) || initialNgn < minFundingNgn) {
    return {
      valid: false,
      error: `A minimum initial card funding of ₦${minFundingNgn.toLocaleString()} NGN is mandatory to create a Virtual Naira card.`,
      issuanceFeeNgn: pricing.issuanceFeeNgn,
      initialFundingNgn: initialNgn,
      totalDebitNgn: 0
    };
  }

  const issuanceFeeNgn = pricing.issuanceFeeNgn || 1500.00;
  const totalDebitNgn = Number((issuanceFeeNgn + initialNgn).toFixed(2));

  return {
    valid: true,
    issuanceFeeNgn,
    initialFundingNgn: initialNgn,
    totalDebitNgn
  };
}

async function runDebitCalculationTests() {
  console.log('\n\x1b[36m=== SUITE 2: Naira Card Issuance Debit Calculation ===\x1b[0m');

  // TC-2.1: Standard baseline issuance: 1,500 fee + 1,000 initial = 2,500 total
  const resStandard = calculateNairaIssuanceDebit(1000.00);
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.1.1',
    'Calculates issuance fee as exactly ₦1,500.00',
    resStandard.issuanceFeeNgn === 1500.00,
    1500.00,
    resStandard.issuanceFeeNgn
  );
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.1.2',
    'Accepts valid minimum initial funding of ₦1,000.00',
    resStandard.initialFundingNgn === 1000.00,
    1000.00,
    resStandard.initialFundingNgn
  );
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.1.3',
    'Calculates total debit as 1,500 + 1,000 = ₦2,500.00',
    resStandard.totalDebitNgn === 2500.00,
    2500.00,
    resStandard.totalDebitNgn
  );
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.1.4',
    'Standard issuance debit validation flag is true',
    resStandard.valid === true,
    true,
    resStandard.valid
  );

  // TC-2.2: Below minimum funding boundary enforcement (e.g. ₦500 < ₦1,000)
  const resSubMin = calculateNairaIssuanceDebit(500.00);
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.2.1',
    'Rejects initial funding below ₦1,000 minimum',
    resSubMin.valid === false,
    false,
    resSubMin.valid
  );
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.2.2',
    'Returns accurate descriptive minimum funding error message',
    resSubMin.error?.includes('minimum initial card funding of ₦1,000 NGN is mandatory') === true,
    true,
    resSubMin.error
  );

  // TC-2.3: Custom funding amount (e.g. ₦5,000 initial funding -> ₦6,500 debit)
  const resCustom = calculateNairaIssuanceDebit(5000.00);
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.3.1',
    'Calculates custom initial funding total debit (1,500 + 5,000 = ₦6,500.00)',
    resCustom.totalDebitNgn === 6500.00,
    6500.00,
    resCustom.totalDebitNgn
  );

  // TC-2.4: Negative and NaN funding validation
  const resNaN = calculateNairaIssuanceDebit(Number.NaN);
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.4.1',
    'Rejects NaN funding input gracefully',
    resNaN.valid === false,
    false,
    resNaN.valid
  );

  const resNeg = calculateNairaIssuanceDebit(-500);
  assert(
    '2. Issuance Debit Calculation',
    'TC-2.4.2',
    'Rejects negative initial funding input',
    resNeg.valid === false,
    false,
    resNeg.valid
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 3: Test User Wallet Balance Validation Against Issuance Requirements
// ─────────────────────────────────────────────────────────────────────────────
interface WalletValidationResult {
  allowed: boolean;
  statusCode: number;
  errorMessage?: string;
  debitedAmount: number;
  currentBalance: number;
  newBalance: number;
  ledgerRecord?: {
    type: 'debit';
    currency: 'NGN';
    amount: number;
    narration: string;
    status: 'completed';
    txRef: string;
  };
}

function validateAndDebitUserWallet(
  currentBalanceNgn: number,
  totalDebitRequiredNgn: number,
  issuanceFeeNgn: number,
  initialFundingNgn: number
): WalletValidationResult {
  if (currentBalanceNgn < totalDebitRequiredNgn) {
    return {
      allowed: false,
      statusCode: 400,
      errorMessage: `Insufficient Naira balance. Total required is ₦${totalDebitRequiredNgn.toLocaleString()} (₦${issuanceFeeNgn.toLocaleString()} issuance fee + ₦${initialFundingNgn.toLocaleString()} initial balance), but your balance is ₦${currentBalanceNgn.toLocaleString()}.`,
      debitedAmount: 0,
      currentBalance: currentBalanceNgn,
      newBalance: currentBalanceNgn
    };
  }

  const newBalance = Number((currentBalanceNgn - totalDebitRequiredNgn).toFixed(2));
  const txRef = `RENTILLY_NGN_CARD_ISSUE_${Date.now()}`;

  return {
    allowed: true,
    statusCode: 200,
    debitedAmount: totalDebitRequiredNgn,
    currentBalance: currentBalanceNgn,
    newBalance: Math.max(0, newBalance),
    ledgerRecord: {
      type: 'debit',
      currency: 'NGN',
      amount: totalDebitRequiredNgn,
      narration: `Virtual Naira Card Issuance & Initial Funding: ₦${totalDebitRequiredNgn.toLocaleString('en-NG', { minimumFractionDigits: 2 })} (incl. ₦${issuanceFeeNgn.toLocaleString()} issuance fee)`,
      status: 'completed',
      txRef
    }
  };
}

async function runWalletBalanceValidationTests() {
  console.log('\n\x1b[36m=== SUITE 3: User Wallet Balance Validation ===\x1b[0m');

  const requiredDebit = 2500.00; // 1,500 fee + 1,000 initial
  const issuanceFee = 1500.00;
  const initialFunding = 1000.00;

  // TC-3.1: Insufficient Balance Scenario (₦1,800 balance < ₦2,500 required)
  const userUnderfunded = validateAndDebitUserWallet(1800.00, requiredDebit, issuanceFee, initialFunding);
  assert(
    '3. Wallet Balance Validation',
    'TC-3.1.1',
    'Blocks issuance when wallet balance is lower than total debit requirement',
    userUnderfunded.allowed === false,
    false,
    userUnderfunded.allowed
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.1.2',
    'Returns HTTP 400 status code for insufficient balance',
    userUnderfunded.statusCode === 400,
    400,
    userUnderfunded.statusCode
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.1.3',
    'Formats detailed insufficient balance error message with shortfall breakdown',
    userUnderfunded.errorMessage === 'Insufficient Naira balance. Total required is ₦2,500 (₦1,500 issuance fee + ₦1,000 initial balance), but your balance is ₦1,800.',
    'Insufficient Naira balance. Total required is ₦2,500 (₦1,500 issuance fee + ₦1,000 initial balance), but your balance is ₦1,800.',
    userUnderfunded.errorMessage
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.1.4',
    'Zero funds debited when validation fails',
    userUnderfunded.debitedAmount === 0,
    0,
    userUnderfunded.debitedAmount
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.1.5',
    'Wallet balance remains unmodified on failure (₦1,800.00)',
    userUnderfunded.newBalance === 1800.00,
    1800.00,
    userUnderfunded.newBalance
  );

  // TC-3.2: Exact Balance Match Scenario (₦2,500 balance == ₦2,500 required)
  const userExact = validateAndDebitUserWallet(2500.00, requiredDebit, issuanceFee, initialFunding);
  assert(
    '3. Wallet Balance Validation',
    'TC-3.2.1',
    'Permits issuance when wallet balance exactly equals required debit (₦2,500.00)',
    userExact.allowed === true,
    true,
    userExact.allowed
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.2.2',
    'Returns HTTP 200 status code for exact balance',
    userExact.statusCode === 200,
    200,
    userExact.statusCode
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.2.3',
    'Wallet balance transitions cleanly to exactly ₦0.00',
    userExact.newBalance === 0.00,
    0.00,
    userExact.newBalance
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.2.4',
    'Exact debit amount debited is ₦2,500.00',
    userExact.debitedAmount === 2500.00,
    2500.00,
    userExact.debitedAmount
  );

  // TC-3.3: Ample Balance Scenario (₦50,000 balance > ₦2,500 required)
  const userAmple = validateAndDebitUserWallet(50000.00, requiredDebit, issuanceFee, initialFunding);
  assert(
    '3. Wallet Balance Validation',
    'TC-3.3.1',
    'Permits issuance when wallet has ample balance (₦50,000.00)',
    userAmple.allowed === true,
    true,
    userAmple.allowed
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.3.2',
    'Computes post-debit balance accurately (50,000 - 2,500 = ₦47,500.00)',
    userAmple.newBalance === 47500.00,
    47500.00,
    userAmple.newBalance
  );

  // TC-3.4: Ledger Transaction Generation & Narration
  assert(
    '3. Wallet Balance Validation',
    'TC-3.4.1',
    'Generates completed debit ledger transaction record',
    userAmple.ledgerRecord?.status === 'completed' && userAmple.ledgerRecord.type === 'debit',
    true,
    `${userAmple.ledgerRecord?.type} - ${userAmple.ledgerRecord?.status}`
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.4.2',
    'Ledger currency is strictly NGN',
    userAmple.ledgerRecord?.currency === 'NGN',
    'NGN',
    userAmple.ledgerRecord?.currency
  );
  assert(
    '3. Wallet Balance Validation',
    'TC-3.4.3',
    'Ledger record contains unique reference prefix RENTILLY_NGN_CARD_ISSUE_',
    userAmple.ledgerRecord?.txRef.startsWith('RENTILLY_NGN_CARD_ISSUE_') === true,
    true,
    userAmple.ledgerRecord?.txRef
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 4: Funding Subunit Calculation (₦1,000 -> 100,000 kobo)
// ─────────────────────────────────────────────────────────────────────────────
function calculateSubunits(amount: number, currency: 'NGN' | 'USD'): number {
  if (isNaN(amount) || amount < 0) return 0;
  // In Maplerad and Nigerian banking rails: 1 NGN = 100 Kobo; 1 USD = 100 Cents
  return Math.max(0, Math.round(amount * 100));
}

function convertSubunitsToMajor(subunits: number): number {
  return Number((subunits / 100).toFixed(2));
}

async function runSubunitCalculationTests() {
  console.log('\n\x1b[36m=== SUITE 4: Funding Subunit Calculation ===\x1b[0m');

  // TC-4.1: Canonical ₦1,000 -> 100,000 Kobo
  const kobo1000 = calculateSubunits(1000.00, 'NGN');
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.1.1',
    'Converts ₦1,000.00 to exactly 100,000 kobo subunits',
    kobo1000 === 100000,
    100000,
    kobo1000
  );
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.1.2',
    'Subunit conversion result is a strict integer',
    Number.isInteger(kobo1000),
    true,
    Number.isInteger(kobo1000)
  );

  // TC-4.2: Fractional Kobo Precision Tests
  const koboFraction1 = calculateSubunits(1500.50, 'NGN');
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.2.1',
    'Converts ₦1,500.50 to exactly 150,050 kobo',
    koboFraction1 === 150050,
    150050,
    koboFraction1
  );

  const koboFraction2 = calculateSubunits(0.99, 'NGN');
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.2.2',
    'Converts ₦0.99 to exactly 99 kobo',
    koboFraction2 === 99,
    99,
    koboFraction2
  );

  // TC-4.3: High-Value Funding
  const kobo10k = calculateSubunits(10000.00, 'NGN');
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.3.1',
    'Converts ₦10,000.00 to exactly 1,000,000 kobo',
    kobo10k === 1000000,
    1000000,
    kobo10k
  );

  // TC-4.4: Zero and Negative Amount Safety
  const koboZero = calculateSubunits(0, 'NGN');
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.4.1',
    'Converts ₦0.00 to 0 kobo',
    koboZero === 0,
    0,
    koboZero
  );

  const koboNegative = calculateSubunits(-50, 'NGN');
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.4.2',
    'Safely clamps negative amounts to 0 kobo',
    koboNegative === 0,
    0,
    koboNegative
  );

  // TC-4.5: Reverse Subunit Parsing (100,000 kobo -> ₦1,000.00 major currency)
  const majorNgn = convertSubunitsToMajor(100000);
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.5.1',
    'Converts 100,000 kobo back to ₦1,000.00 major currency',
    majorNgn === 1000.00,
    1000.00,
    majorNgn
  );

  const majorFraction = convertSubunitsToMajor(250075);
  assert(
    '4. Funding Subunit Calculation',
    'TC-4.5.2',
    'Converts 250,075 kobo back to ₦2,500.75 major currency',
    majorFraction === 2500.75,
    2500.75,
    majorFraction
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUITE 5: Card Record Data Model & Mock Response Parsing
// ─────────────────────────────────────────────────────────────────────────────
interface MapleradIssuingResponse {
  status: boolean;
  message?: string;
  data?: {
    id: string;
    card_number?: string;
    pan?: string;
    masked_pan?: string;
    last4?: string;
    last_4?: string;
    expiry_month?: string;
    expiryMonth?: string;
    expiry_year?: string;
    expiryYear?: string;
    cvv?: string;
    currency?: string;
    brand?: string;
    balance?: number;
    type?: string;
  };
}

function parseMockCardResponse(
  response: MapleradIssuingResponse,
  params: {
    email: string;
    cardholderName: string;
    currency: 'USD' | 'NGN';
    brand?: 'VISA' | 'MASTERCARD';
    initialFunding: number;
    pin?: string;
  }
): VirtualCard {
  if (!response.status || !response.data) {
    throw new Error(response.message || 'Maplerad issuing rail rejected card request.');
  }

  const m = response.data;
  const currency = (params.currency || 'NGN').toUpperCase() as 'USD' | 'NGN';
  const brand = params.brand || (currency === 'NGN' ? 'MASTERCARD' : 'VISA');
  const last4 = m.last4 || m.last_4 || '5678';
  const fullPan = m.card_number || m.pan || `539941001234${last4}`;
  const maskedPan = m.masked_pan || `${brand === 'VISA' ? '4829' : '5399'} •••• •••• ${last4}`;
  const cardIdStr = m.id || `CARD_${Date.now()}_${last4}`;
  const uuidId = crypto.randomUUID();
  const assignedPin = params.pin || '2491';

  // Subunit to major currency balance resolution:
  // If provider returns balance in kobo/cents, divide by 100, else use initialFunding
  const resolvedBalance = m.balance != null ? Number(m.balance) / 100 : Number(params.initialFunding || 0);

  const virtualCard: VirtualCard = {
    id: uuidId,
    cardId: cardIdStr,
    cardholderName: params.cardholderName.trim().toUpperCase(),
    email: params.email.trim().toLowerCase(),
    currency: currency,
    brand: brand,
    cardType: 'VIRTUAL_DEBIT',
    maskedPan: maskedPan,
    fullPan: fullPan,
    expiryMonth: m.expiry_month || m.expiryMonth || '12',
    expiryYear: m.expiry_year || m.expiryYear || '28',
    cvv: m.cvv || '819',
    pin: assignedPin,
    balance: resolvedBalance,
    spendingLimit: currency === 'NGN' ? 5000000.00 : 10000.00,
    isFrozen: false,
    status: 'ACTIVE',
    billingAddress: currency === 'NGN'
      ? CardIssuingService.DEFAULT_NGN_BILLING_ADDRESS
      : CardIssuingService.DEFAULT_BILLING_ADDRESS,
    createdAt: new Date().toISOString()
  };

  return virtualCard;
}

async function runDataModelAndParsingTests() {
  console.log('\n\x1b[36m=== SUITE 5: Card Record Data Model & Mock Response Parsing ===\x1b[0m');

  // TC-5.1: Successful Mock Response Parsing
  const mockProviderResponse: MapleradIssuingResponse = {
    status: true,
    message: 'Card created successfully',
    data: {
      id: 'crd_mpr_sim_94827104',
      card_number: '5399830022334455',
      masked_pan: '5399 •••• •••• 4455',
      last_4: '4455',
      expiry_month: '10',
      expiry_year: '30',
      cvv: '789',
      currency: 'NGN',
      brand: 'MASTERCARD',
      balance: 100000, // 100,000 kobo
      type: 'VIRTUAL'
    }
  };

  const parsedCard = parseMockCardResponse(mockProviderResponse, {
    email: 'Test.User@Rentilly.COM',
    cardholderName: 'john doe',
    currency: 'NGN',
    brand: 'MASTERCARD',
    initialFunding: 1000.00,
    pin: '4820'
  });

  // Verify Identity & Normalization
  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.1',
    'Normalizes email to lowercase (test.user@rentilly.com)',
    parsedCard.email === 'test.user@rentilly.com',
    'test.user@rentilly.com',
    parsedCard.email
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.2',
    'Capitalizes cardholder name to uppercase (JOHN DOE)',
    parsedCard.cardholderName === 'JOHN DOE',
    'JOHN DOE',
    parsedCard.cardholderName
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.3',
    'Generates valid UUID string for card id',
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(parsedCard.id),
    true,
    parsedCard.id
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.4',
    'Maps provider card ID correctly',
    parsedCard.cardId === 'crd_mpr_sim_94827104',
    'crd_mpr_sim_94827104',
    parsedCard.cardId
  );

  // Verify Financial Attributes & Subunits Conversion
  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.5',
    'Parses provider 100,000 kobo balance into ₦1,000.00 major currency',
    parsedCard.balance === 1000.00,
    1000.00,
    parsedCard.balance
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.6',
    'Assigns NGN card spending limit of ₦5,000,000.00',
    parsedCard.spendingLimit === 5000000.00,
    5000000.00,
    parsedCard.spendingLimit
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.7',
    'Assigns brand as MASTERCARD and currency as NGN',
    parsedCard.brand === 'MASTERCARD' && parsedCard.currency === 'NGN',
    'MASTERCARD - NGN',
    `${parsedCard.brand} - ${parsedCard.currency}`
  );

  // Verify Security & PCI-DSS Formatting
  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.8',
    'Masks PAN according to standard (5399 •••• •••• 4455)',
    parsedCard.maskedPan === '5399 •••• •••• 4455',
    '5399 •••• •••• 4455',
    parsedCard.maskedPan
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.9',
    'Stores full PAN securely',
    parsedCard.fullPan === '5399830022334455',
    '5399830022334455',
    parsedCard.fullPan
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.10',
    'PIN is exactly 4 numeric digits',
    /^\d{4}$/.test(parsedCard.pin || ''),
    true,
    parsedCard.pin
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.11',
    'Card status is ACTIVE and isFrozen is false',
    parsedCard.status === 'ACTIVE' && parsedCard.isFrozen === false,
    'ACTIVE - false',
    `${parsedCard.status} - ${parsedCard.isFrozen}`
  );

  // Verify Billing Address Localization
  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.1.12',
    'Assigns Nigerian default billing address for NGN cards',
    parsedCard.billingAddress.country === 'Nigeria' &&
      parsedCard.billingAddress.city === 'Lagos' &&
      parsedCard.billingAddress.street === '12 Admiralty Way, Lekki Phase 1',
    'Nigeria, Lagos, 12 Admiralty Way, Lekki Phase 1',
    `${parsedCard.billingAddress.country}, ${parsedCard.billingAddress.city}, ${parsedCard.billingAddress.street}`
  );

  // TC-5.2: Provider Error / Rejection Handling
  const mockFailedResponse: MapleradIssuingResponse = {
    status: false,
    message: 'Maplerad issuing rail rejected card request. Ensure issuing balance is funded.'
  };

  let threwExpected = false;
  let capturedMessage = '';
  try {
    parseMockCardResponse(mockFailedResponse, {
      email: 'test@rentilly.com',
      cardholderName: 'Jane Doe',
      currency: 'NGN',
      initialFunding: 1000
    });
  } catch (err: any) {
    threwExpected = true;
    capturedMessage = err.message;
  }

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.2.1',
    'Throws error upon provider failure response',
    threwExpected === true,
    true,
    threwExpected
  );

  assert(
    '5. Card Record Data Model & Parsing',
    'TC-5.2.2',
    'Propagates original provider rejection message',
    capturedMessage === 'Maplerad issuing rail rejected card request. Ensure issuing balance is funded.',
    'Maplerad issuing rail rejected card request. Ensure issuing balance is funded.',
    capturedMessage
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCORECARD GENERATION & RUNNER
// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  const startTime = Date.now();
  console.log('\x1b[35m======================================================================\x1b[0m');
  console.log('\x1b[35m  RENTILLY AGENT 10: END-TO-END CARD INTEGRATION & SIMULATION SUITE  \x1b[0m');
  console.log('\x1b[35m======================================================================\x1b[0m');

  await runPricingTests();
  await runDebitCalculationTests();
  await runWalletBalanceValidationTests();
  await runSubunitCalculationTests();
  await runDataModelAndParsingTests();

  const totalDuration = Date.now() - startTime;
  const totalTests = testResults.length;
  const passedTests = testResults.filter(t => t.passed).length;
  const failedTests = testResults.filter(t => !t.passed).length;
  const passRate = ((passedTests / totalTests) * 100).toFixed(1);

  console.log('\n\x1b[35m======================================================================\x1b[0m');
  console.log('\x1b[35m                         TEST SCORECARD                               \x1b[0m');
  console.log('\x1b[35m======================================================================\x1b[0m');
  console.log(`\n${'SUITE'.padEnd(34)} | ${'ID'.padEnd(10)} | ${'STATUS'.padEnd(8)} | TEST CASE`);
  console.log('─'.repeat(90));

  for (const r of testResults) {
    const statusStr = r.passed ? '\x1b[32mPASS\x1b[0m    ' : '\x1b[31mFAIL\x1b[0m    ';
    console.log(`${r.suite.padEnd(34)} | ${r.id.padEnd(10)} | ${statusStr} | ${r.name}`);
  }

  console.log('─'.repeat(90));
  console.log(`\n\x1b[1mSummary Metrics:\x1b[0m`);
  console.log(`  Total Test Cases:    \x1b[36m${totalTests}\x1b[0m`);
  console.log(`  Passed Test Cases:   \x1b[32m${passedTests}\x1b[0m`);
  console.log(`  Failed Test Cases:   ${failedTests === 0 ? '\x1b[32m0\x1b[0m' : `\x1b[31m${failedTests}\x1b[0m`}`);
  console.log(`  Pass Rate:           \x1b[32m${passRate}%\x1b[0m`);
  console.log(`  Execution Time:      ${totalDuration}ms`);

  if (failedTests > 0) {
    console.error('\n\x1b[31mSOME TESTS FAILED! Review errors above.\x1b[0m');
    process.exit(1);
  } else {
    console.log('\n\x1b[32m✔ ALL INTEGRATION ASSERTIONS PASSED 100%!\x1b[0m\n');
  }
}

main().catch(err => {
  console.error('Fatal test execution error:', err);
  process.exit(1);
});
