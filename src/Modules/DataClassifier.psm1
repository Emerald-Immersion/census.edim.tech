#Requires -Modules ObjectPath

Class ClassifiedData {
    [string]$Name
    [string]$Items
}

<#

#>
Function Resolve-Properties {
    param (
        $Collections,
        $SampleSize
    )
    
    $Collections | ForEach-Object {
        $collection = $_

        if (-not $collection.Items) { Write-Error "Items not defined in collection: $($colleciton.Name)"; Return }

        $data = $collection.Items

        if ($SampleSize) {
            $data = $data | Select-Object -First $SampleSize
        }
        
        $props = $data | Get-ObjectPath -PropertyPath ''

        $ht = @{}

        $props | ForEach-Object {
            $ht[$_] = [pscustomobject]@{}
        }

        $collection | Add-Member -NotePropertyName 'Properties' -NotePropertyValue $ht -Force
    }
}
<#

#>
Function Resolve-PropertyNullable {
    process {
        $collection = $_

        if (-not $collection.Items) { Write-Error "Items not defined in collection: $($colleciton.Name)"; Return }
        
        if (-not $collection.Properties) { Write-Error "Properties not defined in collection: $($colleciton.Name)"; Return }

        $data = $collection.Items

        $collection.Properties.PSObject.Properties.Name | ForEach-Object {
            $property = $collection.Properties.$_

            $values = @($data | Expand-ObjectPath -Path $_)

            $property | Add-Member -Force -NotePropertyName 'Nullable' -NotePropertyValue ($values.Count -ne $data.Count)
        }
    }
}
<#

#>
Function Resolve-PropertyInteger {
    process {
        $collection = $_

        if (-not $collection.Items) { Return }
        
        if (-not $collection.Properties) { Return }

        $data = $collection.Items

        $collection.Properties.PSObject.Properties.Name | ForEach-Object {
            $property = $collection.Properties.$_

            $values = @($data | Expand-ObjectPath -Path $_)

            $property | Add-Member -Force -NotePropertyName 'Integer' -NotePropertyValue @(
                $values | Where-Object { 
                    $_ -and $_.ToCharArray() | Where-Object { 
                        -not [char]::IsDigit($_)
                    } | Select-Object -First 1 
                } | Select-Object -First 1
            ).Count -eq 0
        }
    }
}
<#

#>
Function Resolve-PropertyValueType {
    param (
        $Collections
    )
    
    $Collections | ForEach-Object {
        $collection = $_

        $data = $collection.Items

        if (-not $collection.Items) { Return }
        
        if (-not $collection.Properties) { Return }

        $collection.Properties.Keys | ForEach-Object {
            $name = $_

            $property = $collection.Properties[$name]

            $values = $data | Expand-ObjectPath -Path $name

            $options = [ordered]@{
                numeric = '^([0-9]+|[0-9]+\.[0-9]+)$'
            }

            foreach ($v in $values) {
                $removals = foreach ($ok in $options.Keys) {
                    $o = $options[$ok]

                    if ($o -notmatch $o) {
                        $ok
                        break
                    }
                }

                foreach ($r in $removals) {
                    $options.remove($r)
                }

                if ($options.Keys.Count -eq 0) {
                    break
                }
            }

            $values | ForEach-Object {
                $options | Forea
            }

            $type = 'numeric'
            if ($values | Where-Object { $_ -notmatch '[0-9]+' } | Select-Object -First 1) {
                $type = 'decimal'
                if ($values | Where-Object { $_ -notmatch '[0-9]+\.[0-9]+' } | Select-Object -First 1) {
                    $type = 'hex'
                    if ($values | Where-Object { $_ -notmatch '[0-9A-Fa-f]+' } | Select-Object -First 1) {
        
                    }
                }
            }

            
            
        }
        

        $collection | Add-Member -NotePropertyName 'Properties' -NotePropertyValue $props -Force

        $props
    }
}

<#

.INPUTS
@{ Name = 'CollectioName'; Items = @() }

.OUTPUTS
Adds to the Input object the properties:

Properties, PrimaryKey, Related, Links, Distinct, Relationships

#>
Function Resolve-DataRelationships {
    param (
        $Collections
    )
    
    $collections | ForEach-Object {
        $collection = $_

        $data = $collection.Items

        if (-not $collection.Items) { Return }
        
        $props = $data | Get-ObjectPath -PropertyPath ''

        $collection | Add-Member -NotePropertyName 'Properties' -NotePropertyValue $props -Force

        $props
    }

    $collections | ForEach-Object {
        $collection = $_

        $data = $collection.Items

        if (-not $data) { Return }

        $distinct = @{}
        $unique = @{}

        $collection.Properties | ForEach-Object {
            $prop = $_

            $uniq = $data | Group-Object { $_ | Expand-ObjectPath -Path $prop }
            $dist = $uniq | Where-Object { $_.Name -ne '' }

            $distinct[$_] = ($dist.Count / $data.Count)
            $unique[$_] = ($uniq.Count / $data.Count)
        }

        $collection | Add-Member -NotePropertyName 'Distinct' -NotePropertyValue $distinct -Force
        $collection | Add-Member -NotePropertyName 'Unique' -NotePropertyValue $unique -Force
    }

    $collections | ForEach-Object {
        $collection = $_
        
        $collection | Add-Member -NotePropertyName 'PrimaryKey' -NotePropertyValue $null -ErrorAction SilentlyContinue

        if (-not $collection.Distinct) {
            return
        }

        $distinct = @($collection.Distinct.PSObject.Properties.Name | Where-Object {
            $collection.Distinct.$_ -eq 1
        })

        if ($distinct.Count -eq 1) {
            #$collection.PrimaryKey = $distinct[0]
            if ($collection.PrimaryKey -ne $distinct[0]) {
                Write-Host -ForegroundColor Yellow "$($collection.name): $($collection.PrimaryKey) -> $($distinct[0])"
            } else {
                Write-Host -ForegroundColor Green "$($collection.name): $($collection.PrimaryKey)"
            }
        } elseif ($distinct.Count -gt 1) {
            Write-Host -ForegroundColor Cyan "$($collection.name): $($collection.PrimaryKey)"
            $distinct
        } else {
            Write-Host -ForegroundColor Red "$($collection.name): <none>"
        }

        #$idName = "$($collection.name)_id"

        #if ($collection.Properties -contains $idName) {
        #    $collection.PrimaryKey = $idName
        #}
    }
    
    $collections | ForEach-Object {
        $collection = $_

        $related = $collections | Where-Object {
            $_ -ne $collection -and  
            $_.Properties -contains $collection.PrimaryKey
        } | Select-Object -expand name

        $collection | Add-Member -NotePropertyName 'Related' -NotePropertyValue @($related) -Force
    }
    
    $collections | ForEach-Object {
        $collection = $_

        $links = $collection.Properties | Where-Object { $_ -like '*_id' } | ForEach-Object {
            $_.SubString(0, $_.Length - 3)
        } | Where-Object { $_ -notlike $collection.name }

        $collection | Add-Member -NotePropertyName 'Links' -NotePropertyValue @($links) -Force
    }

    $collections | ForEach-Object {
        $collection = $_

        $data = $collection.Items

        if (-not $data) { Return }

        $relationships = @{}
        
        $collection.Links | ForEach-Object {
            $link = $_
            $linkId = "${link}_id"

            $linkCollection = $collections | Where-Object { $_.Name -eq $link }

            if (-not $linkCollection -or -not $linkCollection.Items) {
                Write-Warning "Relationship could not be determined between $($collection.Name) and $link"
                Return
            }

            $dataGroup = $data | Group-Object $linkId
            $linkGroup = $linkCollection.Items | Group-Object $linkId

            $m1 = $dataGroup | Measure-Object -Sum Count
            $m2 = $linkGroup | Measure-Object -Sum Count

            $rel = if ($m1.Count -eq $m1.Sum) {
                'one'
            } else {
                'many'
            }

            $rel += '-to-'

            $rel += if ($m2.Count -eq $m2.Sum) {
                'one'
            } else {
                'many'
            }

            $relationships[$link] = $rel
        }
        
        $collection | Add-Member -NotePropertyName 'Relationships' -NotePropertyValue ([pscustomobject]$relationships) -Force
    }
}
