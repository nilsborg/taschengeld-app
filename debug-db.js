#!/usr/bin/env node

import { createClient } from '@supabase/supabase-js';
import { config } from 'dotenv';

config();

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

async function debugDatabase() {
    console.log('🔍 Debugging database state...\n');
    
    try {
        // Check Louis
        const { data: louis, error: louisError } = await supabase
            .from('kids')
            .select('*')
            .eq('name', 'Louis')
            .single();
            
        if (louisError) {
            console.error('❌ Error fetching Louis:', louisError);
            return;
        }
        
        console.log('👦 Louis data:');
        console.log(JSON.stringify(louis, null, 2));
        console.log('');
        
        // Check transactions
        const { data: transactions, error: transError } = await supabase
            .from('transactions')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(10);
            
        if (transError) {
            console.error('❌ Error fetching transactions:', transError);
            return;
        }
        
        console.log('📝 Recent transactions:');
        if (transactions.length === 0) {
            console.log('No transactions found');
        } else {
            transactions.forEach(t => {
                console.log(`- ${t.type}: ${t.amount}€ at ${t.created_at}`);
                if (t.description) console.log(`  Description: ${t.description}`);
            });
        }
        console.log('');
        
        // Check if weekly allowance is due
        if (transactions.length > 0) {
            const lastWeekly = transactions.find(t => t.type === 'weekly_allowance');
            if (lastWeekly) {
                const lastDate = new Date(lastWeekly.created_at);
                const daysSince = Math.floor((Date.now() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
                console.log(`⏰ Last weekly allowance: ${daysSince} days ago`);
                console.log(`   Weekly allowance is ${daysSince >= 7 ? 'DUE' : 'NOT DUE'}`);
            } else {
                console.log('⏰ No weekly allowance found - should be DUE');
            }
        } else {
            console.log('⏰ No transactions - weekly allowance should be DUE');
        }
        
    } catch (error) {
        console.error('❌ Debug failed:', error);
    }
}

debugDatabase();