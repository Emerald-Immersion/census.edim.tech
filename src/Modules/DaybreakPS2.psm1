#Requires -Modules DayBreak

<#

.DESCRIPTION
Creates a DayBreak API Url for PlanetSide 2 with the given parameters.

Documentation here: https://census.daybreakgames.com/

.PARAMETER Collection
The collection name, can be left empty to give the list of collections.

.PARAMETER Count
Perform a Count query to only return the count for the given query, does not work for everything and may return -1.

.PARAMETER Query
The query string, with or without the ? prefix.

.PARAMETER QueryProperties
The query but with a hash table of Key/Value pairs.

#>
Function New-DBPS2_ApiUrl {
    param (
        [string]$Collection,
        [switch]$Count,
        [string]$Query,
        [HashTable]$QueryProperties
    )

    New-DBApiUrl -NameSpace 'ps2:v2' @PSBoundParameters
}
<#

.EXAMPLE
$collections = Get-DBPS2_Collection

#>
Function Get-DBPS2_Collection {
    $url = New-DBPS2_ApiUrl

    $result = Invoke-DBApi -Url $url

    if (-not $result -or -not $result.returned) {
        Return
    }

    $result.datatype_list
}
<#

.DESCRIPTION 
Performs a query for each collection to get the real item count.

.PARAMETER IncludeCharacter
Character collections exceed 13 million so far, counts are arbitary.

.PARAMETER Force
Use the force, to always resolve the count even if its not a question mark (?).

.EXAMPLE

$collections | Resolve-DBPS2_CollectionCount -PassThru | Out-Host

#>
Function Resolve-DBPS2_CollectionCount ([switch]$PassThru, [switch]$Force, [switch]$IncludeCharacter) {
    process {
        if (-not $Force -and $_.count -ne '?') {
            return
        }

        if ((-not $IncludeCharacter) -and $_.Name -like 'character*') {
            return
        }

        $url = New-DBPS2_ApiUrl -Count -Collection $_.name

        $result = Invoke-DBApi -Url $url

        if ($result -and $result.count) {
            $_.count = $result.count
        }

        if ($PassThru) {
            $_
        }
    }
}
<#

#>
Function Get-DBPS2_Character {
    param (
        [string]
        $Name,
        [switch]$JoinItems
        #[parameter(ValueFromPipelineByPropertyName = 'character_id')]
        #[int64[]]
        #$Id
    )

    $query = [ordered]@{}

    $query['name.first_lower'] = $Name.ToLower()

    if ($JoinItems) {
        $query['c:resolve'] = 'item_full(name.en)'
    }
    
    $url = New-DBPS2_ApiUrl -Collection 'character' -QueryProperties $query

    $result = Invoke-DBApi -Url $url

    if ($result) {
        if (-not $result.returned) {
            Write-Error "Character with the name '$Name' was not found"
            Return
        }

        if ($result.character_list) {
            $result.character_list
        }
    }
}
<#

#>
Function Resolve-DBPS2_CharacterItem {
    param (

    )
    begin {

    }
    process {

    }
    end {

    }
}
<#

#>
Function Resolve-DBPS2_CharacterItemDetail {

}
<#

.EXAMPLE
$results = Get-PlanetSidePlayerItemDetails -PlayerName 'name'

$results | ? { $_.Name -like 'Flak Armor 5' } | ft

$results | ? { $_.Name -like 'Racer High Speed Chassis 1' } | ft

#>
Function Get-DBPS2_PlayerItemDetails ([string]$PlayerName) {
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

.SYNOPSIS


.EXAMPLE

Get-Outfit -Tag 'EDIM'

#>
Function Get-Outfit {
    param (
        [string]$Tag,
        [switch]$ResolveMembers
    )

    $query = [ordered]@{}

    $query['alias_lower'] = $Tag.ToLower()

    if ($ResolveMembers) {
        $query['c:resolve'] = 'member,member_online_status,member_character'
    }
    
    $url = New-DBPS2_ApiUrl -Collection 'outfit' -QueryProperties $query

    $result = Invoke-DBApi -Url $url

    if ($result) {
        if (-not $result.returned) {
            Write-Error "Outfit with the tag '$Tag' was not found"
            Return
        }

        if ($result.outfit_list) {
            $result.outfit_list
        }
    }
}

Function Get-PlayerStats {
    param (
        [Parameter(ValueFromPipelineByPropertyName='character_id')][string[]]$CharacterId
    )
    
    
}