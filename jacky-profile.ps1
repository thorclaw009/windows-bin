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

# Setup VSDev Vars
Write-Host "Call Enter-VSDevShell to load Visual Studio 2026 Community variables"

function Enter-VSDevShell {
    $vcvars = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"

    cmd /c "`"$vcvars`" && set" |
    ForEach-Object {
        if ($_ -match '^(.*?)=(.*)$') {
            Set-Item "Env:$($matches[1])" $matches[2]
        }
    }
}
