
<#
.SYNOPSIS
    Obtain a Windows build of ninja-build tool
.DESCRIPTION
    This script downloads and unpacks a build of Ninja for Windows. Other platforms are not supported
#>
[CmdletBinding()]
param (
    # The Ninja version to download
    [Parameter(Mandatory)]
    [string]
    $Version,
    # The directory in which to put the Ninja executable
    [Parameter(Mandatory)]
    [string]
    $DestDir
)

$ErrorActionPreference = 'Stop'

$ProgressPreference = "SilentlyContinue"
$ninja_zip = Join-Path $DestDir ".ninja.zip"
Invoke-WebRequest `
    -UseBasicParsing `
    -Uri "https://github.com/ninja-build/ninja/releases/download/v$Version/ninja-win.zip" `
    -OutFile $ninja_zip

$expand_dir = Join-Path $DestDir "_expanded"
Expand-Archive -Path $ninja_zip $expand_dir

Move-Item $expand_dir/ninja.exe -Destination $DestDir/ninja.exe -Force
Remove-Item $expand_dir -Recurse
Remove-Item $ninja_zip

Write-Debug "ninja.exe written to [$DestDir/ninja.exe]"
