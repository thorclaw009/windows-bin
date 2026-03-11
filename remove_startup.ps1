# Remove app from Startup (Registry + Startup folder)

param(
    [string]$AppName,   # Name of the app (registry key or shortcut name)
    [string]$Shortcut   # Optional: exact shortcut filename if in Startup folder
)

# --- Remove from Registry (Current User) ---
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Get-ItemProperty -Path $regPath -Name $AppName -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $regPath -Name $AppName
    Write-Output "Removed $AppName from registry startup."
} else {
    Write-Output "$AppName not found in registry startup."
}

# --- Remove from Startup Folder ---
$startupFolder = [Environment]::GetFolderPath("Startup")
if ($Shortcut) {
    $shortcutPath = Join-Path $startupFolder $Shortcut
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-Output "Removed shortcut $Shortcut from Startup folder."
    } else {
        Write-Output "Shortcut $Shortcut not found in Startup folder."
    }
} else {
    Write-Output "No shortcut specified. Skipping Startup folder check."
}
