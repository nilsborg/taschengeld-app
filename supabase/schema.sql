-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom user roles enum
CREATE TYPE user_role AS ENUM ('parent', 'kid');

-- Create profiles table to extend Supabase auth.users
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    role user_role NOT NULL DEFAULT 'kid',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create kids table
CREATE TABLE kids (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL, -- Link to user profile (nullable for existing data)
    name TEXT NOT NULL,
    weekly_allowance DECIMAL(10,2) NOT NULL DEFAULT 0,
    interest_rate DECIMAL(5,4) NOT NULL DEFAULT 0, -- Monthly interest rate as decimal (e.g., 0.01 for 1%)
    current_balance DECIMAL(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create transactions table
CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    kid_id BIGINT NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('weekly_allowance', 'interest', 'withdrawal')),
    amount DECIMAL(10,2) NOT NULL, -- Positive for income, negative for withdrawals
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_kids_name ON kids(name);
CREATE INDEX idx_kids_user_id ON kids(user_id);
CREATE INDEX idx_transactions_kid_id ON transactions(kid_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX idx_transactions_type ON transactions(type);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_kids_updated_at 
    BEFORE UPDATE ON kids 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

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

-- Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Insert initial data for Louis (optional - can be done via the app)
INSERT INTO kids (name, weekly_allowance, interest_rate, current_balance) 
VALUES ('Louis', 10.00, 0.01, 0.00)
ON CONFLICT DO NOTHING;

-- Enable Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE kids ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

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
        )
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
            WHERE id = transactions.kid_id AND user_id = auth.uid()
        ) OR
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