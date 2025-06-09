# Supabase Migration Setup

This guide will help you migrate your Taschengeld app from SQLite/Drizzle to Supabase.

## Prerequisites

1. Create a Supabase account at [supabase.com](https://supabase.com)
2. Create a new Supabase project

## Step 1: Get Your Supabase Credentials

1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **API**
3. Copy the following values:
   - **Project URL** (looks like: `https://your-project-ref.supabase.co`)
   - **Anon public key** (starts with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)

## Step 2: Update Environment Variables

1. Copy your `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update your `.env` file with your Supabase credentials:
   ```env
   # Supabase Configuration
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   
   # Legacy - can be removed after migration
   DATABASE_URL=file:local.db
   ```

## Step 3: Set Up Database Schema

1. In your Supabase project dashboard, go to **SQL Editor**
2. Copy and paste the contents of `supabase/schema.sql`
3. Click **Run** to execute the SQL

This will create:
- `kids` table for storing child information
- `transactions` table for storing all financial transactions
- Proper indexes for performance
- Row Level Security policies (ready for future auth)
- Initial Louis record

## Step 4: Verify Migration

The app is already configured to use the new Supabase service. You can now:

1. Start your development server:
   ```bash
   pnpm dev
   ```

2. Test the following features:
   - View Louis's current balance
   - Add weekly allowance
   - Add monthly interest
   - Make withdrawals
   - View transaction history

## Step 5: Data Migration (Optional)

If you have existing data in your SQLite database that you want to migrate:

1. **Export existing data** from SQLite:
   ```bash
   # This will show you the current data structure
   pnpm db:studio
   ```

2. **Manually insert data** into Supabase:
   - Go to Supabase **Table Editor**
   - Navigate to the `kids` table
   - Update Louis's record with current balance/settings
   - Add historical transactions to the `transactions` table

## Step 6: Clean Up (After Verification)

Once you've verified everything works correctly:

1. Remove Drizzle dependencies:
   ```bash
   pnpm remove drizzle-orm drizzle-kit @libsql/client
   ```

2. Delete old files:
   ```bash
   rm -rf src/lib/server/db/
   rm src/lib/server/pocketMoney.ts
   rm drizzle.config.ts
   rm local.db
   ```

3. Update `package.json` scripts (remove db:* scripts):
   ```json
   {
     "scripts": {
       "dev": "vite dev",
       "build": "vite build",
       "preview": "vite preview",
       // ... other scripts, remove db:push, db:migrate, db:studio
     }
   }
   ```

## API Endpoints

The following API endpoints are available for automation/cron jobs:

- `POST /api/weekly-allowance` - Add weekly allowance (if due)
- `GET /api/weekly-allowance` - Check if weekly allowance is due
- `POST /api/monthly-interest` - Add monthly interest (if due)
- `GET /api/monthly-interest` - Check if monthly interest is due

## Database Schema

### Kids Table
```sql
CREATE TABLE kids (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    weekly_allowance DECIMAL(10,2) NOT NULL DEFAULT 0,
    interest_rate DECIMAL(5,4) NOT NULL DEFAULT 0,
    current_balance DECIMAL(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Transactions Table
```sql
CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    kid_id BIGINT NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('weekly_allowance', 'interest', 'withdrawal')),
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Troubleshooting

### Common Issues

1. **Connection Error**: Double-check your `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `.env`

2. **Permission Denied**: Make sure you ran the schema.sql which includes the necessary RLS policies

3. **Louis Not Found**: The app will automatically create Louis on first load, but you can also insert manually:
   ```sql
   INSERT INTO kids (name, weekly_allowance, interest_rate, current_balance) 
   VALUES ('Louis', 10.00, 0.01, 0.00);
   ```

### Debugging

Enable Supabase client logging by setting the debug flag:
```typescript
const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
  db: { schema: 'public' },
  auth: { persistSession: false },
  realtime: { params: { eventsPerSecond: 10 } },
  global: { headers: { 'x-my-custom-header': 'my-app-name' } },
})
```

## Next Steps

After successfully migrating to Supabase:

1. **Add Authentication**: Implement user registration/login
2. **Multi-user Support**: Modify schema to support multiple families
3. **Real-time Updates**: Use Supabase real-time features
4. **File Storage**: Add receipt/image uploads for transactions
5. **Email Notifications**: Set up automated allowance/interest notifications

## Support

If you encounter issues:
1. Check the Supabase project logs in the dashboard
2. Verify your RLS policies allow the operations you're trying to perform
3. Test individual queries in the Supabase SQL Editor