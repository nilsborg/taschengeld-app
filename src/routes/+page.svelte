<script lang="ts">
	import { goto } from '$app/navigation';
	import { getLoading, isAuthenticated, isParent, isKid } from '$lib/stores/auth.svelte';
	import * as m from '$lib/paraglide/messages.js';

	$effect(() => {
		// Redirect authenticated users to their appropriate dashboard
		if (!getLoading()) {
			if (isAuthenticated()) {
				if (isParent()) {
					goto('/parent');
				} else if (isKid()) {
					goto('/kid');
				}
			}
		}
	});
</script>

<svelte:head>
	<title>{m.app_title()}</title>
</svelte:head>

{#if getLoading()}
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<div class="text-center">
			<div
				class="mx-auto mb-4 h-12 w-12 animate-spin rounded-full border-b-2 border-indigo-600"
			></div>
			<p class="text-gray-600">{m.loading()}</p>
		</div>
	</div>
{:else if !isAuthenticated()}
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<div class="w-full max-w-md space-y-8 text-center">
			<div>
				<h1 class="mb-4 text-4xl font-bold text-gray-900">{m.app_title()}</h1>
				<p class="mb-8 text-lg text-gray-600">{m.app_tagline()}</p>
			</div>

			<div class="space-y-4">
				<a
					href="/auth/login"
					class="flex w-full justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-3 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-none"
				>
					{m.sign_in()}
				</a>

				<a
					href="/auth/signup"
					class="flex w-full justify-center rounded-md border border-gray-300 bg-white px-4 py-3 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-none"
				>
					{m.sign_up()}
				</a>
			</div>

			<div class="mt-8 text-sm text-gray-500">
				<p class="mb-2"><strong>{m.kid()}:</strong> {m.for_kids()}</p>
				<p><strong>{m.parent()}:</strong> {m.for_parents()}</p>
			</div>
		</div>
	</div>
{:else}
	<!-- This shouldn't be reached due to redirects, but just in case -->
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<div class="text-center">
			<p class="text-gray-600">{m.redirecting()}</p>
		</div>
	</div>
{/if}
