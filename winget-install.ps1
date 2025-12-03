Install-Module -Name Microsoft.WinGet.Client
Import-Module Microsoft.WinGet.Client

$GraphicApps = @("KDE.Krita","BlenderFoundation.Blender", "Inkscape.Inkscape")
$DevApps = @("Microsoft.VisualStudio.Community", "Microsoft.PowerShell", "Git.Git", "GitHub.cli", "GitHub.GitLFS", "Kitware.CMake", "JanDeDobbeleer.OhMyPosh", "Microsoft.VisualStudioCode")
$DevAppsPython=@("astral-sh.ruff", "astral-sh.uv", "astral-sh.ty" )
$DevAppsJS=@("OpenJS.NodeJS")
$AIApps = @("ggml.llamacpp")
$OfficeApps=@("KeePassXCTeam.KeePassXC", "TheDocumentFoundation.LibreOffice", "VideoLAN.VLC", "7zip.7zip", "SumatraPDF.SumatraPDF")
$NetworkApps=@("GlavSoft.TightVNC")
$BrowserApps=@("Google.Chrome", "Zen-Team.Zen-Browser")

Write-Host $Apps

function Invoke-AsAdministrator {
    [CmdletBinding(DefaultParameterSetName = 'String')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='String', Position=0)]
        [string]$Command,

        [Parameter(Mandatory=$true, ParameterSetName='ScriptBlock', Position=0)]
        [scriptblock]$ScriptBlock,

        [Parameter(ParameterSetName='ScriptBlock')]
        [object[]]$Args
    )

    switch ($PSCmdlet.ParameterSetName) {
        'String' {
            $argsList = "-NoProfile -Command $Command"
        }
        'ScriptBlock' {
            # Convert scriptblock to string and inject arguments
            $sbText = $ScriptBlock.ToString()
            $argString = ($Args | ForEach-Object { "'$_'" }) -join ' '
            $argsList = "-NoProfile -Command & { param($($Args | ForEach-Object { '$' + $_ })) $sbText } $argString"
        }
    }

    $process = Start-Process powershell -ArgumentList $argsList -Verb RunAs -PassThru
    $process.WaitForExit()
    return $process.ExitCode
}

foreach($app in $GraphicApps + $DevApps + $DevAppsPython + $DevAppsJS + $OfficeApps + $NetworkApps + $BrowserApps + $AIApps) {
    Write-Host "Installing $app"
    Invoke-AsAdministrator -Command "winget install --disable-interactivity --scope machine $app"
}
