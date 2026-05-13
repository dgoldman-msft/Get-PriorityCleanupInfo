---
external help file: Get-PriorityCleanupInfo-help.xml
Module Name: Get-PriorityCleanupInfo
online version: https://github.com/dgoldman-msft/Get-PriorityCleanupInfo
schema: 2.0.0
---

# Get-PriorityCleanupInfo

## SYNOPSIS

Retrieves comprehensive Priority Cleanup policy information from Microsoft Purview /
Security & Compliance Center.

## SYNTAX

```powershell
Get-PriorityCleanupInfo
    [-ConnectExchangeOnline]
    [-UserPrincipalName <String>]
    [-DisableBanner]
    [-StayConnected]
    [-LogDirectory <String>]
    [<CommonParameters>]
```

## DESCRIPTION

Performs a full hierarchical retrieval of all Priority Cleanup retention compliance policies
in the tenant, including:

- All Priority Cleanup retention policy names
- Per-policy distribution details (exchange locations, simulation state, enabled status, mode,
  distribution status, GUID)
- Retention compliance rules linked to each policy (KQL query, compliance tag GUID, action,
  mode, GUID)
- Compliance tags linked to each rule (retention action, type, duration, multistage reviewer
  metadata)

The function always checks for and imports the `ExchangeOnlineManagement` module (v3.9.2+)
before proceeding. It always calls `Connect-IPPSSession` when a UPN is available.

When `-ConnectExchangeOnline` is specified, the function additionally calls
`Connect-ExchangeOnline` and disconnects both sessions automatically on completion
(unless `-StayConnected` is set).

Each matched policy emits a typed `PriorityCleanupInfoResult` object to the pipeline.
The default table view shows `PolicyName`, `PolicyEnabled`, `PolicyMode`,
`DistributionStatus`, `TagName`, and `TagRetentionAction`.

A colour-coded summary list is printed to the console after all policies are processed:
green entries indicate active policy+rule pairs; yellow entries indicate a disabled policy or
rule; the Errors field turns red when DistributionStatus indicates a problem. The full summary
is also written to the log file.

A timestamped log file (`Logging_<yyyyMMdd_HHmmss>.txt`) is written to `-LogDirectory`
on every run so no prior run is overwritten.

## EXAMPLES

### Example 1: Connect and retrieve (full auto-connect)

```powershell
Get-PriorityCleanupInfo -ConnectExchangeOnline -UserPrincipalName "admin@contoso.onmicrosoft.com"
```

Installs/imports `ExchangeOnlineManagement`, connects to Exchange Online and the
Security & Compliance Center, outputs all Priority Cleanup policy details, then disconnects.

### Example 2: Already connected — just query

```powershell
Get-PriorityCleanupInfo -UserPrincipalName "admin@contoso.onmicrosoft.com"
```

Uses an existing Exchange Online session. Connects to the Security & Compliance Center using
the supplied UPN and queries all Priority Cleanup policies.

### Example 3: Suppress banner and keep session open

```powershell
Get-PriorityCleanupInfo -ConnectExchangeOnline -UserPrincipalName "admin@contoso.onmicrosoft.com" -DisableBanner -StayConnected
```

Connects without the connection banner and leaves both sessions open at the end of the run.

### Example 4: Export to CSV

```powershell
Get-PriorityCleanupInfo -UserPrincipalName "admin@contoso.onmicrosoft.com" |
    Export-Csv -Path "C:\Reports\PriorityCleanup.csv" -NoTypeInformation
```

Exports all result objects to a CSV file.

### Example 5: Display as a list

```powershell
Get-PriorityCleanupInfo -UserPrincipalName "admin@contoso.onmicrosoft.com" | Format-List
```

Displays all properties of every result object as a list.

### Example 6: Open in grid view using alias

```powershell
GPPI -UserPrincipalName "admin@contoso.onmicrosoft.com" -StayConnected | Out-GridView
```

Uses the `GPPI` alias, opens results in a graphical grid, and keeps the session open.

### Example 7: Custom log directory

```powershell
Get-PriorityCleanupInfo -ConnectExchangeOnline -UserPrincipalName "admin@contoso.onmicrosoft.com" `
    -LogDirectory "C:\AuditReports\PriorityCleanup"
```

Writes the timestamped log file to a custom directory.

### Example 8: Pipe results for further analysis

```powershell
$results = Get-PriorityCleanupInfo -UserPrincipalName "admin@contoso.onmicrosoft.com"

# Show all policies in enforce mode
$results | Where-Object { $results.PolicyMode -eq 'Enforce' } | Format-Table -AutoSize

# Show multistage reviewer metadata for the first result
$results[0].TagMultiStageReviewers
```

## PARAMETERS

### -ConnectExchangeOnline

When specified, installs/updates/imports `ExchangeOnlineManagement` (minimum v3.9.2),
calls `Connect-ExchangeOnline`, then calls `Connect-IPPSSession`. In the `end` block both
sessions are closed via `Disconnect-ExchangeOnline` unless `-StayConnected` is also specified.

If active sessions already exist, omit this switch and provide `-UserPrincipalName` instead.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserPrincipalName

The UPN (e.g. `admin@contoso.onmicrosoft.com`) passed to `Connect-ExchangeOnline` and
`Connect-IPPSSession`. When provided, `Connect-IPPSSession` performs a silent MSAL token
acquisition from the cache populated by `Connect-ExchangeOnline`, avoiding a second interactive
logon prompt.

When `-ConnectExchangeOnline` is not specified, the UPN is used to authenticate directly to
`Connect-IPPSSession`.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableBanner

When specified together with `-ConnectExchangeOnline`, passes `-ShowBanner:$false` to
`Connect-ExchangeOnline` to suppress the EXO module connection banner. Has no effect if
`-ConnectExchangeOnline` is not also specified.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -StayConnected

When specified, skips `Disconnect-ExchangeOnline` in the `end` block, leaving both the
Exchange Online and IPPS sessions open for subsequent calls in the same PowerShell session.
Only relevant when `-ConnectExchangeOnline` is also specified.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogDirectory

Full path to the directory used for the timestamped log file
(`Logging_<yyyyMMdd_HHmmss>.txt`). The directory is created automatically if it does not
exist. Each run creates a new file so prior runs are never overwritten.

Defaults to `$env:TEMP\PriorityCleanupInfo`.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: $env:TEMP\PriorityCleanupInfo
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: `-Debug`, `-ErrorAction`, `-ErrorVariable`,
`-InformationAction`, `-InformationVariable`, `-OutVariable`, `-OutBuffer`,
`-PipelineVariable`, `-Verbose`, `-WarningAction`, and `-WarningVariable`.
For more information, see [about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

This function does not accept pipeline input.

## OUTPUTS

### PriorityCleanupInfoResult

One object per Priority Cleanup policy. The default `Format-Table` view (defined in
`Get-PriorityCleanupInfo.Format.ps1xml`) shows `PolicyName`, `PolicyEnabled`, `PolicyMode`,
`DistributionStatus`, `TagName`, and `TagRetentionAction`.

| Property | Type | Description |
| --- | --- | --- |
| `PolicyName` | String | Retention compliance policy display name |
| `PolicyGuid` | Guid | Policy GUID |
| `ExchangeLocation` | Object[] | Exchange mailbox scope (`{All}` = all mailboxes) |
| `ExchangeLocationException` | Object[] | Explicitly excluded mailboxes |
| `IsSimulation` | Boolean | Whether the policy is in simulation mode |
| `PolicyEnabled` | Boolean | Whether the policy is enabled |
| `PolicyMode` | String | `Enforce` or `Test` |
| `DistributionStatus` | String | `Success`, `Pending`, `Failed`, etc. |
| `RuleGuid` | Guid | Retention compliance rule GUID |
| `ContentMatchQuery` | String | KQL query used to match items for deletion |
| `ApplyComplianceTag` | Guid | GUID of the compliance tag linked to the rule |
| `RetentionComplianceAction` | String | `Delete`, `Keep`, or `KeepAndDelete` |
| `RuleDisabled` | Boolean | Whether the rule is disabled |
| `RuleMode` | String | `Enforce` or `Test` |
| `TagName` | String | Compliance tag display name |
| `TagRetentionAction` | String | `Delete`, `Keep`, or `KeepAndDelete` |
| `TagRetentionType` | String | `CreationAgeInDays`, `ModificationAgeInDays`, etc. |
| `TagRetentionDuration` | Int | Retention period in days (`-1` = unlimited) |
| `TagMultiStageReviewers` | String | Pretty-printed JSON of multistage review stages and reviewers |
| `TagImmutableId` | Guid | Compliance tag immutable GUID |

## NOTES

- Requires the **Compliance Administrator** or **View-Only Compliance Management** role in the
  Microsoft Purview compliance portal.
- Requires `ExchangeOnlineManagement` v3.9.2 or later. The module is checked and imported on
  every run. If missing and `-ConnectExchangeOnline` is specified, it is installed automatically
  from PSGallery (`-Scope CurrentUser`).
- `-ConnectExchangeOnline` calls both `Connect-ExchangeOnline` and `Connect-IPPSSession`.
  A single `Disconnect-ExchangeOnline` closes both sessions.
- When `-UserPrincipalName` is not supplied and `-ConnectExchangeOnline` is used, the UPN is
  resolved from `Get-ConnectionInformation` after the EXO session is established, enabling
  silent MSAL token reuse for `Connect-IPPSSession`.
- `TagMultiStageReviewers` is serialised to pretty-printed JSON. The raw string is preserved as
  a fallback if JSON parsing fails.
- All log files are timestamped per run. Historical runs accumulate in `-LogDirectory`;
  rotate or archive them as needed.

Alias: `GPPI`

## RELATED LINKS

- [Project repository](https://github.com/dgoldman-msft/Get-PriorityCleanupInfo)
- [Connect-ExchangeOnline](https://learn.microsoft.com/en-us/powershell/module/exchange/connect-exchangeonline)
- [Connect-IPPSSession](https://learn.microsoft.com/en-us/powershell/module/exchange/connect-ippssession)
- [Get-RetentionCompliancePolicy](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-retentioncompliancepolicy)
- [Get-RetentionComplianceRule](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-retentioncompliancerule)
- [Get-ComplianceTag](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-compliancetag)
- [Microsoft Purview Priority Cleanup overview](https://learn.microsoft.com/en-us/purview/priority-cleanup)
