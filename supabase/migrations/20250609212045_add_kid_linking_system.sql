-- Migration: Add kid linking functionality with invitation codes
-- This migration adds invitation codes and linking functionality for kids

-- Add invitation_code column to kids table for linking user accounts
ALTER TABLE kids ADD COLUMN invitation_code TEXT UNIQUE;

-- Add index for better performance on invitation code lookups
CREATE INDEX idx_kids_invitation_code ON kids(invitation_code);

-- Function to generate random invitation codes
CREATE OR REPLACE FUNCTION generate_invitation_code() RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Excluding confusing chars like I, O, 0, 1
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique invitation code for a kid
CREATE OR REPLACE FUNCTION set_invitation_code_for_kid(kid_id BIGINT) RETURNS TEXT AS $$
DECLARE
    new_code TEXT;
    code_exists BOOLEAN;
BEGIN
    LOOP
        new_code := generate_invitation_code();
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM kids WHERE invitation_code = new_code) INTO code_exists;
        
        -- If code doesn't exist, use it
        IF NOT code_exists THEN
            UPDATE kids SET invitation_code = new_code WHERE id = kid_id;
            RETURN new_code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create a table to track kid account linking requests
CREATE TABLE kid_linking_requests (
    id BIGSERIAL PRIMARY KEY,
    kid_id BIGINT NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES profiles(id),
    UNIQUE(kid_id, user_id)
);

-- Create indexes for linking requests
CREATE INDEX idx_kid_linking_requests_kid_id ON kid_linking_requests(kid_id);
CREATE INDEX idx_kid_linking_requests_user_id ON kid_linking_requests(user_id);
CREATE INDEX idx_kid_linking_requests_status ON kid_linking_requests(status);

-- Function to link a kid account using invitation code
CREATE OR REPLACE FUNCTION link_kid_account(code TEXT, user_profile_id UUID) RETURNS BOOLEAN AS $$
DECLARE
    kid_record RECORD;
    existing_link BOOLEAN;
BEGIN
    -- Find kid with this invitation code
    SELECT * INTO kid_record FROM kids WHERE invitation_code = code;
    
    -- If no kid found with this code, return false
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Check if kid is already linked to another user
    IF kid_record.user_id IS NOT NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Check if this user is already linked to another kid
    SELECT EXISTS(SELECT 1 FROM kids WHERE user_id = user_profile_id) INTO existing_link;
    IF existing_link THEN
        RETURN FALSE;
    END IF;
    
    -- Link the accounts
    UPDATE kids 
    SET user_id = user_profile_id, 
        invitation_code = NULL, -- Clear the code after use
        updated_at = NOW()
    WHERE id = kid_record.id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to request linking (for manual approval)
CREATE OR REPLACE FUNCTION request_kid_linking(kid_name TEXT, user_profile_id UUID) RETURNS BOOLEAN AS $$
DECLARE
    kid_record RECORD;
    existing_request BOOLEAN;
BEGIN
    -- Find unlinked kid with this name
    SELECT * INTO kid_record 
    FROM kids 
    WHERE LOWER(name) = LOWER(kid_name) 
    AND user_id IS NULL
    AND EXISTS (
        SELECT 1 FROM profiles p 
        WHERE p.id = (
            SELECT parent_id FROM kids k2 
            WHERE k2.id = kids.id
        ) 
        AND p.role = 'parent'
    )
    LIMIT 1;
    
    -- If no kid found with this name, return false
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Check if request already exists
    SELECT EXISTS(
        SELECT 1 FROM kid_linking_requests 
        WHERE kid_id = kid_record.id AND user_id = user_profile_id
    ) INTO existing_request;
    
    IF existing_request THEN
        RETURN FALSE;
    END IF;
    
    -- Create linking request
    INSERT INTO kid_linking_requests (kid_id, user_id)
    VALUES (kid_record.id, user_profile_id);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Add RLS policies for kid_linking_requests
ALTER TABLE kid_linking_requests ENABLE ROW LEVEL SECURITY;

-- Kids can view their own linking requests
CREATE POLICY "Kids can view their own linking requests" ON kid_linking_requests
    FOR SELECT USING (user_id = auth.uid());

-- Parents can view linking requests for their kids
CREATE POLICY "Parents can view linking requests for their kids" ON kid_linking_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM kids k
            JOIN profiles p ON p.id = k.parent_id
            WHERE k.id = kid_linking_requests.kid_id
            AND p.id = auth.uid()
            AND p.role = 'parent'
        )
    );

-- Parents can update linking requests for their kids
CREATE POLICY "Parents can approve/reject linking requests for their kids" ON kid_linking_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM kids k
            JOIN profiles p ON p.id = k.parent_id
            WHERE k.id = kid_linking_requests.kid_id
            AND p.id = auth.uid()
            AND p.role = 'parent'
        )
    );

-- Kids can create linking requests
CREATE POLICY "Kids can create linking requests" ON kid_linking_requests
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'kid'
        )
    );

-- Grant permissions
GRANT ALL ON kid_linking_requests TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE kid_linking_requests_id_seq TO authenticated;

-- Add comments for documentation
COMMENT ON COLUMN kids.invitation_code IS 'Unique invitation code for linking kid accounts';
COMMENT ON TABLE kid_linking_requests IS 'Requests from kids to link their account to a kid record';
COMMENT ON FUNCTION generate_invitation_code() IS 'Generates random 8-character invitation codes';
COMMENT ON FUNCTION set_invitation_code_for_kid(BIGINT) IS 'Sets a unique invitation code for a kid';
COMMENT ON FUNCTION link_kid_account(TEXT, UUID) IS 'Links a kid account using an invitation code';
COMMENT ON FUNCTION request_kid_linking(TEXT, UUID) IS 'Creates a linking request for manual approval';