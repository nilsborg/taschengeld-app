# Supabase Migration Checklist

## ✅ Completed Steps

- [x] Installed `@supabase/supabase-js` dependency
- [x] Created Supabase client configuration (`src/lib/server/supabase.ts`)
- [x] Created new PocketMoneyService using Supabase (`src/lib/server/pocketMoneySupabase.ts`)
- [x] Updated page server to use new Supabase service
- [x] Updated API routes to use new Supabase service
- [x] Created database schema file (`supabase/schema.sql`)
- [x] Updated environment variables template
- [x] Created setup documentation

## 🚀 Next Steps (You Need to Do)

### 1. Set Up Supabase Project
- [ ] Create account at [supabase.com](https://supabase.com)
- [ ] Create new project
- [ ] Copy Project URL and Anon Key

### 2. Configure Environment
- [ ] Copy `.env.example` to `.env`
- [ ] Add your Supabase credentials to `.env`:
  ```
  SUPABASE_URL=https://your-project-ref.supabase.co
  SUPABASE_ANON_KEY=your-anon-key
  ```

### 3. Set Up Database
- [ ] Go to Supabase SQL Editor
- [ ] Run the contents of `supabase/schema.sql`
- [ ] Verify tables were created (kids, transactions)

### 4. Test Migration
- [ ] Run `pnpm dev`
- [ ] Test adding weekly allowance
- [ ] Test making withdrawals
- [ ] Test adding interest
- [ ] Verify transaction history works

### 5. Data Migration (Optional)
- [ ] Export existing SQLite data if needed
- [ ] Insert historical data into Supabase tables

### 6. Clean Up (After Verification)
- [ ] Remove Drizzle dependencies: `pnpm remove drizzle-orm drizzle-kit @libsql/client`
- [ ] Delete old files:
  - [ ] `src/lib/server/db/` directory
  - [ ] `src/lib/server/pocketMoney.ts`
  - [ ] `drizzle.config.ts`
  - [ ] `local.db`

## 🎯 Success Criteria

Migration is successful when:
- [ ] App starts without errors
- [ ] Can view Louis's balance
- [ ] Can add weekly allowance
- [ ] Can make withdrawals
- [ ] Can add monthly interest
- [ ] Transaction history displays correctly
- [ ] API endpoints work for automation

## 📚 References

- Setup Guide: `SUPABASE_SETUP.md`
- Database Schema: `supabase/schema.sql`
- New Service: `src/lib/server/pocketMoneySupabase.ts`

## 🆘 Need Help?

If you encounter issues:
1. Check Supabase project logs
2. Verify environment variables are correct
3. Ensure schema was applied correctly
4. Test individual database operations in Supabase SQL Editor