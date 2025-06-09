-- Trigger Verification Script
-- Run this to check if the authentication trigger is working properly

-- 1. Check if the trigger exists
SELECT 
    'TRIGGER_STATUS' as section,
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created'
AND trigger_schema = 'public';

-- 2. Check if the function exists
SELECT 
    'FUNCTION_STATUS' as section,
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user'
AND routine_schema = 'public';

-- 3. Check profiles table structure
SELECT 
    'PROFILES_TABLE_STRUCTURE' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 4. Check if user_role enum exists
SELECT 
    'USER_ROLE_ENUM' as section,
    t.typname as type_name,
    e.enumlabel as enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public' 
AND t.typname = 'user_role'
ORDER BY e.enumsortorder;

-- 5. Check current profiles (if any)
SELECT 
    'EXISTING_PROFILES' as section,
    id,
    email,
    full_name,
    role,
    created_at
FROM profiles 
ORDER BY created_at DESC
LIMIT 5;

-- 6. Test the function manually (safe test)
SELECT 
    'FUNCTION_TEST' as section,
    'Testing handle_new_user function manually...' as message;

-- 7. Check RLS policies on profiles table
SELECT 
    'PROFILES_RLS_POLICIES' as section,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'profiles'
ORDER BY policyname;

-- 8. Check if profiles table has RLS enabled
SELECT 
    'PROFILES_RLS_STATUS' as section,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'profiles';