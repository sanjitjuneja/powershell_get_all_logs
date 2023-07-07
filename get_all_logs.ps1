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
$jobs = @()
foreach ($log in $logs) {
    $destinationFile = Join-Path -Path $tempDirectory -ChildPath "$log.csv"
    $jobs += Start-Job -ScriptBlock { 
        Param($log, $destinationFile)
        Get-WinEvent -LogName $log -MaxEvents 1000 | Export-Csv -Path $destinationFile -NoTypeInformation -Force 
    } -ArgumentList $log, $destinationFile
}

# Wait for all jobs to complete and handle errors
foreach ($job in $jobs) {
    $result = Receive-Job -Job $job -Wait -ErrorAction SilentlyContinue
    if ($job.State -eq 'Failed') {
        Write-Host ("Job {0} failed with the following error: {1}" -f $job.Name, $job.JobStateInfo.Reason)
        Remove-Job -Job $job
    } else {
        Remove-Job -Job $job
    }
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
    Write-Host "SUCCESS: ZIP FILE CREATED. TO DOWNLOAD, PLEASE RUN: 'getfile path-C:\Users\Public\Documents\logs.zip'. PLEASE DELETE FILE AFTER DOWNLOADING."
    exit
}
