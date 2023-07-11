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

function Split-ZipFile {
    param(
        [Parameter(Mandatory=$true)][string] $file,
        [Parameter(Mandatory=$true)][long] $size
    )

    Add-Type -TypeDefinition @"
        public class SizeSplitStream : System.IO.Stream {
            private string _path;
            private long _size;
            private int _part;
            private System.IO.Stream _stream;

            public SizeSplitStream(string path, long size) {
                _path = path;
                _size = size;
                _part = 0;
                _stream = CreateStream();
            }

            private System.IO.Stream CreateStream() {
                string partName = GetPartName();
                return new System.IO.FileStream(partName, System.IO.FileMode.CreateNew, System.IO.FileAccess.Write, System.IO.FileShare.None);
            }

            private string GetPartName() {
                string directory = System.IO.Path.GetDirectoryName(_path);
                string fileName = System.IO.Path.GetFileNameWithoutExtension(_path);
                string extension = System.IO.Path.GetExtension(_path);
                return System.IO.Path.Combine(directory, string.Format("{0}_{1:D4}{2}", fileName, _part, extension));
            }

            public override bool CanRead { get { return false; } }
            public override bool CanSeek { get { return false; } }
            public override bool CanWrite { get { return true; } }
            public override void Flush() { _stream.Flush(); }
            public override long Length { get { throw new System.NotSupportedException(); } }
            public override long Position {
                get { throw new System.NotSupportedException(); }
                set { throw new System.NotSupportedException(); }
            }
            public override int Read(byte[] buffer, int offset, int count) { throw new System.NotSupportedException(); }
            public override long Seek(long offset, System.IO.SeekOrigin origin) { throw new System.NotSupportedException(); }
            public override void SetLength(long value) { throw new System.NotSupportedException(); }

            public override void Write(byte[] buffer, int offset, int count) {
                if (_stream.Position + count > _size) {
                    count = (int)(_size - _stream.Position);
                    _stream.Write(buffer, offset, count);
                    _stream.Dispose();
                    _stream = CreateStream();
                    offset += count;
                    count = buffer.Length - offset;
                }
                _stream.Write(buffer, offset, count);
            }

            protected override void Dispose(bool disposing) {
                _stream.Dispose();
                base.Dispose(disposing);
            }
        }
"@

    $sourceStream = New-Object System.IO.FileStream($file, [System.IO.FileMode]::Open)
    $destinationStream = New-Object SizeSplitStream -ArgumentList @($file, $size)
    $sourceStream.CopyTo($destinationStream)
    $sourceStream.Dispose()
    $destinationStream.Dispose()
    Remove-Item $file
}

if ($zipFileSize -gt $zipFileSizeLimit) {
    Split-ZipFile -file $zipFile -size $zipFileSizeLimit
    $zipFileParts = Get-ChildItem -Path $destinationDirectory -Filter "$zipFileName*"
    foreach ($zipFilePart in $zipFileParts) {
        Write-Host "INFO: ZIP FILE PART CREATED. TO DOWNLOAD, PLEASE RUN: 'getfile path-$($zipFilePart.FullName)'. PLEASE DELETE FILE AFTER DOWNLOADING."
    }
} else {
    Write-Host "SUCCESS: ZIP FILE CREATED. TO DOWNLOAD, PLEASE RUN: 'getfile path-$zipFile'. PLEASE DELETE FILE AFTER DOWNLOADING."
}
exit
