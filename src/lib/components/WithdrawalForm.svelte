<script lang="ts">
	import { enhance } from '$app/forms';
	import type { Kid } from '$lib/server/supabase';

	let { louis }: { louis?: Kid } = $props();

	let withdrawLoading = $state(false);
</script>

<div class="rounded-lg bg-white p-6 shadow-md">
	<h2 class="mb-4 text-xl font-semibold text-gray-800">Geld ausgeben</h2>
	<form 
		method="POST" 
		action="?/withdraw" 
		use:enhance={() => {
			withdrawLoading = true;
			return async ({ update }) => {
				await update();
				withdrawLoading = false;
			};
		}}
	>
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
					max={louis?.current_balance ?? 0}
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
				disabled={withdrawLoading}
				class="w-full rounded-md bg-red-600 px-4 py-2 text-white hover:bg-red-700 focus:ring-2 focus:ring-red-500 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
			>
				{#if withdrawLoading}
					<svg class="h-4 w-4 animate-spin" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
				{/if}
				{withdrawLoading ? 'Wird verarbeitet...' : 'Geld ausgeben'}
			</button>
		</div>
	</form>
</div>