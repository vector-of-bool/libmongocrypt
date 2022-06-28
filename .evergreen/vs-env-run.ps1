<#
.SYNOPSIS
    Execute a command with a Visual Studio environment loaded

.DESCRIPTION
    This script will load the specified Visual Studio environment with the
    specified options set, and then execute the given program

    This script makes use of vswhere.exe, which is installed with Visual Studio
    2017 or later, but supports all Visual Studio versions.

    Only the -Version and -TargetArch parameters are required. The command
    should be given as a script block or executable string.

.EXAMPLE
    PS C:\> vs-env-run.ps1 -Version 14.* -TargetArch amd64 { build_all.ps1 }

    This will load the Visual Studio 14 environment targetting amd64 processors
    and then run 'build_all.ps1'
#>
[CmdletBinding(PositionalBinding = $false)]
param (
    # Select a version of Visual Studio to activate. Accepts wildcards.
    #
    # Major versions by year release:
    #
    #   - 14.* => VS 2015
    #   - 15.* => VS 2017
    #   - 16.* => VS 2019
    #   - 17.* => VS 2022
    #
    # Use of a wildcard pattern in scripts is recommended for portability.
    #
    # Supports tab-completion if vswhere.exe is present.
    [Parameter(Mandatory)]
    [ArgumentCompleter({
            param($commandName, $paramName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $vswhere_found = @(Get-ChildItem -Filter vswhere.exe `
                    -Path 'C:\Program Files*\Microsoft Visual Studio\Installer\' `
                    -Recurse)[0]
            if ($null -eq $vswhere_found) {
                Write-Host "No vswhere found"
                return $null
            }
            return & $vswhere_found -utf8 -nologo -format json -all -legacy -prerelease -products * `
            | ConvertFrom-Json `
            | ForEach-Object { $_.installationVersion } `
            | Where-Object { $_ -like "$wordToComplete*" }
        })]
    [string]
    $Version,
    # The target architecture for the build
    [Parameter(Mandatory)]
    [ValidateSet("x86", "amd64", "arm", "arm64", IgnoreCase = $false)]
    [string]
    $TargetArch,
    # Select a specific Windows SDK version.
    [string]
    $WinSDKVersion,
    # The host architecture to use. Not usually needed. Detaults to x86
    [ValidateSet("x86", "amd64", IgnoreCase = $false)]
    [string]
    $HostArch = "x86",
    # The Visual C++ toolset to load
    [string]
    $VCToolsetVersion,
    # Prefer Visual C++ libraries with Spectre mitigations
    [switch]
    $UseSpectreMiticationLibraries,
    # The app platform to load. Default is "Desktop"
    [ValidateSet("Desktop", "UWP", IgnoreCase = $false)]
    [string]
    $AppPlatform = "Desktop",

    # The command to execute within the VS environment. May be any invocable object.
    [Parameter(Mandatory, Position = 1)]
    $Command
)

$ErrorActionPreference = 'Stop'

# Find a vswhere executable
$vswhere_found = Get-ChildItem -Filter vswhere.exe `
    -Path 'C:\Program Files*\Microsoft Visual Studio\Installer\' `
    -Recurse

$vswhere = @($vswhere_found)[0]
Write-Debug "Found vswhere: $vswhere"

# Ask vswhere for all the installed products:
$vs_versions = & $vswhere -utf8 -nologo -format json -all -legacy -prerelease -products * `
| ConvertFrom-Json

# Pick the produce that matches the pattern
$selected = @($vs_versions `
    | Where-Object { $_.installationVersion -like $Version })

if ($selected.Length -eq 0) {
    throw "No Visual Studio was found with a version matching '$Version'"
}

$selected = $selected[0]
Write-Debug "Selected Visual Studio version $($selected.installationVersion)"

# Find the environment-activation script for the chosen VS
$vsdevcmd_bat = @(Get-ChildItem `
        -Path $selected.installationPath `
        -Filter "VsDevCmd.bat" -Recurse)[0]

$env_script_content = ""

# Use batch and the 'set' command to get the required environment variables out.
if ($null -eq $vsdevcmd_bat) {
    Write-Warning "No VsDevCmd.bat found for the requested VS version. Falling back to vcvarsall.bat"
    Write-Warning "Additional platform selection functionality will be limited"
    $vcvarsall_bat = @(Get-ChildItem -Path $selected.installationPath -Filter "vcvarsall.bat" -Recurse)[0]
    if ($null -eq $vcvarsall_bat) {
        throw "No VsDevCmd.bat nor vcvarsall.bat file found for requested Visual Studio version '$($selected.installationVersion)'"
    }
    $env_script_content = @"
        @echo off
        call "$($vcvarsall_bat.FullName)" $TargetArch $WinSDKVersion
        set _rc=%ERRORLEVEL%
        set
        exit /b %_rc%
"@
}
else {
    # Build up the argument string to load the appropriate environment
    $argstr = "-no_logo -arch=$TargetArch -host_arch=$HostArch -app_platform=$AppPlatform"
    if ($UseSpectreMiticationLibraries) {
        $argstr += " -vcvars_specter_libs=spectre"
    }
    if ($WinSDKVersion) {
        $argstr += " -winsdk=$WinSDKVersion"
    }
    if ($VCToolsetVersion) {
        $argstr += " -vcvars_ver=$VCToolsetVersion"
    }

    $env_script_content = @"
        @echo off
        call "$($vsdevcmd_bat.FullName)" $argstr
        set _rc=%ERRORLEVEL%
        set
        exit /b %_rc%
"@
}

# Write the script and then execute it, capturing its output
Set-Content .env.bat $env_script_content

Write-Host "Loading VS environment..."
$output = & cmd.exe /c .env.bat
if ($LASTEXITCODE -ne 0) {
    throw "Loading the environment failed [$LASTEXITCODE]:`n$output"
}

# The plain 'set' command emits VAR=VALUE lines for each loaded environment
# variable. Parse those out and set them in our own environment.
$prior_env = @{}
foreach ($line in $output.Split("`r`n")) {
    if ($line -match "(\w+)=(.+)") {
        $varname = $Matches[1]
        $value = $Matches[2]
        # Set the environment value (may be null):
        $prior_env[$varname] = [System.Environment]::GetEnvironmentVariable($varname)
        [System.Environment]::SetEnvironmentVariable($varname, $value)
    }
}

Write-Debug "Running command: $(ConvertTo-Json $Command)"

try {
    # Now invoke the external command.
    & $Command
    if ($LASTEXITCODE -ne 0) {
        # If it was a process that returned non-zero, throw an error.
        throw "Subcommand failed [$LASTEXITCODE]"
    }
}
finally {
    # Restore the prior environment
    foreach ($key in $prior_env.Keys) {
        [System.Environment]::SetEnvironmentVariable($key, $prior_env[$key])
    }
}