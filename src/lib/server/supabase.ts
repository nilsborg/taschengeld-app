import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

if (!env.SUPABASE_URL) throw new Error('SUPABASE_URL is not set');
if (!env.SUPABASE_ANON_KEY) throw new Error('SUPABASE_ANON_KEY is not set');

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY);

// Database types - these will match our Supabase schema
export interface Kid {
	id: number;
	name: string;
	weekly_allowance: number;
	interest_rate: number;
	current_balance: number;
	created_at: string;
	updated_at: string;
}

export interface Transaction {
	id: number;
	kid_id: number;
	type: 'weekly_allowance' | 'interest' | 'withdrawal';
	amount: number;
	description: string | null;
	created_at: string;
}

export interface NewKid {
	name: string;
	weekly_allowance: number;
	interest_rate: number;
	current_balance?: number;
}

export interface NewTransaction {
	kid_id: number;
	type: 'weekly_allowance' | 'interest' | 'withdrawal';
	amount: number;
	description?: string | null;
}