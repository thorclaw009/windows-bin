param(
    [switch]$Merge = $false
)


function Run-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Args
    )

    Write-Host "Running: git $($Args -join ' ')" -ForegroundColor Cyan
    & git @Args
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Error "Command failed: git $($Args -join ' ') (exit code $code)"
        exit $code
    }
}

$origBranch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($origBranch)) {
    Write-Error "Could not determine current branch."
    exit 1
}

# Optional: ensure git is available
& git --version > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "git not found in PATH."
    exit 1
}

Run-Git -Args @('checkout','main')
Run-Git -Args @('merge',$origBranch)
Run-Git -Args @('pull','github','main')
Run-Git -Args @('checkout',$origBranch)
if ($Merge) {
    Run-Git -Args @('merge','main')
    Write-Host 'Final merge completed successfully.' -ForegroundColor Green
}
else {
    Write-Host 'Final merge skipped (use -Merge to enable).' -ForegroundColor Yellow
}

Write-Host 'All git commands completed successfully.' -ForegroundColor Green
