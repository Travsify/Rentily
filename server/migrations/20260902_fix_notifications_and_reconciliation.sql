-- ============================================================
-- Rentilly Supabase Migration: Notifications + Reconciliation
-- Run this SQL in: Supabase Dashboard → SQL Editor → Run
-- ============================================================

-- 1. reconciled_transactions table
-- Prevents the server from re-crediting users on restart
CREATE TABLE IF NOT EXISTS public.reconciled_transactions (
  flw_ref TEXT PRIMARY KEY,
  user_id TEXT,
  email TEXT,
  amount NUMERIC,
  processed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Mark existing 3 Flutterwave transactions as already processed
INSERT INTO public.reconciled_transactions (flw_ref, user_id, email, amount) VALUES
  ('100004260902142253170089915568', 'b0000000-0000-0000-0000-000000000001', 'patrickachua3@gmail.com', 5000),
  ('100004260902135555170088528786', 'c0000000-0000-0000-0000-000000000001', 'tonerocool1@gmail.com', 2000),
  ('100004260901232426170038034521', 'c0000000-0000-0000-0000-000000000001', 'tonerocool1@gmail.com', 2000)
ON CONFLICT (flw_ref) DO NOTHING;

-- 2. notifications table (in-app notifications)
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  title TEXT NOT NULL,
  category TEXT DEFAULT 'general',
  message TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Service role can insert
DROP POLICY IF EXISTS "Service role insert notifications" ON public.notifications;
CREATE POLICY "Service role insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

-- 3. wallet_transactions table (user-facing wallet history)
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  email TEXT,
  amount NUMERIC NOT NULL,
  type TEXT DEFAULT 'credit',
  status TEXT DEFAULT 'completed',
  flw_ref TEXT UNIQUE,
  tx_ref TEXT,
  narration TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_txns_user_id ON public.wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_txns_email ON public.wallet_transactions(email);

-- 4. Add onesignal_player_id column to profiles for push notifications
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS onesignal_player_id TEXT;

-- 5. Fix wallet balances
-- tonerocool received: 2x ₦2,000 from TOMISIN = ₦4,000 (correct)
UPDATE public.profiles SET wallet_balance = 4000, updated_at = NOW()
WHERE id = 'c0000000-0000-0000-0000-000000000001';

-- Patrick received: ₦5,000 from himself to 9254090338 (correct)
UPDATE public.profiles SET wallet_balance = 5000, updated_at = NOW()
WHERE id = 'b0000000-0000-0000-0000-000000000001';

-- 6. Record wallet transactions for both users
INSERT INTO public.wallet_transactions (user_id, email, amount, type, status, flw_ref, tx_ref, narration, created_at)
VALUES
  (
    'b0000000-0000-0000-0000-000000000001',
    'patrickachua3@gmail.com',
    5000,
    'credit',
    'completed',
    '100004260902142253170089915568',
    'RENTILLY_ACC_usr_1788303582852_zgemh_1788303812582',
    'Bank Transfer from PATRICK OTU ACHUA via OPAY to account 9254090338',
    '2026-09-02T14:22:55.000Z'
  ),
  (
    'c0000000-0000-0000-0000-000000000001',
    'tonerocool1@gmail.com',
    2000,
    'credit',
    'completed',
    '100004260902135555170088528786',
    'RENTILLY_ACC_usr_1788303582852_zgemh_1788303812582',
    'Bank Transfer from TOMISIN OLAMIPO KOLAWOLE via OPAY',
    '2026-09-02T13:55:57.000Z'
  ),
  (
    'c0000000-0000-0000-0000-000000000001',
    'tonerocool1@gmail.com',
    2000,
    'credit',
    'completed',
    '100004260901232426170038034521',
    'RENTILLY_ACC_usr_1788303582852_zgemh_1788303812582',
    'Bank Transfer from TOMISIN OLAMIPO KOLAWOLE via OPAY',
    '2026-09-01T23:24:29.000Z'
  )
ON CONFLICT (flw_ref) DO NOTHING;

-- Done! Verify:
SELECT id, email, wallet_balance, account_number FROM public.profiles
WHERE id IN ('b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001');
