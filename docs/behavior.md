# Script Behavior

## Account Discovery

Both tokens independently call `GET /accounts`. Results are merged so accounts visible to only one token are still included. Duplicate account IDs are de-duplicated.

## Classification

Each account is classified using the `managed_by` field in the API response:

| `managed_by` | Classification | Token Used |
|--------------|---------------|------------|
| Present (has `parent_org_id`) | partner | Partner token |
| Absent | personal | Personal token |

No fallbacks. If the required token for an account is missing, that account is skipped.

## Member Adding

For each user not already a member:

1. Attempts a **direct-add** (`status: accepted`) — adds immediately, no confirmation email.
2. If direct-add is not permitted, falls back to a standard **invite** (`status: pending`) — sends a confirmation email.

Existing members are detected and skipped without making write API calls.

## Rate Limiting

Cloudflare enforces a per-token hourly invite quota. On a 429 response:

- The current user is counted as a failure.
- All remaining accounts using that same token source are skipped for the run.
- The *other* token continues unaffected.

Re-run after approximately one hour.

## Excluding Accounts

Edit the `$skipAccounts` array in the script:

```powershell
$skipAccounts = @("Account Name To Skip")
```

## Output Prefixes

| Prefix | Meaning |
|--------|---------|
| `+` | User successfully added |
| `=` | User already a member, skipped |
| `[!]` | Role downgraded (SuperAdmin → Administrator) |
| `[DRY-RUN]` | Action that would be taken (no change made) |
