import { PocketMoneyService } from '$lib/server/pocketMoney';
import { fail } from '@sveltejs/kit';
import type { PageServerLoad, Actions } from './$types';
import type { Kid, Transaction } from '$lib/server/db/schema';

export const load: PageServerLoad = async (): Promise<{
	louis: Kid | undefined;
	transactions: Transaction[];
}> => {
	// Initialize Louis if he doesn't exist
	await PocketMoneyService.initializeLouis();

	const [louis, transactions] = await Promise.all([
		PocketMoneyService.getLouis(),
		PocketMoneyService.getTransactionHistory(20)
	]);

	return {
		louis,
		transactions
	};
};

export const actions: Actions = {
	withdraw: async ({ request }) => {
		const data = await request.formData();
		const amount = parseFloat(data.get('amount') as string);
		const description = data.get('description') as string;

		if (!amount || amount <= 0) {
			return fail(400, { error: 'Please enter a valid amount' });
		}

		if (!description || description.trim().length === 0) {
			return fail(400, { error: 'Please provide a description' });
		}

		try {
			const newBalance = await PocketMoneyService.withdrawMoney(amount, description.trim());
			return { success: true, newBalance };
		} catch (error) {
			return fail(400, { error: (error as Error).message });
		}
	},

	updateSettings: async ({ request }) => {
		const data = await request.formData();
		const weeklyAllowance = parseFloat(data.get('weeklyAllowance') as string);
		const interestRate = parseFloat(data.get('interestRate') as string);

		if (isNaN(weeklyAllowance) || weeklyAllowance < 0) {
			return fail(400, { error: 'Please enter a valid weekly allowance' });
		}

		if (isNaN(interestRate) || interestRate < 0) {
			return fail(400, { error: 'Please enter a valid interest rate' });
		}

		try {
			await PocketMoneyService.updateLouisSettings(weeklyAllowance, interestRate / 100); // Convert percentage to decimal
			return { success: true, message: 'Settings updated successfully' };
		} catch (error) {
			return fail(400, { error: (error as Error).message });
		}
	},

	addWeeklyAllowance: async () => {
		try {
			const newBalance = await PocketMoneyService.addWeeklyAllowance();
			return { success: true, newBalance, message: 'Weekly allowance added successfully' };
		} catch (error) {
			return fail(400, { error: (error as Error).message });
		}
	},

	addInterest: async () => {
		try {
			const result = await PocketMoneyService.addMonthlyInterest();
			return {
				success: true,
				newBalance: result.newBalance,
				interestAmount: result.interestAmount,
				message: 'Monthly interest added successfully'
			};
		} catch (error) {
			return fail(400, { error: (error as Error).message });
		}
	}
};
