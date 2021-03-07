

<#

$collections | New-EntityRelationshipDiagram -PrintMarkDown -Exclude 'image','image_set' | Out-File 'test.md'

#>
Function New-EntityRelationshipDiagram {
    param (
        [switch]$PrintMarkDown,
        [switch]$HideProperties,
        [string[]]$Exclude
    )
    begin {
        if ($PrintMarkDown) {
            "``````mermaid"
        }
        "erDiagram"
    }
    process {
        $current = $_

        if ($Exclude -contains $current.Name) {
            Return   
        }

        if (-not $HideProperties -and $current.Properties) {
            "    $($current.Name) {"
            $current.Properties | ForEach-Object {
                "        string $($_.Replace('.','-'))"
            }
            "    }"
        }

        if ($current.Relationships) {
            $current.Relationships.PSObject.Properties | Where-Object { $Exclude -notcontains $_.Name} | ForEach-Object {
                $sb = "    $($_.Name.Replace('.','-'))"

                $sb += Switch ($_.Value) {
                    'one-to-one' { '||--||' }
                    'one-to-many' { '||--|{' }
                    'many-to-many' { '}|--|{' }
                    'many-to-one' { '}|--||' }
                    default { '}o--o{' }
                }
                
                $sb += $current.Name.Replace('.','-')
                "$sb : $($_.Value)"
            }
        }
    }
    end {
        if ($PrintMarkDown) {
            "``````"
        }
    }
}


Function Get-Duplicate($Array)
{
    $Unique = $Array | Select-Object * -Unique

    $Duplicates = (Compare-Object -ReferenceObject $Array -DifferenceObject $Unique | Where-Object { 
        $_.sideIndicator -like "<=" }).inputobject

    $UniqueDuplicates = $Duplicates | Select-Object * -Unique

    Foreach ($Duplicate in $UniqueDuplicates)
    {
        [PSCustomObject]@{
            Duplicate = $Duplicate
            Amount = ($Array | Where-Object { $_ -like $Duplicate }).count
        }
    }
}