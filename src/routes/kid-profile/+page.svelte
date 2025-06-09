<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabase';
	import { getUser, isParent } from '$lib/stores/auth.svelte';
	import type { Kid, TransactionWithKid } from '$lib/supabase';

	let kid = $state<Kid | null>(null);
	let transactions = $state<TransactionWithKid[]>([]);
	let isLoading = $state(true);
	let error = $state<string | null>(null);

	// Get kid_id from URL params
	let kidId = $state<number | null>(null);

	onMount(async () => {
		// Check if user is a parent
		if (!isParent()) {
			goto('/');
			return;
		}

		const kidIdParam = $page.url.searchParams.get('kid_id');
		if (!kidIdParam) {
			error = 'No kid ID provided';
			isLoading = false;
			return;
		}

		kidId = parseInt(kidIdParam);
		if (isNaN(kidId)) {
			error = 'Invalid kid ID';
			isLoading = false;
			return;
		}

		await loadKidData();
		await loadTransactions();
	});

	async function loadKidData() {
		const currentUser = getUser();
		if (!currentUser || !kidId) {
			error = 'Not authenticated or no kid ID';
			return;
		}

		try {
			const { data, error: kidError } = await supabase
				.from('kids')
				.select('*')
				.eq('id', kidId)
				.eq('parent_id', currentUser.id)
				.single();

			if (kidError) {
				if (kidError.code === 'PGRST116') {
					error = 'Kid not found or access denied';
				} else {
					throw kidError;
				}
				return;
			}

			kid = data;
		} catch (err) {
			console.error('Error loading kid data:', err);
			error = 'Failed to load kid data';
		}
	}

	async function loadTransactions() {
		const currentUser = getUser();
		if (!currentUser || !kidId) {
			error = 'Not authenticated or no kid ID';
			return;
		}

		try {
			const { data, error: transactionError } = await supabase
				.from('transactions')
				.select(`
					*,
					kids!inner (name, parent_id)
				`)
				.eq('kid_id', kidId)
				.eq('kids.parent_id', currentUser.id)
				.order('created_at', { ascending: false })
				.limit(100);

			if (transactionError) {
				throw transactionError;
			}

			transactions = data || [];
		} catch (err) {
			console.error('Error loading transactions:', err);
			error = 'Failed to load transactions';
		} finally {
			isLoading = false;
		}
	}

	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat('de-DE', {
			style: 'currency',
			currency: 'EUR'
		}).format(amount);
	}

	function formatDate(dateString: string): string {
		return new Date(dateString).toLocaleDateString('de-DE', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getTransactionTypeLabel(type: string): string {
		switch (type) {
			case 'weekly_allowance':
				return 'Weekly Allowance';
			case 'interest':
				return 'Interest';
			case 'withdrawal':
				return 'Withdrawal';
			case 'allowance_change':
				return 'Allowance Change';
			case 'interest_rate_change':
				return 'Interest Rate Change';
			default:
				return type;
		}
	}

	function getTransactionColor(type: string): string {
		switch (type) {
			case 'weekly_allowance':
				return 'text-green-600';
			case 'interest':
				return 'text-blue-600';
			case 'withdrawal':
				return 'text-red-600';
			case 'allowance_change':
				return 'text-orange-600';
			case 'interest_rate_change':
				return 'text-purple-600';
			default:
				return 'text-gray-600';
		}
	}

	function formatTransactionAmount(transaction: TransactionWithKid): string {
		const amount = transaction.amount;
		const type = transaction.type;
		
		switch (type) {
			case 'allowance_change': {
				// Amount is stored as delta in euros
				const prefix = amount >= 0 ? '+' : '';
				return `${prefix}${formatCurrency(amount)}`;
			}
			case 'interest_rate_change': {
				// Amount is stored as delta in percentage points
				const percentPrefix = amount >= 0 ? '+' : '';
				return `${percentPrefix}${amount.toFixed(1)}%`;
			}
			default: {
				// Regular transactions (weekly_allowance, interest, withdrawal)
				const regularPrefix = amount >= 0 ? '+' : '';
				return `${regularPrefix}${formatCurrency(amount)}`;
			}
		}
	}

	function goBack() {
		goto('/parent');
	}
</script>

<svelte:head>
	<title>{kid?.name || 'Kid Profile'} - Taschengeld App</title>
</svelte:head>

<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
	<!-- Back button -->
	<div class="mb-6">
		<button
			onclick={goBack}
			class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
		>
			<svg class="-ml-0.5 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
			</svg>
			Back to Dashboard
		</button>
	</div>

	{#if error}
		<div class="rounded-md bg-red-50 p-4 mb-6">
			<div class="flex">
				<div class="flex-shrink-0">
					<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
						<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
					</svg>
				</div>
				<div class="ml-3">
					<h3 class="text-sm font-medium text-red-800">{error}</h3>
				</div>
			</div>
		</div>
	{/if}

	{#if isLoading}
		<div class="flex justify-center items-center h-64">
			<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
		</div>
	{:else if kid}
		<!-- Kid Profile Header -->
		<div class="bg-white overflow-hidden shadow rounded-lg mb-8">
			<div class="px-4 py-5 sm:p-6">
				<h1 class="text-3xl font-bold text-gray-900 mb-6">{kid.name}'s Account</h1>
				
				<div class="grid grid-cols-1 md:grid-cols-4 gap-6">
					<div class="bg-green-50 rounded-lg p-4">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<svg class="h-8 w-8 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
								</svg>
							</div>
							<div class="ml-4">
								<p class="text-sm font-medium text-green-800">Current Balance</p>
								<p class="text-2xl font-bold text-green-900">{formatCurrency(kid.current_balance)}</p>
							</div>
						</div>
					</div>

					<div class="bg-blue-50 rounded-lg p-4">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<svg class="h-8 w-8 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3a4 4 0 118 0v4m-4 8a4 4 0 01-4-4v-4h8v4a4 4 0 01-4 4z" />
								</svg>
							</div>
							<div class="ml-4">
								<p class="text-sm font-medium text-blue-800">Weekly Allowance</p>
								<p class="text-2xl font-bold text-blue-900">{formatCurrency(kid.weekly_allowance)}</p>
							</div>
						</div>
					</div>

					<div class="bg-purple-50 rounded-lg p-4">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<svg class="h-8 w-8 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
								</svg>
							</div>
							<div class="ml-4">
								<p class="text-sm font-medium text-purple-800">Interest Rate</p>
								<p class="text-2xl font-bold text-purple-900">{(kid.interest_rate * 100).toFixed(1)}%</p>
							</div>
						</div>
					</div>

					<div class="bg-gray-50 rounded-lg p-4">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<svg class="h-8 w-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3a4 4 0 118 0v4m-4 8a4 4 0 01-4-4v-4h8v4a4 4 0 01-4 4z" />
								</svg>
							</div>
							<div class="ml-4">
								<p class="text-sm font-medium text-gray-800">Account Created</p>
								<p class="text-lg font-semibold text-gray-900">{formatDate(kid.created_at).split(',')[0]}</p>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- Transaction History -->
		<div class="bg-white overflow-hidden shadow rounded-lg">
			<div class="px-4 py-5 sm:p-6">
				<h2 class="text-lg font-semibold text-gray-900 mb-4">Transaction History</h2>
				
				{#if transactions.length === 0}
					<p class="text-gray-500 text-center py-8">No transactions yet.</p>
				{:else}
					<div class="overflow-x-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Description</th>
									<th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each transactions as transaction (transaction.id)}
									<tr>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
											{formatDate(transaction.created_at)}
										</td>
										<td class="px-6 py-4 whitespace-nowrap">
											<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
												{getTransactionTypeLabel(transaction.type)}
											</span>
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
											{transaction.description || '-'}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-right {getTransactionColor(transaction.type)} font-medium">
											{formatTransactionAmount(transaction)}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>