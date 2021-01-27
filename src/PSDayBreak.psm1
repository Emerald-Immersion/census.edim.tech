<#

.EXAMPLE
$results = Get-PlanetSidePlayerItemDetails -PlayerName 'name'

$results | ? { $_.Name -like 'Flak Armor 5' } | ft

$results | ? { $_.Name -like 'Racer High Speed Chassis 1' } | ft

#>
Function Get-PlanetSidePlayerItemDetails ([string]$PlayerName) {
    $characters = Invoke-RestMethod "https://census.daybreakgames.com/get/ps2:v2/character/?name.first_lower=$($PlayerName.ToLower())&c:resolve=item_full(name.en)"

    $character = $characters.character_list[0]

    $profiles = Invoke-RestMethod 'https://census.daybreakgames.com/get/ps2:v2/profile?c:limit=100&c:show=profile_id,name.en'

    $item_profile = Invoke-RestMethod "https://census.daybreakgames.com/get/ps2:v2/characters_item?character_id=$($character.character_id)&c:join=type:item_profile^on:item_id^show:profile_id^inject_at:item_profile(type:profile^on:profile_id^show:name.en^inject_at:profile)"

    $item_vehicle = Invoke-RestMethod "https://census.daybreakgames.com/get/ps2:v2/characters_item?character_id=$($character.character_id)&c:join=type:vehicle_attachment^on:item_id^show:description"

    $profile_names = $profiles.profile_list | Group-Object profile_id -AsHashTable
    $item_names = $character.items | Group-Object item_id -AsHashTable
    $vehicle_names = $item_vehicle.characters_item_list | Group-Object item_id -AsHashTable

    $item_profile.characters_item_list | ForEach-Object {
        $item_id = $_.item_id
        $profile_id = $_.item_profile.profile_id
        [pscustomobject]@{
            ID = $item_id
            Name = $item_names[$item_id].name.en
            Profile = $(if ($profile_id) { $profile_names[$profile_id] }).name.en
            Vehicle = $(if ($vehicle_names.ContainsKey($item_id)) { $vehicle_names[$item_id].item_id_join_vehicle_attachment.description })
        }
    }
}
<#

.DESCRIPTION
Simple loop through available API data to grab examples.

.PARAMETER Path
The path of your example data.

.PARAMETER IncludePersonal
Include character and outfit collections, for development, data is in .gitignore

.EXAMPLE

# cleanup errors
gci docs/example -file -recurse -exclude 'index.json' | ? { ($_ | gc -Raw) -like '*Missing Service ID*' } | remove-item
gci docs/example -file -recurse -exclude 'index.json' | ? { ($_ | gc -Raw) -like '*@{*' } | remove-item
gci docs/example -file -recurse -exclude 'index.json' | ? {
    $name = [IO.Path]::GetDirectoryName($_.DirectoryName)

    $data = ($_ | gc -Raw | ConvertFrom-Json)

    -not $data.returned
} | Remove-Item

# small datasets
gci docs/example -file -recurse -exclude 'index.json' | ? {
    $name = [IO.Path]::GetDirectoryName($_.DirectoryName)

    $data = ($_ | gc -Raw | ConvertFrom-Json)

    $data.returned -and $data.returned -lt 1000
} | % { "'$([IO.Path]::GetFileName($_.DirectoryName))'" }

# large datasets
gci docs/example -file -recurse -exclude 'index.json' | ? {
    $name = [IO.Path]::GetDirectoryName($_.DirectoryName)

    $data = ($_ | gc -Raw | ConvertFrom-Json)

    $data.returned -and $data.returned -eq 1000
} | % { "'$([IO.Path]::GetFileName($_.DirectoryName))'" }

# personal datasets
gci docs/example -file -recurse -exclude 'index.json' | ? { 
    $_.FullName -like '*char*' -or $_.FullName -like '*outfit*'
} | % { "'$([IO.Path]::GetFileName($_.DirectoryName))'" }

#>
Function Sync-ExampleCensusData ([string]$Path, [switch]$IncludePersonal) {
    $ps2 = 'https://census.daybreakgames.com/get/ps2:v2'
    $limit = 1000

    $collections = Invoke-RestMethod $ps2

    $collections.datatype_list | ForEach-Object {
        $name = $_.name

        if ($IncludePersonal) {
            if ($name -like 'character*' -or $name -like 'outfit*') {
                Return
            }
        }

        $outputPath = [IO.Path]::Combine($Path, $name)
        $outputName = [IO.Path]::Combine($outputPath, "${limit}.json")

        if ([IO.File]::Exists($outputName)) {
            Return
        }

        $page = $null

        $next

        while (-not $page) {
            try {
                $page = Invoke-RestMethod $next

                if ($page.error -and $page.error -like '*Missing Service ID*') {
                    Write-Host "Throttled, waiting 5 seconds..."
                    $page = $null
                    Start-Sleep -Seconds 5                    
                } else {
                    break
                }
            } catch {
                Write-Host "Request failed, sleeping 5 seconds, probably throttling: $next"
                $_
                Start-Sleep -Seconds 5
            }
        }

        if ($page.error -or $page.errorCode) {
            Write-Warning "Collection returned error: $name"
            $page
        }

        if ($page.returned) {
            New-Item -ItemType Directory $outputPath -ErrorAction SilentlyContinue
    
            $page | ConvertTo-Json -Depth 99 | Out-File $outputName
        }
    }
}
<#

.DESCRIPTION


#>
Function Sync-LiveCensusData ([string]$DataFolder) {
    $ps2 = 'https://census.daybreakgames.com/get/ps2:v2'

    $collections = Invoke-RestMethod $ps2

    $datatype = @{}
    
    $collections.datatype_list | ForEach-Object {
        $name = $_.name
        
        $datatypeFolder = [IO.Path]::Combine($DataFolder, $name)

        $currentItems = Get-ChildItem -Path $datatypeFolder -File -Filter *.json | ForEach-Object {
            try {
                $s = $_.BaseName.Split('-', 2)

                $_ | Add-Member -NotePropertyName 'StartID' -NotePropertyValue [int]$s[0]
                $_ | Add-Member -NotePropertyName 'StopID' -NotePropertyValue [int]$s[1]

                $_ 
            } catch {
                Write-Warning "Error parsing file in data directory: $($_.FullName.SubString($datatypeFolder.Length))"
            }
        }
        
        $datatype[$name] = [pscustomobject]@{
            
        }
    }

}
<#

.EXAMPLE

$vehicle_attachment_pages = Get-PlanetSideMany -url 'https://census.daybreakgames.com/get/ps2:v2/vehicle_attachment/?' -start 0 -limit 5000

$vehicle_attachment = $vehicle_attachment_pages | Select-Object -Expand vehicle_attachment_list

Get-DataStream -Fetch {
    param([int]$Offset, [int]$Count)

    $result = Invoke-RestMethod "https://census.daybreakgames.com/get/ps2:v2/vehicle_attachment/?c:limit=$Count&c:start=$Offset"

    $result.vehicle_attachment_list
}


$vehicle_attachment_pages = Get-PlanetSideMany -url 'https://census.daybreakgames.com/get/ps2:v2/vehicle_attachment/?' -start 0 -limit 5000

#>
Function Get-PlanetSideMany ([string]$url, [int]$start, [int]$limit) {

    Get-DataStream -FromCount -ToCount -Limit 1000 -Fetch {
        param([int]$Offset, [int]$Count)

        $next = "${ps2}/${name}/?c:limit=${Count}&c:start=${Offset}"

        $page = $null

        $retries = 0
        
        while (-not $page) {
            try {
                $page = Invoke-RestMethod $next

                if ($page.error -and $page.error -like '*Missing Service ID*') {
                    Write-Host "Throttled, waiting 5 seconds..."
                    $page = $null
                    Start-Sleep -Seconds 5
                } else {
                    break
                }
            } catch {
                if ($retries -gt 3) {
                    throw $_
                }

                Write-Host "Request failed, sleeping 5 seconds, probably throttling: $next"

                $_

                Start-Sleep -Seconds 5

                $retries += 1
            }
        }

        if ($page.error -or $page.errorCode) {
            Write-Warning "Collection returned error: $name"
            $page
        }

        if ($page.returned) {

        }

        $_
    }

}

<#

.DESCRIPTION


.PARAMETER Fetch
Fetch is called with the parameters based on Time or Count.

This should return each object, so they can be counted.

param([DateTime]$StartTime, [DateTime]$EndTime)
param([int]$Offset, [int]$Count)

.PARAMETER FromCount
Count mode, should be the current number of items you have in the collection.

.PARAMETER ToCount
Count mode, ceiling of a max number of records to fetch.

.PARAMETER FromTime
Time mode, should be the newest item you have in the collection.

.PARAMETER ToCount
Time mode, ceiling of the max time of records to fetch.

.PARAMETER Limit
The limit of items that indicate there are more items.

If your Fetch function returns less than this, the loop will break assuming that it has
reached the end of the data stream.

#>
Function Get-DataStream  {
    param (
        [Parameter(Mandatory)][ScriptBlock]$Fetch,
        [Parameter(Mandatory,ParameterSetName='CountSet')][int]$FromCount,
        [Parameter(Mandatory,ParameterSetName='CountSet')][DateTime]$ToCount,
        [Parameter(Mandatory,ParameterSetName='DateSet')][DateTime]$FromTime,
        [Parameter(Mandatory,ParameterSetName='DateSet')][DateTime]$ToTime,
        [Parameter(Mandatory)][int]$Limit
    )

    if ($PSCmdlet.ParameterSetName -eq 'DateSet') {
        $offset = $FromTime

        while ($true) {
            $results = @(Invoke-Command -ScriptBlock $Fetch -ArgumentList $offset,$ToTime)
    
            if ($results.Length -ge $Limit) {
                
            }
        }
    } else {
        $offset = $FromCount

        while ($true) {
            $counter = 0
    
            try {
                Invoke-Command -ScriptBlock $Fetch -ArgumentList $offset,$Limit | ForEach-Object {
                    $counter += 1
                    $_
                }
            } catch {
                
            }
    
            if ($counter -lt $Limit) {
                break
            } else {
                $offset += $counter
            }
        }
    }

}
<#

.DESCRIPTION
Outputs a JSON file for a lookup table that can be diffed/compared easily.

If values do contain multiple lines it will output like that, but it will still be valid json.

.EXAMPLE

Get-ChildItem . | Select-Object Name,Length,LastWriteTime | ConvertTo-JsonLookup -PropertyId 'Name' -Depth 1

.EXAMPLE

@(
    [ordered]@{ "id" = 1; "text" = "foo" }
    [ordered]@{ "id" = 2; "text" = "foo" }
) | ConvertTo-JsonLookup -PropertyId 'id'

Output:

{
"1": { "id": 1, "text": "foo" }
,"2": { "id": 2, "text": "foo" }
}

#>
Function ConvertTo-JsonLookup {
    param (
        [Parameter(ValueFromPipeline)]$InputObject,
        [Parameter(Mandatory)][string]$PropertyId,
        [int]$Depth = 10
    )
    begin {
        "{"
        $prefix = ''
    }
    process {
        if (-not $_.$PropertyId) {
            Write-Error "One or more items do not have the specified PropertyID."
            Return
        }

        "$prefix`"$($_.$PropertyId)`": $($_ | ConvertTo-Json -Compress -Depth $Depth)"

        if (-not $prefix) {
            $prefix = ','
        }
    }
    end {
        '}'
    }
}
<#

.DESCRIPTION
Converts input objects to JSON, within an JSON object.

.EXAMPLE

{"Items":[
{ "id": 1 }
,{ "id": 2 }
,{ "id": 3 }
],"Count":3}

.NOTES
First item could be null to skip prefix check...

#>
Function ConvertTo-JsonStream {
    param (
        [Parameter(ValueFromPipeline)]$InputObject,
        [int]$Depth = 10,
        [switch]$NoCount
    )
    begin {
        [uint64]$count = 0

        '{"Items":['
    }
    process {
        "$prefix$($_ | ConvertTo-Json -Compress -Depth $Depth)"

        $count += 1

        if (-not $prefix) {
            $prefix = ','
        }
    }
    end {
        if ($NoCount) {
            ']}'
        } else {
            "],`"Count`":$count}"
        }
    }
}