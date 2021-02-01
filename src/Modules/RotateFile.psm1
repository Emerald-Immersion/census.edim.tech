<#

.DESCRIPTION
Performs Out-File but rotates the file based on given parameters.

Rotate only triggers when the next item is processed, but that item will be in the new file.

.PARAMETER Rotate
Scriptblock that returns a new rotated filename, usually containing a TimeStamp.

Or perform rotation on the current file and return the same filename. (Use AlwaysRotate)

.PARAMETER AlwaysRotate
For use with Rotate where the same file name will be returned.

.PARAMETER CheckTimeout
From the start time, check after the expiry. (Least efficient)

.PARAMETER CheckInterval
From the start time, check if the interval has changed, like Hourly files.

.PARAMETER CheckCount
Rotate after a certain number of items have been processed.

.PARAMETER CheckLength
Rotate after the length of items processed have exceeded.

.PARAMETER PadLength
For OCD file lengths, all rotated files will be exactly CheckLength with whitespace at the end.

.EXAMPLE

1..100 | % { Start-Sleep -Milliseconds 1000; $_ } | Out-RotateFile `
    -CheckInterval ([TimeSpan]::FromSeconds(1)) `
    -Rotate { "test_$((Get-Date).ToString('s').Replace(':','-')).log" }


1..100 | % { Start-Sleep -Milliseconds 100; $_ } | Out-File -Append test.txt

.EXAMPLE LogRotate

1..100 | % { Start-Sleep -Milliseconds 200; $_ } | Out-RotateFile `
    -CheckInterval ([TimeSpan]::FromSeconds(3)) `
    -AlwaysRotate -Rotate {
        Remove-Item 'log.txt.3' -ErrorAction SilentlyContinue | Out-Null
        Rename-Item 'log.txt.2' 'log.txt.3' -ErrorAction SilentlyContinue | Out-Null
        Rename-Item 'log.txt.1' 'log.txt.2' -ErrorAction SilentlyContinue | Out-Null
        Rename-Item 'log.txt.0' 'log.txt.1' -ErrorAction SilentlyContinue | Out-Null
        Rename-Item 'log.txt' 'log.txt.0' -ErrorAction SilentlyContinue | Out-Null
        'log.txt'
    }

.EXAMPLE

1..100 | Out-RotateFile `
    -CheckCount 1000
    -PipeScript { param($name); & ConvertTo-JsonStream | Out-File -FilePath $name -Append }
    -AlwaysRotate -Rotate {
        param($oldname)

        if ($oldname) {
            ']}' | Out-File -Append -Path $oldname
        }

        $newname = ''

        '{"Items":[' | Out-File -Append -Path $newname
    }


#>
Function Out-RotateFile {
    param (
        [ScriptBlock]$Rotate,
        [switch]$AlwaysRotate,

        [ScriptBlock]$PipeScript = { param($name); & Out-File -FilePath $name -Append },
        
        [string]$InitialName = $null,
        [int]$InitialCount = 0,
        [int]$InitialLength = 0,

        [Nullable[TimeSpan]]$CheckTimeout,
        [Nullable[TimeSpan]]$CheckInterval,
        [Nullable[Int64]]$CheckCount,
        [Nullable[Int64]]$CheckLength,

        [int]$LengthAdd = [System.Environment]::NewLine.Length,
        [switch]$PadLength
    )
    begin {
        $name = $InitialName
        $start = Get-Date
        $count = $InitialCount
        $length = $InitialLength

        $alwaysRefresh = (-not ($CheckTimeout -or $CheckInterval -or $CheckCount -or $CheckLength))

        $pipeline = $null

        if ($name -or $Initialise) {
            $pipeline = $PipeScript.GetSteppablePipeline($myInvocation.CommandOrigin, $name)
            $pipeline.Begin($true)
        }
    }
    process {
        $interrupted = $true

        try {
            $refresh = $alwaysRefresh
            
            if (-not $pipeline) {
                $refresh = $true
            }
            
            if (-not $refresh -and $CheckTimeout) {
                $refresh = ((Get-Date) - $start) -gt $CheckTimeout.Value
            }
            
            if (-not $refresh -and $CheckInterval) {
                $interval1 = [datetime]($start.Ticks - ($start.Ticks % ($CheckInterval.Ticks)))
                $interval2 = (Get-Date)
                $interval2 = [datetime]($interval2.Ticks - ($interval2.Ticks % ($CheckInterval.Ticks)))
                $refresh = $interval1 -ne $interval2
            }
            
            if (-not $refresh -and $CheckCount) {
                $refresh = $count -ge $CheckCount.Value
            } 
            
            if (-not $refresh -and $CheckLength) {
                if ($PadLength) {
                    if (($length + $_.Length + $LengthAdd) -ge $CheckLength.Value) {
                        $pipeline.Process([string]::new([char]' ', ($CheckLength.Value - $length)))
                        $refresh = $true
                    }
                } else {
                    $refresh = ($length + $LengthAdd) -ge $CheckLength.Value
                }
            } 
            

            if ($refresh) {
                if ($AlwaysRotate -and $pipeline) { $pipeline.End() }
                $newname = Invoke-Command -ScriptBlock $Rotate -ArgumentList $name
                if ($AlwaysRotate -or $name -ne $newname) {
                    $name = $newname
                    if (-not $AlwaysRotate -and $pipeline) { $pipeline.End() }
                    $pipeline = $PipeScript.GetSteppablePipeline($myInvocation.CommandOrigin, $name)
                    $pipeline.Begin($true)
                    $start = Get-Date
                    $count = 0
                    $length = 0
                }
            }

            $count += 1
            $length += $_.Length

            $pipeline.Process($_)

            $interrupted = $false
        } finally {
            if ($interrupted) {
                $pipeline.End()
                $pipeline.Dispose()
            }
        }
    }
    end {
        $pipeline.End()
        $pipeline.Dispose()
    }
}
