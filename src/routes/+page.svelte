<script lang="ts">
	import { enhance } from '$app/forms';
	import type { PageData, ActionData } from './$types';

	let { data }: { data: PageData } = $props();
	let form: ActionData = $state(null);

	// Format currency
	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat('de-DE', {
			style: 'currency',
			currency: 'EUR'
		}).format(amount);
	}

	// Format date
	function formatDate(timestamp: number): string {
		return new Date(timestamp * 1000).toLocaleDateString('de-DE', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	// Get transaction type display
	function getTransactionTypeDisplay(type: string): string {
		switch (type) {
			case 'weekly_allowance':
				return 'Wöchentliches Taschengeld';
			case 'interest':
				return 'Zinsen';
			case 'withdrawal':
				return 'Ausgabe';
			default:
				return type;
		}
	}

	// Get transaction color class
	function getTransactionColor(type: string): string {
		switch (type) {
			case 'weekly_allowance':
				return 'text-green-600';
			case 'interest':
				return 'text-blue-600';
			case 'withdrawal':
				return 'text-red-600';
			default:
				return 'text-gray-600';
		}
	}
</script>

<svelte:head>
	<title>Louis' Taschengeld</title>
</svelte:head>

<main class="min-h-screen bg-gray-50 py-8">
	<div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
		<header class="text-center mb-8">
			<h1 class="text-3xl font-bold text-gray-900">Louis' Taschengeld</h1>
			<p class="text-gray-600 mt-2">Verwalte dein Taschengeld</p>
		</header>

		<!-- Current Balance Card -->
		<section class="bg-white rounded-lg shadow-md p-6 mb-8">
			<h2 class="text-xl font-semibold text-gray-800 mb-4">Aktueller Kontostand</h2>
			<div class="text-center">
				<div class="text-4xl font-bold text-green-600 mb-2">
					{formatCurrency(data.louis?.currentBalance ?? 0)}
				</div>
				<p class="text-gray-600">Verfügbares Guthaben</p>
			</div>
		</section>

		<div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
			<!-- Actions Section -->
			<section class="space-y-6">
				<!-- Withdrawal Form -->
				<div class="bg-white rounded-lg shadow-md p-6">
					<h2 class="text-xl font-semibold text-gray-800 mb-4">Geld ausgeben</h2>
					<form method="POST" action="?/withdraw" use:enhance>
						<div class="space-y-4">
							<div>
								<label for="amount" class="block text-sm font-medium text-gray-700 mb-1">
									Betrag (€)
								</label>
								<input
									type="number"
									id="amount"
									name="amount"
									step="0.01"
									min="0.01"
									max={data.louis?.currentBalance ?? 0}
									class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
									required
								/>
							</div>
							<div>
								<label for="description" class="block text-sm font-medium text-gray-700 mb-1">
									Wofür?
								</label>
								<input
									type="text"
									id="description"
									name="description"
									placeholder="z.B. Süßigkeiten, Spielzeug..."
									class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
									required
								/>
							</div>
							<button
								type="submit"
								class="w-full bg-red-600 text-white py-2 px-4 rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500"
							>
								Geld ausgeben
							</button>
						</div>
					</form>
				</div>

				<!-- Manual Actions -->
				<div class="bg-white rounded-lg shadow-md p-6">
					<h2 class="text-xl font-semibold text-gray-800 mb-4">Manuelle Aktionen</h2>
					<div class="space-y-3">
						<form method="POST" action="?/addWeeklyAllowance" use:enhance>
							<button
								type="submit"
								class="w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500"
							>
								Wöchentliches Taschengeld hinzufügen
							</button>
						</form>
						<form method="POST" action="?/addInterest" use:enhance>
							<button
								type="submit"
								class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
							>
								Monatliche Zinsen hinzufügen
							</button>
						</form>
					</div>
				</div>

				<!-- Settings -->
				<div class="bg-white rounded-lg shadow-md p-6">
					<h2 class="text-xl font-semibold text-gray-800 mb-4">Einstellungen</h2>
					<form method="POST" action="?/updateSettings" use:enhance>
						<div class="space-y-4">
							<div>
								<label for="weeklyAllowance" class="block text-sm font-medium text-gray-700 mb-1">
									Wöchentliches Taschengeld (€)
								</label>
								<input
									type="number"
									id="weeklyAllowance"
									name="weeklyAllowance"
									step="0.01"
									min="0"
									value={data.louis?.weeklyAllowance ?? 10}
									class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
									required
								/>
							</div>
							<div>
								<label for="interestRate" class="block text-sm font-medium text-gray-700 mb-1">
									Monatlicher Zinssatz (%)
								</label>
								<input
									type="number"
									id="interestRate"
									name="interestRate"
									step="0.01"
									min="0"
									value={((data.louis?.interestRate ?? 0.01) * 100).toFixed(2)}
									class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
									required
								/>
							</div>
							<button
								type="submit"
								class="w-full bg-gray-600 text-white py-2 px-4 rounded-md hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500"
							>
								Einstellungen speichern
							</button>
						</div>
					</form>
				</div>
			</section>

			<!-- Transaction History -->
			<section class="bg-white rounded-lg shadow-md p-6">
				<h2 class="text-xl font-semibold text-gray-800 mb-4">Verlauf</h2>
				{#if data.transactions && data.transactions.length > 0}
					<div class="space-y-3 max-h-96 overflow-y-auto">
						{#each data.transactions as transaction}
							<div class="border-b border-gray-200 pb-3 last:border-b-0">
								<div class="flex justify-between items-start">
									<div class="flex-1">
										<div class="font-medium {getTransactionColor(transaction.type)}">
											{getTransactionTypeDisplay(transaction.type)}
										</div>
										{#if transaction.description}
											<div class="text-sm text-gray-600 mt-1">
												{transaction.description}
											</div>
										{/if}
										<div class="text-xs text-gray-500 mt-1">
											{formatDate(transaction.createdAt)}
										</div>
									</div>
									<div class="font-semibold {transaction.amount >= 0 ? 'text-green-600' : 'text-red-600'}">
										{transaction.amount >= 0 ? '+' : ''}{formatCurrency(transaction.amount)}
									</div>
								</div>
							</div>
						{/each}
					</div>
				{:else}
					<p class="text-gray-500 text-center py-8">Noch keine Transaktionen vorhanden.</p>
				{/if}
			</section>
		</div>

		<!-- Success/Error Messages -->
		{#if form?.error}
			<div class="fixed top-4 right-4 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
				{form.error}
			</div>
		{/if}

		{#if form?.success && form?.message}
			<div class="fixed top-4 right-4 bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded">
				{form.message}
			</div>
		{/if}
	</div>
</main>