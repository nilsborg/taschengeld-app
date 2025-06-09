import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async () => {
	// Check if user is authenticated (this will be handled by the client-side auth)
	// For now, we'll let the client handle authentication and data loading
	// Server-side auth validation can be added later with session management
	
	return {};
};