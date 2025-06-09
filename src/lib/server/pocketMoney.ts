import { db } from './db';
import { kids, transactions, type Kid, type NewKid } from './db/schema';
import { eq, desc, and } from 'drizzle-orm';

export class PocketMoneyService {
	// Initialize Louis if he doesn't exist
	static async initializeLouis(weeklyAllowance: number = 10, interestRate: number = 0.01) {
		const existingLouis = await db.select().from(kids).where(eq(kids.name, 'Louis')).limit(1);

		if (existingLouis.length === 0) {
			const [louis] = await db
				.insert(kids)
				.values({
					name: 'Louis',
					weeklyAllowance,
					interestRate,
					currentBalance: 0
				})
				.returning();
			return louis;
		}

		return existingLouis[0];
	}

	// Get Louis's current information
	static async getLouis(): Promise<Kid | undefined> {
		const result = await db.select().from(kids).where(eq(kids.name, 'Louis')).limit(1);
		return result[0];
	}

	// Update Louis's settings
	static async updateLouisSettings(weeklyAllowance?: number, interestRate?: number) {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		const updateData: Partial<NewKid> = {
			updatedAt: new Date()
		};

		if (weeklyAllowance !== undefined) updateData.weeklyAllowance = weeklyAllowance;
		if (interestRate !== undefined) updateData.interestRate = interestRate;

		await db.update(kids).set(updateData).where(eq(kids.id, louis.id));
	}

	// Add weekly allowance
	static async addWeeklyAllowance() {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		const newBalance = louis.currentBalance + louis.weeklyAllowance;

		// Update balance
		await db
			.update(kids)
			.set({
				currentBalance: newBalance,
				updatedAt: new Date()
			})
			.where(eq(kids.id, louis.id));

		// Record transaction
		await db.insert(transactions).values({
			kidId: louis.id,
			type: 'weekly_allowance',
			amount: louis.weeklyAllowance,
			description: 'Weekly allowance payment'
		});

		return newBalance;
	}

	// Add monthly interest
	static async addMonthlyInterest() {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		const interestAmount = louis.currentBalance * louis.interestRate;
		const newBalance = louis.currentBalance + interestAmount;

		// Update balance
		await db
			.update(kids)
			.set({
				currentBalance: newBalance,
				updatedAt: new Date()
			})
			.where(eq(kids.id, louis.id));

		// Record transaction
		await db.insert(transactions).values({
			kidId: louis.id,
			type: 'interest',
			amount: interestAmount,
			description: `Monthly interest payment (${(louis.interestRate * 100).toFixed(2)}%)`
		});

		return { interestAmount, newBalance };
	}

	// Withdraw money
	static async withdrawMoney(amount: number, description: string) {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		if (amount <= 0) throw new Error('Withdrawal amount must be positive');
		if (amount > louis.currentBalance) throw new Error('Insufficient funds');

		const newBalance = louis.currentBalance - amount;

		// Update balance
		await db
			.update(kids)
			.set({
				currentBalance: newBalance,
				updatedAt: new Date()
			})
			.where(eq(kids.id, louis.id));

		// Record transaction
		await db.insert(transactions).values({
			kidId: louis.id,
			type: 'withdrawal',
			amount: -amount, // Negative for withdrawals
			description
		});

		return newBalance;
	}

	// Get transaction history
	static async getTransactionHistory(limit: number = 50) {
		const louis = await this.getLouis();
		if (!louis) throw new Error('Louis not found');

		return await db
			.select()
			.from(transactions)
			.where(eq(transactions.kidId, louis.id))
			.orderBy(desc(transactions.createdAt))
			.limit(limit);
	}

	// Get current balance
	static async getCurrentBalance(): Promise<number> {
		const louis = await this.getLouis();
		return louis?.currentBalance ?? 0;
	}

	// Check if weekly allowance is due (for cron jobs)
	static async isWeeklyAllowanceDue(): Promise<boolean> {
		const louis = await this.getLouis();
		if (!louis) return false;

		const lastWeeklyPayment = await db
			.select()
			.from(transactions)
			.where(and(eq(transactions.kidId, louis.id), eq(transactions.type, 'weekly_allowance')))
			.orderBy(desc(transactions.createdAt))
			.limit(1);

		if (lastWeeklyPayment.length === 0) return true; // No previous payment

		const lastPaymentDate = new Date(lastWeeklyPayment[0].createdAt!);
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

		const lastInterestPayment = await db
			.select()
			.from(transactions)
			.where(and(eq(transactions.kidId, louis.id), eq(transactions.type, 'interest')))
			.orderBy(desc(transactions.createdAt))
			.limit(1);

		if (lastInterestPayment.length === 0) {
			// Check if account is at least a month old
			const accountAge = Math.floor(
				(new Date().getTime() - new Date(louis.createdAt!).getTime()) / (1000 * 60 * 60 * 24)
			);
			return accountAge >= 30;
		}

		const lastPaymentDate = new Date(lastInterestPayment[0].createdAt!);
		const now = new Date();

		// Check if it's a new month
		return (
			lastPaymentDate.getMonth() !== now.getMonth() ||
			lastPaymentDate.getFullYear() !== now.getFullYear()
		);
	}
}
