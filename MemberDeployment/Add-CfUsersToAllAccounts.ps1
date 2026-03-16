param(
    [Parameter(Mandatory = $true)]
    [string]$UsersCsvPath,

    [string]$PersonalToken = $env:CF_PERSONAL_TOKEN,
    [string]$PartnerToken  = $env:CF_PARTNER_TOKEN,

    [switch]$DryRun,
    [switch]$ListRolesOnly
)

$ErrorActionPreference = "Stop"
$BaseUrl = "https://api.cloudflare.com/client/v4"

# ── API helper ────────────────────────────────────────────────────────────────

function Invoke-CfApi {
    param(
        [Parameter(Mandatory)][ValidateSet("GET","POST","PUT","PATCH","DELETE")][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Token,
        [hashtable]$Query,
        $Body
    )

    $uri = $BaseUrl + $Path
    if ($Query -and $Query.Count) {
        $qs = ($Query.GetEnumerator() | ForEach-Object {
            [uri]::EscapeDataString([string]$_.Key) + "=" + [uri]::EscapeDataString([string]$_.Value)
        }) -join "&"
        $uri = $uri + "?" + $qs
    }

    $params = @{
        Method  = $Method
        Uri     = $uri
        Headers = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }
    }
    if ($null -ne $Body) { $params.Body = $Body | ConvertTo-Json -Depth 10 }

    try {
        $resp = Invoke-RestMethod @params
    }
    catch {
        $status = $null; $detail = $null
        if ($_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode } catch {}
        }
        # PS7: Invoke-RestMethod surfaces the response body via ErrorDetails.Message
        if ($_.ErrorDetails.Message) {
            $detail = $_.ErrorDetails.Message
        }
        elseif ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $detail = (New-Object System.IO.StreamReader $stream).ReadToEnd()
            } catch {}
        }
        $msg = "CF API $Method $Path failed"
        if ($status) { $msg += " [HTTP $status]" }
        if ($detail) { $msg += ": $detail" }
        throw $msg
    }

    if (-not $resp.success) {
        throw "CF API $Method $Path failed: $(($resp.errors | ConvertTo-Json -Compress))"
    }
    return $resp
}

function Get-CfPagedResults {
    param(
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$Path,
        [int]$PerPage = 50
    )
    $results = @(); $page = 1
    do {
        $resp = Invoke-CfApi -Method GET -Path $Path -Token $Token -Query @{ page = $page; per_page = $PerPage }
        if ($resp.result) { $results += $resp.result }
        $total = if ($resp.result_info.total_pages) { [int]$resp.result_info.total_pages } else { 1 }
        $page++
    } while ($page -le $total)
    return $results
}

# ── Validation ────────────────────────────────────────────────────────────────

if (-not (Test-Path -LiteralPath $UsersCsvPath)) { throw "CSV not found: $UsersCsvPath" }
if ([string]::IsNullOrWhiteSpace($PersonalToken) -and [string]::IsNullOrWhiteSpace($PartnerToken)) {
    throw "Supply at least one token via -PersonalToken / -PartnerToken or env vars CF_PERSONAL_TOKEN / CF_PARTNER_TOKEN."
}

$users = $null
if (-not $ListRolesOnly) {
    $users = Import-Csv -LiteralPath $UsersCsvPath
    if (-not $users -or $users.Count -eq 0) { throw "CSV is empty." }
    foreach ($u in $users) {
        if (-not $u.Email -or -not $u.Role) {
            throw "CSV row missing Email or Role: $($u | ConvertTo-Json -Compress)"
        }
    }
}

# ── Token registry ───────────────────────────────────────────────────────────
#
# Both tokens run GET /accounts independently so accounts visible to only one
# are still discovered. Classification is based solely on the managed_by field
# returned in each account object:
#   managed_by present  → partner-managed → use partner token exclusively
#   managed_by absent   → personal account → use personal token exclusively
#
# No fallbacks. Each account is assigned exactly one token at classification time.

# ── Account discovery ─────────────────────────────────────────────────────────

$rawAccounts = @{}
foreach ($tName in @("partner", "personal")) {
    $tok = if ($tName -eq "partner") { $PartnerToken } else { $PersonalToken }
    if ([string]::IsNullOrWhiteSpace($tok)) { continue }
    Write-Host "Discovering accounts via '$tName' token..."
    try {
        foreach ($a in (Get-CfPagedResults -Token $tok -Path "/accounts")) {
            if (-not $rawAccounts.ContainsKey($a.id)) {
                $rawAccounts[$a.id] = $a   # full object including managed_by
            }
        }
    }
    catch {
        Write-Warning "Failed to list accounts with '$tName' token: $($_.Exception.Message)"
    }
}

if ($rawAccounts.Count -eq 0) { throw "No Cloudflare accounts discovered with the provided token(s)." }
Write-Host "Discovered $($rawAccounts.Count) account(s).`n"

# Classify each account. Token is locked in here and never changes.
$accounts = foreach ($a in $rawAccounts.Values) {
    $isPartner = $null -ne $a.managed_by -and -not [string]::IsNullOrWhiteSpace($a.managed_by.parent_org_id)

    if ($isPartner -and [string]::IsNullOrWhiteSpace($PartnerToken)) {
        Write-Warning "Account '$($a.name)' is partner-managed but no partner token supplied — skipping."
        continue
    }
    if (-not $isPartner -and [string]::IsNullOrWhiteSpace($PersonalToken)) {
        Write-Warning "Account '$($a.name)' is personal but no personal token supplied — skipping."
        continue
    }

    [pscustomobject]@{
        Id          = $a.id
        Name        = $a.name
        TokenSource = if ($isPartner) { "partner" } else { "personal" }
        Token       = if ($isPartner) { $PartnerToken } else { $PersonalToken }
    }
}

# ── Role cache ────────────────────────────────────────────────────────────────

$roleCache = @{}
function Get-AccountRoles {
    param([string]$Token, [string]$AccountId)
    $key = "$AccountId|$Token"
    if (-not $roleCache.ContainsKey($key)) {
        $roleCache[$key] = Get-CfPagedResults -Token $Token -Path "/accounts/$AccountId/roles" -PerPage 100
    }
    return $roleCache[$key]
}

function Resolve-RoleId {
    param([string]$Token, [string]$AccountId, [string]$RoleName)
    $roles = Get-AccountRoles -Token $Token -AccountId $AccountId
    $match = $roles | Where-Object { $_.name -eq $RoleName } | Select-Object -First 1
    if (-not $match) {
        $avail = ($roles | Select-Object -ExpandProperty name | Sort-Object) -join ", "
        throw "Role '$RoleName' not found. Available: $avail"
    }
    return $match.id
}

# ── List roles only ───────────────────────────────────────────────────────────

if ($ListRolesOnly) {
    foreach ($acct in $accounts) {
        try {
            $roles = Get-AccountRoles -Token $acct.Token -AccountId $acct.Id
            Write-Host "Account: $($acct.Name) ($($acct.Id)) [$($acct.TokenSource)]"
            $roles | Select-Object -ExpandProperty name | Sort-Object | ForEach-Object { Write-Host "  - $_" }
        }
        catch {
            Write-Warning "Could not fetch roles for '$($acct.Name)': $($_.Exception.Message)"
        }
        Write-Host ""
    }
    return
}

# ── Add members ───────────────────────────────────────────────────────────────

$success     = 0
$fail        = 0
$rateLimited = @{}   # tracks token sources ("partner"/"personal") that hit 429

$skipAccounts = @("Bezalu / Talk IT Pro")

foreach ($acct in $accounts) {

    if ($skipAccounts -contains $acct.Name) {
        Write-Host "Account: $($acct.Name) — skipped (excluded account)."
        continue
    }

    if ($rateLimited.ContainsKey($acct.TokenSource)) {
        Write-Host "Account: $($acct.Name) — skipped ($($acct.TokenSource) token rate-limited)."
        $fail += $users.Count
        continue
    }

    # Pre-fetch roles and existing members using the assigned token.
    $accountRoles    = $null
    $existingMembers = $null
    try {
        $accountRoles    = Get-AccountRoles -Token $acct.Token -AccountId $acct.Id
        $existingMembers = Get-CfPagedResults -Token $acct.Token -Path "/accounts/$($acct.Id)/members" -PerPage 50
    }
    catch {
        Write-Warning "  Could not pre-fetch data for '$($acct.Name)': $($_.Exception.Message) — skipping account."
        $fail += $users.Count
        continue
    }

    Write-Host "Account: $($acct.Name) ($($acct.Id)) [$($acct.TokenSource)]"

    $superAdminAvailable = [bool]($accountRoles | Where-Object { $_.name -eq "Super Administrator - All Privileges" })

    $existingEmails = @{}
    foreach ($m in $existingMembers) {
        if ($m.user.email) { $existingEmails[$m.user.email.ToLower()] = $true }
    }

    $tokenRateLimited = $false

    foreach ($u in $users) {
        if ($tokenRateLimited) { $fail++; continue }

        $email    = [string]$u.Email
        $roleName = [string]$u.Role

        if ($existingEmails.ContainsKey($email.ToLower())) {
            Write-Host "  = $email already a member (skipped)."
            $success++
            continue
        }

        $effectiveRole = $roleName
        if (-not $superAdminAvailable -and $effectiveRole -eq "Super Administrator - All Privileges") {
            Write-Host "  [!] SuperAdmin not available on '$($acct.Name)' — using 'Administrator' for $email."
            $effectiveRole = "Administrator"
        }

        $roleId = $null
        try {
            $roleId = Resolve-RoleId -Token $acct.Token -AccountId $acct.Id -RoleName $effectiveRole
        }
        catch {
            Write-Warning "  Could not resolve role '$effectiveRole' in '$($acct.Name)': $($_.Exception.Message) — skipping user."
            $fail++
            continue
        }

        if ($DryRun) {
            Write-Host "  [DRY-RUN] $email as '$effectiveRole' via '$($acct.TokenSource)' token."
            $success++
            continue
        }

        try {
            # Attempt direct-add (status=accepted) first — skips confirmation email.
            # If it fails with 429 rethrow immediately; any other failure falls back to invite.
            try {
                $null = Invoke-CfApi -Method POST -Path "/accounts/$($acct.Id)/members" -Token $acct.Token -Body @{
                    email  = $email
                    roles  = @($roleId)
                    status = "accepted"
                }
                Write-Host "  + $email as '$effectiveRole' (no confirmation email)."
            }
            catch {
                if ($_.Exception.Message -match '"code":\s*429|HTTP 429') { throw }
                Write-Verbose "  Direct-add not permitted for '$($acct.Name)'; sending invite. [$($_.Exception.Message)]"
                $null = Invoke-CfApi -Method POST -Path "/accounts/$($acct.Id)/members" -Token $acct.Token -Body @{
                    email = $email
                    roles = @($roleId)
                }
                Write-Host "  + $email as '$effectiveRole' (confirmation email sent)."
            }
            $success++
        }
        catch {
            if ($_.Exception.Message -match '"code":\s*1003') {
                Write-Host "  = $email already a member (skipped)."
                $success++
            }
            elseif ($_.Exception.Message -match '"code":\s*429|HTTP 429') {
                Write-Warning "  Rate limited ($($acct.TokenSource) token): hourly invite quota exceeded. Skipping all remaining '$($acct.TokenSource)' accounts. Try again in ~1 hour."
                $rateLimited[$acct.TokenSource] = $true
                $tokenRateLimited = $true
                $fail++
            }
            else {
                Write-Warning "  Failed to add $email to '$($acct.Name)': $($_.Exception.Message)"
                $fail++
            }
        }
    }
    Write-Host ""
}

Write-Host "Done. Success: $success  Failures: $fail"
