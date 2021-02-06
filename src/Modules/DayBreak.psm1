
$global:DayBreakDefaultNameSpace = 'ps2:v2'
$global:DayBreakDefaultEnvironment = 'ps2'
$global:DayBreakDefaultServiceID = 's:example'
<#

.PARAMETER Uri
Use New-DBApiUri to create the Uri.

.PARAMETER Retry
Max retries if the HTTP request fails or the error is Missing Service ID.

.PARAMETER RetryDelaySeconds
The retry delay in seconds.

.EXAMPLE

$result = New-DBApiUrl | Invoke-DBApi

$result.error

#>
Function Invoke-DBApi {
    param (
        [Parameter(ValueFromPipeline, Mandatory, ParameterSetName = 'pipe')]
        [Uri]$InputObject,
        [Parameter(ValueFromPipeline, Mandatory, ParameterSetName = 'once')]
        [Uri]$Url,
        [int]$Retry = 10,
        [int]$RetryDelaySeconds = 5
    )
    process {
        $uri = if ($Url) {
            $Url
        } else {
            $_
        }

        if (-not $uri) {
            Write-Error 'No valid Url given'
        }

        $result = $null

        $tries = 0

        Write-Information "Performing request: $uri"

        while (-not $result) {
            $tries += 1

            try {
                $result = Invoke-RestMethod $uri

                if ($result.error -and $result.error -like '*Missing Service ID*') {
                    if ($tries -ge $Retry) {
                        Write-Error -Message 'API Service ID Blocked' -Exception $result
                        break
                    }

                    $result = $null

                    throw 'throttle'              
                } else {
                    break
                }
            } catch {
                if (-not $result -and $tries -ge $Retry) {
                    Write-Error -Message 'HTTP Error' -Exception $_
                }

                Write-Information "Retry request ($tries/$Retry) in $RetryDelaySeconds seconds: $uri"

                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }

        if ($result) {
            if ($result.error -or $result.errorCode) {
                Write-Error -Message 'API Error or ErrorCode' -TargetObject $result
            } else {
                $result
            }
        }
    }
}

<#

#>
Function Receive-DBWebSocket {
    param (
        $DBWebSocket
    )
    
    Receive-Websocket -Websocket $DBWebSocket -NoBinary -AsJson
}
<#

.DESCRIPTION
Connects to the DayBreak WebSocket and returns the WebSocket object.

.PARAMETER Environment
Alternative Namespace/Environment can be provided, default: ps2

.PARAMETER ServiceID
For production use of the code, please populate the service ID with the s: prefix, defaults to: s:example

#>
Function Connect-DBWebSocket {
    param (
        [string]$Environment = $global:DayBreakDefaultEnvironment,
        [string]$ServiceID = $global:DayBreakDefaultServiceID
    )

    Connect-Websocket -URI "wss://push.planetside2.com/streaming?environment=$([Uri]::EscapeDataString($Environment))&service-id=$([Uri]::EscapeDataString($ServiceID))"
}
<#

.DESCRIPTION
Creates a DayBreak API Url with the given parameters.

Documentation here: https://census.daybreakgames.com/

.PARAMETER Collection
The collection name, can be left empty to give the list of collections.

.PARAMETER Count
Perform a Count query to only return the count for the given query, does not work for everything and may return -1.

.PARAMETER Query
The query string, with or without the ? prefix.

This will precede QueryProperties, if defined.

.PARAMETER QueryProperties
The query but with a hash table of Key/Value pairs.

This will follow Query, if defined.

.PARAMETER NameSpace
Alternative namespace can be provided, default: ps2:v2

.PARAMETER ServiceID
For production use of the code, please populate the service ID with the s: prefix, defaults to: s:example

#>
Function New-DBApiUrl {
    param (
        [string]$Collection,
        [switch]$Count,
        [string]$Query,
        [HashTable]$QueryProperties,
        [string]$NameSpace = $global:DayBreakDefaultNameSpace,
        [string]$ServiceID = $global:DayBreakDefaultServiceID
    )

    [Uri]$uri = [uri]::new('https://census.daybreakgames.com')
    
    if ($ServiceID) {
        $uri = [uri]::new($uri, [Uri]::EscapeDataString($ServiceID) + "/")
    }

    if ($Count) {
        $uri = [uri]::new($uri, 'count/')
    } else {
        $uri = [uri]::new($uri, 'get/')
    }

    if ($NameSpace) {
        $uri = [uri]::new($uri, [Uri]::EscapeDataString($NameSpace) + "/")
    }

    if ($Collection) {
        $uri = [uri]::new($uri, [Uri]::EscapeDataString($Collection) + "/")
    }

    $queryString = ''

    if ($Query) {
        if ($Query[0] -ne '?') {
            $queryString = '?'
        } 
        
        $queryString += $Query
    }
    
    if ($QueryProperties) {
        $sb = [System.Text.StringBuilder]::new()
        $suffix = ''

        if (-not $queryString) {
            $suffix = '?'
        } else {
            $suffix = "$queryString&"
        }

        $QueryProperties.Keys | ForEach-Object {
            [void]$sb.Append($suffix)
            [void]$sb.Append([Uri]::EscapeDataString($_))
            [void]$sb.Append('=')
            [void]$sb.Append([Uri]::EscapeDataString($QueryProperties[$_]))
            $suffix = '&'
        }

        $queryString = $sb.ToString()
    }
    
    [uri]::new($uri, $queryString)
}
