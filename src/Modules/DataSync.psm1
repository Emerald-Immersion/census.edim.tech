<#

.DESCRIPTION


.PARAMETER Fetch
Fetch is called with the parameters based on Time or Count.

This should return each object, so they can be counted.

param([DateTime]$StartTime, [DateTime]$EndTime)
param([int]$Offset, [int]$Count)

.PARAMETER FromCount
Count mode, should be the current number of items you have in the collection.

.PARAMETER ToCount
Count mode, ceiling of a max number of records to fetch.

.PARAMETER FromTime
Time mode, should be the newest item you have in the collection.

.PARAMETER ToCount
Time mode, ceiling of the max time of records to fetch.

.PARAMETER Limit
The limit of items that indicate there are more items.

If your Fetch function returns less than this, the loop will break assuming that it has
reached the end of the data stream.

#>
Function Get-DataStream  {
    param (
        [Parameter(Mandatory)][ScriptBlock]$Fetch,
        [Parameter(Mandatory,ParameterSetName='CountSet')][int]$FromCount,
        [Parameter(Mandatory,ParameterSetName='CountSet')][DateTime]$ToCount,
        [Parameter(Mandatory,ParameterSetName='DateSet')][DateTime]$FromTime,
        [Parameter(Mandatory,ParameterSetName='DateSet')][DateTime]$ToTime,
        [Parameter(Mandatory)][int]$Limit
    )

    if ($PSCmdlet.ParameterSetName -eq 'DateSet') {
        $offset = $FromTime

        while ($true) {
            $results = @(Invoke-Command -ScriptBlock $Fetch -ArgumentList $offset,$ToTime)
    
            if ($results.Length -ge $Limit) {
                
            }
        }
    } else {
        $offset = $FromCount

        while ($true) {
            $counter = 0
    
            try {
                Invoke-Command -ScriptBlock $Fetch -ArgumentList $offset,$Limit | ForEach-Object {
                    $counter += 1
                    $_
                }
            } catch {
                
            }
    
            if ($counter -lt $Limit) {
                break
            } else {
                $offset += $counter
            }
        }
    }

}
