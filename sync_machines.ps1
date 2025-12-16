param(
    [string]$OptDir = ""
)



if ($OptDir -eq "") {
    $OptDirOptions = @(
        "D:\Opt",
        "C:\Opt"
    )

    foreach ($dir in $OptDirOptions) {
        if (Test-Path -LiteralPath $dir) {
            $OptDir = $dir
            break
        }
    }   
}

if ($OptDir -eq "") {
    Write-Error "No valid Opt directory found in options: $($OptDirOptions -join ', ')"
    exit 1
}

$SyncDirs = @(
    "D:\Opt\windows-bin",
    "D:\Scratch\numbers"
)

function Run-Command {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [Parameter(Mandatory=$false)]
        [string[]]$Args
    )

    Write-Host "Running: $Command $($Args -join ' ')" -ForegroundColor Cyan
    & $Command @Args
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Error "Command failed: git $($Args -join ' ') (exit code $code)"
        exit $code
    }
}

function SyncDirectory {
    param (
        [string]$Directory,
        [string]$ScriptPath = ".\do_git_pull.ps1"
    )

    Write-Host "Syncing directory: $Directory"
    # Add your sync logic here, e.g., robocopy, rsync, etc.
    # Resolve and enter the target directory
    $resolved = Resolve-Path -LiteralPath $Directory -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-Error "Directory '$Directory' not found."
        exit 1
    }

    try {
        Set-Location $resolved
    } catch {
        Write-Error "Failed to enter directory '$Directory': $_"
        exit 2
    }

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-Error "Script '$ScriptPath' not found."
        exit 3
    }

    # Execute the script in the current directory
    try {
        Run-Command -Command "powershell.exe" -Args @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath, "-Merge" )
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Script '$ScriptPath' failed with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    } catch {
        Write-Error "Error running {$ScriptPath}: $_"
        exit 4
    }
}


foreach ($dir in $SyncDirs) {
    SyncDirectory -Directory $dir -ScriptPath "${OptDir}\windows-bin\do_git_pull.ps1"
}

