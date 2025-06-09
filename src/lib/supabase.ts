import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

if (!PUBLIC_SUPABASE_URL) throw new Error('PUBLIC_SUPABASE_URL is not set');
if (!PUBLIC_SUPABASE_ANON_KEY) throw new Error('PUBLIC_SUPABASE_ANON_KEY is not set');

export const supabase = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
	auth: {
		autoRefreshToken: true,
		persistSession: true,
		detectSessionInUrl: true
	}
});

// Database types - these will match our Supabase schema
export interface Profile {
	id: string;
	email: string;
	full_name: string | null;
	role: 'parent' | 'kid';
	created_at: string;
	updated_at: string;
}

export interface Kid {
	id: number;
	user_id: string | null;
	parent_id: string;
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
	type: 'weekly_allowance' | 'interest' | 'withdrawal' | 'allowance_change' | 'interest_rate_change';
	amount: number;
	description: string | null;
	created_at: string;
}

export interface NewKid {
	name: string;
	weekly_allowance: number;
	interest_rate: number;
	current_balance?: number;
	user_id?: string;
	parent_id: string;
}

export interface NewTransaction {
	kid_id: number;
	type: 'weekly_allowance' | 'interest' | 'withdrawal' | 'allowance_change' | 'interest_rate_change';
	amount: number;
	description?: string | null;
}

export interface TransactionWithKid extends Transaction {
	kids: {
		name: string;
	} | null;
}

// Auth helper functions
export async function signUp(email: string, password: string, fullName: string, role: 'parent' | 'kid') {
	const { data, error } = await supabase.auth.signUp({
		email,
		password,
		options: {
			data: {
				full_name: fullName,
				role: role
			}
		}
	});
	return { data, error };
}

export async function signIn(email: string, password: string) {
	const { data, error } = await supabase.auth.signInWithPassword({
		email,
		password
	});
	return { data, error };
}

export async function signOut() {
	const { error } = await supabase.auth.signOut();
	return { error };
}

export async function getCurrentUser() {
	const { data: { user }, error } = await supabase.auth.getUser();
	return { user, error };
}

export async function getCurrentProfile() {
	const { user, error: userError } = await getCurrentUser();
	if (userError || !user) return { profile: null, error: userError };

	const { data: profile, error } = await supabase
		.from('profiles')
		.select('*')
		.eq('id', user.id)
		.single();

	return { profile, error };
}