
<#

.DESCRIPTION

Be careful with this, it will keep going if you dont constrain it.

.PARAMETER Collection
The collection name, see New-DBApiUrl.

.PARAMETER Query
The query, see New-DBApiUrl.

.PARAMETER QueryProperties
The query as a hashtable, see New-DBApiUrl.

.PARAMETER From
The count to start from.

To use this properly you must have a consitant logical Sort order.

.PARAMETER To
The absolute max number of records, defaults to 20000 to prevent mistakes.

.PARAMETER Limit
The limit of items to get per request.

Must be less than or equal to the max limit of the API, usually 1000.

If the limit is actually less than given, the loop will stop after the first results.

.EXAMPLE

Get-PlanetSideDataStream -Collection 'weapon' 

#>
Function Get-PlanetSideDataStream {
    param (
        [Parameter(Mandatory)][string]$Collection,
        [string]$Query,
        [HashTable]$QueryProperties,
        [int]$From,
        [int]$To = 20000,
        [int]$Limit = 1000,
        [string]$ListName
    )

    $listProperty = if ($ListName) {
        $ListName
    } else {
        "${Collection}_list"
    }

    $splat = @{
        Collection = $Collection
        Query = $Query
        QueryProperties = @{}
    }

    if ($QueryProperties) {
        $QueryProperties.Keys | ForEach-Object {
            $splat.QueryProperties.$_ = $QueryProperties[$_]
        }
    }

    $splat.QueryProperties.'c:limit' = $Limit

    Get-DataStream -From $From -To $To -Limit $Limit -Fetch {
        param([int]$Offset)

        $splat.QueryProperties.'c:start' = $Offset

        $url = New-DBApiUrl @splat
    
        $result = Invoke-DBApi -Url $url
        
        if ($result -and $result.$listProperty) {
            $result.$listProperty
        }
    }
}
<#

.DESCRIPTION
This is needed for event streams because c:start does not work with them.

.PARAMETER TimeStampProperty
Usually the default is for events which use their own after/before criteria.

This may not be needed if Get-PlanetSideDataStream works properly for these queries.

If TimeStampProperty is supplied, it changes to using the specified property criteria.

New/Recent characters: times.creation
Recent/Active characters: times.last_login / times.last_save

Recent Achievements/Directives, characters_achievement_list: start / last_save / finish
Recent Achievements/Directive Tree, characters_directive_tree: completion_time

Recent Stats, characters_stat: last_save
Recent Faction Stats, characters_stat_by_faction: last_save
New Outfits, outfit: time_created
New Outfit Members, outfit_member: member_since

.EXAMPLE


#>
Function Get-PlanetSideTimeStream {
    param (
        [Parameter(Mandatory)][string]$Collection,
        [string]$Query,
        [HashTable]$QueryProperties,

        [DateTime]$From,
        [DateTime]$To,
        [int]$Limit = 1000,

        [TimeSpan]$Interval = [TimeSpan]::FromHours(24),
        [TimeSpan]$IntervalMin = [TimeSpan]::FromSeconds(1),
        [TimeSpan]$IntervalMax = [TimeSpan]::FromDays(7),
        [double]$IntervalRate = 0.1,

        [string[]]$TimeStampProperty,
        [string]$ListName
    )

    $listProperty = if ($ListName) {
        $ListName
    } else {
        "${Collection}_list"
    }

    Get-TimeStream -From $From -To $To -Limit $Limit -Interval $Interval `
    -IntervalMin $IntervalMin -IntervalMax $IntervalMax -IntervalRate $IntervalRate `
    -Fetch {
        param([DateTime]$StartTime, [DateTime]$EndTime)

        $after = [System.DateTimeOffset]::new($StartTime).ToUnixTimeSeconds()
        $before = [System.DateTimeOffset]::new($EndTime).ToUnixTimeSeconds()

        $splat = @{
            Collection = $Collection
            Query = $Query
            QueryProperties = @{}
        }

        if ($QueryProperties) {
            $QueryProperties.Keys | ForEach-Object {
                $splat.QueryProperties[$_] = $QueryProperties[$_]
            }
        }

        $splat.QueryProperties['c:limit'] = $Limit
    
        if ($TimeStampProperty) {
            $TimeStampProperty | ForEach-Object {
                $splat.QueryProperties[$_] = "[$after"
                $splat.QueryProperties[$_] = "]$before"
            }
            
            $url = New-DBApiUrl @splat -Count
        
            $result = Invoke-DBApi -Url $url

            if ($result.count -eq 0) {
                Return
            }
            
            if ($result.count -ge $Limit) {
                throw $Limit
            }
        } else {
            $splat.QueryProperties['before'] = $before
            $splat.QueryProperties['after'] = $after
        }

        $url = New-DBApiUrl @splat
    
        $result = Invoke-DBApi -Url $url
        
        if ($result -and $result.$listProperty) {
            $result.$listProperty
        }
    }
}
<#

.DESCRIPTION
Multiple searches can be done in one request, but it is sensible to limit the amount done
in a single query.

.EXAMPLE

1..100 | Get-PlanetSideDataBatch -Collection 'character_name' -BatchProperty 'name.first_lower' -QueryProperties @{
    'c:show' = 'character_id'
} | Select -Expand character_id

#>
Function Get-PlanetSideDataBatch {
    param (
        [Parameter(ValueFromPipeline)][string[]]$InputObject,
        [Parameter(Mandatory)][string]$Collection,
        [string]$Query,
        [HashTable]$QueryProperties,
        [int]$From,
        [int]$To = 20000,
        [int]$Limit = 1000,
        [string]$ListName,

        [Parameter(Mandatory)][string]$BatchProperty,
        [int]$BatchCount = 100,
        [int]$BatchLength = 1KB
    )
    begin {
        $batch = @()

        $splat = @{
            Collection = $Collection
            Query = $Query
            QueryProperties = @{}
            From = $From
            To = $To
            ListName = $ListName
        }
        
        if ($QueryProperties) {
            $QueryProperties.Keys | ForEach-Object {
                $splat.QueryProperties[$_] = $QueryProperties[$_]
            }
        }

        $count = 0
    }
    process {
        $batch += $_

        $currentBatch = $batch -join ','

        if ($batch.Count -lt $BatchCount -and $currentBatch.Length -lt $BatchLength) {
            Return
        }

        $splat.QueryProperties.$BatchProperty = $currentBatch
        
        Get-PlanetSideDataStream @splat | ForEach-Object { $count += 1; $_ }

        if ($count -gt 0) {
            if ($From) {
                $splat.From = 0
            }
        } elseif ($To) {
            if ($count -gt $To) {
                Write-Warning "To Limit reached: $To"
                Break
            } else {
                $splat.To = $To - $count
            }
        }
    }
    end {
        if ($batch.Count -gt 0) {
            $splat.QueryProperties.$BatchProperty = $batch -join ','
            
            Get-PlanetSideDataStream @splat
        }
    }
}
