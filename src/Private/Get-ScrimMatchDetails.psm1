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

$characters = Get-ScrimCharacters

20:00:45  + end 5 secs

.EXAMPLE

$ScrimChars = Get-ScrimCharacters

$Start = ([DateTime]'2021-02-07 20:00:45')

$Characters = $ScrimChars.CharacterId

Get-MatchDetails -Start $Start -Characters ()

NC 50 / TR 54

.EXAMPLE

$chars = @()

$chars += Get-ScrimCharacters -Group 'VCBC'
$chars += Get-ScrimCharacters -Group 'EDIM'

$events = Get-MatchEvents -Characters $chars.CharacterId -Start ([datetime]'2021-02-14 20:42:19') -Duration ([TimeSpan]::FromMinutes(25)) -KillsOnly

$events | Group-Object faction_id

#>
Function Get-MatchEvents {
	param (
		[byte]$WorldId = 19,
		[TimeSpan]$Duration = ([TimeSpan]::FromMinutes(15)),
		[DateTime]$Start,
		[string[]]$Characters,
		[switch]$KillsOnly
	)

	$End = $Start + $Duration

	$characterEvents = Get-PlanetSideTimeStream -Collection 'characters_event' -QueryProperties @{
		'character_id' = ($characters -join ',')
		'type' = 'KILL,DEATH,VEHICLE_DESTROY,FACILITY_CHARACTER'
	} -From $Start -To $End

	$findOthers = @()

	$findOthers += ($characterEvents | Select-Object -Expand character_id | Sort-Object | Select-Object -Unique)
	$findOthers += ($characterEvents | Select-Object -Expand attacker_character_id | Sort-Object | Select-Object -Unique)

	$otherChars = $findOthers | Sort-Object | Select-Object -Unique | Where-Object { $Characters -notcontains $_ }

	if ($otherChars) {
		$characterEvents += Get-PlanetSideTimeStream -Collection 'characters_event' -QueryProperties @{
			'character_id' = ($otherChars -join ',')
			'type' = 'KILL,DEATH,VEHICLE_DESTROY,FACILITY_CHARACTER'
		} -From $Start -To $End

		$characterEvents = $characterEvents | Sort-Object timestamp
	}

	$allChars = $Characters + $otherChars
	
	if (-not $KillsOnly) {
		$baseEvents = Get-PlanetSideTimeStream -Collection 'world_event' -QueryProperties @{
			'world_id' = $WorldId
			'type' = 'FACILITY'
		} -From $Start.AddHours(-1) -To $End.AddHours(1)

		$allEvents = Get-PlanetSideTimeStream -Collection 'event' -QueryProperties @{
			'type' = 'FACILITY_CHARACTER'
		} -From $Start.AddHours(-1) -To $End.AddHours(1) -Interval ([TimeSpan]::FromMinutes(1))
		
		$allEvents | Where-Object { $allChars.Contains($_.character_id) }
		
		$allEvents | Where-Object { $_.world_id -eq $WorldId }
	} else {
		$characterEvents
	}

	# [System.DateTimeOffset]::FromUnixTimeSeconds($characterEvents[0].timestamp)
	# [System.DateTimeOffset]::FromUnixTimeSeconds(1612729030)
	# [System.DateTimeOffset]::FromUnixTimeSeconds(1612728944)
}
<#

.NOTES 

<group tag>x<account name>[number]<faction suffix>

EDIMxPractice<incrementing number><faction suffixes>

.EXAMPLE


#>
Function Get-ScrimCharacters ([string]$Group = 'EDIM', [string]$Name) {
	if ($Name) {
		"${Group}x${Name}VS"
		"${Group}x${Name}NC"
		"${Group}x${Name}TR"
	} else {
		for ($i = 1; $i -lt 24; $i++) {
			$prefix = "${Group}xPractice${i}"

			$char = "${prefix}VS" | Get-CharacterId

			if (-not $char.CharacterId) {
				break
			}
			
			$char

			"${prefix}NC","${prefix}TR" | Get-CharacterId
		}
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

Function Get-Character {
	
}