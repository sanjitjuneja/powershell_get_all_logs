# SPECIFY FILES TO PULL
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

# COPY FILES TO TEMPORARY DIRECTORY
foreach ($log in $logs) {
	$destinationFile = Join-Path -Path $tempDirectory -ChildPath "$log.csv"
	Get-WinEvent -LogName $log -MaxEvents 1000 | Export-Csv -Path $destinationFile -NoTypeInformation -Force
}

# WAIT FOR ALL WRITES TO FINISH
Start-Sleep -Seconds 15

# CREATE ZIP FILE
$zipFile = Join-Path -Path $destinationDirectory -ChildPath $zipFileName
if (Test-Path -Path $zipFile) {
	Remove-Item -Path $zipFile
}
Compress-Archive -Path $tempDirectory -DestinationPath $zipFile

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
	Write-Host "SUCCESS: ZIP FILE CREATED. TO DOWNLOAD, PLEASE RUN: 'getfile path-C:\Users\Public\Documents\logs.zip'. PLEASE DELETE FILE AFTER DOWNLOAD."
	exit
}
