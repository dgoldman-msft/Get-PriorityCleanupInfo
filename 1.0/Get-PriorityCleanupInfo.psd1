@{
    # Module identity
    RootModule        = 'Get-PriorityCleanupInfo.psm1'
    ModuleVersion     = '1.0'
    GUID              = 'c4e2b7a1-3f8d-4c5e-9b12-a63d5e7f8091'
    Author            = 'Dave Goldman'
    CompanyName       = ' '
    Copyright         = '(c) Dave Goldman. All rights reserved.'

    # Description
    Description       = 'Retrieves comprehensive Priority Cleanup policy information from Microsoft Purview / Security and Compliance Center. Performs a full hierarchical retrieval of retention compliance policies, rules, and compliance tags including multistage reviewer metadata.'

    # Minimum PowerShell version required
    PowerShellVersion = '5.1'

    # ExchangeOnlineManagement >= 3.9.2 is required at runtime but NOT listed in RequiredModules.
    # Listing it here would force PowerShell to import it at module-load time, which fails in
    # sessions where the module is not yet present. Version enforcement is done at runtime
    # inside the function when the module check runs.
    RequiredModules   = @()

    # Format file
    FormatsToProcess  = @('.\xml\Get-PriorityCleanupInfo.Format.ps1xml')

    # Exports
    FunctionsToExport = @('Get-PriorityCleanupInfo')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('GPPI')

    # Private data / Gallery metadata
    PrivateData       = @{
        PSData = @{
            Tags         = @('Purview', 'Compliance', 'PriorityCleanup', 'RetentionPolicy',
                             'ExchangeOnline', 'MicrosoftPurview', 'Security', 'IPPSSession')
            LicenseUri   = 'https://github.com/dgoldman-msft/Get-PriorityCleanupInfo/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/dgoldman-msft/Get-PriorityCleanupInfo'
            ReleaseNotes = 'Initial release.'
        }
    }
}
