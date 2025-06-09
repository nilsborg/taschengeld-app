-- Fix RLS Policies for Taschengeld App
-- This script fixes the Row Level Security policies to allow proper access

-- Drop all existing policies first to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Kids can view their own data" ON kids;
DROP POLICY IF EXISTS "Only parents can modify kids data" ON kids;
DROP POLICY IF EXISTS "Kids can view their own transactions" ON transactions;
DROP POLICY IF EXISTS "Kids can create withdrawals for themselves" ON transactions;
DROP POLICY IF EXISTS "Parents can create any transaction" ON transactions;
DROP POLICY IF EXISTS "Allow all operations on kids" ON kids;
DROP POLICY IF EXISTS "Allow all operations on transactions" ON transactions;

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Kids policies - more permissive for initial setup
CREATE POLICY "Kids can view accessible data" ON kids
    FOR SELECT USING (
        -- Kids can see their own linked records
        user_id = auth.uid() OR
        -- Parents can see all records
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        ) OR
        -- Allow access to unlinked records (like original Louis)
        user_id IS NULL
    );

CREATE POLICY "Kids can create their own record" ON kids
    FOR INSERT WITH CHECK (
        -- Kids can create records for themselves
        user_id = auth.uid() OR
        -- Parents can create records for anyone
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

CREATE POLICY "Kids can update their own data" ON kids
    FOR UPDATE USING (
        -- Kids can update their own records
        user_id = auth.uid() OR
        -- Parents can update any record
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

CREATE POLICY "Parents can delete kids data" ON kids
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

-- Transactions policies - allow kids to withdraw, parents to do everything
CREATE POLICY "View transactions" ON transactions
    FOR SELECT USING (
        -- Kids can see transactions for their linked kids records
        EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND user_id = auth.uid()
        ) OR
        -- Parents can see all transactions
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        ) OR
        -- Allow viewing transactions for unlinked kids (like Louis)
        EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND user_id IS NULL
        )
    );

CREATE POLICY "Kids can create withdrawals" ON transactions
    FOR INSERT WITH CHECK (
        -- Kids can only create withdrawal transactions for themselves
        (type = 'withdrawal' AND EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND user_id = auth.uid()
        )) OR
        -- Parents can create any transaction
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        ) OR
        -- Allow withdrawals for unlinked kids (temporary for Louis)
        (type = 'withdrawal' AND EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND user_id IS NULL
        ))
    );

-- Grant broad permissions to authenticated users (RLS will control access)
GRANT ALL ON profiles TO authenticated;
GRANT ALL ON kids TO authenticated;
GRANT ALL ON transactions TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Display success message
SELECT 'RLS policies updated successfully!' as status;
SELECT 'Kids can now create their own records and make withdrawals' as note;
SELECT 'Parents can manage all data' as note2;