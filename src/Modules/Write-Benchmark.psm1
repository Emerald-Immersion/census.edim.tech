<#

.SYNOPSIS
Outputs using Write-Host the Duration, records and rate of a pipeline.

.DESCRIPTION

.PARAMETER Bandwidth
Uses the Length of strings or numeric arrays

.PARAMETER Progress
Report within the Interval time the stats.

.PARAMETER Interval
Interval between Progress Reports.

.PARAMETER Count
The count/estimate of records expected.

.PARAMETER Length
The length/estimate of data expected.

.EXAMPLE
Invoke-Command -ScriptBlock { $i = 0; while ($true) { Start-Sleep -Milliseconds 500; $i += 1; $i } } | Write-Benchmark -Progress

#>
Function Write-Benchmark {
    param(
        [Switch]$Bandwidth,
        [Switch]$Progress,
        [TimeSpan]$Interval = [TimeSpan]::FromSeconds(5),
        [int]$EstimateCount,
        [int]$EstimateLength,
        [Switch]$DelayOutput,
        [Switch]$NoOutput
    )
    begin {
        $count = 0
        $len = 0
        $prev = 0
        $report = {
            param($sec, $count, $len, $estCount, $estLength)
            $def = [Math]::Max(1 - $sec, 1)
            Write-Host "-------------------------------"
            Write-Host "Duration:           $([Math]::Round(($sec)*$def, 2)) sec"
            Write-Host "Count:              $($count)"
            Write-Host "Rate:               $([Math]::Round(($count/$sec)*$def, 2)) items/sec"
            if ($estCount) {
                $countTotal = $sec / ($count / $estCount)
                Write-Host "Remaining Count:    $($estCount - $count)"
                Write-Host "Remaining Time:     $([TimeSpan]::FromSeconds($countTotal - $sec).ToString())"
            }
            if ($Bandwidth) {
                Write-Host "Length:             $($len | Write-Size)"
                Write-Host "Bandwidth:          $(([Math]::Round(($len/$sec)*$def, 2)) | Write-Size)/sec"
                if ($estLength) {
                    $lenTotal = $sec / ($len / $estLength)
                    Write-Host "Transfer Remaining: $(($estLength - $len) | Write-Size)"
                    Write-Host "Transfer Time:      $([TimeSpan]::FromSeconds($lenTotal - $sec).ToString())"
                }
            }
            Write-Host "-------------------------------"
        }
        $StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
        $StopWatch.Start()
        $Delay = @()
    }
    process {
        $count++

        if ($DelayOutput) { 
            $Delay += $_
        } elseif (-not $NoOutput) {
            $_
        }

        if ($Bandwidth) {
            $len += switch ($_.GetType().Name) {
                'String' { $_.Length }
                'Byte[]' { $_.Length }
                'Int32[]' { $_.Length * 4 }
                'Int64[]' { $_.Length * 8 }
                'String[]' { ($_ | Select-Object -ExpandProperty Length | Measure-Object -Sum).Sum }
                * {
                    $StopWatch.Stop()
                    (($_ | ConvertTo-Binary).Length - 28)
                    $StopWatch.Start()
                }
            }
        }
        if ($Progress) {
            $sec = $StopWatch.Elapsed.TotalSeconds
            if (($sec - $prev) -gt $Interval.TotalSeconds) {
                $prev = $sec
                Invoke-Command -ScriptBlock $report -ArgumentList @($sec, $count, $len, $EstimateCount, $EstimateLength)
            }
        }
    }
    end {
        $StopWatch.Stop()
        Invoke-Command -ScriptBlock $report -ArgumentList @($StopWatch.Elapsed.TotalSeconds, $count, $len, $EstimateCount, $EstimateLength)
        if ($DelayOutput) { $Delay }
    }
}
