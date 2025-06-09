-- Simple diagnostic for signup issues
-- This will show clear results for each check

-- Check 1: Profiles table exists
SELECT 'CHECK 1: Profiles table' as test;
SELECT CASE WHEN COUNT(*) > 0 THEN 'PASS: profiles table exists' ELSE 'FAIL: profiles table missing' END as result
FROM information_schema.tables 
WHERE table_name = 'profiles';

-- Check 2: User role enum exists
SELECT 'CHECK 2: User role enum' as test;
SELECT CASE WHEN COUNT(*) > 0 THEN 'PASS: user_role enum exists' ELSE 'FAIL: user_role enum missing' END as result
FROM pg_type WHERE typname = 'user_role';

-- Check 3: Trigger function exists
SELECT 'CHECK 3: Trigger function' as test;
SELECT CASE WHEN COUNT(*) > 0 THEN 'PASS: handle_new_user function exists' ELSE 'FAIL: handle_new_user function missing' END as result
FROM pg_proc WHERE proname = 'handle_new_user';

-- Check 4: Trigger exists and enabled
SELECT 'CHECK 4: Trigger status' as test;
SELECT CASE 
    WHEN COUNT(*) = 0 THEN 'FAIL: on_auth_user_created trigger missing'
    WHEN COUNT(*) > 0 AND bool_and(tgenabled = 'O') THEN 'PASS: trigger exists and enabled'
    ELSE 'FAIL: trigger exists but disabled'
END as result
FROM pg_trigger WHERE tgname = 'on_auth_user_created';

-- Check 5: RLS enabled on profiles
SELECT 'CHECK 5: RLS on profiles' as test;
SELECT CASE WHEN relrowsecurity THEN 'PASS: RLS enabled' ELSE 'FAIL: RLS disabled' END as result
FROM pg_class WHERE relname = 'profiles';

-- Check 6: Essential RLS policies exist
SELECT 'CHECK 6: RLS policies' as test;
SELECT CASE 
    WHEN COUNT(*) >= 2 THEN 'PASS: Essential policies exist (' || COUNT(*) || ' policies found)'
    ELSE 'FAIL: Missing essential policies (only ' || COUNT(*) || ' policies found)'
END as result
FROM pg_policies 
WHERE tablename = 'profiles' AND policyname IN ('Users can view their own profile', 'Allow profile creation', 'Users can create their own profile');

-- Check 7: Profiles table structure
SELECT 'CHECK 7: Profiles columns' as test;
SELECT 'Column: ' || column_name || ' (' || data_type || ')' as profiles_structure
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY ordinal_position;

-- Check 8: Test manual profile creation
SELECT 'CHECK 8: Manual profile test' as test;
DO $$
DECLARE
    test_id UUID := '00000000-0000-0000-0000-000000000001'::UUID;
BEGIN
    -- Try to insert a test profile
    INSERT INTO profiles (id, email, full_name, role)
    VALUES (test_id, 'diagnostic@test.com', 'Test User', 'kid');
    
    -- If we get here, it worked
    RAISE NOTICE 'PASS: Manual profile creation works';
    
    -- Clean up
    DELETE FROM profiles WHERE id = test_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'FAIL: Manual profile creation failed - % %', SQLSTATE, SQLERRM;
        -- Clean up attempt
        BEGIN
            DELETE FROM profiles WHERE id = test_id;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
END $$;

SELECT 'DIAGNOSTIC COMPLETE - Check messages above for PASS/FAIL results' as final_result;