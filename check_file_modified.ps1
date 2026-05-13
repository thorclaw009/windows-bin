<#
.SYNOPSIS
Checks if a file has been modified since the last time the script was run, and executes one or more commands if it has.

.DESCRIPTION
This script records the last run time in a hidden state file within the same directory as the target file. 
It compares the target file's LastWriteTime with the stored time. If the file is newer, it changes the 
current directory to the target file's directory and executes the specified commands in sequence.

.PARAMETER FileToCheck
The path to the file you want to monitor for changes.

.PARAMETER CommandsToRun
An array of script blocks to execute if the file has been modified. 
Defaults to executing do_git_push.ps1 with -Merge in the script's directory.
#>
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$FileToCheck,

    [scriptblock[]]$CommandsToRun = @(
        { & "$PSScriptRoot\do_git_push.ps1" -Merge }
    )
)

$fileItem = Get-Item -LiteralPath $FileToCheck

# Create a unique state file name based on the file being checked
$safeFileName = $fileItem.Name -replace '[^a-zA-Z0-9_\-]', '_'
$stateFile = Join-Path -Path $fileItem.DirectoryName -ChildPath ".last_run_$safeFileName"

$lastRunTime = [datetime]::MinValue
if (Test-Path -LiteralPath $stateFile) {
    try {
        $lastRunTime = [datetime](Get-Content -LiteralPath $stateFile -ErrorAction Stop)
    } catch {
        Write-Warning "Could not read previous run time from state file. Proceeding as if first run."
    }
}

if ($fileItem.LastWriteTime -gt $lastRunTime) {
    Write-Host "File '$FileToCheck' has been modified since last check. Executing commands..."
    
    # Change to the directory where the target file is located
    Push-Location -LiteralPath $fileItem.DirectoryName
    try {
        foreach ($command in $CommandsToRun) {
            Write-Host "Running: $command"
            & $command
            $executionSuccess = $?
            
            if ($executionSuccess) {
                Write-Host "Command executed successfully."
            } else {
                Write-Warning "Command execution reported an error."
            }
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "File '$FileToCheck' has not been modified since last check. No action taken."
}

# Update the last run time to current time
try {
    [datetime]::Now.ToString("o") | Set-Content -LiteralPath $stateFile -ErrorAction Stop
} catch {
    Write-Error "Failed to save the state to '$stateFile'."
}
