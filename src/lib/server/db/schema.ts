import { sqliteTable, integer, text, real } from 'drizzle-orm/sqlite-core';
import { sql } from 'drizzle-orm';

export const kids = sqliteTable('kids', {
	id: integer('id').primaryKey(),
	name: text('name').notNull(),
	weeklyAllowance: real('weekly_allowance').notNull().default(0),
	interestRate: real('interest_rate').notNull().default(0), // Monthly interest rate as decimal (e.g., 0.01 for 1%)
	currentBalance: real('current_balance').notNull().default(0),
	createdAt: integer('created_at', { mode: 'timestamp' }).default(sql`(unixepoch())`),
	updatedAt: integer('updated_at', { mode: 'timestamp' }).default(sql`(unixepoch())`)
});

export const transactions = sqliteTable('transactions', {
	id: integer('id').primaryKey(),
	kidId: integer('kid_id')
		.notNull()
		.references(() => kids.id),
	type: text('type', { enum: ['weekly_allowance', 'interest', 'withdrawal'] }).notNull(),
	amount: real('amount').notNull(), // Positive for income, negative for withdrawals
	description: text('description'), // Optional description, mainly for withdrawals
	createdAt: integer('created_at', { mode: 'timestamp' }).default(sql`(unixepoch())`)
});

export type Kid = typeof kids.$inferSelect;
export type NewKid = typeof kids.$inferInsert;
export type Transaction = typeof transactions.$inferSelect;
export type NewTransaction = typeof transactions.$inferInsert;
