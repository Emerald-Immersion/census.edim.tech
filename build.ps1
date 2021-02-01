Import-Module ./src/EdimCensus.psm1

<#

.DESCRIPTION
Collects all data needed for development.

#>
Function Invoke-Build {
    $settings = Get-Content -Path './settings.json' -ErrorAction SilentlyContinue | ConvertFrom-Json

    if ($settings) {
        $settings.PSObject.Properties | ForEach-Object {
            Set-Variable -Scope 'Global' -Name $_.Name -Value $_.Value
        }
    }
    
    Sync-ExampleCensusData -Destination './docs/data/ps2_v2_example'
}

if (-not $psISE -and -not $psEditor) {
    Invoke-Build
}