function Get-TimeStamp {
    <#
        .SYNOPSIS
            Returns a formatted timestamp string.

        .DESCRIPTION
            Returns the current date and time as a string in the format
            [yyyy-MM-dd HH:mm:ss] for use in log messages and console output.

        .EXAMPLE
            Get-TimeStamp
            Returns: [2026-05-13 14:30:00]

        .NOTES
            Internal function — not exported by the module.
    #>
    [CmdletBinding()]
    param()

    return "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]"
}
