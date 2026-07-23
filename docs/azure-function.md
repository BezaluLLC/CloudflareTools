# Azure Function Deployment

The `MemberDeploymentFunction/` directory contains a timer-triggered Azure Function that runs the member sync on a schedule.

## Deploying

1. Create an Azure Function App with the **PowerShell 7.4** runtime.
2. Set the required tokens in **Configuration → Application Settings** (not `local.settings.json` — that file is for local dev only and is never deployed).
3. Deploy the code via one of:
   - **CI/CD** — push from a GitHub Actions or Azure DevOps pipeline.
   - **IDE** — use the VS Code Azure Functions extension ("Deploy to Function App…").
   - **CLI** — `func azure functionapp publish <app-name>`.

## Application Settings

| App Setting | Description |
|-------------|-------------|
| `CF_PERSONAL_TOKEN` | Personal API token |
| `CF_PARTNER_TOKEN` | Partner API token (optional) |
| `SUPERADMIN_USERS` | Comma-delimited email addresses assigned `Super Administrator - All Privileges` |
| `ADMIN_USERS` | Comma-delimited email addresses assigned `Administrator` |
| `CF_DRY_RUN` | Set to `"true"` to preview without changes |

## Schedule

Default: hourly (`0 0 * * * *`). Modify the `schedule` in `AddCfUsersTimer/function.json`.

## Users

Set `SUPERADMIN_USERS` and `ADMIN_USERS` in Application Settings. Whitespace around comma-delimited addresses is ignored. An address must appear in only one variable.

## Local Development

1. Copy `local.settings.json.example` → `local.settings.json`
2. Fill in your tokens
3. Run with Azure Functions Core Tools:

```powershell
cd MemberDeploymentFunction
func host start
```

## Runtime

- PowerShell 7.4
- No Az modules required (uses `Invoke-RestMethod` directly)
- 10-minute function timeout configured in `host.json`
