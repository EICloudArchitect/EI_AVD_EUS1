# Define paths
$LocalScriptPath = "C:\Scripts\Setup-TempDisk.ps1"
$MarkerFile = "D:\PagefileConfigured.txt"   # Store marker file on TEMP disk (D:)

# Ensure Scripts folder exists
if (!(Test-Path "C:\Scripts")) {
    New-Item -Path "C:\Scripts" -ItemType Directory -Force
}

# If marker file exists, the script has already run after last deallocation → EXIT
if (Test-Path $MarkerFile) {
    Write-Output "Pagefile was already configured after last deallocation. Skipping execution."
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

# **Create marker file on TEMP disk (D:) to prevent re-running until next deallocation**
New-Item -Path $MarkerFile -ItemType File -Force | Out-Null
Write-Output "Marker file created at $MarkerFile to prevent re-running until next deallocation."

# **Force a Restart ONLY ONCE per deallocation**
Write-Output "Forcing reboot to apply pagefile settings..."
Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 5 /f" -NoNewWindow -Wait
