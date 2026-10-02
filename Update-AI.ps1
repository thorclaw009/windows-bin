# update-ai-tools.ps1
# Checks for Unsloth, Unsloth Studio, Claude, Codex, Cursor and updates them

function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Update-PipPackage {
    param([string]$PackageName)
    if (pip show $PackageName -ErrorAction SilentlyContinue) {
        Write-Host "$PackageName found via pip. Updating..."
        pip install --upgrade $PackageName
    } else {
        Write-Host "$PackageName not found via pip."
    }
}

function Update-NpmPackage {
    param([string]$PackageName)
    if (npm list -g $PackageName -ErrorAction SilentlyContinue) {
        Write-Host "$PackageName found via npm. Updating..."
        npm install -g $PackageName
    } else {
        Write-Host "$PackageName not found via npm."
    }
}

function Update-WingetPackage {
    param([string]$PackageName)
    $pkg = winget list | Select-String $PackageName
    if ($pkg) {
        Write-Host "$PackageName found via winget. Updating..."
        winget upgrade --id $PackageName --silent
    } else {
        Write-Host "$PackageName not found via winget."
    }
}

Write-Host "Checking AI tools..."

# Unsloth (Python package)
#Update-PipPackage -PackageName "unsloth"
if (Test-Command "unsloth") {
    Write-Host "Unsloth found. Updating..."
    irm https://unsloth.ai/install.ps1 | iex
} else {
    Write-Host "Unsloth not found."
}

# Unsloth Studio (Python package)
#Update-PipPackage -PackageName "unsloth-studio"

# Claude (npm package, e.g. claude-cli)
#Update-NpmPackage -PackageName "claude-cli"
if (Test-Command "claude") {
    Write-Host "Claude found. Updating..."
    irm https://claude.ai/install.ps1 | iex
} else {
    Write-Host "Claude not found."
}

# Codex (try winget or npm)
if (Test-Command "codex") {
    Write-Host "Codex found. Updating..."
    Update-WingetPackage -PackageName "OpenAI.Codex"
    Update-NpmPackage -PackageName "codex"
} else {
    Write-Host "Codex not found."
}

if (Test-Command "cursor") {
    Write-Host "Cursor found. Updating..."
    Update-WingetPackage -PackageName "Cursor"
} else {
    Write-Host "Cursor not found."
}

if (Test-Command "cursor") {
        Write-Host "Cursor found. Updating..."
        Update-WingetPackage -PackageName "Cursor"
    } else {
        Write-Host "Cursor not found."
    }

Write-Host "Update check complete."
