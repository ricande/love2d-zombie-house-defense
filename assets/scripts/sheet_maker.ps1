param(
    [Parameter(Mandatory = $true)]
    [string]$Profile,
    [string]$SourceDir,
    [string]$OutputPath,
    [int]$FrameCount,
    [int]$FrameWidth,
    [int]$FrameHeight,
    [int]$PaletteColors,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-MagickPath {
    $candidates = @(
        "magick",
        "C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe",
        "C:\Program Files\ImageMagick-7.1.2-Q16\magick.exe"
    )

    foreach ($candidate in $candidates) {
        try {
            if ($candidate -eq "magick") {
                $cmd = Get-Command "magick" -ErrorAction Stop
                return $cmd.Source
            }
            if (Test-Path $candidate) {
                return $candidate
            }
        } catch {
            # Try next candidate.
        }
    }

    throw "ImageMagick executable not found. Install ImageMagick or add magick.exe to PATH."
}

function Resolve-ProjectPath {
    param(
        [string]$ProjectRoot,
        [string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return Join-Path $ProjectRoot $PathValue
}

function Ensure-FrameCount {
    param(
        [string]$FramesDir,
        [string]$Prefix,
        [int]$ExpectedCount
    )

    $count = (Get-ChildItem -Path $FramesDir -Filter "$Prefix*.png" | Measure-Object).Count
    if ($count -ne $ExpectedCount) {
        throw "Expected $ExpectedCount frames for '$Prefix' but found $count."
    }
}

function Invoke-MagickCommand {
    param(
        [string]$Magick,
        [string[]]$CommandArgs,
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Host ("[DryRun] {0} {1}" -f $Magick, ($CommandArgs -join " "))
        return
    }

    & $Magick @CommandArgs
}

function Build-Row {
    param(
        [string]$Magick,
        [string]$FramesDir,
        [string]$RowsDir,
        [string]$Direction,
        [int]$FrameCount,
        [int]$FrameWidth,
        [int]$FrameHeight,
        [switch]$DryRun
    )

    $framePaths = @()
    for ($i = 0; $i -lt $FrameCount; $i++) {
        $idx = "{0:D2}" -f $i
        $framePath = Join-Path $FramesDir ("{0}_{1}.png" -f $Direction, $idx)
        if (-not $DryRun -and -not (Test-Path $framePath)) {
            throw "Missing frame: $framePath"
        }
        $framePaths += $framePath
    }

    $rowPath = Join-Path $RowsDir ("{0}.png" -f $Direction)
    $geometry = "{0}x{1}+0+0" -f $FrameWidth, $FrameHeight
    $tile = "{0}x1" -f $FrameCount
    $args = @("montage") + $framePaths + @("-background", "none", "-tile", $tile, "-geometry", $geometry, $rowPath)
    Invoke-MagickCommand -Magick $Magick -CommandArgs $args -DryRun:$DryRun
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$profilesPath = Join-Path $scriptDir "sheet_profiles.psd1"

if (-not (Test-Path $profilesPath)) {
    throw "Profile config not found: $profilesPath"
}

$config = Import-PowerShellDataFile -Path $profilesPath
if (-not $config.Profiles.ContainsKey($Profile)) {
    $available = $config.Profiles.Keys | Sort-Object
    throw "Unknown profile '$Profile'. Available profiles: $($available -join ', ')"
}

$effectiveProfile = @{}
foreach ($key in $config.Defaults.Keys) {
    $effectiveProfile[$key] = $config.Defaults[$key]
}
foreach ($key in $config.Profiles[$Profile].Keys) {
    $effectiveProfile[$key] = $config.Profiles[$Profile][$key]
}

if ($PSBoundParameters.ContainsKey("SourceDir")) { $effectiveProfile.SourceDir = $SourceDir }
if ($PSBoundParameters.ContainsKey("OutputPath")) { $effectiveProfile.OutputPath = $OutputPath }
if ($PSBoundParameters.ContainsKey("FrameCount")) { $effectiveProfile.FrameCount = $FrameCount }
if ($PSBoundParameters.ContainsKey("FrameWidth")) { $effectiveProfile.FrameWidth = $FrameWidth }
if ($PSBoundParameters.ContainsKey("FrameHeight")) { $effectiveProfile.FrameHeight = $FrameHeight }
if ($PSBoundParameters.ContainsKey("PaletteColors")) { $effectiveProfile.PaletteColors = $PaletteColors }

foreach ($requiredKey in $config.ProfileSchema.Required) {
    if (-not $effectiveProfile.ContainsKey($requiredKey) -or $null -eq $effectiveProfile[$requiredKey]) {
        throw "Profile '$Profile' is missing required key '$requiredKey'."
    }
}

$sourceDirAbs = Resolve-ProjectPath -ProjectRoot $projectRoot -PathValue $effectiveProfile.SourceDir
$outputPathAbs = Resolve-ProjectPath -ProjectRoot $projectRoot -PathValue $effectiveProfile.OutputPath
$frameWidth = [int]$effectiveProfile.FrameWidth
$frameHeight = [int]$effectiveProfile.FrameHeight
$frameCount = [int]$effectiveProfile.FrameCount
$paletteColors = [int]$effectiveProfile.PaletteColors
$directionOrder = [string[]]$effectiveProfile.DirectionOrder
$sourceMap = $effectiveProfile.SourceMap
$mirrorMap = $effectiveProfile.MirrorMap

if (-not (Test-Path $sourceDirAbs)) {
    throw "Source directory not found: $sourceDirAbs"
}

foreach ($direction in $sourceMap.Keys) {
    $sourceFile = Join-Path $sourceDirAbs $sourceMap[$direction]
    if (-not (Test-Path $sourceFile)) {
        throw "Missing source GIF for direction '$direction': $sourceFile"
    }
}

foreach ($targetDirection in $mirrorMap.Keys) {
    $sourceDirection = [string]$mirrorMap[$targetDirection]
    if (-not $sourceMap.ContainsKey($sourceDirection)) {
        throw "Mirror source direction '$sourceDirection' for target '$targetDirection' is not defined in SourceMap."
    }
}

$buildDir = Join-Path $scriptDir (".build\{0}" -f $Profile)
$framesDir = Join-Path $buildDir "frames"
$rowsDir = Join-Path $buildDir "rows"

if (-not $DryRun) {
    if (Test-Path $buildDir) {
        Remove-Item -Path $buildDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $framesDir -Force | Out-Null
    New-Item -ItemType Directory -Path $rowsDir -Force | Out-Null
    $outputDir = Split-Path -Parent $outputPathAbs
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
}

$magick = Get-MagickPath
Write-Host ("Profile: {0}" -f $Profile)
Write-Host ("SourceDir: {0}" -f $sourceDirAbs)
Write-Host ("OutputPath: {0}" -f $outputPathAbs)
Write-Host ("Frame: {0}x{1} x {2} frames" -f $frameWidth, $frameHeight, $frameCount)

foreach ($direction in $sourceMap.Keys) {
    $sourceFile = Join-Path $sourceDirAbs $sourceMap[$direction]
    $targetPattern = Join-Path $framesDir ("{0}_%02d.png" -f $direction)
    $args = @(
        $sourceFile,
        "-coalesce",
        "+repage",
        "-resize",
        ("{0}x{1}!" -f $frameWidth, $frameHeight),
        $targetPattern
    )
    Invoke-MagickCommand -Magick $magick -CommandArgs $args -DryRun:$DryRun
}

if (-not $DryRun) {
    foreach ($direction in $sourceMap.Keys) {
        Ensure-FrameCount -FramesDir $framesDir -Prefix ("{0}_" -f $direction) -ExpectedCount $frameCount
    }
}

for ($i = 0; $i -lt $frameCount; $i++) {
    $idx = "{0:D2}" -f $i
    foreach ($targetDirection in $mirrorMap.Keys) {
        $sourceDirection = [string]$mirrorMap[$targetDirection]
        $sourceFrame = Join-Path $framesDir ("{0}_{1}.png" -f $sourceDirection, $idx)
        $targetFrame = Join-Path $framesDir ("{0}_{1}.png" -f $targetDirection, $idx)
        $args = @($sourceFrame, "-flop", $targetFrame)
        Invoke-MagickCommand -Magick $magick -CommandArgs $args -DryRun:$DryRun
    }
}

if (-not $DryRun) {
    foreach ($targetDirection in $mirrorMap.Keys) {
        Ensure-FrameCount -FramesDir $framesDir -Prefix ("{0}_" -f $targetDirection) -ExpectedCount $frameCount
    }
}

foreach ($direction in $directionOrder) {
    Build-Row `
        -Magick $magick `
        -FramesDir $framesDir `
        -RowsDir $rowsDir `
        -Direction $direction `
        -FrameCount $frameCount `
        -FrameWidth $frameWidth `
        -FrameHeight $frameHeight `
        -DryRun:$DryRun
}

$rowPaths = @()
foreach ($direction in $directionOrder) {
    $rowPaths += (Join-Path $rowsDir ("{0}.png" -f $direction))
}

$png8Output = "PNG8:" + $outputPathAbs
$appendArgs = $rowPaths + @("-append", "-colors", "$paletteColors", $png8Output)
Invoke-MagickCommand -Magick $magick -CommandArgs $appendArgs -DryRun:$DryRun

$alphaArgs = @($outputPathAbs, "-background", "none", "-alpha", "on", $png8Output)
Invoke-MagickCommand -Magick $magick -CommandArgs $alphaArgs -DryRun:$DryRun

if ($DryRun) {
    Write-Host "[DryRun] No files were written."
    exit 0
}

$identifyOutput = & $magick identify -format "%w %h %k %[channels]" $outputPathAbs
$parts = $identifyOutput -split " "
if ($parts.Count -lt 4) {
    throw "Unexpected identify output: $identifyOutput"
}

$actualWidth = [int]$parts[0]
$actualHeight = [int]$parts[1]
$actualColors = [int]$parts[2]
$channels = $parts[3]

$expectedWidth = $frameWidth * $frameCount
$expectedHeight = $frameHeight * $directionOrder.Count

if ($actualWidth -ne $expectedWidth -or $actualHeight -ne $expectedHeight) {
    throw "Output size mismatch. Expected ${expectedWidth}x${expectedHeight}, got ${actualWidth}x${actualHeight}."
}

if ($channels -notmatch "a") {
    throw "Output channels do not include alpha: $identifyOutput"
}

Write-Host ("Sprite sheet created: {0}" -f $outputPathAbs)
Write-Host ("Identify: {0}" -f $identifyOutput)
Write-Host ("Expected size: {0}x{1}" -f $expectedWidth, $expectedHeight)
Write-Host ("Colors: {0} (target <= {1}), channels: {2}" -f $actualColors, $paletteColors, $channels)
