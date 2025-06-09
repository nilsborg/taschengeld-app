-- Manual Profile Creation Helper Script
-- Use this if the automatic trigger isn't working for profile creation

-- Function to manually create a profile for an existing auth user
CREATE OR REPLACE FUNCTION create_profile_for_user(
    user_email TEXT,
    user_full_name TEXT DEFAULT NULL,
    user_role user_role DEFAULT 'kid'
)
RETURNS TEXT AS $$
DECLARE
    user_id UUID;
    profile_exists BOOLEAN;
    result_message TEXT;
BEGIN
    -- Find the user ID from auth.users
    SELECT id INTO user_id 
    FROM auth.users 
    WHERE email = user_email;
    
    IF user_id IS NULL THEN
        RETURN 'ERROR: User with email ' || user_email || ' not found in auth.users';
    END IF;
    
    -- Check if profile already exists
    SELECT EXISTS(
        SELECT 1 FROM profiles WHERE id = user_id
    ) INTO profile_exists;
    
    IF profile_exists THEN
        RETURN 'SKIP: Profile already exists for user ' || user_email;
    END IF;
    
    -- Create the profile
    INSERT INTO profiles (id, email, full_name, role)
    VALUES (user_id, user_email, user_full_name, user_role);
    
    RETURN 'SUCCESS: Profile created for user ' || user_email || ' with role ' || user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Example usage (uncomment and modify as needed):
-- SELECT create_profile_for_user('parent@example.com', 'Parent User', 'parent');
-- SELECT create_profile_for_user('kid@example.com', 'Kid User', 'kid');

-- Check current auth users without profiles
SELECT 
    'USERS_WITHOUT_PROFILES' as section,
    au.id,
    au.email,
    au.created_at as user_created,
    CASE 
        WHEN p.id IS NULL THEN 'MISSING PROFILE'
        ELSE 'HAS PROFILE'
    END as profile_status
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
ORDER BY au.created_at DESC;

-- Bulk create profiles for all auth users that don't have them
-- (This will create 'kid' profiles by default - you can update roles afterward)
INSERT INTO profiles (id, email, full_name, role)
SELECT 
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'full_name', 'User'),
    COALESCE((au.raw_user_meta_data->>'role')::user_role, 'kid')
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- Show results after bulk creation
SELECT 
    'PROFILES_AFTER_CREATION' as section,
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN role = 'parent' THEN 1 END) as parent_count,
    COUNT(CASE WHEN role = 'kid' THEN 1 END) as kid_count
FROM profiles;

-- Display all current profiles
SELECT 
    'ALL_PROFILES' as section,
    id,
    email,
    full_name,
    role,
    created_at
FROM profiles
ORDER BY created_at DESC;