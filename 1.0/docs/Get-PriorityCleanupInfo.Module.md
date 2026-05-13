---
Module Name: Get-PriorityCleanupInfo
Module Guid: c4e2b7a1-3f8d-4c5e-9b12-a63d5e7f8091
Download Help Link: https://github.com/dgoldman-msft/Get-PriorityCleanupInfo
Help Version: 1.0
Locale: en-US
---

# Get-PriorityCleanupInfo Module

## Description

Performs a full hierarchical retrieval of **Microsoft Purview Priority Cleanup** retention
compliance policies, their associated retention compliance rules, and compliance tags —
including multistage reviewer metadata.

The module queries the Security & Compliance Center via `Connect-IPPSSession` and walks the
following object hierarchy for every Priority Cleanup policy found:

```text
Retention Compliance Policy
  └─ Retention Compliance Rule  (ContentMatchQuery, RetentionComplianceAction)
       └─ Compliance Tag        (RetentionAction, RetentionType, MultiStageReviewerMetadata)
```

Each policy emits a typed `PriorityCleanupInfoResult` object to the pipeline. The default
`Format-Table` view (defined in the module's Format.ps1xml) shows `PolicyName`, `PolicyEnabled`,
`PolicyMode`, `DistributionStatus`, `TagName`, and `TagRetentionAction`.

At the end of each run a colour-coded summary list is printed to the console — green entries
indicate active policy+rule pairs, yellow entries indicate at least one disabled component,
and the Errors field turns red when DistributionStatus indicates a problem. The full summary
is also written to the log file.

A timestamped log file (`Logging_<yyyyMMdd_HHmmss>.txt`) is written to `-LogDirectory`
on every run so prior runs are never overwritten.

Use `-ConnectExchangeOnline` with optional `-UserPrincipalName` to connect to both Exchange
Online and the Security & Compliance Center automatically, with silent MSAL token reuse for
the IPPS session so only one interactive logon prompt is shown. Use `-StayConnected` to keep
the session open between calls.

## Get-PriorityCleanupInfo Cmdlets

### [Get-PriorityCleanupInfo](Get-PriorityCleanupInfo.md)

Retrieves comprehensive Priority Cleanup policy information from Microsoft Purview /
Security & Compliance Center.
