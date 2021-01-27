Import-Module ./src/PSDayBreak.psm1

<#

.DESCRIPTION
Collects all data needed for development.

#>
Function Invoke-Build {

    Sync-ExampleCensusData -Path './docs/example' -IncludePersonalData
    
    
}

if (-not $psISE -and -not $psEditor) {
    Invoke-Build
}