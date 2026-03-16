# Add-CfUsersToAllAccounts

Bulk-adds users from a CSV file to every Cloudflare account discoverable by your API token(s). Designed for agencies and MSPs managing both directly-owned accounts and partner-managed tenant accounts from a single run.

---

## Requirements

- PowerShell 7.0 or later
- At least one Cloudflare API token (personal, partner, or both)
- A CSV file listing the users and roles to assign

---

## Token Setup

The script accepts two tokens covering two distinct account types:

| Token | Purpose | Env Variable |
|---|---|---|
| Personal | Accounts you own directly (no `managed_by`) | `CF_PERSONAL_TOKEN` |
| Partner | Tenant-managed client accounts (`managed_by` present) | `CF_PARTNER_TOKEN` |

Either token is optional — if you only supply one, accounts requiring the other are skipped with a warning. Supplying both is recommended for full coverage.

### Creating API Tokens

Both tokens must be created at **My Profile → API Tokens** in the Cloudflare dashboard.

**Minimum required permissions for each token:**

| Permission | Level | Why |
|---|---|---|
| Account Settings | Read | Discover accounts via `GET /accounts` |
| Account Members | Edit | Add members via `POST /accounts/{id}/members` |

> **Partner token:** Must be created under the partner/tenant account (e.g. "Bezalu.com - Agency"), not a client account.

### Setting Environment Variables (recommended)

Avoids passing tokens on the command line where they may appear in shell history.

```powershell
$env:CF_PERSONAL_TOKEN = "your-personal-api-token"
$env:CF_PARTNER_TOKEN  = "your-partner-api-token"
```

To persist them across sessions, set them as user or system environment variables in Windows.

---

## CSV Format

The CSV must have exactly two columns: `Email` and `Role`.

```csv
Email,Role
alice@example.com,Super Administrator - All Privileges
bob@example.com,Administrator
carol@example.com,Administrator
```

- **Email** — the Cloudflare account email address of the user to add.
- **Role** — the exact Cloudflare role name. Case-sensitive. Run with `-ListRolesOnly` to see available roles for each account.

A sample file is included: [`users.csv`](users.csv)

> **Note:** If a role named "Super Administrator - All Privileges" is requested for a partner-managed account that does not surface that role (common for tenant accounts), the script automatically downgrades the assignment to "Administrator" and logs a notice.

---

## Usage

### Standard run

```powershell
.\Add-CfUsersToAllAccounts.ps1 -UsersCsvPath .\users.csv
```

Tokens are read from `$env:CF_PERSONAL_TOKEN` and `$env:CF_PARTNER_TOKEN` automatically.

### Pass tokens explicitly

```powershell
.\Add-CfUsersToAllAccounts.ps1 -UsersCsvPath .\users.csv `
    -PersonalToken "your-personal-token" `
    -PartnerToken  "your-partner-token"
```

### Dry run (no changes made)

Preview every action the script would take without making any API calls that modify data.

```powershell
.\Add-CfUsersToAllAccounts.ps1 -UsersCsvPath .\users.csv -DryRun
```

### List available roles per account

Useful before your first run to confirm role names and verify token access. No CSV required.

```powershell
.\Add-CfUsersToAllAccounts.ps1 -UsersCsvPath .\users.csv -ListRolesOnly
```

---

## How It Works

### 1. Account Discovery

Both tokens independently call `GET /accounts`. Results are merged so that accounts visible to only one token are still included. Duplicate account IDs are de-duplicated (first token to return the account wins for the raw object).

### 2. Classification

Each account is classified using the `managed_by` field in the API response:

| `managed_by` | Classification | Token Used |
|---|---|---|
| Present (has `parent_org_id`) | `partner` | Partner token |
| Absent | `personal` | Personal token |

This classification is set once and never overridden. No fallbacks. If the appropriate token for an account is not configured, the account is skipped.

### 3. Pre-fetch

Before processing users for each account, the script fetches:
- All available roles (`GET /accounts/{id}/roles`) — to validate role names and detect SuperAdmin availability.
- All existing members (`GET /accounts/{id}/members`) — to skip users already present without burning API quota on redundant POSTs.

### 4. Member Adding

For each user not already a member:

1. Attempts a **direct-add** (`status: accepted`) — adds the user immediately with no confirmation email required.
2. If direct-add is not permitted (not all accounts support it), falls back to a standard **invite** (`status: pending`) which sends a confirmation email to the user.

### 5. Rate Limiting

Cloudflare enforces a per-token hourly invite quota. If a 429 is received:
- The current user is counted as a failure.
- All remaining accounts assigned to that same token (`partner` or `personal`) are skipped for the rest of the run with a clear notice.
- Accounts using the *other* token are unaffected and continue processing.

Re-run the script after approximately one hour to retry.

---

## Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-UsersCsvPath` | String | Yes | Path to the CSV file containing users and roles. |
| `-PersonalToken` | String | No | Cloudflare API token for personal accounts. Defaults to `$env:CF_PERSONAL_TOKEN`. |
| `-PartnerToken` | String | No | Cloudflare API token for partner-managed accounts. Defaults to `$env:CF_PARTNER_TOKEN`. |
| `-DryRun` | Switch | No | Simulate all actions without making any write API calls. |
| `-ListRolesOnly` | Switch | No | Print available roles for each discovered account and exit. |

---

## Output

Each account prints a header line showing its name, ID, and token classification:

```
Account: United Mortgage Lending (2194a6c1630bb7f5823ee5b80a67e9e2) [partner]
  + alice@example.com as 'Administrator' (no confirmation email).
  = bob@example.com already a member (skipped).

Account: Provider Claims Management (7c43118039e58fbe53b759a500e07933) [personal]
  + alice@example.com as 'Super Administrator - All Privileges' (confirmation email sent).

Done. Success: 3  Failures: 0
```

| Prefix | Meaning |
|---|---|
| `+` | User successfully added |
| `=` | User already a member, skipped |
| `[!]` | Role downgraded (SuperAdmin → Administrator) |
| `[DRY-RUN]` | Action that would be taken (no change made) |

The script exits with code `0` if all operations succeeded, `1` if any failures occurred.

---

## Excluding Accounts

To permanently exclude specific accounts from all runs, edit the `$skipAccounts` array near the bottom of the script:

```powershell
$skipAccounts = @("Bezalu / Talk IT Pro", "Another Account Name")
```

Excluded accounts are skipped before any API calls are made and appear in output as:
```
Account: Bezalu / Talk IT Pro — skipped (excluded account).
```

---

## Troubleshooting

**"No Cloudflare accounts discovered"**
Both tokens failed or returned empty results. Verify the tokens are valid and have Account Settings: Read permission.

**"Role 'X' not found. Available: ..."**
The role name in the CSV doesn't exactly match what Cloudflare returns. Run `-ListRolesOnly` to see the exact available role names for that account.

**"Could not pre-fetch data for '...'"**
The assigned token couldn't read roles or members for that account. Check that the token has Account Members: Read permission, and that the `managed_by` classification is correct.

**Authentication error (10000) on partner accounts**
The partner token doesn't have sufficient permissions, or was created under the wrong account. Ensure it was created under the tenant/partner account with Account Members: Edit permission.

**Confirmation emails going to users**
Direct-add (`status: accepted`) is only supported on certain account types (typically Enterprise/partner-managed). On personal accounts a confirmation email is expected.
