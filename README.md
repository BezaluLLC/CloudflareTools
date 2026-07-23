# CloudflareTools

Bulk member management for Cloudflare accounts. Designed for agencies and MSPs managing both directly-owned and partner-managed tenant accounts.

## What's Included

| Path | Description |
|------|-------------|
| `MemberDeployment/` | Standalone PowerShell script — run locally on-demand |
| `MemberDeploymentFunction/` | Azure Functions (PowerShell, timer-triggered) — runs hourly on a schedule |

The standalone variant reads a `users.csv` file (treat it as sensitive and keep it out of source control). The Azure Function variant reads comma-delimited email addresses from `SUPERADMIN_USERS` and `ADMIN_USERS`. Both add users to discovered Cloudflare accounts (see `docs/behavior.md` for account exclusion/skipping).

## Quick Start

### Prerequisites

- PowerShell 7+
- At least one Cloudflare API token with **Account Settings: Read** and **Account Members: Edit**

### Local (one-shot)

```powershell
$env:CF_PERSONAL_TOKEN = "your-personal-token"
$env:CF_PARTNER_TOKEN  = "your-partner-token"

cd MemberDeployment
.\Add-CfUsersToAllAccounts.ps1 -UsersCsvPath .\users.csv
```

### Azure Function (scheduled)

1. Create an Azure Function App (PowerShell 7.4 runtime).
2. Set `CF_PERSONAL_TOKEN`, `CF_PARTNER_TOKEN`, `SUPERADMIN_USERS`, `ADMIN_USERS`, and optionally `CF_DRY_RUN` in **Application Settings**.
3. Deploy via CI/CD pipeline or directly from your IDE (e.g. VS Code Azure Functions extension).

For local development, copy `local.settings.json.example` → `local.settings.json` and fill in tokens and user email addresses.

The function triggers hourly (`0 0 * * * *`). Set `CF_DRY_RUN=true` to preview without changes.

## Documentation

See [`docs/`](docs/) for detailed usage, token setup, CSV format, user configuration, and behavior reference.

## License

[MIT](LICENSE) — Bezalu LLC