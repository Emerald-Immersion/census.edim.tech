<#

.DESCRIPTION
Sorts data as it is pipelined in to create statistics such as IQR, Median Average and Standard Diviation.

.NOTES
Use Measure-Range if you just need basic numbers, it is 2-3x faster as it does not need to sort the input.

Q2 is Mode Average.

.EXAMPLE

$samples = 0..10000

Measure-Command { 0..10000 | Measure-Object -Min -Max -Sum -Average }

Measure-Command { 0..10000 | Measure-Statistics -Sum }

#>
Function Measure-Statistics {
    param (
        [string]$Property,
        [switch]$Sum,
        [switch]$Simple,
        [switch]$Extended
    )
    begin {
        $collection = [System.Collections.SortedList]::new()
        $count = 0
        $total = $null
    }
    process {
        if ($Property) {
            $val = $_.$Property
        } else {
            $val = $_
        }
        
        if ($null -eq $val) {
            Return
        }

        $count += 1

        if (-not $collection.ContainsKey($val)) {
            $collection.Add($val, @())
        }

        if ($Sum) {
            if ($total) {
                $total += $val
            } else {
                $total = $val
            }
        }

        $collection[$val] += $_
    }
    end {
        $result = [ordered]@{
            Count = $count
        }

        if ($count -eq 0) {
            [pscustomobject]$result
            Return
        }

        $result.Min = $collection.Keys[0]
        $result.Max = $collection.Keys[$collection.Keys.Count - 1]

        if ($Sum) {
            $result.Sum = $total
            $result.Average = $total/$count
        }

        $q1 = [Math]::Floor($collection.Count*0.25)
        $q2 = [Math]::Round($collection.Count*0.50)
        $q3 = [Math]::Ceiling($collection.Count*0.75)
        
        $result.Q1 = $collection.Keys[$q1]
        $result.Q2 = $collection.Keys[$q2]
        $result.Q3 = $collection.Keys[$q3]

        if ($Sum -and -not $Simple) {
            $medianSum = $collection.Keys | Select-Object -Skip $q1 -First $q2 | & {
                begin { $i = $null }
                process { for ($i = 0; $i -lt ($collection[$_].Count); $i++) { if (-not $i) { $i = $_ } else { $i += $_ } } }
                end { $i }
            }

            $result.MedianAverage = $medianSum/$q2

            $stddevSum = $collection.Keys | & {
                begin { $i = $null }
                process { $r = [Math]::Pow($_ - $result.Average, 2); for ($i = 0; $i -lt ($collection[$_].Count); $i++) { if (-not $i) { $i = $r } else { $i += $r } } }
                end { $i }
            }

            $result.StdDev = $stddevSum/$collection.Count
        }

        if ($Extended) {
            $result.Distribution = ($result.Q2/$result.Q3)-($result.Q1/$result.Q2)
        }

        [pscustomobject]$result
    }
}
