Import-Module ./src/EdimCensus.psm1

<#

.DESCRIPTION
Updates website data.

#>
Function Invoke-Update {
    # TODO: Run updates...
    
    # Get-JsonIndex -Path './docs/data' | ConvertTo-Json -Depth 10 | Out-File './docs/data/index.json'
    
    # Sync-ExampleCensusData -Path './docs/data/ps2_v2'

    Get-JsonIndex -Path './docs/data' | ConvertTo-Json -Depth 10 | Out-File './docs/data/index.json'
}
<#

#>
Function Get-JsonIndex ($Path) {
    $ht = [ordered]@{}

    Get-ChildItem -Path $Path -Exclude 'index.json','character*','outfit*' | ForEach-Object {
        if ($_.PSIsContainer) {
            $ht["/$($_.Name)"] = Get-JsonIndex -Path $_.FullName
        } else {
            $ht[$_.Name] = [ordered]@{
                Length = $_.Length
                LastWriteTimeUtc = [DateTimeOffset]::new($_.LastWriteTimeUtc).ToUnixTimeMilliseconds()
            }
        }
    }

    [pscustomobject]$ht
}

if (-not $psISE -and -not $psEditor) {
    Invoke-Update
}
