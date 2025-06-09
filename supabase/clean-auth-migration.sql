-- Safe Authentication Migration for Existing Taschengeld Database
-- This adds authentication to your existing kids and transactions tables

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom user roles enum (only if it doesn't exist)
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('parent', 'kid');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create profiles table (only if it doesn't exist)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    role user_role NOT NULL DEFAULT 'kid',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add user_id column to existing kids table (only if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'kids' AND column_name = 'user_id') THEN
        ALTER TABLE kids ADD COLUMN user_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create indexes for better performance (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_kids_name ON kids(name);
CREATE INDEX IF NOT EXISTS idx_kids_user_id ON kids(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_kid_id ON transactions(kid_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for profiles table (only if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_profiles_updated_at') THEN
        CREATE TRIGGER update_profiles_updated_at 
            BEFORE UPDATE ON profiles 
            FOR EACH ROW 
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, full_name, role)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name', 
            COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'kid'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to create profile on user signup (replace if exists)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Enable Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE kids ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
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

-- Kids policies
CREATE POLICY "Kids can view their own data" ON kids
    FOR SELECT USING (
        user_id = auth.uid() OR 
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        ) OR
        user_id IS NULL  -- Allow access to legacy records (like Louis)
    );

CREATE POLICY "Only parents can modify kids data" ON kids
    FOR ALL USING (
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
            WHERE id = transactions.kid_id AND (user_id = auth.uid() OR user_id IS NULL)
        ) OR
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

CREATE POLICY "Kids can create withdrawals for themselves" ON transactions
    FOR INSERT WITH CHECK (
        type = 'withdrawal' AND
        (EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND user_id = auth.uid()
        ) OR 
        -- Allow withdrawals for legacy records (kids without user_id)
        EXISTS (
            SELECT 1 FROM kids 
            WHERE id = transactions.kid_id AND user_id IS NULL
        ))
    );

CREATE POLICY "Parents can create any transaction" ON transactions
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'parent'
        )
    );

-- Grant necessary permissions to authenticated users
GRANT ALL ON profiles TO authenticated;
GRANT ALL ON kids TO authenticated;
GRANT ALL ON transactions TO authenticated;

-- Grant usage on sequences
GRANT USAGE, SELECT ON SEQUENCE kids_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE transactions_id_seq TO authenticated;

-- Display success message
SELECT 'Authentication migration completed successfully!' as status;
SELECT 'You can now create parent and kid accounts via the app' as next_step;
SELECT 'Existing Louis record will remain accessible to all users until linked' as note;