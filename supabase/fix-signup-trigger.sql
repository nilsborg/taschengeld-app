-- Fix signup trigger issues
-- This script diagnoses and fixes user signup problems

-- First, let's check if the trigger function exists
SELECT proname, prosrc FROM pg_proc WHERE proname = 'handle_new_user';

-- Check if the trigger exists
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'on_auth_user_created';

-- Check profiles table structure
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY ordinal_position;

-- Check if user_role enum exists, if not create it
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('parent', 'kid');
        RAISE NOTICE 'Created user_role enum';
    ELSE
        RAISE NOTICE 'user_role enum already exists';
    END IF;
END $$;

-- Ensure profiles table has correct structure
DO $$
BEGIN
    -- Check if role column exists with correct type
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'role' 
        AND data_type = 'USER-DEFINED'
    ) THEN
        -- Add role column if it doesn't exist
        ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role user_role NOT NULL DEFAULT 'kid';
        RAISE NOTICE 'Added role column to profiles table';
    ELSE
        RAISE NOTICE 'Role column already exists';
    END IF;
END $$;

-- Drop and recreate the trigger function with better error handling
CREATE OR REPLACE FUNCTION handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
    -- Insert into profiles with error handling
    INSERT INTO profiles (id, email, full_name, role)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'kid')
    );
    
    -- Log successful profile creation
    RAISE NOTICE 'Profile created for user: %', NEW.id;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error details
        RAISE LOG 'Error in handle_new_user for user %: % %', NEW.id, SQLERRM, SQLSTATE;
        -- Re-raise the exception to prevent user creation
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Recreate the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Test the function with a mock user
DO $$
DECLARE
    test_user_id UUID := gen_random_uuid();
BEGIN
    -- This is just a test - we won't actually insert into auth.users
    RAISE NOTICE 'Testing profile creation logic...';
    
    -- Test profile insertion directly
    INSERT INTO profiles (id, email, full_name, role)
    VALUES (test_user_id, 'test@example.com', 'Test User', 'kid');
    
    -- Clean up test data
    DELETE FROM profiles WHERE id = test_user_id;
    
    RAISE NOTICE 'Profile creation test completed successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Profile creation test failed: % %', SQLERRM, SQLSTATE;
        -- Clean up any partial test data
        DELETE FROM profiles WHERE id = test_user_id;
END $$;

-- Check RLS policies on profiles table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'profiles';

-- Ensure basic RLS policies exist for profiles
DO $$
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
    DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
    DROP POLICY IF EXISTS "Allow profile creation" ON profiles;
    
    -- Create basic RLS policies
    CREATE POLICY "Users can view their own profile" ON profiles
        FOR SELECT USING (auth.uid() = id);
    
    CREATE POLICY "Users can update their own profile" ON profiles
        FOR UPDATE USING (auth.uid() = id);
        
    -- Allow inserts for the trigger (SECURITY DEFINER function)
    CREATE POLICY "Allow profile creation" ON profiles
        FOR INSERT WITH CHECK (true);
        
    RAISE NOTICE 'RLS policies created for profiles table';
END $$;

-- Final verification
SELECT 'Trigger function exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as status
FROM pg_proc WHERE proname = 'handle_new_user';

SELECT 'Trigger exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as status
FROM pg_trigger WHERE tgname = 'on_auth_user_created';

SELECT 'Profiles table exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as status
FROM information_schema.tables WHERE table_name = 'profiles';

-- Show final state
SELECT 'Setup completed successfully. Try creating a new user now.' as message;