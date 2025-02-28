# Define URLs and paths
$rdmsUrl = "https://aka.ms/rdmultimediasvc"  # Microsoft link for latest RDMS version
$downloadPath = "$env:TEMP\RemoteDesktopMultimediaService.msi"
$markerPath = "C:\ProgramData\Microsoft\Windows\RDMS_Installed.txt"

Write-Output "Downloading Remote Desktop Multimedia Service from Microsoft..."
Invoke-WebRequest -Uri $rdmsUrl -OutFile $downloadPath

# Install RD Multimedia Service
if (Test-Path $downloadPath) {
    Write-Output "Installing Remote Desktop Multimedia Service..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$downloadPath`" /quiet /norestart" -Wait -NoNewWindow

    # Create a marker file after successful execution
    "RD Multimedia Service Installed Successfully on $(Get-Date)" | Out-File -FilePath $markerPath -Encoding utf8 -Force
    Write-Output "Marker file created at $markerPath"

    # Cleanup downloaded installer
    Write-Output "Cleaning up temporary files..."
    Remove-Item -Path $downloadPath -Force
    Write-Output "Cleanup complete."
} else {
    Write-Output "Error: RD Multimedia Service download failed!"
}
