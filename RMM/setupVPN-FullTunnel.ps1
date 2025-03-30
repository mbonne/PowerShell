<#
.SYNOPSIS
  Creates a Meraki L2TP VPN connection on Windows 10 or 11 (Professional or Enterprise editions only).
.DESCRIPTION
  This script collects input parameters and creates a VPN connection using the Add-VPNConnection cmdlet.
  It validates the Windows edition and ensures compatibility with Meraki L2TP VPN settings.
.PARAMETER Name
  The name of the VPN connection that will appear in the Windows UI. (Mandatory)
.PARAMETER ServerAddr
  The server address for the VPN connection. (Mandatory)
.PARAMETER L2TPPSK
  The pre-shared key for the L2TP connection. (Mandatory)
.PARAMETER DnsSuffix
  The DNS suffix used by the VPN connection. (Mandatory)
.NOTES
  Version:        2.0
  Author:         mbonne
  Creation Date:  03/28/2019
  Updated:        10/2023
  Purpose/Change: Added compatibility checks for Windows 10/11 Professional/Enterprise editions and parameterized inputs.
.EXAMPLE
  .\setupVPN.ps1 -Name "MyVPN" -ServerAddr "vpn.example.com" -L2TPPSK "MySecretKey" -DnsSuffix "example.com"
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$ServerAddr,

    [Parameter(Mandatory = $true)]
    [string]$L2TPPSK,

    [Parameter(Mandatory = $true)]
    [string]$DnsSuffix
)

#-----------------------------------------------------------[Validation]-----------------------------------------------------------

# Check Windows version and edition
$OSBuildNumber = (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber

if ($OSBuildNumber -lt 10240) {
  Write-Error "!!! This script is only compatible with Windows 10 or later. Stopping VPN Config !!!"
  exit 1
}

$OSEdition = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID


if ($OSEdition -notin @("Professional", "Enterprise")) {
    Write-Error "!!! This script requires Windows Professional or Enterprise edition. Stopping VPN Config !!!"
    exit 1
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

try {
    Import-Module VpnClient -ErrorAction Stop

    Add-VpnConnection -RememberCredential -Name $Name -ServerAddress $ServerAddr -AuthenticationMethod Pap `
        -TunnelType L2tp -EncryptionLevel Custom -L2tpPsk $L2TPPSK -DnsSuffix $DnsSuffix -Force

    Write-Host "`n>>> VPN Connection has been successfully created."
    Write-Host "VPN Display Name: $Name"
    Write-Host "Server: $ServerAddr"
    Write-Host "Pre-Shared Key: $L2TPPSK"
    Write-Host "DNS Suffix: $DnsSuffix"
    Write-Host "Detailed information is located below:"
    Get-VpnConnection | Where-Object { $_.Name -eq $Name } | Format-List
} catch {
    Write-Error "!!! An error occurred while creating the VPN connection: $_ !!!"
    exit 1
}
