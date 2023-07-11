# Ensure 7-Zip is installed
if (!(Test-Path "${Env:ProgramFiles}\7-Zip\7z.exe")) {
    Write-Host "7-Zip must be installed for this script to work."
    exit
}

# SPECIFY LOGS TO PULL
$logs = @(
    "Security",
    "System",
    "Application"
)

# SPECIFY DESTINATION DIRECTORY
$destinationDirectory = "C:\Users\Public\Documents"

# CREATE TEMPORARY DIRECTORY
$tempDirectory = Join-Path -Path $destinationDirectory -ChildPath "temp"
if (!(Test-Path -Path $tempDirectory)) {
    New-Item -ItemType Directory -Path $tempDirectory
}

# EXPORT LOGS TO TEMPORARY DIRECTORY
foreach ($log in $logs) {
    $destinationFile = Join-Path -Path $tempDirectory -ChildPath "$log.evtx"
    # Use wevtutil to export the log
    wevtutil epl $log $destinationFile
}

# Calculate total size of all log files
$totalSize = (Get-ChildItem $tempDirectory -Recurse | Measure-Object -Property Length -Sum).Sum

# DEFINE ZIP FILE NAME
$zipFileName = "logs.zip"
$zipFile = Join-Path -Path $destinationDirectory -ChildPath $zipFileName

if($totalSize -gt 3GB) {
    # If total size is greater than 3GB, use 7-Zip to split into chunks

    # Remove existing zip file if it exists
    if (Test-Path -Path $zipFile) {
        Remove-Item -Path $zipFile
    }

    try {
        & "${Env:ProgramFiles}\7-Zip\7z.exe" a -tzip -v3g $zipFile $tempDirectory\*
    } catch {
        Write-Host "ERROR: Failed to compress and split the archive: $_"
        exit
    }

    # Provide instructions for downloading zip file parts
    $zipFileParts = Get-ChildItem -Path $destinationDirectory -Filter "$zipFileName*"
    foreach ($zipFilePart in $zipFileParts) {
        Write-Host "INFO: ZIP FILE PART CREATED. TO DOWNLOAD, PLEASE RUN: 'getfile path-$($zipFilePart.FullName)'. PLEASE DELETE FILE AFTER DOWNLOADING."
    }
} else {
    # If total size is less than 3GB, use Compress-Archive

    # Remove existing zip file if it exists
    if (Test-Path -Path $zipFile) {
        Remove-Item -Path $zipFile
    }

    try {
        Compress-Archive -Path $tempDirectory\* -DestinationPath $zipFile -ErrorAction Stop
    } catch {
        Write-Host "ERROR: Failed to compress the archive: $_"
        exit
    }

    Write-Host "INFO: ZIP FILE CREATED. TO DOWNLOAD, PLEASE RUN: 'getfile path-$zipFile'. PLEASE DELETE FILE AFTER DOWNLOADING."
}

# CLEAN UP TEMPORARY DIRECTORY
Remove-Item -Path $tempDirectory -Recurse -Force

exit
