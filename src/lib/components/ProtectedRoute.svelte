<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { getProfile, getLoading, isAuthenticated } from '$lib/stores/auth.svelte';
	import type { Snippet } from 'svelte';

	interface Props {
		requireAuth?: boolean;
		requiredRole?: 'parent' | 'kid';
		redirectTo?: string;
		children: Snippet;
	}

	let { 
		requireAuth = true, 
		requiredRole, 
		redirectTo = '/auth/login',
		children 
	}: Props = $props();

	let isAuthorized = $state(false);
	let isChecking = $state(true);

	function checkAuthorization() {
		isChecking = true;

		// Check if authentication is required
		if (requireAuth && !isAuthenticated()) {
			const currentPath = $page.url.pathname;
			goto(`${redirectTo}?redirectTo=${encodeURIComponent(currentPath)}`);
			return;
		}

		// Check role requirements
		if (requiredRole && getProfile()) {
			if (getProfile()!.role !== requiredRole) {
				// Redirect to appropriate dashboard based on actual role
				if (getProfile()!.role === 'parent') {
					goto('/parent');
				} else if (getProfile()!.role === 'kid') {
					goto('/kid');
				} else {
					goto(redirectTo);
				}
				return;
			}
		}

		// User is authorized
		isAuthorized = true;
		isChecking = false;
	}

	// Reactive check when auth state changes
	$effect(() => {
		if (!getLoading()) {
			checkAuthorization();
		}
	});
</script>

{#if getLoading() || isChecking}
	<div class="min-h-screen flex items-center justify-center bg-gray-50">
		<div class="text-center">
			<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
			<p class="text-gray-600">Checking authorization...</p>
		</div>
	</div>
{:else if isAuthorized}
	{@render children()}
{:else}
	<div class="min-h-screen flex items-center justify-center bg-gray-50">
		<div class="text-center">
			<div class="mb-4">
				<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
				</svg>
			</div>
			<h2 class="text-lg font-medium text-gray-900 mb-2">Access Denied</h2>
			<p class="text-gray-600 mb-4">You don't have permission to access this page.</p>
			<a 
				href="/"
				class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
			>
				Go Home
			</a>
		</div>
	</div>
{/if}