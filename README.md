# CloudflareTools

Bulk member management for Cloudflare accounts. Designed for agencies and MSPs managing both directly-owned and partner-managed tenant accounts.

## What's Included

| Path | Description |
|------|-------------|
| `MemberDeployment/` | Standalone PowerShell script — run locally on-demand |
| `MemberDeploymentFunction/` | Azure Functions (PowerShell, timer-triggered) — runs hourly on a schedule |

Both variants read a `users.csv` file and add users to every Cloudflare account discoverable by your API token(s).  
Take care to ensure this file is not exposed publicly, as it outlines your team's emails and permission layout.  

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
2. Set `CF_PERSONAL_TOKEN`, `CF_PARTNER_TOKEN`, and optionally `CF_DRY_RUN` in **Application Settings**.
3. Place your `users.csv` in the `MemberDeploymentFunction/` root.
4. Deploy via CI/CD pipeline or directly from your IDE (e.g. VS Code Azure Functions extension).

For local development, copy `local.settings.json.example` → `local.settings.json` and fill in tokens.

The function triggers hourly (`0 0 * * * *`). Set `CF_DRY_RUN=true` to preview without changes.

## Documentation

See [`docs/`](docs/) for detailed usage, token setup, CSV format, and behavior reference.

## License

[MIT](LICENSE) — Bezalu LLC