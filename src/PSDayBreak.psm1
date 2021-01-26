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

.EXAMPLE

gci data -file -recurse | ? { ($_ | gc -Raw) -like '*Missing Service ID*' } | remove-item

gci data -file -recurse | ? { ($_ | gc -Raw) -like '*@{*' } | remove-item

gci data -file -recurse | ? {
    $name = [IO.Path]::GetDirectoryName($_.DirectoryName)

    $data = ($_ | gc -Raw | ConvertFrom-Json)

    -not $data.returned
} | gc

#>
Function Sync-PlanetSideData ($OutputFolder) {
    $ps2 = 'https://census.daybreakgames.com/get/ps2:v2'

    $collections = Invoke-RestMethod $ps2

    $limit = 1000
    $offset = 0

    $collections.datatype_list | ForEach-Object {
        $name = $_.name

        $outputName = [IO.Path]::Combine($OutputFolder, "data/${name}/${offset}-${limit}_example.json")

        if ([IO.File]::Exists($outputName)) {
            Return
        }

        $next = "${ps2}/${name}/?c:limit=$limit&c:start=$offset"

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

        New-Item -ItemType Directory "data/${name}" -ErrorAction SilentlyContinue

        $page | ConvertTo-Json -Depth 99 | Out-File $outputName
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
    $offset = 0 + $start

    while ($true) {
        $next = "${url}c:limit=$limit&c:start=$offset"

        Write-Host $next

        try {
            $page = Invoke-RestMethod $next

            if ($page.returned) {
                
            }
        } catch {
            Write-Host "Request failed, sleeping 5 seconds, probably throttling: $next"
            $_
            Start-Sleep -Seconds 5
            continue
        }

        $page

        if ($page.returned -ne $limit) {
            break
        }

        $offset += $limit
    }
}

<#

.DESCRIPTION


.PARAMETER Fetch
Fetch is called with the parameters based on Time or Count.

This should return an array of objects.

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
            $results = Invoke-Command -ScriptBlock $Fetch -ArgumentList $offset,$ToTime
    
            if ($results.Length -ge $Limit) {
                
            }
        }
    } else {
        $offset = $FromCount

        while ($true) {
            $counter = 0
    
            Invoke-Command -ScriptBlock $Fetch -ArgumentList $offset,$Limit | ForEach-Object {
                $counter += 1
                $_
            }
    
            if ($counter -lt $Limit) {
                break
            } else {
                $offset += $counter
            }
        }
    }

}
