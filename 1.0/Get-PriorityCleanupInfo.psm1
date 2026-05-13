# Dot-source internal helper functions
. (Join-Path $PSScriptRoot 'internal\functions\Get-TimeStamp.ps1')
. (Join-Path $PSScriptRoot 'internal\functions\Write-ToLogFile.ps1')

# Dot-source public functions
. (Join-Path $PSScriptRoot 'functions\Get-PriorityCleanupInfo.ps1')

# Export public functions and aliases
Export-ModuleMember -Function 'Get-PriorityCleanupInfo' -Alias 'GPPI'
