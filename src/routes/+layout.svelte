<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { getProfile, getLoading, isAuthenticated, isParent, isKid, signOut, initializeAuth } from '$lib/stores/auth.svelte';

	let { children } = $props();

	// Initialize auth on mount
	onMount(() => {
		initializeAuth();
	});

	// Handle logout
	async function handleLogout() {
		await signOut();
		goto('/auth/login');
	}

	// Check if current route requires auth
	let requiresAuth = $derived(!$page.route.id?.startsWith('/auth/'));
	
	// Redirect logic
	$effect(() => {
		if (!getLoading() && requiresAuth) {
			if (!isAuthenticated()) {
				goto(`/auth/login?redirectTo=${encodeURIComponent($page.url.pathname)}`);
			} else if (getProfile()) {
				// Role-based redirects
				const currentPath = $page.route.id;
				if (currentPath === '/') {
					// Redirect from home based on role
					if (isParent()) {
						goto('/parent');
					} else if (isKid()) {
						goto('/kid');
					}
				} else if (currentPath?.startsWith('/parent/') && !isParent()) {
					// Kids can't access parent routes
					goto('/kid');
				} else if (currentPath?.startsWith('/kid/') && !isKid()) {
					// Parents can access kid routes (for oversight)
					// No redirect needed
				}
			}
		}
	});
</script>

{#if getLoading()}
	<div class="min-h-screen flex items-center justify-center">
		<div class="animate-spin rounded-full h-32 w-32 border-b-2 border-indigo-600"></div>
	</div>
{:else if !isAuthenticated() && requiresAuth}
	<!-- This will be handled by the redirect logic above -->
	<div class="min-h-screen flex items-center justify-center">
		<div class="text-center">
			<p class="text-gray-600">Redirecting to login...</p>
		</div>
	</div>
{:else if isAuthenticated() && getProfile()}
	<!-- Authenticated layout with navigation -->
	<div class="min-h-screen bg-gray-50">
		<nav class="bg-white shadow">
			<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
				<div class="flex justify-between h-16">
					<div class="flex">
						<div class="flex-shrink-0 flex items-center">
							<h1 class="text-xl font-bold text-gray-900">Taschengeld App</h1>
						</div>
						<div class="hidden sm:ml-6 sm:flex sm:space-x-8">
							{#if isKid()}
								<a href="/kid" class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium">
									My Account
								</a>
							{/if}
							{#if isParent()}
								<a href="/parent" class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium">
									Dashboard
								</a>
								<a href="/kid" class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium">
									Kid's Account
								</a>
							{/if}
						</div>
					</div>
					<div class="flex items-center space-x-4">
						<span class="text-sm text-gray-700">
							{getProfile()?.full_name} ({getProfile()?.role})
						</span>
						<button
							onclick={handleLogout}
							class="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-2 rounded-md text-sm font-medium"
						>
							Logout
						</button>
					</div>
				</div>
			</div>
		</nav>

		<main>
			{@render children()}
		</main>
	</div>
{:else}
	<!-- Auth pages (login/signup) -->
	{@render children()}
{/if}
