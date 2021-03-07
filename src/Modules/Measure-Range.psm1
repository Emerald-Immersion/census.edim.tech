<#

.DESCRIPTION
Faster than Measure-Object for doing Count/Min/Max/Sum/Average.

.PARAMETER Property
If specified, will use the property with that name for each object.

.PARAMETER Sum
If the property type can be added/divided, this will provide both the Sum and Average in the result.

#>
Function Measure-Range {
    param (
        [string]$Property,
        [Switch]$Sum,
        [Switch]$Average,
        [Switch]$Minimum,
        [Switch]$Maximum
    )
    begin {
        $min = $null
        $max = $null
        $total = $null
        $count = $null
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

        if ($Minimum -and (-not $min -or $val -lt $min)) {
            $min = $val
        }
        
        if ($Maximum -and (-not $max -or $val -gt $max)) {
            $max = $val
        }
        
        if ($Sum -or $Average) {
            $total += $val
        }
    }
    end {
        $result = [ordered]@{
            Count = $count
        }

        if ($Average) {
            $result.Average = $total
            if ($count -gt 0) {
                $result.Average = $total/$count
            }
        }

        if ($Sum) {
            $result.Sum = $total
        }

        if ($Min) {
            $result.Minimum = $min
        }

        if ($Max) {
            $result.Maximum = $max
        }

        $result.Property = $Property

        [pscustomobject]$result
    }
}
