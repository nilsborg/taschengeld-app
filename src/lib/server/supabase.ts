import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

if (!env.SUPABASE_URL) throw new Error('SUPABASE_URL is not set');
if (!env.SUPABASE_ANON_KEY) throw new Error('SUPABASE_ANON_KEY is not set');
if (!env.SUPABASE_SERVICE_ROLE_KEY) throw new Error('SUPABASE_SERVICE_ROLE_KEY is not set');

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
	auth: {
		autoRefreshToken: false,
		persistSession: false,
		detectSessionInUrl: false
	}
});

// Service role client for server-side operations that bypass RLS
export const supabaseService = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
	auth: {
		autoRefreshToken: false,
		persistSession: false,
		detectSessionInUrl: false
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
	user_id?: string;
}

export interface NewTransaction {
	kid_id: number;
	type: 'weekly_allowance' | 'interest' | 'withdrawal';
	amount: number;
	description?: string | null;
}

// Auth helper functions for server-side operations
export async function createServerClient(accessToken?: string) {
	if (accessToken) {
		return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
			auth: {
				autoRefreshToken: false,
				persistSession: false,
				detectSessionInUrl: false
			},
			global: {
				headers: {
					Authorization: `Bearer ${accessToken}`
				}
			}
		});
	}
	return supabase;
}

export async function getServerSession(request: Request) {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader) return null;

	const token = authHeader.replace('Bearer ', '');
	const client = createServerClient(token);

	const {
		data: { user },
		error
	} = await client.auth.getUser(token);
	if (error || !user) return null;

	return user;
}

export async function getUserProfile(userId: string, accessToken?: string) {
	const client = accessToken ? createServerClient(accessToken) : supabase;

	const { data: profile, error } = await client
		.from('profiles')
		.select('*')
		.eq('id', userId)
		.single();

	if (error) {
		console.error('Error fetching user profile:', error);
		return null;
	}

	return profile;
}
