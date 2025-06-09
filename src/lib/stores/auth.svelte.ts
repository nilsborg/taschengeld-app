import { browser } from '$app/environment';
import { supabase, type Profile } from '$lib/supabase';
import type { User } from '@supabase/supabase-js';

// Create reactive state
let userState = $state<User | null>(null);
let profileState = $state<Profile | null>(null);
let loadingState = $state<boolean>(true);

// Export reactive state accessors
export function getUser() {
	return userState;
}

export function getProfile() {
	return profileState;
}

export function getLoading() {
	return loadingState;
}

export function setUser(val: User | null) {
	userState = val;
}

export function setProfile(val: Profile | null) {
	profileState = val;
}

export function setLoading(val: boolean) {
	loadingState = val;
}

// Derived state
const isAuthenticatedState = $derived(!!userState);
const isParentState = $derived(profileState?.role === 'parent');
const isKidState = $derived(profileState?.role === 'kid');

// Export functions that return derived values
export function isAuthenticated() {
	return isAuthenticatedState;
}

export function isParent() {
	return isParentState;
}

export function isKid() {
	return isKidState;
}

// Initialize auth state
export async function initializeAuth() {
	if (!browser) return;

	setLoading(true);

	try {
		// Get initial session
		const { data: { session }, error } = await supabase.auth.getSession();
		
		if (error) {
			console.error('Error getting session:', error);
			return;
		}

		if (session?.user) {
			setUser(session.user);
			await loadProfile(session.user.id);
		}

		// Listen for auth changes
		supabase.auth.onAuthStateChange(async (event, session) => {
			if (session?.user) {
				setUser(session.user);
				await loadProfile(session.user.id);
			} else {
				setUser(null);
				setProfile(null);
			}
			setLoading(false);
		});
	} catch (error) {
		console.error('Error initializing auth:', error);
	} finally {
		setLoading(false);
	}
}

// Load user profile
async function loadProfile(userId: string) {
	try {
		const { data: profileData, error } = await supabase
			.from('profiles')
			.select('*')
			.eq('id', userId)
			.single();

		if (error) {
			if (error.code === 'PGRST116') {
				console.warn('Profile not found for user:', userId, 'This might be expected for new users');
				// Profile doesn't exist yet - this is okay for new signups
				// The trigger should create it, or manual creation will handle it
				return;
			}
			console.error('Error loading profile:', error);
			return;
		}

		if (profileData) {
			setProfile(profileData);
		}
	} catch (error) {
		console.error('Error loading profile:', error);
	}
}

// Auth actions
export async function signUp(email: string, password: string, fullName: string, role: 'parent' | 'kid') {
	setLoading(true);
	
	try {
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

		if (error) {
			throw error;
		}

		return { data, error: null };
	} catch (error) {
		console.error('Sign up error:', error);
		return { data: null, error };
	} finally {
		setLoading(false);
	}
}

export async function signIn(email: string, password: string) {
	setLoading(true);
	
	try {
		const { data, error } = await supabase.auth.signInWithPassword({
			email,
			password
		});

		if (error) {
			throw error;
		}

		return { data, error: null };
	} catch (error) {
		console.error('Sign in error:', error);
		return { data: null, error };
	} finally {
		setLoading(false);
	}
}

export async function signOut() {
	setLoading(true);
	
	try {
		const { error } = await supabase.auth.signOut();
		
		if (error) {
			throw error;
		}

		setUser(null);
		setProfile(null);
		
		return { error: null };
	} catch (error) {
		console.error('Sign out error:', error);
		return { error };
	} finally {
		setLoading(false);
	}
}

// Initialize auth when module loads
if (browser) {
	initializeAuth();
}