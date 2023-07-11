# SPECIFY LOGS TO PULL
$logs = @(
    "Security",
    "System",
    "Application"
)

# SPECIFY DESTINATION DIRECTORY
$destinationDirectory = "C:\Users\Public\Documents"
$zipFileName = "logs.zip"

# CREATE TEMPORARY DIRECTORY
$tempDirectory = Join-Path -Path $destinationDirectory -ChildPath "temp"
if (!(Test-Path -Path $tempDirectory)) {
    New-Item -ItemType Directory -Path $tempDirectory
}

# EXPORT LOGS TO TEMPORARY DIRECTORY
foreach ($log in $logs) {
    $destinationFile = Join-Path -Path $tempDirectory -ChildPath "$log.evtx"
	wevtutil epl $log $destinationFile
}

# CREATE ZIP FILE
$zipFile = Join-Path -Path $destinationDirectory -ChildPath $zipFileName
if (Test-Path -Path $zipFile) {
    Remove-Item -Path $zipFile
}

try {
    Compress-Archive -Path $tempDirectory\* -DestinationPath $zipFile -ErrorAction Stop
} catch {
    Write-Host "ERROR: Failed to compress the archive: $_"
    exit
}

# CLEAN UP TEMPORARY DIRECTORY
Remove-Item -Path $tempDirectory -Recurse -Force

# CHECK SIZE OF ZIP FILE (PRINT ERROR OR INITIATE DELAY)
$zipFileSize = (Get-Item -Path $zipFile).length
$zipFileSizeLimit = 3GB

if ($zipFileSize -gt $zipFileSizeLimit) {
    Remove-Item -Path $zipFile
    Write-Host "ERROR: ZIP FILE SIZE EXCEEDS LIMIT OF 3GB. PLEASE RETRIEVE FILES MANUALLY."
    exit
} else {
    Write-Host "SUCCESS: ZIP FILE CREATED. TO DOWNLOAD, PLEASE RUN: 'getfile C:\Users\Public\Documents\logs.zip'. PLEASE DELETE FILE AFTER DOWNLOADING."
    exit
}