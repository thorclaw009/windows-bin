# Run in PowerShell as Administrator
Install-Module PSWindowsUpdate -Force

# Import the module
Import-Module PSWindowsUpdate

# Check for updates
Get-WindowsUpdate

# Install updates
Install-WindowsUpdate -AcceptAll -AutoReboot
