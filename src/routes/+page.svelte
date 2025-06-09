<script lang="ts">
	import { enhance } from '$app/forms';
	import type { Kid, Transaction } from '$lib/server/db/schema';

	let { data }: { data: { louis?: Kid; transactions?: Transaction[] } } = $props();

	// Format currency
	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat('de-DE', {
			style: 'currency',
			currency: 'EUR'
		}).format(amount);
	}

	// Format date
	function formatDate(timestamp: number | Date | null): string {
		if (!timestamp) return '';
		const date = typeof timestamp === 'number' ? new Date(timestamp * 1000) : new Date(timestamp);
		return date.toLocaleDateString('de-DE', {
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
	<div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
		<header class="mb-8 text-center">
			<h1 class="text-3xl font-bold text-gray-900">Louis' Taschengeld</h1>
			<p class="mt-2 text-gray-600">Verwalte dein Taschengeld</p>
		</header>

		<!-- Current Balance Card -->
		<section class="mb-8 rounded-lg bg-white p-6 shadow-md">
			<h2 class="mb-4 text-xl font-semibold text-gray-800">Aktueller Kontostand</h2>
			<div class="text-center">
				<div class="mb-2 text-4xl font-bold text-green-600">
					{formatCurrency(data.louis?.currentBalance ?? 0)}
				</div>
				<p class="text-gray-600">Verfügbares Guthaben</p>
			</div>
		</section>

		<div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
			<!-- Actions Section -->
			<section class="space-y-6">
				<!-- Withdrawal Form -->
				<div class="rounded-lg bg-white p-6 shadow-md">
					<h2 class="mb-4 text-xl font-semibold text-gray-800">Geld ausgeben</h2>
					<form method="POST" action="?/withdraw" use:enhance>
						<div class="space-y-4">
							<div>
								<label for="amount" class="mb-1 block text-sm font-medium text-gray-700">
									Betrag (€)
								</label>
								<input
									type="number"
									id="amount"
									name="amount"
									step="0.01"
									min="0.01"
									max={data.louis?.currentBalance ?? 0}
									class="w-full rounded-md border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:outline-none"
									required
								/>
							</div>
							<div>
								<label for="description" class="mb-1 block text-sm font-medium text-gray-700">
									Wofür?
								</label>
								<input
									type="text"
									id="description"
									name="description"
									placeholder="z.B. Süßigkeiten, Spielzeug..."
									class="w-full rounded-md border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:outline-none"
									required
								/>
							</div>
							<button
								type="submit"
								class="w-full rounded-md bg-red-600 px-4 py-2 text-white hover:bg-red-700 focus:ring-2 focus:ring-red-500 focus:outline-none"
							>
								Geld ausgeben
							</button>
						</div>
					</form>
				</div>

				<!-- Manual Actions -->
				<div class="rounded-lg bg-white p-6 shadow-md">
					<h2 class="mb-4 text-xl font-semibold text-gray-800">Manuelle Aktionen</h2>
					<div class="space-y-3">
						<form method="POST" action="?/addWeeklyAllowance" use:enhance>
							<button
								type="submit"
								class="w-full rounded-md bg-green-600 px-4 py-2 text-white hover:bg-green-700 focus:ring-2 focus:ring-green-500 focus:outline-none"
							>
								Wöchentliches Taschengeld hinzufügen
							</button>
						</form>
						<form method="POST" action="?/addInterest" use:enhance>
							<button
								type="submit"
								class="w-full rounded-md bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:outline-none"
							>
								Monatliche Zinsen hinzufügen
							</button>
						</form>
					</div>
				</div>

				<!-- Settings -->
				<div class="rounded-lg bg-white p-6 shadow-md">
					<h2 class="mb-4 text-xl font-semibold text-gray-800">Einstellungen</h2>
					<form method="POST" action="?/updateSettings" use:enhance>
						<div class="space-y-4">
							<div>
								<label for="weeklyAllowance" class="mb-1 block text-sm font-medium text-gray-700">
									Wöchentliches Taschengeld (€)
								</label>
								<input
									type="number"
									id="weeklyAllowance"
									name="weeklyAllowance"
									step="0.01"
									min="0"
									value={data.louis?.weeklyAllowance ?? 10}
									class="w-full rounded-md border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:outline-none"
									required
								/>
							</div>
							<div>
								<label for="interestRate" class="mb-1 block text-sm font-medium text-gray-700">
									Monatlicher Zinssatz (%)
								</label>
								<input
									type="number"
									id="interestRate"
									name="interestRate"
									step="0.01"
									min="0"
									value={((data.louis?.interestRate ?? 0.01) * 100).toFixed(2)}
									class="w-full rounded-md border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:outline-none"
									required
								/>
							</div>
							<button
								type="submit"
								class="w-full rounded-md bg-gray-600 px-4 py-2 text-white hover:bg-gray-700 focus:ring-2 focus:ring-gray-500 focus:outline-none"
							>
								Einstellungen speichern
							</button>
						</div>
					</form>
				</div>
			</section>

			<!-- Transaction History -->
			<section class="rounded-lg bg-white p-6 shadow-md">
				<h2 class="mb-4 text-xl font-semibold text-gray-800">Verlauf</h2>
				{#if data.transactions && data.transactions.length > 0}
					<div class="max-h-96 space-y-3 overflow-y-auto">
						{#each data.transactions as transaction (transaction.id)}
							<div class="border-b border-gray-200 pb-3 last:border-b-0">
								<div class="flex items-start justify-between">
									<div class="flex-1">
										<div class="font-medium {getTransactionColor(transaction.type)}">
											{getTransactionTypeDisplay(transaction.type)}
										</div>
										{#if transaction.description}
											<div class="mt-1 text-sm text-gray-600">
												{transaction.description}
											</div>
										{/if}
										<div class="mt-1 text-xs text-gray-500">
											{formatDate(transaction.createdAt)}
										</div>
									</div>
									<div
										class="font-semibold {transaction.amount >= 0
											? 'text-green-600'
											: 'text-red-600'}"
									>
										{transaction.amount >= 0 ? '+' : ''}{formatCurrency(transaction.amount)}
									</div>
								</div>
							</div>
						{/each}
					</div>
				{:else}
					<p class="py-8 text-center text-gray-500">Noch keine Transaktionen vorhanden.</p>
				{/if}
			</section>
		</div>

		<!-- Success/Error Messages -->
		<!-- Note: Form feedback will be handled via enhanced forms or client-side state -->
	</div>
</main>
