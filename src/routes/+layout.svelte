<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import {
		getProfile,
		getLoading,
		isAuthenticated,
		isParent,
		isKid,
		signOut,
		initializeAuth
	} from '$lib/stores/auth.svelte';
	import * as m from '$lib/paraglide/messages.js';
	import { getLocale, locales, localizeHref } from '$lib/paraglide/runtime.js';

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
	<div class="flex min-h-screen items-center justify-center">
		<div class="h-32 w-32 animate-spin rounded-full border-b-2 border-indigo-600"></div>
	</div>
{:else if !isAuthenticated() && requiresAuth}
	<!-- This will be handled by the redirect logic above -->
	<div class="flex min-h-screen items-center justify-center">
		<div class="text-center">
			<p class="text-gray-600">{m.redirecting()}</p>
		</div>
	</div>
{:else if isAuthenticated() && getProfile()}
	<!-- Authenticated layout with navigation -->
	<div class="min-h-screen bg-gray-50">
		<nav class="bg-white shadow">
			<div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
				<div class="flex h-16 justify-between">
					<div class="flex">
						<div class="flex flex-shrink-0 items-center">
							<h1 class="text-xl font-bold text-gray-900">{m.app_title()}</h1>
						</div>
						<div class="hidden sm:ml-6 sm:flex sm:space-x-8">
							{#if isKid()}
								<a
									href="/kid"
									class="inline-flex items-center border-b-2 border-transparent px-1 pt-1 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
								>
									{m.kid_dashboard()}
								</a>
							{/if}
							{#if isParent()}
								<a
									href="/parent"
									class="inline-flex items-center border-b-2 border-transparent px-1 pt-1 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
								>
									{m.parent_dashboard()}
								</a>
							{/if}
						</div>
					</div>
					<div class="flex items-center space-x-4">
						<!-- Language Switcher -->
						<div class="relative">
							<select
								value={getLocale()}
								onchange={(e) => {
									const newLang = (e.target as HTMLSelectElement).value;
									const newUrl = localizeHref($page.url.pathname, { locale: newLang });
									goto(newUrl);
								}}
								class="rounded-md border border-gray-300 bg-white px-3 py-1 text-sm focus:border-indigo-500 focus:ring-indigo-500"
							>
								{#each locales as locale}
									<option value={locale}>
										{locale === 'en' ? 'English' : 'Deutsch'}
									</option>
								{/each}
							</select>
						</div>
						<span class="text-sm text-gray-700">
							{getProfile()?.full_name} ({getProfile()?.role})
						</span>
						<button
							onclick={handleLogout}
							class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-700"
						>
							{m.logout()}
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
