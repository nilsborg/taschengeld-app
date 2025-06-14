<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabase';
	import { getUser } from '$lib/stores/auth.svelte';
	import type { Kid, TransactionWithKid, KidLinkingRequest } from '$lib/supabase';

	let kids = $state<Kid[]>([]);
	let transactions = $state<TransactionWithKid[]>([]);
	let linkingRequests = $state<KidLinkingRequest[]>([]);
	let isLoading = $state(true);
	let error = $state<string | null>(null);
	
	// Allowance management
	let isAddingAllowance = $state(false);
	let allowanceError = $state<string | null>(null);
	
	// Interest management
	let isAddingInterest = $state(false);
	let interestError = $state<string | null>(null);
	
	// Kid management
	let showAddKidForm = $state(false);
	let newKidName = $state('');
	let newKidAllowance = $state(10.00);
	let newKidInterestRate = $state(0.01);
	let newKidInitialBalance = $state('');
	let isAddingKid = $state(false);
	let addKidError = $state<string | null>(null);

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		isLoading = true;
		await Promise.all([loadKids(), loadAllTransactions(), loadLinkingRequests()]);
		isLoading = false;
	}

	async function loadKids() {
		const currentUser = getUser();
		if (!currentUser) {
			error = 'Not authenticated';
			return;
		}

		try {
			const { data, error: kidError } = await supabase
				.from('kids')
				.select('*')
				.eq('parent_id', currentUser.id)
				.order('name');

			if (kidError) {
				throw kidError;
			}

			kids = data || [];
		} catch (err) {
			console.error('Error loading kids:', err);
			error = 'Failed to load kids data';
		}
	}

	async function loadAllTransactions() {
		const currentUser = getUser();
		if (!currentUser) {
			error = 'Not authenticated';
			return;
		}

		try {
			const { data, error: transactionError } = await supabase
				.from('transactions')
				.select(`
					*,
					kids!inner (name, parent_id)
				`)
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
		}
	}

	async function addWeeklyAllowance() {
		isAddingAllowance = true;
		allowanceError = null;

		try {
			for (const kid of kids) {
				// Create allowance transaction
				const { error: transactionError } = await supabase
					.from('transactions')
					.insert({
						kid_id: kid.id,
						type: 'weekly_allowance',
						amount: kid.weekly_allowance,
						description: 'Weekly allowance'
					});

				if (transactionError) {
					throw transactionError;
				}

				// Update kid's balance
				const newBalance = kid.current_balance + kid.weekly_allowance;
				const { error: updateError } = await supabase
					.from('kids')
					.update({ current_balance: newBalance })
					.eq('id', kid.id);

				if (updateError) {
					throw updateError;
				}

				// Update local state
				kid.current_balance = newBalance;
			}

			await loadAllTransactions();
		} catch (err) {
			console.error('Error adding weekly allowance:', err);
			allowanceError = 'Failed to add weekly allowance';
		} finally {
			isAddingAllowance = false;
		}
	}

	async function addMonthlyInterest() {
		isAddingInterest = true;
		interestError = null;

		try {
			for (const kid of kids) {
				if (kid.current_balance > 0) {
					const interestAmount = kid.current_balance * kid.interest_rate;
					
					// Create interest transaction
					const { error: transactionError } = await supabase
						.from('transactions')
						.insert({
							kid_id: kid.id,
							type: 'interest',
							amount: interestAmount,
							description: `Monthly interest (${(kid.interest_rate * 100).toFixed(1)}%)`
						});

					if (transactionError) {
						throw transactionError;
					}

					// Update kid's balance
					const newBalance = kid.current_balance + interestAmount;
					const { error: updateError } = await supabase
						.from('kids')
						.update({ current_balance: newBalance })
						.eq('id', kid.id);

					if (updateError) {
						throw updateError;
					}

					// Update local state
					kid.current_balance = newBalance;
				}
			}

			await loadAllTransactions();
		} catch (err) {
			console.error('Error adding monthly interest:', err);
			interestError = 'Failed to add monthly interest';
		} finally {
			isAddingInterest = false;
		}
	}

	async function addNewKid() {
		const currentUser = getUser();
		if (!currentUser) {
			addKidError = 'Not authenticated';
			return;
		}

		if (!newKidName.trim()) {
			addKidError = 'Please enter a name';
			return;
		}

		isAddingKid = true;
		addKidError = null;

		try {
			const { data, error: insertError } = await supabase
				.from('kids')
				.insert({
					name: newKidName.trim(),
					weekly_allowance: newKidAllowance,
					interest_rate: newKidInterestRate,
					current_balance: newKidInitialBalance ? parseFloat(newKidInitialBalance) : 0,
					parent_id: currentUser.id
				})
				.select()
				.single();

			if (insertError) {
				throw insertError;
			}

			kids = [...kids, data];
			
			// Reset form
			newKidName = '';
			newKidAllowance = 10.00;
			newKidInterestRate = 0.01;
			newKidInitialBalance = '';
			showAddKidForm = false;
		} catch (err) {
			console.error('Error adding new kid:', err);
			addKidError = 'Failed to add new kid';
		} finally {
			isAddingKid = false;
		}
	}

	async function loadLinkingRequests() {
		const currentUser = getUser();
		if (!currentUser) {
			error = 'Not authenticated';
			return;
		}

		try {
			const { data, error: requestError } = await supabase
				.from('kid_linking_requests')
				.select(`
					*,
					kids!inner (name, parent_id),
					profiles!kid_linking_requests_user_id_fkey (full_name, email)
				`)
				.eq('kids.parent_id', currentUser.id)
				.eq('status', 'pending')
				.order('requested_at', { ascending: false });

			if (requestError) {
				throw requestError;
			}

			linkingRequests = data || [];
		} catch (err) {
			console.error('Error loading linking requests:', err);
		}
	}

	async function generateInvitationCode(kidId: number) {
		try {
			const { data, error } = await supabase.rpc('set_invitation_code_for_kid', {
				kid_id: kidId
			});

			if (error) {
				throw error;
			}

			// Update local state
			const kidIndex = kids.findIndex(k => k.id === kidId);
			if (kidIndex !== -1) {
				kids[kidIndex] = { ...kids[kidIndex], invitation_code: data };
			}

			return data;
		} catch (err) {
			console.error('Error generating invitation code:', err);
			throw err;
		}
	}

	async function clearInvitationCode(kidId: number) {
		try {
			const { error } = await supabase
				.from('kids')
				.update({ invitation_code: null })
				.eq('id', kidId);

			if (error) {
				throw error;
			}

			// Update local state
			const kidIndex = kids.findIndex(k => k.id === kidId);
			if (kidIndex !== -1) {
				kids[kidIndex] = { ...kids[kidIndex], invitation_code: null };
			}
		} catch (err) {
			console.error('Error clearing invitation code:', err);
		}
	}

	async function approveLinkingRequest(requestId: number) {
		try {
			const request = linkingRequests.find(r => r.id === requestId);
			if (!request) return;

			// Update the linking request status
			const { error: requestError } = await supabase
				.from('kid_linking_requests')
				.update({ 
					status: 'approved',
					resolved_at: new Date().toISOString(),
					resolved_by: getUser()?.id
				})
				.eq('id', requestId);

			if (requestError) {
				throw requestError;
			}

			// Link the kid account
			const { error: linkError } = await supabase
				.from('kids')
				.update({ user_id: request.user_id })
				.eq('id', request.kid_id);

			if (linkError) {
				throw linkError;
			}

			// Reload data
			await loadData();
		} catch (err) {
			console.error('Error approving linking request:', err);
		}
	}

	async function rejectLinkingRequest(requestId: number) {
		try {
			const { error } = await supabase
				.from('kid_linking_requests')
				.update({ 
					status: 'rejected',
					resolved_at: new Date().toISOString(),
					resolved_by: getUser()?.id
				})
				.eq('id', requestId);

			if (error) {
				throw error;
			}

			// Remove from local state
			linkingRequests = linkingRequests.filter(r => r.id !== requestId);
		} catch (err) {
			console.error('Error rejecting linking request:', err);
		}
	}

	async function updateKidSettings(kid: Kid, field: string, value: number) {
		const oldValue = kid[field as keyof Kid] as number;
		
		// Don't update if value hasn't changed
		if (oldValue === value) {
			return;
		}

		try {
			const { error } = await supabase
				.from('kids')
				.update({ [field]: value })
				.eq('id', kid.id);

			if (error) {
				throw error;
			}

			// Create audit log transaction
			let transactionType: 'allowance_change' | 'interest_rate_change';
			let description: string;
			let amount: number;

			if (field === 'weekly_allowance') {
				transactionType = 'allowance_change';
				const delta = value - oldValue;
				description = `Weekly allowance changed from ${formatCurrency(oldValue)} to ${formatCurrency(value)}`;
				amount = delta; // Store the change amount, not the new value
			} else if (field === 'interest_rate') {
				transactionType = 'interest_rate_change';
				const deltaPercent = (value - oldValue) * 100; // Convert to percentage points
				description = `Interest rate changed from ${(oldValue * 100).toFixed(1)}% to ${(value * 100).toFixed(1)}%`;
				amount = deltaPercent; // Store the percentage point change
			} else {
				// Unknown field, still log but with generic info
				transactionType = 'allowance_change';
				const delta = value - oldValue;
				description = `Setting '${field}' changed from ${oldValue} to ${value}`;
				amount = delta;
			}

			// Insert audit log transaction
			const { error: transactionError } = await supabase
				.from('transactions')
				.insert({
					kid_id: kid.id,
					type: transactionType,
					amount: amount,
					description: description
				});

			if (transactionError) {
				console.error('Error logging settings change:', transactionError);
				// Don't throw error here - the main update succeeded
			}

			// Update local state
			const kidIndex = kids.findIndex(k => k.id === kid.id);
			if (kidIndex !== -1) {
				kids[kidIndex] = { ...kids[kidIndex], [field]: value };
			}

			// Reload transactions to show the new log entry
			await loadAllTransactions();
		} catch (err) {
			console.error('Error updating kid settings:', err);
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

	let totalBalance = $derived(kids.reduce((sum, kid) => sum + kid.current_balance, 0));
	let totalWeeklyAllowance = $derived(kids.reduce((sum, kid) => sum + kid.weekly_allowance, 0));
</script>

<svelte:head>
	<title>Parent Dashboard - Taschengeld App</title>
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
	{:else}
		<!-- Overview Cards -->
		<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
			<div class="bg-white overflow-hidden shadow rounded-lg">
				<div class="p-5">
					<div class="flex items-center">
						<div class="flex-shrink-0">
							<svg class="h-8 w-8 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
							</svg>
						</div>
						<div class="ml-5 w-0 flex-1">
							<dl>
								<dt class="text-sm font-medium text-gray-500 truncate">Total Balance</dt>
								<dd class="text-lg font-medium text-gray-900">{formatCurrency(totalBalance)}</dd>
							</dl>
						</div>
					</div>
				</div>
			</div>

			<div class="bg-white overflow-hidden shadow rounded-lg">
				<div class="p-5">
					<div class="flex items-center">
						<div class="flex-shrink-0">
							<svg class="h-8 w-8 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
							</svg>
						</div>
						<div class="ml-5 w-0 flex-1">
							<dl>
								<dt class="text-sm font-medium text-gray-500 truncate">Total Kids</dt>
								<dd class="text-lg font-medium text-gray-900">{kids.length}</dd>
							</dl>
						</div>
					</div>
				</div>
			</div>

			<div class="bg-white overflow-hidden shadow rounded-lg">
				<div class="p-5">
					<div class="flex items-center">
						<div class="flex-shrink-0">
							<svg class="h-8 w-8 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3a4 4 0 118 0v4m-4 8a4 4 0 01-4-4v-4h8v4a4 4 0 01-4 4z" />
							</svg>
						</div>
						<div class="ml-5 w-0 flex-1">
							<dl>
								<dt class="text-sm font-medium text-gray-500 truncate">Weekly Allowance</dt>
								<dd class="text-lg font-medium text-gray-900">{formatCurrency(totalWeeklyAllowance)}</dd>
							</dl>
						</div>
					</div>
				</div>
			</div>
		</div>

		<!-- Actions -->
		<div class="bg-white shadow rounded-lg mb-8">
			<div class="px-4 py-5 sm:p-6">
				<h2 class="text-lg font-semibold text-gray-900 mb-4">Management Actions</h2>
				
				<div class="flex flex-wrap gap-4">
					<button
						onclick={addWeeklyAllowance}
						disabled={isAddingAllowance || kids.length === 0}
						class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{#if isAddingAllowance}
							<svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							Adding...
						{:else}
							Add Weekly Allowance to All
						{/if}
					</button>

					<button
						onclick={addMonthlyInterest}
						disabled={isAddingInterest || kids.length === 0}
						class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{#if isAddingInterest}
							<svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							Adding...
						{:else}
							Add Monthly Interest to All
						{/if}
					</button>

					<button
						onclick={() => showAddKidForm = !showAddKidForm}
						class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
					>
						{showAddKidForm ? 'Cancel' : 'Add New Kid'}
					</button>
				</div>

				{#if allowanceError}
					<div class="text-red-600 text-sm mt-2">{allowanceError}</div>
				{/if}
				{#if interestError}
					<div class="text-red-600 text-sm mt-2">{interestError}</div>
				{/if}
			</div>
		</div>

		<!-- Add Kid Form -->
		{#if showAddKidForm}
			<div class="bg-white shadow rounded-lg mb-8">
				<div class="px-4 py-5 sm:p-6">
					<h3 class="text-lg font-semibold text-gray-900 mb-4">Add New Kid</h3>
					
					<form onsubmit={(e) => { e.preventDefault(); addNewKid(); }} class="space-y-4">
						<div class="grid grid-cols-1 md:grid-cols-4 gap-4">
							<div>
								<label for="kidName" class="block text-sm font-medium text-gray-700">Name</label>
								<input
									type="text"
									id="kidName"
									bind:value={newKidName}
									class="mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
									placeholder="Kid's name"
									disabled={isAddingKid}
									required
								/>
							</div>

							<div>
								<label for="kidAllowance" class="block text-sm font-medium text-gray-700">Weekly Allowance (€)</label>
								<input
									type="number"
									step="0.01"
									min="0"
									id="kidAllowance"
									bind:value={newKidAllowance}
									class="mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
									disabled={isAddingKid}
								/>
							</div>

							<div>
								<label for="kidInterest" class="block text-sm font-medium text-gray-700">Interest Rate (%)</label>
								<input
									type="number"
									step="0.1"
									min="0"
									id="kidInterest"
									bind:value={newKidInterestRate}
									class="mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
									disabled={isAddingKid}
								/>
							</div>

							<div>
								<label for="kidInitialBalance" class="block text-sm font-medium text-gray-700">Initial Balance (€)</label>
								<input
									type="number"
									step="0.01"
									min="0"
									id="kidInitialBalance"
									bind:value={newKidInitialBalance}
									class="mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
									placeholder="0.00 (optional)"
									disabled={isAddingKid}
								/>
							</div>
						</div>

						{#if addKidError}
							<div class="text-red-600 text-sm">{addKidError}</div>
						{/if}

						<div class="flex space-x-3">
							<button
								type="submit"
								disabled={isAddingKid}
								class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
							>
								{#if isAddingKid}
									<svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
										<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
										<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
									</svg>
									Adding...
								{:else}
									Add Kid
								{/if}
							</button>

							<button
								type="button"
								onclick={() => showAddKidForm = false}
								class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
							>
								Cancel
							</button>
						</div>
					</form>
				</div>
			</div>
		{/if}

		<!-- Kids Management -->
		<div class="bg-white shadow rounded-lg mb-8">
			<div class="px-4 py-5 sm:p-6">
				<h2 class="text-lg font-semibold text-gray-900 mb-4">Kids Overview</h2>
				
				{#if kids.length === 0}
					<p class="text-gray-500 text-center py-8">No kids added yet. Add your first kid to get started!</p>
				{:else}
					<div class="overflow-x-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
									<th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Balance</th>
									<th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Weekly Allowance</th>
									<th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Interest Rate</th>
									<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Account Status</th>
									<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each kids as kid (kid.id)}
									<tr>
										<td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
											{kid.name}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">
											{formatCurrency(kid.current_balance)}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">
											<input
												type="number"
												step="0.01"
												min="0"
												value={kid.weekly_allowance}
												onblur={(e) => updateKidSettings(kid, 'weekly_allowance', parseFloat((e.target as HTMLInputElement).value))}
												class="w-20 px-2 py-1 border border-gray-300 rounded-md text-sm"
											/>
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">
											<input
												type="number"
												step="0.001"
												min="0"
												value={(kid.interest_rate * 100).toFixed(1)}
												onblur={(e) => updateKidSettings(kid, 'interest_rate', parseFloat((e.target as HTMLInputElement).value) / 100)}
												class="w-16 text-right border-gray-300 rounded-md text-sm"
											/>%
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-center text-sm">
											{#if kid.user_id}
												<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
													Linked
												</span>
											{:else if kid.invitation_code}
												<div class="space-y-1">
													<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
														Code: {kid.invitation_code}
													</span>
													<button
														onclick={() => clearInvitationCode(kid.id)}
														class="text-xs text-red-600 hover:text-red-900"
													>
														Clear
													</button>
												</div>
											{:else}
												<button
													onclick={() => generateInvitationCode(kid.id)}
													class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800 hover:bg-gray-200"
												>
													Generate Code
												</button>
											{/if}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-center text-sm font-medium">
											<a href="/kid-profile?kid_id={kid.id}" class="text-indigo-600 hover:text-indigo-900">View Details</a>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		</div>

		<!-- Linking Requests -->
		{#if linkingRequests.length > 0}
			<div class="bg-white shadow rounded-lg mb-8">
				<div class="px-4 py-5 sm:p-6">
					<h2 class="text-lg font-semibold text-gray-900 mb-4">Account Linking Requests</h2>
					<p class="text-sm text-gray-600 mb-4">Kids who have registered and want to link their accounts to your kid records.</p>
					
					<div class="overflow-x-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Kid Name</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User Account</th>
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Requested At</th>
									<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each linkingRequests as request (request.id)}
									<tr>
										<td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
											{request.kids?.name || 'Unknown'}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
											<div>
												<div class="font-medium">{request.profiles?.full_name || 'Unknown'}</div>
												<div class="text-gray-500">{request.profiles?.email || 'No email'}</div>
											</div>
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
											{formatDate(request.requested_at)}
										</td>
										<td class="px-6 py-4 whitespace-nowrap text-center text-sm font-medium space-x-2">
											<button
												onclick={() => approveLinkingRequest(request.id)}
												class="inline-flex items-center px-3 py-1 border border-transparent text-xs font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
											>
												Approve
											</button>
											<button
												onclick={() => rejectLinkingRequest(request.id)}
												class="inline-flex items-center px-3 py-1 border border-gray-300 text-xs font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
											>
												Reject
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			</div>
		{/if}

		<!-- Recent Transactions -->
		<div class="bg-white shadow rounded-lg">
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
									<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Kid</th>
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
										<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
											{transaction.kids?.name || 'Unknown'}
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