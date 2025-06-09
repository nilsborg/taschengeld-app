-- Migration: Add new transaction types for settings changes
-- This migration adds 'allowance_change' and 'interest_rate_change' transaction types

-- Update the transaction type check constraint to include new types
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_type_check 
    CHECK (type IN ('weekly_allowance', 'interest', 'withdrawal', 'allowance_change', 'interest_rate_change'));

-- Add a comment to document the new transaction types
COMMENT ON COLUMN transactions.type IS 'Transaction type: weekly_allowance, interest, withdrawal, allowance_change, interest_rate_change';

-- Note: For settings change transactions:
-- - allowance_change: amount field contains the new allowance value
-- - interest_rate_change: amount field contains the new interest rate (as decimal)
-- - description field contains details about the change (old value -> new value)