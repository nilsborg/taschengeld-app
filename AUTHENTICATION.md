# Authentication System

This document describes the authentication and authorization system implemented for the Taschengeld App using Supabase Auth.

## Overview

The app implements role-based authentication with two user types:
- **Kids**: Can view their own transactions and make withdrawals
- **Parents**: Can view all data, manage allowances/interest, but cannot make withdrawals

## Architecture

### Frontend Authentication
- **Client**: `src/lib/supabase.ts` - Client-side Supabase configuration
- **Auth Store**: `src/lib/stores/auth.ts` - Reactive authentication state management
- **Protected Routes**: Role-based route protection and redirects

### Backend Authentication
- **Server Client**: `src/lib/server/supabase.ts` - Server-side operations
- **Database Schema**: Role-based Row Level Security (RLS) policies
- **API Protection**: Server-side route protection (future enhancement)

## User Roles and Permissions

### Kid Role (`role: 'kid'`)
✅ **Allowed:**
- View own balance and transaction history
- Make withdrawals from own account
- See allowance and interest payments

❌ **Denied:**
- Access other kids' accounts
- Add allowances or interest
- Modify account settings
- Access parent dashboard

### Parent Role (`role: 'parent'`)
✅ **Allowed:**
- View all kids' accounts and balances
- Add weekly allowances to all accounts
- Add monthly interest to all accounts
- Manage kid settings (allowance amounts, interest rates)
- View complete transaction history
- Add new kids to the system
- Access kid dashboards (for oversight)

❌ **Denied:**
- Make withdrawals (kids must do this themselves)

## Database Security

### Row Level Security (RLS) Policies

#### Profiles Table
```sql
-- Users can only view/update their own profile
CREATE POLICY "Users can view their own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);
```

#### Kids Table
```sql
-- Kids can view their own data, parents can view all
CREATE POLICY "Kids can view their own data" ON kids
    FOR SELECT USING (
        user_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'parent')
    );

-- Only parents can modify kids data
CREATE POLICY "Only parents can modify kids data" ON kids
    FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'parent')
    );
```

#### Transactions Table
```sql
-- Kids can view their own transactions, parents can view all
CREATE POLICY "Kids can view their own transactions" ON transactions
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM kids WHERE id = transactions.kid_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'parent')
    );

-- Kids can only create withdrawals for themselves
CREATE POLICY "Kids can create withdrawals for themselves" ON transactions
    FOR INSERT WITH CHECK (
        type = 'withdrawal' AND
        EXISTS (SELECT 1 FROM kids WHERE id = transactions.kid_id AND user_id = auth.uid())
    );

-- Parents can create any transaction
CREATE POLICY "Parents can create any transaction" ON transactions
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'parent')
    );
```

## Authentication Flow

### 1. Sign Up Process
```typescript
// User creates account with role selection
const { data, error } = await signUp(email, password, fullName, role);

// Automatic profile creation via database trigger
// -> Creates entry in profiles table with selected role
// -> For kids: optionally creates linked entry in kids table
```

### 2. Sign In Process
```typescript
// User signs in
const { data, error } = await signIn(email, password);

// Auth store automatically:
// -> Sets user state
// -> Loads user profile with role
// -> Redirects to appropriate dashboard
```

### 3. Route Protection
```typescript
// Layout handles automatic redirects based on:
// 1. Authentication status
// 2. User role
// 3. Current route

// Examples:
// - Unauthenticated users -> /auth/login
// - Kids accessing /parent/* -> /kid
// - Parents can access both /parent/* and /kid/*
```

## Components

### Authentication Store (`src/lib/stores/auth.ts`)
Manages global authentication state:
- `user`: Current Supabase user object
- `profile`: User profile with role information
- `loading`: Authentication check status
- `isAuthenticated`: Derived authentication status
- `isParent`: Derived parent role check
- `isKid`: Derived kid role check

### Protected Route Component (`src/lib/components/ProtectedRoute.svelte`)
Reusable component for route protection:
```svelte
<ProtectedRoute requireAuth={true} requiredRole="parent">
    <!-- Parent-only content -->
</ProtectedRoute>
```

## API Routes

### Authentication Endpoints
- `GET/POST /auth/callback` - Handles OAuth callbacks
- `GET/POST /auth/logout` - Handles user logout

### Protected API Endpoints (Future)
All API routes should validate user authentication and role:
```typescript
export const POST: RequestHandler = async ({ request, locals }) => {
    const user = await getServerSession(request);
    if (!user) {
        throw error(401, 'Unauthorized');
    }
    
    const profile = await getUserProfile(user.id);
    if (profile?.role !== 'parent') {
        throw error(403, 'Forbidden');
    }
    
    // Handle request...
};
```

## Client-Side Route Protection

### Automatic Redirects
The main layout (`+layout.svelte`) handles:
1. Loading authentication state
2. Redirecting unauthenticated users to login
3. Role-based dashboard redirects
4. Preventing unauthorized access

### Manual Protection
For additional protection, use the `ProtectedRoute` component:
```svelte
<ProtectedRoute requiredRole="parent">
    <ParentOnlyContent />
</ProtectedRoute>
```

## Security Considerations

### 1. Row Level Security (RLS)
- All tables have RLS enabled
- Policies enforce role-based access at the database level
- No way to bypass permissions via direct database access

### 2. Client-Side Security
- Authentication state is reactive and always up-to-date
- Route protection prevents UI access to unauthorized content
- All sensitive operations require backend validation

### 3. Server-Side Security
- Server-side clients can validate user sessions
- API endpoints should always verify authentication
- Database policies provide ultimate security layer

## Error Handling

### Authentication Errors
- Invalid credentials: Display error message on login form
- Account not confirmed: Redirect to email confirmation notice
- Session expired: Automatic redirect to login with message

### Authorization Errors
- Insufficient permissions: Show access denied page
- Invalid role: Redirect to appropriate dashboard
- Missing profile: Force profile creation flow

## Testing Authentication

### Manual Testing Checklist
1. **Sign Up Flow**
   - [ ] Create parent account
   - [ ] Create kid account
   - [ ] Verify email confirmation (if enabled)
   - [ ] Check profile creation

2. **Sign In Flow**
   - [ ] Valid credentials redirect to correct dashboard
   - [ ] Invalid credentials show error
   - [ ] Remember user session across browser refresh

3. **Role-Based Access**
   - [ ] Kids cannot access parent routes
   - [ ] Parents can access both parent and kid routes
   - [ ] Unauthenticated users redirected to login

4. **Data Access**
   - [ ] Kids only see their own data
   - [ ] Parents see all data
   - [ ] Kids can only withdraw from own account
   - [ ] Parents cannot make withdrawals

### Automated Testing (Future)
Consider adding:
- Unit tests for auth store functions
- Integration tests for authentication flows
- E2E tests for role-based access scenarios

## Environment Configuration

### Required Environment Variables
```env
# Server-side (private)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# Client-side (public)
PUBLIC_SUPABASE_URL=https://your-project.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

### Supabase Project Settings
1. **Authentication Settings**
   - Site URL: `http://localhost:5173` (development)
   - Redirect URLs: `http://localhost:5173/auth/callback`

2. **Row Level Security**
   - Ensure RLS is enabled on all tables
   - Verify policies are correctly applied

## Troubleshooting

### Common Issues

1. **"User not authenticated" errors**
   - Check environment variables
   - Verify Supabase project configuration
   - Clear browser localStorage and retry

2. **Role-based access not working**
   - Verify user profile has correct role
   - Check RLS policies in Supabase dashboard
   - Test policies in SQL editor

3. **Redirect loops**
   - Check layout redirect logic
   - Verify auth store initialization
   - Clear browser cache and cookies

4. **Database permission errors**
   - Verify RLS policies are active
   - Check user authentication status
   - Test queries in Supabase SQL editor

### Debug Tools
- Browser DevTools: Check network requests and local storage
- Supabase Dashboard: Monitor auth events and database queries
- Console Logs: Enable auth debugging in development

## Future Enhancements

### Short Term
- [ ] Email confirmation flow
- [ ] Password reset functionality
- [ ] Server-side session validation
- [ ] API route protection

### Long Term
- [ ] Multi-factor authentication
- [ ] Social login providers (Google, Apple)
- [ ] Family/household management
- [ ] Admin role for multi-family systems
- [ ] Audit logging for sensitive operations

## Support

For authentication-related issues:
1. Check this documentation
2. Review Supabase Auth documentation
3. Test with SQL queries in Supabase dashboard
4. Check browser console for error messages