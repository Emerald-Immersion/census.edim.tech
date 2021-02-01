
<#

.EXAMPLE

$vehicle_attachment_pages = Get-PlanetSideMany -url 'https://census.daybreakgames.com/get/ps2:v2/vehicle_attachment/?' -start 0 -limit 5000

$vehicle_attachment = $vehicle_attachment_pages | Select-Object -Expand vehicle_attachment_list

Get-DataStream -Fetch {
    param([int]$Offset, [int]$Count)

    $result = Invoke-RestMethod "https://census.daybreakgames.com/get/ps2:v2/vehicle_attachment/?c:limit=$Count&c:start=$Offset"

    $result.vehicle_attachment_list
}


$vehicle_attachment_pages = Get-PlanetSideMany -url 'https://census.daybreakgames.com/get/ps2:v2/vehicle_attachment/?' -start 0 -limit 5000

#>
Function Get-PlanetSideMany ([string]$url, [int]$start, [int]$limit) {

    Get-DataStream -FromCount -ToCount -Limit 1000 -Fetch {
        param([int]$Offset, [int]$Count)

        $next = "${ps2}/${name}/?c:limit=${Count}&c:start=${Offset}"

        $page = $null

        $retries = 0
        
        while (-not $page) {
            try {
                $page = Invoke-RestMethod $next

                if ($page.error -and $page.error -like '*Missing Service ID*') {
                    Write-Host "Throttled, waiting 5 seconds..."
                    $page = $null
                    Start-Sleep -Seconds 5
                } else {
                    break
                }
            } catch {
                if ($retries -gt 3) {
                    throw $_
                }

                Write-Host "Request failed, sleeping 5 seconds, probably throttling: $next"

                $_

                Start-Sleep -Seconds 5

                $retries += 1
            }
        }

        if ($page.error -or $page.errorCode) {
            Write-Warning "Collection returned error: $name"
            $page
        }
 
        if ($page.returned) {

        }

        $_
    }

}