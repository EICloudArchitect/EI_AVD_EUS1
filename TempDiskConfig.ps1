# Define paths
$MarkerFile = "D:\PagefileConfigured.txt"
$LogFile = "C:\Temp\Setup-TempDisk.log"

# Function for logging
function Write-Log {
    param ([string]$Message)

    # Ensure C:\Temp exists
    if (!(Test-Path "C:\Temp")) {
        New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
    }

    # Write log entry
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Output $Message
}

Write-Log "========================= Script Started ========================="

# **Check for Marker File - If Exists, Still Check If Deallocation Happened**
$Uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$MinutesUp = (New-TimeSpan -Start $Uptime -End (Get-Date)).TotalMinutes

if ((Test-Path $MarkerFile) -and ($MinutesUp -gt 5)) {
    Write-Log "Marker file exists, and uptime is greater than 5 minutes. Skipping script execution."
    exit 0  # **Ensures script stops here and does NOT continue.**
}

Write-Log "No marker file found OR system booted after deallocation. Running configuration."

# **Ensure Temp Disk (D:) is available before proceeding**
$TempDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -or $_.OperationalStatus -eq 'Offline' }
if ($TempDisk) {
    try {
        $TempDisk | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false
        Write-Log "Temporary disk initialized and formatted."
    } catch {
        Write-Log "ERROR: Failed to initialize disk: $_"
    }
} else {
    Write-Log "No uninitialized temporary disk found or already online."
}

# **Ensure Windows is NOT auto-managing the Pagefile**
try {
    Set-CimInstance -Query "SELECT * FROM Win32_ComputerSystem" -Property @{AutomaticManagedPagefile=$false}
    Write-Log "Disabled automatic pagefile management."
} catch {
    Write-Log "ERROR: Could not disable auto-managed pagefile: $_"
}

# **Remove any existing Page File on C:**
$ExistingCPageFile = Get-CimInstance -ClassName Win32_PageFileSetting | Where-Object { $_.Name -eq "C:\pagefile.sys" }
if ($ExistingCPageFile) {
    try {
        Remove-CimInstance -InputObject $ExistingCPageFile
        Write-Log "Removed existing pagefile at C:\pagefile.sys."
    } catch {
        Write-Log "ERROR: Failed to remove C:\ pagefile: $_"
    }
}

# **Remove any existing Page File on D:**
$ExistingDPageFile = Get-CimInstance -ClassName Win32_PageFileSetting | Where-Object { $_.Name -eq "D:\pagefile.sys" }
if ($ExistingDPageFile) {
    try {
        Remove-CimInstance -InputObject $ExistingDPageFile
        Write-Log "Removed previous pagefile at D:\pagefile.sys."
    } catch {
        Write-Log "ERROR: Failed to remove D:\ pagefile: $_"
    }
}

# **Create a New Pagefile on D:**
try {
    New-CimInstance -ClassName Win32_PageFileSetting -Property @{
        Name = "D:\pagefile.sys"
        InitialSize = [UInt32]65536
        MaximumSize = [UInt32]65536
    } -Namespace "root\cimv2"
    Write-Log "Successfully created pagefile on D:\pagefile.sys."
} catch {
    Write-Log "ERROR: Failed to create pagefile on D:\ $_"
}

# **Ensure Pagefile.sys File is Created**
if (Test-Path "D:\pagefile.sys") {
    Write-Log "Pagefile successfully created on D:\pagefile.sys."
} else {
    Write-Log "ERROR: Pagefile was NOT created!"
}

# **Create the Marker File so the script doesn't run again on reboot**
try {
    New-Item -Path $MarkerFile -ItemType File -Force | Out-Null
    Write-Log "Marker file created at $MarkerFile."
} catch {
    Write-Log "ERROR: Failed to create marker file: $_"
}

# **Ensure a Reboot Happens After a Deallocation Event**
if ($MinutesUp -lt 5) {
    Write-Log "System booted after a deallocation event. Forcing reboot to finalize pagefile setup..."
    Restart-Computer -Force
} else {
    Write-Log "System has been running longer than 5 minutes. No reboot required."
}

Write-Log "========================= Script Completed ========================="
