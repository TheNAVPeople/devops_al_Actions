param (
    [string] $Path
)

$settingsPath = Join-Path -Path $Path -ChildPath ".github\TNP-Settings.json"

if (Test-Path -Path $settingsPath -PathType Leaf) {
    [PSObject]$data = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($null -ne $data) {
        $data.psobject.properties | ForEach-Object { 
            [string]$name = $_.Name 
            [string]$value = ""
            if ($_.Value -is [string]) {
                $value = $_.Value
            } else {
                #write first array entry from the list property to the main variables
                if (($_.TypeNameOfValue -eq "System.Object[]") -and ($_.Value.Count -ge 1)) {
                    $singleItem = $_.Value.Get(0)
                    $singleItem.psobject.properties | ForEach-Object { 
                        [string]$itemName = ($name + "_" + $_.Name)
                        $itemValue = $_.Value
                        Write-Output "$itemName=$itemValue" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
                    }
                }

                $value = ConvertTo-Json $_.Value -Compress
            }
            Write-Output "$name=$value" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        }
    }
}

