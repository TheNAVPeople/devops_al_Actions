param (
    [string] $Path,
    [string] $OutputPath,
    [string] $PreRelease,
    [string] $Repository,
    [string] $Branch,
    [string] $Commit,
    [string] $Uri,
    [string] $ApiKey,
    [string] $SettingsPath,
    [string] $DefaultSettingsPath
)

import-module T3PALAppsBuilder

if ([System.String]::IsNullOrWhitespace($SettingsPath)) {
    $SettingsPath = $DefaultSettingsPath
} elseif (!(Test-Path -Path $SettingsPath)) {
    throw "ERROR: NuGet settings file $SettingsPath cannot be found"
}

if ((![System.String]::IsNullOrWhiteSpace($Repository)) -and (![System.String]::IsNullOrWhiteSpace($Branch)) -and ([System.String]::IsNullOrWhiteSpace($Commit))) {
    $Commit = git log -1 --format="%H"
}

Push-T3PALAppsFolderToNuGet -Path $Path -OutputPath $OutputPath -PreRelease $PreRelease -Repository $Repository -Branch $Branch -Commit $Commit -Uri $Uri -ApiKey $ApiKey -SettingsPath $SettingsPath -ProjectPath $Path
