<#
.SYNOPSIS
    Script to download and install CrowdStrike software from a local SMB path.

.DESCRIPTION
    This script downloads the specified installer from a shared SMB path and installs it with the provided CID.
    For ease of access, the SMB share is assumed to be accessible without credentials or User has already authenticated.

.PARAMETER exeName
    The name of the executable file to be downloaded and installed.

.PARAMETER smbSharedFilePath
    The SMB shared file path where the installer is located.

.PARAMETER CID
    The CID value required for the installation.

.EXAMPLE
    .\installCSFalcon.ps1 -exeName "WindowsSensor.MaverickGyr.exe" -smbSharedFilePath "\\server\share" -CID "9B8158CEXAMPLECID1633DA7418C2-D4"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$exeName,

    [Parameter(Mandatory = $true)]
    [string]$smbSharedFilePath,

    [Parameter(Mandatory = $true)]
    [string]$CID
)

# Variables
$softwareName = "CrowdStrike"
$workdir = "C:\Windows\Temp"
$logFile = "$workdir\installCSFalcon.log"

# Function to log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

# Start logging
Write-Log "Script execution started."

try {
    # Check if CrowdStrike service is running
    $serviceCheck = cmd.exe /c "sc query csagent"
    if ($serviceCheck -match "RUNNING") {
        Write-Log "$softwareName is already installed and running." -Level "INFO"
        return
    } else {
        Write-Log "$softwareName is not running or not installed. Proceeding with installation." -Level "WARNING"
    }

    Write-Log "Beginning $softwareName installation."

    # Ensure working directory exists
    if (-Not (Test-Path -Path $workdir -PathType Container)) {
        New-Item -Path $workdir -ItemType Directory -Force | Out-Null
        Write-Log "Created working directory: $workdir."
    } else {
        Write-Log "Working directory already exists: $workdir."
    }

    # Define source and destination paths
    $source = Join-Path -Path $smbSharedFilePath -ChildPath $exeName
    $destination = Join-Path -Path $workdir -ChildPath $exeName

    # Download the installer
    if (Get-Command 'Invoke-WebRequest' -ErrorAction SilentlyContinue) {
        Invoke-WebRequest -Uri $source -OutFile $destination -ErrorAction Stop
        Write-Log "Downloaded $exeName to $destination."
    } else {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($source, $destination)
        Write-Log "Downloaded $exeName to $destination using WebClient."
    }

    # Start the installation
    $installCommand = "$destination /install /quiet /norestart CID=$CID"
    Write-Log "Executing installation command: $installCommand."
    cmd.exe /c $installCommand | Out-Null

    # Wait for installation to complete
    Start-Sleep -Seconds 35

    # Verify installation
    $serviceCheck = cmd.exe /c "sc query csagent"
    if ($serviceCheck -match "RUNNING") {
        Write-Log "$softwareName installation completed successfully."
    } else {
        Write-Log "Failed to verify $softwareName installation." -Level "ERROR"
    }
} catch {
    Write-Log "An error occurred: $_" -Level "ERROR"
} finally {
    Write-Log "Script execution completed."
}