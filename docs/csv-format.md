# CSV Format

The CSV must have exactly two columns: `Email` and `Role`.

```csv
Email,Role
alice@example.com,Super Administrator - All Privileges
bob@example.com,Administrator
carol@example.com,Administrator
```

- **Email** — the Cloudflare account email address of the user to add.
- **Role** — the exact Cloudflare role name (case-sensitive).

Run with `-ListRolesOnly` to discover available roles per account:

```powershell
.\Add-CfUsersToAllAccounts.ps1 -UsersCsvPath .\users.csv -ListRolesOnly
```

> If "Super Administrator - All Privileges" is requested for a partner-managed account that doesn't expose it, the script automatically downgrades to "Administrator" and logs a notice.
