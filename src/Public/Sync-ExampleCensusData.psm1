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

$Destination = 'docs/data/ps2_v2_example'

Sync-ExampleCensusData -Destination $Destination

#>
Function Sync-ExampleCensusData ([string]$Destination, [switch]$IncludePersonal, [switch]$Refresh, [switch]$Force) {
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

        if ((-not $IncludePersonal) -and ($_.name -like '*character*' -or $_.name -like '*outfit*')) {
            Write-Host -ForegroundColor Yellow "Skipping collection, personal: $($_.name)"
            Return
        }

        if ((-not $Force) -and $_.count -eq '?' -or $_.count -eq 'dynamic') {
            Write-Host -ForegroundColor Yellow "Skipping collection, size: $($_.name)"
            Return
        }

        $outputPath = [IO.Path]::Combine($Destination, $_.name)
        $outputName = [IO.Path]::Combine($outputPath, "1000.json")
        
        $listName = "$($collection.name)_list"

        if ((-not $Refresh) -and [IO.File]::Exists($outputName)) {
            Write-Host -ForegroundColor Green "Skipping collection, exists: $($_.name)"
            Return
        }
        
        $ht = [ordered]@{
            'c:limit' = 1000
        }

        Write-Host "Collection, request: $($_.name)"

        $url = New-DBApiUrl -Collection $_.name -QueryProperties $ht

        $result = Invoke-DBApi -Url $url

        if ($result.returned) {
            New-Item -ItemType Directory $outputPath -ErrorAction SilentlyContinue
    
            $result | ConvertTo-Json -Depth 99 | Out-File $outputName
            
            Write-Host -ForegroundColor Green "Collection, response: $($_.name)"

            if ($result.$listName) {
                $props = $result.$listName | Get-JsonObjectPath -PropertyPath '' # $collection.name

                $collection | Add-Member -NotePropertyName 'Properties' -NotePropertyValue $props -Force
            }
        }
    }
    
    $collections | ForEach-Object {
        $collection = $_

        if ($collection.Properties) {
            Return
        }

        $outputPath = [IO.Path]::Combine($Destination, $collection.name)
        $outputName = [IO.Path]::Combine($outputPath, "1000.json")

        $listName = "$($collection.name)_list"

        $result = Get-Content $outputName | ConvertFrom-Json -Depth 10

        if ($result.$listName) {
            $props = $result.$listName | Get-JsonObjectPath -PropertyPath '' # $collection.name

            $collection | Add-Member -NotePropertyName 'Properties' -NotePropertyValue $props -Force

            $props
        }
    }

    $collections | ForEach-Object {
        $collection = $_
        
        $collection | Add-Member -NotePropertyName 'PrimaryKey' -NotePropertyValue '' -Force

        $idName = "$($collection.name)_id"

        if ($collection.Properties -contains $idName) {
            $collection.PrimaryKey = $idName
        }
    }
    
    $collections | ForEach-Object {
        $collection = $_

        $rels = $collections | Where-Object {
            $_ -ne $collection -and  
            $_.Properties -contains $collection.PrimaryKey
        }

        $collection | Add-Member -NotePropertyName 'Relationships' -NotePropertyValue $rels.name -Force
    }
    
    $collections | ConvertTo-Json -Depth 10 | Out-File $collectionsFile
}

