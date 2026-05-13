function Write-ToLogFile {
    <#
        .SYNOPSIS
            Writes a message to the console and to a log file.

        .DESCRIPTION
            Module-level helper that writes a string to both the console (via Write-Host)
            and a persistent log file (Logging.txt) inside the specified directory.
            Creates the log directory automatically if it does not exist.

            Inside Get-PriorityCleanupInfo this function is shadowed by a local override
            that writes to the per-run timestamped log file ($script:_logFile) instead of
            the default Logging.txt, so all calls within the function target the correct
            file without any call-site changes.

        .PARAMETER StringObject
            The message string to write to the console and log file.

        .PARAMETER LogDirectory
            Full path to the directory where Logging.txt will be stored.
            Defaults to ".\Logs".

        .PARAMETER ForegroundColor
            Optional console foreground colour passed to Write-Host.

        .EXAMPLE
            Write-ToLogFile "$(Get-TimeStamp) Connecting to Exchange Online"

        .EXAMPLE
            Write-ToLogFile -StringObject "$(Get-TimeStamp) Export complete" -LogDirectory "C:\Reports\Logs"

        .NOTES
            Internal function — not exported by the module.
            Depends on Get-TimeStamp for formatted timestamps in error messages.
    #>
    [OutputType([System.String])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$StringObject,

        [Parameter()]
        [string]$LogDirectory = '.\Logs',

        [Parameter()]
        [System.ConsoleColor]$ForegroundColor
    )

    process {
        if (-not (Test-Path -Path $LogDirectory)) {
            if ($PSCmdlet.ShouldProcess($LogDirectory, 'Create logging directory')) {
                try {
                    New-Item -Path $LogDirectory -ItemType Directory -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Output "$(Get-TimeStamp) ERROR: Could not create log directory '$LogDirectory': $_"
                    return
                }
            }
        }

        try {
            if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
                Write-Host $StringObject -ForegroundColor $ForegroundColor
            }
            else {
                Write-Host $StringObject
            }
            Out-File -FilePath (Join-Path $LogDirectory 'Logging.txt') `
                     -InputObject $StringObject -Encoding utf8 -Append -ErrorAction Stop
        }
        catch {
            Write-Output "$(Get-TimeStamp) ERROR: Could not write to log file: $_"
        }
    }
}
