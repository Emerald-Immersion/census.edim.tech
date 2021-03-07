
<#

.EXAMPLE

$splat = @{
    OutfitTag = 'EDIM'
    FromDate = [datetime]'2021-03-06 18:45:00'
    ToDate = [datetime]'2021-03-06 20:15:00'
    ZoneId = '1311081'
}

$scores = Get-OutfitActivity @splat

$scores | ? { $_.Kills -gt 0 } | Sort-Object -Descending Kills | Format-Table


#>
Function Get-OutfitActivity {
    param(
        [string]$OutfitTag,
        [DateTime]$FromDate,
        [DateTime]$ToDate,
        [string]$ZoneId
    )
    
    $InformationPreference = 'Continue'

    $outfit = Get-Outfit -Tag $OutfitTag -ResolveMembers

    $recentMembers = $outfit.members | Where-Object { [System.DateTimeOffset]::FromUnixTimeSeconds($_.times.last_login) -ge $FromDate -or [System.DateTimeOffset]::FromUnixTimeSeconds($_.times.last_save) -ge $FromDate }

    $recentMembers | ForEach-Object { $_ | Add-Member -MemberType NoteProperty -Name characters_event -Value @() -Force }

    $memberLookup = $recentMembers | Group-Object -AsHashTable character_id

    $otherEvents = @()
    
    Get-PlanetSideTimeStream -Collection 'characters_event' -From $FromDate -To $ToDate -Interval ([TimeSpan]::FromSeconds(2869)) -QueryProperties @{
        'character_id' = $recentMembers.character_id -join ','
        'type' = 'KILL,DEATH,VEHICLE_DESTROY,FACILITY_CHARACTER'
    } | ForEach-Object {
        if (-not $ZoneId -or ($ZoneId -and $_.zone_id -eq $ZoneId)) {
            if ($memberLookup.ContainsKey($_.character_id)) {
                $memberLookup[$_.character_id][0].characters_event += $_
            } elseif ($memberLookup.ContainsKey($_.attacker_character_id)) {
                $memberLookup[$_.attacker_character_id][0].characters_event += $_
            } else {
                $otherEvents += $_
            }
        }

        $_
    } | Write-Benchmark -NoOutput -Progress

    #$facilityEvents = Get-PlanetSideTimeStream -Collection 'world_event' -QueryProperties @{
    #    'type' = 'FACILITY'
    #} -From $FromDate -To $ToDate | Where-Object { -not $ZoneId -or ($ZoneId -and $_.zone_id -eq $ZoneId) }

    # $recentMembers | Select -expand characters_event | ? { $_.table_type -eq 'kills' } | Where-Object { $_.is_headshot -gt 0 } | Measure-Object

    $scores = $recentMembers | ForEach-Object {
        $member = $_

        $result = [ordered]@{
            Name = $member.name.first
            Kills = 0
            Deaths = 0
            Suicides = 0
            Redeploys = 0
            Headshots = 0
            AxilPoints = 0
            TeamKills = 0
            KDR = 0
            HKR = 0
            HDR = 0
            VehicleKills = 0
            VehicleDeaths = 0
            VehicleLost = 0
            BaseCapture = 0
            BaseDefend = 0
        }

        if ($member.characters_event) {
            $eventsGrouped = $member.characters_event | Group-Object -AsHashTable table_type

            if ($eventsGrouped.ContainsKey('kills')) {
                $result.Kills = ($eventsGrouped['kills'] | Where-Object { $_.attacker_character_id -eq $member.character_id } | Measure-Object).Count
                
                $result.Redeploys = ($eventsGrouped['kills'] | Where-Object { $_.character_id -eq $member.character_id } | Measure-Object).Count

                $result.Headshots = ($eventsGrouped['kills'] | Where-Object { $_.is_headshot -gt 0 } | Measure-Object).Count
                $result.VehicleKills = ($eventsGrouped['kills'] | Where-Object { $_.attacker_vehicle_id -ne 0 } | Measure-Object).Count
                $result.AxilPoints = ($eventsGrouped['kills'] | Where-Object { $_.character_id -eq '5428059164954198113' } | Measure-Object).Count

                $result.TeamKills = ($eventsGrouped['kills'] | Where-Object { $_.character_id -eq '5428059164954198113' } | Measure-Object).Count
            }
            
            if ($eventsGrouped.ContainsKey('deaths')) {
                $result.Deaths = ($eventsGrouped['deaths'] | Where-Object { $_.attacker_character_id -ne $member.character_id } | Measure-Object).Count

                $result.Suicides = ($eventsGrouped['deaths'] | Where-Object { $_.attacker_character_id -eq $member.character_id } | Measure-Object).Count

                $deathHeadshots = ($eventsGrouped['deaths'] | Where-Object { $_.is_headshot -gt 0 } | Measure-Object).Count

                if ($result.Deaths -gt 0) {
                    $result.HDR = [Math]::Round($deathHeadshots / $result.Deaths, 2)
                }

                $result.VehicleDeaths = ($eventsGrouped['deaths'] | Where-Object { $_.attacker_vehicle_id -ne 0 } | Measure-Object).Count
                
                if ($member.character_id -eq '5428059164954198113') {
                    $result.Suicides = 0
                }
            }

            if ($eventsGrouped.ContainsKey('facility_character_event')) {
                $result.BaseCapture = ($eventsGrouped['facility_character_event'] | Where-Object { $_.event_type -eq 'PlayerFacilityCapture' } | Measure-Object).Count
                $result.BaseDefend = ($eventsGrouped['facility_character_event'] | Where-Object { $_.event_type -eq 'PlayerFacilityDefend' } | Measure-Object).Count
            }

            if ($eventsGrouped.ContainsKey('vehicle_destroy')) {
                $result.VehicleKills += $eventsGrouped['vehicle_destroy'].Count
            }

            if ($result.Deaths -gt 0) {
                $result.KDR = [Math]::Round($result.Kills / $result.Deaths, 2)
            } else {
                $result.KDR = $result.Kills
            }

            if ($result.Kills -gt 0) {
                $result.HKR = [Math]::Round($result.Headshots / $result.Kills, 2)
            }
        }

        [pscustomobject]$result
    }
}

Function Get-Md5Hash {
    begin {
        $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
        $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    }
    process {
        [System.Convert]::ToBase64String($md5.ComputeHash($utf8.GetBytes($_)))
    }
}
