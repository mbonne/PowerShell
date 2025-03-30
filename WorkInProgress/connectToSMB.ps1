<#
.SYNOPSIS
    Map a network share to a drive letter in an environment without an on-premises directory/domain.
    Script requires end-user interaction for credentials.

.DESCRIPTION
    This script maps a network share to a specified drive letter using provided credentials. It validates inputs, checks for existing mappings, and handles errors gracefully.

.PARAMETER Server
    The name or IP address of the server hosting the network share.

.PARAMETER ShareName
    The name of the network share to map.

.PARAMETER DriveLetter
    The drive letter to assign to the mapped network share.

.NOTES
    Author: mbonne
    Date: 2025-03-30
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$ShareName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z](:|:\\)?$')]
    [string]$DriveLetter
)

# Normalize drive letter format
if ($DriveLetter -notmatch ':\\$') {
    $DriveLetter = "${DriveLetter}:\"
}

# Define constants
$Port = 445
$CredentialPromptMessage = "Enter credentials for \\$Server\$ShareName"

# Check if the drive letter is already mapped
$IsDriveMapped = Test-Path -Path $DriveLetter

# Test SMB connection
try {
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    $TcpClient.Connect($Server, $Port)
    if (-not $TcpClient.Connected) {
        throw "Unable to connect to \\$Server on port $Port."
    }
} catch {
    Write-Error "Error: $_"
    return
} finally {
    $TcpClient.Dispose()
}

# Attempt to map the network share
try {
    if (-not $IsDriveMapped) {
        Write-Host ">> Attempting to map network share \\$Server\$ShareName to $DriveLetter"

        # Prompt for credentials
        $Credentials = Get-Credential -Message $CredentialPromptMessage

        # Map the network share
        New-SmbMapping -LocalPath $DriveLetter `
                       -RemotePath "\\$Server\$ShareName" `
                       -Persistent $true `
                       -UserName ($Credentials.GetNetworkCredential().UserName) `
                       -Password ($Credentials.GetNetworkCredential().Password)

        if ($?) {
            Write-Host ">> Successfully mapped \\$Server\$ShareName to $DriveLetter"
            explorer.exe $DriveLetter
        } else {
            Write-Warning ">> Failed to map the drive. Check your credentials or network settings."
        }
    } else {
        Write-Host ">> $DriveLetter is already mapped."
    }
} catch {
    Write-Error "An error occurred while mapping the network share: $_"
} finally {
    # Clear sensitive variables
    Remove-Variable -Name 'Credentials' -ErrorAction SilentlyContinue
}

# Display current SMB mappings
try {
    $SmbMappings = Get-SmbMapping | Format-Table -AutoSize | Out-String
    Write-Host "Current SMB Mappings:"
    Write-Host $SmbMappings
} catch {
    Write-Warning "Unable to retrieve SMB mappings: $_"
}
