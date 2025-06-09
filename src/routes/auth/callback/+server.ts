import { redirect } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import type { RequestHandler } from './$types';

const supabase = createClient(env.SUPABASE_URL!, env.SUPABASE_ANON_KEY!);

export const GET: RequestHandler = async ({ url, cookies }) => {
	const code = url.searchParams.get('code');
	const next = url.searchParams.get('next') ?? '/';

	if (code) {
		try {
			const { data, error } = await supabase.auth.exchangeCodeForSession(code);
			
			if (error) {
				console.error('Auth callback error:', error);
				throw redirect(303, '/auth/login?error=Authentication failed');
			}

			if (data.session) {
				// Set session cookies if needed for SSR
				const { access_token, refresh_token } = data.session;
				
				// Note: In a production app, you might want to set httpOnly cookies
				// for better security, but since we're using client-side auth,
				// Supabase will handle session management
				
				// Redirect to the intended page or dashboard based on user role
				const { data: profile } = await supabase
					.from('profiles')
					.select('role')
					.eq('id', data.user.id)
					.single();

				if (profile?.role === 'parent') {
					throw redirect(303, '/parent');
				} else if (profile?.role === 'kid') {
					throw redirect(303, '/kid');
				} else {
					throw redirect(303, next);
				}
			}
		} catch (err) {
			console.error('Unexpected auth callback error:', err);
			if (err instanceof Response) {
				throw err; // Re-throw redirect responses
			}
			throw redirect(303, '/auth/login?error=Authentication failed');
		}
	}

	// No code provided, redirect to login
	throw redirect(303, '/auth/login?error=No authentication code provided');
};