param (
    [Parameter(Mandatory = $true)]
    [string]$InstallerName,

    [Parameter(Mandatory = $true)]
    [string]$DownloadUrl
)

# Define log file path
$LogFile = Join-Path -Path $env:TEMP -ChildPath "InstallScriptLog_$(Get-Date -Format 'yyyyMMddHHmmss').log"

# Function to log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
}

# Start logging
Write-Log "Script execution started."

try {
    # Define paths
    $TempPath = $env:TEMP
    $InstallerPath = Join-Path -Path $TempPath -ChildPath $InstallerName

    # Download the installer
    Write-Log "Downloading installer from $DownloadUrl to $InstallerPath."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -ErrorAction Stop

    # Run the installer
    Write-Log "Starting installer $InstallerPath with silent arguments."
    Start-Process -FilePath $InstallerPath -ArgumentList "/silent /install" -Verb RunAs -Wait -ErrorAction Stop

    # Clean up
    Write-Log "Removing installer $InstallerPath."
    Remove-Item -Path $InstallerPath -Force -ErrorAction Stop

    Write-Log "Installation completed successfully."
} catch {
    # Log any errors
    Write-Log "An error occurred: $_" -Level "ERROR"
    throw
} finally {
    Write-Log "Script execution finished."
}