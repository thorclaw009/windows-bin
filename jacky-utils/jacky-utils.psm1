function Import-JackyProfile {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ParameterSetName = 'Path', Position = 0)]
        [string]$Path = "d:\Opt\windows-bin\jacky-profile.ps1",

        [Parameter(ParameterSetName = 'ScriptBlock', Position = 0)]
        [scriptblock]$ScriptBlock
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Path' {
            if (Test-Path $Path) {
                . $Path
            }
            else {
                Write-Error "Profile script not found at $Path"
            }
        }
        'ScriptBlock' {
            . $ScriptBlock
        }
    }
}

function Add-IfMissing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$File,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$String
    )

    if (-not (Test-Path $File)) {
        Write-Error "File not found: $File"
        return
    }

    # Read file content
    $content = Get-Content $File

    # Normalize whitespace and compare case-insensitive
    $exists = $content | ForEach-Object { $_.Trim() } | Where-Object { $_ -ieq $String }

    if (-not $exists) {
        Add-Content -Path $File -Value $String
        Write-Host "Added setup line to $File"
    }
    else {
        Write-Host "Setup line already exists in $File"
    }
}

