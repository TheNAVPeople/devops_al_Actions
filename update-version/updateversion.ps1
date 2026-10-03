param (
    [string] $Path,
    [string] $BCConfiguration,
    [string] $VersionMajor,
    [string] $VersionMinor,
    [string] $VersionBuild,
    [string] $VersionRevision,
    [string] $VersionBuildOffset,
    [string] $VersionRevisionOffset,
    [string] $CommitVersionChange = "false",
    [string] $VersionChangeCommitMessage,
    [string] $SyncWithConfigurations
)

import-module T3PALAppsBuilder

#update version number
if ((![System.String]::IsNullOrWhiteSpace($VersionBuild)) -and (![System.String]::IsNullOrWhiteSpace($VersionBuildOffset))) {
    $VersionBuild = (([int]$VersionBuild) + ([int]$VersionBuildOffset)).ToString()
}
if ((![System.String]::IsNullOrWhiteSpace($VersionRevision)) -and (![System.String]::IsNullOrWhiteSpace($VersionRevisionOffset))) {
    $VersionRevision = (([int]$VersionRevision) + ([int]$VersionRevisionOffset)).ToString()
}
if ((![System.String]::IsNullOrWhiteSpace($VersionMajor)) -or (![System.String]::IsNullOrWhiteSpace($VersionMinor)) -or (![System.String]::IsNullOrWhiteSpace($VersionBuild)) -or (![System.String]::IsNullOrWhiteSpace($VersionRevision))) {
    [string] $folderVersion = Set-T3PALFolderVersion -Path $Path -Major $VersionMajor -Minor $VersionMinor -Build $VersionBuild -Revision $VersionRevision -Configuration $BCConfiguration -SyncVersionWithConfigurations $SyncWithConfigurations

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

