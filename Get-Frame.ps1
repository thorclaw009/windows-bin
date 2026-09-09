<#
.SYNOPSIS
    Extracts one frame from an MP4 video.

.DESCRIPTION
    Frame numbers are 1-based. For example, -FrameIndex 1 extracts the first
    frame and -FrameIndex -1 extracts the last frame. The extracted image is
    written to a PNG file by default, and the resulting path is written to the
    pipeline.

    Requires ffmpeg and ffprobe to be installed and available on PATH.

.EXAMPLE
    .\Get-Frame.ps1 -InputFile .\video.mp4 -FrameIndex 1

.EXAMPLE
    .\Get-Frame.ps1 -InputFile .\video.mp4 -FrameIndex -1 -OutputFile .\last.png

.EXAMPLE
    .\Get-Frame.ps1 -InputFile .\video.mp4 -FrameIndex -10 -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $InputFile,

    [Parameter(Mandatory = $true, Position = 1)]
    [long] $FrameIndex,

    [Parameter(Position = 2)]
    [string] $OutputFile,

    [switch] $Force
)

$ErrorActionPreference = 'Stop'

if ($FrameIndex -eq 0) {
    throw 'FrameIndex cannot be 0. Frame numbers start at 1; use negative numbers to count from the end.'
}

$ffmpeg = Get-Command ffmpeg -CommandType Application -ErrorAction SilentlyContinue
$ffprobe = Get-Command ffprobe -CommandType Application -ErrorAction SilentlyContinue

if ($null -eq $ffmpeg -or $null -eq $ffprobe) {
    throw 'Both ffmpeg and ffprobe must be installed and available on PATH.'
}

$inputItem = Get-Item -LiteralPath $InputFile -ErrorAction Stop
if ($inputItem.PSIsContainer) {
    throw "Input path is a directory, not a video file: '$InputFile'."
}

if ($inputItem.Extension -notmatch '^\.mp4$') {
    Write-Warning "Input file extension is '$($inputItem.Extension)'; continuing because ffmpeg will determine the format."
}

$inputPath = $inputItem.FullName

# Count decoded video frames so negative indices can be resolved accurately.
$probeArguments = @(
    '-v', 'error',
    '-count_frames',
    '-select_streams', 'v:0',
    '-show_entries', 'stream=nb_read_frames',
    '-of', 'default=noprint_wrappers=1:nokey=1',
    $inputPath
)

$frameCountText = (& $ffprobe.Source @probeArguments 2>$null | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($frameCountText)) {
    throw "Could not determine the number of video frames in '$inputPath'."
}

[long] $frameCount = 0
$parsed = [long]::TryParse(
    ([string] $frameCountText).Trim(),
    [Globalization.NumberStyles]::Integer,
    [Globalization.CultureInfo]::InvariantCulture,
    [ref] $frameCount
)

if (-not $parsed -or $frameCount -le 0) {
    throw "ffprobe did not return a usable video frame count for '$inputPath'."
}

# Convert the user-facing 1-based index to ffmpeg's zero-based frame number.
[long] $zeroBasedFrame = if ($FrameIndex -gt 0) {
    $FrameIndex - 1
} else {
    $frameCount + $FrameIndex
}

if ($zeroBasedFrame -lt 0 -or $zeroBasedFrame -ge $frameCount) {
    throw "FrameIndex $FrameIndex is outside the video. Valid values are 1 through $frameCount, or -1 through -$frameCount."
}

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $defaultOutputName = '{0}_frame_{1}.png' -f $inputItem.BaseName, $FrameIndex
    $OutputFile = Join-Path -Path $inputItem.DirectoryName -ChildPath $defaultOutputName
}

$outputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
    [System.IO.Path]::GetFullPath($OutputFile)
} else {
    # Resolve relative paths against PowerShell's current location, which can
    # differ from the process working directory used by .NET GetFullPath().
    [System.IO.Path]::GetFullPath((Join-Path -Path (Get-Location).Path -ChildPath $OutputFile))
}
$outputDirectory = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "Output directory does not exist: '$outputDirectory'."
}

if ((Test-Path -LiteralPath $outputPath -PathType Leaf) -and -not $Force) {
    throw "Output file already exists: '$outputPath'. Use -Force to overwrite it."
}

$selectExpression = "select=eq(n\,$zeroBasedFrame)"
$ffmpegArguments = @(
    '-hide_banner',
    '-loglevel', 'error',
    '-i', $inputPath,
    '-vf', $selectExpression,
    '-frames:v', '1',
    '-fps_mode', 'vfr'
)

if ($Force) {
    $ffmpegArguments += '-y'
} else {
    $ffmpegArguments += '-n'
}

$ffmpegArguments += $outputPath

& $ffmpeg.Source @ffmpegArguments
if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg failed while extracting frame $FrameIndex from '$inputPath'."
}

if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "ffmpeg completed without creating the output file '$outputPath'."
}

Write-Output $outputPath
