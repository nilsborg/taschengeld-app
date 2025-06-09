import { PocketMoneyService } from '$lib/server/pocketMoney';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async () => {
	try {
		// Check if weekly allowance is due
		const isDue = await PocketMoneyService.isWeeklyAllowanceDue();
		
		if (!isDue) {
			return json({ 
				success: false, 
				message: 'Weekly allowance is not due yet' 
			});
		}

		// Add weekly allowance
		const newBalance = await PocketMoneyService.addWeeklyAllowance();
		
		return json({ 
			success: true, 
			message: 'Weekly allowance added successfully',
			newBalance 
		});
	} catch (error) {
		console.error('Error adding weekly allowance:', error);
		return json({ 
			success: false, 
			error: (error as Error).message 
		}, { status: 500 });
	}
};

// GET endpoint to check if weekly allowance is due (for monitoring)
export const GET: RequestHandler = async () => {
	try {
		const isDue = await PocketMoneyService.isWeeklyAllowanceDue();
		const louis = await PocketMoneyService.getLouis();
		
		return json({ 
			isDue,
			currentBalance: louis?.currentBalance ?? 0,
			weeklyAllowance: louis?.weeklyAllowance ?? 0
		});
	} catch (error) {
		console.error('Error checking weekly allowance status:', error);
		return json({ 
			success: false, 
			error: (error as Error).message 
		}, { status: 500 });
	}
};