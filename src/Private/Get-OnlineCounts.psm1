



# https://census.daybreakgames.com/count/ps2:v2/character/?times.last_save=%3E1611772257
<#

$InformationPreference = 'Continue'

    
    $from = [System.DateTimeOffset]::new(((Get-Date).AddHours(-2))).ToUnixTimeSeconds()
    $to = [System.DateTimeOffset]::new(((Get-Date).AddHours(-1))).ToUnixTimeSeconds()
    
    $query = [ordered]@{
        'c:join' = 'characters_world^inject_at:world^show:world_id'
        #'c:hide' = 'faction_id,head_id,title_id,name,certs,battle_rank,profile_id,prestige_level,daily_ribbon'
    }

    $result = Get-PlanetSideTimeStream -Collection 'character' -QueryProperties $query `
        -From $Since -To (Get-Date) -TimeStampProperty 'times.last_save' -Interval ([TimeSpan]::FromHours(6))

 https://census.daybreakgames.com/s%3ADayBreakPwsh/count/ps2%3Av2/character/?times.last_save=>1613751152

 
 https://census.daybreakgames.com/s%3ADayBreakPwsh/count/ps2%3Av2/character/?character_id=<5428010618013876561

#>
Function Get-OnlineCounts {
    param (
        $Since = ((Get-Date).AddDays(-2))
    )

    $seconds = [System.DateTimeOffset]::new($Since).ToUnixTimeSeconds()
    
    $query = [ordered]@{
        'times.last_save' = ">$seconds"
        'c:join' = 'characters_world^inject_at:world^show:world_id'
        'c:hide' = 'faction_id,head_id,title_id,name,certs,battle_rank,profile_id,prestige_level,daily_ribbon'
    }

    $result = Get-PlanetSideDataStream -Collection 'character' -QueryProperties $query


    $from = [System.DateTimeOffset]::new(((Get-Date).AddHours(-2))).ToUnixTimeSeconds()
    $to = [System.DateTimeOffset]::new(((Get-Date).AddHours(-1))).ToUnixTimeSeconds()
    
    $query = [ordered]@{
        'c:join' = 'characters_world^inject_at:world^show:world_id'
        #'c:hide' = 'faction_id,head_id,title_id,name,certs,battle_rank,profile_id,prestige_level,daily_ribbon'
    }

    $result = Get-PlanetSideTimeStream -Collection 'character' -QueryProperties $query `
        -From (Get-Date).AddHours(-2) -To (Get-Date).AddHours(-1) -TimeStampProperty 'times.last_save' -Interval ([TimeSpan]::FromSeconds(60))

}