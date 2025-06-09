# Automation Setup for Louis' Taschengeld App

This document explains how to set up automated weekly allowance payments and monthly interest calculations for the pocket money app.

## Automated Payments

The app provides API endpoints that can be called by cron jobs or other scheduling systems to automatically process payments.

### API Endpoints

#### Weekly Allowance

- **URL**: `POST /api/weekly-allowance`
- **Purpose**: Adds weekly allowance if due (checks if 7+ days since last payment)
- **Response**: JSON with success status and new balance

#### Monthly Interest

- **URL**: `POST /api/monthly-interest`
- **Purpose**: Adds monthly interest if due (checks if new month since last payment)
- **Response**: JSON with success status, interest amount, and new balance

#### Status Check Endpoints

- **URL**: `GET /api/weekly-allowance` - Check if weekly allowance is due
- **URL**: `GET /api/monthly-interest` - Check if monthly interest is due

## Setting Up Cron Jobs

### Option 1: Using crontab (Linux/macOS)

1. Open your crontab:

```bash
crontab -e
```

2. Add these lines for automated payments:

```bash
# Weekly allowance every Saturday at 8:00 AM
0 8 * * 6 curl -X POST http://localhost:5173/api/weekly-allowance

# Monthly interest on the 1st day of each month at 9:00 AM
0 9 1 * * curl -X POST http://localhost:5173/api/monthly-interest
```

### Option 2: Using systemd timers (Linux)

Create timer files in `/etc/systemd/system/`:

#### Weekly Allowance Timer

**File**: `/etc/systemd/system/taschengeld-weekly.service`

```ini
[Unit]
Description=Louis Taschengeld Weekly Allowance
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/curl -X POST http://localhost:5173/api/weekly-allowance
```

**File**: `/etc/systemd/system/taschengeld-weekly.timer`

```ini
[Unit]
Description=Run weekly allowance every Saturday at 8:00 AM
Requires=taschengeld-weekly.service

[Timer]
OnCalendar=Sat *-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

#### Monthly Interest Timer

**File**: `/etc/systemd/system/taschengeld-monthly.service`

```ini
[Unit]
Description=Louis Taschengeld Monthly Interest
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/curl -X POST http://localhost:5173/api/monthly-interest
```

**File**: `/etc/systemd/system/taschengeld-monthly.timer`

```ini
[Unit]
Description=Run monthly interest on 1st day of month at 9:00 AM
Requires=taschengeld-monthly.service

[Timer]
OnCalendar=*-*-01 09:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start the timers:

```bash
sudo systemctl enable taschengeld-weekly.timer
sudo systemctl enable taschengeld-monthly.timer
sudo systemctl start taschengeld-weekly.timer
sudo systemctl start taschengeld-monthly.timer
```

### Option 3: Using Node.js Scheduler (Built-in)

You can add this to your SvelteKit app for built-in scheduling:

1. Install node-cron:

```bash
pnpm add node-cron
pnpm add -D @types/node-cron
```

2. Create `src/lib/server/scheduler.ts`:

```typescript
import cron from 'node-cron';
import { PocketMoneyService } from './pocketMoney';

export function startScheduler() {
	// Weekly allowance every Saturday at 8:00 AM
	cron.schedule('0 8 * * 6', async () => {
		try {
			const isDue = await PocketMoneyService.isWeeklyAllowanceDue();
			if (isDue) {
				await PocketMoneyService.addWeeklyAllowance();
				console.log('Weekly allowance added automatically');
			}
		} catch (error) {
			console.error('Error adding weekly allowance:', error);
		}
	});

	// Monthly interest on 1st day of month at 9:00 AM
	cron.schedule('0 9 1 * *', async () => {
		try {
			const isDue = await PocketMoneyService.isMonthlyInterestDue();
			if (isDue) {
				await PocketMoneyService.addMonthlyInterest();
				console.log('Monthly interest added automatically');
			}
		} catch (error) {
			console.error('Error adding monthly interest:', error);
		}
	});

	console.log('Taschengeld scheduler started');
}
```

3. Add to your `src/hooks.server.ts`:

```typescript
import { startScheduler } from '$lib/server/scheduler';

// Start scheduler when server starts
startScheduler();
```

## Production Considerations

### Security

- In production, consider adding authentication to the API endpoints
- Use environment variables for API keys if needed
- Implement rate limiting

### Monitoring

- Set up logging for automated payments
- Add monitoring to ensure cron jobs are running
- Consider sending notifications (email/SMS) when payments are processed

### Backup Strategy

- Regular database backups
- Test restore procedures
- Monitor disk space for the SQLite database

### Example Monitoring Script

Create `scripts/check-automation.sh`:

```bash
#!/bin/bash

# Check if weekly allowance is due
WEEKLY_STATUS=$(curl -s http://localhost:5173/api/weekly-allowance | jq -r '.isDue')

# Check if monthly interest is due
MONTHLY_STATUS=$(curl -s http://localhost:5173/api/monthly-interest | jq -r '.isDue')

echo "Weekly allowance due: $WEEKLY_STATUS"
echo "Monthly interest due: $MONTHLY_STATUS"

# Log to file with timestamp
echo "$(date): Weekly=$WEEKLY_STATUS, Monthly=$MONTHLY_STATUS" >> /var/log/taschengeld-status.log
```

## Testing Automation

Before setting up production cron jobs, test the endpoints manually:

```bash
# Test weekly allowance
curl -X POST http://localhost:5173/api/weekly-allowance

# Test monthly interest
curl -X POST http://localhost:5173/api/monthly-interest

# Check status
curl http://localhost:5173/api/weekly-allowance
curl http://localhost:5173/api/monthly-interest
```

## Troubleshooting

### Common Issues

1. **Server not running**: Ensure your SvelteKit app is running on the specified port
2. **Network issues**: Check firewall settings and network connectivity
3. **Database locked**: Ensure only one process is accessing the SQLite database
4. **Permission issues**: Verify cron job user has necessary permissions

### Logs

- Check system logs: `journalctl -u taschengeld-weekly.service`
- Check cron logs: `grep CRON /var/log/syslog`
- Application logs: Check your SvelteKit app console output

This automation ensures Louis receives his allowance every Saturday at 8:00 AM and earns interest on the first day of each month, making the pocket money system fully automated!
