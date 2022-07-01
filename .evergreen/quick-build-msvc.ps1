<#
.SYNOPSIS
    Configure and build libmongocrypt with all default settings for MSVC,
    loading the VS environment and using Ninja.
#>
[CmdletBinding(PositionalBinding = $false)]
param (
    # Use the specified Visual Studio version. (See vs-env-run.ps1 for more info)
    [string]
    $VSVersion = "*",
    # Build the given target MSVC architecture
    [string]
    $TargetArch = "amd64",
    # Build the specified CMake configuration
    [string]
    $Config = "RelWithDebInfo",
    # The directory in which to write the installation resutl
    [string]
    $InstallDir,
    # The directory in which to store the build files
    [string]
    $BuildDir,
    # The source directory to build
    [string]
    $SourceDir,
    # Skip running tests
    [switch]
    $SkipTests,
    # Additional settings to pass to CMake
    [string[]]
    $Settings
)

$ErrorActionPreference = "stop"

$evg_dir = $PSScriptRoot

& $evg_dir/get-ninja.ps1 -DestDir $evg_dir -Version 1.11.0 | Out-Null

$ninja_bin = Join-Path $evg_dir "ninja"

$vs_env_run = Join-Path $evg_dir "vs-env-run.ps1"
$ci_ps1 = Join-Path $evg_dir "ci.ps1"

Write-Host "Run script [$vs_env_run]"

& $vs_env_run -Version:$VSVersion -Target:$TargetArch -Command {
    $more_settings = @($Settings)
    $more_settings += "CMAKE_MAKE_PROGRAM=$ninja_bin"
    & $ci_ps1 -Generator Ninja `
        -Config:$Config `
        -SourceDir:$SourceDir `
        -BuildDir:$BuildDir `
        -Settings:$more_settings `
        -InstallDir:$InstallDir `
        -SkipTests:$SkipTests
}
