param(
    [ValidateRange(1, 65535)]
    [int]$Port = 3180,
    [switch]$Select
)

$localAddresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.IPAddress -notlike '169.254.*' -and
        $_.PrefixLength -ge 0 -and
        $_.PrefixLength -le 32
    })

$addressesToScan = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($localAddress in $localAddresses) {
    if ($localAddress.PrefixLength -lt 16) {
        Write-Warning "Skipping $($localAddress.IPAddress)/$($localAddress.PrefixLength): subnet is larger than 65,536 addresses."
        continue
    }

    $addressBytes = [System.Net.IPAddress]::Parse($localAddress.IPAddress).GetAddressBytes()
    $networkBytes = [byte[]]::new(4)
    $remainingPrefixBits = $localAddress.PrefixLength

    for ($index = 0; $index -lt 4; $index++) {
        $bitsInOctet = [Math]::Min(8, $remainingPrefixBits)
        $mask = if ($bitsInOctet -eq 0) {
            0
        } else {
            (0xFF -shl (8 - $bitsInOctet)) -band 0xFF
        }
        $networkBytes[$index] = [byte]($addressBytes[$index] -band $mask)
        $remainingPrefixBits -= $bitsInOctet
    }

    $networkNumber = [uint64](
        ([uint64]$networkBytes[0] -shl 24) -bor
        ([uint64]$networkBytes[1] -shl 16) -bor
        ([uint64]$networkBytes[2] -shl 8) -bor
        [uint64]$networkBytes[3]
    )
    $subnetSize = [uint64]1 -shl (32 - $localAddress.PrefixLength)

    if ($localAddress.PrefixLength -le 30) {
        $firstHost = $networkNumber + 1
        $lastHost = $networkNumber + $subnetSize - 2
    } elseif ($localAddress.PrefixLength -eq 31) {
        $firstHost = $networkNumber
        $lastHost = $networkNumber + 1
    } else {
        $firstHost = $networkNumber
        $lastHost = $networkNumber
    }

    for ([uint64]$number = $firstHost; $number -le $lastHost; $number++) {
        $bytes = [byte[]]@(
            [byte](($number -shr 24) -band 0xFF),
            [byte](($number -shr 16) -band 0xFF),
            [byte](($number -shr 8) -band 0xFF),
            [byte]($number -band 0xFF)
        )
        [void]$addressesToScan.Add(([System.Net.IPAddress]::new($bytes)).ToString())
    }
}

if ($addressesToScan.Count -eq 0) {
    Write-Warning 'No scannable local IPv4 addresses were found.'
    return
}

$servers = @($addressesToScan | ForEach-Object -Parallel {
    $ip = $_
    $uri = "http://${ip}:$using:Port/v1/models"

    $tcpClient = $null
    try {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $connectTask = $tcpClient.ConnectAsync($ip, [int]$using:Port)
        if (-not $connectTask.Wait(500) -or -not $tcpClient.Connected) {
            return
        }
    } catch {
        return
    } finally {
        if ($null -ne $tcpClient) {
            $tcpClient.Dispose()
        }
    }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 3 -ErrorAction Stop
        if ($null -eq $response.data) {
            return
        }

        $models = @($response.data | ForEach-Object {
            if ($_.id) {
                $_.id
            }
        })

        [PSCustomObject]@{
            IP     = $ip
            URL    = "http://${ip}:$using:Port"
            Models = $models -join ', '
        }
    } catch {
        # Most scanned addresses will be offline or will not expose this API.
    }
} -ThrottleLimit 128)

if ($servers.Count -eq 0) {
    Write-Host "No OpenAI-compatible servers found on port $Port."
    return
}

$servers = @($servers | Sort-Object IP)

if (-not $Select) {
    Write-Host "OpenAI-compatible servers on port ${Port}:"
    $servers | Format-Table -AutoSize -Wrap
    return
}

if ([Console]::IsInputRedirected) {
    throw 'Interactive selection requires a console. Run the script from a terminal.'
}

$selectedIndex = 0
$selectedServer = $null

while ($null -eq $selectedServer) {
    Clear-Host
    Write-Host "Select an OpenAI-compatible server on port ${Port}:"

    for ($index = 0; $index -lt $servers.Count; $index++) {
        $marker = if ($index -eq $selectedIndex) { '>' } else { ' ' }
        $line = '{0} {1}. {2}  {3}' -f $marker, ($index + 1), $servers[$index].URL, $servers[$index].Models
        if ($index -eq $selectedIndex) {
            Write-Host $line -ForegroundColor Cyan
        } else {
            Write-Host $line
        }
    }

    Write-Host 'Use Up/Down and Enter to select, a number for quick selection, or Esc to cancel.'
    $key = [Console]::ReadKey($true)

    switch ($key.Key) {
        'UpArrow' {
            $selectedIndex = ($selectedIndex - 1 + $servers.Count) % $servers.Count
        }
        'DownArrow' {
            $selectedIndex = ($selectedIndex + 1) % $servers.Count
        }
        'Enter' {
            $selectedServer = $servers[$selectedIndex]
        }
        'Escape' {
            Write-Host 'Selection cancelled.'
            return
        }
        default {
            if ($key.KeyChar -match '^[1-9]$') {
                $numberedIndex = [int]::Parse($key.KeyChar.ToString()) - 1
                if ($numberedIndex -lt $servers.Count) {
                    $selectedIndex = $numberedIndex
                    $selectedServer = $servers[$selectedIndex]
                }
            }
        }
    }
}

$env:OPENAI_BASE_URL = "$($selectedServer.URL)/v1"
$env:OPENAI_API_KEY = "sk-jb-12345678"
Write-Host "Selected $($selectedServer.URL). OPENAI_BASE_URL and OPENAI_API_KEY are set for this PowerShell session."
