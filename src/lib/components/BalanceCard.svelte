<script lang="ts">
	import type { Kid } from '$lib/server/supabase';

	let { louis }: { louis?: Kid } = $props();

	// Format currency
	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat('de-DE', {
			style: 'currency',
			currency: 'EUR'
		}).format(amount);
	}
</script>

<section class="mb-8 rounded-lg bg-white p-6 shadow-md">
	<h2 class="mb-4 text-xl font-semibold text-gray-800">Aktueller Kontostand</h2>
	<div class="text-center">
		<div class="mb-2 text-4xl font-bold text-green-600">
			{formatCurrency(louis?.current_balance ?? 0)}
		</div>
		<p class="text-gray-600">Verfügbares Guthaben</p>
	</div>
</section>