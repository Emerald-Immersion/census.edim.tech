<#

#>
Function Connect-Websocket ([Uri]$URI, [TimeSpan]$Timeout = [timespan]::Zero) {
    $cts = [System.Threading.CancellationTokenSource]::new()

    $ws = [System.Net.WebSockets.ClientWebSocket]::new()

    if ($Timeout -ne [TimeSpan]::Zero) {
        $cts.CancelAfter($Timeout)
    }

    $ws.ConnectAsync($URI, $cts.Token) | Resolve-Task -CancelSources $cts

    $ws
}
<#

.DESCRIPTION

.NOTES
Although it can be cancelled with Ctrl+C, the cancellation of ReceiveAsync will cause the socket to Abort.

You can use Select-Object -First 1 to limit the results gracefully that wont initilise another ReceiveAsync call.

.EXAMPLE

Receive-Websocket -WebSocket $socket

#>
Function Receive-Websocket {
    param (
        [System.Net.WebSockets.Websocket]$Websocket,
        [switch]$NoBinary,
        [switch]$NoText,
        [switch]$AsJson,
        [Text.Encoding]$Encoding = [Text.Encoding]::UTF8,
        [int]$InitialBufferSize = 1KB,
        [int]$MaxBufferSize = 64KB
    )

    if ($Websocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        throw 'Socket not open'
    }

    $buffer = [byte[]]::new($InitialBufferSize)
    $count = 0

    $cts = [System.Threading.CancellationTokenSource]::new()

    try {
        while ($Websocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $seg = [System.ArraySegment[byte]]::new($buffer, $count, $buffer.Length - $count)

            [System.Net.WebSockets.WebSocketReceiveResult]$receiveResult = $Websocket.ReceiveAsync($seg, $cts.Token) | Resolve-Task -CancelSources $cts

            if ($NoBinary -and $receiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Binary) {
                throw [System.Net.WebSockets.WebSocketCloseStatus]::InvalidMessageType
            } elseif ($NoText -and $receiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {
                throw [System.Net.WebSockets.WebSocketCloseStatus]::InvalidMessageType
            } elseif ($receiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                throw [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure
            } elseif (-not $receiveResult.EndOfMessage -and $buffer.Length -ge $MaxBufferSize) {
                throw [System.Net.WebSockets.WebSocketCloseStatus]::MessageTooBig
            }

            $count += $receiveResult.Count

            if ($receiveResult.EndOfMessage) {
                if ($receiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {
                    $str = $Encoding.getstring($buffer, 0, $count)

                    if ($AsJson) {
                        $str | ConvertFrom-Json -Depth 10
                    } else {
                        $str
                    }
                } else {
                    $buffer

                    $buffer = [byte[]]::new($buffer.Length)
                }

                $count = 0
            } elseif ($buffer.Length -lt $MaxBufferSize) {
                $newBuffer = [byte[]]::new($buffer.Length -shl 1)

                $buffer.CopyTo($newBuffer, 0)

                $buffer = $newBuffer
            }
        }
    } catch {
        $closeStatus = if ($_ -is [System.Net.WebSockets.WebSocketCloseStatus]) {
            $_
        } else {
            [System.Net.WebSockets.WebSocketCloseStatus]::InternalServerError
        }

        $closeMessage = if ($close -eq [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure) {
            'Client Request Closure'
        } else {
            "$($receiveResult.MessageType) not supported"
        }

        $cts = [System.Threading.CancellationTokenSource]::new()

        $Websocket.CloseAsync($closeStatus, $closeMessage, $cts.Token) | Resolve-Task -CancelSources $cts

        if ($_ -isnot [System.Net.WebSockets.WebSocketCloseStatus]) {
            throw $_
        }
    } finally {
        
    }
}
<#

#>
Function Resolve-Task {
    param (
        [Parameter(ValueFromPipeline, Mandatory)][System.Threading.Tasks.Task[]]$InputObject,
        [System.Threading.CancellationTokenSource[]]$CancelSources
    )
    begin {
        $tasks = @()
    }
    process {
        $tasks += $_
    }
    end {
        try {
            $pending = [System.Collections.ArrayList]$tasks

            while ($pending.Count -gt 0) {
                $a = $pending.ToArray()

                $r = [System.Threading.Tasks.Task]::WaitAny($a, 200)

                if ($r -ne -1) {
                    [System.Threading.Tasks.Task]$task = $a[$r]

                    $pending.Remove($task)

                    if ($task.Exception) {
                        Write-Error -Message 'Task Exception' -Exception $task.Exception
                    } else {
                        $result = $task.GetAwaiter().GetResult()

                        if ($result -isnot [Type]::GetType('System.Threading.Tasks.VoidTaskResult')) {
                            $result
                        }
                    }
                }
            }
        } finally {
            if ($CancelSources -and $CancelSources.Count -gt 0) {
                $CancelSources | ForEach-Object {
                    $_.Cancel()
                }
            }
        }
    }
}
