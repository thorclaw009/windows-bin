param(
    [string]$ScratchDir = ""
)

if ($ScratchDir -eq "") {
    Write-Host "Searching for Scratch dir"
    $ScratchDirOptions = @("$HOME\Scratch", "D:\Scratch", "E:\Scratch")

    foreach ($dir in $ScratchDirOptions) {
        if (Test-Path -LiteralPath $dir) {
            $ScratchDir = $dir
            break
        }
    }   
}

if ($ScratchDir -eq "") {
    Write-Error "No valid Scratch directory found in options: $($ScratchDirOptions -join ', ')"
    exit 1
} else {
    Write-Host "ScratchDir set to $ScratchDir"
}

# List of files to monitor
$filesToMonitor = @(
    "$ScratchDir\numbers\others\jackybaltes_numbers.kdbx"
)

# Function to run git commands in the repo directory
function Run-GitCommands($repoPath, $changedFile) {
    Write-Host "Detected change in $changedFile" -ForegroundColor Green
    $commands = @(
        "git add $changedFile",
        "git commit -m 'Auto commit triggered by watcher for $changedFile'",
        "git checkout main",
        "git merge local",
        "git push github main",
        "git checkout local"
    )

    foreach ($cmd in $commands) {
        Write-Host "Running: $cmd" -ForegroundColor Cyan
        $process = Start-Process -FilePath "git" -ArgumentList $cmd `
            -WorkingDirectory $repoPath -NoNewWindow -RedirectStandardOutput Pipe -RedirectStandardError Pipe -PassThru
        $process.WaitForExit()
        $output = $process.StandardOutput.ReadToEnd()
        $errorRet  = $process.StandardError.ReadToEnd()
        if ($output) { Write-Host $output }
        if ($errorRet)  { Write-Host $error -ForegroundColor Red }
    }
}

# Create watchers for each file
$watchers = @()
foreach ($filePath in $filesToMonitor) {
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path   = (Split-Path $filePath)
    $watcher.Filter = (Split-Path $filePath -Leaf)
    $watcher.NotifyFilter = [System.IO.NotifyFilters]'LastWrite, FileName, Size'

    Register-ObjectEvent $watcher Changed -Action {
        $changedFile = $Event.SourceEventArgs.FullPath
        $repoPath    = Split-Path $changedFile -Parent   # infer repo from directory
        Run-GitCommands $repoPath $changedFile
    }

    $watcher.EnableRaisingEvents = $true
    $watchers += $watcher
    Write-Host "Monitoring $filePath for changes..."
}

Write-Host "Press Enter to exit."
Read-Host
