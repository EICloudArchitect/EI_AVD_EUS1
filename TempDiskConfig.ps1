# Define paths
$LocalScriptPath = "C:\Scripts\Setup-TempDisk.ps1"

# Ensure Scripts folder exists
if (!(Test-Path "C:\Scripts")) {
    New-Item -Path "C:\Scripts" -ItemType Directory -Force
}


# Get system uptime in minutes
$Uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$MinutesUp = (New-TimeSpan -Start $Uptime -End (Get-Date)).TotalMinutes

Write-Output "System Uptime: $MinutesUp minutes"

# If system uptime is greater than 10 minutes, skip everything
if ($MinutesUp -gt 5) {
    Write-Output "VM was restarted recently, skipping pagefile setup."
    exit 0
}

Write-Output "VM has been fully powered on after deallocation. Setting up temp disk and pagefile..."

# Initialize Temp Disk if needed
$TempDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -or $_.OperationalStatus -eq 'Offline' }
if ($TempDisk) {
    $TempDisk | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false
    Write-Output "Temporary disk initialized and formatted."
} else {
    Write-Output "No uninitialized temporary disk found."
}

# Reset Page File (Disable automatic management)
Set-CimInstance -Query "SELECT * FROM Win32_ComputerSystem" -Property @{AutomaticManagedPagefile=$false}

# Remove any existing Page File
$C_Pagefile = Get-CimInstance -ClassName Win32_PageFileSetting | Where-Object { $_.Name -eq "C:\pagefile.sys" }
if ($C_Pagefile) {
    Remove-CimInstance -InputObject $C_Pagefile
    Write-Output "Removed existing Page File on C: drive."
}

# Set new Pagefile on Temp Disk (D:)
New-CimInstance -ClassName Win32_PageFileSetting -Property @{
    Name="D:\pagefile.sys"
    InitialSize=[UInt32]65536
    MaximumSize=[UInt32]65536
} -Namespace "root\cimv2"

Write-Output "Page file successfully created on D:\pagefile.sys"

# **Force a Restart Only If The System Has Been Running Less Than 5 Minutes**
Write-Output "Forcing reboot to apply pagefile settings..."
Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 5 /f" -NoNewWindow -Wait
