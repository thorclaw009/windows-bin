param(
	[switch] $DisableZig = $false,
	[switch] $DisableCAD = $false,
	[switch] $Intel = $false,
    [switch] $Nvidia = $false
)

#Install-Module -Name Microsoft.WinGet.Client
Update-Module -Name Microsoft.WinGet.Client
Import-Module Microsoft.WinGet.Client

$GraphicApps = @("KDE.Krita","BlenderFoundation.Blender", "Inkscape.Inkscape", "Gyan.FFmpeg")
$DevApps = @("Microsoft.VisualStudio.Community", "Microsoft.PowerShell", "Git.Git", "GitHub.cli", "GitHub.GitLFS", "Kitware.CMake", "JanDeDobbeleer.OhMyPosh", "Microsoft.VisualStudioCode")
$DevAppsPython=@("astral-sh.ruff", "astral-sh.uv", "astral-sh.ty" )
$DevAppsZig=@("zig.zig", "zigtools.zls")
$DevAppsJS=@("OpenJS.NodeJS", "Oven-sh.Bun")
$AIApps = @("ggml.llamacpp")
$OfficeApps=@("KeePassXCTeam.KeePassXC", "TheDocumentFoundation.LibreOffice", "7zip.7zip", "SumatraPDF.SumatraPDF")
#$UtilApps=@("RamenSoftware.Windhawk")
$NetworkApps=@("GlavSoft.TightVNC", "Tailscale.Tailscale")
$BrowserApps=@("Google.Chrome", "Zen-Team.Zen-Browser")
$CADApps=@("FreeCAD.FreeCAD", "KiCAD.KiCAD")
$MediaApps=@("OBSProject.OBSStudio",  "VideoLAN.VLC")
$IntelLicensingApps = @("Intel.OneAPI.BaseToolkit", "Intel.OneAPI.HPC.Toolkit", "Intel.OneAPI.DPCPP.Compatibility.Toolkit")
$NvidiaApps = @("Nvidia.CUDA", "Nvidia.PhysX")

function Invoke-AsAdministrator {
    [CmdletBinding(DefaultParameterSetName = 'String')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='String', Position=0)]
        [string]$Command,

        [Parameter(Mandatory=$true, ParameterSetName='ScriptBlock', Position=0)]
        [scriptblock]$ScriptBlock,

        [Parameter(ParameterSetName='ScriptBlock')]
        [object[]]$MyArgs
    )

    switch ($PSCmdlet.ParameterSetName) {
        'String' {
            $argsList = "-NoProfile -Command $Command"
        }
        'ScriptBlock' {
            # Convert scriptblock to string and inject arguments
            $sbText = $ScriptBlock.ToString()
            $argString = ($MyArgs | ForEach-Object { "'$_'" }) -join ' '
            $argsList = "-NoProfile -Command & { param($($MyArgs | ForEach-Object { '$' + $_ })) $sbText } $argString"
        }
    }

    $process = Start-Process powershell -ArgumentList $argsList -Verb RunAs -PassThru
    $process.WaitForExit()
    return $process.ExitCode
}

function Get-OneAPIDevices {
    <#
    .SYNOPSIS
        Enumerates oneAPI-compatible devices (CPU, GPU, etc.) on the system.

    .DESCRIPTION
        This function checks for Intel oneAPI runtimes and lists available devices.
        It uses SYCL (via libsycl.dll) if present, which is the programming model for oneAPI.

    .OUTPUTS
        A list of detected oneAPI devices with type and vendor.
    #>

    try {
        # Path to Intel oneAPI SYCL runtime DLL
        $syclDll = "C:\Program Files (x86)\Intel\oneAPI\compiler\latest\bin\libsycl.dll"

        if (-not (Test-Path $syclDll)) {
            Write-Output "Intel oneAPI SYCL runtime not found. Please install Intel oneAPI Base Toolkit."
            return
        }

        # Load SYCL interop
        $interop = Add-Type -MemberDefinition @"
using System;
using System.Runtime.InteropServices;

public class SyclInterop {
    [DllImport("libsycl.dll")]
    public static extern int syclDetectDevices();
}
"@ -Name "SyclInterop" -Namespace "OneAPI" -PassThru

        # Call detection (dummy example, actual SYCL interop requires C++/CLI bindings)
        $result = [OneAPI.SyclInterop]::syclDetectDevices()

        if ($result -eq 0) {
            Write-Output "No oneAPI devices detected."
        } else {
            Write-Output "OneAPI devices detected (CPU/GPU)."
        }
    }
    catch {
        Write-Output "Error: Unable to query oneAPI devices."
    }
}

function Test-CUDA-Installation {
    <#
    .SYNOPSIS
        Checks if NVIDIA CUDA is installed on the system.

    .DESCRIPTION
        This function verifies CUDA installation by:
        1. Checking for the CUDA environment variable.
        2. Looking for the CUDA toolkit directory.
        3. Checking if nvcc.exe (CUDA compiler) is available in PATH.

    .OUTPUTS
        Boolean (True if CUDA is installed, False otherwise)
    #>

    try {
        $cudaPath = $env:CUDA_PATH
        $nvcc = Get-Command nvcc.exe -ErrorAction SilentlyContinue

        if ($cudaPath -and (Test-Path $cudaPath)) {
            Write-Output "CUDA installation detected at $cudaPath"
            return $true
        }
        elseif ($nvcc) {
            Write-Output "CUDA compiler (nvcc.exe) detected in PATH."
            return $true
        }
        else {
            Write-Output "No CUDA installation detected."
            return $false
        }
    }
    catch {
        Write-Output "Error checking CUDA installation."
        return $false
    }
}

$allApps = $GraphicApps + $DevApps + $DevAppsPython + $DevAppsJS + $OfficeApps + $NetworkApps + $BrowserApps + $AIApps + $MediaApps

if (-not $DisableZig) {
	$allApps = $allApps + $DevAppsZig
}

if (-not $DisableCAD) {
	$allApps = $allApps + $CADApps
}

$openAPIDevices = Get-OneAPIDevices
if ($openAPIDevices -like "*OneAPI devices detected*") {
	$allApps = $allApps + $IntellicensingApps
}

if ($Nvidia) {
    Write-Host "Forced installation of Nvidia Apps"
	$allApps = $allApps + $NvidiaApps
} else {
    Write-Host "Testing installation of Nvidia Apps"
    $nvCheck = Test-CUDA-Installation
    Write-Host "Test-CUDA-Installation $nvCheck"
	if ($nvCheck) {
        $allApps = $allApps + $NvidiaApps
    }   
}

Write-Host "Installing the following apps: $allApps"

foreach($app in $allApps) {
    Write-Host "Installing $app"
    Invoke-AsAdministrator -Command "winget install --disable-interactivity --scope machine $app"
}
