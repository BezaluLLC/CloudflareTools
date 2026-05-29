# Add-CfUsersToAllAccounts

Standalone PowerShell script for bulk-adding users to all discoverable Cloudflare accounts.

## Usage

```powershell
$env:CF_PERSONAL_TOKEN = "your-personal-token"
$env:CF_PARTNER_TOKEN  = "your-partner-token"

.\Add-CfUsersToAllAccounts.ps1 -UsersCsvPath .\users.csv
```

## Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-UsersCsvPath` | String | Yes | Path to the CSV file containing users and roles. |
| `-PersonalToken` | String | No | Cloudflare API token for personal accounts. Defaults to `$env:CF_PERSONAL_TOKEN`. |
| `-PartnerToken` | String | No | Cloudflare API token for partner-managed accounts. Defaults to `$env:CF_PARTNER_TOKEN`. |
| `-DryRun` | Switch | No | Simulate all actions without making any write API calls. |
| `-ListRolesOnly` | Switch | No | Print available roles for each discovered account and exit. |

See [`../docs/`](../docs/) for token setup, CSV format, behavior details, and troubleshooting.

**Confirmation emails going to users**
Direct-add (`status: accepted`) is only supported on certain account types (typically Enterprise/partner-managed). On personal accounts a confirmation email is expected.
