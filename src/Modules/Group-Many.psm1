<#

.DESCRIPTION
Like Group-Object except it uses a ScriptBlock against the object
and adds creates a group with each one, adding the object to it.

This does mean a single input object will appear in multiple groups.

.EXAMPLE

'weapon_group_id','zone_id','character_id','attachment_list','zone_effect','vehicle_id' | Group-Many {
    & Get-FullTextIndex -Min 2 -Max 5
} | Sort Count

#>
Function Group-Many {
    param (
        [ScriptBlock]$ScriptBlock,
        [switch]$AsHashTable
    )
    begin {
        $pipe = $ScriptBlock.GetSteppablePipeline()

        $pipe.Begin($true)
        
        $groups = @{}
    }
    process {
        $obj = $_

        $pipe.Process($obj) | ForEach-Object {
            if (-not $groups.ContainsKey($_)) {
                $groups.Add($_, @())
            }

            $groups[$_] += $obj
        }
    }
    end {
        if ($AsHashTable) {
            $groups
            return
        }

        $groups.Keys | ForEach-Object {
            [pscustomobject]@{
                Name = $_
                Count = $groups[$_].Count
                Group = $groups[$_]
            }
        }
    }
}
<#

#>
Function Get-FullTextIndex ($Min = 3, $Max = 8) {
    process {
        $len = $_.Length - $min

        if ($len -lt 1) {
            Return
        }

        for ($x = 0; $x -le $len; $x++) {
            for ($y = $Min; $y -le $Max -and ($x + $y) -le $_.Length; $y++) {
                $_.SubString($x, $y)
            }
        }
    }
}
