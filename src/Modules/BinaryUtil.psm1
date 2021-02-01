<#

.DESCRIPTION
Compresses multiple numeric properties into a single integer or buffer.

If numbers are all normal sizes use a struct with Marshal StructureToPtr and PtrToStructure for better performance.

.PARAMETER PropertyMap
Ordered hashtable with property names as keys and bit lengths as values.

.PARAMETER Truncate
If a number exceeds the bit size, it will become the max value and loose the original value.

.PARAMETER BigInteger
Always return a BigInteger, which allows the type to be converted to bytes.

.EXAMPLE Discord Snowflake

$inputObject = @{ Timestamp  = 41944705796; InternalWorkerId = 1; InternalProcessId = 0; Increment = 7 }
$discordSnowflake = [ordered]@{ Timestamp = 42; InternalWorkerId = 5; InternalProcessId = 5; Increment = 12 }

$inputobject | Compress-Bits -PropertyMap $discordSnowflake

.EXAMPLE Can serialize larger data sets using BigInteger and convert to base64.

[Convert]::ToBase64String(($inputobject | Compress-Bits -PropertyMap $propertyMap -BigInteger).ToByteArray())

#>
Function Compress-Bits {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline)]$InputObject,
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$PropertyMap,
        [switch]$Truncate,
        [switch]$BigInteger
    )
    begin {
        $totalBits = 0
        
        $PropertyMap.Values | ForEach-Object { $totalBits += $_ }

        $number = New-Number -Size $totalBits -BigInteger:$BigInteger

        $totalBits = $number + $totalBits
    }
    process {
        $obj = $_

        $result = $number

        $offset = $totalBits

        foreach ($key in $PropertyMap.Keys) {
            $len = $PropertyMap[$key]

            $val = $number
            
            if ($obj.$key) {
                $val += $obj.$key
            }

            $maxsize = if ($len -ge 64) {
                ([bigint]::Pow(2, $len)-1)
            } else {
                ([Math]::Pow(2, $len)-1)
            }

            if ($val -gt $maxsize) {
                if ($Truncate) {
                    $val = $maxsize
                } else {
                    throw "Object property value exceeds $len bits (No-Truncate): $key = $val/$maxsize"
                }
            }

            $offset -= $len

            Write-Verbose "$result -bor ($val -shl $offset) >> $result -bor $($val -shl $offset) >>"
            
            $result = $result -bor ($val -shl $offset)
        }

        $result
    }
}
<#

.DESCRIPTION
Expands a single number into multiple numeric properties.

Supports all number types including bigint, extracts a sequence of numbers into an object.

If numbers are all normal sizes use a struct with Marshal StructureToPtr and PtrToStructure for better performance.

.PARAMETER PropertyMap
Ordered hashtable with property names as keys and bit lengths as values.

.PARAMETER BigInteger
Always return a BigInteger, which allows the type to be converted to bytes.

.PARAMETER AsHashTable
Return hashtable instead of psobject.

.EXAMPLE Discord Snowflake

$discordSnowflake = [ordered]@{ Timestamp = 42; InternalWorkerId = 5; InternalProcessId = 5; Increment = 12 }

175928847299117063 | Expand-Bits -PropertyMap $discordSnowflake

#>
Function Expand-Bits {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline)]$InputObject,
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$PropertyMap,
        [switch]$BigInteger,
        [switch]$AsHashTable
    )
    begin {
        $totalBits = 0
        
        $PropertyMap.Values | ForEach-Object { $totalBits += $_ }
    }
    process {
        $bits = $_

        $ht = [ordered]@{}

        $c = 0

        foreach ($key in $PropertyMap.Keys) {
            $bitLength = $PropertyMap[$key]

            $offset = ($totalBits - $c - $bitLength)
            
            $number = New-Number -Size $bitLength -BigInteger:$BigInteger

            $maxsize = if ($bitLength -ge 64) {
                ([bigint]::Pow(2, $bitLength)-1)
            } else {
                ([Math]::Pow(2, $bitLength)-1)
            }

            $and = $number
            
            $and += $maxsize

            $and = $and -shl $offset

            $ht[$key] = $number -bor (($bits -band $and) -shr $offset)

            $c += $bitLength
        }

        if ($AsHashTable) {
            $ht
        } else {
            [pscustomobject]$ht
        }
    }
}
<#

.DESCRIPTION
Returns the smallest number type given an existing max size.

.PARAMETER Size
The largest size of the number needed.

.PARAMETER BigInteger
Always return a BigInteger.

#>
Function New-Number ([Parameter(Mandatory)]$Size, [switch]$BigInteger) {
    if ($BigInteger) {
        [bigint]::Zero
    } elseif ($Size -le 8) {
        [byte]::MinValue
    } elseif ($Size -le 16) {
        [UInt16]::MinValue
    } elseif ($Size -le 32) {
        [UInt32]::MinValue
    } elseif ($Size -le 64) {
        [UInt64]::MinValue
    } else {
        [bigint]::Zero
    }
}
<#


.EXAMPLE

$a = [bigint]::new(1111)
$b = [bigint]::new(2222)
$c = [bigint]::new(3333)

$d = $a -bxor $b -bxor $c

$d -bxor $b -bxor $c
$d -bxor $a -bxor $c
$d -bxor $a -bxor $b

#>
Function Compress-Parity {
    begin {
        $result = $null
    }
    process {
        if ($null -eq $result) {
            $result = $_
        } else {
            $result = $result -bxor $_
        }
    }
    end {
        $result
    }
}
<#

#>
Function Expand-Parity ($Parity) {
    begin {
        $result = $Parity
    }
    process {
        $result = $result -bxor $_
    }
    end {
        $result
    }
}
<#

#>
Function Export-BinaryStream {
    param (
        [string]$Path,
        [switch]$Append
    )
    begin {

    }
    process {
        
    }
    end {

    }
}
<#

#>
Function Import-BinaryStream {
    param (
        [string]$Path
    )
    process {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -band [IO.FileShare]::Delete))

        if (-not $stream) {
            Write-Error "Could not process file: $Path"
            Return
        }

        
    }
}