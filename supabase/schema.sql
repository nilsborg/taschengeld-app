-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create kids table
CREATE TABLE kids (
    id BIGSERIAL PRIMARY KEY,
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
CREATE INDEX idx_kids_name ON kids(name);
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

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_kids_updated_at 
    BEFORE UPDATE ON kids 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert initial data for Louis (optional - can be done via the app)
INSERT INTO kids (name, weekly_allowance, interest_rate, current_balance) 
VALUES ('Louis', 10.00, 0.01, 0.00)
ON CONFLICT DO NOTHING;

-- Enable Row Level Security (RLS) - for future multi-user support
ALTER TABLE kids ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- For now, allow all operations (we'll restrict this when we add auth)
CREATE POLICY "Allow all operations on kids" ON kids FOR ALL USING (true);
CREATE POLICY "Allow all operations on transactions" ON transactions FOR ALL USING (true);

-- Grant necessary permissions to authenticated users
GRANT ALL ON kids TO authenticated;
GRANT ALL ON transactions TO authenticated;
GRANT ALL ON kids TO anon;
GRANT ALL ON transactions TO anon;

-- Grant usage on sequences
GRANT USAGE, SELECT ON SEQUENCE kids_id_seq TO authenticated, anon;
GRANT USAGE, SELECT ON SEQUENCE transactions_id_seq TO authenticated, anon;