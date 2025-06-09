<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabase';
	import { getUser } from '$lib/stores/auth.svelte';
	import type { Kid, Transaction } from '$lib/supabase';

	let kidData = $state<Kid | null>(null);
	let transactions = $state<Transaction[]>([]);
	let isLoading = $state(true);
	let error = $state<string | null>(null);
	let withdrawalAmount = $state('');
	let withdrawalDescription = $state('');
	let isWithdrawing = $state(false);
	let withdrawalError = $state<string | null>(null);

	onMount(async () => {
		await loadKidData();
		await loadTransactions();
	});

	async function loadKidData() {
		const currentUser = getUser();
		if (!currentUser) return;

		try {
			const { data: kids, error: kidError } = await supabase
				.from('kids')
				.select('*')
				.eq('user_id', currentUser.id)
				.single();

			if (kidError) {
				if (kidError.code === 'PGRST116') {
					// No kid record found - redirect to linking page
					goto('/link-account');
					return;
				} else {
					throw kidError;
				}
			} else {
				kidData = kids;
			}
		} catch (err) {
			console.error('Error loading kid data:', err);
			error = 'Failed to load account data';
		}
	}

	async function loadTransactions() {
		if (!kidData) return;

		try {
			const { data, error: transactionError } = await supabase
				.from('transactions')
				.select('*')
				.eq('kid_id', kidData.id)
				.order('created_at', { ascending: false })
				.limit(50);

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

	async function handleWithdrawal() {
		if (!kidData || !withdrawalAmount) return;

		const amount = parseFloat(withdrawalAmount);
		
		if (isNaN(amount) || amount <= 0) {
			withdrawalError = 'Please enter a valid amount';
			return;
		}

		if (amount > kidData.current_balance) {
			withdrawalError = 'Insufficient balance';
			return;
		}

		isWithdrawing = true;
		withdrawalError = null;

		try {
			// Create withdrawal transaction
			const { data: transaction, error: transactionError } = await supabase
				.from('transactions')
				.insert({
					kid_id: kidData.id,
					type: 'withdrawal',
					amount: -amount, // Negative for withdrawal
					description: withdrawalDescription || 'Withdrawal'
				})
				.select()
				.single();

			if (transactionError) {
				throw transactionError;
			}

			// Update kid's balance
			const newBalance = kidData.current_balance - amount;
			const { error: updateError } = await supabase
				.from('kids')
				.update({ current_balance: newBalance })
				.eq('id', kidData.id);

			if (updateError) {
				throw updateError;
			}

			// Update local state
			kidData.current_balance = newBalance;
			transactions = [transaction, ...transactions];

			// Clear form
			withdrawalAmount = '';
			withdrawalDescription = '';
		} catch (err) {
			console.error('Error processing withdrawal:', err);
			withdrawalError = 'Failed to process withdrawal';
		} finally {
			isWithdrawing = false;
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

	function formatTransactionAmount(transaction: Transaction): string {
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
</script>

<svelte:head>
	<title>My Account - Taschengeld App</title>
</svelte:head>

<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
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
	{:else if kidData}
		<!-- Account Overview -->
		<div class="bg-white overflow-hidden shadow rounded-lg mb-8">
			<div class="px-4 py-5 sm:p-6">
				<h1 class="text-2xl font-bold text-gray-900 mb-4">Welcome, {kidData.name}!</h1>
				
				<div class="grid grid-cols-1 md:grid-cols-3 gap-6">
					<div class="bg-green-50 rounded-lg p-4">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<svg class="h-8 w-8 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
								</svg>
							</div>
							<div class="ml-4">
								<p class="text-sm font-medium text-green-800">Current Balance</p>
								<p class="text-2xl font-bold text-green-900">{formatCurrency(kidData.current_balance)}</p>
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
								<p class="text-2xl font-bold text-blue-900">{formatCurrency(kidData.weekly_allowance)}</p>
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
								<p class="text-2xl font-bold text-purple-900">{(kidData.interest_rate * 100).toFixed(1)}%</p>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- Withdrawal Form -->
		<div class="bg-white overflow-hidden shadow rounded-lg mb-8">
			<div class="px-4 py-5 sm:p-6">
				<h2 class="text-lg font-semibold text-gray-900 mb-4">Make a Withdrawal</h2>
				
				<form onsubmit={(e) => { e.preventDefault(); handleWithdrawal(); }} class="space-y-4">
					<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
						<div>
							<label for="amount" class="block text-sm font-medium text-gray-700">Amount</label>
							<div class="mt-1 relative rounded-md shadow-sm">
								<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
									<span class="text-gray-500 sm:text-sm">€</span>
								</div>
								<input
									type="number"
									step="0.01"
									min="0"
									max={kidData.current_balance}
									id="amount"
									bind:value={withdrawalAmount}
									class="focus:ring-indigo-500 focus:border-indigo-500 block w-full pl-7 pr-12 sm:text-sm border-gray-300 rounded-md"
									placeholder="0.00"
									disabled={isWithdrawing}
								/>
							</div>
						</div>

						<div>
							<label for="description" class="block text-sm font-medium text-gray-700">Description (optional)</label>
							<input
								type="text"
								id="description"
								bind:value={withdrawalDescription}
								class="mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
								placeholder="What is this for?"
								disabled={isWithdrawing}
							/>
						</div>
					</div>

					{#if withdrawalError}
						<div class="text-red-600 text-sm">{withdrawalError}</div>
					{/if}

					<button
						type="submit"
						disabled={isWithdrawing || !withdrawalAmount || kidData.current_balance <= 0}
						class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{#if isWithdrawing}
							<svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							Processing...
						{:else}
							Withdraw Money
						{/if}
					</button>
				</form>
			</div>
		</div>

		<!-- Transaction History -->
		<div class="bg-white overflow-hidden shadow rounded-lg">
			<div class="px-4 py-5 sm:p-6">
				<h2 class="text-lg font-semibold text-gray-900 mb-4">Recent Transactions</h2>
				
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