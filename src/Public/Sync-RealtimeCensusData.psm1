

function Sync-RealTimeCensusDeta {
    param (
        $DestinationPath
    )

    $socket = Connect-DBWebSocket
    
    Receive-DBWebSocket -DBWebSocket $socket | Select-Object -First 1 *

    #$socket.SendAsync(
}