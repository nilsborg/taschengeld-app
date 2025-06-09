import { redirect } from '@sveltejs/kit';
import { supabase } from '$lib/supabase';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ cookies }) => {
	try {
		// Sign out from Supabase
		const { error } = await supabase.auth.signOut();
		
		if (error) {
			console.error('Logout error:', error);
			// Even if there's an error, we should still clear local session
		}

		// Clear any server-side session cookies if they exist
		cookies.delete('sb-access-token', { path: '/' });
		cookies.delete('sb-refresh-token', { path: '/' });

		// Redirect to login page
		throw redirect(303, '/auth/login?message=Successfully logged out');
	} catch (err) {
		console.error('Unexpected logout error:', err);
		
		// If it's a redirect, re-throw it
		if (err instanceof Response) {
			throw err;
		}
		
		// Otherwise, still redirect to login
		throw redirect(303, '/auth/login?error=Logout failed');
	}
};

export const GET: RequestHandler = async (event) => {
	// Handle GET requests by redirecting to POST
	// This allows for simple logout links
	return await POST(event);
};