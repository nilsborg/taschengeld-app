import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async () => {
	// The homepage now just serves as a landing page
	// Authentication and routing are handled client-side
	return {};
};
