-- Bypass trigger approach for signup issues
-- This temporarily disables the problematic trigger and handles profile creation in the app

-- 1. Disable the existing trigger temporarily
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Create a simplified manual profile creation approach
-- Remove the trigger function dependency

-- 3. Update RLS policies to allow manual profile creation
DROP POLICY IF EXISTS "Allow profile creation" ON profiles;

-- Allow authenticated users to insert their own profile
CREATE POLICY "Users can create their own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 4. Grant explicit permissions for profile creation
GRANT INSERT ON profiles TO authenticated;
GRANT SELECT ON profiles TO authenticated;
GRANT UPDATE ON profiles TO authenticated;

-- 5. Ensure the profiles table structure is correct
DO $$
BEGIN
    -- Make sure all required columns exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'id'
    ) THEN
        ALTER TABLE profiles ADD COLUMN id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'email'
    ) THEN
        ALTER TABLE profiles ADD COLUMN email TEXT NOT NULL;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'full_name'
    ) THEN
        ALTER TABLE profiles ADD COLUMN full_name TEXT;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'role'
    ) THEN
        ALTER TABLE profiles ADD COLUMN role user_role NOT NULL DEFAULT 'kid';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE profiles ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE profiles ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    END IF;
    
    RAISE NOTICE 'Profiles table structure verified';
END $$;

-- 6. Test manual profile creation
DO $$
DECLARE
    test_id UUID := gen_random_uuid();
    test_email TEXT := 'bypass_test_' || extract(epoch from now()) || '@example.com';
BEGIN
    RAISE NOTICE 'Testing manual profile creation without trigger...';
    
    -- Test direct insertion
    INSERT INTO profiles (id, email, full_name, role, created_at, updated_at)
    VALUES (test_id, test_email, 'Bypass Test User', 'kid', NOW(), NOW());
    
    RAISE NOTICE 'Manual profile creation: SUCCESS';
    
    -- Clean up
    DELETE FROM profiles WHERE id = test_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Manual profile creation FAILED: % - %', SQLSTATE, SQLERRM;
        -- Clean up
        BEGIN
            DELETE FROM profiles WHERE id = test_id;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
END $$;

-- 7. Create a simple function for manual profile creation (optional)
CREATE OR REPLACE FUNCTION create_user_profile(
    user_id UUID,
    user_email TEXT,
    user_full_name TEXT DEFAULT '',
    user_role user_role DEFAULT 'kid'
) RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO profiles (id, email, full_name, role, created_at, updated_at)
    VALUES (user_id, user_email, user_full_name, user_role, NOW(), NOW());
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Failed to create profile for %: % %', user_id, SQLERRM, SQLSTATE;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION create_user_profile TO authenticated;

SELECT 'Bypass trigger setup completed. Signup should now work with manual profile creation.' as result;