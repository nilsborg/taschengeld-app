<script lang="ts">
	import { goto } from '$app/navigation';
	import { getLoading, isAuthenticated, isParent, isKid } from '$lib/stores/auth.svelte';

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
	<title>Taschengeld App</title>
</svelte:head>

{#if getLoading()}
	<div class="min-h-screen flex items-center justify-center bg-gray-50">
		<div class="text-center">
			<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
			<p class="text-gray-600">Loading...</p>
		</div>
	</div>
{:else if !isAuthenticated()}
	<div class="min-h-screen flex items-center justify-center bg-gray-50">
		<div class="max-w-md w-full space-y-8 text-center">
			<div>
				<h1 class="text-4xl font-bold text-gray-900 mb-4">Taschengeld App</h1>
				<p class="text-lg text-gray-600 mb-8">Manage your pocket money with ease</p>
			</div>
			
			<div class="space-y-4">
				<a 
					href="/auth/login" 
					class="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
				>
					Sign In
				</a>
				
				<a 
					href="/auth/signup" 
					class="w-full flex justify-center py-3 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
				>
					Create Account
				</a>
			</div>

			<div class="mt-8 text-sm text-gray-500">
				<p class="mb-2"><strong>For Kids:</strong> Track your allowance, view transactions, and make withdrawals</p>
				<p><strong>For Parents:</strong> Manage allowances, add interest, and oversee all accounts</p>
			</div>
		</div>
	</div>
{:else}
	<!-- This shouldn't be reached due to redirects, but just in case -->
	<div class="min-h-screen flex items-center justify-center bg-gray-50">
		<div class="text-center">
			<p class="text-gray-600">Redirecting to your dashboard...</p>
		</div>
	</div>
{/if}