#Requires -Modules DayBreakPS2
#Requires -Modules JsonObject
#Requires -Modules DataSync

<#

.DESCRIPTION
The different classifications of data are:

Character = 13 million records
Outfit = 253k records with 1.3m member records

Small < 1000 records, usually lookup tables
Medium < 10k records, most collections
Large > 10k records, usually relationship tables



#>
Function Sync-LiveCensusData ([string]$DataFolder) {

    $begin = Get-Date

    $collections = Get-DBPS2_Collection

    $collections | Resolve-DBPS2_CollectionCount -PassThru | Out-Host

    $collections | Where-Object { $_.count -lt 10000 } | ForEach-Object {
        
        $url = New-DBApiUrl -Collection $_.name -Query '?c:limit=10000'

        $result = Invoke-DBApi -Url $url

        

        for ($i = 0; $i -lt $_.count; $i += 1000) {
            $to = $i + 1000

            # ConvertTo-JsonLookup
        }
    }
}