<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabase';
	import { getUser, getProfile, isKid } from '$lib/stores/auth.svelte';

	let isLoading = $state(false);
	let error = $state<string | null>(null);
	let success = $state<string | null>(null);

	// Invitation code method
	let invitationCode = $state('');
	let isLinkingWithCode = $state(false);

	// Manual request method
	let kidName = $state('');
	let isRequestingLink = $state(false);

	// Check if user is already linked
	let isAlreadyLinked = $state(false);

	onMount(async () => {
		// Check if user is a kid and not already linked
		if (!isKid()) {
			goto('/');
			return;
		}

		await checkIfAlreadyLinked();
	});

	async function checkIfAlreadyLinked() {
		const currentUser = getUser();
		if (!currentUser) return;

		try {
			const { data, error: kidError } = await supabase
				.from('kids')
				.select('id, name')
				.eq('user_id', currentUser.id);

			if (kidError) {
				console.error('Error checking kid link:', kidError);
				return;
			}

			if (data && data.length > 0) {
				isAlreadyLinked = true;
			}
		} catch (err) {
			console.error('Error checking if already linked:', err);
		}
	}

	async function linkWithInvitationCode() {
		if (!invitationCode.trim()) {
			error = 'Please enter an invitation code';
			return;
		}

		const currentUser = getUser();
		if (!currentUser) {
			error = 'Not authenticated';
			return;
		}

		isLinkingWithCode = true;
		error = null;

		try {
			const { data, error: linkError } = await supabase.rpc('link_kid_account', {
				code: invitationCode.trim().toUpperCase(),
				user_profile_id: currentUser.id
			});

			if (linkError) {
				throw linkError;
			}

			if (data) {
				success = 'Account successfully linked! Redirecting to your account...';
				setTimeout(() => {
					goto('/kid');
				}, 2000);
			} else {
				error = 'Invalid invitation code or code already used';
			}
		} catch (err) {
			console.error('Error linking with invitation code:', err);
			error = 'Failed to link account. Please check your invitation code.';
		} finally {
			isLinkingWithCode = false;
		}
	}

	async function requestManualLink() {
		if (!kidName.trim()) {
			error = "Please enter your name as it appears in your parent's account";
			return;
		}

		const currentUser = getUser();
		if (!currentUser) {
			error = 'Not authenticated';
			return;
		}

		isRequestingLink = true;
		error = null;

		try {
			const { data, error: requestError } = await supabase.rpc('request_kid_linking', {
				kid_name: kidName.trim(),
				user_profile_id: currentUser.id
			});

			if (requestError) {
				throw requestError;
			}

			if (data) {
				success = 'Linking request sent! Your parent will need to approve it.';
				kidName = '';
			} else {
				error = 'No matching kid record found or request already exists';
			}
		} catch (err) {
			console.error('Error requesting manual link:', err);
			error = 'Failed to send linking request';
		} finally {
			isRequestingLink = false;
		}
	}

	function goToAccount() {
		goto('/kid');
	}
</script>

<svelte:head>
	<title>Link Your Account - Taschengeld App</title>
</svelte:head>

<div class="flex min-h-screen flex-col justify-center bg-gray-50 py-12 sm:px-6 lg:px-8">
	<div class="sm:mx-auto sm:w-full sm:max-w-md">
		<h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">Link Your Account</h2>
		<p class="mt-2 text-center text-sm text-gray-600">
			Connect your account to your allowance record
		</p>
	</div>

	<div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
		<div class="bg-white px-4 py-8 shadow sm:rounded-lg sm:px-10">
			{#if isAlreadyLinked}
				<!-- Already linked -->
				<div class="text-center">
					<div
						class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-green-100"
					>
						<svg
							class="h-6 w-6 text-green-600"
							fill="none"
							viewBox="0 0 24 24"
							stroke="currentColor"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M5 13l4 4L19 7"
							/>
						</svg>
					</div>
					<h3 class="mb-2 text-lg font-medium text-gray-900">Account Already Linked</h3>
					<p class="mb-6 text-sm text-gray-600">
						Your account is already connected to your allowance record.
					</p>
					<button
						onclick={goToAccount}
						class="flex w-full justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-none"
					>
						Go to My Account
					</button>
				</div>
			{:else}
				<!-- Linking options -->
				{#if error}
					<div class="mb-6 rounded-md bg-red-50 p-4">
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
								<h3 class="text-sm font-medium text-red-800">{error}</h3>
							</div>
						</div>
					</div>
				{/if}

				{#if success}
					<div class="mb-6 rounded-md bg-green-50 p-4">
						<div class="flex">
							<div class="flex-shrink-0">
								<svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
									<path
										fill-rule="evenodd"
										d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
										clip-rule="evenodd"
									/>
								</svg>
							</div>
							<div class="ml-3">
								<h3 class="text-sm font-medium text-green-800">{success}</h3>
							</div>
						</div>
					</div>
				{/if}

				<!-- Method 1: Invitation Code -->
				<div class="space-y-6">
					<div>
						<h3 class="mb-4 text-lg font-medium text-gray-900">Option 1: Use Invitation Code</h3>
						<p class="mb-4 text-sm text-gray-600">
							If your parent gave you an invitation code, enter it below:
						</p>

						<form
							onsubmit={(e) => {
								e.preventDefault();
								linkWithInvitationCode();
							}}
							class="space-y-4"
						>
							<div>
								<label for="invitation-code" class="block text-sm font-medium text-gray-700">
									Invitation Code
								</label>
								<input
									type="text"
									id="invitation-code"
									bind:value={invitationCode}
									maxlength="8"
									placeholder="Enter 8-character code"
									class="mt-1 block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 uppercase placeholder-gray-400 focus:border-indigo-500 focus:ring-indigo-500 focus:outline-none sm:text-sm"
									disabled={isLinkingWithCode}
									style="text-transform: uppercase;"
								/>
							</div>

							<button
								type="submit"
								disabled={isLinkingWithCode || !invitationCode.trim()}
								class="flex w-full justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
							>
								{#if isLinkingWithCode}
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
									Linking Account...
								{:else}
									Link Account
								{/if}
							</button>
						</form>
					</div>

					<!-- Divider -->
					<div class="relative">
						<div class="absolute inset-0 flex items-center">
							<div class="w-full border-t border-gray-300"></div>
						</div>
						<div class="relative flex justify-center text-sm">
							<span class="bg-white px-2 text-gray-500">Or</span>
						</div>
					</div>

					<!-- Method 2: Manual Request -->
					<div>
						<h3 class="mb-4 text-lg font-medium text-gray-900">Option 2: Request Manual Linking</h3>
						<p class="mb-4 text-sm text-gray-600">
							Enter your name exactly as your parent entered it when creating your account:
						</p>

						<form
							onsubmit={(e) => {
								e.preventDefault();
								requestManualLink();
							}}
							class="space-y-4"
						>
							<div>
								<label for="kid-name" class="block text-sm font-medium text-gray-700">
									Your Name
								</label>
								<input
									type="text"
									id="kid-name"
									bind:value={kidName}
									placeholder="Enter your name"
									class="mt-1 block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 placeholder-gray-400 focus:border-indigo-500 focus:ring-indigo-500 focus:outline-none sm:text-sm"
									disabled={isRequestingLink}
								/>
							</div>

							<button
								type="submit"
								disabled={isRequestingLink || !kidName.trim()}
								class="flex w-full justify-center rounded-md border border-transparent bg-gray-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-gray-700 focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
							>
								{#if isRequestingLink}
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
											d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
										></path>
									</svg>
									Sending Request...
								{:else}
									Send Linking Request
								{/if}
							</button>
						</form>
					</div>

					<!-- Help text -->
					<div class="mt-6 text-center">
						<p class="text-xs text-gray-500">
							Need help? Ask your parent to check their dashboard for linking options.
						</p>
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>
