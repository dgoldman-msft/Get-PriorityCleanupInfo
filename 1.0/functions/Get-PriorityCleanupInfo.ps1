function Get-PriorityCleanupInfo {
    <#
        .SYNOPSIS
            Retrieves comprehensive Priority Cleanup policy information from Microsoft Purview /
            Security & Compliance Center.

        .DESCRIPTION
            Get-PriorityCleanupInfo performs a full hierarchical retrieval of all Priority Cleanup
            retention compliance policies, including:

              - All Priority Cleanup retention policies (names)
              - Per-policy distribution details (exchange locations, simulation state, enabled
                status, mode, distribution status, GUID)
              - Retention compliance rules linked to each policy (query, tag, action, mode, GUID)
              - Compliance tags linked to each rule (retention action, type, duration, multistage
                reviewer metadata)

            The function iterates over every Priority Cleanup policy found and outputs a structured
            PriorityCleanupInfoResult object for each one, making the results easy to pipe, export,
            or format.

            When -ConnectExchangeOnline is specified the function will:
              1. Check for the ExchangeOnlineManagement module (v3.9.2+), installing or updating
                 it from PSGallery as required.
              2. Import the module.
              3. Connect to Exchange Online (Connect-ExchangeOnline).
              4. Connect to the Security & Compliance endpoint (Connect-IPPSSession), resolving
                 the UPN from the established EXO session when -UserPrincipalName is not supplied.
              5. Disconnect automatically when the function finishes (unless -StayConnected is set).

            The ExchangeOnlineManagement module is checked and imported on every run regardless
            of whether -ConnectExchangeOnline is specified. Connect-IPPSSession is always called
            when -UserPrincipalName is provided or when -ConnectExchangeOnline resolves a UPN.

        .PARAMETER ConnectExchangeOnline
            When specified, installs/updates/imports ExchangeOnlineManagement, then calls
            Connect-ExchangeOnline and Connect-IPPSSession automatically.
            Omit this switch if you are already connected to the compliance endpoint.

        .PARAMETER UserPrincipalName
            The UPN (e.g. admin@contoso.onmicrosoft.com) passed to Connect-ExchangeOnline and
            Connect-IPPSSession. When provided both connections use the supplied UPN, enabling
            silent/certificate-based or pre-authenticated flows without a second interactive prompt.
            Also used when -ConnectExchangeOnline is not specified to authenticate to
            Connect-IPPSSession directly.

        .PARAMETER DisableBanner
            When specified together with -ConnectExchangeOnline, passes -ShowBanner:$false to
            Connect-ExchangeOnline to suppress the connection banner.

        .PARAMETER StayConnected
            When specified, skips the automatic Disconnect-ExchangeOnline call at the end of the
            function so the session remains open for further commands.

        .PARAMETER LogDirectory
            Directory for the timestamped log file (Logging_<yyyyMMdd_HHmmss>.txt).
            Each run creates a new file so prior runs are never overwritten.
            Defaults to a 'PriorityCleanupInfo' subfolder inside $env:TEMP.

        .EXAMPLE
            Get-PriorityCleanupInfo -ConnectExchangeOnline -UserPrincipalName "admin@contoso.onmicrosoft.com"

            Installs/imports the module, connects using the specified UPN, outputs all Priority
            Cleanup policy details, then disconnects.

        .EXAMPLE
            Get-PriorityCleanupInfo -ConnectExchangeOnline -UserPrincipalName "admin@contoso.onmicrosoft.com" |
                Export-Csv -Path "C:\Reports\PriorityCleanup.csv" -NoTypeInformation

            Exports all results to a CSV file.

        .EXAMPLE
            Get-PriorityCleanupInfo -UserPrincipalName "admin@contoso.onmicrosoft.com" | Format-List

            Uses an existing Exchange Online session and authenticates to Connect-IPPSSession
            with the supplied UPN. Displays all results as a list.

        .EXAMPLE
            Get-PriorityCleanupInfo -ConnectExchangeOnline -DisableBanner -StayConnected | Out-GridView

            Connects without the banner, displays results in a grid, and leaves the session open.

        .OUTPUTS
            PriorityCleanupInfoResult — one object per Priority Cleanup policy with properties:
            PolicyName, PolicyGuid, ExchangeLocation, ExchangeLocationException, IsSimulation,
            PolicyEnabled, PolicyMode, DistributionStatus, RuleGuid, ContentMatchQuery,
            ApplyComplianceTag, RetentionComplianceAction, RuleDisabled, RuleMode,
            TagName, TagRetentionAction, TagRetentionType, TagRetentionDuration,
            TagMultiStageReviewers, TagImmutableId.

        .NOTES
            Prerequisites:
              - ExchangeOnlineManagement module v3.9.2+ (auto-installed when -ConnectExchangeOnline
                is specified, otherwise must be present).
              - The authenticating account requires the Compliance Administrator or View-Only
                Compliance Management role in the Microsoft Purview compliance portal.

            Alias: GPPI

            Author  : Dave Goldman
            Version : 1.0.0
            Date    : 2026-05-13
        #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [Alias('GPPI')]
    [OutputType('PriorityCleanupInfoResult')]
    param (
        [Parameter()]
        [switch]$ConnectExchangeOnline,

        [Parameter()]
        [string]$UserPrincipalName,

        [Parameter()]
        [switch]$DisableBanner,

        [Parameter()]
        [switch]$StayConnected,

        [Parameter()]
        [string]$LogDirectory = (Join-Path $env:TEMP 'PriorityCleanupInfo')
    )

    begin {
        #region --- Helpers (shadow Write-ToLogFile for timestamped log) ---
        $script:_runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $script:_logFile  = Join-Path $LogDirectory "Logging_$($script:_runStamp).txt"
        $script:_abortRun = $false

        # Shadow the module-level Write-ToLogFile so every call in this function
        # writes to the per-run timestamped log file without changing any call sites.
        function Write-ToLogFile {
            param(
                [Parameter(Mandatory = $true, Position = 0)]
                [string]$Message,
                [System.ConsoleColor]$ForegroundColor
            )
            try {
                if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
                    Write-Host $Message -ForegroundColor $ForegroundColor
                }
                else {
                    Write-Host $Message
                }
                Out-File -FilePath $script:_logFile -InputObject $Message -Encoding utf8 -Append -ErrorAction Stop
            }
            catch {
                Write-Host "$(Get-TimeStamp) WARNING: Could not write to log: $_" -ForegroundColor DarkYellow
            }
        }

        # Ensure log directory exists
        if (-not (Test-Path -Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
        }

        $separator = "$(Get-TimeStamp) " + ('-' * 80)
        Write-ToLogFile $separator
        Write-ToLogFile "$(Get-TimeStamp) Starting Get-PriorityCleanupInfo"
        Write-ToLogFile "$(Get-TimeStamp) LogDirectory          : $LogDirectory"
        Write-ToLogFile "$(Get-TimeStamp) ConnectExchangeOnline : $ConnectExchangeOnline"
        Write-ToLogFile "$(Get-TimeStamp) UserPrincipalName     : $UserPrincipalName"
        Write-ToLogFile "$(Get-TimeStamp) DisableBanner         : $DisableBanner"
        Write-ToLogFile "$(Get-TimeStamp) StayConnected         : $StayConnected"
        #endregion

        #region --- Module check and import (always runs) ---
        $requiredEXOVersion = [version]'3.9.2'
        Write-ToLogFile "$(Get-TimeStamp) Checking for ExchangeOnlineManagement module"
        try {
            $installedEXO = Get-Module -ListAvailable -Name ExchangeOnlineManagement |
                Sort-Object Version -Descending | Select-Object -First 1

            if (-not $installedEXO) {
                if ($ConnectExchangeOnline) {
                    Write-ToLogFile "$(Get-TimeStamp) ExchangeOnlineManagement not found. Installing from PSGallery..." -ForegroundColor Yellow
                    Install-Module -Name ExchangeOnlineManagement -MinimumVersion $requiredEXOVersion `
                        -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                    Write-ToLogFile "$(Get-TimeStamp) ExchangeOnlineManagement $requiredEXOVersion installed successfully" -ForegroundColor Green
                }
                else {
                    Write-ToLogFile "$(Get-TimeStamp) ERROR: ExchangeOnlineManagement not found. Install it or re-run with -ConnectExchangeOnline." -ForegroundColor Red
                    $script:_abortRun = $true
                    return
                }
            }
            elseif ($installedEXO.Version -lt $requiredEXOVersion) {
                if ($ConnectExchangeOnline) {
                    Write-ToLogFile "$(Get-TimeStamp) ExchangeOnlineManagement $($installedEXO.Version) is below minimum $requiredEXOVersion. Updating..." -ForegroundColor Yellow
                    Update-Module -Name ExchangeOnlineManagement -Force -ErrorAction Stop
                    Write-ToLogFile "$(Get-TimeStamp) ExchangeOnlineManagement updated to minimum $requiredEXOVersion" -ForegroundColor Green
                }
                else {
                    Write-ToLogFile "$(Get-TimeStamp) WARNING: ExchangeOnlineManagement $($installedEXO.Version) is below minimum $requiredEXOVersion. Proceeding anyway." -ForegroundColor Yellow
                }
            }
            else {
                Write-ToLogFile "$(Get-TimeStamp) ExchangeOnlineManagement $($installedEXO.Version) found (>= $requiredEXOVersion)" -ForegroundColor Green
            }

            Import-Module ExchangeOnlineManagement -MinimumVersion $requiredEXOVersion -ErrorAction Stop
            Write-ToLogFile "$(Get-TimeStamp) ExchangeOnlineManagement imported" -ForegroundColor Green
        }
        catch {
            Write-ToLogFile "$(Get-TimeStamp) ERROR: Failed to load ExchangeOnlineManagement: $($_.Exception.Message)" -ForegroundColor Red
            $script:_abortRun = $true
            return
        }
        #endregion

        #region --- Connect to Exchange Online (only when -ConnectExchangeOnline) ---
        if ($ConnectExchangeOnline) {
            Write-Verbose "Auto-connecting to Exchange Online"
            try {
                $connectParams = @{ ErrorAction = 'Stop' }
                if ($DisableBanner)     { $connectParams['ShowBanner']        = $false }
                if ($UserPrincipalName) { $connectParams['UserPrincipalName'] = $UserPrincipalName }
                Connect-ExchangeOnline @connectParams
                Write-Verbose "Successfully connected to Exchange Online"
                Write-ToLogFile "$(Get-TimeStamp) Successfully connected to Exchange Online" -ForegroundColor Green
            }
            catch {
                Write-ToLogFile "$(Get-TimeStamp) ERROR: Failed to connect to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
                $script:_abortRun = $true
                return
            }
        }
        #endregion

        #region --- Connect to Security & Compliance Center ---
        try {
            # Resolve UPN: prefer explicit parameter, fall back to active EXO session info
            $resolvedUPN = if ($UserPrincipalName) {
                $UserPrincipalName
            }
            elseif ($ConnectExchangeOnline) {
                (Get-ConnectionInformation | Select-Object -First 1).UserPrincipalName
            }

            Write-ToLogFile "$(Get-TimeStamp) Connecting to Security and Compliance Center"
            $ippsParams = @{ ErrorAction = 'Stop' }
            if ($DisableBanner) { $ippsParams['ShowBanner']        = $false }
            if ($resolvedUPN)   { $ippsParams['UserPrincipalName'] = $resolvedUPN }
            Connect-IPPSSession @ippsParams
            Write-Verbose "Successfully connected to Security and Compliance Center"
            Write-ToLogFile "$(Get-TimeStamp) Successfully connected to Security and Compliance Center" -ForegroundColor Green
        }
        catch {
            Write-ToLogFile "$(Get-TimeStamp) ERROR: Failed to connect to Security and Compliance Center: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "ERROR: Could not connect to the Security and Compliance Center." -ForegroundColor Red
            Write-Host "  Action required: Ensure your account has the 'Compliance Administrator' role." -ForegroundColor Yellow
            $script:_abortRun = $true
            return
        }
        #endregion

        #region --- Validate required cmdlets are available ---
        Write-Verbose "Validating Security and Compliance session..."
        if (-not (Get-Command -Name 'Get-RetentionCompliancePolicy' -ErrorAction SilentlyContinue)) {
            Write-ToLogFile "$(Get-TimeStamp) ERROR: Get-RetentionCompliancePolicy cmdlet not found. No active Security and Compliance session detected." -ForegroundColor Red
            Write-Host "ERROR: No active Security and Compliance session was found." -ForegroundColor Red
            Write-Host "  Action required: Provide -UserPrincipalName so Connect-IPPSSession can authenticate," -ForegroundColor Yellow
            Write-Host "  or use -ConnectExchangeOnline to also connect to Exchange Online first." -ForegroundColor Yellow
            $script:_abortRun = $true
            return
        }
        Write-Verbose "Security and Compliance session validated"
        Write-ToLogFile "$(Get-TimeStamp) Security and Compliance session validated" -ForegroundColor Green
        #endregion
    }

    process {
        if ($script:_abortRun) { return }

        #region --- Step 1: Get all Priority Cleanup policies ---
        Write-ToLogFile "$(Get-TimeStamp) Retrieving all Priority Cleanup retention compliance policies..."
        $policies = Get-RetentionCompliancePolicy -PriorityCleanup |
            Select-Object -ExpandProperty Name

        if (-not $policies) {
            Write-Warning "No Priority Cleanup retention compliance policies were found."
            Write-ToLogFile "$(Get-TimeStamp) WARNING: No Priority Cleanup policies found." -ForegroundColor Yellow
            return
        }

        Write-ToLogFile "$(Get-TimeStamp) Found $(@($policies).Count) policy/policies: $($policies -join ', ')" -ForegroundColor Cyan
        #endregion

        $script:_results = [System.Collections.Generic.List[PSCustomObject]]::new()

        foreach ($policyName in $policies) {

            #region --- Step 2: Distribution detail ---
            Write-ToLogFile "$(Get-TimeStamp) Retrieving distribution detail for policy: '$policyName'..."
            $detail = Get-RetentionCompliancePolicy $policyName -PriorityCleanup -DistributionDetail |
                Select-Object ExchangeLocation, ExchangeLocationException,
                              IsSimulation, PriorityCleanup, Enabled,
                              Mode, DistributionStatus, Guid

            if (-not $detail) {
                Write-Warning "Could not retrieve distribution details for policy '$policyName'. Skipping."
                Write-ToLogFile "$(Get-TimeStamp) WARNING: No distribution detail for '$policyName'. Skipping." -ForegroundColor Yellow
                continue
            }

            $policyGuid = $detail.Guid
            Write-ToLogFile "$(Get-TimeStamp) Policy GUID: $policyGuid" -ForegroundColor Yellow

            Write-Host ""
            Write-Host "$(Get-TimeStamp) ---- POLICY: $policyName ----" -ForegroundColor Cyan
            Write-Host ("  {0,-26}: {1}" -f 'PolicyGuid',               $policyGuid)
            Write-Host ("  {0,-26}: {1}" -f 'ExchangeLocation',         ($detail.ExchangeLocation -join ', '))
            Write-Host ("  {0,-26}: {1}" -f 'ExchangeLocationException', ($detail.ExchangeLocationException -join ', '))
            Write-Host ("  {0,-26}: {1}" -f 'IsSimulation',             $detail.IsSimulation)
            Write-Host ("  {0,-26}: {1}" -f 'PriorityCleanup',          $detail.PriorityCleanup)
            Write-Host ("  {0,-26}: {1}" -f 'Enabled',                  $detail.Enabled)
            Write-Host ("  {0,-26}: {1}" -f 'Mode',                     $detail.Mode)
            Write-Host ("  {0,-26}: {1}" -f 'DistributionStatus',       $detail.DistributionStatus)
            #endregion

            #region --- Step 3: Retention compliance rule ---
            Write-ToLogFile "$(Get-TimeStamp) Retrieving retention compliance rule for policy GUID: '$policyGuid'..."
            $rule = Get-RetentionComplianceRule -Policy $policyGuid -PriorityCleanup |
                Select-Object ContentMatchQuery, ApplyComplianceTag,
                              RetentionComplianceAction, PriorityCleanup,
                              Policy, Disabled, Mode, Guid

            if (-not $rule) {
                Write-Warning "No retention compliance rule found for policy '$policyName' (GUID: $policyGuid)."
                Write-ToLogFile "$(Get-TimeStamp) WARNING: No rule found for policy '$policyName'." -ForegroundColor Yellow
                [PSCustomObject]@{
                    PSTypeName                = 'PriorityCleanupInfoResult'
                    PolicyName                = $policyName
                    PolicyGuid                = $policyGuid
                    ExchangeLocation          = $detail.ExchangeLocation
                    ExchangeLocationException = $detail.ExchangeLocationException
                    IsSimulation              = $detail.IsSimulation
                    PolicyEnabled             = $detail.Enabled
                    PolicyMode                = $detail.Mode
                    DistributionStatus        = $detail.DistributionStatus
                    RuleGuid                  = $null
                    ContentMatchQuery         = $null
                    ApplyComplianceTag        = $null
                    RetentionComplianceAction = $null
                    RuleDisabled              = $null
                    RuleMode                  = $null
                    TagName                   = $null
                    TagRetentionAction        = $null
                    TagRetentionType          = $null
                    TagRetentionDuration      = $null
                    TagMultiStageReviewers    = $null
                    TagImmutableId            = $null
                }
                continue
            }

            $tagGuid = $rule.ApplyComplianceTag
            Write-ToLogFile "$(Get-TimeStamp) Rule GUID: $($rule.Guid) | ApplyComplianceTag: $tagGuid" -ForegroundColor Yellow

            Write-Host ""
            Write-Host "$(Get-TimeStamp) ---- RULE: $($rule.Guid) ----" -ForegroundColor Cyan
            Write-Host ("  {0,-26}: {1}" -f 'RuleGuid',                 $rule.Guid)
            Write-Host ("  {0,-26}: {1}" -f 'ContentMatchQuery',        $rule.ContentMatchQuery)
            Write-Host ("  {0,-26}: {1}" -f 'ApplyComplianceTag',       $tagGuid)
            Write-Host ("  {0,-26}: {1}" -f 'RetentionComplianceAction', $rule.RetentionComplianceAction)
            Write-Host ("  {0,-26}: {1}" -f 'PriorityCleanup',          $rule.PriorityCleanup)
            Write-Host ("  {0,-26}: {1}" -f 'Disabled',                 $rule.Disabled)
            Write-Host ("  {0,-26}: {1}" -f 'Mode',                     $rule.Mode)
            #endregion

            #region --- Step 4: Compliance tag ---
            $tag = $null
            if (-not [string]::IsNullOrWhiteSpace($tagGuid)) {
                Write-ToLogFile "$(Get-TimeStamp) Retrieving compliance tag: '$tagGuid'..."
                $tag = Get-ComplianceTag $tagGuid -PriorityCleanup |
                    Select-Object Name, RetentionAction, RetentionType,
                                  RetentionDuration, MultiStageReviewerMetadata,
                                  PriorityCleanup, ImmutableId
                Write-ToLogFile "$(Get-TimeStamp) Tag Name: $($tag.Name)" -ForegroundColor Yellow

                # Pretty-print the MultiStageReviewerMetadata for console display
                $reviewerDisplay = if ($tag.MultiStageReviewerMetadata) {
                    try {
                        $parsed = $tag.MultiStageReviewerMetadata | ConvertFrom-Json -ErrorAction Stop
                        $lines  = foreach ($stage in $parsed.MultiStageReviewSettings) {
                            "    Stage: $($stage.StageName) | Reviewers: $($stage.Reviewers -join ', ')"
                        }
                        $lines -join "`n"
                    }
                    catch { "    $($tag.MultiStageReviewerMetadata)" }
                }
                else { '    (none)' }

                Write-Host ""
                Write-Host "$(Get-TimeStamp) ---- COMPLIANCE TAG: $($tag.Name) ----" -ForegroundColor Cyan
                Write-Host ("  {0,-26}: {1}" -f 'ImmutableId',      $tag.ImmutableId)
                Write-Host ("  {0,-26}: {1}" -f 'RetentionAction',   $tag.RetentionAction)
                Write-Host ("  {0,-26}: {1}" -f 'RetentionType',     $tag.RetentionType)
                Write-Host ("  {0,-26}: {1}" -f 'RetentionDuration', $tag.RetentionDuration)
                Write-Host ("  {0,-26}: {1}" -f 'PriorityCleanup',   $tag.PriorityCleanup)
                Write-Host "  MultiStageReviewers:"
                Write-Host $reviewerDisplay
            }
            else {
                Write-Warning "Rule for policy '$policyName' has no ApplyComplianceTag value."
                Write-ToLogFile "$(Get-TimeStamp) WARNING: No ApplyComplianceTag on rule for '$policyName'." -ForegroundColor Yellow
            }
            #endregion

            #region --- Output ---
            Write-ToLogFile "$(Get-TimeStamp) Emitting result for policy '$policyName'"
            $result = [PSCustomObject]@{
                PSTypeName                = 'PriorityCleanupInfoResult'
                PolicyName                = $policyName
                PolicyGuid                = $policyGuid
                ExchangeLocation          = $detail.ExchangeLocation
                ExchangeLocationException = $detail.ExchangeLocationException
                IsSimulation              = $detail.IsSimulation
                PolicyEnabled             = $detail.Enabled
                PolicyMode                = $detail.Mode
                DistributionStatus        = $detail.DistributionStatus
                RuleGuid                  = $rule.Guid
                ContentMatchQuery         = $rule.ContentMatchQuery
                ApplyComplianceTag        = $tagGuid
                RetentionComplianceAction = $rule.RetentionComplianceAction
                RuleDisabled              = $rule.Disabled
                RuleMode                  = $rule.Mode
                TagName                   = $tag.Name
                TagRetentionAction        = $tag.RetentionAction
                TagRetentionType          = $tag.RetentionType
                TagRetentionDuration      = $tag.RetentionDuration
                TagMultiStageReviewers    = if ($tag.MultiStageReviewerMetadata) {
                                                try {
                                                    ($tag.MultiStageReviewerMetadata | ConvertFrom-Json -ErrorAction Stop) |
                                                        ConvertTo-Json -Depth 10
                                                }
                                                catch { $tag.MultiStageReviewerMetadata }
                                            }
                                            else { $null }
                TagImmutableId            = $tag.ImmutableId
            }
            $script:_results.Add($result)
            #endregion
        }

        #region --- Summary list ---
        Write-Host ""
        Write-ToLogFile "$(Get-TimeStamp) ===== SUMMARY =====" -ForegroundColor Cyan

        foreach ($r in $script:_results) {
            $pState    = if ($r.PolicyEnabled)      { 'Enabled'  } else { 'Disabled' }
            $rState    = if ($r.RuleDisabled)       { 'Disabled' } else { 'Enabled'  }
            $tagName   = if ($r.TagName)            { $r.TagName } else { '(none)'   }
            $tagAct    = if ($r.TagRetentionAction) { $r.TagRetentionAction } else { '(none)' }
            $rGuid     = if ($r.RuleGuid)           { $r.RuleGuid } else { '(none)'  }
            $errors    = @()
            if ($r.DistributionStatus -and $r.DistributionStatus -notin @('Success', 'Pending')) {
                $errors += "Distribution: $($r.DistributionStatus)"
            }
            $errorText = if ($errors.Count -gt 0) { $errors -join '; ' } else { 'None' }
            $color     = if ($r.PolicyEnabled -and -not $r.RuleDisabled) { 'Green' } else { 'Yellow' }
            $errColor  = if ($errors.Count -gt 0) { 'Red' } else { $color }

            $line = "  {0,-20}: {1}"
            Write-Host ""
            Write-ToLogFile ($line -f 'Policy Name',    $r.PolicyName)  -ForegroundColor $color
            Write-ToLogFile ($line -f 'Policy State',   $pState)        -ForegroundColor $color
            Write-ToLogFile ($line -f 'Rule GUID',      $rGuid)         -ForegroundColor $color
            Write-ToLogFile ($line -f 'Rule State',     $rState)        -ForegroundColor $color
            Write-ToLogFile ($line -f 'Compliance Tag', $tagName)       -ForegroundColor $color
            Write-ToLogFile ($line -f 'Tag Action',     $tagAct)        -ForegroundColor $color
            Write-ToLogFile ($line -f 'Errors',         $errorText)     -ForegroundColor $errColor
        }
        #endregion

        Write-Host ""
        Write-ToLogFile "$(Get-TimeStamp) Get-PriorityCleanupInfo complete." -ForegroundColor Cyan
        Write-Host "Log file: $($script:_logFile)" -ForegroundColor Cyan
    }

    end {
        # Disconnect if this function established the session
        if ($ConnectExchangeOnline -and -not $StayConnected -and -not $script:_abortRun) {
            try {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Stop
                Write-Verbose "Disconnected from Exchange Online and Security and Compliance Center"
                Write-ToLogFile "$(Get-TimeStamp) Disconnected from Exchange Online and Security and Compliance Center" -ForegroundColor Green
            }
            catch {
                Write-ToLogFile "$(Get-TimeStamp) WARNING: Could not disconnect: $($_.Exception.Message)" -ForegroundColor DarkYellow
            }
        }
    }
}
