# User Configuration

Configure users with two comma-delimited environment variables:

```powershell
$env:SUPERADMIN_USERS = "alice@example.com"
$env:ADMIN_USERS      = "bob@example.com,carol@example.com"
```

- `SUPERADMIN_USERS` — users receive `Super Administrator - All Privileges`.
- `ADMIN_USERS` — users receive `Administrator`.

Run with `-ListRolesOnly` to discover available roles per account:

```powershell
.\Add-CfUsersToAllAccounts.ps1 -ListRolesOnly
```

Whitespace around comma-delimited addresses is ignored. An address must appear in only one variable. If `Super Administrator - All Privileges` is not available for an account, the script automatically downgrades that user to `Administrator` and logs a notice.
