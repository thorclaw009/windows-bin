. $PSScriptRoot\jacky-utils.ps1
Import-Module jacky-utils

# eza configurations
if (Test-Path Alias:\ls) {
    Remove-Item Alias:\ls
}

# Define a function for ls
function ll {
    eza --long --icons=auto --git
}

# Setup zoxide
Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
