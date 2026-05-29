# Token Setup

The scripts accept two tokens covering two distinct account types:

| Token | Purpose | Env Variable |
|-------|---------|--------------|
| Personal | Accounts you own directly (no `managed_by`) | `CF_PERSONAL_TOKEN` |
| Partner | Tenant-managed client accounts (`managed_by` present) | `CF_PARTNER_TOKEN` |

Either token is optional — if you only supply one, accounts requiring the other are skipped with a warning.

## Required Permissions

Both tokens must be created at **My Profile → API Tokens** in the Cloudflare dashboard.

| Permission | Level | Why |
|------------|-------|-----|
| Account Settings | Read | Discover accounts via `GET /accounts` |
| Account Members | Edit | Add members via `POST /accounts/{id}/members` |

> **Partner token** must be created under the partner/tenant account (e.g. your agency), not a client account.

## Setting Environment Variables

```powershell
$env:CF_PERSONAL_TOKEN = "your-personal-api-token"
$env:CF_PARTNER_TOKEN  = "your-partner-api-token"
```

To persist across sessions, set them as user or system environment variables in Windows.
