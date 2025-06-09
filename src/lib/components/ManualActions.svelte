<script lang="ts">
	import { enhance } from '$app/forms';

	let weeklyAllowanceLoading = $state(false);
	let interestLoading = $state(false);
</script>

<div class="rounded-lg bg-white p-6 shadow-md">
	<h2 class="mb-4 text-xl font-semibold text-gray-800">Manuelle Aktionen</h2>
	<div class="space-y-3">
		<form 
			method="POST" 
			action="?/addWeeklyAllowance" 
			use:enhance={() => {
				weeklyAllowanceLoading = true;
				return async ({ update }) => {
					await update();
					weeklyAllowanceLoading = false;
				};
			}}
		>
			<button
				type="submit"
				disabled={weeklyAllowanceLoading}
				class="w-full rounded-md bg-green-600 px-4 py-2 text-white hover:bg-green-700 focus:ring-2 focus:ring-green-500 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
			>
				{#if weeklyAllowanceLoading}
					<svg class="h-4 w-4 animate-spin" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
				{/if}
				{weeklyAllowanceLoading ? 'Wird hinzugefügt...' : 'Wöchentliches Taschengeld hinzufügen'}
			</button>
		</form>
		<form 
			method="POST" 
			action="?/addInterest" 
			use:enhance={() => {
				interestLoading = true;
				return async ({ update }) => {
					await update();
					interestLoading = false;
				};
			}}
		>
			<button
				type="submit"
				disabled={interestLoading}
				class="w-full rounded-md bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
			>
				{#if interestLoading}
					<svg class="h-4 w-4 animate-spin" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
				{/if}
				{interestLoading ? 'Wird hinzugefügt...' : 'Monatliche Zinsen hinzufügen'}
			</button>
		</form>
	</div>
</div>