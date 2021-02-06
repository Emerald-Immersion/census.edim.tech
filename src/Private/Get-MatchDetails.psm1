#Requires -Modules DayBreakPS2
#Requires -Modules JsonObject
#Requires -Modules DataSync

<#

.OUTPUTS

@(
	@{
		Name = ''
		Match = ''
		
		Points = 0
		Score = 0
		Kills = 0
		Deaths = 0
		HeadshotRatio = 0.5
	}
)

.EXAMPLE



$tsv = @'
Account,Player
EDIMxPractice1VS,
'@

EDIMxPractice7

7,3,4,6,11

5,1,9,8,2

1,2,3,4,5,6,7,8,9,11 | % {
	"EDIMxPractice${_}VS"
	"EDIMxPractice${_}NC"
	"EDIMxPractice${_}TR"
} | % {
    $url = New-DBPS2_ApiUrl -Collection 'character' -QueryProperties $query

	$result = Invoke-DBApi -Url $url
}


$to = [datetime]'02/01/2021 00:00:00'
$from = [datetime]'01/29/2021 00:00:00'

$after = [System.DateTimeOffset]::new($from).ToUnixTimeSeconds()
$before = [System.DateTimeOffset]::new($to).ToUnixTimeSeconds()

$results5 = Get-PlanetSideTimeStream -Collection 'world_event' -Query '?world_id=19' -From $from -To $to | % {
	$_ | Write-Host
	$_
}

$results4 = @()

Get-PlanetSideDataStream -Collection 'world_event' -Query "?world_id=19&before=$before&after=$after" | % {
	$results4 += $_
}

$a = $results5

$b = $results5 | select –unique

Compare-object –referenceobject $b –differenceobject $a

#>
Function Get-MatchDetails {
	param (
		$WorldId = 19
		
	)

	
	$characters = Get-ScrimCharacters

	$querylist = $characters.CharacterId -join ','

	Get-PlanetSideTimeStream -Collection 'world_event' -QueryProperties @{
		'character_id' = $querylist
		'type' = 'DEATH,VEHICLE_DESTROY,FACILITY_CHARACTER'
	}

	$url = New-DBApiUrl -Collection 'characters_event' -QueryProperties @{
		'character_id' = $querylist
		'type' = 'DEATH,VEHICLE_DESTROY,FACILITY_CHARACTER'
		'c:limit' = 1000
	}

	$result = Invoke-DBApi -Url $url
	
	$measure = $result.characters_event_list | Measure-Object timestamp -Minimum -Maximum

	$from = $measure.Minimum
	$to = $measure.Maximum

	Get-PlanetSideDataStream -Collection 

	# [System.DateTimeOffset]::FromUnixTimeSeconds(1611519229)
}
<#

.NOTES 

<group tag>x<account name>[number]<faction suffix>

EDIMxPractice<incrementing number><faction suffixes>

.EXAMPLE


#>
Function Get-ScrimCharacters ([string]$Outfit = 'EDIM') {
	begin {

	}
	process {
		
		1,2,3,4,5,6,7,8,9,11 | ForEach-Object {
			"${Outfit}xPractice${_}VS"
			"${Outfit}xPractice${_}NC"
			"${Outfit}xPractice${_}TR"
		} | Get-CharacterId
	
	}
	end {

	}

}
<#

#>
Function Get-CharacterId {
	process {
		$name = $_


		
		$url = New-DBPS2_ApiUrl -Collection 'character_name' -QueryProperties @{
			'name.first_lower' = $name.ToLower()
			'c:show' = 'character_id'
		}

		$result = Invoke-DBApi -Url $url

		$obj = @{
			CharacterName = $name
			CharacterId = ''
		}

		if ($result) {
			$obj.CharacterId = $result.character_name_list[0].character_id
		}

		[pscustomobject]$obj
	}
}
