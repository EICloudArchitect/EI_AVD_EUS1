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

# **Ensure the Temp Disk (D:) is available before proceeding**
if (!(Test-Path "D:\")) {
    Write-Output "ERROR: Temp Disk (D:) not found! Pagefile setup aborted."
    exit 1
}

# **Initialize Temp Disk if needed**
$TempDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -or $_.OperationalStatus -eq 'Offline' }
if ($TempDisk) {
    $TempDisk | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false
    Write-Output "Temporary disk initialized and formatted."
} else {
    Write-Output "No uninitialized temporary disk found."
}

# **Ensure Windows is NOT auto-managing the Pagefile**
Set-CimInstance -Query "SELECT * FROM Win32_ComputerSystem" -Property @{AutomaticManagedPagefile=$false}

# **Remove any existing Page File on C:**
$ExistingCPageFile = Get-CimInstance -ClassName Win32_PageFileSetting | Where-Object { $_.Name -eq "C:\pagefile.sys" }
if ($ExistingCPageFile) {
    Write-Output "Removing existing pagefile at C:\pagefile.sys..."
    Remove-CimInstance -InputObject $ExistingCPageFile
}

# **Remove any existing Page File on D:**
$ExistingDPageFile = Get-CimInstance -ClassName Win32_PageFileSetting | Where-Object { $_.Name -eq "D:\pagefile.sys" }
if ($ExistingDPageFile) {
    Write-Output "Removing previous pagefile at D:\pagefile.sys..."
    Remove-CimInstance -InputObject $ExistingDPageFile
}

# **Explicitly Create the New Pagefile on D:**
Write-Output "Creating new pagefile on D:\pagefile.sys..."
New-CimInstance -ClassName Win32_PageFileSetting -Property @{
    Name = "D:\pagefile.sys"
    InitialSize = 65536
    MaximumSize = 65536
} -Namespace "root\cimv2"

# **Verify Pagefile Creation**
Start-Sleep -Seconds 5
if (Test-Path "D:\pagefile.sys") {
    Write-Output "Pagefile successfully created on D:\pagefile.sys"
} else {
    Write-Output "ERROR: Pagefile was NOT created on D:\!"
    exit 1
}

# **Create marker file on TEMP disk (D:) to prevent re-running until next deallocation**
New-Item -Path $MarkerFile -ItemType File -Force | Out-Null
Write-Output "Marker file created at $MarkerFile to prevent re-running until next deallocation."

# **Force a Restart to Apply Pagefile**
Write-Output "Forcing system reboot to apply pagefile settings..."
shutdown.exe /r /t 5 /f
