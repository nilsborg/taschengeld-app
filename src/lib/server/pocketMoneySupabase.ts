import { supabase, supabaseService, type Kid, type Transaction } from './supabase';

export class PocketMoneyService {
	// Initialize Louis if he doesn't exist
	static async initializeLouis(weeklyAllowance: number = 10, interestRate: number = 0.01) {
		const { data: existingLouis, error } = await supabase
			.from('kids')
			.select('*')
			.eq('name', 'Louis')
			.single();

		if (error && error.code !== 'PGRST116') {
			// PGRST116 is "not found" error, which is expected if Louis doesn't exist
			throw new Error(`Failed to check for existing Louis: ${error.message}`);
		}

		if (!existingLouis) {
			const { data: newLouis, error: insertError } = await supabase
				.from('kids')
				.insert({
					name: 'Louis',
					weekly_allowance: weeklyAllowance,
					interest_rate: interestRate,
					current_balance: 0
				})
				.select()
				.single();

			if (insertError) {
				throw new Error(`Failed to create Louis: ${insertError.message}`);
			}

			return newLouis;
		}

		return existingLouis;
	}

	// Get Louis's current data
	static async getLouis(): Promise<Kid | undefined> {
		const { data, error } = await supabaseService
			.from('kids')
			.select('*')
			.eq('name', 'Louis')
			.single();

		if (error && error.code !== 'PGRST116') {
			throw new Error(`Failed to get Louis: ${error.message}`);
		}

		return data || undefined;
	}

	// Update Louis's settings
	static async updateLouisSettings(weeklyAllowance?: number, interestRate?: number) {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		const updateData: Partial<Kid> = { updated_at: new Date().toISOString() };
		if (weeklyAllowance !== undefined) updateData.weekly_allowance = weeklyAllowance;
		if (interestRate !== undefined) updateData.interest_rate = interestRate;

		const { error } = await supabase.from('kids').update(updateData).eq('id', louis.id);

		if (error) {
			throw new Error(`Failed to update Louis settings: ${error.message}`);
		}
	}

	// Manual weekly allowance addition (bypasses timing check for UI)
	static async addWeeklyAllowanceManual(): Promise<number> {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		const newBalance = louis.current_balance + louis.weekly_allowance;

		// Update balance
		const { error: updateError } = await supabaseService
			.from('kids')
			.update({
				current_balance: newBalance,
				updated_at: new Date().toISOString()
			})
			.eq('id', louis.id);

		if (updateError) {
			throw new Error(`Failed to update balance: ${updateError.message}`);
		}

		// Record transaction
		const { error: transactionError } = await supabaseService.from('transactions').insert({
			kid_id: louis.id,
			type: 'weekly_allowance',
			amount: louis.weekly_allowance,
			description: null
		});

		if (transactionError) {
			throw new Error(`Failed to record transaction: ${transactionError.message}`);
		}

		return newBalance;
	}

	// Add weekly allowance
	static async addWeeklyAllowance(): Promise<number> {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		const newBalance = louis.current_balance + louis.weekly_allowance;

		// Update balance
		const { error: updateError } = await supabase
			.from('kids')
			.update({
				current_balance: newBalance,
				updated_at: new Date().toISOString()
			})
			.eq('id', louis.id);

		if (updateError) {
			throw new Error(`Failed to update balance: ${updateError.message}`);
		}

		// Record transaction
		const { error: transactionError } = await supabase.from('transactions').insert({
			kid_id: louis.id,
			type: 'weekly_allowance',
			amount: louis.weekly_allowance,
			description: null
		});

		if (transactionError) {
			throw new Error(`Failed to record transaction: ${transactionError.message}`);
		}

		return newBalance;
	}

	// Add monthly interest
	static async addMonthlyInterest(): Promise<{ newBalance: number; interestAmount: number }> {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		if (louis.current_balance <= 0) {
			throw new Error('No balance to earn interest on');
		}

		const interestAmount = louis.current_balance * louis.interest_rate;
		const newBalance = louis.current_balance + interestAmount;

		// Update balance
		const { error: updateError } = await supabase
			.from('kids')
			.update({
				current_balance: newBalance,
				updated_at: new Date().toISOString()
			})
			.eq('id', louis.id);

		if (updateError) {
			throw new Error(`Failed to update balance: ${updateError.message}`);
		}

		// Record transaction
		const { error: transactionError } = await supabase.from('transactions').insert({
			kid_id: louis.id,
			type: 'interest',
			amount: interestAmount,
			description: null
		});

		if (transactionError) {
			throw new Error(`Failed to record transaction: ${transactionError.message}`);
		}

		return { newBalance, interestAmount };
	}

	// Withdraw money
	static async withdrawMoney(amount: number, description: string): Promise<number> {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		if (amount > louis.current_balance) {
			throw new Error('Insufficient funds');
		}

		const newBalance = louis.current_balance - amount;

		// Update balance
		const { error: updateError } = await supabase
			.from('kids')
			.update({
				current_balance: newBalance,
				updated_at: new Date().toISOString()
			})
			.eq('id', louis.id);

		if (updateError) {
			throw new Error(`Failed to update balance: ${updateError.message}`);
		}

		// Record transaction (negative amount for withdrawal)
		const { error: transactionError } = await supabase.from('transactions').insert({
			kid_id: louis.id,
			type: 'withdrawal',
			amount: -amount, // Negative for withdrawal
			description
		});

		if (transactionError) {
			throw new Error(`Failed to record transaction: ${transactionError.message}`);
		}

		return newBalance;
	}

	// Get transaction history
	static async getTransactionHistory(limit: number = 20): Promise<Transaction[]> {
		const { data, error } = await supabase
			.from('transactions')
			.select('*')
			.order('created_at', { ascending: false })
			.limit(limit);

		if (error) {
			throw new Error(`Failed to get transaction history: ${error.message}`);
		}

		return data || [];
	}

	// Get transactions for a specific kid
	static async getKidTransactions(kidId: number, limit: number = 20): Promise<Transaction[]> {
		const { data, error } = await supabase
			.from('transactions')
			.select('*')
			.eq('kid_id', kidId)
			.order('created_at', { ascending: false })
			.limit(limit);

		if (error) {
			throw new Error(`Failed to get kid transactions: ${error.message}`);
		}

		return data || [];
	}

	// Get current balance
	static async getCurrentBalance(): Promise<number> {
		const louis = await this.getLouis();
		return louis?.current_balance ?? 0;
	}

	// Check if weekly allowance is due (for cron jobs)
	static async isWeeklyAllowanceDue(): Promise<boolean> {
		const louis = await this.getLouis();
		if (!louis) return false;

		const { data: lastWeeklyPayment, error } = await supabaseService
			.from('transactions')
			.select('*')
			.eq('kid_id', louis.id)
			.eq('type', 'weekly_allowance')
			.order('created_at', { ascending: false })
			.limit(1);

		if (error) {
			throw new Error(`Failed to check weekly allowance status: ${error.message}`);
		}

		if (!lastWeeklyPayment || lastWeeklyPayment.length === 0) return true; // No previous payment

		const lastPaymentDate = new Date(lastWeeklyPayment[0].created_at);
		const now = new Date();
		const daysSinceLastPayment = Math.floor(
			(now.getTime() - lastPaymentDate.getTime()) / (1000 * 60 * 60 * 24)
		);

		return daysSinceLastPayment >= 7;
	}

	// Check if monthly interest is due (for cron jobs)
	static async isMonthlyInterestDue(): Promise<boolean> {
		const louis = await this.getLouis();
		if (!louis) return false;

		const { data: lastInterestPayment, error } = await supabase
			.from('transactions')
			.select('*')
			.eq('kid_id', louis.id)
			.eq('type', 'interest')
			.order('created_at', { ascending: false })
			.limit(1);

		if (error) {
			throw new Error(`Failed to check interest status: ${error.message}`);
		}

		if (!lastInterestPayment || lastInterestPayment.length === 0) {
			// Check if account is at least a month old
			const accountAge = Math.floor(
				(new Date().getTime() - new Date(louis.created_at).getTime()) / (1000 * 60 * 60 * 24)
			);
			return accountAge >= 30;
		}

		const lastPaymentDate = new Date(lastInterestPayment[0].created_at);
		const now = new Date();

		// Check if it's a new month
		return (
			lastPaymentDate.getMonth() !== now.getMonth() ||
			lastPaymentDate.getFullYear() !== now.getFullYear()
		);
	}
}
