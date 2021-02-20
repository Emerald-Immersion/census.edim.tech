
<#

.DESCRIPTION

.EXAMPLE

#>
Function Get-ObjectPath {
    param (
        $PropertyPath = $null,
        [switch]$IncludeType,
        [int]$MaxDepth = 10,
        [int]$Depth,
        [Type]$Parent
    )
    begin {
        $ht = @{}
        $i = 0
        $splat = @{
            IncludeType = $IncludeType
            MaxDepth = $MaxDepth
            Depth = ($Depth + 1)
        }
    }
    process {
        $item = $_
        
        $itemType = $item.GetType()

        $itemPath = if ('' -eq $PropertyPath) {
            $null
        } elseif ($PropertyPath) {
            $PropertyPath
        } else {
            $itemType.Name
        }

        if ($item -is [Array]) {
            if ($Depth -ge $MaxDepth) { Return }

            $item | Get-ObjectPath -PropertyPath "$itemPath[]" -Parent $itemType @splat | ForEach-Object {
                if (-not $ht.ContainsKey($_)) {
                    $ht.Add($_, ($i += 1))
                }
            }
            Return
            
        } elseif ($_ -is [Enum]) {
            # TODO: Maybe represent possible values if switch provided?
        } elseif ($item -is [String] -or $_ -is [ValueType] -or $itemType.IsPrimitive) {
            
        } elseif ($Parent -and $item -is $Parent -and $Parent.Name -ne 'PSCustomObject' -and $Parent.Name -ne 'PSObject') {

        } elseif ($item -is [Object]) {
            if ($Depth -ge $MaxDepth) { Return }
            
            $item.PSObject.Properties | Where-Object { 
                ($KeepNull -or $null -ne $_.Value) -and 
                ($KeepPS -or $_.Name -cnotlike 'PS*') 
            } | ForEach-Object {
                $prop = $_
                $newpath = (@($itemPath, $prop.Name) | Where-Object { $_ }) -join '.'
                
                $prop.Value | Get-ObjectPath -PropertyPath $newpath -Parent $itemType @splat | ForEach-Object {
                    if (-not $ht.ContainsKey($_)) {
                        $ht.Add($_, ($i += 1))
                    }
                }
            }
            Return
        }
        
        if ($IncludeType) {
            "${itemPath}:$($itemType.Name)"
        } else {
            $itemPath
        }
    }
    end {
        $ht.Keys | Sort-Object { $ht[$_] }
    }
}
<#

#>
Function Expand-ObjectPath {
    param (
        [Parameter(ValueFromPipeline)]$InputObject,
        [Parameter(Position = 0)][string]$Path
    )
    process {
        $current = $_
        
        foreach ($p in $Path) {
            if (-not $current.$p) {
                Return
            }

            $current = $current.$p
        }
    
        $current
    }
}
<#

#>
Function Select-ObjectPath {
    param (
        [Parameter(Position = 0)][string[]]$Properties,
        [switch]$AsHashTable
    )
    process {
        $ht = @{}

        foreach ($path in $Properties) {
            $current = $_

            $split = $path -split '.'

            foreach ($p in $split) {
                if (-not $current.$p) {
                    Return
                }

                $current = $current.$p
            }
        }

        if ($AsHashTable) {
            $ht
        } else {
            [pscustomobject]$ht
        }
    }
}
