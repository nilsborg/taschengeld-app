-- Migration: Add parent_id to kids table to establish parent-child relationships
-- This migration adds a parent_id column to the kids table and updates RLS policies

-- Add parent_id column to kids table
ALTER TABLE kids ADD COLUMN parent_id UUID REFERENCES profiles(id) ON DELETE CASCADE;

-- Create index for better performance
CREATE INDEX idx_kids_parent_id ON kids(parent_id);

-- Update existing kids to have a parent_id (assign to first parent user if any exists)
-- This is for backward compatibility with existing data
UPDATE kids 
SET parent_id = (
    SELECT id FROM profiles 
    WHERE role = 'parent' 
    ORDER BY created_at 
    LIMIT 1
)
WHERE parent_id IS NULL 
AND EXISTS (SELECT 1 FROM profiles WHERE role = 'parent');

-- Drop existing RLS policies for kids and transactions
DROP POLICY IF EXISTS "Kids can view their own data" ON kids;
DROP POLICY IF EXISTS "Only parents can modify kids data" ON kids;
DROP POLICY IF EXISTS "Kids can view their own transactions" ON transactions;
DROP POLICY IF EXISTS "Kids can create withdrawals for themselves" ON transactions;
DROP POLICY IF EXISTS "Parents can create any transaction" ON transactions;

-- Create new RLS policies with proper parent-child relationships

-- Kids policies
CREATE POLICY "Kids can view their own profile" ON kids
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Parents can view their own kids" ON kids
    FOR SELECT USING (
        parent_id = auth.uid() AND 
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

CREATE POLICY "Parents can create kids" ON kids
    FOR INSERT WITH CHECK (
        parent_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

CREATE POLICY "Parents can update their own kids" ON kids
    FOR UPDATE USING (
        parent_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

CREATE POLICY "Parents can delete their own kids" ON kids
    FOR DELETE USING (
        parent_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

-- Transactions policies
CREATE POLICY "Kids can view their own transactions" ON transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Parents can view transactions of their kids" ON transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND parent_id = auth.uid()
        ) AND
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

CREATE POLICY "Kids can create withdrawals for themselves" ON transactions
    FOR INSERT WITH CHECK (
        type = 'withdrawal' AND
        EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Parents can create any transaction for their kids" ON transactions
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND parent_id = auth.uid()
        ) AND
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

-- Update the NewKid interface comment for documentation
COMMENT ON COLUMN kids.parent_id IS 'References the parent profile who manages this kid';
COMMENT ON TABLE kids IS 'Kids managed by parents, with proper parent-child relationships';