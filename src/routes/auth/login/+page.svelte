<script lang="ts">
	import { goto } from '$app/navigation';
	import { signIn } from '$lib/stores/auth.svelte';
	import { page } from '$app/stores';
	import * as m from '$lib/paraglide/messages.js';

	let email = '';
	let password = '';
	let error: string | null = null;
	let isLoading = false;

	async function handleSubmit() {
		if (!email || !password) {
			error = m.error_validation();
			return;
		}

		isLoading = true;
		error = null;

		const { error: signInError } = await signIn(email, password);

		if (signInError) {
			error = (signInError as { message?: string }).message || m.error_general();
			isLoading = false;
			return;
		}

		// Redirect to appropriate page based on role or redirect param
		const redirectTo = $page.url.searchParams.get('redirectTo') || '/';
		goto(redirectTo);
	}
</script>

<svelte:head>
	<title>{m.login()} - {m.app_title()}</title>
</svelte:head>

<div class="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 sm:px-6 lg:px-8">
	<div class="w-full max-w-md space-y-8">
		<div>
			<h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
				{m.sign_in()}
			</h2>
			<p class="mt-2 text-center text-sm text-gray-600">
				{m.dont_have_account()}
				<a href="/auth/signup" class="font-medium text-indigo-600 hover:text-indigo-500">
					{m.sign_up()}
				</a>
			</p>
		</div>

		<form class="mt-8 space-y-6" on:submit|preventDefault={handleSubmit}>
			<div class="-space-y-px rounded-md shadow-sm">
				<div>
					<label for="email" class="sr-only">{m.email()}</label>
					<input
						id="email"
						name="email"
						type="email"
						autocomplete="email"
						required
						bind:value={email}
						class="relative block w-full appearance-none rounded-none rounded-t-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-indigo-500 focus:ring-indigo-500 focus:outline-none sm:text-sm"
						placeholder={m.email()}
						disabled={isLoading}
					/>
				</div>
				<div>
					<label for="password" class="sr-only">{m.password()}</label>
					<input
						id="password"
						name="password"
						type="password"
						autocomplete="current-password"
						required
						bind:value={password}
						class="relative block w-full appearance-none rounded-none rounded-b-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-indigo-500 focus:ring-indigo-500 focus:outline-none sm:text-sm"
						placeholder={m.password()}
						disabled={isLoading}
					/>
				</div>
			</div>

			{#if error}
				<div class="rounded-md bg-red-50 p-4">
					<div class="flex">
						<div class="flex-shrink-0">
							<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
								<path
									fill-rule="evenodd"
									d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
									clip-rule="evenodd"
								/>
							</svg>
						</div>
						<div class="ml-3">
							<h3 class="text-sm font-medium text-red-800">
								{error}
							</h3>
						</div>
					</div>
				</div>
			{/if}

			<div>
				<button
					type="submit"
					disabled={isLoading}
					class="group relative flex w-full justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
				>
					{#if isLoading}
						<svg
							class="mr-3 -ml-1 h-5 w-5 animate-spin text-white"
							xmlns="http://www.w3.org/2000/svg"
							fill="none"
							viewBox="0 0 24 24"
						>
							<circle
								class="opacity-25"
								cx="12"
								cy="12"
								r="10"
								stroke="currentColor"
								stroke-width="4"
							></circle>
							<path
								class="opacity-75"
								fill="currentColor"
								d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
							></path>
						</svg>
						{m.loading()}
					{:else}
						{m.sign_in()}
					{/if}
				</button>
			</div>
		</form>
	</div>
</div>
