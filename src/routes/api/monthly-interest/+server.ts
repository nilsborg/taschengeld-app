import { PocketMoneyService } from '$lib/server/pocketMoney';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async () => {
	try {
		// Check if monthly interest is due
		const isDue = await PocketMoneyService.isMonthlyInterestDue();
		
		if (!isDue) {
			return json({ 
				success: false, 
				message: 'Monthly interest is not due yet' 
			});
		}

		// Add monthly interest
		const result = await PocketMoneyService.addMonthlyInterest();
		
		return json({ 
			success: true, 
			message: 'Monthly interest added successfully',
			interestAmount: result.interestAmount,
			newBalance: result.newBalance
		});
	} catch (error) {
		console.error('Error adding monthly interest:', error);
		return json({ 
			success: false, 
			error: (error as Error).message 
		}, { status: 500 });
	}
};

// GET endpoint to check if monthly interest is due (for monitoring)
export const GET: RequestHandler = async () => {
	try {
		const isDue = await PocketMoneyService.isMonthlyInterestDue();
		const louis = await PocketMoneyService.getLouis();
		
		return json({ 
			isDue,
			currentBalance: louis?.currentBalance ?? 0,
			interestRate: louis?.interestRate ?? 0,
			potentialInterest: louis ? louis.currentBalance * louis.interestRate : 0
		});
	} catch (error) {
		console.error('Error checking monthly interest status:', error);
		return json({ 
			success: false, 
			error: (error as Error).message 
		}, { status: 500 });
	}
};