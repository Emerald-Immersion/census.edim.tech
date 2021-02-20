#Requires -Modules DayBreakPS2
#Requires -Modules JsonObject

<#

.DESCRIPTION
Simple loop through available API data to grab examples.

.PARAMETER Destination
The path of your example data.

.PARAMETER IncludePersonal
Include character and outfit collections, for development, data is in .gitignore

.PARAMETER Refresh
Recollect data even if it exists.

.PARAMETER Force
Use the force, to attempt all collections.

.EXAMPLE

$Destination = 'docs/data/ps2_v2'

Sync-SampleCensusData -Destination $Destination

#>
Function Sync-SampleCensusData ([string]$Destination, [switch]$Refresh, [switch]$Force) {
    $collectionsFile = [IO.Path]::Combine($Destination, 'collections.json')

    $collections = @()

    if (-not $Refresh -and [IO.File]::Exists($collectionsFile)) {
        $collections = Get-Content $collectionsFile | ConvertFrom-Json
    } else {
        $collections = Get-DBPS2_Collection

        $collections | Resolve-DBPS2_CollectionCount -PassThru | Out-Host

        $collections | ConvertTo-Json -Depth 10 | Out-File $collectionsFile
    }

    $collections | ForEach-Object {
        $collection = $_

        $collection | Add-Member -NotePropertyName 'Items' -NotePropertyValue @() -Force

        if ((-not $Force) -and $_.count -eq '?' -or $_.count -eq 'dynamic') {
            Write-Host -ForegroundColor Yellow "Skipping collection, size: $($_.name)"
            Return
        }

        $outputPath = [IO.Path]::Combine($Destination, $_.name)

        $outputName = [IO.Path]::Combine($outputPath, "sample.json")
        
        $listName = "$($collection.name)_list"

        if ((-not $Refresh) -and [IO.File]::Exists($outputName)) {
            $sample = Get-Content $outputName | ConvertFrom-Json -Depth 10

            if ($sample.$listName) {
                $collection.Items = $sample.$listName
            }

            Return
        }
        
        Write-Host "Collection, request: $($_.name)"

        $url = New-DBApiUrl -Collection $_.name -QueryProperties @{
            'c:limit' = 1000
        }

        $result = Invoke-DBApi -Url $url

        if ($result.returned) {
            New-Item -ItemType Directory $outputPath -ErrorAction SilentlyContinue | Out-Null
    
            $result | ConvertTo-Json -Depth 99 | Out-File $outputName
            
            Write-Host -ForegroundColor Green "Collection, response: $($_.name)"

            if ($result.$listName) {
                $collection.Items = $result.$listName                
            }
        } else {
            Write-Host -ForegroundColor Red "Collection, invalid: $($_.name)"
        }
    }

    Resolve-DataRelationships -Collections $collections

    $collections | Select-Object -Exclude Items * | ConvertTo-Json -Depth 10 | Out-File $collectionsFile
}

