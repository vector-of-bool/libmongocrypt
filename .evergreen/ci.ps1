<#
.SYNOPSIS
    Configure, build, test, and install libmongocrypt
.DESCRIPTION
    This script executes a CMake configure+build, optional install, and optional test, all in one
    shot.
#>
[CmdletBinding(PositionalBinding = $false)]
param (
    # The CMake build configuration to configure and build
    [ValidateSet("Debug", "Release", "RelWithDebInfo", IgnoreCase = $false)]
    [string]
    $Config = "RelWithDebInfo",
    # The CMake options to set for the build
    #
    # Use KEY=VALUE pairs, all will be passed as '-D' arguments to CMake
    [string[]]
    $Settings,
    # The CMake executable to run. If unspecified, uses the 'cmake' on PATH
    [string]
    $CMake,
    # Set the CMake generator with '-G'
    [string]
    $Generator,
    # Set the CMake toolset with -T
    [string]
    $Toolset,
    # Set the CMake platform with -A
    [string]
    $Platform,
    # The directory in which to write the build files
    [string]
    $BuildDir,
    # The directory in which to install the results of the build
    [string]
    $InstallDir,
    # Clean the directory before building
    [switch]
    $Clean,
    # Skip running tests
    [switch]
    $SkipTests
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($CMake)) {
    if (Test-Path Env:/CMAKE) {
        $CMake = $env:CMAKE
    }
    else {
        $CMake = "cmake"
    }
}

$cmake_exe = (Get-Command $CMake -CommandType Application).Path

Write-Host "Using CMake executable [$cmake_exe]"

# The .evergreen directory
$evg_dir = $PSScriptRoot

$libmongocrypt_dir = Split-Path -Parent $evg_dir

if ([string]::IsNullOrEmpty($BuildDir)) {
    $BuildDir = Join-Path $libmongocrypt_dir "_build"
}
$BuildDir = [IO.Path]::GetFullPath($BuildDir)
Write-Debug "Using build directory [$BuildDir]"

# Build up the CMake command
$argv = @(
    "-H$libmongocrypt_dir",
    "-B$BuildDir",
    "-DCMAKE_BUILD_TYPE:STRING=$config"
)

$want_install = -not [string]::IsNullOrEmpty($InstallDir)
if ($want_install) {
    $InstallDir = [IO.Path]::GetFullPath($InstallDir)
    $argv += "-DCMAKE_INSTALL_PREFIX:PATH=$InstallDir"
    Write-Host "Setting installation prefix to [$InstallDir]"
}

foreach ($opt in $Settings) {
    $argv += "-D$OPT"
}

if (-not [string]::IsNullOrEmpty($Generator)) {
    $argv += "-G$Generator"
}

if (-not [string]::IsNullOrEmpty($Toolset)) {
    $argv += "-T$Toolset"
}

if (-not [string]::IsNullOrEmpty($Platform)) {
    $argv += "-A$Platform"
}

if ($Clean) {
    Remove-Item (Join-Path $BuildDir "CMakeCache.txt") -ErrorAction Ignore
    Remove-Item (Join-Path $BuildDir "CMakeFiles") -Recurse -ErrorAction Ignore
}

Write-Host "Configuring $Config in $BuildDir"
& $cmake_exe @argv
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed [$LASTEXITCODE]"
}

Write-Host "Building $Config in [$BuildDir]"
& $cmake_exe --build $BuildDir --config $Config
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed [$LASTEXITCODE]"
}

if (-not $SkipTests) {
    Write-Host "Testing $Config in [$BuildDir]"
    $cmake_bin_dir = Split-Path -Parent $cmake_exe
    $ctest_exe = Join-Path $cmake_bin_dir "ctest"
    $ctest = (Get-Command $ctest_exe).Path
    & $cmake_exe -E chdir $BuildDir `
        $ctest -C $Config --output-on-failure
    if ($LASTEXITCODE -ne 0) {
        throw "CTest execution failed [$LASTEXITCODE]"
    }
}

if ($want_install) {
    Write-Host "Installing $Config from [$BuildDir] into [$InstallDir]"
    & $cmake_exe -D CMAKE_INSTALL_CONFIG_NAME="$Config" -P "$BuildDir/cmake_install.cmake"
    if ($LASTEXITCODE -ne 0) {
        throw "CMake install failed [$LASTEXITCODE]"
    }
}
