<#

.EXAMPLE

$Characters = '8291480109032492129'

logged in: ([datetime]'2021-02-07T15:54:15')

session duration: 33:50



https://census.daybreakgames.com/s%3Aexample/get/ps2%3Av2/event/?type=DEATH%2CKILL%2CVEHICLE_DESTROY%2CFACILITY_CHARACTER&after=1612137600&character_id=8291480109032492129&c%3Alimit=1000&before=1612224000

#>
Function Get-MatchDetails {
	param (
        [string[]]$Characters,
        [DateTime]$FromDate,
        [DateTime]$ToDate,
        $WorldId = 10,
        $ZoneId
	)

    $characterList = $Characters -join ','
    
	$events = Get-PlanetSideTimeStream -Collection 'characters_event' -QueryProperties @{
		'character_id' = $characterList
		'type' = 'DEATH,KILL,VEHICLE_DESTROY,FACILITY_CHARACTER'
	} -From ([datetime]'2021-02-07T15:54:15') -To ([datetime]'2021-02-07T15:54:15').AddSeconds((33*60)+50)

    # https://census.daybreakgames.com/get/ps2:v2/world_event/?type=FACILITY&c:limit=10

    $facilityEvents = Get-PlanetSideTimeStream -Collection 'world_event' -QueryProperties @{
        'type' = 'FACILITY'
    } -From ([datetime]'2021-02-07T15:54:15') -To ([datetime]'2021-02-07T15:54:15').AddSeconds((33*60)+50)



    $facilities = $events | ? { $_.table_type -eq 'facility_character_event' }

    $facilities | Sort-Object timestamp {

        
        [pscustomobject]@{
            
        }
    }
}

Function Group-Range {

}
