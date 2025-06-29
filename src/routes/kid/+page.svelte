<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabase';
	import { getUser } from '$lib/stores/auth.svelte';
	import type { Kid, Transaction } from '$lib/supabase';
	import * as m from '$lib/paraglide/messages.js';

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
			withdrawalError = m.error_validation();
			return;
		}

		if (!withdrawalDescription.trim()) {
			withdrawalError = m.error_validation();
			return;
		}

		if (amount > kidData.current_balance) {
			withdrawalError = m.insufficient_funds();
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
				return m.transaction_allowance();
			case 'interest':
				return m.transaction_interest();
			case 'withdrawal':
				return m.transaction_withdrawal();
			case 'allowance_change':
				return m.transaction_allowance() + ' ' + m.type();
			case 'interest_rate_change':
				return m.interest_rate() + ' ' + m.type();
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
	<title>{m.kid_dashboard()} - {m.app_title()}</title>
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
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

	{#if isLoading}
		<div class="flex h-64 items-center justify-center">
			<div class="h-12 w-12 animate-spin rounded-full border-b-2 border-indigo-600"></div>
		</div>
	{:else if kidData}
		<!-- Account Overview -->
		<div class="mb-8 overflow-hidden rounded-lg bg-white shadow">
			<div class="px-4 py-5 sm:p-6">
				<h1 class="mb-4 text-2xl font-bold text-gray-900">Welcome, {kidData.name}!</h1>

				<div class="grid grid-cols-1 gap-6 md:grid-cols-3">
					<div class="rounded-lg bg-green-50 p-4">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<svg
									class="h-8 w-8 text-green-400"
									fill="none"
									viewBox="0 0 24 24"
									stroke="currentColor"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"
									/>
								</svg>
							</div>
							<div class="ml-4">
								<p class="text-sm font-medium text-green-800">{m.current_balance()}</p>
								<p class="text-2xl font-bold text-green-900">
									{formatCurrency(kidData.current_balance)}
								</p>
							</div>
						</div>
					</div>

					<div class="rounded-lg bg-blue-50 p-4">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<svg
									class="h-8 w-8 text-blue-400"
									fill="none"
									viewBox="0 0 24 24"
									stroke="currentColor"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M8 7V3a4 4 0 118 0v4m-4 8a4 4 0 01-4-4v-4h8v4a4 4 0 01-4 4z"
									/>
								</svg>
							</div>
							<div class="ml-4">
								<p class="text-sm font-medium text-blue-800">{m.weekly_allowance()}</p>
								<p class="text-2xl font-bold text-blue-900">
									{formatCurrency(kidData.weekly_allowance)}
								</p>
							</div>
						</div>
					</div>

					<div class="rounded-lg bg-purple-50 p-4">
						<div class="flex items-center">
							<div class="flex-shrink-0">
								<svg
									class="h-8 w-8 text-purple-400"
									fill="none"
									viewBox="0 0 24 24"
									stroke="currentColor"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
									/>
								</svg>
							</div>
							<div class="ml-4">
								<p class="text-sm font-medium text-purple-800">{m.interest_rate()}</p>
								<p class="text-2xl font-bold text-purple-900">
									{(kidData.interest_rate * 100).toFixed(1)}%
								</p>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- Withdrawal Form -->
		<div class="mb-8 overflow-hidden rounded-lg bg-white shadow">
			<div class="px-4 py-5 sm:p-6">
				<h2 class="mb-4 text-lg font-semibold text-gray-900">{m.make_withdrawal()}</h2>

				<form
					onsubmit={(e) => {
						e.preventDefault();
						handleWithdrawal();
					}}
					class="space-y-4"
				>
					<div class="grid grid-cols-1 gap-4 md:grid-cols-2">
						<div>
							<label for="amount" class="block text-sm font-medium text-gray-700"
								>{m.amount()}</label
							>
							<div class="relative mt-1 rounded-md shadow-sm">
								<div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
									<span class="text-gray-500 sm:text-sm">€</span>
								</div>
								<input
									type="number"
									step="0.01"
									min="0"
									max={kidData.current_balance}
									id="amount"
									bind:value={withdrawalAmount}
									class="block w-full rounded-md border-gray-300 pr-12 pl-7 focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
									placeholder="0.00"
									disabled={isWithdrawing}
									required
								/>
							</div>
						</div>

						<div>
							<label for="description" class="block text-sm font-medium text-gray-700"
								>{m.description()}</label
							>
							<input
								type="text"
								id="description"
								bind:value={withdrawalDescription}
								class="mt-1 block w-full rounded-md border-gray-300 focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
								placeholder="What is this for?"
								disabled={isWithdrawing}
								required
							/>
						</div>
					</div>

					{#if withdrawalError}
						<div class="text-sm text-red-600">{withdrawalError}</div>
					{/if}

					<button
						type="submit"
						disabled={isWithdrawing}
						class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
					>
						{#if isWithdrawing}
							<svg
								class="mr-2 -ml-1 h-4 w-4 animate-spin text-white"
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
							{m.withdrawal_submit()}
						{/if}
					</button>
				</form>
			</div>
		</div>

		<!-- Transaction History -->
		<div class="overflow-hidden rounded-lg bg-white shadow">
			<div class="px-4 py-5 sm:p-6">
				<h2 class="mb-4 text-lg font-semibold text-gray-900">{m.recent_transactions()}</h2>

				{#if transactions.length === 0}
					<p class="py-8 text-center text-gray-500">{m.no_transactions_message()}</p>
				{:else}
					<div class="overflow-x-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th
										class="px-6 py-3 text-left text-xs font-medium tracking-wider text-gray-500 uppercase"
										>{m.date()}</th
									>
									<th
										class="px-6 py-3 text-left text-xs font-medium tracking-wider text-gray-500 uppercase"
										>{m.type()}</th
									>
									<th
										class="px-6 py-3 text-left text-xs font-medium tracking-wider text-gray-500 uppercase"
										>{m.description()}</th
									>
									<th
										class="px-6 py-3 text-right text-xs font-medium tracking-wider text-gray-500 uppercase"
										>{m.amount()}</th
									>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-200 bg-white">
								{#each transactions as transaction (transaction.id)}
									<tr>
										<td class="px-6 py-4 text-sm whitespace-nowrap text-gray-900">
											{formatDate(transaction.created_at)}
										</td>
										<td class="px-6 py-4 whitespace-nowrap">
											<span
												class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800"
											>
												{getTransactionTypeLabel(transaction.type)}
											</span>
										</td>
										<td class="px-6 py-4 text-sm whitespace-nowrap text-gray-900">
											{transaction.description || '-'}
										</td>
										<td
											class="px-6 py-4 text-right text-sm whitespace-nowrap {getTransactionColor(
												transaction.type
											)} font-medium"
										>
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
