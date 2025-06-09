<script lang="ts">
	import type { Transaction } from '$lib/server/supabase';

	let { transactions }: { transactions?: Transaction[] } = $props();

	// Format currency
	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat('de-DE', {
			style: 'currency',
			currency: 'EUR'
		}).format(amount);
	}

	// Format date
	function formatDate(timestamp: string | Date | null): string {
		if (!timestamp) return '';
		const date = new Date(timestamp);
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

<div class="rounded-lg bg-white p-6 shadow-md">
	<h2 class="mb-4 text-xl font-semibold text-gray-800">Verlauf</h2>
	{#if transactions && transactions.length > 0}
		<div class="max-h-96 space-y-3 overflow-y-auto">
			{#each transactions as transaction (transaction.id)}
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
								{formatDate(transaction.created_at)}
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
</div>