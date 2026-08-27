# AddCurrentDirToUserPath.ps1
# This script adds the current directory to the user's PATH variable permanently.

param(
    [ValidateSet("User","Machine")]
    [string]$Role = "Machine"
)

# Map Role to EnvironmentVariableTarget
$target = if ($Role -eq "Machine") { [System.EnvironmentVariableTarget]::Machine } else { [System.EnvironmentVariableTarget]::User }

# If System and not elevated, warn and exit
if ($target -eq [System.EnvironmentVariableTarget]::Machine) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Output "Setting the System/Machine PATH requires administrator privileges. Run PowerShell as Administrator."
        exit 1
    }
}


# Get the current directory
$currentDir = (Get-Location).Path

# Get the existing user PATH
$existingPath = [Environment]::GetEnvironmentVariable("Path", $target)

# Check if current directory is already in PATH
if ($existingPath -split ";" -contains $currentDir) {
    Write-Output "The current directory is already in the PATH."
} else {
    # Append current directory to PATH
    $newPath = if ([string]::IsNullOrEmpty($existingPath)) {
        $currentDir
    } else {
        "$existingPath;$currentDir"
    }

    # Set the new PATH for the user (persistent)
    [Environment]::SetEnvironmentVariable("Path", $newPath, $target)

    Write-Output "Added $currentDir to the $target's PATH."
    Write-Output "You may need to restart your terminal for changes to take effect."
}
