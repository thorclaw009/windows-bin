<#
.SYNOPSIS
Commits modified tracked files and pushes to the remote repository if the local branch is ahead.

.DESCRIPTION
This script first checks if there are any modified tracked files in the specified directory. 
If there are, it executes a 'git commit -a -m Message' (defaults to "auto commit").
Then it checks if the local repository is ahead of the specified remote ("origin" by default). 
If it is, it executes a 'git push' (assuming the "executes a git commit" in the prompt was a typo for pushing commits).

.PARAMETER Directory
The directory of the git repository. Defaults to the current directory (".").

.PARAMETER Message
The Message to use for the auto-commit. Defaults to "auto commit".

.PARAMETER Remote
The name of the remote repository. Defaults to "origin".
#>
param (
    [string]$Directory = ".",
    [string]$Message = "auto commit",
    [string]$Remote = "origin"
)

# Resolve the directory path and switch to it
$targetDir = Resolve-Path $Directory
Push-Location -LiteralPath $targetDir

try {
    # 1. Check for modified tracked files
    # 'git status -uno --porcelain' lists changed tracked files. If empty, no tracked files are changed.
    $changes = git status -uno --porcelain
    
    if ($changes) {
        Write-Host "Found modified tracked files. Committing with Message: '$Message'"
        git commit -a -m $Message
    }
    else {
        Write-Host "No modified tracked files found. Skipping commit."
    }

    # 2. Check if ahead of remote
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($currentBranch)) {
        Write-Warning "Could not determine current branch. Is this a valid git repository with at least one commit?"
        return
    }

    # Check how many commits we are ahead of the remote
    $aheadOutput = git rev-list --count "${Remote}/${currentBranch}..HEAD" 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        $aheadCount = [int]$aheadOutput
        if ($aheadCount -gt 0) {
            Write-Host "Local repository is ahead of ${Remote} by ${aheadCount} commit(s). Executing Push-Git-Local.ps1..."
            & "$PSScriptRoot\Push-Git-Local.ps1" -Remote $Remote -Merge
        }
        else {
            Write-Host "Local repository is up-to-date with ${Remote}. No push needed."
        }
    }
    else {
        # If rev-list fails, it's likely because the remote tracking branch doesn't exist yet.
        Write-Host "Remote tracking branch '${Remote}/${currentBranch}' not found. Assuming we need to push. Executing Push-Git-Local.ps1..."
        & "$PSScriptRoot\Push-Git-Local.ps1" -Remote $Remote -Merge
        finally {
            Pop-Location
        }
    }
}
finally {
    Pop-Location
}

