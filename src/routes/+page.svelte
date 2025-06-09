<script lang="ts">
	import type { Kid, Transaction } from '$lib/server/supabase';
	import BalanceCard from '$lib/components/BalanceCard.svelte';
	import WithdrawalForm from '$lib/components/WithdrawalForm.svelte';
	import ManualActions from '$lib/components/ManualActions.svelte';
	import Settings from '$lib/components/Settings.svelte';
	import TransactionHistory from '$lib/components/TransactionHistory.svelte';

	let { data }: { data: { louis?: Kid; transactions?: Transaction[] } } = $props();
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

		<!-- Current Balance -->
		<BalanceCard louis={data.louis} />

		<div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
			<!-- Actions Section -->
			<section class="space-y-6">
				<!-- Withdrawal Form -->
				<WithdrawalForm louis={data.louis} />

				<!-- Manual Actions -->
				<ManualActions />

				<!-- Settings -->
				<Settings louis={data.louis} />
			</section>

			<!-- Transaction History -->
			<section>
				<TransactionHistory transactions={data.transactions} />
			</section>
		</div>

		<!-- Success/Error Messages -->
		<!-- Note: Form feedback will be handled via enhanced forms or client-side state -->
	</div>
</main>