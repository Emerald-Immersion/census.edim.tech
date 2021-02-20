<#

.DESCRIPTION
Like group object except it assumes the input is in an sort order relvent to the grouping
and returns a result of each group when it changes.

.PARAMETER ScriptBlock
For best performance use { & Select-Object -Expand Property }

.EXAMPLE

0..10000 | Group-Stream { $_ - ($_ % 10) }

Name Count Group
---- ----- -----
0       10 {0, 1, 2, 3...}
10      10 {10, 11, 12, 13...}
20      10 {20, 21, 22, 23...}
30      10 {30, 31, 32, 33...}
40      10 {40, 41, 42, 43...}
50      10 {50, 51, 52, 53...}
60      10 {60, 61, 62, 63...}
70      10 {70, 71, 72, 73...}
80      10 {80, 81, 82, 83...}
90      10 {90, 91, 92, 93...}
100      1 {100}

Measure-Command { 0..1000000 | Group-Stream { $_ - ($_ % 10) } }


#>
Function Group-Stream {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$InputObject,
        [Parameter(Mandatory, ParameterSetName = 'ByProperty', Position = 0)][string[]]$Property,
        [Parameter(Mandatory, ParameterSetName = 'ByScriptBlock', Position = 0)][ScriptBlock]$ScriptBlock,
        [Parameter(ParameterSetName = 'ByProperty')][string]$PropertyJoin = ', '
    )
    begin {
        $current = $null
        $array = @()
        
        $pipe = $null
        
        if ($ScriptBlock) {
            try {
                $pipe = $ScriptBlock.GetSteppablePipeline($MyInvocation.CommandOrigin)
                $pipe.Begin() 
            } catch {

            }
        }
    }
    process {
        $item = $_

        $keys = if ($pipe) {
            $pipe.Process($item)
        } elseif ($Property) {
            foreach ($prop in $Property) {
                $item.$prop
            }
        } elseif ($ScriptBlock) {
            & $ScriptBlock
        }

        $key = $keys -join $PropertyJoin

        if ($current -ne $key) {
            if ($null -ne $current) {
                [PSCustomObject]@{
                    Name = $current
                    Count = $array.Count
                    Group = $array
                }
            }
            $current = $key
            $array = @()
        }

        $array += $_
    }
    end {
        if ($null -ne $current) {
            [PSCustomObject]@{
                Name = $current
                Count = $array.Count
                Group = $array
            }
        }

        if ($pipe) {
            $pipe.End()
        }
    }
}
