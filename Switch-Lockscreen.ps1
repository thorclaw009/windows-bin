<#
.SYNOPSIS
    Enables or disables the Windows 11 lock screen.

.DESCRIPTION
    Disable:
        Creates the NoLockScreen policy value and sets it to 1.

    Enable:
        Removes the NoLockScreen policy value and deletes the
        Personalization key if it becomes empty.

.EXAMPLE
    .\Toggle-LockScreen.ps1 -Action Disable

.EXAMPLE
    .\Toggle-LockScreen.ps1 -Action Enable
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet("Enable", "Disable")]
    [string]$Action
)

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
$ValueName = "NoLockScreen"

# Verify script is running elevated
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

switch ($Action) {

    "Disable" {
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }

        New-ItemProperty `
            -Path $RegPath `
            -Name $ValueName `
            -PropertyType DWord `
            -Value 1 `
            -Force | Out-Null

        Write-Host "Lock screen disabled." -ForegroundColor Green
    }

    "Enable" {
        if (Test-Path $RegPath) {

            Remove-ItemProperty `
                -Path $RegPath `
                -Name $ValueName `
                -ErrorAction SilentlyContinue

            # Remove Personalization key if empty
            $key = Get-Item $RegPath -ErrorAction SilentlyContinue

            if ($null -ne $key) {
                $subKeys = $key.GetSubKeyNames()
                $values = $key.GetValueNames()

                if ($subKeys.Count -eq 0 -and $values.Count -eq 0) {
                    Remove-Item $RegPath -Force
                }
            }
        }

        Write-Host "Lock screen enabled." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Sign out or restart Windows for the change to take effect." -ForegroundColor Yellow
