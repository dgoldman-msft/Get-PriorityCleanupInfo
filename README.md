# Get-PriorityCleanupInfo

A PowerShell function that performs a full hierarchical retrieval of **Microsoft Purview Priority Cleanup** retention compliance policies, their associated rules, and compliance tags — including multistage reviewer metadata.

---

## Overview

Priority Cleanup is a Microsoft Purview feature that allows administrators to define retention policies that permanently delete content matching a specific query, subject to a multistage approval workflow before deletion occurs.

`Get-PriorityCleanupInfo` walks the full object hierarchy for every Priority Cleanup policy in the tenant:

```text
Retention Compliance Policy
  └─ Retention Compliance Rule  (ContentMatchQuery, RetentionComplianceAction)
       └─ Compliance Tag        (RetentionAction, MultiStageReviewerMetadata)
```

At the end of each run a **summary list** is printed to the console showing the policy name and state, rule GUID and state, compliance tag name, tag retention action, and any distribution errors detected — colour-coded green (active), yellow (disabled), or red (errors).

---

## Prerequisites

| Requirement | Details |
| --- | --- |
| PowerShell | 5.1 or PowerShell 7+ |
| ExchangeOnlineManagement | v3.9.2 or later (auto-installed when `-ConnectExchangeOnline` is used) |
| Role | **Compliance Administrator** or **View-Only Compliance Management** in the Microsoft Purview compliance portal |

---

## Installation

Download or clone the repository and dot-source the file in your PowerShell session:

```powershell
git clone https://github.com/dgoldman-msft/Get-PriorityCleanupInfo.git
. .\Get-PriorityCleanupInfo\Get-PriorityCleanupInfo.ps1
```

---

## Parameters

| Parameter | Type | Description |
| --- | --- | --- |
| `-ConnectExchangeOnline` | Switch | Installs/updates/imports `ExchangeOnlineManagement`, calls `Connect-ExchangeOnline`, then calls `Connect-IPPSSession`. Omit if already connected. |
| `-UserPrincipalName` | String | UPN passed to `Connect-ExchangeOnline` and `Connect-IPPSSession`. Enables silent token re-use so no second interactive prompt appears. |
| `-DisableBanner` | Switch | Suppresses the Exchange Online connection banner (`-ShowBanner:$false`). Only effective with `-ConnectExchangeOnline`. |
| `-StayConnected` | Switch | Skips the automatic `Disconnect-ExchangeOnline` call at the end of the run, leaving the session open. |
| `-LogDirectory` | String | Directory for timestamped log files (`Logging_<yyyyMMdd_HHmmss>.txt`). Each run creates a new file. Defaults to `$env:TEMP\PriorityCleanupInfo`. |

The function also has an alias: **`GPPI`**

---

## Usage

### Connect and retrieve (full auto-connect)

```powershell
Get-PriorityCleanupInfo -ConnectExchangeOnline -UserPrincipalName "admin@contoso.onmicrosoft.com"
```

### Already connected — just query

```powershell
Get-PriorityCleanupInfo -UserPrincipalName "admin@contoso.onmicrosoft.com"
```

### Suppress banner and keep session open

```powershell
Get-PriorityCleanupInfo -ConnectExchangeOnline -UserPrincipalName "admin@contoso.onmicrosoft.com" -DisableBanner -StayConnected
```

### Export results to CSV

```powershell
Get-PriorityCleanupInfo -UserPrincipalName "admin@contoso.onmicrosoft.com" |
    Export-Csv -Path "C:\Reports\PriorityCleanup.csv" -NoTypeInformation
```

### Display as a list

```powershell
Get-PriorityCleanupInfo -UserPrincipalName "admin@contoso.onmicrosoft.com" | Format-List
```

### Open in a grid view

```powershell
GPPI -UserPrincipalName "admin@contoso.onmicrosoft.com" -StayConnected | Out-GridView
```

---

## Output

Each Priority Cleanup policy emits one **`PSCustomObject`** to the pipeline with the following properties:

| Property | Source |
| --- | --- |
| `PolicyName` | Policy display name |
| `PolicyGuid` | Policy GUID |
| `ExchangeLocation` | Exchange mailbox scope (`{All}` = all mailboxes) |
| `ExchangeLocationException` | Excluded mailboxes |
| `IsSimulation` | Whether the policy is running in simulation mode |
| `PolicyEnabled` | `True` / `False` |
| `PolicyMode` | `Enforce` / `Test` |
| `DistributionStatus` | `Success`, `Pending`, etc. |
| `RuleGuid` | Rule GUID |
| `ContentMatchQuery` | KQL query used to match items for deletion |
| `ApplyComplianceTag` | GUID of the linked compliance tag |
| `RetentionComplianceAction` | `Delete`, `Keep`, `KeepAndDelete` |
| `RuleDisabled` | `True` / `False` |
| `RuleMode` | `Enforce` / `Test` |
| `TagName` | Compliance tag display name |
| `TagRetentionAction` | `Delete`, `Keep`, `KeepAndDelete` |
| `TagRetentionType` | `CreationAgeInDays`, `ModificationAgeInDays`, etc. |
| `TagRetentionDuration` | Retention period in days (`-1` = unlimited) |
| `TagMultiStageReviewers` | Pretty-printed JSON of multistage review stages and reviewers |
| `TagImmutableId` | Compliance tag immutable GUID |

### Console summary list

After processing all policies the function prints a per-policy summary list, e.g.:

```text
  Policy Name         : Priority Cleanup Policy
  Policy State        : Enabled
  Rule GUID           : 84bd3d33-4b74-4190-8e86-2bac7a18240e
  Rule State          : Enabled
  Compliance Tag      : Priority Cleanup Policy
  Tag Action          : Delete
  Errors              : None
```

Entries are colour-coded **green** when both policy and rule are active, **yellow** when either is disabled, and the `Errors` line turns **red** when `DistributionStatus` indicates a problem.

---

## Logging

Each run writes a timestamped log file to the `LogDirectory`:

```text
$env:TEMP\PriorityCleanupInfo\Logging_20260513_142315.txt
```

The log path is printed to the console at the end of every run.

---

## How it works

The function makes four sequential compliance cmdlet calls per policy:

| Step | Cmdlet | Purpose |
| --- | --- | --- |
| 1 | `Get-RetentionCompliancePolicy -PriorityCleanup` | Enumerate all Priority Cleanup policy names |
| 2 | `Get-RetentionCompliancePolicy <name> -PriorityCleanup -DistributionDetail` | Retrieve locations, status, and policy GUID |
| 3 | `Get-RetentionComplianceRule -Policy <policyGuid> -PriorityCleanup` | Retrieve the rule and the `ApplyComplianceTag` GUID |
| 4 | `Get-ComplianceTag <tagGuid> -PriorityCleanup` | Retrieve tag settings and multistage reviewer metadata |

---

## License

[MIT](LICENSE) © 2026 Dave Goldman
