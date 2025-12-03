# AddCurrentDirToUserPath.ps1
# This script adds the current directory to the user's PATH variable permanently.

# Get the current directory
$currentDir = (Get-Location).Path

# Get the existing user PATH
$existingPath = [Environment]::GetEnvironmentVariable("Path", "User")

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
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")

    Write-Output "Added $currentDir to the user's PATH."
    Write-Output "You may need to restart your terminal for changes to take effect."
}
