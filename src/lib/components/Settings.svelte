<script lang="ts">
	import { enhance } from '$app/forms';
	import type { Kid } from '$lib/server/supabase';

	let { louis }: { louis?: Kid } = $props();

	let settingsLoading = $state(false);
</script>

<div class="rounded-lg bg-white p-6 shadow-md">
	<h2 class="mb-4 text-xl font-semibold text-gray-800">Einstellungen</h2>
	<form 
		method="POST" 
		action="?/updateSettings" 
		use:enhance={() => {
			settingsLoading = true;
			return async ({ update }) => {
				await update();
				settingsLoading = false;
			};
		}}
	>
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
					value={louis?.weekly_allowance ?? 10}
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
					value={((louis?.interest_rate ?? 0.01) * 100).toFixed(2)}
					class="w-full rounded-md border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:outline-none"
					required
				/>
			</div>
			<button
				type="submit"
				disabled={settingsLoading}
				class="w-full rounded-md bg-gray-600 px-4 py-2 text-white hover:bg-gray-700 focus:ring-2 focus:ring-gray-500 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
			>
				{#if settingsLoading}
					<svg class="h-4 w-4 animate-spin" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
				{/if}
				{settingsLoading ? 'Wird gespeichert...' : 'Einstellungen speichern'}
			</button>
		</div>
	</form>
</div>