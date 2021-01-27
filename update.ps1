Import-Module ./src/PSDayBreak.psm1

# TODO: Run updates...

# Get-JsonIndex -Path './docs/data' | ConvertTo-Json -Depth 10 | Out-File './docs/data/index.json'

Get-JsonIndex -Path './docs/example' | ConvertTo-Json -Depth 10 | Out-File './docs/example/index.json'

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