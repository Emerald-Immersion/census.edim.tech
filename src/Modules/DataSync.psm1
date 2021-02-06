<#

.DESCRIPTION


.PARAMETER Fetch
Fetch is called with the parameters for the offset and number of items to collect.

This should return each object, so they can be counted.

param([int]$Offset, [int]$Limit)

.PARAMETER From
Should be the current number of items you have in the collection.

.PARAMETER To
Ceiling of a max number of records to fetch.

.PARAMETER Limit
The limit of items that indicate there are more items.

If your Fetch function returns less than this, the loop will break assuming that it has
reached the end of the data stream.

#>
Function Get-DataStream  {
    param (
        [Parameter(Mandatory)][ScriptBlock]$Fetch,
        [int]$From,
        [int]$To,
        [Parameter(Mandatory)][int]$Limit
    )

    $offset = $From

    while ($true) {
        $counter = 0

        Invoke-Command -ScriptBlock $Fetch -ArgumentList $offset,$Limit | ForEach-Object {
            $counter += 1
            $_
        }
            
        if (($To -gt 0 -and $offset -gt $To) -or $counter -lt $Limit) {
            break
        } else {
            $offset += $counter
        }
    }
}
<#

.DESCRIPTION
For queries that involve time but also limits.

Say you want an hour of logs but can only get 1000 log items per request.

This will re-query smaller time frames in a dynamic way until it gets less than
that limit, then query that next time frame within it.

You can cross your streams...

.PARAMETER Fetch
A script block that takes the parameters:

param([DateTime]$StartTime, [DateTime]$EndTime, [int]$Limit)

If you `throw $Limit`, this assumes you were able to check the number of records
in an inexpensive way and will act like it reached the Limit normally.

.PARAMETER Limit
The amount of items that indicate there are two many for this current timeframe.

.PARAMETER From

If only from is set:
 - Past = Go fowards from then to now
 - Future = Go backwards from then to now;

.PARAMETER To

If only To is set:
 - Past = Go backwards from now
 - Future = Go fowards from now

.PARAMETER Interval
The interval is the sample size for the timeframe.

This changes based on the IntervalRate.

.PARAMETER IntervalMin
Default is one second, can be as little as a tick.

If this is reached and the results reach the limit, an exception will be thrown.

If you want to handle this situation, in your Fetch function detect if the interval
is at is minimum and if so, use Get-DataStream to get all the records for that timeframe.

.PARAMETER IntervalMax
Default is one week.

.PARAMETER IntervalRate
The rate of which the interval will both change and consider a change needed.

This grows if there are considerably less results than the limit.

It shrinks if there is more than the limit, or if it is already close.

.PARAMETER RangeMatch
Choose not to subtract the IntervalMin from the StartDate for each query.

Normal: $Date -ge $StartDate -and $Date -le $EndDate
RangeMatch: $Date -gt $StartDate -and $Date -le $EndDate

.EXAMPLE

$Fetch = {
    param([DateTime]$StartTime, [DateTime]$EndTime, [int]$Limit)

    if ($StartTime.Hour -gt 8 -and $StartTime.Hour -lt 18) {
        if (($EndTime-$StartTime).TotalMinutes -lt 30) {
            2..$Limit
            Write-Host -ForegroundColor Green "$StartTime > $EndTime"
        } else {
            0..$Limit
            Write-Host -ForegroundColor Red "$StartTime > $EndTime"
        }
    } else {
        2..$Limit
        Write-Host -ForegroundColor Yellow "$StartTime > $EndTime"
    }
}

Get-TimeStream -Fetch $Fetch -Limit 10 -IntervalRate 0.01 -From ([DateTime]'2021-01-01') | Out-Null
Get-TimeStream -Fetch $Fetch -Limit 10 -IntervalRate 0.01 -To ([DateTime]'2021-01-01') | Out-Null
Get-TimeStream -Fetch $Fetch -Limit 10 -From ([DateTime]'2021-01-01') -To ([DateTime]'2021-01-02') | Out-Null
Get-TimeStream -Fetch $Fetch -Limit 10 -From ([DateTime]'2021-01-02') -To ([DateTime]'2021-01-01') | Out-Null

#>
Function Get-TimeStream  {
    param (
        [Parameter(Mandatory)]
        [ScriptBlock]$Fetch,

        [DateTime]$From,
        [DateTime]$To,

        [Parameter(Mandatory)]
        [int]$Limit,

        [TimeSpan]$Interval = [TimeSpan]::FromHours(1),
        [TimeSpan]$IntervalMin = [TimeSpan]1,
        [TimeSpan]$IntervalMax = [TimeSpan]::FromDays(7),
        [double]$IntervalRate = 0.1,

        [switch]$RangeMatch
    )

    if (-not $From -and -not $To) {
        throw 'Either From or/and To must be set.'
    }

    if ($Interval -lt [TimeSpan]1) {
        throw 'Interval must be greater than zero.'
    }
    
    if ($IntervalMin -le [TimeSpan]::Zero -or $IntervalMin -gt $Interval) {
        throw 'Interval minimum must be greater than zero and less than or equal to Interval'
    }
    
    if ($IntervalMax -le $IntervalMin -or $IntervalMax -lt $Interval) {
        throw 'Interval maximum must be greater than the minimum and greater or equal to Interval.'
    }

    if ($IntervalRate -lt 0 -or $IntervalRate -gt 1) {
        throw 'Interval rate must be between inclusive 0 and 1.'
    }

    $startTime = $From
    $endTime = $To

    if (-not $startTime) { $startTime = [DateTime]::UtcNow }
    if (-not $endTime) { $endTime = [DateTime]::UtcNow }

    $timeSpan = $Interval.Ticks
    $minSpan = $IntervalMin.Ticks
    $maxSpan = $IntervalMax.Ticks

    $rateChange = 1 - $IntervalRate
    
    $reverse = $startTime -gt $endTime

    if ($reverse) {
        $timeSpan = -$timeSpan
        $minSpan = -$maxSpan
        $maxSpan = -$minSpan
    }

    $rangeTime = $startTime

    $argList = [object[]]::new(3)
    $argList[2] = $Limit

    while (($reverse ? $rangeTime -gt $endTime : $rangeTime -lt $endTime)) {
        $rangeTime = $rangeTime.AddTicks($timeSpan)

        if ($reverse) {
            if ($rangeTime -lt $endTime) {
                $rangeTime = $endTime
            }
            $argList[0] = $rangeTime
            $argList[1] = $startTime
        } else {
            if ($rangeTime -gt $endTime) {
                $rangeTime = $endTime
            }
            $argList[0] = $startTime
            $argList[1] = $rangeTime
        }

        $limitReached = $false
        
        $results = $null

        try {
            $results = @(Invoke-Command -ScriptBlock $Fetch -ArgumentList $argList)
        } catch {
            if ($_ -ne $Limit) {
                throw $_
            }

            $limitReached = $true
        }

        if ($limitReached -or ($results.Length -ge $Limit)) {
            if ($timeSpan -eq $minSpan) { throw 'Reached IntervalMin, cannot make a smaller timeframe.' }

            $rangeTime = $startTime
            $timeSpan *= $rateChange

            if ($timeSpan -lt $minSpan) { $timeSpan = $minSpan }
        } else {
            $results

            $startTime = $rangeTime 

            if (-not $RangeMatch) {
                $startTime -= $IntervalMin
            }

            if (1 - ($results.Length/$Limit) -gt $IntervalRate) {
                $timeSpan /= $rateChange
                
                if ($timeSpan -gt $maxSpan) { $timeSpan = $maxSpan }
            }
        }
    }
}
