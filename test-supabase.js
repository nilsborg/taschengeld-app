#!/usr/bin/env node

/**
 * Simple test script to verify Supabase migration
 * Run with: node test-supabase.js
 */

import { createClient } from '@supabase/supabase-js';
import { config } from 'dotenv';

// Load environment variables
config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
	console.error('❌ Missing Supabase environment variables');
	console.log('Please check your .env file contains:');
	console.log('- SUPABASE_URL');
	console.log('- SUPABASE_ANON_KEY');
	process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testSupabaseConnection() {
	console.log('🧪 Testing Supabase Migration...\n');

	try {
		// Test 1: Check connection
		console.log('1. Testing connection...');
		const { data, error } = await supabase.from('kids').select('count').single();
		if (error && error.code !== 'PGRST116') {
			throw new Error(`Connection failed: ${error.message}`);
		}
		console.log('✅ Connected to Supabase successfully\n');

		// Test 2: Check if Louis exists
		console.log('2. Checking for Louis...');
		const { data: louis, error: louisError } = await supabase
			.from('kids')
			.select('*')
			.eq('name', 'Louis')
			.single();

		if (louisError && louisError.code !== 'PGRST116') {
			throw new Error(`Failed to query Louis: ${louisError.message}`);
		}

		if (!louis) {
			console.log('⚠️  Louis not found, creating...');
			const { data: newLouis, error: createError } = await supabase
				.from('kids')
				.insert({
					name: 'Louis',
					weekly_allowance: 10.00,
					interest_rate: 0.01,
					current_balance: 0.00
				})
				.select()
				.single();

			if (createError) {
				throw new Error(`Failed to create Louis: ${createError.message}`);
			}
			
			console.log('✅ Louis created successfully');
			console.log(`   ID: ${newLouis.id}, Balance: $${newLouis.current_balance}\n`);
		} else {
			console.log('✅ Louis found');
			console.log(`   ID: ${louis.id}, Balance: $${louis.current_balance}\n`);
		}

		// Test 3: Check transactions table
		console.log('3. Testing transactions table...');
		const { data: transactions, error: transError } = await supabase
			.from('transactions')
			.select('*')
			.limit(5);

		if (transError) {
			throw new Error(`Failed to query transactions: ${transError.message}`);
		}

		console.log(`✅ Transactions table accessible (${transactions.length} records found)\n`);

		// Test 4: Test a simple insert/delete cycle
		console.log('4. Testing write operations...');
		const testLouisId = louis?.id || 1;
		
		// Insert a test transaction
		const { data: testTransaction, error: insertError } = await supabase
			.from('transactions')
			.insert({
				kid_id: testLouisId,
				type: 'weekly_allowance',
				amount: 0.01,
				description: 'Test transaction'
			})
			.select()
			.single();

		if (insertError) {
			throw new Error(`Failed to insert test transaction: ${insertError.message}`);
		}

		console.log('✅ Insert operation successful');

		// Delete the test transaction
		const { error: deleteError } = await supabase
			.from('transactions')
			.delete()
			.eq('id', testTransaction.id);

		if (deleteError) {
			throw new Error(`Failed to delete test transaction: ${deleteError.message}`);
		}

		console.log('✅ Delete operation successful\n');

		// Summary
		console.log('🎉 All tests passed! Migration verification complete.');
		console.log('Your app should now work with Supabase.\n');
		
		console.log('Next steps:');
		console.log('1. Start your dev server: pnpm dev');
		console.log('2. Test the full application');
		console.log('3. If everything works, clean up old Drizzle files');

	} catch (error) {
		console.error('❌ Test failed:', error.message);
		console.log('\nTroubleshooting:');
		console.log('1. Check your Supabase project dashboard');
		console.log('2. Verify your environment variables');
		console.log('3. Make sure you ran the schema.sql in Supabase SQL Editor');
		console.log('4. Check Row Level Security policies');
		process.exit(1);
	}
}

// Run the test
testSupabaseConnection();