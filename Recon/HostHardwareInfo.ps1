# Retrieve system information
$ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$BIOS = Get-CimInstance -ClassName Win32_BIOS
$Processor = Get-CimInstance -ClassName Win32_Processor
$GPUs = Get-CimInstance -ClassName Win32_VideoController
$PhysicalMemory = Get-CimInstance -ClassName Win32_PhysicalMemory

# Fetch the disk and logical disk info with selected properties
$DiskDrives = Get-CimInstance -ClassName Win32_DiskDrive | Select-Object DeviceID, Index, MediaType, Model
$LogicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object DeviceID, VolumeName, FreeSpace, Size, DriveType, ProviderName

# RAM Details
$TotalRAM = [math]::Round(($ComputerSystem.TotalPhysicalMemory / 1GB), 0)
$ConfiguredClockSpeed = ($PhysicalMemory | Select-Object -First 1 -ExpandProperty ConfiguredClockSpeed)
$RAMSpeed = ($PhysicalMemory | Select-Object -First 1 -ExpandProperty Speed)
$RAMManufacturer = ($PhysicalMemory | Select-Object -First 1 -ExpandProperty Manufacturer)
$RAMPartNumber = ($PhysicalMemory | Select-Object -First 1 -ExpandProperty PartNumber) -replace "\s+$", ""
$SMBIOSMemoryType = ($PhysicalMemory | Select-Object -First 1 -ExpandProperty SMBIOSMemoryType)

# Determine DDR Version - DDR6 and other newer Memory types to be added
$DDRVersion = switch ($SMBIOSMemoryType) {
    20 { "DDR" }
    21 { "DDR2" }
    24 { "DDR3" }
    26 { "DDR4" }
    34 { "DDR5" }
    default { "Unknown" }
}

$DIMMCount = ($PhysicalMemory | Measure-Object).Count
$PerDIMMSize = [math]::Round(($TotalRAM / $DIMMCount), 0)
$RAMConfiguration = "{0}x {1}GB DIMMs" -f $DIMMCount, $PerDIMMSize
$RAMSummary = "{0} GB {1} @ {2} MHz (Speed: {3} MHz), {4}, {5}, PartNumber: {6}" -f `
    $TotalRAM, $DDRVersion, $ConfiguredClockSpeed, $RAMSpeed, $RAMConfiguration, $RAMManufacturer, $RAMPartNumber

# Fetch VRAM from the registry
$qwMemorySize = (Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -Name HardwareInformation.qwMemorySize -ErrorAction SilentlyContinue)."HardwareInformation.qwMemorySize"

# If found, calculate VRAM in GB
if ($qwMemorySize) {
    $VRAM = [math]::round($qwMemorySize / 1GB)
} else {
    # Default fallback in case of no registry entry
    $VRAM = "Unknown"
}

# GPU Details
$GPUInfo = $GPUs | ForEach-Object {
    $DedicatedVRAM = $VRAM
    if ($DedicatedVRAM -gt 0) {
        $DedicatedVRAM = [math]::Round($DedicatedVRAM, 0)  # VRAM is in GB
    } else {
        $DedicatedVRAM = "Unknown"
    }
    "GPU: {0} ({1} GB VRAM) - {2}, {3}" -f $_.Name, $DedicatedVRAM, $_.PNPDeviceID, $_.VideoProcessor
}

# Storage Details - Volume info and Installed Disks info
$StorageInfo = $LogicalDisks | ForEach-Object {
    $disk = $_
    
    # Calculate used percentage of the disk
    $usedPercent = if ($disk.Size -gt 0) { [math]::Round(((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100), 0) } else { "Unknown" }
    $diskSizeGB = if ($disk.Size -gt 0) { [math]::Round($disk.Size / 1GB, 0) } else { "Unknown" }
    
    # Output based on drive type
    if ($disk.DriveType -eq 4) {
        # Mapped Network Drive
        "{0} {1} ({2} GB) ({3}% used)" -f $_.DeviceID, $_.ProviderName, $diskSizeGB, $usedPercent
    } else {
        # Local Disk
        "{0} {1} ({2} GB) ({3}% used)" -f $_.DeviceID, ($disk.VolumeName -ne $null -and $disk.VolumeName -ne "" ? $disk.VolumeName : "Local Disk"),
        $diskSizeGB, $usedPercent
    }
}

# Installed Disks Info
$InstalledDisks = $DiskDrives | ForEach-Object {
    "{0} {1} - {2}" -f $_.DeviceID, $_.Model, $_.MediaType
}

# Get connected Wi-Fi details
$WiFiDetails = netsh wlan show interfaces | Out-String

# Extract SSID
if ($WiFiDetails -match "SSID\s+:\s+(.+)") { $ConnectedSSID = $matches[1].Trim() } else { $ConnectedSSID = "Not Connected" }

# Extract Encryption Type
if ($WiFiDetails -match "Authentication\s+:\s+(.+)") { $EncryptionType = $matches[1].Trim() } else { $EncryptionType = "Unknown" }

# Extract Band (Directly grab the Band string from the output)
if ($WiFiDetails -match "Band\s+:\s+(.+)") { $Band = $matches[1].Trim() } else { $Band = "Unknown" }

# Extract Channel
if ($WiFiDetails -match "Channel\s+:\s+(\d+)") { $Channel = $matches[1].Trim() } else { $Channel = "Unknown" }

# Extract RSSI (Signal Strength)
if ($WiFiDetails -match "Signal\s+:\s+(\d+)%") { $RSSI = [int]$matches[1] } else { $RSSI = "Unknown" }

# Extract TX Rate
if ($WiFiDetails -match "Transmit rate\s+\(Mbps\)\s+:\s+(\d+)") { $TransmitRate = $matches[1] + " Mbps" } else { $TransmitRate = "Unknown" }

# Extract RX Rate
if ($WiFiDetails -match "Receive rate\s+\(Mbps\)\s+:\s+(\d+)") { $ReceiveRate = $matches[1] + " Mbps" } else { $ReceiveRate = "Unknown" }

# Extract Radio Type
if ($WiFiDetails -match "Radio type\s+:\s+(.+)") { $RadioType = $matches[1].Trim() } else { $RadioType = "Unknown" }

# Calculate SNR (Assuming RSSI % of 100 is mapped to -30dBm)
$SNR = if ($RSSI -ne "Unknown") { "$([math]::Round($RSSI / 2, 0)) dB" } else { "Unknown" }

# Format output
$WiFiSummary = "SSID: {0}, Encryption: {1}, Band: {2}, Channel: {3}, RadioType: {4}, RSSI: {5}%, SNR: {6}, TX/RX: {7} / {8}" -f `
    $ConnectedSSID, $EncryptionType, $Band, $Channel, $RadioType, $RSSI, $SNR, $TransmitRate, $ReceiveRate

# Output formatted Wi-Fi summary
$WiFiSummary




# Updated NIC output (Removing Channel and Width from NIC list)
$NICDetails = $NICInfo | Sort-Object Name | ForEach-Object {
    $nic = $_
    
    # Determine the correct adapter type
    if ($nic.Name -match "Wi-Fi|Wireless" -or $nic.NetConnectionID -match "Wi-Fi") {
        $adapterType = "Wi-Fi"
    } elseif ($nic.AdapterType -eq "Ethernet 802.3") {
        $adapterType = "Ethernet"
    } else {
        $adapterType = $nic.AdapterType
    }

    # Determine speed representation
    if ($adapterType -eq "Ethernet") {
        if ($nic.Speed -ge 1000000000) {
            $nicSpeed = "1Gbps"
        } elseif ($nic.Speed -ge 100000000) {
            $nicSpeed = "100Mbps"
        } elseif ($nic.Speed -ge 10000000) {
            $nicSpeed = "10Mbps"
        } else {
            $nicSpeed = "{0} Kbps" -f [math]::Round($nic.Speed / 1Kb, 0)
        }
    } else {
        # Keep Mbps/Gbps format for Wi-Fi
        if ($nic.Speed -gt 1000000000) {
            $nicSpeed = "{0} Gbps" -f [math]::Round($nic.Speed / 1Gb, 2)
        } elseif ($nic.Speed -gt 1000000) {
            $nicSpeed = "{0} Mbps" -f [math]::Round($nic.Speed / 1Mb, 2)
        } else {
            $nicSpeed = "{0} Kbps" -f [math]::Round($nic.Speed / 1Kb, 2)
        }
    }

    # Build NIC info string
    "{0} (MAC: {1}, Speed: {2}, Type: {3})" -f $nic.Name, $nic.MACAddress, $nicSpeed, $adapterType
}

# Output system info
[PSCustomObject]@{
    Hostname        = $env:COMPUTERNAME
    Manufacturer    = $ComputerSystem.Manufacturer
    Model           = $ComputerSystem.Model
    SerialNumber    = $BIOS.SerialNumber
    CPU             = "{0} ({1} Cores)" -f $Processor.Name, $Processor.NumberOfCores
    RAM             = $RAMSummary
    GPU             = $GPUInfo -join "; "
    Disks           = $StorageInfo -join "`n"
    InstalledDisks  = $InstalledDisks -join "`n"
    NICs            = $NICDetails -join "`n"
    ConnectedSSID   = $WiFiSummary
} | Format-List



# End of script
# This script retrieves and formats system information including CPU, RAM, GPU, storage, and network interfaces.