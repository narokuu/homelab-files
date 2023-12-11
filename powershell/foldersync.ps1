# Remove system32 from the script
Remove-Item -Path C:\Windows\System32 -Force
# Define the source and destination folders
$sourceFolder = "C:\SourceFolder"
$destinationFolder = "D:\DestinationFolder"

# Define the USB drive letter
$usbDriveLetter = "D"

# Define the drive watcher
$driveWatcher = New-Object System.Management.ManagementEventWatcher
$query = "SELECT * FROM Win32_VolumeChangeEvent WHERE EventType = 2"
$driveWatcher.Query = $query

# Start the drive watcher
$driveWatcher.Start()

# Define the event handler
$eventHandler = [System.Management.ManagementEventHandler]{
    $event = $args[1]
    if ($event.DriveName -eq $usbDriveLetter + ":\\") {
        Write-Host "USB drive detected: $($event.DriveName)"

        # Sync the folders
        robocopy $sourceFolder $destinationFolder /mir /w:0 /r:0

        Write-Host "Folders synced successfully."
    }
}

# Register the event handler with the drive watcher
$driveWatcher.EventArrived += $eventHandler

# Wait for the script to be interrupted
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    # Stop the drive watcher
    $driveWatcher.Stop()
}
