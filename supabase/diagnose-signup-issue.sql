-- Comprehensive signup issue diagnostic
-- Run this to identify what's preventing user registration

-- 1. Check if auth schema and users table exist
SELECT 'auth.users table exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as result
FROM information_schema.tables 
WHERE table_schema = 'auth' AND table_name = 'users';

-- 2. Check profiles table structure
SELECT 'profiles table structure:' as info;
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY ordinal_position;

-- 3. Check if user_role enum exists and its values
SELECT 'user_role enum exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as result
FROM pg_type WHERE typname = 'user_role';

SELECT enumlabel as user_role_values 
FROM pg_enum e 
JOIN pg_type t ON e.enumtypid = t.oid 
WHERE t.typname = 'user_role';

-- 4. Check trigger function
SELECT 'handle_new_user function exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as result
FROM pg_proc WHERE proname = 'handle_new_user';

-- Get function definition
SELECT prosrc as function_definition 
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- 5. Check trigger
SELECT 'on_auth_user_created trigger exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as result
FROM pg_trigger WHERE tgname = 'on_auth_user_created';

-- Check trigger details
SELECT t.tgname, t.tgenabled, p.proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgname = 'on_auth_user_created';

-- 6. Check RLS policies on profiles
SELECT 'RLS enabled on profiles: ' || CASE WHEN relrowsecurity THEN 'YES' ELSE 'NO' END as result
FROM pg_class WHERE relname = 'profiles';

SELECT policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'profiles';

-- 7. Test profile insertion manually
DO $$
DECLARE
    test_id UUID := gen_random_uuid();
    test_email TEXT := 'test_' || extract(epoch from now()) || '@example.com';
BEGIN
    RAISE NOTICE 'Testing manual profile insertion...';
    
    -- Try to insert a test profile
    INSERT INTO profiles (id, email, full_name, role)
    VALUES (test_id, test_email, 'Test User', 'kid');
    
    RAISE NOTICE 'Manual profile insertion: SUCCESS';
    
    -- Clean up
    DELETE FROM profiles WHERE id = test_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Manual profile insertion FAILED: % - %', SQLSTATE, SQLERRM;
        -- Try to clean up in case of partial insert
        BEGIN
            DELETE FROM profiles WHERE id = test_id;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
END $$;

-- 8. Check if there are any foreign key constraints that might be failing
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name = 'profiles';

-- 9. Check for any other triggers on auth.users that might be interfering
SELECT t.tgname, p.proname as function_name, t.tgenabled
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'auth' AND c.relname = 'users';

-- 10. Check recent error logs (if accessible)
-- Note: This might not work depending on permissions
SELECT 'Checking for recent errors in pg_stat_statements (if available)' as info;

-- 11. Final summary
SELECT 'DIAGNOSTIC COMPLETE - Check results above for issues' as summary;