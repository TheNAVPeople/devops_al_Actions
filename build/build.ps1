param (
    [string] $Path,
    [string] $CompilerPath,
    [string] $Analyzers, 
    [string] $WarnAsError,
    [string] $OutPath,
    [string] $ALPackagesPath = '.alpackages',
    [string] $Ruleset,
    [string] $DefaultRuleset,

    [string] $ApiKey,
    [string] $NuGetSettingsPath,
    [string] $DependenciesSelectionMode,
    [string] $DependenciesPreReleaseSuffix,
    [string] $DownloadDependencies = "true",

    [string] $BCConfiguration,
    [string] $BCApplicationVersion,
    [string] $BCRuntimeVersion,
    [string] $BCVersion,
    [string] $BCVersionSelectionMode = "Closest",
    [string] $BCArtifactsType = "onprem",
    [string] $BCArtifactsStorageAccount,
    [string] $BCCountry = "gb",    
    [string] $VersionMajor,
    [string] $VersionMinor,
    [string] $VersionBuild,
    [string] $VersionRevision,
    [string] $VersionBuildOffset,
    [string] $VersionRevisionOffset,
    [string] $CommitVersionChange = "false",
    [string] $ChangeVersion = "true",
    [string] $VersionChangeCommitMessage,
    [string] $UseNavCompiler = "false",
    [string] $DirectBCArtifactsSymbolsDownload = "false",
    [string] $CompilerLog,
    [string] $Parallel
)

function Check-ProjectReferencesPreview {
    param (
        [string] $CompilerPath,
        [string] $ProjectPath,
        [string] $Configuration,
        [string] $ArtifactsType,
        [string] $StorageAccount,
        [string] $SelectVersion
    )

    # check if current project should switch to preview
    $isPreview = (($storageAccount -eq "bcinsider") -or ($SelectVersion -eq "NextMinor") -or ($SelectVersion -eq "NextMajor"))
    $isMarketplaceCompiler = ($CompilerPath.ToLower().Contains("marketplace"))

    $settingsChanged = $false

    if ((!$isPreview) -and ($isMarketplaceCompiler)) {
        # get solution runtime
        $solutionPlatformVersion = Get-T3PALFolderMinPlatformVersion -Path $ProjectPath
        $solutionRuntime = $solutionPlatformVersion.Major - 11

        # get marketplace extension runtime
        $compilerFilePath = Join-Path -Path $CompilerPath -ChildPath "win32\alc.exe"
        $compilerVersionText = (Get-Item $compilerFilePath).VersionInfo.FileVersion
        $compilerVersion = [System.Version]::new($compilerVersionText)
        $compilerRuntime = $compilerVersion.Major

        # if project runtime greater than current compiler, then detect version
        if ($solutionRuntime -gt $compilerRuntime) {
            $runtimeDiff = ($solutionRuntime - $compilerRuntime)
            $isPreview = $true
            $settingsChanged = $true

            $ArtifactsType = "Sandbox"
            if ($runtimeDiff -eq 1) {
                $StorageAccount = ""
                $SelectVersion = "NextMajor"
            } else {
                $StorageAccount = "bcinsider"
                $SelectVersion = "Latest"          
            }
        }
    }

     $data = [PSCustomObject]@{
        ArtifactsType = $ArtifactsType
        StorageAccount = $StorageAccount
        SelectVersion = $SelectVersion
        IsPreview = $isPreview
        SettingsChanged = $settingsChanged
    }

    return $data
}

function CheckUrlLinkValue {
    param (
        [string] $FilePath,
        [string] $PropertyName,
        [string] $PropertyValue,
        [string] $LogFile,
        $ValidUrlsList
    )

    if (![System.String]::IsNullOrWhiteSpace($PropertyValue)) {
        $valid = $false
        $urlToCheck = $PropertyValue.ToLower().Trim()

        foreach ($validUrl in $validUrlsList) {
            if (![System.String]::IsNullOrWhiteSpace($validUrl)) {
                if ($urlToCheck.StartsWith($validUrl)) {
                    $valid = $true
                    break
                }
            }
        }

        if (!$valid) {
            $msgLine = "Error: Property " + $PropertyName + " cannot contain " + $PropertyValue + " value in the " + $FilePath + " file."
            if (![System.String]::IsNullOrWhiteSpace($LogFile)) {
                Add-Content -Path $LogFile -Value $msgLine
            }
            Write-Host $msgLine
        }

        return $valid

    } else {
        return $true
    }
}

function Check-ProjectAppJson {
    param (
        [string] $Path,
        [string] $ValidUrls,
        [string] $LogFile
    )

    $filePath = Join-Path -Path $Path -ChildPath "app.json"

    $valid = $true

    if (![System.String]::IsNullOrWhiteSpace($ValidUrls)) {
        $validUrlsList = $ValidUrls | ConvertFrom-Json | ForEach-Object { $_.ToLower().Trim() }

        if (Test-Path $filePath) {
            try {
                $jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json

                $validContextSensitiveHelpUrl = CheckUrlLinkValue -FilePath $filePath -PropertyName "contextSensitiveHelpUrl" -PropertyValue $jsonContent.contextSensitiveHelpUrl -ValidUrlsList $validUrlsList -LogFile $LogFile
                $validPrivacyStatement = CheckUrlLinkValue -FilePath $filePath -PropertyName "privacyStatement" -PropertyValue $jsonContent.privacyStatement -ValidUrlsList $validUrlsList -LogFile $LogFile
                $validHelp = CheckUrlLinkValue -FilePath $filePath -PropertyName "help" -PropertyValue $jsonContent.help -ValidUrlsList $validUrlsList -LogFile $LogFile
                $validEULA = CheckUrlLinkValue -FilePath $filePath -PropertyName "EULA" -PropertyValue $jsonContent.EULA -ValidUrlsList $validUrlsList -LogFile $LogFile
                $validUrl = CheckUrlLinkValue -FilePath $filePath -PropertyName "url" -PropertyValue $jsonContent.url -ValidUrlsList $validUrlsList -LogFile $LogFile

                $valid = $validContextSensitiveHelpUrl -and $validPrivacyStatement -and $validHelp -and $validEULA -and $validUrl
            } catch {
                Write-Error "Error: Failed to read or parse JSON from path: '$filePath'. Error: $_"
                $valid = $false
            }
        }
    }

    return $valid
}

function Check-WorkspaceAppJsons {
    param (
        [string] $Path,
        [string] $ValidUrls,
        [string] $LogFile
    )

    $valid = $true
    $projectsList = Get-T3PALWorkspaceProjects -Path $Path
    foreach ($project in $projectsList) {
        $validProject = Check-ProjectAppJsons -Path $project.ProjectPath -ValidUrls $ValidUrls -LogFile $LogFile
        $valid = $valid -and $validProject
    }

    return $validProject
}

function Check-FolderAppJsons {
    param (
        [string] $Path,
        [string] $ValidUrls,
        [string] $LogFile
    )

    $TestPath = $Path.ToLower()
    
    if ($TestPath.EndsWith("app.json")) {
        $projectFolder = Split-Path -Path $Path
        return Check-ProjectAppJson -Path $projectFolder -ValidUrls $ValidUrls -LogFile $LogFile
    } elseif ($TestPath.EndsWith(".code-workspace")) {
        return Check-WorkspaceAppJsons -Path $Path -ValidUrls $ValidUrls -LogFile $LogFile
    } else {
        $filePath = Join-Path -Path $Path -ChildPath "app.json"
        if (Test-Path -Path $filePath -PathType Leaf) {
            $projectFolder = Split-Path -Path $filePath
            return Check-ProjectAppJson -Path $projectFolder -ValidUrls $ValidUrls -LogFile $LogFile
        } else {
            $workspaceFiles = @(Get-Childitem -Path $Path -Filter "*.code-workspace")
            if (($workspaceFiles | Measure-Object).Count -eq 1) {
                $filePath = $WorkspaceFiles[0]
                return Check-WorkspaceAppJsons -Path $filePath -ValidUrls $ValidUrls -LogFile $LogFile
            }
        }
    }    
}

function WriteValidUrls {
    param (
        [string] $ValidUrls,
        [string] $LogFile
    )

    if (![System.String]::IsNullOrWhiteSpace($ValidUrls)) {
        $validUrlsList = $ValidUrls | ConvertFrom-Json | ForEach-Object { $_.ToLower().Trim() }
        foreach ($validUrl in $validUrlsList) {
            if (![System.String]::IsNullOrWhiteSpace($validUrl)) {
                $msgLine = "  " + $validUrl
                if (![System.String]::IsNullOrWhiteSpace($LogFile)) {
                    Add-Content -Path $LogFile -Value $msgLine
                }
                Write-Host $msgLine
            }
        }
    }

}

Import-Module BcContainerHelper
import-module T3PALAppsBuilder

#check urls in app.json
$UrlsToTest = '
[
    "https://continia-tools.gitbook.io",
    "https://docs.continia.com",
    "https://docs.microsoft.com",
    "https://github.com",
    "https://go.microsoft.com/fwlink/?linkid=2179727",
    "https://help.lscentral.lsretail.com",
    "https://learn.microsoft.com",
    "https://the365people.com",
    "https://thenavpeople.co.uk",
    "https://thenavpeople.com",
    "https://tisski.com",
    "https://www.the365people.com",
    "https://www.thenavpeople.co.uk",
    "https://www.node4.co.uk",
    "https://portal.lsretail.com",
    "https://www.lsretail.com",
    "https://lsretail.com",
    "https://node4.co.uk"
]
'

$appJsonTest = Check-FolderAppJsons -Path $Path -ValidUrls $UrlsToTest -LogFile $CompilerLog
if (!$appJsonTest) {
    $msgLine = "Remove invalid properties from the app.json or make sure that they start with one of these trusted urls:"
    if (![System.String]::IsNullOrWhiteSpace($CompilerLog)) {
        Add-Content -Path $CompilerLog -Value $msgLine
    }
    Write-Host $msgLine
    WriteValidUrls -ValidUrls $UrlsToTest -LogFile $CompilerLog
    throw "Security error. Invalid urls found in the app.json."
}

#use default country
if ([System.String]::IsNullOrWhiteSpace($BCCountry)) {
    $BCCountry = "gb"
}

#use default ruleset
if (([System.String]::IsNullOrWhiteSpace($Ruleset)) -and (![System.String]::IsNullOrWhiteSpace($Analyzers))) {
    $Ruleset = $DefaultRuleset
}

#update version number
if (([System.String]::IsNullOrWhiteSpace($ChangeVersion)) -or ($ChangeVersion -eq "true")) {

    if ((![System.String]::IsNullOrWhiteSpace($VersionBuild)) -and (![System.String]::IsNullOrWhiteSpace($VersionBuildOffset))) {
        $VersionBuild = (([int]$VersionBuild) + ([int]$VersionBuildOffset)).ToString()
    }

    if ((![System.String]::IsNullOrWhiteSpace($VersionRevision)) -and (![System.String]::IsNullOrWhiteSpace($VersionRevisionOffset))) {
        $VersionRevision = (([int]$VersionRevision) + ([int]$VersionRevisionOffset)).ToString()
    }

    if ((![System.String]::IsNullOrWhiteSpace($VersionMajor)) -or (![System.String]::IsNullOrWhiteSpace($VersionMinor)) -or (![System.String]::IsNullOrWhiteSpace($VersionBuild)) -or (![System.String]::IsNullOrWhiteSpace($VersionRevision))) {
        [string] $folderVersion = Set-T3PALFolderVersion -Path $Path -Major $VersionMajor -Minor $VersionMinor -Build $VersionBuild -Revision $VersionRevision -Configuration $BCConfiguration

        if ($CommitVersionChange -eq "true") {

            if ([System.String]::IsNullOrWhiteSpace($VersionChangeCommitMessage)) {
                $VersionChangeCommitMessage = "[skip ci] - Build version update"
            }

            $commitMessage = ($VersionChangeCommitMessage + " " + $folderVersion)
            git add --all
            git commit -m $commitMessage -q
            git push
        }

    }
}

# Convert project if required
if ((![System.String]::IsNullOrWhiteSpace($BCApplicationVersion)) -or (![System.String]::IsNullOrWhiteSpace($BCRuntimeVersion)) -or (![System.String]::IsNullOrWhiteSpace($BCConfiguration))) {
    Set-T3PALFolderConfiguration -Path $Path -CompilerPath $CompilerPath -Application $BCApplicationVersion -Runtime $BCRuntimeVersion -Configuration $BCConfiguration
}

# Check if extension references preview build and preview compiler and dependencies should be used
$newSettings = Check-ProjectReferencesPreview -CompilerPath $CompilerPath -ProjectPath $Path -Configuration $BCConfiguration -ArtifactsType $BCArtifactsType -StorageAccount $BCArtifactsStorageAccount -SelectVersion $BCVersionSelectionMode
if ($newSettings.SettingsChanged) {
    
    # update settings   
    $BCArtifactsType = $newSettings.ArtifactsType
    $BCArtifactsStorageAccount = $newSettings.StorageAccount
    $BCVersionSelectionMode = $newSettings.SelectVersion

    # get preview compiler
    Write-Host "Extension references preview libraries. Downloading compiler preview."
    $CompilerBasePath = "C:\al-compiler"
    
    $mtx = New-Object System.Threading.Mutex($false, "T3PDevOpsALCompilerInstallation")
    try {
        if ($mtx.WaitOne()) {
            $CompilerPath = Install-T3PALCompiler -CompilerPath $CompilerBasePath -Type $BCArtifactsType -StorageAccount $BCArtifactsStorageAccount -Select $BCVersionSelectionMode
        }
    } finally {
        if ($mtx -ne $null) {
            [void]$mtx.ReleaseMutex()
            $mtx.Dispose()
        }
    }
}

if (!$newSettings.IsPreview) {
    $DirectBCArtifactsSymbolsDownload = "true"
}

if (([System.String]::IsNullOrWhiteSpace($DownloadDependencies)) -or ($DownloadDependencies.ToString() -eq "true")) {
    if ($DirectBCArtifactsSymbolsDownload -eq "true") {

        # Download dependencies from NuGet and microsoft artifacts
        Get-T3PALFolderDependenciesFromNuGet -Path $Path -ApiKey $ApiKey -ALPackagesPath $ALPackagesPath -Select $DependenciesSelectionMode -PreRelease $DependenciesPreReleaseSuffix -CompilerPath $CompilerPath -Country $BCCountry -ArtifactsCachePath "c:\bcartifactscache" -ArtifactsStorageAccount $BCArtifactsStorageAccount -Symbols "true" -ClearPackages "true" -SaaS "true" -UseBCArtifacts "true" -IncludeMicrosoftSymbols "true"

    } else {

        # Download dependencies from NuGet
        Get-T3PALFolderDependenciesFromNuGet -Path $Path -ApiKey $ApiKey -ALPackagesPath $ALPackagesPath -Select $DependenciesSelectionMode -PreRelease $DependenciesPreReleaseSuffix -CompilerPath $CompilerPath -Country $BCCountry -ArtifactsCachePath "c:\bcartifactscache" -ArtifactsStorageAccount $BCArtifactsStorageAccount -Symbols "true" -ClearPackages "true" -SaaS "true" -UseBCArtifacts "true" -IncludeMicrosoftSymbols "false"

        $mtx = New-Object System.Threading.Mutex($false, "T3PDevOpsALCompilerInstallation")
        try {
            if ($mtx.WaitOne()) {
                # Download microsoft dependencies
                Get-T3PALFolderPlatformDependencies -Path $Path -ALPackagesPath $ALPackagesPath -Country $BCCountry -Version $BCVersion -Select $BCVersionSelectionMode -Type $BCArtifactsType -StorageAccount $BCArtifactsStorageAccount
            }
        } finally {
            if ($mtx -ne $null) {
                [void]$mtx.ReleaseMutex()
                $mtx.Dispose()
            }
        }

    }
}

# Compile extensions
if ($UseNavCompiler -eq "true")
{
    $Analyzers = $null
    $Ruleset = $null
}

Invoke-T3PALFolderCompiler -Path $Path -CompilerPath $CompilerPath -Analyzers $Analyzers -OutPath $OutPath -WarnAsError $WarnAsError -ALPackagesPath $ALPackagesPath -Ruleset $Ruleset -LogFile $CompilerLog -Parallel $Parallel

# Copy *.md files to the output folder
if ((![System.String]::IsNullOrWhiteSpace($OutPath)) -and ($OutPath -ne $Path)) {
    # Copy all .md files (non-recursive, with force)
    Get-ChildItem -Path $Path -Filter *.md -File | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $OutPath -Force
    }
}

