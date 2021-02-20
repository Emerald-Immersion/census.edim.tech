#Requires -Modules DayBreakPS2
#Requires -Modules JsonObject
#Requires -Modules DataSync

<#

.DESCRIPTION
The different classifications of data are:

Character = 13 million records
Outfit = 253k records with 1.3m member records

Small < 1000 records, usually lookup tables
Medium < 10k records, most collections
Large > 10k records, usually relationship tables


.EXAMPLE

$Destination = 'docs/data/ps2_v2'

#>
Function Sync-LiveCensusData ([string]$Destination) {
    $collectionsFile = [IO.Path]::Combine($Destination, 'collections.json')

    if (-not [IO.File]::Exists($collectionsFile)) {
        Sync-SampleCensusData
    }
    
    $collections = Get-Content $collectionsFile | ConvertFrom-Json

    $ignore = @(
        # Exclude player data and require specific queries
        'characters_event'
        'characters_event_grouped'
        'characters_friend'
        'characters_item'
        'characters_leaderboard'
        'characters_online_status'
        'single_character_by_id'

        'directive_tier'
        
        # Require specific queries
        'event'
        'leaderboard'
        'map'

        # pointless really
        'image'
        'image_set'
    )

    $easy = $collections | Where-Object { $ignore -notcontains $_.name -and 
        $_.PrimaryKey -and $_.count -gt 0 -and $_.count -lt 100000 
    }
    
    $easy | ForEach-Object {
        $collection = $_

        $collectionFolder = [IO.Path]::Combine($Destination, $collection.name)

        New-Item -ItemType Directory -Path $collectionFolder -ErrorAction SilentlyContinue | Out-Null
        
        $existing = @(Get-ChildItem $collectionFolder -File | Where-Object { $_.Name -match '[0-9]+.json' })

        $offset = 0
        
        if ($existing.Count -gt 1) {
            $offset = (($existing.Count - 1) * 1000)
        }

        Get-PlanetSideDataStream -Collection $collection.name -From $offset | Sort-Object $collection.PrimaryKey | Group-Stream { 
            $id = $_.$($collection.PrimaryKey); ($id - ($id % 1000))
        } | ForEach-Object {
            $collectionFile = [IO.Path]::Combine($collectionFolder, "$($_.Name).json")

            $_.Group | ConvertTo-JsonLookup -PropertyId $collection.PrimaryKey | Out-File $collectionFile
        }
    }

    
    # $collections | Where-Object { $easy -notcontains $_ -and $_.count -gt 0 -and $_.count -lt 100000 } | ft
}