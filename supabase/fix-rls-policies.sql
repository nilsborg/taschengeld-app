-- Fix RLS policies for profile creation
-- This addresses the "new row violates row-level security policy" error

-- First, let's see what policies currently exist
SELECT policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'profiles';

-- Drop all existing policies on profiles table
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Allow profile creation" ON profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON profiles;

-- Temporarily disable RLS to allow initial setup
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create comprehensive RLS policies for profiles

-- 1. Allow users to view their own profile
CREATE POLICY "profiles_select_own" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- 2. Allow users to insert their own profile (for signup)
CREATE POLICY "profiles_insert_own" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 3. Allow users to update their own profile
CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 4. Allow service role to do everything (for admin functions)
CREATE POLICY "profiles_service_role_all" ON profiles
    FOR ALL USING (current_setting('role') = 'service_role');

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON profiles TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Test the policies by attempting a manual profile creation
DO $$
DECLARE
    test_id UUID := gen_random_uuid();
    test_email TEXT := 'rls_test_' || extract(epoch from now()) || '@example.com';
BEGIN
    -- Note: This test won't work because we don't have auth.uid() context in DO blocks
    -- But we can test the table structure
    RAISE NOTICE 'RLS policies updated for profiles table';
    RAISE NOTICE 'Profiles table is ready for manual profile creation from authenticated users';
END $$;

-- Show final policies
SELECT 'Final RLS policies for profiles:' as info;
SELECT policyname, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY policyname;

-- Verify table permissions
SELECT 'Permissions granted to authenticated role' as info;
SELECT privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name = 'profiles' AND grantee = 'authenticated';

SELECT 'RLS policies fixed. Try user signup again.' as result;