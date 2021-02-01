$ModuleDir = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    '.\src'
}

[System.Collections.ArrayList]$items = @(Get-ChildItem -Path $ModuleDir -Directory | Get-ChildItem -Filter *.psm1 -Recurse)

$count = $items.Count
$items | ForEach-Object { $_ | Add-Member -NotePropertyName Attempts -NotePropertyValue 0 -Force } 

while ($items.Count -gt 0) {
    $item = $items[0]
    $items.RemoveAt(0)
    $item.Attempts += 1

    try {
        Import-Module -ErrorAction Stop -Name $item.FullName
    } catch {
        if ($_.Exception.ErrorRecord -like '*#requires*') {
            if ($item.Attempts -gt $count) {
                Write-Error -Exception $_.Exception
                break
            }

            $items.Add($item)
        } else {
            Write-Error -Exception $_.Exception
        }
    }
}
