<#

.DESCRIPTION


#>
Function Get-JsonObjectCommands {
    Get-Command -Module 'JsonObject'
}
<#

.DESCRIPTION

.EXAMPLE

#>
Function Get-JsonObjectPath {
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

            $item | Get-JsonObjectPath -PropertyPath "$itemPath[]" -Parent $itemType @splat | ForEach-Object {
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
                
                $prop.Value | Get-JsonObjectPath -PropertyPath $newpath -Parent $itemType @splat | ForEach-Object {
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

.DESCRIPTION Converts types such as DateTime and Enums into strings/integers for friendlier conversion to Json.

.PARAMETER DateTimeFormat
Supports normal [DateTime] toString formats.

Also supports 'js' for Unix Miliseconds and 'unix' for Unix Seconds, both since 1970 epoch.

A bit hacky but js/unix output as a string instead of a number, makes it easer to determine.

.EXAMPLE 

$object | ConvertTo-JsonObject | ConvertTo-Json

#>
Function ConvertTo-JsonObject ($DateTimeFormat = 'js', [switch]$EnumString, [switch]$KeepNull, [switch]$KeepPS) {
    process {
        if ($_ -is [Array]) {
            $_ | ConvertTo-JsonObject @PSBoundParameters
        } elseif ($_ -is [Enum]) {
            if ($EnumString) { $_.ToString() } else { [int]$_ }
        } elseif ($_ -is [DateTime]) {
            if ($DateTimeFormat -eq 'js') {
                [DateTimeOffset]::new($_).ToUnixTimeMilliseconds().ToString()
            } elseif ($DateTimeFormat -eq 'unix') {
                [DateTimeOffset]::new($_).ToUnixTimeSeconds().ToString()
            } else {
                $_.ToString($DateTimeFormat)
            }
        } elseif ($_ -is [String] -or $_ -is [ValueType] -or $_.GetType().IsPrimitive) {
            $_
        } elseif ($_ -is [Object]) {
            $ht = [ordered]@{}

            $_.PSObject.Properties | ? { ($KeepNull -or $null -ne $_.Value) -and ($KeepPS -or $_.Name -cnotlike 'PS*') } | % {
                $ht[$_.Name] = $_.Value | ConvertTo-JsonObject @PSBoundParameters
            }

            [pscustomobject]$ht
        } else {
            $_
        }
    }
}
<#

.DESCRIPTION Attempts to convert types such as DateTime back into objects.

.PARAMETER DateTimeFormat
Supports normal [DateTime] toString formats.

Also supports 'js' for Unix Miliseconds and 'unix' for Unix Seconds, both since 1970 epoch.

A bit hacky but js/unix output as a string instead of a number, makes it easer to determine.

.EXAMPLE

$json | ConvertFrom-Json | ConvertFrom-JsonObject

#>
Function ConvertFrom-JsonObject ($DateTimeFormat = 'js') {
    process {
        if ($_ -is [Array]) {
            $_ | ConvertFrom-JsonObject @PSBoundParameters
        } elseif ($_ -is [String]) {
            [DateTime]$dt = [DateTime]::MinValue

            if ($DateTimeFormat -eq 'js' -or $DateTimeFormat -eq 'unix') {
                [Int64]$int = 0

                if ([Int64]::TryParse($_, [ref]$int)) {
                    $dt = $null
                    
                    if ($DateTimeFormat -eq 'unix') {
                        [DateTimeOffset]::FromUnixTimeSeconds($int)
                    } else {
                        [DateTimeOffset]::FromUnixTimeMilliseconds($int)
                    }                    
                } else {
                    $_
                }
            } else {
                if ([DateTime]::TryParseExact($_, $DateTimeFormat, $null, [ref]$dt)) {
                    $dt
                } else {
                    $_
                }
            }
        } elseif ($_ -is [Object]) {
            $ht = [ordered]@{}

            $_.PSObject.Properties | ? { ($KeepNull -or $null -ne $_.Value) -and ($KeepPS -or $_.Name -cnotlike 'PS*') } | % {
                $ht[$_.Name] = $_.Value | ConvertFrom-JsonObject @PSBoundParameters
            }

            [pscustomobject]$ht
        } else {
            $_
        }
    }
}
<#

.DESCRIPTION
Outputs a JSON file for a lookup table that can be diffed/compared easily.

If values do contain multiple lines it will output like that, but it will still be valid json.

.EXAMPLE

Get-ChildItem . | Select-Object Name,Length,LastWriteTime | ConvertTo-JsonLookup -PropertyId 'Name' -Depth 1

.EXAMPLE

@(
    [ordered]@{ "id" = 1; "text" = "foo" }
    [ordered]@{ "id" = 2; "text" = "foo" }
) | ConvertTo-JsonLookup -PropertyId 'id'

Output:

{
"1": { "id": 1, "text": "foo" }
,"2": { "id": 2, "text": "foo" }
}

#>
Function ConvertTo-JsonLookup {
    param (
        [Parameter(ValueFromPipeline)]$InputObject,
        [Parameter(Mandatory)][string]$PropertyId,
        [int]$Depth = 10
    )
    begin {
        "{"
        $prefix = ''
    }
    process {
        if (-not $_.$PropertyId) {
            Write-Error "One or more items do not have the specified PropertyID."
            Return
        }

        "$prefix`"$($_.$PropertyId)`": $($_ | ConvertTo-Json -Compress -Depth $Depth)"

        if (-not $prefix) {
            $prefix = ','
        }
    }
    end {
        '}'
    }
}
<#

.DESCRIPTION
Converts input objects to JSON, within an JSON object.

.EXAMPLE

{"Items":[
{ "id": 1 }
,{ "id": 2 }
,{ "id": 3 }
],"Count":3}

.NOTES
First item could be null to skip prefix check...

#>
Function ConvertTo-JsonStream {
    param (
        [Parameter(ValueFromPipeline)]$InputObject,
        [int]$Depth = 10,
        [switch]$NoCount,
        [switch]$CreateAppend,
        [switch]$Append,
        [switch]$CloseAppend
    )
    begin {
        [uint64]$count = 0

        if (-not $Append -and -not $CloseAppend) {
            '{"Items":['
        }
    }
    process {
        "$prefix$($_ | ConvertTo-Json -Compress -Depth $Depth)"

        $count += 1

        if (-not $prefix) {
            $prefix = ','
        }
    }
    end {
        if (-not $Append -and -not $CreateAppend) {
            if ($NoCount) {
                ']}'
            } else {
                "],`"Count`":$count}"
            }
        }
    }
}
<#

#>
Function ConvertFrom-JsonStream {
    param (
        [switch]$Append
    )
    begin {
        $first = $null
    }
    process {
        if (-not $first) {
            $first = "${_}]}" | ConvertFrom-Json -ErrorAction Stop
            Return
        }

        if ($_[0] -eq ']') {
            break # Breaks the input pipeline to indicate completion
        } else {
            try {
                $_.TrimStart(',') | ConvertFrom-Json -ErrorAction Stop
            } catch {
                if ($Append) {
                    break
                } else {
                    $_
                }
            }
        }
    }
}
<#

.DESCRIPTION
Converts input objects to flat rows, within an JSON object.

It (obviously) results in a smaller JSON file as the property keys do not need repeating for each row.

.PARAMETER Property
List of properties to output from every input.

.PARAMETER NoCount
Dont output the count at the end.

.PARAMETER Append
Assume the header is already written, write rows but do not write the end.

To end your own stream write the line with ']}' at the end.

.PARAMETER Appendable
Write the header, write the rows but do not write the end.

Used initially, but if the file exists use Append.

.EXAMPLE

{"Items":[
{ "id": 1 }
,{ "id": 2 }
,{ "id": 3 }
],"Count":3}

.NOTES
First item could be null to skip prefix check...

#>
Function ConvertTo-JsonSeperatedValues {
    param (
        [Parameter(ValueFromPipeline)]$InputObject,
        [Parameter(Mandatory)][string[]]$Property,
        [switch]$NoCount,
        [Parameter(ParameterSetName='create')][switch]$CreateAppend,
        [Parameter(ParameterSetName='append')][switch]$Append,
        [Parameter(ParameterSetName='close')][switch]$CloseAppend
    )
    begin {
        [uint64]$count = 0

        if (-not $Append -and -not $CloseAppend) {
            "{`"Columns`": [`"$($Property -join '","')`"], `"Rows`":["
        }
    }
    process {
        $item = $_
        
        $cells = $Property | ForEach-Object { if ($item.$_ -is [ValueType]) { $item.$_ } else { $item.$_.ToString() } }

        "$prefix$($cells | ConvertTo-Json -Compress)"

        $count += 1

        if (-not $prefix) {
            $prefix = ','
        }
    }
    end {
        if (-not $Append -and -not $CreateAppend) {
            if ($NoCount) {
                ']}'
            } else {
                "],`"Count`":$count}"
            }
        }
    }
}
<#

.PARAMETER Append
Gracefully end on error as it may indicate a last line that has not been flushed yet with Append.

#>
Function ConvertFrom-JsonSeperatedValues {
    param (
        [switch]$Append
    )
    begin {
        $header = $null
    }
    process {
        if (-not $header) {
            $first = "${_}]}" | ConvertFrom-Json -ErrorAction Stop
            $header = $first.Columns
            Return
        }

        if ($_[0] -eq ']') {
            break # Breaks the input pipeline to indicate completion
        } else {
            try {
                $arr = $_.TrimStart(',') | ConvertFrom-Json -ErrorAction Stop

                $ht = [ordered]@{}

                for ($i = 0; $i -lt $header.Length; $i++) {
                    $ht[$header[$i]] = $arr[$i]
                }
            } catch {
                if ($Append) {
                    break
                } else {
                    $_
                }
            }
        }
    }
}
