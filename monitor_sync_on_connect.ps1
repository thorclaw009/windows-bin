Param(
    [string]$SyncScript = "$PSScriptRoot\sync_machines.ps1",
    [int]$IntervalSeconds = 15
)

if (-not (Test-Path $SyncScript)) {
    Write-Warning "Sync script not found at $SyncScript"
}

# Transcript/log file in the same directory as the script
$transcriptPath = Join-Path $PSScriptRoot 'monitor_sync_transcript.txt'
try {
    Start-Transcript -Path $transcriptPath -Append -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Start-Transcript failed: $_"
}

$prevOnline = $false
Write-Host "Monitoring connectivity; will run $SyncScript when Internet becomes available..."

try {
    while ($true) {
        try {
            $online = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
        } catch {
            $online = $false
        }

        if ($online -and -not $prevOnline) {
            Write-Host "$(Get-Date -Format o) - Internet available; executing sync script..."
            try {
                & $SyncScript
            } catch {
                Write-Host "$(Get-Date -Format o) - Sync script error: $_"
            }
        }

        $prevOnline = $online
        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    try {
        Stop-Transcript -ErrorAction SilentlyContinue
    } catch {}
}
