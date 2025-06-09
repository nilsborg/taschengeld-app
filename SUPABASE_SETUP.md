# Supabase Setup with Authentication

This guide will help you set up Supabase for the Taschengeld app with user authentication and role-based access control.

## Prerequisites

1. Create a Supabase account at [supabase.com](https://supabase.com)
2. Create a new Supabase project

## Step 1: Get Your Supabase Credentials

1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **API**
3. Copy the following values:
   - **Project URL** (looks like: `https://your-project-ref.supabase.co`)
   - **Anon public key** (starts with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)

## Step 2: Configure Authentication

1. In your Supabase project dashboard, go to **Authentication** → **Settings**
2. Under **Site URL**, add your development URL: `http://localhost:5173`
3. Under **Redirect URLs**, add: `http://localhost:5173/auth/callback`
4. For production, add your production URLs as well

## Step 3: Update Environment Variables

1. Copy your `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update your `.env` file with your Supabase credentials:
   ```env
   # Supabase Configuration (Server-side)
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   
   # Supabase Configuration (Client-side - these will be exposed to the browser)
   PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
   PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
   
   # Legacy - can be removed after migration
   DATABASE_URL=file:local.db
   ```

## Step 4: Set Up Database Schema

1. In your Supabase project dashboard, go to **SQL Editor**
2. Copy and paste the contents of `supabase/schema.sql`
3. Click **Run** to execute the SQL

This will create:
- `profiles` table for user profiles with roles (parent/kid)
- `kids` table for storing child information (linked to user profiles)
- `transactions` table for storing all financial transactions
- Proper indexes for performance
- Row Level Security policies for secure access control
- Authentication triggers and functions
- Initial Louis record (for legacy support)

## Step 5: Test Authentication

1. Start your development server:
   ```bash
   pnpm dev
   ```

2. Visit `http://localhost:5173` and test:
   - Creating a new account (try both parent and kid roles)
   - Signing in with existing credentials
   - Role-based page access (kids vs parents)

## Step 6: Verify Full Functionality

The app now uses Supabase with full authentication. Test the following features:

**As a Kid:**
- View your current balance and transaction history
- Make withdrawals from your account
- See weekly allowance and interest deposits

**As a Parent:**
- View all kids' accounts and balances
- Add weekly allowances to all kids
- Add monthly interest to all accounts
- Manage kid settings (allowance amounts, interest rates)
- View all transaction history across accounts
- Add new kids to the system

## Step 7: Data Migration (Optional)

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

## Step 8: Clean Up (After Verification)

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

### Profiles Table (User Authentication)
```sql
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    role user_role NOT NULL DEFAULT 'kid', -- 'parent' or 'kid'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Kids Table (Enhanced with User Links)
```sql
CREATE TABLE kids (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    weekly_allowance DECIMAL(10,2) NOT NULL DEFAULT 0,
    interest_rate DECIMAL(5,4) NOT NULL DEFAULT 0,
    current_balance DECIMAL(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Transactions Table (Unchanged)
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

## Authentication Features

- **Role-based Access Control**: Parents can see everything, kids can only see their own data
- **Secure Withdrawals**: Only kids can withdraw from their own accounts
- **Protected Routes**: Authentication required for all money management features
- **User Profiles**: Automatic profile creation with role assignment on signup

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

## User Roles and Permissions

### Kid Role
- ✅ View their own balance and transaction history
- ✅ Make withdrawals from their account
- ✅ See allowance and interest payments
- ❌ Cannot access other kids' accounts
- ❌ Cannot add allowances or interest
- ❌ Cannot modify account settings

### Parent Role  
- ✅ View all kids' accounts and balances
- ✅ Add weekly allowances to all accounts
- ✅ Add monthly interest to all accounts
- ✅ Manage kid settings (allowance amounts, interest rates)
- ✅ View complete transaction history
- ✅ Add new kids to the system
- ❌ Cannot make withdrawals (kids must do this themselves)

## Next Steps

Now that authentication is set up:

1. **Multi-family Support**: Extend to support multiple families/households
2. **Real-time Updates**: Use Supabase real-time features for live balance updates
3. **Email Notifications**: Set up automated allowance/interest notifications
4. **Mobile App**: Consider building a mobile version with the same backend
5. **Advanced Features**: Add goals, savings targets, or spending categories

## Support

If you encounter issues:
1. Check the Supabase project logs in the dashboard
2. Verify your RLS policies allow the operations you're trying to perform
3. Test individual queries in the Supabase SQL Editor