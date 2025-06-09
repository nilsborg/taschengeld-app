<script lang="ts">
	import { goto } from '$app/navigation';
	import { signUp } from '$lib/stores/auth.svelte';
	import { supabase } from '$lib/supabase';
	
	let email = '';
	let password = '';
	let confirmPassword = '';
	let fullName = '';
	let role: 'parent' | 'kid' = 'kid';
	let error: string | null = null;
	let isLoading = false;

	async function handleSubmit() {
		// Validation
		if (!email || !password || !confirmPassword || !fullName) {
			error = 'Please fill in all fields';
			return;
		}

		if (password !== confirmPassword) {
			error = 'Passwords do not match';
			return;
		}

		if (password.length < 6) {
			error = 'Password must be at least 6 characters long';
			return;
		}

		isLoading = true;
		error = null;

		const { data, error: signUpError } = await signUp(email, password, fullName, role);

		if (signUpError) {
			error = signUpError.message;
			isLoading = false;
			return;
		}

		// If user was created but profile might not exist, try to create it manually
		if (data.user) {
			try {
				// Check if profile exists
				const { data: existingProfile } = await supabase
					.from('profiles')
					.select('*')
					.eq('id', data.user.id)
					.single();

				// If no profile exists, create one manually
				if (!existingProfile) {
					const { error: profileError } = await supabase
						.from('profiles')
						.insert({
							id: data.user.id,
							email: email,
							full_name: fullName,
							role: role
						});

					if (profileError) {
						console.error('Error creating profile:', profileError);
						// Continue anyway - profile creation might have worked via trigger
					}
				}

				// User was automatically signed in
				if (role === 'parent') {
					goto('/parent');
				} else {
					goto('/kid');
				}
			} catch (err) {
				console.error('Error handling profile creation:', err);
				// Fallback to login page
				goto('/auth/login?message=Account created, please sign in');
			}
		} else {
			// Redirect to login with success message
			goto('/auth/login?message=Check your email to confirm your account');
		}
	}
</script>

<svelte:head>
	<title>Sign Up - Taschengeld App</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
	<div class="max-w-md w-full space-y-8">
		<div>
			<h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
				Create your account
			</h2>
			<p class="mt-2 text-center text-sm text-gray-600">
				Or
				<a href="/auth/login" class="font-medium text-indigo-600 hover:text-indigo-500">
					sign in to your existing account
				</a>
			</p>
		</div>
		
		<form class="mt-8 space-y-6" on:submit|preventDefault={handleSubmit}>
			<div class="space-y-4">
				<div>
					<label for="fullName" class="block text-sm font-medium text-gray-700">Full Name</label>
					<input
						id="fullName"
						name="fullName"
						type="text"
						autocomplete="name"
						required
						bind:value={fullName}
						class="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
						placeholder="Enter your full name"
						disabled={isLoading}
					/>
				</div>

				<div>
					<label for="email" class="block text-sm font-medium text-gray-700">Email Address</label>
					<input
						id="email"
						name="email"
						type="email"
						autocomplete="email"
						required
						bind:value={email}
						class="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
						placeholder="Enter your email address"
						disabled={isLoading}
					/>
				</div>

				<div>
					<label for="role" class="block text-sm font-medium text-gray-700">I am a...</label>
					<select
						id="role"
						name="role"
						bind:value={role}
						class="mt-1 block w-full px-3 py-2 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
						disabled={isLoading}
					>
						<option value="kid">Kid (can view transactions and make withdrawals)</option>
						<option value="parent">Parent (can view everything but cannot withdraw)</option>
					</select>
				</div>

				<div>
					<label for="password" class="block text-sm font-medium text-gray-700">Password</label>
					<input
						id="password"
						name="password"
						type="password"
						autocomplete="new-password"
						required
						bind:value={password}
						class="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
						placeholder="Enter your password"
						disabled={isLoading}
					/>
				</div>

				<div>
					<label for="confirmPassword" class="block text-sm font-medium text-gray-700">Confirm Password</label>
					<input
						id="confirmPassword"
						name="confirmPassword"
						type="password"
						autocomplete="new-password"
						required
						bind:value={confirmPassword}
						class="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
						placeholder="Confirm your password"
						disabled={isLoading}
					/>
				</div>
			</div>

			{#if error}
				<div class="rounded-md bg-red-50 p-4">
					<div class="flex">
						<div class="flex-shrink-0">
							<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
								<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
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
					class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
				>
					{#if isLoading}
						<svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Creating account...
					{:else}
						Create account
					{/if}
				</button>
			</div>

			<div class="text-xs text-gray-500 text-center">
				<p><strong>Parent:</strong> Can view all transactions and balances, manage allowances and interest, but cannot make withdrawals.</p>
				<p><strong>Kid:</strong> Can view their own transactions and current balance, and can make withdrawals from their account.</p>
			</div>
		</form>
	</div>
</div>